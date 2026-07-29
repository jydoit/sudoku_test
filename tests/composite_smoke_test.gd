extends SceneTree

const LevelStoreScript = preload("res://scripts/level_store.gd")
const CompositeLevelScript = preload("res://scripts/composite_level.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")
const SAVE_PATH := "user://color_queens_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_save := ""
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_PATH)
	var levels := LevelStoreScript.load_levels()
	var composite: Dictionary = {}
	var fallback_composite: Dictionary = {}
	var level: Dictionary = {}
	var level_index := -1
	var checked_levels := 0
	for candidate_index in range(levels.size()):
		var candidate: Dictionary = levels[candidate_index]
		if int(candidate.get("rows", 0)) < 6:
			continue
		checked_levels += 1
		for seed_offset in range(12):
			var candidate_composite: Dictionary = CompositeLevelScript.build(candidate, 20260722 + seed_offset)
			if candidate_composite.is_empty():
				continue
			if fallback_composite.is_empty():
				fallback_composite = candidate_composite
				level = candidate
				level_index = candidate_index
			if candidate_composite["validLayouts"].size() >= 2:
				composite = candidate_composite
				level = candidate
				level_index = candidate_index
				break
		if not composite.is_empty() or checked_levels >= 12:
			break
	if composite.is_empty():
		composite = fallback_composite
	assert(not level.is_empty(), "Composite test requires a 6x6 or larger level")
	assert(not composite.is_empty(), "A supported level should produce a composite assembly")
	assert(int(composite["rows"]) >= 6, "Composite gameplay must start at 6x6")
	var composite_difficulty := str(composite.get("difficulty", "medium"))
	var selected_count: int = composite["selectedRegionIds"].size()
	if composite_difficulty == "simple":
		assert(selected_count == 1 or selected_count == 2, "Simple assembly should use one or two color regions")
	elif composite_difficulty == "medium":
		assert(selected_count == 2, "Medium assembly should use exactly two color regions")
	else:
		assert(selected_count == 3, "Hard assembly should use exactly three color regions")
	assert(composite["pieces"].size() >= selected_count, "Every selected color region should contribute at least one piece")
	assert(composite["validLayouts"].size() >= 1, "The runtime generator should retain at least one uniquely solvable color layout")
	assert(composite.get("clueCells", []).size() == composite["selectedRegionIds"].size(), "Each selected color region should retain one locked clue cell")
	assert(not composite.get("constructionIndexSet", {}).is_empty(), "Generated assembly data should cache its construction-cell index set")
	var construction_keys := {}
	for raw in composite["constructionCells"]:
		construction_keys["%d,%d" % [int(raw[0]), int(raw[1])]] = true
	var clue_region_ids := {}
	for raw in composite.get("clueCells", []):
		var clue_key := "%d,%d" % [int(raw[0]), int(raw[1])]
		assert(not construction_keys.has(clue_key), "Locked color clues must stay outside the construction wells")
		clue_region_ids[int(composite["baseRegions"][int(raw[0])][int(raw[1])])] = true
	for region_id in composite["selectedRegionIds"]:
		assert(clue_region_ids.has(int(region_id)), "Every construction color should remain visible as a board clue")

	for piece in composite["pieces"]:
		assert(piece["cells"].size() >= 1, "Three failed cuts may fall back to a one-cell assembly piece")
		assert(
			CompositeLevelScript._cells_connected(CompositeLevelScript._arrays_to_cells(piece["cells"])),
			"Every generated assembly piece must be orthogonally connected"
		)
		assert(piece.has("candidateOrigins") and piece.has("candidateCellIndices"), "Every piece should cache its geometric origins and occupied indices")
		assert(
			piece["candidateOrigins"] == CompositeLevelScript._compute_piece_candidate_origins(piece, composite["constructionCells"]),
			"Cached origins must match the uncached geometric calculation"
		)

	_test_difficulty_region_selection()
	_test_clue_selection()
	_test_partial_deadlock_connectivity()
	_test_shared_placement_evaluation()
	_test_difficulty_builds(levels)
	_test_reported_level_split(levels)
	var template_families: Array = CompositeLevelScript.SHAPE_TEMPLATES.map(func(template: Dictionary) -> String:
		return str(template.get("family", ""))
	)
	assert(template_families.has("z"), "The assembly template pool should include Z pieces")
	assert(template_families.has("rectangle"), "The assembly template pool should include the 2x2 square")

	var layout: Dictionary = composite["validLayouts"][0]
	var placements: Dictionary = layout["placements"].duplicate(true)
	assert(CompositeLevelScript.matching_layout(composite, placements)["signature"] == layout["signature"], "A complete approved placement should resolve to its final layout")
	assert(CompositeLevelScript.has_valid_completion(composite, {}), "A fresh assembly should have at least one valid completion")
	var empty_evaluation: Dictionary = CompositeLevelScript.evaluate_placement_state(composite, {}, true)
	assert(bool(empty_evaluation.get("valid", false)) and not bool(empty_evaluation.get("deadlocked", true)), "One shared evaluation should accept the fresh assembly")
	assert(empty_evaluation.get("allowedByPiece", {}).size() == composite["pieces"].size(), "One shared evaluation should return origins for every piece")
	var complete_evaluation: Dictionary = CompositeLevelScript.evaluate_placement_state(composite, placements, true)
	assert(
		str(complete_evaluation.get("layout", {}).get("signature", "")) == str(layout["signature"]),
		"A complete shared evaluation should return the final layout without a second solve"
	)
	for piece in composite["pieces"]:
		var piece_id := int(piece["pieceId"])
		var geometric_origins: Array = CompositeLevelScript._piece_candidate_origins(piece, composite["constructionCells"])
		var open_origins: Array = CompositeLevelScript.allowed_origins(composite, {}, piece_id)
		assert(open_origins.size() == geometric_origins.size(), "An empty board should allow every origin that geometrically fits the construction space")

	var packed: PackedScene = load("res://scenes/main.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.tutorial_completed = true
	game.tutorial_started = false
	game.in_tutorial = false
	game.composite_tutorial_seen = true
	if int(game.current_level.get("levelId", -1)) < 0:
		game._load_level(0, false, LevelDirectorScript.manual_schedule_for_level(game.levels, 0, 1))
	var formal_index: int = game.current_level_index
	var formal_display: int = game.player_level_number
	var formal_states: Array = game.cell_states.duplicate(true)
	var formal_coins: int = game.coin_count
	assert(game.home_composite_button != null, "Home should expose a block gameplay entry")
	game._start_home_composite_flow()
	await process_frame
	assert(game.home_composite_entry_active, "Home block entry should start an isolated experience")
	assert(game._is_assembly_phase() and int(game.current_level.get("rows", 0)) == 6, "Home block entry should open a 6x6 assembly")
	assert(not game.home_composite_progress_snapshot.is_empty(), "Home block entry should snapshot formal progress")
	assert(game.home_composite_round == 1 and str(game.composite_data.get("difficulty", "")) == "simple", "The first debug round should use the Simple assembly pattern")
	assert([1, 2].has(game.composite_data.get("selectedRegionIds", []).size()), "The Simple debug pattern should select one or two construction colors")
	assert(game.composite_data.get("validLayouts", []).size() == 1, "The debug flow should stop after its first legal layout")
	assert(not game.active_schedule.has("assemblyPrebuiltData"), "Transient prebuilt assembly data must be consumed before the schedule is saved")
	assert(game.level_label.text == game._t("拼块挑战 · 第 %d 局", [1]), "The isolated entry should display its round number")
	assert(game.assembly_stage_label.text == "SIMPLE", "The compact stage badge should display the Simple debug pattern")
	assert(game.level_label.get_parent().get_combined_minimum_size().x <= 527.0, "The assembly header must fit the 539px viewport after safe margins")
	assert(not game.level_select_button.visible, "The isolated block challenge should hide formal level selection")
	var first_home_seed := int(game.composite_data.get("seed", 0))
	game._start_next_home_composite_round()
	await process_frame
	assert(game.home_composite_round == 2 and str(game.composite_data.get("difficulty", "")) == "medium", "The second debug round should use the Medium assembly pattern")
	assert(game.composite_data.get("selectedRegionIds", []).size() == 2, "The Medium debug pattern should select exactly two construction colors")
	assert(game.level_label.text == game._t("拼块挑战 · 第 %d 局", [2]) and game.assembly_stage_label.text == "MEDIUM", "The second round should display its compact Medium pattern")
	assert(game._is_assembly_phase() and int(game.composite_data.get("seed", 0)) != first_home_seed, "The next round should generate a different assembly")
	game._start_next_home_composite_round()
	await process_frame
	assert(game.home_composite_round == 3 and str(game.composite_data.get("difficulty", "")) == "hard", "The third debug round should use the Hard assembly pattern")
	assert(game.composite_data.get("selectedRegionIds", []).size() == 3, "The Hard debug pattern should select exactly three construction colors")
	assert(game.composite_data.get("validLayouts", []).size() == 1, "The Hard debug pattern should not run the full multi-layout search")
	assert(game.level_label.text == game._t("拼块挑战 · 第 %d 局", [3]) and game.assembly_stage_label.text == "HARD", "The third round should display its compact Hard pattern")
	assert(game._home_composite_pattern_for_round(4) == "simple", "The debug difficulty sequence should loop back to Simple after Hard")
	_test_tray_horizontal_scroll(game.assembly_view)
	_test_tray_return_slot_focus(game.assembly_view)
	var history_layout: Dictionary = game.composite_data["validLayouts"][0]
	var history_piece_id := int(game.composite_data["pieces"][0]["pieceId"])
	var history_origin: Array = history_layout["placements"][str(history_piece_id)].duplicate()
	var history_slot_index: int = game.composite_tray_slots.find(history_piece_id)
	assert(history_slot_index >= 0, "An unplaced piece should occupy one persistent tray slot")
	game._on_assembly_placement_requested(history_piece_id, history_origin)
	assert(game.composite_placements.has(str(history_piece_id)), "The history regression fixture should contain an unfinished placed piece")
	assert(int(game.composite_tray_slots[history_slot_index]) == -1, "Placing a piece should leave its previous tray slot empty")
	game._on_assembly_return_requested(history_piece_id, history_slot_index)
	assert(not game.composite_placements.has(str(history_piece_id)), "Releasing a board piece over the focused tray slot should return it")
	assert(int(game.composite_tray_slots[history_slot_index]) == history_piece_id, "The returned piece should belong to the focused empty slot")
	game._on_assembly_placement_requested(history_piece_id, history_origin)
	var saved_tray_slots: Array = game.composite_tray_slots.duplicate()
	game._save_game()
	game.queue_free()
	await process_frame
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	assert(not game.home_composite_entry_active and game.home_composite_round == 0, "Restarting from the isolated experience should return to formal progress")
	assert(game.current_level_index == formal_index and game.player_level_number == formal_display, "Restarting should restore the formal level")
	assert(game.cell_states == formal_states and game.coin_count == formal_coins, "Restarting should restore the formal board and resources")
	assert(game._home_composite_history_is_valid(game.home_composite_history), "Restarting should retain a valid independent block-game history")
	assert(int(game.home_composite_history.get("round", 0)) == 3, "The independent block-game history should retain the latest round")
	assert(game.home_composite_button.text == game._t("拼块玩法 · 第 %d 局", [3]), "The home entry should display the resumable block-game round")
	game._start_home_composite_flow()
	await process_frame
	assert(game.home_composite_entry_active and game.home_composite_round == 3, "Re-entering block gameplay should resume the unfinished round instead of starting at round one")
	assert(game.composite_placements.get(str(history_piece_id), []) == history_origin, "Re-entering block gameplay should restore the unfinished piece placement")
	assert(game.composite_tray_slots == saved_tray_slots, "Re-entering block gameplay should restore empty and occupied tray slots")
	game._show_home()
	await process_frame
	assert(not game.home_composite_entry_active and game.current_level_index == formal_index, "Leaving the resumed block round should restore formal progress again")
	var unfinished_history: Dictionary = game.home_composite_history.duplicate(true)
	game.home_composite_history["isCompleted"] = true
	assert(game._home_composite_resume_round() == 4, "A completed saved block round should advance the next entry instead of replaying the completed round")
	game.home_composite_history = unfinished_history
	game.composite_tutorial_seen = false
	var schedule := LevelDirectorScript.manual_schedule_for_level(game.levels, level_index, 80)
	assert(bool(schedule.get("assemblyEnabled", false)), "A 6x6 milestone schedule should enable assembly")
	game._load_level(level_index, false, schedule)
	game._show_game()
	await process_frame
	assert(game._is_assembly_phase(), "Composite schedule should start in assembly")
	assert(game.composite_intro_running and game.assembly_view.input_locked, "The first composite level should start the flow animation")
	await game.assembly_view.intro_finished
	await process_frame
	assert(game.composite_tutorial_seen and not game.composite_intro_running, "Completing the first flow animation should persist its seen state")
	var saved_view_data: Dictionary = game.assembly_view.assembly_data
	var saved_view_allowed: Dictionary = game.assembly_view.allowed_by_piece
	var tall_piece := {
		"pieceId": 999,
		"regionId": 1,
		"cells": [[0, 0], [1, 0], [2, 0], [2, 1], [3, 0]]
	}
	game.assembly_view.assembly_data = {"pieces": [tall_piece]}
	game.assembly_view.allowed_by_piece = {"999": [[0, 0]]}
	game.assembly_view._drag_piece_id = 999
	game.assembly_view._drag_source = "tray"
	var snap_geometry: Dictionary = game.assembly_view._board_geometry()
	var snap_cell_size: float = float(snap_geometry["cellSize"])
	var snap_board_rect: Rect2 = snap_geometry["rect"]
	var snap_board_origin: Vector2 = snap_board_rect.position
	var exact_pointer := snap_board_origin + Vector2(snap_cell_size, snap_cell_size * 4.72)
	assert(game.assembly_view._origin_for_pointer(exact_pointer) == Vector2i.ZERO, "A four-cell-tall irregular piece should snap where it is visually aligned")
	var nearby_pointer := exact_pointer + Vector2(snap_cell_size * 0.70, -snap_cell_size * 0.40)
	assert(game.assembly_view._origin_for_pointer(nearby_pointer) == Vector2i.ZERO, "A nearby legal well should magnetically absorb the irregular piece")
	game.assembly_view.assembly_data = saved_view_data
	game.assembly_view.allowed_by_piece = saved_view_allowed
	game.assembly_view._drag_piece_id = -1
	game.assembly_view._drag_source = ""
	assert(game.assembly_view.visible, "Assembly view should replace the standard board")
	assert(not game.progress_row.visible, "Crown progress must stay hidden during assembly")
	assert(not game.clear_button.visible and not game.crown_find_button.visible and not game.hint_button.visible, "Crown tools must stay hidden during assembly")
	var hint_before: int = game.hint_count
	var crown_find_before: int = game.crown_find_count
	game._use_hint()
	game._use_crown_find()
	game._clear_board()
	assert(game.hint_count == hint_before and game.crown_find_count == crown_find_before, "Hidden assembly tools must not consume inventory")
	game._on_help()
	assert(game.help_tabs.current_tab == 1, "Assembly help should open the block gameplay tab")
	game.dialog_controller.hide_dialog(true)

	var runtime_layout: Dictionary = game.composite_data["validLayouts"][0]
	var runtime_pieces: Array = game.composite_data["pieces"]
	var first_piece_id := int(runtime_pieces[0]["pieceId"])
	game._on_assembly_placement_requested(first_piece_id, runtime_layout["placements"][str(first_piece_id)])
	assert(game.composite_placements.has(str(first_piece_id)), "Placed assembly state should be recorded")
	game._save_game()
	game.queue_free()
	await process_frame

	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	assert(game._is_assembly_phase(), "Restart should resume the assembly phase")
	assert(game.composite_placements.has(str(first_piece_id)), "Restart should restore placed blocks")
	assert(game.composite_placement_history.back() == first_piece_id, "Restart should restore the order used for automatic deadlock revival")
	var revive_origin: Array = game.composite_placements[str(first_piece_id)].duplicate()
	game.coin_count = 1000
	var revive_price: int = game._current_tool_price("revive")
	game.composite_deadlocked = true
	game._show_composite_deadlock()
	assert(game.result_overlay_mode == "assembly_deadlock" and game.assembly_view.input_locked, "A block deadlock should lock input and show the recovery page")
	game._revive_composite_deadlock()
	assert(not game.composite_placements.has(str(first_piece_id)), "Coin revival should automatically return the last placed piece")
	assert(game.coin_count == 1000 - revive_price and not game.composite_deadlocked, "Coin revival should charge the current revive price and clear the deadlock")
	game._on_assembly_placement_requested(first_piece_id, revive_origin)
	game.composite_deadlocked = true
	game._show_composite_deadlock()
	game._restart_composite_round_from_deadlock()
	await process_frame
	assert(game._is_assembly_phase() and game.composite_placements.is_empty(), "Restarting a block deadlock should reset the current assembly round")
	runtime_layout = game.composite_data["validLayouts"][0]
	for piece in game.composite_data["pieces"]:
		var piece_id := int(piece["pieceId"])
		game._on_assembly_placement_requested(piece_id, runtime_layout["placements"][str(piece_id)])
	await create_timer(1.05).timeout
	assert(game.composite_phase == "crown", "Completing the construction zone should enter the crown phase")
	assert(game.progress_row.visible and game.clear_button.visible and game.crown_find_button.visible and game.hint_button.visible, "Crown UI should return after the transition")
	assert(not game.hint_button.disabled, "Formal Hint must be re-enabled after leaving the assembly phase")
	assert(not game.assembly_view.visible, "Assembly view should leave after conversion")
	assert(not game._build_best_next_hint().is_empty(), "The generated crown phase should provide a formal X hint")
	game.hint_count = 1
	game._update_hint_button()
	game._use_hint()
	assert(game.hint_count == 0 and not game.board.guide_cells.is_empty(), "Formal Hint should remain usable and draw its X-only guide after conversion")
	var final_signature := str(game.active_schedule.get("assemblyLayoutSignature", ""))
	assert(not final_signature.is_empty(), "Final assembly signature should be locked")
	game._save_game()
	game.queue_free()
	await process_frame

	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	assert(game.composite_phase == "crown", "Restart after conversion should stay in crown mode")
	assert(str(game.active_schedule.get("assemblyLayoutSignature", "")) == final_signature, "Restart should keep the same generated color layout")
	game.queue_free()
	await process_frame

	if had_save:
		var restore_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		restore_file.store_string(previous_save)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	print("COMPOSITE SMOKE TEST PASSED: generation, %d valid layouts, assembly UI, transition and resume" % composite["validLayouts"].size())
	quit(0)


func _test_difficulty_region_selection() -> void:
	var regions := [
		[0, 0, 0, 0, 1, 1],
		[0, 0, 0, 0, 1, 1],
		[2, 2, 2, 3, 3, 3],
		[2, 2, 2, 3, 3, 3],
		[4, 4, 4, 4, 5, 5],
		[4, 4, 4, 4, 5, 5]
	]
	var region_cells := {}
	for row in range(regions.size()):
		for col in range(regions[row].size()):
			var region_id := int(regions[row][col])
			if not region_cells.has(region_id):
				region_cells[region_id] = []
			region_cells[region_id].append(Vector2i(col, row))

	var single_count := 0
	for seed in range(400):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var selected: Array = CompositeLevelScript._select_regions(region_cells, regions, rng, "simple")
		if selected.size() == 1:
			single_count += 1
			assert([0, 4].has(int(selected[0])), "Simple single-region mode should select a largest region")
		else:
			assert(selected.has(3) and (selected.has(1) or selected.has(5)), "Simple two-region mode should select a smallest adjacent legal pair")
	assert(single_count >= 180 and single_count <= 260, "Simple region count should stay near the requested 55/45 distribution")

	var medium_rng := RandomNumberGenerator.new()
	medium_rng.seed = 17
	assert(CompositeLevelScript._select_regions(region_cells, regions, medium_rng, "medium").size() == 2, "Medium must select two adjacent regions")
	var hard_rng := RandomNumberGenerator.new()
	hard_rng.seed = 17
	assert(CompositeLevelScript._select_regions(region_cells, regions, hard_rng, "hard").size() == 3, "Hard must select three adjacent regions")
	assert(CompositeLevelScript._desired_piece_count(15, "simple") == 4, "Simple piece count should use the 0.5 factor")
	assert(CompositeLevelScript._desired_piece_count(15, "medium") == 5, "Medium piece count should use the 0.6 factor")
	assert(CompositeLevelScript._desired_piece_count(15, "hard") == 6, "Hard piece count should use the 0.8 factor")
	assert(CompositeLevelScript._desired_piece_count(5, "simple") == 2, "Small simple regions should still split when their movable area supports two pieces")


func _test_clue_selection() -> void:
	var regions := [
		[1, 1, 2, 2],
		[1, 1, 2, 3],
		[4, 1, 1, 3],
		[4, 4, 3, 3]
	]
	var region_cells: Array = []
	for row in range(regions.size()):
		for col in range(regions[row].size()):
			if int(regions[row][col]) == 1:
				region_cells.append(Vector2i(col, row))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var clue: Vector2i = CompositeLevelScript._select_clue_cell(region_cells, regions, 1, rng)
	assert(CompositeLevelScript._row_column_different_color_max(Vector2i(2, 2), regions, 1) == 3, "Clue score should use max(row different colors, column different colors), not their sum")
	assert(clue == Vector2i(2, 2), "Clue selection should prefer the edge cell with the highest row-or-column different-color count")
	assert(not CompositeLevelScript._is_articulation_cell(region_cells, clue), "Selected clue cells must not disconnect their color region")

	var line_regions := [
		[1, 1, 1],
		[2, 2, 2],
		[3, 3, 3]
	]
	var line_cells := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert(CompositeLevelScript._is_articulation_cell(line_cells, Vector2i(1, 0)), "The middle of a three-cell line should be recognized as an articulation point")
	var line_rng := RandomNumberGenerator.new()
	line_rng.seed = 7
	var safe_line_clue: Vector2i = CompositeLevelScript._select_clue_cell(line_cells, line_regions, 1, line_rng)
	assert(safe_line_clue != Vector2i(1, 0), "Clue selection must exclude articulation points before applying the row-or-column score")

	var disconnected_remainder := [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(3, 0), Vector2i(3, 1)
	]
	var split_rng := RandomNumberGenerator.new()
	split_rng.seed = 11
	assert(
		CompositeLevelScript._split_region_from_clue(disconnected_remainder, Vector2i(-1, 0), 1, split_rng, "simple", false).is_empty(),
		"A disconnected final remainder must be rejected instead of becoming one irregular piece"
	)


func _test_difficulty_builds(levels: Array) -> void:
	for difficulty in ["simple", "medium", "hard"]:
		var generated: Dictionary = {}
		for level in levels:
			if int(level.get("rows", 0)) < 6 or CompositeLevelScript._normalize_difficulty(str(level.get("difficulty", ""))) != difficulty:
				continue
			for seed_offset in range(18):
				generated = CompositeLevelScript.build(level, 20260728 + seed_offset)
				if not generated.is_empty():
					break
			if not generated.is_empty():
				break
		assert(not generated.is_empty(), "Every composite difficulty should generate on a supported default level")
		var expected_counts := {"medium": 2, "hard": 3}
		if difficulty == "simple":
			assert([1, 2].has(generated["selectedRegionIds"].size()), "Simple generated levels should use one or two regions")
		else:
			assert(generated["selectedRegionIds"].size() == int(expected_counts[difficulty]), "Generated region count should match the composite difficulty")
		for region_id in generated["selectedRegionIds"]:
			var piece_count := 0
			for piece in generated["pieces"]:
				if int(piece["regionId"]) == int(region_id):
					piece_count += 1
			assert(piece_count >= 1, "Every generated construction color should provide at least one movable piece")


func _test_reported_level_split(levels: Array) -> void:
	var reported_level: Dictionary = {}
	var factor_level: Dictionary = {}
	for level in levels:
		if int(level.get("levelId", -1)) == 71:
			reported_level = level
		elif int(level.get("levelId", -1)) == 73:
			factor_level = level
	assert(not reported_level.is_empty(), "The reported composite regression level should exist")
	var generated: Dictionary = CompositeLevelScript.build(reported_level, 91268854)
	assert(not generated.is_empty(), "The reported composite seed should remain reproducible")
	assert(generated["selectedRegionIds"].size() == 2, "The reported simple seed should select two construction colors")
	for region_id in generated["selectedRegionIds"]:
		var region_piece_sizes: Array = []
		for piece in generated["pieces"]:
			if int(piece["regionId"]) == int(region_id):
				region_piece_sizes.append(piece["cells"].size())
		assert(region_piece_sizes.size() == 2, "A five-cell construction color must split into two pieces instead of one full-region piece")
		for piece_size in region_piece_sizes:
			assert(int(piece_size) >= 2, "The reported five-cell construction colors should split without singleton fallback")
	assert(not factor_level.is_empty(), "The reported factor regression level should exist")
	var factor_generated: Dictionary = CompositeLevelScript.build(factor_level, 93284698)
	assert(not factor_generated.is_empty(), "The reported factor seed should remain reproducible")
	var largest_piece_count := 0
	for region_id in factor_generated["selectedRegionIds"]:
		var movable_cell_count := 0
		for raw_cell in factor_generated["constructionCells"]:
			if int(factor_generated["baseRegions"][int(raw_cell[0])][int(raw_cell[1])]) == int(region_id):
				movable_cell_count += 1
		var actual_piece_count := 0
		for piece in factor_generated["pieces"]:
			if int(piece["regionId"]) == int(region_id):
				actual_piece_count += 1
		var expected_piece_count: int = CompositeLevelScript._desired_piece_count(movable_cell_count, "simple")
		assert(actual_piece_count == expected_piece_count, "The reported large simple region should follow the 0.5 piece-count factor")
		largest_piece_count = maxi(largest_piece_count, actual_piece_count)
	assert(largest_piece_count >= 4, "The reported large simple region must no longer be capped at three pieces")


func _test_partial_deadlock_connectivity() -> void:
	var construction_cells := [
		[0, 1], [0, 2],
		[1, 0], [1, 1], [1, 2],
		[2, 0], [2, 1], [2, 2]
	]
	var data := {
		"rows": 3,
		"cols": 3,
		"baseRegions": [
			[1, 9, 9],
			[9, 9, 9],
			[9, 9, 9]
		],
		"selectedRegionIds": [1],
		"constructionCells": construction_cells,
		"pieces": [
			{"pieceId": 0, "regionId": 1, "cells": [[0, 0]]},
			{"pieceId": 1, "regionId": 2, "cells": [[0, 0], [0, 1], [0, 2]]},
			{"pieceId": 2, "regionId": 1, "cells": [[0, 0]]}
		]
	}
	var open_bridge := {"0": [2, 2]}
	assert(
		CompositeLevelScript.has_valid_completion(data, open_bridge),
		"Unoccupied cells must remain available as arbitrary-color bridges between placed same-color cells"
	)
	var blocked_bridge := {
		"0": [2, 2],
		"1": [1, 0]
	}
	assert(
		not CompositeLevelScript.has_valid_completion(data, blocked_bridge),
		"Placed different-color blocks that cut every blank path should produce a real connectivity deadlock"
	)


func _test_shared_placement_evaluation() -> void:
	var data := {
		"rows": 1,
		"cols": 3,
		"baseRegions": [[1, 1, 1]],
		"selectedRegionIds": [1],
		"constructionCells": [[0, 0], [0, 1], [0, 2]],
		"pieces": [
			{"pieceId": 0, "regionId": 1, "cells": [[0, 0], [0, 1]]},
			{"pieceId": 1, "regionId": 1, "cells": [[0, 0]]}
		],
		"validLayouts": []
	}
	CompositeLevelScript._prepare_runtime_cache(data)
	var partial := {"0": [0, 0]}
	var evaluation: Dictionary = CompositeLevelScript.evaluate_placement_state(data, partial, true)
	assert(bool(evaluation.get("valid", false)), "A multi-cell piece should count as one placed piece during occupancy validation")
	assert(not bool(evaluation.get("deadlocked", true)), "The remaining unit piece should keep the partial state playable")
	assert(
		evaluation.get("allowedByPiece", {}).get("1", []) == [[0, 2]],
		"The shared occupancy should exclude cells occupied by another piece"
	)
	var overlap := {"0": [0, 0], "1": [0, 1]}
	assert(
		not bool(CompositeLevelScript.evaluate_placement_state(data, overlap, true).get("valid", true)),
		"One shared evaluation must reject overlapping pieces before mutating gameplay state"
	)


func _test_tray_horizontal_scroll(view) -> void:
	var saved_data: Dictionary = view.assembly_data
	var saved_slots: Array = view.tray_slot_piece_ids.duplicate()
	var overflow_pieces: Array = []
	for piece_id in range(7):
		overflow_pieces.append({
			"pieceId": piece_id,
			"regionId": 1,
			"cells": [[0, 0], [0, 1]]
		})
	view.assembly_data = {"pieces": overflow_pieces}
	view.tray_slot_piece_ids = [0, 1, 2, 3, 4, 5, 6]
	view.active = true
	view.visible = true
	view.input_locked = false
	view.tray_scroll = 0.0
	assert(view._tray_max_scroll() > 0.0, "The tray scroll regression fixture must overflow horizontally")

	var tray_center: Vector2 = view._tray_rect().get_center()
	view._pointer_pressed(tray_center, 7)
	view._pointer_moved(tray_center + Vector2(-44.0, -8.0), 7)
	assert(view._interaction_mode == "scroll" and view.tray_scroll > 0.0, "A slightly diagonal left swipe over a tray piece should scroll instead of starting a piece drag")
	view._pointer_released(tray_center + Vector2(-44.0, -8.0), 7)

	view.tray_scroll = 0.0
	var pan := InputEventPanGesture.new()
	pan.position = view.get_global_transform_with_canvas() * tray_center
	pan.delta = Vector2(-1.0, 0.0)
	view._input(pan)
	assert(view.tray_scroll > 0.0, "A Mac trackpad pan gesture over an overflowing tray should scroll it")
	view.assembly_data = saved_data
	view.tray_slot_piece_ids = saved_slots
	view.tray_scroll = 0.0
	view.queue_redraw()


func _test_tray_return_slot_focus(view) -> void:
	var saved_data: Dictionary = view.assembly_data
	var saved_placements: Dictionary = view.placements.duplicate(true)
	var saved_slots: Array = view.tray_slot_piece_ids.duplicate()
	var saved_scroll: float = view.tray_scroll
	var pieces: Array = []
	for piece_id in range(7):
		pieces.append({
			"pieceId": piece_id,
			"regionId": 1,
			"trayIndex": piece_id,
			"cells": [[0, 0]]
		})
	view.assembly_data = {"pieces": pieces}
	view.placements = {"0": [0, 0], "3": [0, 1]}
	view.tray_slot_piece_ids = [1, 2, -1, -1, 4, 5, 6]
	view.tray_scroll = view._tray_max_scroll()
	view._drag_piece_id = 3
	view._drag_source = "board"
	view._return_slot_index = -1
	view._prepare_return_slot_focus()
	assert(view._return_slot_index == 2, "Returning a board piece should choose the first empty tray slot from the head")
	view.focus_tray_slot(view._return_slot_index, false)
	assert(view.tray_scroll < view._tray_max_scroll(), "The tray should move away from its tail to focus the selected empty slot")
	view.assembly_data = saved_data
	view.placements = saved_placements
	view.tray_slot_piece_ids = saved_slots
	view.tray_scroll = saved_scroll
	view._drag_piece_id = -1
	view._drag_source = ""
	view._return_slot_index = -1
	view.queue_redraw()
