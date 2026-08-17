extends SceneTree

const LevelDirectorScript = preload("res://scripts/level_director.gd")
const CoinEconomyScript = preload("res://scripts/coin_economy.gd")
const CoinRewardPolicyScript = preload("res://scripts/coin_reward_policy.gd")
const UITokensScript = preload("res://scripts/ui_tokens.gd")
const CoinRollDisplayScript = preload("res://scripts/components/coin_roll_display.gd")
const CoinIconResourceScript = preload("res://scripts/components/coin_icon_resource.gd")
const SAVE_PATH := "user://smoke_test_save.json"


func _initialize() -> void:
	ProjectSettings.set_setting("color_king/testing/save_path", SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	call_deferred("_run")


func _run() -> void:
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
	assert(game.home_screen.get_script() == load("res://scripts/pages/home_page.gd"), "Home UI should be owned by the independent home page")
	assert(game.game_screen != null, "Game screen should exist")
	assert(game.formal_level_page != null and game.composite_level_page != null, "Formal and composite gameplay should use independent page instances")
	assert(game.game_screen == game.formal_level_page and not game.composite_level_page.visible, "Ordinary levels should bind main flow to the formal level page")
	assert(game.result_page != null and game.completion_overlay == game.result_page, "Completion, failure and deadlock states should share the independent result page")
	assert(game.help_content.get_script() == load("res://scripts/dialogs/help_dialog_content.gd"), "Help content should be independent from the app flow controller")
	assert(game.level_select_content.get_script() == load("res://scripts/dialogs/level_select_dialog_content.gd"), "Level selection content should be independent from the app flow controller")
	assert(game.settings_content.get_script() == load("res://scripts/dialogs/settings_dialog_content.gd"), "Settings content should be independent from the app flow controller")
	assert(game.opening_king_overlay.get_script() == load("res://scripts/overlays/opening_king_overlay.gd"), "Opening king presentation should be owned by an independent overlay")
	assert(game.tutorial_overlay.get_script() == load("res://scripts/overlays/tutorial_overlay.gd"), "Tutorial pointer and center feedback should be owned by an independent overlay")
	assert(game.feedback_layer.get_script() == load("res://scripts/overlays/feedback_layer.gd"), "Global toast feedback should be owned by an independent layer")
	assert(game.tutorial_controller.get_script() == load("res://scripts/controllers/tutorial_controller.gd"), "Tutorial session state should be owned by the tutorial controller")
	assert(game.tutorial_controller.has_method("double_press") and game.tutorial_controller.has_method("settle_after_exclusions") and game.tutorial_controller.has_method("undo"), "Tutorial controller should own the single-map state transitions and history")
	assert(game.formal_controller.get_script() == load("res://scripts/controllers/formal_game_controller.gd"), "Formal board mutations and history should be owned by the formal game controller")
	assert(game.composite_controller.get_script() == load("res://scripts/controllers/composite_game_controller.gd"), "Composite placement state should be owned by the composite controller")
	assert(game.hint_engine.get_script() == load("res://scripts/controllers/hint_engine.gd"), "Formal hint filtering and session state should be owned by the hint engine")
	assert(game.hint_engine.has_method("prepare") and game.hint_engine.has_method("build_formal_x_hint"), "Hint engine should own the complete formal strategy pipeline")
	assert(not game.has_method("_best_locked_candidate_hint") and not game.has_method("_best_exclusion_hint"), "Main flow should not retain concrete formal hint algorithms")
	assert(game.player_wallet.get_script() == load("res://scripts/services/player_wallet.gd"), "Coin balance and tool transactions should be owned by the player wallet")
	assert(load("res://scripts/rules/crown_rule_engine.gd").is_completed(game.current_level, game.cell_states) == false, "Crown rule engine should evaluate board completion independently")
	assert(load("res://scripts/storage/game_save_service.gd").states_match_size(game.cell_states, int(game.current_level["rows"]), int(game.current_level["cols"])), "Save service should validate board state dimensions")
	assert(game.save_repository.get_script() == load("res://scripts/storage/save_repository.gd"), "Save file IO should be isolated behind the save repository")
	assert(game.game_screen.has_method("present_tool"), "Level pages should own tool copy, price pill, disabled state and visual styling")
	assert(game.game_screen.coin_roll_display.get_script() == CoinRollDisplayScript, "The level header should use the shared coin roller")
	assert(game.result_page.result_coin_roll_display.get_script() == CoinRollDisplayScript, "The result page should use the shared coin roller")
	assert(game.progress_bar != null and game.progress_label != null, "Level screen should show crown progress")
	assert(CoinIconResourceScript.texture() != null, "Coin balance should generate its texture from the SVG coin source")
	assert(game.LION_KING_ICON != null, "Core game pieces should use the lion king texture")
	assert(game.LION_KING_WRONG_ICON != null, "Wrong placements should use the worried lion texture")
	assert(game.LION_KING_VICTORY_ICON != null, "Completion should use the standing lion texture")
	assert(game.LION_KING_VICTORY_FRAMES.size() == 9, "Completion lion should provide wave and expression animation frames")
	assert(game.board.PIECE_TEXTURE == game.LION_KING_ICON, "Board pieces and UI should share the same lion king texture")
	assert(game.board.WRONG_PIECE_TEXTURE == game.LION_KING_WRONG_ICON, "Wrong board pieces and UI should share the worried lion texture")
	assert(game.board.HAPPY_PIECE_TEXTURE.resource_path == "res://assets/ui/lion_king_happy.svg", "Correct crown feedback should preload the dedicated happy lion expression")
	var ui_asset_directory := DirAccess.open("res://assets/ui")
	assert(ui_asset_directory != null, "Runtime UI asset directory should be readable")
	if ui_asset_directory:
		for ui_asset_name in ui_asset_directory.get_files():
			assert(not ui_asset_name.to_lower().ends_with(".png"), "Runtime UI assets must use SVG instead of PNG: %s" % ui_asset_name)
	var level_coin_icon := game.coin_balance_roll_clip.get_parent().get_node_or_null("CoinIcon") as TextureRect
	assert(level_coin_icon != null and level_coin_icon.texture != null, "Level coin balance should render the SVG coin icon beside its rolling value")
	var level_coin_display = game.game_screen.coin_roll_display
	var result_coin_display = game.result_page.result_coin_roll_display
	assert(level_coin_display.primary_label.get_theme_font_size("font_size") >= 23, "The level balance should use a readable mobile font size")
	assert(result_coin_display.primary_label.get_theme_font_size("font_size") >= 30, "The result balance should use a large reward font size")
	assert(level_coin_display.counter_height() >= 44.0 and result_coin_display.counter_height() >= 48.0, "Coin clips should include vertical font and shadow safety space")
	assert(level_coin_display.counter_width() >= 62.0, "The level coin clip should retain its compact five-digit width")
	var result_balance_profiles := {
		0: [38, 42.0],
		8: [38, 42.0],
		18: [36, 58.0],
		108: [34, 76.0],
		999: [34, 76.0],
		1000: [32, 94.0],
		99999: [29, 108.0],
		999999: [26, 122.0],
		9999999: [23, 122.0],
	}
	for balance in result_balance_profiles.keys():
		level_coin_display.set_value(balance)
		result_coin_display.set_value(balance)
		assert(level_coin_display.primary_label.text == str(balance), "The level balance should display %d without truncation" % balance)
		assert(result_coin_display.primary_label.text == str(balance), "The result balance should display %d without truncation" % balance)
		assert(level_coin_display.labels_fit_clip() and result_coin_display.labels_fit_clip(), "Both balance labels should remain inside their metric-sized clips")
		assert(not level_coin_display.secondary_label.visible and not result_coin_display.secondary_label.visible, "Static balance updates should hide the spare rolling label")
		assert(is_zero_approx(level_coin_display.primary_label.position.y) and is_zero_approx(level_coin_display.secondary_label.position.y), "Static level balance updates should reset both rolling offsets")
		assert(is_zero_approx(result_coin_display.primary_label.position.y) and is_zero_approx(result_coin_display.secondary_label.position.y), "Static result balance updates should reset both rolling offsets")
		var expected_profile: Array = result_balance_profiles[balance]
		assert(result_coin_display.active_font_size() == int(expected_profile[0]), "Result balance %d should use its digit-count font profile" % balance)
		assert(result_coin_display.counter_width() >= float(expected_profile[1]), "Result balance %d should reserve its digit-count width" % balance)
	assert(level_coin_display.primary_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and level_coin_display.primary_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "The level balance should be centered in both axes")
	assert(result_coin_display.primary_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and result_coin_display.primary_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "The result balance should align toward the coin while remaining vertically centered")
	assert(result_coin_display.coin_icon.custom_minimum_size.x >= 44.0, "The result reward coin should remain visually prominent")
	assert(result_coin_display.primary_label.get_theme_constant("outline_size") >= 1, "The result balance should use a stable bold treatment")
	assert(result_coin_display.get_theme_constant("separation") == 0, "An explicit spacer should own the result coin gap instead of a theme separation")
	assert(result_coin_display.content_gap_spacer != null, "The result coin display should include an explicit icon-to-number spacer")
	assert(result_coin_display.configured_content_gap() == game.result_page.RESULT_COIN_BALANCE_GAP, "The result coin spacer should keep the approved fixed width")
	assert(result_coin_display.primary_label.position.x >= 8.0, "The result number should keep inner padding in addition to the container separation")
	var level_top_row: HBoxContainer = level_coin_display.get_parent().get_parent().get_parent()
	assert(level_top_row.get_combined_minimum_size().x <= 528.0, "The enlarged five-digit coin badge should still fit the 540px level header")
	assert(result_coin_display.get_combined_minimum_size().x <= 480.0, "The five-digit result balance should remain inside the result card safe width")
	result_coin_display.set_value(99)
	result_coin_display.animate_reel_to(100, 0.12)
	assert(result_coin_display.active_digit_count() == 3 and result_coin_display.active_font_size() == 34, "A 99-to-100 reel should lock the three-digit layout before moving")
	await create_timer(0.16).timeout
	result_coin_display.set_value(100)
	result_coin_display.animate_reel_to(99, 0.12)
	assert(result_coin_display.active_digit_count() == 3 and result_coin_display.active_font_size() == 34, "A 100-to-99 reel should keep the three-digit layout while moving")
	await create_timer(0.16).timeout
	assert(result_coin_display.active_digit_count() == 2 and result_coin_display.active_font_size() == 36, "A decreasing reel should shrink only after stopping at the final balance")
	game.layout_direction = Control.LAYOUT_DIRECTION_RTL
	await process_frame
	assert(level_coin_display.layout_direction == Control.LAYOUT_DIRECTION_LTR and result_coin_display.layout_direction == Control.LAYOUT_DIRECTION_LTR, "Coin icon and number order should stay LTR in RTL locales")
	game.layout_direction = Control.LAYOUT_DIRECTION_INHERITED
	level_coin_display.set_value(99)
	level_coin_display.animate_to(108, 0.36)
	await create_timer(0.06).timeout
	level_coin_display.set_value(99999)
	assert(level_coin_display.primary_label.text == "99999" and not level_coin_display.secondary_label.visible, "A static update should safely interrupt and reset an active coin roll")
	assert(is_zero_approx(level_coin_display.primary_label.position.y), "An interrupted coin roll should restore the visible label to y=0")
	result_coin_display.set_value(10)
	result_coin_display.roll_step_to(11, 0.12)
	result_coin_display.roll_step_to(12, 0.12)
	assert(result_coin_display.queued_step_count() == 2, "Dense coin arrivals should queue instead of interrupting the active digit roll")
	await create_timer(0.16).timeout
	assert(result_coin_display.displayed_value() == 11 and result_coin_display.queued_step_count() == 1, "Queued coin rolls should finish in arrival order")
	await create_timer(0.14).timeout
	assert(result_coin_display.displayed_value() == 12 and result_coin_display.queued_step_count() == 0, "The coin roll queue should drain to the final balance")
	assert(result_coin_display.primary_label.text == "12" and not result_coin_display.secondary_label.visible, "A drained roll queue should normalize the final visible label")
	result_coin_display.set_value(20)
	var reel_finished_state := {"target": -1}
	var reel_notch_state := {"count": 0, "indices": []}
	result_coin_display.roll_finished.connect(func(value: int) -> void: reel_finished_state["target"] = value)
	result_coin_display.reel_notch.connect(func(_value: int, step_index: int, _step_count: int) -> void:
		reel_notch_state["count"] = int(reel_notch_state["count"]) + 1
		reel_notch_state["indices"].append(step_index)
	)
	result_coin_display.animate_reel_to(31, 0.48)
	await create_timer(0.18).timeout
	assert(result_coin_display.displayed_value() not in [20, 31], "A result reel should skip through a bounded set of intermediate balances")
	await create_timer(0.36).timeout
	assert(result_coin_display.displayed_value() == 31 and not result_coin_display.secondary_label.visible, "A result reel should decelerate and normalize at the exact target balance")
	assert(int(reel_finished_state["target"]) == 31, "The result reel should emit its real completion event only after stopping at the exact target balance")
	assert(int(reel_notch_state["count"]) == 4 and reel_notch_state["indices"] == [0, 1, 2, 3], "The reel should emit one synchronized notch per visible weighted step")
	assert(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 540 and int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 960, "Coin layouts should be tested against the Pixel-sized 540x960 viewport")
	game._update_coin_label()
	result_coin_display.set_value(0)
	assert(game.opening_king_overlay != null, "Level screen should provide an opening king overlay")
	assert(game.INK == UITokensScript.INK, "Main UI should use the shared ink token")
	assert(game.REGION_COLORS == UITokensScript.REGION_COLORS, "Main UI should use the shared region palette")
	assert(game.board.BOARD_INK == UITokensScript.INK, "Board symbols should use the shared ink token")
	assert(UITokensScript.BOARD_BORDER.a == 1.0, "Board borders should use a precomposed color with stable visual opacity")
	assert(is_equal_approx(UITokensScript.ATTENTION_MASK_COLOR.a, 0.70), "Hint masks should use the approved 70 percent opacity")
	assert(UITokensScript.board_border_width(5) == 4.0, "5x5 board border should follow the UI guide")
	assert(UITokensScript.board_border_width(7) == 3.0, "7x7 board border should follow the UI guide")
	assert(UITokensScript.board_border_width(9) == 2.0, "9x9 board border should follow the UI guide")
	assert(UITokensScript.CROWN_MAX_FONT_RATIO <= 0.72, "Opening crown scale should stay inside its cell")
	assert(CoinRewardPolicyScript.base_reward_for_display_level(1) == 1, "Opening levels should grant one base coin")
	var size_six_unlock := LevelDirectorScript.minimum_display_for_size(6)
	var size_seven_unlock := LevelDirectorScript.minimum_display_for_size(7)
	var size_eight_unlock := LevelDirectorScript.minimum_display_for_size(8)
	var size_nine_unlock := LevelDirectorScript.minimum_display_for_size(9)
	assert(CoinRewardPolicyScript.base_reward_for_display_level(size_six_unlock - 1) == 1 and CoinRewardPolicyScript.base_reward_for_display_level(size_six_unlock) == 2, "The 6x6 unlock should raise the base reward to two coins")
	assert(CoinRewardPolicyScript.base_reward_for_display_level(size_seven_unlock) == 3, "The 7x7 unlock should raise the base reward to three coins")
	assert(CoinRewardPolicyScript.base_reward_for_display_level(size_eight_unlock) == 4, "The 8x8 unlock should raise the base reward to four coins")
	assert(CoinRewardPolicyScript.base_reward_for_display_level(size_nine_unlock) == 5, "The 9x9 unlock should cap the base reward at five coins")
	assert(CoinRewardPolicyScript.completion_reward(1, 3, 3) == 2, "A no-heart-loss multi-heart completion should round its 1.3x reward upward")
	assert(CoinRewardPolicyScript.completion_reward(size_nine_unlock, 2, 2) == 7, "Excellent rewards should round five times 1.3 upward")
	assert(CoinRewardPolicyScript.completion_reward(size_nine_unlock, 2, 1) == 5, "A heart-loss completion should receive the base reward")
	assert(CoinRewardPolicyScript.completion_reward(size_nine_unlock, 1, 1) == 5, "Single-heart levels should not qualify for Excellent")
	var economy_test_progress := CoinEconomyScript.default_progress()
	assert(CoinEconomyScript.standard_tool_price(CoinEconomyScript.TOOL_HINT, 1) == 3, "A new user's hint fallback price should sum three one-coin rewards")
	assert(CoinEconomyScript.standard_tool_price(CoinEconomyScript.TOOL_CROWN_FIND, 1) == 6, "A new user's crown-find fallback price should sum six one-coin rewards")
	assert(CoinEconomyScript.standard_tool_price(CoinEconomyScript.TOOL_REVIVE, size_six_unlock) == 4, "Revive should retain a two-base price")
	assert(CoinEconomyScript.rewarded_ad_coin_grant(6, 0, 1) == 6, "A rewarded ad should cover a full tool shortage")
	assert(CoinEconomyScript.rewarded_ad_coin_grant(6, 5, 1) == 1, "A rewarded ad should grant at least one current base without over-funding the wallet")
	for completion_index in range(3):
		CoinEconomyScript.record_completion(economy_test_progress, completion_index + 1, completion_index + 1, 5, 3, 3, 2, 0)
	assert(CoinEconomyScript.tool_price(CoinEconomyScript.TOOL_HINT, 4, economy_test_progress, 0) == 6, "Hint pricing should sum the latest three actual rewards")
	assert(CoinEconomyScript.tool_price(CoinEconomyScript.TOOL_CROWN_FIND, 4, economy_test_progress, 0) == 9, "Crown-find pricing should use three actual rewards and backfill the remaining three")
	assert(game.INITIAL_HINT_COUNT == 5 and game.INITIAL_CROWN_FIND_COUNT == 3, "New users should start with five hints and three crown finds")
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
	assert(game.settings_content.music_toggle != null and game.settings_content.sfx_toggle != null and game.settings_content.haptics_toggle != null, "Settings should expose music, sound-effects and haptics controls")
	assert(
		game.settings_content.music_toggle.text == game._t("开启")
		and game.settings_content.sfx_toggle.text == game._t("开启")
		and game.settings_content.haptics_toggle.text == game._t("开启"),
		"Enabled settings should render explicit readable localized state text: %s / %s / %s / expected %s" % [
			game.settings_content.music_toggle.text,
			game.settings_content.sfx_toggle.text,
			game.settings_content.haptics_toggle.text,
			game._t("开启"),
		]
	)
	assert(game.settings_content.sfx_toggle.custom_minimum_size.y >= 44.0, "Mobile settings toggles should preserve a reliable touch target")
	game.language_picker.select(game.localization.locale_index("ar"))
	game.settings_content.music_toggle.button_pressed = false
	game.settings_content.sfx_toggle.button_pressed = false
	game.settings_content.haptics_toggle.button_pressed = false
	var apply_language_button: Button = game.dialog_controller.find_child("DialogAction_apply", true, false)
	assert(apply_language_button != null, "Language settings should expose a standard apply action")
	apply_language_button.pressed.emit()
	await process_frame
	assert(game.selected_language == "ar" and game.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Arabic should apply RTL layout")
	assert(not game.music_enabled and not game.sfx_enabled and not game.haptics_enabled, "Music, sound effects and haptics settings should apply independently")
	assert(not game.board.haptics_enabled, "Disabling haptics should update the active board immediately")
	game.music_enabled = true
	game.sfx_enabled = true
	game.haptics_enabled = true
	game.audio_controller.set_audio_preferences(true, true, true)
	game.board.set_haptics_enabled(true)
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
	assert(game.level_heart_label.get_parent() != game.clear_button.get_parent(), "Level hearts should no longer occupy a bottom tool slot")
	assert(game.clear_button.get_parent() == game.crown_find_button.get_parent() and game.clear_button.get_parent() == game.hint_button.get_parent(), "Clear, crown find and hint should share the bottom tool bar")
	game.crown_find_count = game.INITIAL_CROWN_FIND_COUNT
	game.hint_count = game.INITIAL_HINT_COUNT
	game._update_crown_find_button()
	game._update_hint_button()
	assert(game.level_heart_slots.size() == game.INITIAL_HEART_COUNT, "The top heart badge should keep independent heart slots")
	assert(game.level_heart_tweens.is_empty(), "In-level hearts should remain static without background pulse tweens")
	for heart_index in range(game.level_heart_slots.size()):
		var heart_slot: Label = game.level_heart_slots[heart_index]
		assert(heart_slot.custom_minimum_size.x >= 32.0 and heart_slot.custom_minimum_size.y >= 38.0, "Heart slots should not be compressed")
		assert(heart_slot.scale.is_equal_approx(Vector2.ONE), "Every in-level heart should stay at its normal scale")
	for tool_button in [game.clear_button, game.crown_find_button, game.hint_button]:
		var tool_icon: Control = tool_button.find_child("ToolIcon", true, false)
		var tool_label: Label = tool_button.find_child("ToolLabel", true, false)
		assert(tool_icon != null and tool_label != null, "Every tool should expose a large icon and caption")
		assert(tool_icon.custom_minimum_size.x >= 44.0 and tool_icon.custom_minimum_size.y >= 44.0, "Tool icons should remain prominent inside the compact mobile toolbar")
		assert(tool_icon.position.y < tool_label.position.y, "Tool icons should render above their captions")
	assert(game.clear_button_label.text == "清除", "Clear should keep its primary label concise")
	assert(game.clear_status_label.text == "免费", "Clear should communicate its free status in the shared footer pill")
	assert(game.crown_find_button_label.text == "直找" and game.hint_button_label.text == "提示", "Tool names should not mix counts or prices into the primary label")
	assert(str(game.crown_find_status_label.text).contains("免费") and str(game.hint_status_label.text).contains("免费"), "Available tool uses should be displayed in the fixed status pill")
	assert(not game.crown_find_status_icon.visible and not game.hint_status_icon.visible, "Free tool uses should not imply an immediate coin charge")
	for tool_button in [game.clear_button, game.crown_find_button, game.hint_button]:
		var status_pill: PanelContainer = tool_button.find_child("ToolStatusPill", true, false)
		assert(status_pill != null and status_pill.custom_minimum_size.y >= 20.0, "Every tool should keep an aligned fixed-height status pill")
	game.localization.set_locale("en")
	await process_frame
	await process_frame
	assert(game.clear_button_label.text == "Clear", "Clear must follow the active English locale")
	assert(game.crown_find_button_label.text == "Find", "Crown finder must follow the active English locale")
	assert(game.hint_button_label.text == "Hint", "Hint must follow the active English locale")
	assert(game.clear_status_label.text == "Free", "The permanent free status must be localized")
	assert(game.crown_find_status_label.text == "Free ×%d" % game.crown_find_count, "Crown finder free uses must be localized")
	assert(game.hint_status_label.text == "Free ×%d" % game.hint_count, "Hint free uses must be localized")
	assert(game.settings_button.tooltip_text == "Settings" and game.help_button.tooltip_text == "View rules", "Top-bar tooltips must refresh with the locale")
	assert(game.help_tabs.get_tab_title(0) == "Rules" and game.help_tabs.get_tab_title(1) == "Block assembly", "Help tabs must refresh through the shared localization controller")
	game._on_help()
	await process_frame
	var localized_dialog_title: Label = game.dialog_controller.find_child("DialogTitle", true, false)
	var localized_dialog_action: Button = game.dialog_controller.find_child("DialogAction_close", true, false)
	assert(localized_dialog_title.text == "Rules" and localized_dialog_action.text == "Got it", "Raw dialog copy must be localized by DialogController")
	game.dialog_controller.hide_dialog(true)
	var saved_formal_snapshot: Dictionary = game.formal_progress_snapshot.duplicate(true)
	assert(game._capture_formal_progress_snapshot(), "Skip-tutorial localization requires a saved formal level fixture")
	game.in_tutorial = true
	game._request_skip_tutorial()
	await process_frame
	var skip_dialog_message := game.dialog_controller.find_child("DialogMessage", true, false) as Label
	var continue_tutorial_action := game.dialog_controller.find_child("DialogAction_continue", true, false) as Button
	var confirm_skip_action := game.dialog_controller.find_child("DialogAction_skip", true, false) as Button
	assert(localized_dialog_title.text == "Skip the tutorial?", "Skip-tutorial title must follow the active English locale")
	assert(skip_dialog_message.text == "You will return to your saved level and the tutorial will no longer open automatically.", "Skip-tutorial snapshot copy must not retain hard-coded Chinese")
	assert(continue_tutorial_action.text == "Continue" and confirm_skip_action.text == "Skip", "Skip-tutorial actions must follow the active English locale")
	game.dialog_controller.hide_dialog(true)
	await process_frame
	for locale in ["ar", "fr", "la"]:
		game.localization.set_locale(locale)
		game._request_skip_tutorial()
		await process_frame
		var localized_skip_actions: Array[Node] = game.dialog_controller._action_row.get_children()
		assert(localized_skip_actions.size() == 2, "Skip-tutorial dialog should expose two actions in locale %s" % locale)
		continue_tutorial_action = localized_skip_actions[0] as Button
		confirm_skip_action = localized_skip_actions[1] as Button
		assert(not _contains_cjk(localized_dialog_title.text), "Skip-tutorial title must not leak Chinese in locale %s" % locale)
		assert(not _contains_cjk(skip_dialog_message.text), "Skip-tutorial message must not leak Chinese in locale %s" % locale)
		assert(not _contains_cjk(continue_tutorial_action.text) and not _contains_cjk(confirm_skip_action.text), "Skip-tutorial actions must not leak Chinese in locale %s" % locale)
		game.dialog_controller.hide_dialog(true)
		await process_frame
	game.localization.set_locale("en")
	game.in_tutorial = false
	game.formal_progress_snapshot = saved_formal_snapshot
	var leaked_english_copy := _cjk_control_copy(game, game.language_picker)
	assert(leaked_english_copy.is_empty(), "English UI must not retain hard-coded CJK copy: %s" % ", ".join(leaked_english_copy))
	game.localization.set_locale("zh")
	await process_frame
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
	assert(game.level_select_picker.get_item_count() == 0, "Debug level choices should stay lazy until the dialog opens")
	game._open_level_select()
	assert(game.dialog_controller.is_dialog_open("level_select"), "Level selection dialog should open through the shared controller")
	assert(game.level_select_picker.get_item_count() == game.levels.size(), "Level selection should list all levels")
	game.level_select_picker.select(1)
	var enter_level_button: Button = game.dialog_controller.find_child("DialogAction_enter", true, false)
	assert(enter_level_button != null, "Level selection should expose the standard primary action")
	enter_level_button.pressed.emit()
	assert(int(game.current_level["levelId"]) == int(game.levels[1]["levelId"]), "Level selection should enter the selected level")
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
	var composite_unlock_display := int(LevelDirectorScript.SIZE_UNLOCK_DISPLAY_LEVELS[6])
	assert(composite_unlock_display == 11, "6x6 should unlock at display level 11 for the current testing cycle")
	assert(LevelDirectorScript.minimum_display_for_size(6) == composite_unlock_display, "The 6x6 unlock display should have one shared source of truth")
	assert(not LevelDirectorScript.is_size_unlocked(6, composite_unlock_display - 1), "6x6 should stay locked before its configured display level")
	assert(LevelDirectorScript.is_size_unlocked(6, composite_unlock_display), "6x6 should unlock at its configured display level")
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
	var size_six_probe_display := LevelDirectorScript.minimum_display_for_size(6) + 1
	var cold_size_progress := {"completedLevelIds": [], "recentRuns": [], "statsByArm": {}}
	var cold_size_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, size_six_probe_display, cold_size_progress)
	assert(str(cold_size_schedule.get("mode", "")) == "new_size_probe", "A newly unlocked size should enter the cold-start probe branch")
	assert(int(cold_size_schedule.get("selectedSize", 0)) == 6 and str(cold_size_schedule.get("selectedDifficulty", "")) == "medium", "A new size should prefer its Medium probe")
	var size_quota_stats := {}
	for size in [5, 6]:
		for difficulty in ["simple", "medium", "hard", "challenge"]:
			size_quota_stats["%d|%s" % [size, difficulty]] = {"plays": 12 if size == 5 else 1}
	var size_quota_progress := {"completedLevelIds": [], "recentRuns": [], "statsByArm": size_quota_stats}
	var size_quota_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, size_six_probe_display, size_quota_progress)
	assert(int(size_quota_schedule.get("selectedSize", 0)) == 6, "The size exposure quota should prioritize the under-exposed size")
	var no_tool_progress := {"completedLevelIds": [], "recentRuns": [
		{"size": 5, "toolUses": 0},
		{"size": 5, "toolUses": 0},
		{"size": 6, "toolUses": 0}
	], "statsByArm": {}}
	assert(LevelDirectorScript._no_tool_streak(no_tool_progress) == 3, "Three recent runs without tools should raise the difficulty pressure state")
	var recent_probe_stats := {}
	for size in [5, 6]:
		for difficulty in ["simple", "medium", "hard", "challenge"]:
			recent_probe_stats["%d|%s" % [size, difficulty]] = {"plays": 1 if not (size == 6 and difficulty == "hard") else 0}
	var recent_probe_progress := {"completedLevelIds": [], "recentRuns": [
		{"displayLevel": size_six_probe_display, "size": 6, "toolUses": 0},
		{"displayLevel": size_six_probe_display + 1, "size": 6, "toolUses": 0},
		{"displayLevel": size_six_probe_display + 2, "size": 6, "toolUses": 0}
	], "statsByArm": recent_probe_stats}
	var recent_probe_schedule := LevelDirectorScript.schedule_for_display_level(game.levels, size_six_probe_display + 2, recent_probe_progress)
	assert(int(recent_probe_schedule.get("selectedSize", 0)) == 6 and str(recent_probe_schedule.get("selectedDifficulty", "")) == "hard", "Three no-tool runs should raise the recent-size probe to Hard")
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
	assert(["5|challenge", "5|hard", "6|challenge", "6|hard"].has(challenge_arm), "Milestone should choose a supported hard or challenge arm from the currently unlocked sizes")
	var reward_progress := {"completedLevelIds": [], "recentRuns": [], "statsByArm": {}}
	LevelDirectorScript.record_completion(reward_progress, game.levels[0], LevelDirectorScript.schedule_for_display_level(game.levels, 1, {}), 2000.0, 10, 0, "2026-07-09", 1000)
	var reward_run: Dictionary = reward_progress["recentRuns"][0]
	var reward_before_bonus := float(reward_run["reward"])
	assert(float(reward_run["elapsedSeconds"]) == 900.0, "Reward elapsed time should be capped at 15 minutes")
	LevelDirectorScript.record_next_level_opened(reward_progress)
	assert(bool(reward_run["openedNextLevel"]) and float(reward_run["reward"]) > reward_before_bonus, "Opening the next level should add a reward bonus")
	assert(float(reward_progress["statsByArm"]["5|simple"].get("nextLevelA", 0.0)) > 1.0, "Opening the next level should update the Beta success posterior")
	LevelDirectorScript.record_completion(reward_progress, game.levels[1], LevelDirectorScript.schedule_for_display_level(game.levels, 2, {}), 100.0, 8, 0, "2026-07-09", 1200)
	var second_reward_run: Dictionary = reward_progress["recentRuns"][1]
	LevelDirectorScript.record_retention_if_needed(reward_progress, "2026-07-10", 1000 + 12 * 60 * 60)
	assert(bool(reward_run["retainedNextDay"]) and bool(second_reward_run["retainedNextDay"]), "Startup retention should mark every cross-day run within 24 hours")
	assert(float(reward_progress["statsByArm"]["5|simple"].get("retentionA", 0.0)) > 1.0, "Next-day retention should update the Beta retention posterior")
	assert(float(reward_progress["banditState"]["sizeAlpha"]["5"]) > 1.0, "User feedback should update the size Dirichlet exploration posterior")
	var reward_after_retention := float(reward_run["reward"])
	LevelDirectorScript.record_retention_if_needed(reward_progress, "2026-07-10", 1000 + 12 * 60 * 60)
	assert(float(reward_run["reward"]) == reward_after_retention, "Retention bonus should not be added twice")
	var expired_progress := {"completedLevelIds": [], "recentRuns": [], "statsByArm": {}}
	LevelDirectorScript.record_completion(expired_progress, game.levels[0], LevelDirectorScript.schedule_for_display_level(game.levels, 1, {}), 100.0, 8, 0, "2026-07-09", 1000)
	var expired_run: Dictionary = expired_progress["recentRuns"][0]
	LevelDirectorScript.record_retention_if_needed(expired_progress, "2026-07-10", 1000 + 24 * 60 * 60 + 1)
	assert(not bool(expired_run["retainedNextDay"]), "Retention bonus should expire after 24 hours")
	var failed_progress := {"completedLevelIds": [], "recentRuns": [], "statsByArm": {}}
	LevelDirectorScript.record_failure(failed_progress, game.levels[0], LevelDirectorScript.schedule_for_display_level(game.levels, 1, {}), 80.0, 4, 0, "2026-07-09", 1000)
	assert(float(failed_progress["statsByArm"]["5|simple"].get("completionB", 0.0)) > 1.0, "A failed level should update the Beta failure posterior")

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
	assert(game.board.reaction_kind == "correct" and game.board.reaction_cell == Vector2i(int(solution_cell[1]), int(solution_cell[0])), "Correct crowns should trigger the dedicated cheerful lion reaction")
	game._undo()
	assert(game.cell_states[int(solution_cell[0])][int(solution_cell[1])] == "empty", "Undo should remove the placed crown")
	var wrong_cells := _first_non_solution_cells(game, game.INITIAL_HEART_COUNT)
	var wrong_cell: Vector2i = wrong_cells[0]
	var hearts_before_wrong: int = game.heart_count
	var crown_find_count_before_wrong: int = game.crown_find_count
	game._on_cell_double_pressed(wrong_cell.y, wrong_cell.x)
	assert(game.cell_states[wrong_cell.y][wrong_cell.x] == "wrong", "Double tap on a non-answer cell should mark a red X")
	assert(game.board.shake_cell == wrong_cell, "Wrong crown attempts should trigger the board wrong-feedback shake")
	assert(game.board.reaction_kind == "wrong" and game.board.reaction_cell == wrong_cell, "Wrong crown attempts should temporarily show the worried lion reaction")
	assert(game.heart_count == hearts_before_wrong - 1, "Wrong crown attempts should consume one heart")
	assert(game.crown_find_count == crown_find_count_before_wrong, "Wrong crown attempts must not consume crown-find uses")
	assert(game.level_heart_slots[game.heart_count].get_theme_color("font_color") == game.HEART_EMPTY_COLOR, "A lost heart should turn gray")
	assert(game.level_heart_slots[game.heart_count].scale.is_equal_approx(Vector2.ONE), "A lost heart should remain at its normal scale")
	assert(game.level_heart_tweens.is_empty(), "Heart loss should not start or retain any in-level pulse tween")
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
	await process_frame
	var result_safe_width: float = game.completion_overlay.size.x - 60.0
	assert(game.result_page.reward_label.size.x <= result_safe_width + 1.0, "Failure result text must stay inside the mobile safe width")
	assert(game.completion_next_button.size.x <= result_safe_width + 1.0, "Failure result primary button must stay inside the mobile safe width")
	var revive_price: int = game._current_tool_price(CoinEconomyScript.TOOL_REVIVE)
	assert(game.completion_next_button.text == game._t("金币复活  -%d", [revive_price]), "Failure primary action should expose the current revive price")
	assert(game.completion_replay_button.text == game._t("重新挑战"), "Failure secondary action should restart without preserving the board")
	var failure_locale: String = game.localization.current_locale
	game.localization.set_locale("en")
	game._prepare_failure_result_page()
	assert(game.result_page.completion_title.text == "Challenge failed", "Failure title should follow the English locale")
	assert(game.result_page.result_reward_label.text == "No hearts left", "Failure reward text should follow the English locale")
	assert(game.result_page.result_tip_label.text == "Revive keeps the board and restores one heart.", "Failure explanation should follow the English locale")
	assert(game.completion_next_button.text == "Revive -%d" % revive_price, "Failure action should follow the English locale")
	assert(game.completion_replay_button.text == "Retry", "Failure retry action should follow the English locale")
	game.localization.set_locale(failure_locale)
	game._prepare_failure_result_page()
	var wrong_marks_before_revive := _count_state(game.cell_states, "wrong")
	game.coin_count = revive_price
	game._completion_primary_pressed()
	assert(not game.is_failed, "Coin revive should return the current run to a playable state")
	assert(game.heart_count == 1, "Coin revive should restore one heart")
	assert(_count_state(game.cell_states, "wrong") == wrong_marks_before_revive, "Coin revive should preserve the current board")
	assert(game.coin_count == 0, "Coin revive should reconcile its displayed price")
	assert(not game.completion_overlay.visible, "Coin revive should close the failure page")
	game._replay_level()
	assert(not game.is_failed, "Retrying should clear the failed state")
	assert(game.heart_count == game.current_heart_limit, "Retrying should restore the heart limit for the current display level")
	game._on_cell_double_pressed(wrong_cell.y, wrong_cell.x)
	assert(game.cell_states[wrong_cell.y][wrong_cell.x] == "wrong", "A wrong crown should be present before clearing")
	assert(not game.clear_button.disabled, "Clear should enable when only a wrong crown mark is removable")
	var hearts_before_clear: int = game.heart_count
	var clearable_piece: Array = _first_editable_solution_cell(game)
	game.cell_states[int(clearable_piece[0])][int(clearable_piece[1])] = "piece"
	var clearable_cell: Vector2i = _first_empty_non_king_cell(game)
	game.cell_states[clearable_cell.y][clearable_cell.x] = "blocked"
	game.board.set_states(game.cell_states)
	game._validate_and_update(false)
	assert(not game.clear_button.disabled, "Clear should enable when removable marks exist")
	var coins_before_clear: int = game.coin_count
	var exchanges_before_clear: int = game.run_coin_exchange_count
	var spent_before_clear := int(game.economy_progress.get("totalCoinSpent", 0))
	game._clear_board()
	assert(game.cell_states[wrong_cell.y][wrong_cell.x] == "empty", "Clear must remove wrong crown marks")
	assert(game.cell_states[clearable_cell.y][clearable_cell.x] == "empty", "Clear must remove normal X marks")
	assert(game.cell_states[int(clearable_piece[0])][int(clearable_piece[1])] == "empty", "Clear must remove normal crowns")
	assert(game._piece_positions().size() == 1, "Clear must keep the fixed opening king")
	assert(game.cell_states[int(king_position[0])][int(king_position[1])] == "king", "Clear must not remove the fixed king")
	assert(game.heart_count == hearts_before_clear, "Clearing wrong marks must not refund consumed hearts")
	assert(game.coin_count == coins_before_clear and game.run_coin_exchange_count == exchanges_before_clear, "Clear must not spend coins or record a tool exchange")
	assert(int(game.economy_progress.get("totalCoinSpent", 0)) == spent_before_clear, "Clear must not enter the coin-spend ledger")
	assert(game.clear_button.disabled, "Clear should disable after all removable marks are removed")
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
	assert(game.crown_find_button_label.text == "直找", "Crown find should not display an exhausted ×0 state")
	assert(game.crown_find_status_icon.visible and int(game.crown_find_status_label.text) > 0, "Crown find should replace the free status with its coin price")
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
	assert(game.board.guide_pulse_cells.size() >= 1 and game.board.guide_pulse_tween != null, "Hint primary cells should receive one soft halo animation")
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
	var remaining_hints_after_free_use: int = game.hint_count
	game.hint_count = 0
	game._update_hint_button()
	assert(game.hint_button_label.text == "提示", "Hint should not display an exhausted ×0 state")
	var hint_price: int = game._current_tool_price(CoinEconomyScript.TOOL_HINT)
	assert(game.hint_status_icon.visible and int(game.hint_status_label.text) == hint_price, "An exhausted hint should show its coin price even when the current balance cannot cover it")
	game.coin_count = hint_price
	game._update_hint_button()
	assert(game.hint_status_icon.visible and int(game.hint_status_label.text) == hint_price, "An exhausted hint should show its coin price when the balance can cover it")
	game.coin_count = 0
	game.game_screen.present_tool("hint", {"label": "提示", "status": "free_forever", "disabled": false})
	assert(game.hint_status_label.text == "免费", "The level page placeholder fixture should reproduce the stale Free state")
	game._validate_and_update(false)
	assert(game.hint_status_icon.visible and int(game.hint_status_label.text) == hint_price, "Level validation must replace the page placeholder with the real hint price")
	game.hint_count = remaining_hints_after_free_use
	game._update_hint_button()
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
	var result_sound_events: Array[String] = []
	var result_music_events: Array[String] = []
	game.result_page.sound_requested.connect(func(kind: String) -> void: result_sound_events.append(kind))
	game.result_page.music_requested.connect(func(kind: String) -> void: result_music_events.append(kind))
	var completion_coins_before: int = game.coin_count
	var expected_completion_reward := CoinRewardPolicyScript.completion_reward(
		game.player_level_number,
		game.current_heart_limit,
		game.heart_count
	)
	for coordinate in game.current_level["solution"]:
		game._on_cell_double_pressed(int(coordinate[0]), int(coordinate[1]))
	assert(game.is_completed, "A valid solution must complete the level")
	assert(game.coin_count == completion_coins_before + expected_completion_reward, "Completion should grant the dynamic coin reward")
	assert(int(game.economy_progress["totalCoinEarned"]) >= expected_completion_reward, "Economy progress should retain earned-coin totals")
	assert(game.board.victory_tween != null, "Completion should start the board victory timeline")
	assert(game.board.victory_origin.x >= 0, "The board victory wave should originate from the final lion")
	assert(game.board.victory_result_delay() >= game.board.VICTORY_TIMELINE_DURATION, "The result page should wait for the in-board celebration")

	await create_timer(game.board.victory_result_delay() + 0.18).timeout
	assert(game.result_page.completion_title.text == game._t("EXCELLENT"), "A no-heart-loss multi-heart completion should display Excellent")
	assert(game.result_page.result_is_excellent, "Excellent completion should enable the dedicated celebration state")
	assert(
		game.result_page.result_petals_layer.visible
		and game.result_page.result_petals_layer.get_child_count() == game.result_page.RESULT_PETAL_COUNT,
		"Excellent should play the complete falling-petal celebration"
	)
	assert(game.result_page.result_success_sequence_tween != null, "Excellent should own one serial celebration timeline")
	assert("celebration" in result_music_events, "Excellent should start the warm celebration cue with the petals")
	assert("coin_arrive" not in result_sound_events and "coin_reel" not in result_sound_events, "Coin sounds must not overlap the opening petal phase")
	assert(game.audio_controller.has_method("play_result_music"), "The audio controller should lazy-load the Excellent celebration cue")
	assert(game.audio_controller.RESULT_MUSIC_PATHS.has("celebration"), "Excellent should map to the packaged cheerful result cue")
	assert(game.result_page.RESULT_PETAL_SEQUENCE_DURATION >= 4.7 and game.result_page.RESULT_PETAL_SEQUENCE_DURATION <= 4.9, "The petal phase should stay readable without delaying the reward sequence")
	assert(game.result_page.RESULT_PETAL_FADE_FRACTION <= 0.16, "Petals should remain visible until they are close to the lion")
	var expected_petal_receiver: Vector2 = game.result_page._control_center_in_layer(
		game.result_page.result_piece_icon,
		game.result_page.result_petals_layer
	)
	var actual_petal_receiver: Vector2 = game.result_page._result_petal_receiver(game.result_page.size)
	assert(actual_petal_receiver.distance_to(expected_petal_receiver) < 0.5, "Falling petals should fade around the lion rather than the coin balance")
	var subtitle_center: Vector2 = game.result_page._control_center_in_layer(
		game.result_page.reward_label,
		game.result_page.result_petals_layer
	)
	assert(actual_petal_receiver.y > subtitle_center.y + game.result_page.reward_label.size.y * 0.5, "The resolved petal target must sit below the result header")

	await create_timer(
		game.result_page.RESULT_PETAL_SEQUENCE_DURATION
		+ game.result_page.RESULT_COIN_MAX_DURATION
		+ 0.12
	).timeout
	assert(game.result_page.result_coin_roll_row.visible and not game.result_page.result_reward_label.visible, "Success result should show the dedicated rolling coin reward")
	assert(game.result_page.result_coin_roll_display.visual_gap_from_icon_to_number() >= 35.5, "The visible result layout should preserve about 36px from the coin edge to the number start")
	assert(game.result_page.result_reward_coin_icon != null and game.result_page.result_reward_coin_icon.visible, "The result reward should use a coin icon without a text prefix")
	assert(game.result_page.result_coin_roll_row.get_child_count() == 3, "The reward row should contain the coin icon, explicit spacing, and rolling number")
	assert(game.result_page.result_coin_roll_primary.text == str(game.coin_count), "The result coin roller should finish at the player's current balance")
	assert(game.result_page.result_coin_tween != null, "Granted coins should use a lion-to-balance flight animation on the result page")
	assert(is_zero_approx(game.result_page.RESULT_COIN_START_DELAY), "Coin flight should begin immediately when the final petal phase ends")
	assert(result_sound_events.find("coin_arrive") < result_sound_events.find("coin_reel"), "Coin arrivals should complete before the reel sound begins")
	assert(result_sound_events.count("coin_reel") >= 1, "The result reel should emit tactile notch sounds from its real visual steps")
	assert(game.result_page.result_piece_icon.texture in game.LION_KING_VICTORY_FRAMES, "Success result should animate with the lion wave frames")
	assert(game.result_page.result_lion_wave_tween != null, "Success result should run the lion wave animation")
	assert(game.result_page.result_lion_animation_name in ["wave", "tongue", "funny"], "Success result should randomly choose a supported lion animation")
	assert(game.result_page.result_piece_icon.scale.is_equal_approx(Vector2.ONE), "Success lion should keep a fixed visual size without front-back pulsing")
	assert(is_zero_approx(game.result_page.result_piece_icon.rotation), "Success lion should keep a fixed body axis without rocking")
	game.current_heart_limit = 1
	game.heart_count = 1
	var manual_balance_after: int = game.coin_count
	var manual_balance_before: int = maxi(0, manual_balance_after - 5)
	game._prepare_success_result_page(5)
	await process_frame
	var expected_flight_source: Vector2 = game.result_page._control_point_in_flight_layer(
		game.result_page.result_piece_icon,
		Vector2(
			game.result_page.result_piece_icon.size.x * 0.70,
			game.result_page.result_piece_icon.size.y * 0.50 + 4.0
		)
	)
	var expected_flight_target: Vector2 = game.result_page._control_center_in_flight_layer(
		game.result_page.result_reward_coin_icon
	)
	var flight_layer_bounds := Rect2(Vector2.ZERO, game.result_page.result_coin_flight_layer.size)
	assert(flight_layer_bounds.has_point(expected_flight_source), "Reward coins should start from the lion inside the flight layer coordinate space")
	assert(flight_layer_bounds.has_point(expected_flight_target), "Reward coins should end at the balance coin icon inside the flight layer coordinate space")
	var manual_reward_stagger: float = minf(
		game.result_page.RESULT_COIN_FLIGHT_MAX_STAGGER,
		maxf(
			game.result_page.RESULT_COIN_FLIGHT_MIN_STAGGER,
			(
				game.result_page.RESULT_COIN_MAX_DURATION
					- game.result_page.RESULT_COIN_START_DELAY
					- game.result_page.RESULT_COIN_FLIGHT_DURATION
					- game.result_page.RESULT_COIN_REEL_DURATION
				- game.result_page.RESULT_COIN_REEL_SETTLE_HOLD
			) / 4.0
		)
	)
	var manual_flight_duration: float = (
		game.result_page.RESULT_COIN_START_DELAY
		+ game.result_page.RESULT_COIN_FLIGHT_DURATION
		+ manual_reward_stagger * 4.0
	)
	await create_timer(manual_flight_duration - 0.08).timeout
	assert(game.result_page.result_coin_roll_primary.text == str(manual_balance_before), "The result balance should stay at its initial value until every reward coin has arrived")
	await create_timer(0.38).timeout
	var rolling_values := [game.result_page.result_coin_roll_primary.text, game.result_page.result_coin_roll_secondary.text]
	assert(rolling_values.any(func(value: String) -> bool: return value not in [str(manual_balance_before), str(manual_balance_after)]), "The result reel should visibly pass a bounded intermediate balance after every reward coin arrives")
	assert(game.result_page.result_coin_flight_layer.get_child_count() == 0, "The balance reel should begin only after all reward coin flyers have completed")
	for flyer in game.result_page.result_coin_flight_layer.get_children():
		assert(flyer.size.is_equal_approx(game.result_page.RESULT_COIN_FLYER_SIZE), "Flying coin sprites must keep their mobile-sized bounds")
		assert(flyer.get_global_rect().intersects(game.completion_overlay.get_global_rect()), "Flying coin sprites must remain visible inside the result screen")
	assert(game.result_page.result_coin_roll_primary.scale == Vector2.ONE and game.result_page.result_coin_roll_secondary.scale == Vector2.ONE, "The coin roller must not use the old scale-recovery effect")
	await create_timer(game.result_page.RESULT_COIN_REEL_DURATION + 0.24).timeout
	assert(game.result_page.result_coin_roll_primary.text == str(manual_balance_after) and not game.result_page.result_coin_roll_secondary.visible, "The visible roller should finish at the player's current balance")
	assert(game.result_page.completion_title.text == game._t("GOOD"), "A single-heart completion should display Good")
	assert(not game.result_page.result_is_excellent, "Good completion should disable the Excellent-only celebration state")
	assert(not game.result_page.result_petals_layer.visible, "Good should stop and hide the falling-petal celebration")
	await create_timer(0.35).timeout
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


func _cjk_control_copy(root_node: Node, excluded_option_button: OptionButton) -> Array[String]:
	var leaked: Array[String] = []
	if root_node is Label or root_node is Button:
		var visible_text := str(root_node.get("text"))
		if _contains_cjk(visible_text):
			leaked.append("%s=%s" % [str(root_node.get_path()), visible_text])
	if root_node is Control:
		var tooltip := (root_node as Control).tooltip_text
		if _contains_cjk(tooltip):
			leaked.append("%s.tooltip=%s" % [str(root_node.get_path()), tooltip])
	if root_node is OptionButton and root_node != excluded_option_button:
		var option_button := root_node as OptionButton
		for item_index in range(option_button.item_count):
			var item_text := option_button.get_item_text(item_index)
			if _contains_cjk(item_text):
				leaked.append("%s.item%d=%s" % [str(root_node.get_path()), item_index, item_text])
	if root_node is TabContainer:
		var tabs := root_node as TabContainer
		for tab_index in range(tabs.get_tab_count()):
			var tab_title := tabs.get_tab_title(tab_index)
			if _contains_cjk(tab_title):
				leaked.append("%s.tab%d=%s" % [str(root_node.get_path()), tab_index, tab_title])
	for child in root_node.get_children():
		leaked.append_array(_cjk_control_copy(child, excluded_option_button))
	return leaked


func _contains_cjk(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint >= 0x3400 and codepoint <= 0x9FFF:
			return true
	return false


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
