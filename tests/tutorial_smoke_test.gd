extends SceneTree

const SAVE_PATH := "user://color_queens_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("CASES TUTOR-001..004")
	var previous_save := ""
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	await process_frame
	game.localization.set_locale("en")
	game.coach_label.text = game._runtime_text(
		"每个颜色区域都要找到一个小狮子。现在这个区域只剩一个可选格，双击找到它。",
		"Observe the highlighted cell."
	)
	game._validate_and_update(false)
	assert(game.coach_label.text == "Each color region needs one lion. Only one cell remains here; double-tap it.", "Validation must not overwrite the English tutorial guidance")
	game.localization.set_locale("zh")
	game.coach_label.text = "每个颜色区域都要找到一个小狮子。现在这个区域只剩一个可选格，双击找到它。"
	await process_frame

	assert(not game.tutorial_completed, "Fresh save should require tutorial")
	assert(game.in_tutorial, "Fresh install should enter tutorial immediately")
	assert(game.tutorial_step_index == 0, "Tutorial should start at the single onboarding map")
	assert(int(game.current_level["rows"]) == 5 and int(game.current_level["cols"]) == 5, "Tutorial should use one larger 5x5 map")
	assert(str(game.current_level["kind"]) == "single_map", "Tutorial should run as one guided map")
	assert(game.top_home_button.visible, "Tutorial should keep the formal level home control")
	assert(game.help_button.visible, "Tutorial should keep the formal level help control")
	assert(game.level_heart_label.visible, "Tutorial should keep the formal level heart badge")
	assert(not game.level_select_button.visible, "Tutorial should replace level selection with the skip action")
	assert(game.tutorial_skip_button.visible, "Tutorial should allow skipping")
	assert(game.tutorial_skip_button.text == "跳过", "Tutorial skip button should use full copy")
	assert(game.undo_button == null, "Tutorial should not expose undo")
	assert(game.level_label.text == "新手教程", "Tutorial should use the same visible title row as formal levels")
	assert(game.coach_panel.visible, "Tutorial should keep its required instructional text card")
	assert(game.clear_button == null, "Tutorial should not expose the removed clear tool")
	assert(game.crown_find_button.visible and game.crown_find_button.disabled, "Tutorial should keep lion finder visible until its guided step")
	assert(game.hint_button.visible, "Tutorial should keep hint available")
	assert(game.hint_button.disabled, "Hint should wait until the clue step")
	assert(game.crown_find_button_label.text == "" and game.hint_button_label.text == "", "Tutorial tool counters should start empty instead of infinite")
	assert(game.coach_label.text == "每个颜色区域都要找到一个小狮子。现在这个区域只剩一个可选格，双击找到它。", "Tutorial should start with the first color-region crown clue")
	assert(game.coach_label.get_theme_font_size("font_size") >= 18, "Tutorial guidance should use larger text")
	assert(game.coach_label.get_theme_color("font_color") == Color("#31506D"), "Tutorial guidance should use dark text")
	assert(game.tutorial_hand_label.visible, "Tutorial should show hand pointer")
	assert(game.tutorial_hand_label.get_theme_font_size("font_size") >= 56, "Tutorial hand should be large and easy to notice")
	assert(game.board.tutorial_mask_enabled, "Tutorial should mask non-target cells")
	assert(game.board.tutorial_focus_cell == Vector2i(2, 2), "Tutorial should focus the first crown")

	game._on_cell_pressed(2, 2)
	assert(game.cell_states[2][2] == "empty", "Single tap should not place the first crown")
	game._on_cell_double_pressed(2, 2)
	await process_frame
	assert(game.cell_states[2][2] == "piece", "Double tap should place the first crown")
	assert(game.coach_label.text == "小狮子不能和小狮子挨着。滑过它周围的格子，把这些位置标记为 X。", "Tutorial should teach surrounding exclusions after first crown")
	assert(not game.board.tutorial_mask_enabled and not game.board.guide_mask_enabled, "Tutorial exclusion stages should keep the full board visible")
	assert(game.board.guide_cells.size() == 8, "Adjacent exclusion should expose all eight legal cells at once")
	assert(game.board.tutorial_focus_cell == Vector2i(-1, -1), "Open exclusion guidance should not restore a single-cell mask")

	await _complete_current_exclusions(game)
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT, "Tutorial should ask for a hint after exclusions")
	assert(game.coach_label.text == "点一下提示，看看下一步该观察哪里。", "Tutorial should guide hint after exclusions")
	assert(not game.hint_button.disabled, "Hint button should be enabled at the clue step")
	assert(game.hint_button_label.text == "×1", "Tutorial hint should show one use only when guiding the hint button")
	await create_timer(0.25).timeout
	await process_frame
	assert(game.tutorial_hand_control == game.hint_button, "Tutorial should point to the hint button")

	game._use_hint()
	await process_frame
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT_PLACE, "Hint should move to guided crown placement")
	assert(game.hint_button_label.text == "×0", "Tutorial hint should show zero after the guided click")
	assert(game.coach_label.text == "每个颜色区域都要找到一个小狮子。现在这个区域只剩一个可选格，双击找到它。", "Hint should explain the color-region crown clue")
	assert(game.board.tutorial_focus_cell == Vector2i(1, 0), "Hint should focus the next crown")
	game._on_cell_pressed(0, 1)
	assert(game.cell_states[0][1] == "empty", "Hinted crown still requires a double tap")
	game._on_cell_double_pressed(0, 1)
	await process_frame
	assert(game.cell_states[0][1] == "piece", "Double tap should place the hinted crown")

	await _complete_current_exclusions(game)
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_CROWN_FIND, "Tutorial should teach crown find after the normal hint")
	assert(game.coach_label.text == "点击小狮子，直接找到一个小狮子。教程中不会消耗使用次数。", "Lion-finder step should explain its direct locked result")
	assert(not game.crown_find_button.disabled, "Crown find should unlock only for its guided step")
	assert(game.crown_find_button_label.text == "×1", "Tutorial lion finder should show one use only when guiding the lion button")
	await create_timer(0.25).timeout
	await process_frame
	assert(game.tutorial_hand_control == game.crown_find_button, "Tutorial should point to the crown-find button")
	var crown_find_count_before: int = game.crown_find_count
	game._use_crown_find()
	await process_frame
	assert(game.cell_states[1][4] == "hint", "Crown find should directly place a locked tutorial crown")
	assert(game.crown_find_count == crown_find_count_before, "Tutorial crown find must not consume formal free uses")
	assert(game.crown_find_button_label.text == "×0", "Tutorial lion finder should show zero after the guided click")
	assert(game.tutorial_crown_find_taught, "Tutorial should remember that crown find has been taught")
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_ROW_COL, "Crown find should continue with the remaining rule exclusions")
	assert(game.coach_label.text == "小狮子按钮已直接找到并锁定小狮子，周围位置已经排除。继续排除同行同列。", "Lion find should explain the locked result and next remaining rule")

	await _complete_current_exclusions(game)
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT_PLACE, "Tutorial should directly reveal later crown clues after tool teaching")
	assert(game.coach_label.text == "每个颜色区域都要找到一个小狮子。现在这个区域只剩一个可选格，双击找到它。", "Later clue should skip repeated tool teaching")
	assert(game.hint_button.disabled and game.crown_find_button.disabled, "Tutorial tools should lock again after their teaching steps")
	assert(game.board.tutorial_focus_cell == Vector2i(3, 4), "Direct clue should focus the next manual crown")
	game._on_cell_double_pressed(4, 3)
	await process_frame

	await _complete_current_exclusions(game)
	assert(game.tutorial_interaction_stage == game.TUTORIAL_PHASE_HINT_PLACE, "Final crown should skip the hint button")
	assert(game.hint_button.disabled, "Hint should stay disabled when only the final crown remains")
	assert(game.coach_label.text == "每行、每列都要找到一个小狮子。现在只剩这个位置符合规则，双击找到最后一个小狮子。", "Final crown should be guided directly")
	assert(game.board.tutorial_focus_cell == Vector2i(0, 3), "Final step should focus the last crown")
	game._on_cell_double_pressed(3, 0)
	await process_frame

	assert(game.is_completed, "Tutorial should complete after all crowns are found")
	assert(game._piece_positions().size() == 5, "Tutorial should find all five crowns on one map")
	assert(game.coach_label.text == "已经了解全部规则，开始真正的挑战吧！", "Tutorial should show final challenge copy")
	assert(game.completion_overlay.visible, "Tutorial should show final start challenge overlay")
	assert(game.completion_next_button.text == "开始挑战", "Tutorial final button should start challenge")

	game._next_level()
	await process_frame
	assert(game.tutorial_completed, "Tutorial should be saved complete")
	assert(not game.in_tutorial, "Game should leave tutorial")
	assert(int(game.current_level["levelId"]) == 1, "Tutorial should enter formal level 1")
	assert(game._piece_positions().size() == 1, "Formal level 1 should start with the fixed opening king")
	assert(game.crown_find_button_label.text == "×3" and game.hint_button_label.text == "×3", "Formal tools should restore their real counters after tutorial")
	var king_position: Array = game.current_level["kingPosition"]
	assert(game.cell_states[int(king_position[0])][int(king_position[1])] == "king", "Formal level 1 should display the opening king")
	assert(not game.tutorial_skip_button.visible, "Formal level should hide the tutorial top button")
	assert(game.top_home_button.visible, "Formal level should restore the home button")
	assert(not game.board.tutorial_mask_enabled, "Formal level should not keep tutorial mask")

	game._show_home()
	await process_frame
	game._simulate_new_user_flow()
	await process_frame
	assert(game.in_tutorial, "New user button should re-enter tutorial")
	assert(not game.tutorial_completed, "New user button should reset tutorial completion")
	assert(game.tutorial_step_index == 0, "New user button should restart tutorial")
	game._request_skip_tutorial()
	assert(game.dialog_controller.is_dialog_open("tutorial_skip"), "Tutorial skip should open its confirmation dialog")
	var skip_button: Button = game.dialog_controller.find_child("DialogAction_skip", true, false)
	assert(skip_button != null, "Tutorial skip dialog should expose its confirm action")
	skip_button.pressed.emit()
	await process_frame
	assert(game.tutorial_completed and not game.in_tutorial, "Confirmed skip should persist completion and leave tutorial")
	assert(int(game.current_level["levelId"]) == 1, "Confirmed skip should enter formal level 1")

	game.queue_free()
	await process_frame
	_restore_save(had_save, previous_save)
	print("TUTORIAL SMOKE TEST PASSED")
	quit()


func _complete_current_exclusions(game) -> void:
	while game.tutorial_interaction_stage == game.TUTORIAL_PHASE_ADJACENT or game.tutorial_interaction_stage == game.TUTORIAL_PHASE_ROW_COL:
		var targets: Array = game.board.guide_cells.keys()
		assert(not targets.is_empty(), "Exclusion phase should expose every remaining target in the current rule group")
		assert(not game.board.tutorial_mask_enabled and not game.board.guide_mask_enabled, "Exclusion phases should never dim non-target cells")
		if game.tutorial_interaction_stage == game.TUTORIAL_PHASE_ROW_COL:
			assert(game._tutorial_hand_cell_action() == "single", "Row/column phase should demonstrate tapping the green guide cell")
			var row_col_copy_valid: bool = game.coach_label.text == "每行、每列都只能有一个小狮子。这个小狮子所在的行和列，其他格都可以标记 X。"
			row_col_copy_valid = row_col_copy_valid or game.coach_label.text == "小狮子按钮已直接找到并锁定小狮子，周围位置已经排除。继续排除同行同列。"
			assert(row_col_copy_valid, "Row/column phase should use concise exclusion copy")
			var first_row_col: Vector2i = targets[0]
			var target_count_before_drag: int = _blocked_count(game, targets)
			game._on_cell_drag_started(first_row_col.y, first_row_col.x)
			assert(game.cell_states[first_row_col.y][first_row_col.x] == "blocked", "Row/column tutorial should tolerate a slight drag that starts on the green guide cell")
			if targets.size() > 1:
				var next_dragged: Vector2i = targets[1]
				game._on_cell_dragged(next_dragged.y, next_dragged.x)
				assert(_blocked_count(game, targets) == target_count_before_drag + 1, "Row/column tutorial should not mark extra cells through a drag path")
			game._on_cell_drag_ended()
		else:
			assert(game._tutorial_hand_cell_action() == "slide", "Adjacent phase should demonstrate sliding")
			var first: Vector2i = targets[0]
			game._on_cell_drag_started(first.y, first.x)
			for raw_target in targets.slice(1):
				var target: Vector2i = raw_target
				game._on_cell_dragged(target.y, target.x)
			game._on_cell_drag_ended()
		await process_frame


func _blocked_count(game, cells: Array) -> int:
	var count := 0
	for raw_cell in cells:
		var cell: Vector2i = raw_cell
		if game.cell_states[cell.y][cell.x] == "blocked":
			count += 1
	return count


func _restore_save(had_save: bool, contents: String) -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(contents)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
