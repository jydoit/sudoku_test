extends SceneTree

const LevelDirectorScript = preload("res://scripts/level_director.gd")
const SAVE_PATH := "user://color_queens_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_save := ""
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_PATH)

	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	assert(game.levels.size() >= 50, "MVP should include 50 default levels")
	assert(game.home_screen != null, "Home screen should exist")
	assert(game.game_screen != null, "Game screen should exist")
	game.tutorial_completed = true
	game.tutorial_started = false
	if game.tutorial_resume_dialog:
		game.tutorial_resume_dialog.hide()
	game._load_level(0)
	game._show_game()
	assert(game.level_select_button != null, "Level screen should expose level selection")
	game._open_level_select()
	assert(game.level_select_dialog.visible, "Level selection dialog should open")
	assert(game.level_select_picker.get_item_count() == game.levels.size(), "Level selection should list all levels")
	game.level_select_picker.select(1)
	game._confirm_level_select()
	assert(int(game.current_level["levelId"]) == int(game.levels[1]["levelId"]), "Level selection should enter the selected level")
	await process_frame
	assert(game.board != null and game.board.size.x >= 400.0, "Board must render at a mobile-friendly size")

	for level in game.levels:
		_validate_solution(level)
	for index in range(9):
		assert(str(game.levels[index].get("kingInfo", "")).begins_with("国王提示："), "First nine levels should include king guidance copy")
		assert(game.levels[index].get("kingPosition", []).size() == 2, "First nine levels should include an opening king position")
	assert(str(game.levels[9].get("kingInfo", "")) == "", "Level 10 should not use the first-nine king guidance copy")
	assert(game.levels[9].get("kingPosition", []).is_empty(), "Level 10 should not start with a king position")
	for display_level in range(1, 11):
		var fixed_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, display_level, {})
		assert(int(fixed_schedule["levelIndex"]) == display_level - 1, "First ten display levels must stay fixed")
	assert(LevelDirectorScript.unlocked_sizes(11) == [5, 6], "Display level 11 should unlock 5x5 and 6x6")
	assert(LevelDirectorScript.unlocked_sizes(40).has(9), "Display level 40 should unlock 9x9")
	var completed_ids := []
	for completed_id in range(1, 31):
		completed_ids.append(completed_id)
	var dynamic_progress := {"completedLevelIds": completed_ids, "recentRuns": [], "statsByArm": {}}
	var dynamic_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, 11, dynamic_progress)
	assert(int(dynamic_schedule["displayLevel"]) == 11, "Dynamic schedule should keep the player-facing level number")
	assert(not completed_ids.has(int(dynamic_schedule["levelId"])), "Dynamic schedule should skip already completed raw levelIds")
	_validate_dynamic_king_positions(game.levels[int(dynamic_schedule["levelIndex"])], dynamic_schedule)
	var challenge_progress := {
		"completedLevelIds": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
		"recentRuns": [
			{"levelId": 1, "size": 5, "difficulty": "simple", "elapsedSeconds": 20.0, "moves": 5, "hints": 0},
			{"levelId": 7, "size": 5, "difficulty": "hard", "elapsedSeconds": 95.0, "moves": 21, "hints": 1}
		],
		"statsByArm": {}
	}
	var challenge_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, 20, challenge_progress)
	assert(bool(challenge_schedule["isMilestoneChallenge"]), "Every tenth display level should be marked as a challenge")
	assert(str(challenge_schedule["mode"]) == "challenge", "Milestone levels should use the challenge branch")

	game.immediate_errors = true
	game.heart_count = 3
	game._load_level(0)
	assert(str(game.coach_label.text).begins_with("国王提示："), "Level 1 should display king guidance in the coach area")
	var king_position: Array = game.current_level["kingPosition"]
	assert(game.cell_states[int(king_position[0])][int(king_position[1])] == "king", "Level 1 should show a fixed king at the opening position")
	assert(game._piece_positions().size() == 1, "Opening king should count as an existing piece")
	game._on_cell_pressed(0, 0)
	assert(game.cell_states[0][0] == "blocked", "First tap must place an exclusion mark")
	game._on_cell_pressed(0, 0)
	assert(game.cell_states[0][0] == "empty", "Second tap must cancel an exclusion mark")
	var drag_cells := _first_two_editable_cells(game)
	var drag_start: Vector2i = drag_cells[0]
	var drag_next: Vector2i = drag_cells[1]
	game._on_cell_drag_started(drag_start.y, drag_start.x)
	game._on_cell_dragged(drag_next.y, drag_next.x)
	game._on_cell_drag_ended()
	assert(game.cell_states[drag_start.y][drag_start.x] == "blocked" and game.cell_states[drag_next.y][drag_next.x] == "blocked", "Drag from empty cells must mark X")
	game._on_cell_drag_started(drag_start.y, drag_start.x)
	game._on_cell_dragged(drag_next.y, drag_next.x)
	game._on_cell_drag_ended()
	assert(game.cell_states[drag_start.y][drag_start.x] == "empty" and game.cell_states[drag_next.y][drag_next.x] == "empty", "Drag from X cells must erase X")
	var solution_cell: Array = _first_editable_solution_cell(game)
	game._on_cell_double_pressed(int(solution_cell[0]), int(solution_cell[1]))
	assert(game.cell_states[int(solution_cell[0])][int(solution_cell[1])] == "piece", "Double tap on the answer must place a crown")
	game._undo()
	assert(game.cell_states[int(solution_cell[0])][int(solution_cell[1])] == "empty", "Undo should remove the placed crown")
	var exploratory_cell := _first_non_solution_non_conflicting_cell(game)
	var hearts_before_explore: int = game.heart_count
	game._on_cell_double_pressed(exploratory_cell.y, exploratory_cell.x)
	assert(game.cell_states[exploratory_cell.y][exploratory_cell.x] == "piece", "Non-solution exploratory crowns should be allowed when they do not break rules")
	assert(game.heart_count == hearts_before_explore, "Non-conflicting exploratory crowns should not consume hearts")
	game._on_cell_pressed(exploratory_cell.y, exploratory_cell.x)
	assert(game.cell_states[exploratory_cell.y][exploratory_cell.x] == "blocked", "Editable crowns should turn into X on single tap")
	game._on_cell_pressed(exploratory_cell.y, exploratory_cell.x)
	assert(game.cell_states[exploratory_cell.y][exploratory_cell.x] == "empty", "X created from an editable crown should clear on the next tap")
	var conflict_cell := _first_conflicting_cell(game)
	var hearts_before_conflict: int = game.heart_count
	game._on_cell_double_pressed(conflict_cell.y, conflict_cell.x)
	assert(game.cell_states[conflict_cell.y][conflict_cell.x] == "piece", "Rule-breaking crowns should stay editable as normal pieces")
	assert(game.heart_count == hearts_before_conflict - 1, "Rule-breaking crowns should consume one heart")
	assert(game.board.error_cells.has(conflict_cell), "Rule-breaking crowns should be highlighted by conflict detection")
	assert(game.heart_dialog.visible, "Rule-breaking crowns should show the heart placeholder dialog")
	game.heart_dialog.hide()
	game.cell_states[conflict_cell.y][conflict_cell.x] = "wrong"
	game.board.set_states(game.cell_states)
	game._on_cell_pressed(conflict_cell.y, conflict_cell.x)
	assert(game.cell_states[conflict_cell.y][conflict_cell.x] == "empty", "Single tap must clear legacy wrong red X marks")
	game.cell_states[conflict_cell.y][conflict_cell.x] = "wrong"
	game.board.set_states(game.cell_states)
	game._clear_board()
	assert(game.cell_states[conflict_cell.y][conflict_cell.x] == "empty", "Clear must remove legacy wrong red X marks")
	assert(game._piece_positions().size() == 1, "Clear must keep the fixed opening king")
	assert(game.cell_states[int(king_position[0])][int(king_position[1])] == "king", "Clear must not remove the fixed king")
	game.resume_level_id = int(game.current_level["levelId"])
	game.resume_completed = false
	game.resume_states = game.cell_states.duplicate(true)
	game._load_level(0, true, LevelDirectorScript.schedule_for_display_level(game.levels, 1, {}))
	assert(game.cell_states[int(king_position[0])][int(king_position[1])] == "king", "Fixed opening levels should still show the opening king after restore")
	assert(_count_state(game.cell_states, "blocked") == 0, "Fixed opening levels should not restore old X marks")
	assert(_count_state(game.cell_states, "wrong") == 0, "Fixed opening levels should not restore old wrong marks")

	game.hint_count = 3
	game._update_hint_button()
	var coins_before: int = game.coin_count
	var hints_before: int = game.hint_count
	game._use_hint()
	assert(game._piece_positions().size() == 1, "Hint should teach without placing a new piece")
	assert(game.board.guide_cells.size() >= 1, "Hint must highlight the best next reasoning step")
	assert(str(game.coach_label.text).length() >= 20, "Hint must explain why this step is useful now")
	assert(game.hint_count == hints_before - 1, "Hint must consume one available use")
	assert(game.coin_count == coins_before, "Free hint uses must not charge coins")

	game._load_level(0)
	for coordinate in game.current_level["solution"]:
		game._on_cell_double_pressed(int(coordinate[0]), int(coordinate[1]))
	assert(game.is_completed, "A valid solution must complete the level")

	await create_timer(0.8).timeout
	game.queue_free()
	await process_frame
	_restore_save(had_save, previous_save)
	print("SMOKE TEST PASSED: levels, conflicts, undo, clear, hint and completion")
	quit()


func _first_two_editable_cells(game) -> Array:
	var result: Array = []
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if game._is_king_cell(row, col):
				continue
			if str(game.cell_states[row][col]) == "empty":
				result.append(Vector2i(col, row))
				if result.size() == 2:
					return result
	return result


func _first_editable_solution_cell(game) -> Array:
	for coordinate in game.current_level["solution"]:
		if not game._is_king_cell(int(coordinate[0]), int(coordinate[1])):
			return coordinate
	return game.current_level["solution"][0]


func _first_non_solution_non_conflicting_cell(game) -> Vector2i:
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if game._is_king_cell(row, col) or game._is_solution_cell(row, col):
				continue
			if str(game.cell_states[row][col]) != "empty":
				continue
			game.cell_states[row][col] = "piece"
			var conflicts: bool = game._piece_conflicts_at(Vector2i(col, row))
			game.cell_states[row][col] = "empty"
			if not conflicts:
				return Vector2i(col, row)
	assert(false, "Test level should have at least one non-solution exploratory cell that does not immediately conflict")
	return Vector2i(-1, -1)


func _first_conflicting_cell(game) -> Vector2i:
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if game._is_king_cell(row, col):
				continue
			if str(game.cell_states[row][col]) != "empty":
				continue
			game.cell_states[row][col] = "piece"
			var conflicts: bool = game._piece_conflicts_at(Vector2i(col, row))
			game.cell_states[row][col] = "empty"
			if conflicts:
				return Vector2i(col, row)
	assert(false, "Test level should have at least one cell that conflicts with the opening king")
	return Vector2i(-1, -1)


func _count_state(states: Array, target: String) -> int:
	var count := 0
	for row in states:
		for state in row:
			if str(state) == target:
				count += 1
	return count


func _validate_dynamic_king_positions(level: Dictionary, schedule: Dictionary) -> void:
	var kings: Array = schedule.get("kingPositions", [])
	assert(kings.size() >= 1 and kings.size() <= 3, "Dynamic levels should reveal 1-3 opening kings")
	var allowed := {}
	for ordinal in [2, 4, 6, 8]:
		var index := int(ordinal) - 1
		if index >= 0 and index < level["solution"].size():
			var coordinate: Array = level["solution"][index]
			allowed[Vector2i(int(coordinate[1]), int(coordinate[0]))] = true
	for king in kings:
		assert(king is Array and king.size() >= 2, "Opening king should use [row, col]")
		assert(allowed.has(Vector2i(int(king[1]), int(king[0]))), "Opening king should come from solution positions 2/4/6/8")


func _validate_solution(level: Dictionary) -> void:
	var rows := int(level["rows"])
	var cols := int(level["cols"])
	assert(rows == cols, "Migrated levels should be square")
	assert(rows >= 5 and rows <= 9, "Migrated levels should support 5x5 through 9x9 boards")
	assert(level["regions"].size() == rows, "Region row count must match level")
	for region_row in level["regions"]:
		assert(region_row.size() == cols, "Region column count must match level")
	assert(int(level["targetCount"]) == rows, "Queens-style levels should place one piece per row")

	var seen_rows := {}
	var seen_cols := {}
	var seen_regions := {}
	var positions: Array[Vector2i] = []
	for coordinate in level["solution"]:
		var row := int(coordinate[0])
		var col := int(coordinate[1])
		var region := int(level["regions"][row][col])
		assert(not seen_rows.has(row), "Solution row must be unique")
		assert(not seen_cols.has(col), "Solution column must be unique")
		assert(not seen_regions.has(region), "Solution region must be unique")
		seen_rows[row] = true
		seen_cols[col] = true
		seen_regions[region] = true
		positions.append(Vector2i(col, row))
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var a := positions[i]
			var b := positions[j]
			assert(not (absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1), "Solution pieces cannot be adjacent")
	assert(str(level.get("difficulty", "")) != "", "Each default level should have a difficulty label")


func _count_solutions(level: Dictionary, limit: int) -> int:
	var rows := int(level["rows"])
	var cols := int(level["cols"])
	var used_cols := {}
	var used_regions := {}
	var positions: Array[Vector2i] = []
	return _search_solutions(level, rows, cols, 0, used_cols, used_regions, positions, limit)


func _search_solutions(level: Dictionary, rows: int, cols: int, row: int, used_cols: Dictionary, used_regions: Dictionary, positions: Array[Vector2i], limit: int) -> int:
	if row >= rows:
		return 1

	var count := 0
	for col in range(cols):
		if used_cols.has(col):
			continue
		var region := int(level["regions"][row][col])
		if used_regions.has(region):
			continue
		var candidate := Vector2i(col, row)
		var adjacent := false
		for position in positions:
			if absi(position.x - candidate.x) <= 1 and absi(position.y - candidate.y) <= 1:
				adjacent = true
				break
		if adjacent:
			continue

		used_cols[col] = true
		used_regions[region] = true
		positions.append(candidate)
		count += _search_solutions(level, rows, cols, row + 1, used_cols, used_regions, positions, limit - count)
		positions.pop_back()
		used_cols.erase(col)
		used_regions.erase(region)
		if count >= limit:
			return count
	return count


func _restore_save(had_save: bool, contents: String) -> void:
	if had_save:
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(contents)
		file = null
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
