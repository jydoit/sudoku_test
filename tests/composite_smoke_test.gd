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
	assert(composite["selectedRegionIds"].size() >= 1 and composite["selectedRegionIds"].size() <= 2, "Assembly should remove one or two regions")
	assert(composite["pieces"].size() >= 2, "Removed regions should split into multiple pieces")
	assert(composite["validLayouts"].size() >= 2, "The runtime generator should retain multiple valid color layouts for dynamic crown calibration")

	for piece in composite["pieces"]:
		assert(piece["cells"].size() >= 2, "Every assembly piece must contain at least two cells")
		assert(_cells_connected(piece["cells"]), "Every assembly piece must stay connected")

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
	game._save_game()
	game.queue_free()
	await process_frame
	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	assert(not game.home_composite_entry_active, "Restarting from the isolated experience should return to formal progress")
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
	assert(not game.assembly_view.visible, "Assembly view should leave after conversion")
	assert(not game._build_best_next_hint().is_empty(), "The generated crown phase should provide a formal X hint")
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


func _cells_connected(raw_cells: Array) -> bool:
	if raw_cells.is_empty():
		return false
	var allowed := {}
	for raw in raw_cells:
		allowed[Vector2i(int(raw[1]), int(raw[0]))] = true
	var queue: Array[Vector2i] = [allowed.keys()[0]]
	var visited := {queue[0]: true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if allowed.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited.size() == allowed.size()
