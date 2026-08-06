extends SceneTree

const LevelStoreScript = preload("res://scripts/level_store.gd")
const CompositeLevelScript = preload("res://scripts/composite_level.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")
const CompositeLevelDirectorScript = preload("res://scripts/composite_level_director.gd")
const CompositeLevelStoreScript = preload("res://scripts/composite_level_store.gd")
const CompositeCoinPolicyScript = preload("res://scripts/composite_coin_policy.gd")
const SAVE_PATH := "user://color_queens_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var previous_save := ""
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_PATH)
	var levels := LevelStoreScript.load_levels()
	_test_composite_coin_policy()
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
	game.home_composite_entry_active = false
	game.home_composite_progress_snapshot.clear()
	game.home_composite_history.clear()
	game.composite_director_progress.clear()
	game.composite_coin_progress = CompositeCoinPolicyScript.default_progress()
	if int(game.current_level.get("levelId", -1)) < 0:
		game._load_level(0, false, LevelDirectorScript.manual_schedule_for_level(game.levels, 0, 1))
	var composite_unlock_display := LevelDirectorScript.minimum_display_for_size(6)
	game.player_level_number = composite_unlock_display - 1
	game.active_schedule["displayLevel"] = game.player_level_number
	game.is_completed = false
	game._update_home()
	assert(not game.home_composite_button.disabled, "The locked block entry should remain clickable after the tutorial")
	assert(game.home_composite_button.text == game._t("拼块玩法 · 第 %d 关解锁", [composite_unlock_display]), "The locked block entry should expose the required formal level")
	var snapshot_before_locked_tap: Dictionary = game.formal_progress_snapshot.duplicate(true)
	game._start_home_composite_flow()
	await process_frame
	assert(game.dialog_controller.is_dialog_open("home_composite_locked"), "Tapping the locked block entry should open its requirement dialog")
	assert(not game.home_composite_entry_active, "A locked block entry must not create an isolated gameplay session")
	assert(game.formal_progress_snapshot == snapshot_before_locked_tap, "A locked entry must not mutate the formal progress snapshot")
	game.dialog_controller.hide_dialog(true)
	game.player_level_number = LevelDirectorScript.minimum_display_for_size(6)
	game.active_schedule["displayLevel"] = game.player_level_number
	game._update_home()
	assert(game._home_composite_is_unlocked(), "The home block entry should unlock with the ordinary 6x6 size condition")
	var formal_index: int = game.current_level_index
	var formal_display: int = game.player_level_number
	var formal_states: Array = game.cell_states.duplicate(true)
	var formal_coins: int = game.coin_count
	assert(game.home_composite_button != null, "Home should expose a block gameplay entry")
	_test_composite_director_model(game.levels, game.composite_levels)
	game._start_home_composite_flow()
	await process_frame
	assert(game.home_composite_entry_active, "Home block entry should start an isolated experience")
	assert(game._is_assembly_phase() and int(game.current_level.get("rows", 0)) == 6, "Home block entry should open a 6x6 assembly")
	assert(not game.home_composite_progress_snapshot.is_empty(), "Home block entry should snapshot formal progress")
	var first_pattern := str(game.composite_data.get("difficulty", ""))
	assert(game.home_composite_round == 1 and CompositeLevelDirectorScript.PATTERNS.has(first_pattern), "The first block round should sample a supported assembly pattern")
	assert(is_equal_approx(float(game.active_schedule.get("compositeExplorationProbability", 0.0)), 0.50), "A cold block model should start with 50% random exploration")
	assert(["random_exploration", "posterior_multinomial"].has(str(game.active_schedule.get("compositePatternSelectionMode", ""))), "The schedule should expose its pattern selection branch")
	assert(str(game.active_schedule.get("compositeBaseDifficultyClass", "")) == str(game.current_level.get("difficulty", "")), "The block director should retain the ordinary recommendation difficulty class")
	assert(game.composite_data.get("validLayouts", []).size() == 1, "The debug flow should stop after its first legal layout")
	assert(not game.active_schedule.has("assemblyPrebuiltData"), "Transient prebuilt assembly data must be consumed before the schedule is saved")
	assert(game.level_label.text == game._t("拼块挑战 · 第 %d 局", [1]), "The isolated entry should display its round number")
	assert(game.assembly_stage_label.text == first_pattern.to_upper(), "The compact stage badge should display the sampled pattern")
	assert(game.level_label.get_parent().get_combined_minimum_size().x <= 527.0, "The assembly header must fit the 539px viewport after safe margins")
	assert(not game.level_select_button.visible, "The isolated block challenge should hide formal level selection")
	var first_home_seed := int(game.composite_data.get("seed", 0))
	game._start_next_home_composite_round()
	await process_frame
	var second_pattern := str(game.composite_data.get("difficulty", ""))
	assert(game.home_composite_round == 2 and CompositeLevelDirectorScript.PATTERNS.has(second_pattern), "The second block round should sample a supported assembly pattern")
	assert(game.level_label.text == game._t("拼块挑战 · 第 %d 局", [2]) and game.assembly_stage_label.text == second_pattern.to_upper(), "The second round should display its sampled pattern")
	assert(game._is_assembly_phase() and int(game.composite_data.get("seed", 0)) > 0 and first_home_seed > 0, "Every recommended round should load an offline assembly seed")
	game._start_next_home_composite_round()
	await process_frame
	var third_pattern := str(game.composite_data.get("difficulty", ""))
	assert(game.home_composite_round == 3 and CompositeLevelDirectorScript.PATTERNS.has(third_pattern), "The third block round should sample a supported assembly pattern")
	assert(int(game.composite_coin_progress.get("dailyFreeRoundsUsed", 0)) == 3, "Starting three new block rounds should consume three daily free entries")
	assert(game.coin_count == formal_coins, "The first five daily block rounds should not deduct entry coins")
	game._play_coin_deduction_animation(10, 8, 2)
	await process_frame
	assert(game.coin_delta_panel != null and game.coin_delta_panel.visible, "A paid block entry should show a floating coin deduction indicator")
	assert(game.coin_delta_label.text == "−2", "The entry animation should expose the exact deducted amount")
	await create_timer(0.85).timeout
	assert(game.coin_label.text == "8" and not game.coin_delta_panel.visible, "The level coin balance should roll down and finish at the deducted balance")
	game._update_coin_label()
	game.localization.set_locale("en")
	assert(game._composite_result_coin_text(2, 0, false) == "Daily free round · No entry coins deducted\nCompletion reward: 2 coins", "A free block result should clearly state that no entry coins were deducted")
	assert(game._composite_result_coin_text(4, 2, true) == "Entry: -2 coins · Reward: +4 coins\nNet change: +2 coins", "A paid block result should clearly separate entry cost, reward, and net change")
	assert(game.composite_data.get("validLayouts", []).size() == 1, "Recommended offline data should contain one approved layout")
	assert(game.level_label.text == game._t("拼块挑战 · 第 %d 局", [3]) and game.assembly_stage_label.text == third_pattern.to_upper(), "The third round should display its sampled pattern")
	if game.composite_data.get("pieces", []).size() < 2:
		_load_multi_piece_home_fixture(game)
	_test_tray_horizontal_scroll(game.assembly_view)
	_test_tray_return_slot_focus(game.assembly_view)
	var history_layout: Dictionary = game.composite_data["validLayouts"][0]
	var history_piece_id := int(game.composite_data["pieces"][0]["pieceId"])
	var history_origin: Array = history_layout["placements"][str(history_piece_id)].duplicate()
	var history_slot_index: int = game.composite_tray_slots.find(history_piece_id)
	assert(history_slot_index >= 0, "An unplaced piece should occupy one persistent tray slot")
	game._on_assembly_placement_requested(history_piece_id, history_origin)
	assert(game.composite_placements.has(str(history_piece_id)), "The history regression fixture should contain an unfinished placed piece")
	var completed_slot_index: int = game.composite_tray_slots.find(history_piece_id)
	assert(completed_slot_index >= 0 and completed_slot_index >= history_slot_index, "Placed pieces should remain visible as completed slots after unplaced pieces")
	game._on_assembly_return_requested(history_piece_id, history_slot_index)
	assert(not game.composite_placements.has(str(history_piece_id)), "Releasing a board piece over the focused tray slot should return it")
	assert(game.composite_tray_slots.find(history_piece_id) >= 0, "A returned piece should be reinserted into the automatically sorted tray")
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
	assert(not game.opening_king_overlay.visible and not game.opening_king_reveal_pending, "Leaving block gameplay must not reveal the formal opening-king popup on the home screen")
	var unfinished_history: Dictionary = game.home_composite_history.duplicate(true)
	var saved_coin_progress: Dictionary = game.composite_coin_progress.duplicate(true)
	game.composite_coin_progress["dailyDate"] = game._today_string()
	game.composite_coin_progress["dailyFreeRoundsUsed"] = CompositeCoinPolicyScript.DAILY_FREE_ROUNDS
	game._update_home()
	assert(game.home_composite_button.text == game._t("拼块玩法 · 第 %d 局", [3]), "Resuming an unfinished round should remain free after the daily quota")
	game.home_composite_history["isCompleted"] = true
	assert(game._home_composite_resume_round() == 4, "A completed saved block round should advance the next entry instead of replaying the completed round")
	game._update_home()
	assert(game.home_composite_button.text == game._t("拼块玩法 · -%d 金币", [2]), "A new round after the daily quota should display its entry cost")
	game.home_composite_history = unfinished_history
	game.composite_coin_progress = saved_coin_progress
	var crown_history: Dictionary = unfinished_history.duplicate(true)
	var crown_state: Dictionary = crown_history["compositeState"].duplicate(true)
	crown_state["phase"] = "crown"
	crown_state["finalRegions"] = history_layout["regions"].duplicate(true)
	crown_state["finalSolution"] = history_layout["solution"].duplicate(true)
	crown_state["layoutSignature"] = str(history_layout["signature"])
	crown_history["compositeState"] = crown_state
	crown_history["activeSchedule"]["assemblyLayoutSignature"] = str(history_layout["signature"])
	crown_history["isCompleted"] = false
	game.home_composite_history = crown_history
	game._start_home_composite_flow()
	await process_frame
	assert(game.home_composite_entry_active and game.composite_mode and game.composite_phase == "crown", "A saved block round in crown phase should resume instead of showing a generation failure")
	game._show_home()
	await process_frame
	assert(not game.opening_king_overlay.visible and not game.opening_king_reveal_pending, "Returning home from a saved crown-phase block round must clear the opening-king popup")
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
	assert(game.clear_button.visible and game.crown_find_button.visible and game.hint_button.visible, "Assembly should keep the shared tool bar visible at the bottom")
	assert(game.assembly_tray_target.visible, "Assembly should show the waiting area above the board")
	assert(game.assembly_tray_target.get_global_rect().position.y < game.board.get_global_rect().position.y, "The waiting area should be positioned above the board")
	assert(game.action_bar.get_global_rect().position.y > game.board.get_global_rect().end.y - 4.0, "Assembly tools should remain below the board")
	var hint_before: int = game.hint_count
	var crown_find_before: int = game.crown_find_count
	var hint_target: Dictionary = game._assembly_hint_target()
	assert(not hint_target.is_empty(), "Assembly hint should find a target while the tray still has unplaced blocks")
	assert(not game.composite_placements.has(str(hint_target["pieceId"])), "Assembly hint should prefer an unplaced block")
	var hint_origin: Vector2i = hint_target["origin"]
	assert(game._assembly_origin_in_list([hint_origin.y, hint_origin.x], game.assembly_view.allowed_by_piece.get(str(hint_target["pieceId"]), [])), "Assembly hint should point to a currently open origin")
	var hint_locale: String = game.localization.current_locale
	game.localization.set_locale("en")
	game._use_hint()
	assert(game.assembly_view._hint_piece_id >= 0 and game.hint_count == hint_before - 1, "Assembly hint should show a correct block position and consume one hint")
	assert(str(game.assembly_view._hint_title.text).begins_with("Hint: place the "), "Runtime assembly hint titles must use the shared English localization")
	assert(game.assembly_view._hint_copy.text == "Correct position: row %d, column %d" % [hint_origin.y + 1, hint_origin.x + 1], "Runtime assembly coordinates must use the shared English localization")
	var hint_close_button := game.assembly_view.find_child("HintCloseButton", true, false) as Button
	assert(hint_close_button != null and hint_close_button.text == "Got it", "Runtime assembly hint actions must use the shared English localization")
	game.assembly_view.hide_piece_hint()
	game.localization.set_locale(hint_locale)
	assert(not game.crown_find_button.disabled and not game._assembly_direct_find_target().is_empty(), "Assembly direct find should expose a smallest remaining color target")
	assert(game.crown_find_count == crown_find_before, "Inspecting the assembly direct-find target should not consume a use")
	game._update_assembly_tool_buttons()
	game._on_help()
	assert(game.help_tabs.current_tab == 1, "Assembly help should open the block gameplay tab")
	game.dialog_controller.hide_dialog(true)

	var runtime_layout: Dictionary = game.composite_data["validLayouts"][0]
	var runtime_pieces: Array = game.composite_data["pieces"]
	var first_piece_id := int(runtime_pieces[0]["pieceId"])
	game._on_assembly_placement_requested(first_piece_id, runtime_layout["placements"][str(first_piece_id)])
	assert(game.composite_placements.has(str(first_piece_id)), "Placed assembly state should be recorded")
	var first_piece_origin: Array = game.composite_placements[str(first_piece_id)].duplicate()
	var view: AssemblyView = game.assembly_view
	view._pointer_down = true
	view._pointer_id = 17
	view._interaction_mode = "drag"
	view._drag_piece_id = first_piece_id
	view._drag_source = "board"
	view._return_slot_index = -1
	view._pointer_released(view._tray_rect().get_center(), 17)
	assert(not game.composite_placements.has(str(first_piece_id)), "A release directly in the waiting area must return the block even without a final motion event")
	assert(game.composite_tray_slots.find(first_piece_id) >= 0, "A directly released block must immediately re-enter the sorted tray")
	game._on_assembly_placement_requested(first_piece_id, first_piece_origin)
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


func _test_composite_director_model(levels: Array, entries: Dictionary) -> void:
	var progress := {}
	assert(is_equal_approx(CompositeLevelDirectorScript.exploration_probability(progress, 6), 0.50), "A new size should begin at 50% exploration")
	var candidate := CompositeLevelDirectorScript.recommend(levels, entries, 1, 1, progress)
	assert(not candidate.is_empty(), "The block director should recommend from the offline catalog")
	var level_index := int(candidate.get("levelIndex", -1))
	assert(level_index >= 0 and level_index < levels.size(), "The block director should return a source level index")
	var level: Dictionary = levels[level_index]
	assert(int(level.get("rows", 0)) == 6, "The ordinary unlock policy should start the isolated block mode at 6x6")
	var schedule: Dictionary = candidate.get("schedule", {})
	assert(str(schedule.get("compositeBaseDifficultyClass", "")) == str(level.get("difficulty", "")), "The base difficulty class must come from the ordinary level recommendation")
	assert(not CompositeLevelStoreScript.find(entries, int(level.get("levelId", -1)), str(schedule.get("assemblyDifficultyPattern", ""))).is_empty(), "The recommended pattern must exist offline")
	var advanced_candidate := CompositeLevelDirectorScript.recommend(levels, entries, 1, 180, {})
	var advanced_level: Dictionary = levels[int(advanced_candidate.get("levelIndex", -1))]
	assert(int(advanced_level.get("rows", 0)) == 7 and str(advanced_level.get("difficulty", "")) == "medium", "A newly unlocked composite size should reuse the ordinary director's Medium cold-start probe")

	for sample_index in range(30):
		var sampled_schedule := schedule.duplicate(true)
		var pattern: String = CompositeLevelDirectorScript.PATTERNS[sample_index % CompositeLevelDirectorScript.PATTERNS.size()]
		sampled_schedule["assemblyDifficultyPattern"] = pattern
		sampled_schedule["homeCompositeRound"] = sample_index + 1
		CompositeLevelDirectorScript.record_result(
			progress,
			level,
			sampled_schedule,
			true,
			60.0,
			10,
			0
		)
	assert(is_equal_approx(CompositeLevelDirectorScript.exploration_probability(progress, 6), 0.20), "Balanced evidence should reduce exploration to its 20% floor")
	var size_stats: Dictionary = progress.get("patternStatsBySize", {}).get("6", {})
	for pattern in CompositeLevelDirectorScript.PATTERNS:
		assert(int(size_stats.get(pattern, {}).get("plays", 0)) == 10, "Evidence sufficiency should count every pattern independently")
	var selector_progress: Dictionary = progress.get("levelRecommendationProgress", {})
	var arm_key := "%d|%s" % [int(level.get("rows", 0)), str(level.get("difficulty", "simple"))]
	assert(int(selector_progress.get("statsByArm", {}).get(arm_key, {}).get("plays", 0)) == 30, "Block results should update the ordinary recommendation posterior in an isolated progress store")

	var posterior_progress := {}
	CompositeLevelDirectorScript.normalize_progress(posterior_progress)
	var success_schedule := schedule.duplicate(true)
	success_schedule["assemblyDifficultyPattern"] = "simple"
	CompositeLevelDirectorScript.record_result(posterior_progress, level, success_schedule, true, 60.0, 10, 0)
	var alpha_after_success: Dictionary = posterior_progress["patternAlphaBySize"]["6"]
	assert(float(alpha_after_success["simple"]) > float(alpha_after_success["medium"]), "A successful pattern should gain posterior mass")
	var medium_before_failure := float(alpha_after_success["medium"])
	CompositeLevelDirectorScript.record_result(posterior_progress, level, success_schedule, false, 60.0, 10, 0)
	var alpha_after_failure: Dictionary = posterior_progress["patternAlphaBySize"]["6"]
	assert(float(alpha_after_failure["medium"]) > medium_before_failure, "A failed pattern should distribute posterior mass to the alternatives like the ordinary director")


func _load_multi_piece_home_fixture(game) -> void:
	for level_index in range(game.levels.size()):
		var level: Dictionary = game.levels[level_index]
		if int(level.get("rows", 0)) < 6:
			continue
		for pattern in CompositeLevelDirectorScript.PATTERNS:
			var offline_data := CompositeLevelStoreScript.find(game.composite_levels, int(level.get("levelId", -1)), pattern)
			if offline_data.get("pieces", []).size() < 2:
				continue
			var schedule := LevelDirectorScript.manual_schedule_for_level(game.levels, level_index, 1, "home_composite")
			schedule["assemblyEnabled"] = true
			schedule["assemblySeed"] = int(offline_data.get("seed", 0))
			schedule["assemblyDifficultyPattern"] = pattern
			schedule["homeCompositeRound"] = game.home_composite_round
			game._load_level(level_index, false, schedule)
			return
	assert(false, "The offline catalog should include a multi-piece regression fixture")


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
	assert(view._interaction_mode == "scroll" and view.tray_scroll > 0.0, "A horizontal swipe over the tray should scroll instead of starting a piece drag")
	view._pointer_released(tray_center + Vector2(-44.0, -8.0), 7)

	view.tray_scroll = 0.0
	var pan := InputEventPanGesture.new()
	pan.position = view.get_global_transform_with_canvas() * tray_center
	pan.delta = Vector2(-1.0, 0.0)
	view._input(pan)
	assert(view.tray_scroll > 0.0, "A trackpad horizontal pan gesture over an overflowing tray should scroll it")
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
	view.tray_slot_piece_ids = [0, 1, 2, 3, 4, 5, 6]
	view.tray_scroll = view._tray_max_scroll()
	view._drag_piece_id = 3
	view._drag_source = "board"
	view._return_slot_index = -1
	view._prepare_return_slot_focus()
	assert(view._return_slot_index == 3, "Returning a board piece should focus its current completed slot")
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


func _test_composite_coin_policy() -> void:
	var progress := CompositeCoinPolicyScript.default_progress()
	var today := "2026-08-06"
	assert(CompositeCoinPolicyScript.base_reward_for_round(1) == 2, "Block rounds 1-10 should award two base coins")
	assert(CompositeCoinPolicyScript.base_reward_for_round(10) == 2, "The first reward band should include round 10")
	assert(CompositeCoinPolicyScript.base_reward_for_round(11) == 3, "Every ten played rounds should add one base coin")
	assert(CompositeCoinPolicyScript.base_reward_for_round(61) == 8 and CompositeCoinPolicyScript.base_reward_for_round(100) == 8, "Block rewards should cap at eight base coins")
	for round_number in range(1, 6):
		var free_quote := CompositeCoinPolicyScript.round_quote(round_number, progress, today)
		assert(not bool(free_quote.get("paid", true)) and int(free_quote.get("entryCost", -1)) == 0, "The first five block rounds of a day should be free")
		CompositeCoinPolicyScript.record_round_started(progress, today, free_quote)
	var paid_quote := CompositeCoinPolicyScript.round_quote(6, progress, today)
	assert(bool(paid_quote.get("paid", false)), "The sixth newly started block round of a day should require coins")
	assert(int(paid_quote.get("entryCost", 0)) == 2, "Paid block entry should cost reward minus two with a two-coin minimum")
	assert(int(paid_quote.get("reward", 0)) == 4, "A paid two-coin reward round should receive the minimum two-coin completion bonus")
	var late_paid_quote := CompositeCoinPolicyScript.round_quote(61, progress, today)
	assert(int(late_paid_quote.get("entryCost", 0)) == 6, "An eight-coin block round should cost six coins after the free quota")
	assert(int(late_paid_quote.get("reward", 0)) == 11, "Paid reward should add fifty percent of a six-coin entry fee")
	var next_day_quote := CompositeCoinPolicyScript.round_quote(62, progress, "2026-08-07")
	assert(not bool(next_day_quote.get("paid", true)) and int(progress.get("dailyFreeRoundsUsed", -1)) == 0, "A new local date should reset the five free block rounds")
