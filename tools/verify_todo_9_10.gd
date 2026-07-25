extends SceneTree

const LevelDirectorScript = preload("res://scripts/level_director.gd")
const SAVE_PATH := "user://color_queens_save.json"

var packed: PackedScene
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_save()
	packed = load("res://scenes/main.tscn")
	_check(packed != null, "VERIFY setup should load main scene")

	var game = await _new_game()
	game.localization.set_locale("zh")
	await _settle()

	for display_level in [11, 30, 31, 50]:
		await _verify_high_level_failure_flow(game, display_level)

	await _dispose_game(game)

	await _verify_resume_after_hint(31)
	await _verify_resume_after_drag(31)
	await _verify_resume_after_wrong_mark(11)
	await _verify_resume_failed_overlay(31)

	_remove_save()
	if failures.is_empty():
		print("TODO 9/10 VERIFY PASSED: high-level failure and resume cleanup")
		quit()
	else:
		for failure in failures:
			push_error(failure)
		print("TODO 9/10 VERIFY FAILED: %d issue(s)" % failures.size())
		quit(1)


func _new_game():
	var game = packed.instantiate()
	root.add_child(game)
	await _settle()
	game.tutorial_completed = true
	game.tutorial_started = false
	game.in_tutorial = false
	return game


func _dispose_game(game) -> void:
	if game and is_instance_valid(game):
		root.remove_child(game)
		game.queue_free()
	await _settle()


func _verify_high_level_failure_flow(game, display_level: int) -> void:
	var schedule := LevelDirectorScript.schedule_for_display_level(game.levels, display_level, {})
	game.player_level_number = display_level
	game._load_level(int(schedule.get("levelIndex", 0)), false, schedule)
	game._show_game()
	game._cancel_opening_king_intro()
	await _settle()

	var expected_hearts: int = game._heart_limit_for_display_level(display_level)
	_check(game.current_heart_limit == expected_hearts, "Display level %d should use the documented heart limit" % display_level)
	_check(game.heart_count == expected_hearts, "Display level %d should start with full hearts" % display_level)
	_check(not game.is_failed, "Display level %d should start active" % display_level)

	var wrong_cells := _first_non_solution_cells(game, expected_hearts)
	_check(wrong_cells.size() == expected_hearts, "Display level %d should provide enough wrong cells for failure verification" % display_level)
	var original_level_id := int(game.current_level["levelId"])
	var failure_seen := 0
	for index in range(wrong_cells.size()):
		var cell: Vector2i = wrong_cells[index]
		var hearts_before: int = game.heart_count
		game._on_cell_double_pressed(cell.y, cell.x)
		await _settle()
		_check(int(game.current_level["levelId"]) == original_level_id, "Wrong attempt should not reload display level %d" % display_level)
		_check(game.cell_states[cell.y][cell.x] == "wrong", "Wrong attempt should leave a locked red X on display level %d" % display_level)
		_check(game.heart_count == hearts_before - 1, "Wrong attempt should consume exactly one heart on display level %d" % display_level)
		if game.heart_count > 0:
			_check(not game.is_failed, "Display level %d should not fail before hearts reach zero" % display_level)
			_check(not game.completion_overlay.visible, "Display level %d should not show failure overlay before hearts reach zero" % display_level)
		else:
			failure_seen += 1
			_check(game.is_failed, "Display level %d should fail when hearts reach zero" % display_level)
			_check(game.completion_overlay.visible, "Display level %d should show failure overlay when hearts reach zero" % display_level)
			_check(game.result_overlay_mode == "failure", "Display level %d should enter failure result mode" % display_level)
			_check(game.completion_next_button.text == "重新挑战", "Display level %d failure primary button should retry" % display_level)
			_check(game.completion_replay_button.text == "返回首页", "Display level %d failure secondary button should return home" % display_level)
	_check(failure_seen == 1, "Display level %d should enter failure once" % display_level)


func _verify_resume_after_hint(display_level: int) -> void:
	_remove_save()
	var game = await _new_game()
	_load_display_level(game, display_level)
	game._use_hint()
	await _settle()
	_check(game.board.guide_mask_enabled, "Hint scenario should create a temporary guide mask")
	_check(not game.board.guide_cells.is_empty(), "Hint scenario should create temporary guide cells")
	var level_id := int(game.current_level["levelId"])
	var saved_states: Array = game.cell_states.duplicate(true)
	await _dispose_game(game)

	var restored = await _new_game()
	await _settle()
	_check(int(restored.current_level["levelId"]) == level_id, "Resume after hint should restore the saved level")
	_check(restored.cell_states == saved_states, "Resume after hint should restore board progress")
	_check(restored.board.guide_cells.is_empty(), "Resume after hint should clear temporary guide cells")
	_check(restored.drag_mode == "", "Resume after hint should not retain drag mode")
	_check(not restored.completion_overlay.visible, "Resume after hint should not show stale overlays")
	await _dispose_game(restored)


func _verify_resume_after_drag(display_level: int) -> void:
	_remove_save()
	var game = await _new_game()
	_load_display_level(game, display_level)
	var start := _first_empty_non_solution_cell(game)
	var next := _adjacent_empty_non_solution_cell(game, start)
	_check(start.x >= 0 and next.x >= 0, "Drag scenario should find adjacent editable cells")
	game._on_cell_drag_started(start.y, start.x)
	game._on_cell_dragged(next.y, next.x)
	game._on_cell_drag_ended()
	await _settle()
	_check(game.drag_mode == "", "Drag should end before save")
	var saved_states: Array = game.cell_states.duplicate(true)
	await _dispose_game(game)

	var restored = await _new_game()
	await _settle()
	_check(restored.cell_states == saved_states, "Resume after drag should restore permanent X marks")
	_check(restored.drag_mode == "", "Resume after drag should not retain drag mode")
	_check(restored.drag_cells.is_empty(), "Resume after drag should not retain drag cells")
	_check(restored.board.guide_cells.is_empty(), "Resume after drag should not show a hint mask")
	await _dispose_game(restored)


func _verify_resume_after_wrong_mark(display_level: int) -> void:
	_remove_save()
	var game = await _new_game()
	_load_display_level(game, display_level)
	var wrong := _first_empty_non_solution_cell(game)
	var hearts_before: int = game.heart_count
	game._on_cell_double_pressed(wrong.y, wrong.x)
	await _settle()
	_check(game.cell_states[wrong.y][wrong.x] == "wrong", "Wrong mark scenario should create a locked red X")
	_check(game.heart_count == hearts_before - 1, "Wrong mark scenario should consume one heart")
	_check(not game.is_failed, "Display level %d should have hearts remaining after one wrong mark" % display_level)
	var saved_states: Array = game.cell_states.duplicate(true)
	var saved_hearts: int = game.heart_count
	await _dispose_game(game)

	var restored = await _new_game()
	await _settle()
	_check(restored.cell_states == saved_states, "Resume after wrong mark should preserve the red X")
	_check(restored.heart_count == saved_hearts, "Resume after wrong mark should preserve remaining hearts")
	_check(not restored.is_failed, "Resume after non-fatal wrong mark should remain playable")
	_check(restored.board.guide_cells.is_empty(), "Resume after wrong mark should not show stale hint mask")
	await _dispose_game(restored)


func _verify_resume_failed_overlay(display_level: int) -> void:
	_remove_save()
	var game = await _new_game()
	_load_display_level(game, display_level)
	var wrong := _first_empty_non_solution_cell(game)
	game._on_cell_double_pressed(wrong.y, wrong.x)
	await _settle()
	_check(game.is_failed, "Display level %d should fail after one wrong mark at one-heart tiers" % display_level)
	_check(game.completion_overlay.visible, "Failed state should show the failure overlay before app exit")
	await _dispose_game(game)

	var restored = await _new_game()
	await _settle()
	_check(restored.is_failed, "Resume after failed level should preserve failed state")
	restored._start_current_flow()
	await _settle()
	_check(restored.completion_overlay.visible, "Starting a resumed failed level should show failure overlay")
	_check(restored.result_overlay_mode == "failure", "Resume after failed level should remain in failure mode")
	_check(restored.board.guide_cells.is_empty(), "Resume after failed level should not show a stale hint mask")
	await _dispose_game(restored)


func _load_display_level(game, display_level: int) -> void:
	var schedule := LevelDirectorScript.schedule_for_display_level(game.levels, display_level, {})
	game.player_level_number = display_level
	game._load_level(int(schedule.get("levelIndex", 0)), false, schedule)
	game._show_game()
	game._cancel_opening_king_intro()


func _first_non_solution_cells(game, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if game._is_king_cell(row, col) or game._is_solution_cell(row, col):
				continue
			if game.cell_states[row][col] == "empty":
				cells.append(Vector2i(col, row))
				if cells.size() >= count:
					return cells
	return cells


func _first_empty_non_solution_cell(game) -> Vector2i:
	var cells := _first_non_solution_cells(game, 1)
	return cells[0] if not cells.is_empty() else Vector2i(-1, -1)


func _adjacent_empty_non_solution_cell(game, start: Vector2i) -> Vector2i:
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate: Vector2i = start + delta
		if candidate.x < 0 or candidate.y < 0:
			continue
		if candidate.y >= int(game.current_level["rows"]) or candidate.x >= int(game.current_level["cols"]):
			continue
		if game._is_king_cell(candidate.y, candidate.x) or game._is_solution_cell(candidate.y, candidate.x):
			continue
		if game.cell_states[candidate.y][candidate.x] == "empty":
			return candidate
	return Vector2i(-1, -1)


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.05).timeout
	await process_frame
