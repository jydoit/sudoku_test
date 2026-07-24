extends SceneTree

const LevelDirectorScript = preload("res://scripts/level_director.gd")
const CoinEconomyScript = preload("res://scripts/coin_economy.gd")
const UITokensScript = preload("res://scripts/ui_tokens.gd")
const SAVE_PATH := "user://color_queens_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("CASES HOME-001..004 LEVEL-001..004 BOARD-001..009 HINT-001..004 TOOL-001..003 ECON-001 RESULT-001..002 I18N-001..002 DATA-001..003")
	var previous_save := ""
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_PATH)

	var custom_font_path := str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	assert(custom_font_path == "res://assets/fonts/NotoSansSC-Regular.ttf", "Project must configure the bundled CJK font")
	var custom_font: Font = load(custom_font_path)
	assert(custom_font != null, "Bundled UI font must load successfully")
	assert(custom_font.has_char("中".unicode_at(0)), "Bundled UI font must contain Chinese glyphs")

	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "Main scene must load")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	assert(game.localization != null, "Main UI should use the shared localization controller")
	assert(game.LocalizationControllerScript.locale_for_system("zh_CN") == "zh", "System Chinese locales should map to Chinese")
	assert(game.LocalizationControllerScript.locale_for_system("ar_SA") == "ar", "System Arabic locales should map to Arabic")
	assert(game.LocalizationControllerScript.locale_for_system("fr_FR") == "fr", "System French locales should map to French")
	assert(game.LocalizationControllerScript.locale_for_system("la") == "la", "System Latin locales should map to Latin")
	assert(game.LocalizationControllerScript.locale_for_system("de_DE") == "en", "Unsupported system locales should fall back to English")
	assert(game.ARABIC_FONT != null and game.ARABIC_FONT.has_char("ع".unicode_at(0)), "Bundled Arabic fallback font must contain Arabic glyphs")
	assert(game.UI_FONT.fallbacks.has(game.ARABIC_FONT), "The shared UI font should register the Arabic fallback")
	game.localization.set_locale("en")
	assert(game.localization.runtime_text("尚未收录的动态中文") == "Follow the highlighted guidance to continue.", "Unknown runtime Chinese must not leak into non-Chinese locales")
	game.localization.set_locale("zh")
	assert(game.localization.runtime_text("尚未收录的动态中文") == "尚未收录的动态中文", "Chinese runtime copy should stay intact in the Chinese locale")
	await process_frame

	assert(game.levels.size() >= 50, "MVP should include 50 default levels")
	assert(game.home_screen != null, "Home screen should exist")
	assert(game.game_screen != null, "Game screen should exist")
	assert(game.progress_bar != null and game.progress_label != null, "Level screen should show crown progress")
	assert(game.COIN_ICON != null, "Coin balance should use the generated coin texture")
	assert(game.LION_KING_ICON != null, "Core game pieces should use the lion king texture")
	assert(game.LION_KING_WRONG_ICON != null, "Wrong placements should use the worried lion texture")
	assert(game.LION_KING_VICTORY_ICON != null, "Completion should use the standing lion texture")
	assert(game.LION_KING_VICTORY_FRAMES.size() == 9, "Completion lion should provide wave and expression animation frames")
	assert(game.board.PIECE_TEXTURE == game.LION_KING_ICON, "Board pieces and UI should share the same lion king texture")
	assert(game.board.WRONG_PIECE_TEXTURE == game.LION_KING_WRONG_ICON, "Wrong board pieces and UI should share the worried lion texture")
	assert(game.coin_label.get_parent().get_node_or_null("CoinIcon") != null, "Level coin balance should render the coin icon beside its value")
	assert(game.opening_king_overlay != null, "Level screen should provide an opening king overlay")
	assert(game.INK == UITokensScript.INK, "Main UI should use the shared ink token")
	assert(game.REGION_COLORS == UITokensScript.REGION_COLORS, "Main UI should use the shared region palette")
	assert(game.board.BOARD_INK == UITokensScript.INK, "Board symbols should use the shared ink token")
	assert(UITokensScript.BOARD_BORDER.a == 1.0, "Board borders should use a precomposed color with stable visual opacity")
	assert(UITokensScript.same_region_gap_color(UITokensScript.REGION_COLORS[0]) == UITokensScript.BOARD_GAP, "Same-region gaps should stay on the white board surface so cells never merge into a single color block")
	var different_region_pair := _first_adjacent_region_pair(game.board.regions)
	assert(different_region_pair.size() == 4, "Smoke fixture should include adjacent color regions")
	assert(game.board._gap_color_between(different_region_pair[0], different_region_pair[1], different_region_pair[2], different_region_pair[3]) == UITokensScript.BOARD_GAP, "Different-region gaps should stay white without dark divider lines")
	assert(is_equal_approx(UITokensScript.ATTENTION_MASK_COLOR.a, 0.58), "Hint masks should use the approved semi-transparent white-gray overlay")
	assert(UITokensScript.board_border_width(5) == 4.0, "5x5 board border should follow the UI guide")
	assert(UITokensScript.board_border_width(7) == 3.0, "7x7 board border should follow the UI guide")
	assert(UITokensScript.board_border_width(9) == 2.0, "9x9 board border should follow the UI guide")
	assert(UITokensScript.CROWN_MAX_FONT_RATIO <= 0.72, "Opening crown scale should stay inside its cell")
	assert(UITokensScript.REGION_PATTERN_NAMES.size() == UITokensScript.REGION_COLORS.size(), "Every region color should have one documented pattern")
	for pattern_name in UITokensScript.REGION_PATTERN_NAMES:
		assert("交叉" not in str(pattern_name) and "X" not in str(pattern_name).to_upper(), "Region patterns must not resemble player X marks")
	assert(CoinEconomyScript.size_base_reward(5) < CoinEconomyScript.size_base_reward(9), "Larger boards should grant a larger base coin reward")
	assert(CoinEconomyScript.level_base_reward(5, 1) < CoinEconomyScript.level_base_reward(5, 0), "Opening king levels should grant fewer coins")
	var clean_reward := CoinEconomyScript.completion_reward(5, 0, 0)
	var mistake_floor_reward := CoinEconomyScript.completion_reward(5, 0, 9)
	assert(mistake_floor_reward == int(round(float(clean_reward) * 0.5)), "Mistake deductions should stop at half of the level base reward")
	var economy_test_progress := CoinEconomyScript.default_progress()
	var economy_base := CoinEconomyScript.level_base_reward(5, 0)
	assert(CoinEconomyScript.standard_tool_price(CoinEconomyScript.TOOL_HINT, 5, 0) == economy_base, "Logic hint should cost one level base")
	assert(CoinEconomyScript.standard_tool_price(CoinEconomyScript.TOOL_REVIVE, 5, 0) == economy_base * 2, "Revive should cost two level bases")
	assert(CoinEconomyScript.standard_tool_price(CoinEconomyScript.TOOL_CROWN_FIND, 5, 0) == economy_base * 3, "Crown find should cost three level bases")
	assert(CoinEconomyScript.rewarded_ad_coin_grant(economy_base * 3, 0, 5, 0) == economy_base * 3, "A rewarded ad should cover a full tool shortage")
	assert(CoinEconomyScript.rewarded_ad_coin_grant(economy_base * 3, economy_base * 3 - 1, 5, 0) == economy_base, "A rewarded ad should grant at least one level base without over-funding the wallet")
	for completion_index in range(3):
		CoinEconomyScript.record_completion(economy_test_progress, completion_index + 1, 5, 0, 0, economy_base, 0)
	var discounted_hint_price := CoinEconomyScript.tool_price(CoinEconomyScript.TOOL_HINT, 5, 0, economy_test_progress, 0)
	assert(discounted_hint_price < economy_base, "Three completions without a coin exchange should discount the next tool price")
	assert(CoinEconomyScript.tool_price(CoinEconomyScript.TOOL_HINT, 5, 0, economy_test_progress, 3) == economy_base, "Repeated exchanges should restore the standard tool price")
	assert(game._heart_limit_for_display_level(10) == 3, "The first ten display levels should keep three hearts")
	assert(game._heart_limit_for_display_level(11) == 2 and game._heart_limit_for_display_level(30) == 2, "Display levels 11-30 should use two hearts")
	assert(game._heart_limit_for_display_level(31) == 1, "Display level 31 onward should use one heart")
	game.tutorial_completed = true
	game.tutorial_started = false
	if game.dialog_controller:
		game.dialog_controller.hide_dialog(true)
	game._load_level(0)
	game._show_game()
	await process_frame
	await process_frame
	assert(game.top_home_button.custom_minimum_size.x >= 52.0, "The level home control should use an enlarged touch target")
	assert(game.coach_panel != null and not game.coach_panel.visible, "Formal levels should remove the coach text interval from the layout")
	assert(game.board.size.y >= 600.0, "The board layout should receive the space released by the hidden coach interval")
	var expanded_board_rect: Rect2 = game.board._board_geometry()["rect"]
	assert(expanded_board_rect.size.x >= 510.0 and expanded_board_rect.size.y >= 510.0, "The formal board should use the tightened horizontal and internal spacing")
	assert(game.help_button != null and game.help_button.get_parent() == game.top_home_button.get_parent(), "Help should share the level top navigation row")
	assert(game.help_button.custom_minimum_size.x >= 46.0, "Help should use a mobile-friendly touch target")
	assert(game.settings_button != null and game.settings_button.get_parent() == game.top_home_button.get_parent(), "Settings should share the level top navigation row")
	assert(game.dialog_controller != null, "All modal dialogs should use the shared dialog controller")
	var dialog_card: PanelContainer = game.dialog_controller.find_child("DialogCard", true, false)
	var dialog_style := dialog_card.get_theme_stylebox("panel") as StyleBoxFlat
	assert(dialog_style.bg_color == UITokensScript.DIALOG_SURFACE, "Dialog cards should use the shared warm surface token")
	assert(dialog_style.border_color == UITokensScript.DIALOG_BORDER and dialog_style.border_width_left == UITokensScript.DIALOG_BORDER_WIDTH, "Dialog cards should use the shared border style")
	var help_content: Control = game.dialog_controller.content("help_rules")
	assert(help_content != null and help_content.name == "HelpContent", "Help dialog should provide custom visual rule content")
	for illustration_name in ["AdjacentRuleIllustration", "RowColumnRuleIllustration", "RegionRuleIllustration"]:
		assert(help_content.find_child(illustration_name, true, false) != null, "Help dialog should show all three rule illustrations")
	game._on_help()
	assert(game.dialog_controller.is_dialog_open("help"), "Help button should open the elimination rules dialog")
	var help_close_button: Button = game.dialog_controller.find_child("DialogAction_close", true, false)
	assert(help_close_button != null, "Help dialog should expose the standard primary action")
	help_close_button.pressed.emit()
	assert(not game.dialog_controller.visible, "A shared dialog action should close the modal layer")
	game._on_settings()
	assert(game.dialog_controller.is_dialog_open("settings"), "Settings should open through the shared dialog controller")
	assert(game.language_picker.item_count == 5, "Language settings should list all supported languages")
	game.language_picker.select(game.localization.locale_index("ar"))
	var apply_language_button: Button = game.dialog_controller.find_child("DialogAction_apply", true, false)
	assert(apply_language_button != null, "Language settings should expose a standard apply action")
	apply_language_button.pressed.emit()
	await process_frame
	assert(game.selected_language == "ar" and game.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Arabic should apply RTL layout")
	assert(game.localization.text("设置") == "الإعدادات", "Arabic settings copy should come from the localization controller")
	game.localization.set_locale("fr")
	await process_frame
	assert(game.localization.text("设置") == "Paramètres", "French copy should come from the localization controller")
	game.localization.set_locale("la")
	await process_frame
	assert(game.localization.text("设置") == "Configurationes", "Latin copy should come from the localization controller")
	game.localization.set_locale("zh")
	await process_frame
	assert(game.layout_direction == Control.LAYOUT_DIRECTION_LTR, "Chinese should restore LTR layout")
	assert(game.level_heart_label.get_parent() == game.top_home_button.get_parent(), "Level hearts should share the top navigation row with coins")
	assert(game.clear_button == null, "Clear should no longer be exposed as a bottom tool")
	assert(game.crown_find_button.get_parent() == game.hint_button.get_parent(), "Lion finder and hint should share the bottom tool bar")
	assert(game.level_heart_slots.size() == game.INITIAL_HEART_COUNT, "The top heart badge should keep independent heart slots")
	assert(game.level_heart_tweens.size() == game.INITIAL_HEART_COUNT, "Every visible heart should keep a stable tween slot")
	for heart_index in range(game.level_heart_slots.size()):
		var heart_slot: Label = game.level_heart_slots[heart_index]
		assert(heart_slot.custom_minimum_size.x >= 32.0 and heart_slot.custom_minimum_size.y >= 38.0, "Heart slots should not be compressed")
		assert(game.level_heart_tweens[heart_index] == null, "Hearts should stay still by default")
	for tool_button in [game.crown_find_button, game.hint_button]:
		var tool_icon: Control = tool_button.find_child("ToolIcon", true, false)
		var tool_label: Label = tool_button.find_child("ToolLabel", true, false)
		assert(tool_icon != null and tool_label != null, "Every tool should expose a large icon and caption")
		assert(tool_icon.custom_minimum_size.x >= 48.0 and tool_icon.custom_minimum_size.y >= 48.0, "Tool icons should use the enlarged visual size")
		assert(tool_icon.position.x < tool_label.position.x, "Tool icons should render before their compact counters")
	assert(game.crown_find_button_label.text == "×3", "Lion finder should show only its icon and remaining count")
	assert(game.hint_button_label.text == "×3", "Hint should show only its icon and remaining count")
	assert(not game.crown_find_button_label.text.contains("小狮子") and not game.hint_button_label.text.contains("提示"), "Tool captions should not repeat names beside recognizable icons")
	var completed_start_level_id := int(game.current_level["levelId"])
	game.completed_levels = [completed_start_level_id]
	game.director_progress = {"completedLevelIds": [completed_start_level_id], "recentRuns": [], "statsByArm": {}}
	game.is_completed = true
	game._show_home()
	game._start_current_flow()
	assert(game.game_screen.visible, "Starting from home after a completed saved level should enter the game")
	assert(game.player_level_number == 2, "Starting from home after a completed saved level should advance to the next display level")
	assert(not game.is_completed, "The auto-advanced level should be playable")
	assert(game.opening_king_overlay.visible, "A level with opening kings should show the count overlay")
	assert(game.board.hidden_king_cells.size() == game.active_king_positions.size(), "Opening kings should stay hidden until their flight animation lands")
	game._cancel_opening_king_intro()
	var resumed_editable_cell := _first_empty_non_king_cell(game)
	game._on_cell_pressed(resumed_editable_cell.y, resumed_editable_cell.x)
	assert(game.cell_states[resumed_editable_cell.y][resumed_editable_cell.x] == "blocked", "The auto-advanced level should accept normal input")
	game.completed_levels.clear()
	game.director_progress.clear()
	game._load_level(0)
	game._show_game()
	assert(game.level_select_button != null, "Level screen should expose level selection")
	game._open_level_select()
	assert(game.dialog_controller.is_dialog_open("level_select"), "Level selection dialog should open through the shared controller")
	assert(game.level_select_grid != null and game.level_select_buttons.size() == mini(game.LEVEL_SELECT_PAGE_SIZE, game.levels.size()), "Level selection should show a full page of large number buttons")
	for level_button in game.level_select_buttons:
		assert(level_button.custom_minimum_size.x >= 58.0 and level_button.custom_minimum_size.y >= 58.0, "Every level number should be a mobile-friendly touch target")
	if game.levels.size() > game.LEVEL_SELECT_PAGE_SIZE:
		game.level_select_next_button.pressed.emit()
		assert(game.level_select_page == 1 and game.level_select_selected_index == game.LEVEL_SELECT_PAGE_SIZE, "Next page should advance by exactly twenty data levels")
		assert(game.level_select_buttons[0].name == "LevelSelect_%d" % int(game.levels[game.LEVEL_SELECT_PAGE_SIZE]["levelId"]), "Paged grid should still display data levelIds")
		game.level_select_previous_button.pressed.emit()
		assert(game.level_select_page == 0, "Previous page should return to the first twenty levels")
	var manual_select_index := 10
	var manual_level_id := int(game.levels[manual_select_index]["levelId"])
	game.level_select_buttons[manual_select_index].pressed.emit()
	assert(game.level_select_selected_index == manual_select_index, "Tapping a number tile should select that exact data level")
	var enter_level_button: Button = game.dialog_controller.find_child("DialogAction_enter", true, false)
	assert(enter_level_button != null, "Level selection should expose the standard primary action")
	assert(enter_level_button.text == game._t("进入关卡 %d", [manual_level_id]), "Primary action should repeat the selected levelId")
	enter_level_button.pressed.emit()
	assert(int(game.current_level["levelId"]) == manual_level_id, "Level selection should enter the selected level")
	assert(game.player_level_number == manual_level_id, "Manual selection should use the visible levelId as the top display number")
	assert(game.level_label.text == game._t("关卡 %d", [manual_level_id]), "Top level title should match the number chosen in the level grid")
	await process_frame
	assert(game.board != null and game.board.size.x >= 400.0, "Board must render at a mobile-friendly size")

	for level in game.levels:
		_validate_solution(level)
	var expected_opening_difficulties := ["simple", "simple", "simple", "simple", "simple", "medium", "medium", "medium", "simple", "hard"]
	var scheduled_opening_ids := []
	for display_level in range(1, 11):
		var fixed_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, display_level, {})
		var repeated_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, display_level, {})
		var scheduled_level: Dictionary = game.levels[int(fixed_schedule["levelIndex"])]
		scheduled_opening_ids.append(int(fixed_schedule["levelId"]))
		assert(int(fixed_schedule["levelIndex"]) == int(repeated_schedule["levelIndex"]), "Fixed opening schedule should be deterministic")
		assert(int(scheduled_level.get("rows", 0)) == 5 and int(scheduled_level.get("cols", 0)) == 5, "First ten display levels should use 5x5 boards")
		assert(str(scheduled_level.get("difficulty", "")) == expected_opening_difficulties[display_level - 1], "First ten display levels should follow the requested difficulty plan")
		if display_level <= 9:
			assert(fixed_schedule.get("kingPositions", []).size() == 1, "First nine display levels should reveal one opening king")
		else:
			assert(fixed_schedule.get("kingPositions", []).is_empty(), "Display level 10 should not start with a king")
			assert(bool(fixed_schedule["isMilestoneChallenge"]), "Display level 10 should be marked as a challenge")
	assert(scheduled_opening_ids.slice(0, 5) == [1, 2, 3, 11, 12], "Display levels 1-5 should use the first five 5x5 simple boards")
	assert(scheduled_opening_ids.slice(5, 8) == [4, 5, 6], "Display levels 6-8 should use the first three 5x5 medium boards")
	assert(scheduled_opening_ids[8] == 13, "Display level 9 should return to a 5x5 simple board")
	assert(scheduled_opening_ids[9] == 7, "Display level 10 should use the first 5x5 hard board")
	var level_index: Dictionary = LevelDirectorScript.build_level_index(game.levels)
	assert(level_index[5]["simple"].slice(0, 5) == [0, 1, 2, 10, 11], "Level index should group levels by size and difficulty")
	var recent_medium_ids := []
	for raw_index in level_index[6]["medium"].slice(0, 3):
		recent_medium_ids.append(int(game.levels[int(raw_index)]["levelId"]))
	var filtered_candidates: Array = LevelDirectorScript._candidate_indices(game.levels, level_index, [6], ["medium"], [], recent_medium_ids, false, false)
	for raw_index in filtered_candidates:
		assert(not recent_medium_ids.has(int(game.levels[int(raw_index)]["levelId"])), "Candidate filtering should skip recent levelIds")
	var completed_ids := []
	for completed_id in range(1, 31):
		completed_ids.append(completed_id)
	var dynamic_progress := {"completedLevelIds": completed_ids, "recentRuns": [], "statsByArm": {}}
	var dynamic_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, 11, dynamic_progress)
	assert(int(dynamic_schedule["displayLevel"]) == 11, "Dynamic schedule should keep the player-facing level number")
	assert(not completed_ids.has(int(dynamic_schedule["levelId"])), "Dynamic schedule should skip already completed raw levelIds")
	_validate_dynamic_king_positions(game.levels[int(dynamic_schedule["levelIndex"])], dynamic_schedule)
	assert(LevelDirectorScript._opening_king_count_for_size(5, RandomNumberGenerator.new()) == 1, "5x5 dynamic levels should reveal exactly one opening king")
	for size in [6, 7, 8, 9]:
		var count_rng := RandomNumberGenerator.new()
		count_rng.seed = size
		var king_count: int = LevelDirectorScript._opening_king_count_for_size(size, count_rng)
		assert(king_count >= 1 and king_count <= 3, "Dynamic opening king count should stay in the supported 1-3 range")
		if size == 6:
			assert(king_count <= 2, "6x6 dynamic levels should reveal at most two opening kings")
	var post_challenge_progress := {
		"completedLevelIds": [1, 2, 3, 11, 12, 4, 5, 6, 13, 7],
		"recentRuns": [
			{"displayLevel": 10, "levelId": 7, "size": 5, "difficulty": "hard", "isMilestoneChallenge": true}
		],
		"statsByArm": {}
	}
	var post_challenge_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, 11, post_challenge_progress)
	assert(str(post_challenge_schedule["mode"]) == "post_challenge", "The level after a challenge should use the easier recovery branch")
	assert(int(post_challenge_schedule["selectedSize"]) == 5, "The post-challenge level should keep the challenge size")
	assert(str(post_challenge_schedule["selectedDifficulty"]) == "medium", "The post-challenge level should lower difficulty by one step")
	assert(post_challenge_schedule.get("kingPositions", []).size() >= 1, "The post-challenge level should reveal opening kings")
	var no_king_progress := {
		"completedLevelIds": [],
		"recentRuns": [
			{"displayLevel": 54, "levelId": 200, "size": 7, "difficulty": "medium", "isMilestoneChallenge": false}
		],
		"statsByArm": {}
	}
	var no_king_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, 55, no_king_progress)
	assert(no_king_schedule.get("kingPositions", []).is_empty(), "After level 50 every fifth level should hide opening kings")
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
	var challenge_arm := "%d|%s" % [int(challenge_schedule["selectedSize"]), str(challenge_schedule["selectedDifficulty"])]
	assert(["5|challenge", "5|hard"].has(challenge_arm), "Milestone should either raise difficulty or keep the current size when larger boards are locked")
	var reward_progress := {"completedLevelIds": [], "recentRuns": [], "statsByArm": {}}
	LevelDirectorScript.record_completion(reward_progress, game.levels[0], LevelDirectorScript.schedule_for_display_level(game.levels, 1, {}), 2000.0, 10, 0, "2026-07-09", 1000)
	var reward_run: Dictionary = reward_progress["recentRuns"][0]
	var reward_before_bonus := float(reward_run["reward"])
	assert(float(reward_run["elapsedSeconds"]) == 900.0, "Reward elapsed time should be capped at 15 minutes")
	LevelDirectorScript.record_next_level_opened(reward_progress)
	assert(bool(reward_run["openedNextLevel"]) and float(reward_run["reward"]) > reward_before_bonus, "Opening the next level should add a reward bonus")
	LevelDirectorScript.record_completion(reward_progress, game.levels[1], LevelDirectorScript.schedule_for_display_level(game.levels, 2, {}), 100.0, 8, 0, "2026-07-09", 1200)
	var second_reward_run: Dictionary = reward_progress["recentRuns"][1]
	LevelDirectorScript.record_retention_if_needed(reward_progress, "2026-07-10", 1000 + 12 * 60 * 60)
	assert(bool(reward_run["retainedNextDay"]) and bool(second_reward_run["retainedNextDay"]), "Startup retention should mark every cross-day run within 24 hours")
	var reward_after_retention := float(reward_run["reward"])
	LevelDirectorScript.record_retention_if_needed(reward_progress, "2026-07-10", 1000 + 12 * 60 * 60)
	assert(float(reward_run["reward"]) == reward_after_retention, "Retention bonus should not be added twice")
	var expired_progress := {"completedLevelIds": [], "recentRuns": [], "statsByArm": {}}
	LevelDirectorScript.record_completion(expired_progress, game.levels[0], LevelDirectorScript.schedule_for_display_level(game.levels, 1, {}), 100.0, 8, 0, "2026-07-09", 1000)
	var expired_run: Dictionary = expired_progress["recentRuns"][0]
	LevelDirectorScript.record_retention_if_needed(expired_progress, "2026-07-10", 1000 + 24 * 60 * 60 + 1)
	assert(not bool(expired_run["retainedNextDay"]), "Retention bonus should expire after 24 hours")

	game.immediate_errors = true
	game.heart_count = 3
	var display_four_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, 4, {})
	game._load_level(int(display_four_schedule["levelIndex"]), false, display_four_schedule)
	assert(not game.coach_panel.visible, "Opening-king levels should not show a coach text card")
	assert(game.active_king_positions.size() == 1, "Display level 4 should reveal one fixed opening king")
	var display_ten_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, 10, {})
	game._load_level(int(display_ten_schedule["levelIndex"]), false, display_ten_schedule)
	assert(game.active_king_positions.is_empty(), "Display level 10 should not reveal an opening king")
	assert(game._piece_positions().is_empty(), "Display level 10 should start without prefilled crowns")
	game._load_level(0)
	assert(not game.coach_panel.visible, "Formal levels should keep king guidance visual-only")
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
	game._on_cell_pressed(int(solution_cell[0]), int(solution_cell[1]))
	assert(game.cell_states[int(solution_cell[0])][int(solution_cell[1])] == "piece", "Confirmed lions should be locked and ignore single taps")
	game._undo()
	assert(game.cell_states[int(solution_cell[0])][int(solution_cell[1])] == "piece", "Undo must preserve a locked confirmed lion")
	assert(game._opening_lion_subtitle(1) == "开局提供 1 个提示小狮子", "Chinese opening copy should use its singular-specific source")
	game.localization.set_locale("en")
	assert(game._opening_lion_subtitle(1) == "1 lion is provided at the start", "English opening copy should use correct singular grammar")
	assert(game.localization.runtime_text(str(game.TUTORIAL_LEVELS[0]["tutorial"])) == "Each color region needs one lion. Only one cell remains here; double-tap it.", "English tutorial must start with the PRD color-region clue")
	game.localization.set_locale("zh")
	game._load_level(0, false, LevelDirectorScript.schedule_for_display_level(game.levels, 1, {}))
	var wrong_cells := _first_non_solution_cells(game, game.INITIAL_HEART_COUNT)
	var wrong_cell: Vector2i = wrong_cells[0]
	var hearts_before_wrong: int = game.heart_count
	var crown_find_count_before_wrong: int = game.crown_find_count
	game._on_cell_double_pressed(wrong_cell.y, wrong_cell.x)
	assert(game.cell_states[wrong_cell.y][wrong_cell.x] == "wrong", "Double tap on a non-answer cell should mark a red X")
	assert(game.heart_count == hearts_before_wrong - 1, "Wrong crown attempts should consume one heart")
	assert(game.crown_find_count == crown_find_count_before_wrong, "Wrong crown attempts must not consume crown-find uses")
	assert(game.level_heart_slots[game.heart_count].get_theme_color("font_color") == game.HEART_EMPTY_COLOR, "A lost heart should turn gray")
	assert(game.level_heart_slots[game.heart_count].scale.is_equal_approx(Vector2.ONE), "A lost heart should stop at its normal scale")
	assert(game.level_heart_tweens[game.heart_count] == null, "A lost heart should stop pulsing")
	assert(game.level_heart_tweens[0] == null, "Remaining hearts should stay still after a lost heart")
	assert(not game.board.error_cells.has(wrong_cell), "Wrong crown attempts should not be treated as rule-conflict crowns")
	assert(not game.is_failed, "A single wrong crown attempt should not fail the level while hearts remain")
	game._on_cell_pressed(wrong_cell.y, wrong_cell.x)
	assert(game.cell_states[wrong_cell.y][wrong_cell.x] == "wrong", "Single tap must not clear locked red X marks")
	game._on_cell_drag_started(wrong_cell.y, wrong_cell.x)
	game._on_cell_drag_ended()
	assert(game.cell_states[wrong_cell.y][wrong_cell.x] == "wrong", "Dragging from a locked red X must not erase it")
	for index in range(1, wrong_cells.size()):
		var next_wrong: Vector2i = wrong_cells[index]
		game._on_cell_double_pressed(next_wrong.y, next_wrong.x)
	assert(game.is_failed, "The level should fail when hearts reach zero")
	assert(game.completion_overlay.visible, "Failing the level should show the result overlay")
	assert(game.completion_title.text == "再试一次", "Failure title should match the new result-page copy")
	assert(game.completion_next_button.text == "重新挑战", "Failure primary action should restart the challenge")
	assert(game.completion_replay_button.text == "返回首页", "Failure secondary action should return home")
	game._completion_primary_pressed()
	assert(not game.is_failed, "Retrying should clear the failed state")
	assert(game.heart_count == game.current_heart_limit, "Retrying should restore the heart limit for the current display level")
	game._on_cell_double_pressed(wrong_cell.y, wrong_cell.x)
	assert(game.cell_states[wrong_cell.y][wrong_cell.x] == "wrong", "A wrong lion mark should remain locked without a clear tool")
	game._prepare_failure_result_page()
	game.completion_overlay.show()
	game._completion_secondary_pressed()
	assert(game.home_screen.visible, "Failure secondary action should return to the home screen")
	game.resume_level_id = int(game.current_level["levelId"])
	game.resume_completed = false
	game.resume_states = game.cell_states.duplicate(true)
	game._load_level(0, true, LevelDirectorScript.schedule_for_display_level(game.levels, 1, {}))
	assert(game.cell_states[int(king_position[0])][int(king_position[1])] == "king", "Fixed opening levels should still show the opening king after restore")
	assert(_count_state(game.cell_states, "blocked") == 0, "Fixed opening levels should not restore old X marks")
	assert(_count_state(game.cell_states, "wrong") == 0, "Fixed opening levels should not restore old wrong marks")

	game.crown_find_count = game.INITIAL_CROWN_FIND_COUNT
	game._update_crown_find_button()
	var direct_target := _first_empty_solution_vector(game)
	game._use_crown_find()
	assert(game.cell_states[direct_target.y][direct_target.x] == "hint", "Crown find should directly place a locked crown on a solution cell")
	assert(game.crown_find_count == game.INITIAL_CROWN_FIND_COUNT - 1, "Crown find should consume one use")
	assert(game._piece_positions().has(direct_target), "Crown find result should count as a placed crown")
	while game.crown_find_count > 0:
		game._use_crown_find()
	assert(game.crown_find_count == 0, "Crown find count should stop at zero")
	assert(not game.crown_find_button.disabled, "Crown find should remain available for coins after free uses are exhausted")
	assert(str(game.crown_find_button_label.text).contains("-"), "Crown find should display its current coin price")
	var pieces_before_shortage: int = game._piece_positions().size()
	game.coin_count = 0
	game._use_crown_find()
	assert(game._piece_positions().size() == pieces_before_shortage, "Insufficient coins must not place a crown")
	assert(game.dialog_controller.is_dialog_open("coin_shortage"), "Insufficient coins should offer voluntary purchase and rewarded-ad routes")
	assert(game.pending_coin_tool == CoinEconomyScript.TOOL_CROWN_FIND, "Coin shortage dialog should retain the requested tool")
	assert(game.pending_rewarded_coin_grant > 0 and game.pending_rewarded_coin_grant <= game.pending_coin_price, "Rewarded-ad grant should cover the shortage without exceeding the requested tool price")
	var shortage_later_button: Button = game.dialog_controller.find_child("DialogAction_later", true, false)
	assert(shortage_later_button != null, "Coin shortage should expose all actions through the shared controller")
	shortage_later_button.pressed.emit()
	var locked_hints_before_clear := _count_state(game.cell_states, "hint")
	var mark_before_hint_clear := _first_empty_non_king_cell(game)
	game.cell_states[mark_before_hint_clear.y][mark_before_hint_clear.x] = "blocked"
	game.board.set_states(game.cell_states)
	game._validate_and_update(false)
	game._clear_board()
	assert(game.crown_find_count == 0, "Clearing the board should not restore crown find uses")
	assert(game.cell_states[mark_before_hint_clear.y][mark_before_hint_clear.x] == "empty", "Clear should execute when a normal mark exists beside crown-find results")
	assert(_count_state(game.cell_states, "hint") == locked_hints_before_clear, "Clear must preserve locked crown-find results")

	game.hint_count = 3
	game._update_hint_button()
	var coins_before: int = game.coin_count
	var hints_before: int = game.hint_count
	game._use_hint()
	assert(game._piece_positions().size() == 1 + locked_hints_before_clear, "Hint should teach without placing a new piece")
	assert(game.board.guide_cells.size() >= 1, "Hint must highlight the best next reasoning step")
	assert(game.board.guide_mask_enabled, "Formal hints should keep the standard non-target mask")
	assert(game.board.guide_pulse_cells.is_empty() and game.board.guide_pulse_tween == null, "Hint cells should not receive halo or flashing animation")
	var guide_target := Vector2i(-1, -1)
	for guide_cell in game.board.guide_cells.keys():
		assert(game.board._guide_kind(guide_cell) == "exclude_empty", "Formal hint ranges should contain X targets only")
		assert(game.cell_states[guide_cell.y][guide_cell.x] == "empty", "Formal hint targets should be empty before interaction")
		assert(not game._is_solution_cell(guide_cell.y, guide_cell.x), "Formal hint targets must never be crown solution cells")
		assert(game.board._guide_cell_is_actionable(guide_cell), "Every visible formal hint target should be actionable")
		if guide_target.x < 0 and game.board._guide_cell_is_actionable(guide_cell):
			guide_target = guide_cell
	assert(guide_target.x >= 0 and game.board._interaction_allowed_for_cell(guide_target), "Actionable hint target cells should remain interactive")
	for guide_cell in game.board.guide_cells.keys():
		assert(game.board._cell_is_attention_target(guide_cell), "All hint guide cells should remain visually unmasked")
	var marked_cell: Vector2i = game._piece_positions()[0]
	assert(game.board._cell_is_attention_target(marked_cell), "Existing crowns should remain visually unmasked during hints")
	var masked_cell := Vector2i(-1, -1)
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			var candidate := Vector2i(col, row)
			if not game.board._cell_is_attention_target(candidate):
				masked_cell = candidate
				break
		if masked_cell.x >= 0:
			break
	assert(masked_cell.x >= 0 and not game.board._interaction_allowed_for_cell(masked_cell), "Cells outside the hint range should be masked and non-interactive")
	assert(not game.coach_panel.visible, "Hints should use board visuals without showing explanatory text")
	assert(game.hint_count == hints_before - 1, "Hint must consume one available use")
	assert(game.coin_count == coins_before, "Free hint uses must not charge coins")
	game._on_cell_pressed(guide_target.y, guide_target.x)
	assert(game.cell_states[guide_target.y][guide_target.x] == "blocked", "Clicking a formal hint target should draw an X")

	var crown_only_states: Array = game._blank_states(int(game.current_level["rows"]), int(game.current_level["cols"]))
	var solution_cells: Array[Vector2i] = []
	for coordinate in game.current_level["solution"]:
		solution_cells.append(Vector2i(int(coordinate[1]), int(coordinate[0])))
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if not solution_cells.has(Vector2i(col, row)):
				crown_only_states[row][col] = "blocked"
	game.cell_states = crown_only_states
	game._apply_king_positions_to_state()
	game.board.set_states(game.cell_states)
	game.board.set_guides({})
	assert(game._build_best_next_hint().is_empty(), "A board with only crown candidates should not produce a formal hint")
	var no_x_hint_count: int = game.hint_count
	game._use_hint()
	assert(game.hint_count == no_x_hint_count, "Hint uses should not be consumed when no non-crown X target exists")

	game._load_level(0)
	var completion_coins_before: int = game.coin_count
	var expected_completion_reward := CoinEconomyScript.completion_reward(
		int(game.current_level["rows"]),
		game.active_king_positions.size(),
		0
	)
	for coordinate in game.current_level["solution"]:
		game._on_cell_double_pressed(int(coordinate[0]), int(coordinate[1]))
	assert(game.is_completed, "A valid solution must complete the level")
	assert(game.coin_count == completion_coins_before + expected_completion_reward, "Completion should grant the dynamic coin reward")
	assert(int(game.economy_progress["totalCoinEarned"]) >= expected_completion_reward, "Economy progress should retain earned-coin totals")

	await create_timer(1.2).timeout
	assert(not game.result_reward_label.visible, "Success result should not show an unused crown reward")
	assert(game.result_piece_icon.texture in game.LION_KING_VICTORY_FRAMES, "Success result should animate with the lion wave frames")
	assert(game.result_lion_wave_tween != null, "Success result should run the lion wave animation")
	assert(game.result_lion_animation_name in ["wave", "tongue", "funny"], "Success result should randomly choose a supported lion animation")
	assert(game.result_piece_icon.scale.is_equal_approx(Vector2.ONE), "Success lion should keep a fixed body scale")
	assert(is_zero_approx(game.result_piece_icon.rotation), "Success lion should keep a fixed body position without rotation")
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


func _first_empty_solution_vector(game) -> Vector2i:
	for coordinate in game.current_level["solution"]:
		var row := int(coordinate[0])
		var col := int(coordinate[1])
		if str(game.cell_states[row][col]) == "empty":
			return Vector2i(col, row)
	assert(false, "Test level should have at least one empty solution cell")
	return Vector2i(-1, -1)


func _first_non_solution_cells(game, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if game._is_king_cell(row, col) or game._is_solution_cell(row, col):
				continue
			if str(game.cell_states[row][col]) != "empty":
				continue
			result.append(Vector2i(col, row))
			if result.size() == count:
				return result
	assert(false, "Test level should have enough non-solution cells for wrong crown attempts")
	return result


func _first_adjacent_region_pair(regions: Array) -> Array:
	for row in range(regions.size()):
		for col in range(regions[row].size() - 1):
			if int(regions[row][col]) != int(regions[row][col + 1]):
				return [row, col, row, col + 1]
	for row in range(regions.size() - 1):
		for col in range(regions[row].size()):
			if int(regions[row][col]) != int(regions[row + 1][col]):
				return [row, col, row + 1, col]
	return []


func _first_empty_non_king_cell(game) -> Vector2i:
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if game._is_king_cell(row, col):
				continue
			if str(game.cell_states[row][col]) == "empty":
				return Vector2i(col, row)
	assert(false, "Test level should have at least one empty editable cell")
	return Vector2i(-1, -1)


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
