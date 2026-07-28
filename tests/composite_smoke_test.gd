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

	_test_difficulty_region_selection()
	_test_clue_selection()
	_test_difficulty_builds(levels)
	var template_families: Array = CompositeLevelScript.SHAPE_TEMPLATES.map(func(template: Dictionary) -> String:
		return str(template.get("family", ""))
	)
	assert(template_families.has("z"), "The assembly template pool should include Z pieces")
	assert(template_families.has("rectangle"), "The assembly template pool should include the 2x2 square")

	var layout: Dictionary = composite["validLayouts"][0]
	var placements: Dictionary = layout["placements"].duplicate(true)
	assert(CompositeLevelScript.matching_layout(composite, placements)["signature"] == layout["signature"], "A complete approved placement should resolve to its final layout")
	for piece in composite["pieces"]:
		var piece_id := int(piece["pieceId"])
		assert(not CompositeLevelScript.allowed_origins(composite, {}, piece_id).is_empty(), "Every piece should expose at least one legal starting placement")

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
	assert(game.home_composite_round == 1 and game.level_label.text == game._t("拼块挑战 · 第 %d 局", [1]), "The isolated entry should not display a fake formal level number")
	assert(not game.level_select_button.visible, "The isolated block challenge should hide formal level selection")
	var first_home_seed := int(game.composite_data.get("seed", 0))
	game._start_next_home_composite_round()
	await process_frame
	assert(game.home_composite_round == 2 and game.level_label.text == game._t("拼块挑战 · 第 %d 局", [2]), "The home challenge should continue into a numbered next round")
	assert(game._is_assembly_phase() and int(game.composite_data.get("seed", 0)) != first_home_seed, "The next round should generate a different assembly")
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


func _test_clue_selection() -> void:
	var square: Array = []
	for row in range(5):
		for col in range(5):
			square.append(Vector2i(col, row))
	var simple_rng := RandomNumberGenerator.new()
	simple_rng.seed = 23
	var simple_clue: Vector2i = CompositeLevelScript._select_clue_cell(square, "simple", simple_rng)
	assert(simple_clue.x == 0 or simple_clue.x == 4 or simple_clue.y == 0 or simple_clue.y == 4, "Simple clue should come from the region edge")

	var hard_interior_count := 0
	var medium_interior_count := 0
	for seed in range(200):
		var medium_rng := RandomNumberGenerator.new()
		medium_rng.seed = seed
		var medium_clue: Vector2i = CompositeLevelScript._select_clue_cell(square, "medium", medium_rng)
		if medium_clue.x > 0 and medium_clue.x < 4 and medium_clue.y > 0 and medium_clue.y < 4:
			medium_interior_count += 1
		var hard_rng := RandomNumberGenerator.new()
		hard_rng.seed = seed
		var hard_clue: Vector2i = CompositeLevelScript._select_clue_cell(square, "hard", hard_rng)
		if hard_clue.x > 0 and hard_clue.x < 4 and hard_clue.y > 0 and hard_clue.y < 4:
			hard_interior_count += 1
	assert(medium_interior_count >= 60 and medium_interior_count <= 100, "Medium clues should use surrounded cells about 40 percent of the time")
	assert(hard_interior_count >= 120 and hard_interior_count <= 160, "Hard clues should use surrounded cells about 70 percent of the time")


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
