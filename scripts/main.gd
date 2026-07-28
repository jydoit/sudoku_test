extends Control

const LevelStoreScript = preload("res://scripts/level_store.gd")
const GameBoardScript = preload("res://scripts/game_board.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")
const CoinEconomyScript = preload("res://scripts/coin_economy.gd")
const UITokensScript = preload("res://scripts/ui_tokens.gd")
const ToolIconScript = preload("res://scripts/tool_icon.gd")
const RuleIllustrationScript = preload("res://scripts/rule_illustration.gd")
const DialogControllerScript = preload("res://scripts/dialog_controller.gd")
const LocalizationControllerScript = preload("res://scripts/localization_controller.gd")
const AudioControllerScript = preload("res://scripts/audio_controller.gd")
const CompositeLevelScript = preload("res://scripts/composite_level.gd")
const AssemblyViewScript = preload("res://scripts/assembly_view.gd")
const UI_FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.ttf")
const ARABIC_FONT: Font = preload("res://assets/fonts/NotoSansArabic-Regular.ttf")
const COIN_ICON = preload("res://assets/ui/coin.png")
const LION_KING_ICON = preload("res://assets/ui/lion_king.png")
const LION_KING_WRONG_ICON = preload("res://assets/ui/lion_king_wrong.png")
const LION_KING_VICTORY_ICON = preload("res://assets/ui/lion_king_victory.png")
const LION_KING_VICTORY_OUT_ICON = preload("res://assets/ui/lion_king_victory_out.png")
const LION_KING_VICTORY_IN_ICON = preload("res://assets/ui/lion_king_victory_in.png")
const LION_KING_VICTORY_WAVE_OUT_MID_ICON = preload("res://assets/ui/lion_king_victory_wave_out_mid.png")
const LION_KING_VICTORY_WAVE_IN_MID_ICON = preload("res://assets/ui/lion_king_victory_wave_in_mid.png")
const LION_KING_VICTORY_TONGUE_PEEK_ICON = preload("res://assets/ui/lion_king_victory_tongue_peek.png")
const LION_KING_VICTORY_TONGUE_OUT_ICON = preload("res://assets/ui/lion_king_victory_tongue_out.png")
const LION_KING_VICTORY_WINK_ICON = preload("res://assets/ui/lion_king_victory_wink.png")
const LION_KING_VICTORY_FUNNY_ICON = preload("res://assets/ui/lion_king_victory_funny.png")
const LION_KING_VICTORY_FRAMES = [
	LION_KING_VICTORY_ICON,
	LION_KING_VICTORY_OUT_ICON,
	LION_KING_VICTORY_IN_ICON,
	LION_KING_VICTORY_WAVE_OUT_MID_ICON,
	LION_KING_VICTORY_WAVE_IN_MID_ICON,
	LION_KING_VICTORY_TONGUE_PEEK_ICON,
	LION_KING_VICTORY_TONGUE_OUT_ICON,
	LION_KING_VICTORY_WINK_ICON,
	LION_KING_VICTORY_FUNNY_ICON
]
const SAVE_PATH := "user://color_queens_save.json"
const SAVE_VERSION := 11
const INITIAL_HINT_COUNT := 3
const INITIAL_HEART_COUNT := 3
const INITIAL_CROWN_FIND_COUNT := 3
const INK := UITokensScript.INK
const MUTED := UITokensScript.MUTED
const CREAM := UITokensScript.SURFACE_CREAM
const CARD := UITokensScript.SURFACE_CARD
const GREEN := UITokensScript.SUCCESS_GREEN
const HEART_ACTIVE_COLOR := Color("#F25D72")
const HEART_EMPTY_COLOR := Color("#C8CDD5")
const HEART_PULSE_STAGGER_SECONDS := 0.0
const COACH_TUTORIAL_SIZE := 19
const COACH_NORMAL_SIZE := 16
const TUTORIAL_PHASE_PLACE := 0
const TUTORIAL_PHASE_ADJACENT := 1
const TUTORIAL_PHASE_ROW_COL := 2
const TUTORIAL_PHASE_HINT := 3
const TUTORIAL_PHASE_HINT_PLACE := 4
const TUTORIAL_PHASE_CROWN_FIND := 5
const TUTORIAL_PHASE_DONE := 6
const REGION_COLOR_NAMES = UITokensScript.REGION_COLOR_NAMES
const REGION_COLORS = UITokensScript.REGION_COLORS

const TUTORIAL_LEVELS = [
	{
		"levelId": -101,
		"title": "新手教程",
		"name": "",
		"rows": 5,
		"cols": 5,
		"targetCount": 5,
		"tutorial": "每个颜色区域都要找到一个皇冠。现在这个区域只剩一个可选格，双击找到它。",
		"regions": [
			[3, 2, 2, 4, 4],
			[3, 2, 4, 4, 4],
			[3, 2, 1, 5, 5],
			[3, 3, 5, 5, 5],
			[3, 3, 5, 5, 5]
		],
		"solution": [[2, 2], [0, 1], [1, 4], [4, 3], [3, 0]],
		"target": [2, 2],
		"kind": "single_map"
	}
]

var levels: Array = []
var current_level_index := 0
var player_level_number := 1
var current_level: Dictionary = {}
var active_schedule: Dictionary = {}
var active_king_positions: Array = []
var cell_states: Array = []
var move_history: Array = []
var completed_levels: Array = []
var director_progress: Dictionary = {}
var economy_progress: Dictionary = CoinEconomyScript.default_progress()
var coin_count := 55
var heart_count := INITIAL_HEART_COUNT
var current_heart_limit := INITIAL_HEART_COUNT
var hint_count := INITIAL_HINT_COUNT
var crown_find_count := INITIAL_CROWN_FIND_COUNT
var immediate_errors := true
var is_completed := false
var is_failed := false
var active_hint_step: Dictionary = {}
var active_hint_stage := 0
var run_started_unix := 0
var run_move_count := 0
var run_hint_count := 0
var run_coin_exchange_count := 0
var resume_level_id := -1
var resume_states: Array = []
var resume_completed := false
var resume_failed := false
var formal_progress_snapshot: Dictionary = {}
var home_composite_progress_snapshot: Dictionary = {}
var home_composite_entry_active := false
var home_composite_round := 0
var resume_composite_state: Dictionary = {}
var composite_mode := false
var composite_phase := "crown"
var composite_data: Dictionary = {}
var composite_placements: Dictionary = {}
var composite_final_layout: Dictionary = {}
var composite_tutorial_seen := false
var composite_intro_running := false
var composite_intro_marks_seen := false
var tutorial_completed := false
var tutorial_started := false
var tutorial_step_index := 0
var tutorial_interaction_stage := 0
var tutorial_button_stage := 0
var tutorial_solution_index := 0
var tutorial_active_crown := Vector2i(-1, -1)
var tutorial_hint_target := Vector2i(-1, -1)
var tutorial_hint_button_taught := false
var tutorial_crown_find_taught := false
var in_tutorial := false
var tutorial_hand_cell := Vector2i(-1, -1)
var tutorial_hand_control: Control
var tutorial_hand_token := 0
var tutorial_focus_token := 0

var home_screen: Control
var game_screen: Control
var home_coin_label: Label
var home_heart_label: Label
var home_star_label: Label
var home_start_button: Button
var home_composite_button: Button
var level_select_button: Button
var settings_button: Button
var home_chest_label: Label
var board
var level_picker: OptionButton
var level_select_picker: OptionButton
var level_label: Label
var help_button: Button
var top_home_button: Button
var coin_label: Label
var level_heart_label: Control
var level_heart_slots: Array[Label] = []
var level_heart_tweens: Array = []
var progress_bar: ProgressBar
var progress_label: Label
var progress_row: Control
var action_bar: Control
var assembly_stage_label: Label
var assembly_view
var coach_panel: PanelContainer
var coach_label: Label
var opening_king_overlay: ColorRect
var opening_king_panel: PanelContainer
var opening_king_title: Label
var opening_king_count_label: Label
var opening_king_source_label: Control
var opening_king_source_count_label: Label
var undo_button: Button
var clear_button: Button
var clear_button_label: Label
var crown_find_button: Button
var crown_find_button_label: Label
var hint_button: Button
var hint_button_label: Label
var tutorial_skip_button: Button
var completion_overlay: ColorRect
var completion_title: Label
var reward_label: Label
var result_icon_label: Label
var result_piece_icon: TextureRect
var result_reward_label: Label
var result_tip_label: Label
var completion_next_button: Button
var completion_replay_button: Button
var toast_label: Label
var tutorial_center_popup: Label
var tutorial_hand_label: Label
var dialog_controller
var help_content: Control
var help_tabs: TabContainer
var level_select_content: Control
var settings_content: Control
var language_picker: OptionButton
var localization
var audio_controller
var selected_language := ""
var pending_coin_tool := ""
var pending_coin_price := 0
var pending_rewarded_coin_grant := 0
var toast_tween: Tween
var tutorial_center_tween: Tween
var tutorial_hand_tween: Tween
var opening_king_tween: Tween
var result_lion_tween: Tween
var result_lion_wave_tween: Tween
var result_lion_animation_name := ""
var opening_king_flyers: Array[TextureRect] = []
var opening_king_animation_token := 0
var drag_mode := ""
var drag_changed := false
var drag_cells := {}
var opening_king_reveal_pending := false
var result_overlay_mode := "success"



func _ready() -> void:
	levels = LevelStoreScript.load_levels()
	if levels.is_empty():
		_show_fatal_error("没有找到可用关卡")
		return
	_load_save()
	localization = LocalizationControllerScript.new()
	localization.initialize(selected_language)
	selected_language = localization.current_locale
	localization.locale_changed.connect(_on_locale_changed)
	audio_controller = AudioControllerScript.new()
	add_child(audio_controller)
	_configure_font_fallbacks()
	LevelDirectorScript.record_retention_if_needed(director_progress, _today_string(), int(Time.get_unix_time_from_system()))
	_build_ui()
	_apply_layout_direction()
	current_level_index = clampi(current_level_index, 0, levels.size() - 1)
	var resume_schedule := _schedule_for_current_level()
	current_level_index = int(resume_schedule.get("levelIndex", current_level_index))
	_load_level(current_level_index, true, resume_schedule)
	if tutorial_started:
		_show_home()
		_show_tutorial_resume_dialog()
	elif tutorial_completed:
		_show_home()
	else:
		_start_tutorial_step(0)


func _configure_font_fallbacks() -> void:
	if not UI_FONT.fallbacks.has(ARABIC_FONT):
		UI_FONT.fallbacks.append(ARABIC_FONT)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = CREAM
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	home_screen = _build_home_screen()
	add_child(home_screen)

	game_screen = _build_game_screen()
	add_child(game_screen)
	game_screen.hide()

	_build_opening_king_overlay()
	_build_completion_overlay()
	_build_toast()
	_build_tutorial_center_popup()
	_build_tutorial_hand_pointer()
	_build_dialog_controller()
	_build_help_dialog()
	_build_level_select_dialog()
	_build_settings_dialog()


func _build_home_screen() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var base := ColorRect.new()
	base.color = Color("#DDF5FF")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)

	var sky := ColorRect.new()
	sky.color = Color("#248DFF")
	sky.set_anchor(SIDE_RIGHT, 1.0)
	sky.set_anchor(SIDE_BOTTOM, 0.58)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)

	var glow := ColorRect.new()
	glow.color = Color("#8BD0FF")
	glow.set_anchor(SIDE_TOP, 0.42)
	glow.set_anchor(SIDE_RIGHT, 1.0)
	glow.set_anchor(SIDE_BOTTOM, 0.78)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)

	var floor := ColorRect.new()
	floor.color = Color("#DDF5FF")
	floor.set_anchor(SIDE_TOP, 0.72)
	floor.set_anchor(SIDE_RIGHT, 1.0)
	floor.set_anchor(SIDE_BOTTOM, 1.0)
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(floor)

	root.add_child(_build_home_castle())
	root.add_child(_build_home_primary_buttons())
	return root


func _build_home_top_resources() -> Control:
	var bar := HBoxContainer.new()
	bar.set_anchor(SIDE_LEFT, 0.0)
	bar.set_anchor(SIDE_RIGHT, 1.0)
	bar.offset_left = 18
	bar.offset_top = 18
	bar.offset_right = -18
	bar.offset_bottom = 62
	bar.add_theme_constant_override("separation", 8)

	home_coin_label = _coin_value_label(coin_count)
	bar.add_child(_coin_resource_badge(home_coin_label))

	home_heart_label = _resource_label("♥  %d" % heart_count, Color("#F06B78"))
	bar.add_child(home_heart_label)

	home_star_label = _resource_label("★  %d" % completed_levels.size(), Color("#5D74D9"))
	bar.add_child(home_star_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var settings := _small_button("⚙")
	settings.tooltip_text = "设置"
	settings.pressed.connect(_on_settings)
	bar.add_child(settings)
	return bar


func _build_home_castle() -> Control:
	var castle := VBoxContainer.new()
	castle.set_anchor(SIDE_LEFT, 0.08)
	castle.set_anchor(SIDE_TOP, 0.12)
	castle.set_anchor(SIDE_RIGHT, 0.92)
	castle.set_anchor(SIDE_BOTTOM, 0.56)
	castle.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "color king"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#FFE06F"))
	title.add_theme_color_override("font_shadow_color", Color(0.10, 0.23, 0.45, 0.30))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_font_size_override("font_size", 48)
	castle.add_child(title)

	var castle_body := _piece_texture_rect(Vector2(210, 210))
	castle_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	castle.add_child(castle_body)

	return castle


func _build_home_side_buttons() -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var daily := _floating_home_button("礼")
	daily.position = Vector2(18, 114)
	daily.tooltip_text = "每日奖励"
	daily.pressed.connect(func() -> void:
		coin_count += 10
		_update_coin_label()
		_update_home()
		_save_game()
		_show_toast("每日奖励：金币 +10")
	)
	layer.add_child(daily)

	var chest := _floating_home_button("箱")
	chest.position = Vector2(18, 176)
	chest.tooltip_text = "宝箱"
	chest.pressed.connect(func() -> void: _show_toast("继续通关，皇冠宝箱即将开启"))
	layer.add_child(chest)

	var editor := _floating_home_button("编")
	editor.position = Vector2(18, 238)
	editor.tooltip_text = "关卡编辑器"
	editor.pressed.connect(_open_level_editor)
	layer.add_child(editor)

	var event := _floating_home_button("!")
	event.set_anchor(SIDE_LEFT, 1.0)
	event.set_anchor(SIDE_RIGHT, 1.0)
	event.offset_left = -70
	event.offset_top = 136
	event.offset_right = -18
	event.offset_bottom = 188
	event.tooltip_text = "活动"
	event.pressed.connect(func() -> void: _show_toast("活动将在后续版本开放"))
	layer.add_child(event)

	var rank := _floating_home_button("榜")
	rank.set_anchor(SIDE_LEFT, 1.0)
	rank.set_anchor(SIDE_RIGHT, 1.0)
	rank.offset_left = -70
	rank.offset_top = 198
	rank.offset_right = -18
	rank.offset_bottom = 250
	rank.tooltip_text = "排行榜"
	rank.pressed.connect(func() -> void: _show_toast("排行榜将在后续版本开放"))
	layer.add_child(rank)
	return layer


func _build_home_primary_buttons() -> Control:
	var column := VBoxContainer.new()
	column.set_anchor(SIDE_LEFT, 0.0)
	column.set_anchor(SIDE_TOP, 0.63)
	column.set_anchor(SIDE_RIGHT, 1.0)
	column.set_anchor(SIDE_BOTTOM, 0.94)
	column.offset_left = 36
	column.offset_right = -36
	column.add_theme_constant_override("separation", 10)

	home_start_button = _royal_home_button("开始关卡", Color("#3E8DFF"))
	home_start_button.custom_minimum_size.y = 70
	home_start_button.pressed.connect(_start_current_flow)
	column.add_child(home_start_button)

	home_composite_button = _royal_home_button("拼块玩法", Color("#635BDB"))
	home_composite_button.custom_minimum_size.y = 64
	home_composite_button.pressed.connect(_start_home_composite_flow)
	column.add_child(home_composite_button)

	var newbie := _royal_home_button("新人流程", CARD)
	newbie.custom_minimum_size.y = 60
	newbie.add_theme_color_override("font_color", Color("#287BFF"))
	newbie.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.0))
	newbie.add_theme_stylebox_override("hover", _card_style(Color("#F6FAFF"), 22, true))
	newbie.add_theme_stylebox_override("pressed", _button_style(Color("#E7F1FF"), 22))
	newbie.pressed.connect(_replay_tutorial_preserving_progress)
	column.add_child(newbie)
	return column


func _build_home_bottom_nav() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchor(SIDE_TOP, 1.0)
	panel.set_anchor(SIDE_RIGHT, 1.0)
	panel.set_anchor(SIDE_BOTTOM, 1.0)
	panel.offset_top = -78
	panel.add_theme_stylebox_override("panel", _button_style(Color("#1679D4"), 0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	row.add_child(_nav_button("★", "星"))
	row.add_child(_nav_button("杯", "杯"))

	var home := _nav_button("城", "主页")
	home.disabled = true
	row.add_child(home)

	row.add_child(_nav_button("队", "队"))
	row.add_child(_nav_button("⚙", "设"))
	return panel


func _build_home_resource_bar() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 58
	row.add_theme_constant_override("separation", 8)

	home_coin_label = _coin_value_label(coin_count)
	row.add_child(_coin_resource_badge(home_coin_label))

	home_heart_label = _resource_label("♥  %d" % heart_count, Color("#F06B78"))
	row.add_child(home_heart_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var settings := _small_button("⚙")
	settings.tooltip_text = "设置"
	settings.pressed.connect(_on_settings)
	row.add_child(settings)

	var editor := _small_button("编")
	editor.tooltip_text = "关卡编辑器"
	editor.pressed.connect(_open_level_editor)
	row.add_child(editor)
	return row


func _build_home_hero() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 410
	panel.add_theme_stylebox_override("panel", _card_style(Color("#DDEFFD"), 24, true, 18))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "color king"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 36)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "皇冠花园"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("#52627A"))
	subtitle.add_theme_font_size_override("font_size", 18)
	column.add_child(subtitle)

	var castle := _piece_texture_rect(Vector2(180, 180))
	castle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(castle)

	return panel


func _build_home_actions() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)

	home_start_button = _action_button("开始关卡", Color("#FFB84E"))
	home_start_button.custom_minimum_size.y = 66
	home_start_button.add_theme_font_size_override("font_size", 23)
	home_start_button.pressed.connect(_start_current_flow)
	column.add_child(home_start_button)

	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 70
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)

	var daily := _action_button("每日奖励", Color("#FFFFFF"))
	daily.pressed.connect(func() -> void:
		coin_count += 10
		_update_coin_label()
		_update_home()
		_save_game()
		_show_toast("每日奖励：金币 +10")
	)
	row.add_child(daily)

	var chest := _action_button("宝箱", Color("#FFFFFF"))
	chest.pressed.connect(func() -> void: _show_toast("继续通关，皇冠宝箱即将开启"))
	row.add_child(chest)
	return column


func _build_home_nav() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 54
	row.add_theme_constant_override("separation", 8)

	var home := _action_button("主页", Color("#EAF8F0"))
	home.disabled = true
	row.add_child(home)

	var event := _action_button("活动")
	event.pressed.connect(func() -> void: _show_toast("活动将在后续版本开放"))
	row.add_child(event)

	var shop := _action_button("商店")
	shop.pressed.connect(func() -> void: _show_toast("商店将在后续版本开放"))
	row.add_child(shop)
	return row


func _build_game_screen() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 6)
	safe_margin.add_theme_constant_override("margin_right", 6)
	safe_margin.add_theme_constant_override("margin_top", 16)
	safe_margin.add_theme_constant_override("margin_bottom", 12)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	safe_margin.add_child(content)

	content.add_child(_build_top_bar())
	content.add_child(_build_level_header())
	progress_row = _build_progress_row()
	content.add_child(progress_row)
	content.add_child(_build_coach())

	board = GameBoardScript.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.cell_pressed.connect(_on_cell_pressed)
	board.cell_double_pressed.connect(_on_cell_double_pressed)
	board.cell_drag_started.connect(_on_cell_drag_started)
	board.cell_dragged.connect(_on_cell_dragged)
	board.cell_drag_ended.connect(_on_cell_drag_ended)
	content.add_child(board)

	action_bar = _build_action_bar()
	content.add_child(action_bar)
	root.add_child(safe_margin)

	assembly_view = AssemblyViewScript.new()
	assembly_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	assembly_view.z_index = 4
	assembly_view.placement_requested.connect(_on_assembly_placement_requested)
	assembly_view.return_requested.connect(_on_assembly_return_requested)
	assembly_view.intro_finished.connect(_on_composite_intro_finished)
	root.add_child(assembly_view)
	assembly_view.bind_targets(board, action_bar)
	return root


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 72
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 18, true))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	margin.add_child(row)

	top_home_button = _small_button("⌂", Vector2(52, 52), 28)
	top_home_button.tooltip_text = "返回首页"
	top_home_button.pressed.connect(_show_home)
	row.add_child(top_home_button)

	coin_label = _coin_value_label(coin_count)
	row.add_child(_coin_resource_badge(coin_label))

	level_heart_label = _build_heart_display()
	row.add_child(level_heart_label)

	tutorial_skip_button = _small_button("跳")
	tutorial_skip_button.tooltip_text = "跳过新手教程"
	tutorial_skip_button.pressed.connect(_on_tutorial_button_pressed)
	tutorial_skip_button.hide()
	row.add_child(tutorial_skip_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	help_button = _small_button("?", Vector2(46, 46), 24)
	help_button.tooltip_text = "查看消除规则"
	help_button.pressed.connect(_on_help)
	row.add_child(help_button)

	settings_button = _small_button("⚙", Vector2(46, 46), 22)
	settings_button.tooltip_text = "设置"
	settings_button.pressed.connect(_on_settings)
	row.add_child(settings_button)

	level_select_button = _small_button("选关")
	level_select_button.tooltip_text = "选择关卡"
	level_select_button.pressed.connect(_open_level_select)
	row.add_child(level_select_button)
	return panel


func _build_level_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 46

	level_label = Label.new()
	level_label.add_theme_color_override("font_color", INK)
	level_label.add_theme_font_size_override("font_size", 27)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(level_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	assembly_stage_label = Label.new()
	assembly_stage_label.text = "先拼好颜色区域"
	assembly_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	assembly_stage_label.add_theme_color_override("font_color", Color("#536179"))
	assembly_stage_label.add_theme_font_size_override("font_size", 15)
	assembly_stage_label.hide()
	row.add_child(assembly_stage_label)

	return row


func _build_progress_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 46
	row.add_theme_constant_override("separation", 10)

	var piece := _piece_texture_rect(Vector2(38, 38))
	row.add_child(piece)

	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size.y = 24
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _button_style(UITokensScript.PROGRESS_TRACK, 12))
	progress_bar.add_theme_stylebox_override("fill", _button_style(UITokensScript.PROGRESS_FILL, 12))
	row.add_child(progress_bar)

	progress_label = Label.new()
	progress_label.custom_minimum_size.x = 52
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.add_theme_color_override("font_color", INK)
	progress_label.add_theme_font_size_override("font_size", 18)
	row.add_child(progress_label)
	return row


func _build_opening_king_overlay() -> void:
	opening_king_overlay = ColorRect.new()
	opening_king_overlay.color = UITokensScript.OPENING_OVERLAY_SCRIM
	opening_king_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opening_king_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	opening_king_overlay.z_index = 9
	opening_king_overlay.hide()
	add_child(opening_king_overlay)

	opening_king_panel = PanelContainer.new()
	opening_king_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	opening_king_panel.position = Vector2(-180, 112)
	opening_king_panel.size = Vector2(360, 190)
	opening_king_panel.custom_minimum_size = Vector2(360, 190)
	opening_king_panel.add_theme_stylebox_override("panel", _card_style(UITokensScript.OPENING_OVERLAY_CARD, 24, true, 22))
	opening_king_overlay.add_child(opening_king_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	opening_king_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	opening_king_title = Label.new()
	opening_king_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_king_title.add_theme_color_override("font_color", INK)
	opening_king_title.add_theme_font_size_override("font_size", 24)
	column.add_child(opening_king_title)

	opening_king_count_label = Label.new()
	opening_king_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening_king_count_label.add_theme_color_override("font_color", MUTED)
	opening_king_count_label.add_theme_font_size_override("font_size", 17)
	column.add_child(opening_king_count_label)

	opening_king_source_label = HBoxContainer.new()
	opening_king_source_label.custom_minimum_size.y = 64
	opening_king_source_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opening_king_source_label.alignment = BoxContainer.ALIGNMENT_CENTER
	opening_king_source_label.add_theme_constant_override("separation", 6)
	opening_king_source_label.add_child(_piece_texture_rect(Vector2(58, 58)))
	opening_king_source_count_label = Label.new()
	opening_king_source_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	opening_king_source_count_label.add_theme_color_override("font_color", INK)
	opening_king_source_count_label.add_theme_font_size_override("font_size", 28)
	opening_king_source_label.add_child(opening_king_source_count_label)
	column.add_child(opening_king_source_label)


func _build_coach() -> Control:
	coach_panel = PanelContainer.new()
	coach_panel.name = "TutorialCoachPanel"
	coach_panel.custom_minimum_size.y = 78
	coach_panel.add_theme_stylebox_override("panel", _button_style(Color("#FFF0C9"), 16))

	coach_label = Label.new()
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coach_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coach_label.add_theme_color_override("font_color", Color("#72552B"))
	coach_label.add_theme_font_size_override("font_size", 13)
	coach_panel.add_child(coach_label)
	coach_panel.hide()
	return coach_panel


func _build_action_bar() -> Control:
	var row := HBoxContainer.new()
	row.name = "LevelToolBar"
	row.custom_minimum_size.y = 94
	row.add_theme_constant_override("separation", 10)

	var clear_tool := _tool_button("clear", "清除 · 免费", Color("#EEF5FF"), Color("#477DB7"))
	clear_button = clear_tool["button"]
	clear_button_label = clear_tool["label"]
	clear_button.pressed.connect(_clear_board)
	row.add_child(clear_button)

	var crown_tool := _tool_button("crown", "皇冠直找", Color("#FFF4CE"), Color("#B97A09"))
	crown_find_button = crown_tool["button"]
	crown_find_button_label = crown_tool["label"]
	crown_find_button.pressed.connect(_use_crown_find)
	row.add_child(crown_find_button)

	var hint_tool := _tool_button("hint", "提示", Color("#EAF8F0"), Color("#23845C"))
	hint_button = hint_tool["button"]
	hint_button_label = hint_tool["label"]
	hint_button.pressed.connect(_use_hint)
	row.add_child(hint_button)
	_update_crown_find_button()
	_update_hint_button()
	return row


func _build_heart_display() -> Control:
	var panel := PanelContainer.new()
	panel.name = "LevelHeartBadge"
	panel.tooltip_text = "本关生命"
	panel.custom_minimum_size = Vector2(116, 42)
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 18, true, 4))

	var hearts := HBoxContainer.new()
	hearts.name = "HeartSlots"
	hearts.alignment = BoxContainer.ALIGNMENT_CENTER
	hearts.add_theme_constant_override("separation", 2)
	panel.add_child(hearts)
	level_heart_slots.clear()
	for index in range(INITIAL_HEART_COUNT):
		var heart := Label.new()
		heart.name = "Heart%d" % (index + 1)
		heart.custom_minimum_size = Vector2(32, 38)
		heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heart.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heart.add_theme_font_size_override("font_size", 30)
		heart.pivot_offset = Vector2(16, 19)
		hearts.add_child(heart)
		level_heart_slots.append(heart)
	return panel


func _build_ad_placeholder() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 38
	panel.add_theme_stylebox_override("panel", _button_style(Color("#EEEAE3"), 12))
	var label := Label.new()
	label.text = "广告位 · Demo Placeholder"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#AAA39A"))
	label.add_theme_font_size_override("font_size", 12)
	panel.add_child(label)
	return panel


func _build_completion_overlay() -> void:
	completion_overlay = ColorRect.new()
	completion_overlay.color = Color("#DDF5FF")
	completion_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	completion_overlay.z_index = 10
	completion_overlay.hide()
	add_child(completion_overlay)

	var sky := ColorRect.new()
	sky.color = Color("#248DFF")
	sky.set_anchor(SIDE_RIGHT, 1.0)
	sky.set_anchor(SIDE_BOTTOM, 0.52)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	completion_overlay.add_child(sky)

	var glow := ColorRect.new()
	glow.color = Color("#8BD0FF")
	glow.set_anchor(SIDE_TOP, 0.36)
	glow.set_anchor(SIDE_RIGHT, 1.0)
	glow.set_anchor(SIDE_BOTTOM, 0.72)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	completion_overlay.add_child(glow)

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 30)
	safe_area.add_theme_constant_override("margin_right", 30)
	safe_area.add_theme_constant_override("margin_top", 112)
	safe_area.add_theme_constant_override("margin_bottom", 56)
	completion_overlay.add_child(safe_area)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	safe_area.add_child(column)

	completion_title = Label.new()
	completion_title.text = "太棒了！"
	completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_title.add_theme_color_override("font_color", Color("#FFE06F"))
	completion_title.add_theme_color_override("font_shadow_color", Color(0.10, 0.23, 0.45, 0.30))
	completion_title.add_theme_constant_override("shadow_offset_x", 0)
	completion_title.add_theme_constant_override("shadow_offset_y", 4)
	completion_title.add_theme_font_size_override("font_size", 54)
	column.add_child(completion_title)

	reward_label = Label.new()
	reward_label.text = "第 1 关 已完成"
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", Color.WHITE)
	reward_label.add_theme_color_override("font_shadow_color", Color(0.10, 0.23, 0.45, 0.26))
	reward_label.add_theme_constant_override("shadow_offset_x", 0)
	reward_label.add_theme_constant_override("shadow_offset_y", 3)
	reward_label.add_theme_font_size_override("font_size", 29)
	column.add_child(reward_label)

	var showcase := PanelContainer.new()
	showcase.custom_minimum_size = Vector2(0, 250)
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.add_theme_stylebox_override("panel", _card_style(CARD, 32, true, 28))
	column.add_child(showcase)

	var showcase_column := VBoxContainer.new()
	showcase_column.alignment = BoxContainer.ALIGNMENT_CENTER
	showcase_column.add_theme_constant_override("separation", 10)
	showcase.add_child(showcase_column)

	result_piece_icon = _piece_texture_rect(Vector2(164, 164), LION_KING_VICTORY_ICON)
	showcase_column.add_child(result_piece_icon)

	result_icon_label = Label.new()
	result_icon_label.text = "♥"
	result_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_icon_label.add_theme_color_override("font_color", Color("#F25D72"))
	result_icon_label.add_theme_color_override("font_shadow_color", Color("#B92E4A"))
	result_icon_label.add_theme_constant_override("shadow_offset_x", 0)
	result_icon_label.add_theme_constant_override("shadow_offset_y", 5)
	result_icon_label.add_theme_font_size_override("font_size", 104)
	result_icon_label.hide()
	showcase_column.add_child(result_icon_label)

	result_reward_label = Label.new()
	result_reward_label.text = ""
	result_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_reward_label.add_theme_color_override("font_color", Color("#2F73D9"))
	result_reward_label.add_theme_font_size_override("font_size", 24)
	result_reward_label.hide()
	showcase_column.add_child(result_reward_label)

	result_tip_label = Label.new()
	result_tip_label.text = "继续前进，收集更多皇冠"
	result_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_tip_label.add_theme_color_override("font_color", Color("#6A82A6"))
	result_tip_label.add_theme_font_size_override("font_size", 17)
	showcase_column.add_child(result_tip_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 22
	column.add_child(spacer)

	completion_next_button = _action_button("下一关", Color("#3E8DFF"))
	completion_next_button.custom_minimum_size.y = 74
	completion_next_button.add_theme_color_override("font_color", Color.WHITE)
	completion_next_button.add_theme_font_size_override("font_size", 30)
	completion_next_button.pressed.connect(_completion_primary_pressed)
	column.add_child(completion_next_button)

	completion_replay_button = _action_button("主菜单", CARD)
	completion_replay_button.custom_minimum_size.y = 66
	completion_replay_button.add_theme_color_override("font_color", Color("#287BFF"))
	completion_replay_button.add_theme_font_size_override("font_size", 27)
	completion_replay_button.pressed.connect(_completion_secondary_pressed)
	column.add_child(completion_replay_button)


func _build_toast() -> void:
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.position = Vector2(-190, -112)
	toast_label.size = Vector2(380, 48)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_font_size_override("font_size", 15)
	toast_label.add_theme_stylebox_override("normal", _button_style(Color("#2F3B50"), 18))
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.z_index = 20
	toast_label.modulate.a = 0.0
	add_child(toast_label)


func _build_tutorial_center_popup() -> void:
	tutorial_center_popup = Label.new()
	tutorial_center_popup.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_center_popup.position = Vector2(-210, -44)
	tutorial_center_popup.size = Vector2(420, 88)
	tutorial_center_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_center_popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_center_popup.add_theme_color_override("font_color", Color.WHITE)
	tutorial_center_popup.add_theme_font_size_override("font_size", 22)
	tutorial_center_popup.add_theme_stylebox_override("normal", _card_style(Color("#2F3B50"), 18, true, 18))
	tutorial_center_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_center_popup.z_index = 21
	tutorial_center_popup.modulate.a = 0.0
	add_child(tutorial_center_popup)


func _build_tutorial_hand_pointer() -> void:
	tutorial_hand_label = Label.new()
	tutorial_hand_label.text = "👆"
	tutorial_hand_label.size = Vector2(96, 96)
	tutorial_hand_label.pivot_offset = Vector2(48, 48)
	tutorial_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tutorial_hand_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_hand_label.add_theme_color_override("font_color", Color("#2F3B50"))
	tutorial_hand_label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.86))
	tutorial_hand_label.add_theme_constant_override("shadow_offset_x", 0)
	tutorial_hand_label.add_theme_constant_override("shadow_offset_y", 3)
	tutorial_hand_label.add_theme_font_size_override("font_size", 66)
	tutorial_hand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_hand_label.z_index = 22
	tutorial_hand_label.hide()
	add_child(tutorial_hand_label)
	if board:
		board.resized.connect(func() -> void:
			if tutorial_hand_label.visible:
				_position_tutorial_hand()
		)


func _build_dialog_controller() -> void:
	dialog_controller = DialogControllerScript.new()
	dialog_controller.action_selected.connect(_on_dialog_action_selected)
	dialog_controller.cancelled.connect(_on_dialog_cancelled)
	add_child(dialog_controller)


func _build_help_dialog() -> void:
	help_tabs = TabContainer.new()
	help_tabs.name = "HelpContent"
	help_tabs.custom_minimum_size = Vector2(408, 470)
	help_content = help_tabs

	var margin := MarginContainer.new()
	margin.name = "消除规则"
	margin.custom_minimum_size = Vector2(408, 438)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	help_tabs.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var intro := Label.new()
	intro.text = "记住三个规则，把不可能的位置标记为 X。"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", INK)
	intro.add_theme_font_size_override("font_size", 16)
	column.add_child(intro)

	column.add_child(_build_help_rule(
		RuleIllustrationScript.ADJACENT,
		"AdjacentRuleIllustration",
		"皇冠周围都是 X",
		"皇冠的八个邻近方格不能再出现皇冠。"
	))
	column.add_child(_build_help_rule(
		RuleIllustrationScript.ROW_COLUMN,
		"RowColumnRuleIllustration",
		"每行、每列一个皇冠",
		"找到皇冠后，同一行和同一列的其它格都标记 X。"
	))
	column.add_child(_build_help_rule(
		RuleIllustrationScript.REGION,
		"RegionRuleIllustration",
		"每种颜色一个皇冠",
		"一个颜色区域只能有一个皇冠，其余同色格标记 X。"
	))

	var assembly_scroll := ScrollContainer.new()
	assembly_scroll.name = "拼块玩法"
	assembly_scroll.custom_minimum_size = Vector2(408, 438)
	help_tabs.add_child(assembly_scroll)
	var assembly_margin := MarginContainer.new()
	assembly_margin.add_theme_constant_override("margin_left", 10)
	assembly_margin.add_theme_constant_override("margin_right", 10)
	assembly_margin.add_theme_constant_override("margin_top", 8)
	assembly_margin.add_theme_constant_override("margin_bottom", 8)
	assembly_scroll.add_child(assembly_margin)
	var assembly_column := VBoxContainer.new()
	assembly_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assembly_column.add_theme_constant_override("separation", 8)
	assembly_margin.add_child(assembly_column)
	var assembly_intro := Label.new()
	assembly_intro.text = "先补完整个颜色区域，再开始找皇冠。"
	assembly_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assembly_intro.add_theme_color_override("font_color", INK)
	assembly_intro.add_theme_font_size_override("font_size", 16)
	assembly_column.add_child(assembly_intro)
	assembly_column.add_child(_build_assembly_help_step("1", "向上拖出彩色方块", "底部托盘可以左右滑动，查看尚未放置的方块。"))
	assembly_column.add_child(_build_assembly_help_step("2", "完整对齐空白凹槽", "方块不能越界或重叠，同一种颜色最终必须连在一起。"))
	assembly_column.add_child(_build_assembly_help_step("3", "可以随时拿回重放", "把棋盘上的立体方块向下拖回托盘，再尝试其它位置。"))
	assembly_column.add_child(_build_assembly_help_step("4", "拼完自动进入找皇冠", "立体方块会压平为正常颜色棋盘，并恢复清除、直找和提示。"))
	var replay_button := Button.new()
	replay_button.name = "ReplayAssemblyIntro"
	replay_button.text = "重播演示"
	replay_button.custom_minimum_size.y = 48
	replay_button.add_theme_font_size_override("font_size", 16)
	replay_button.add_theme_stylebox_override("normal", _button_style(UITokensScript.SOFT_BLUE, 14))
	replay_button.pressed.connect(_replay_composite_intro_from_help)
	assembly_column.add_child(replay_button)
	dialog_controller.register_content("help_rules", help_content)


func _build_assembly_help_step(number: String, title_text: String, body_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 78
	panel.add_theme_stylebox_override("panel", _dialog_content_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var badge := Label.new()
	badge.text = number
	badge.custom_minimum_size = Vector2(34, 34)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_font_size_override("font_size", 17)
	badge.add_theme_stylebox_override("normal", _button_style(UITokensScript.PRIMARY_BLUE, 17))
	row.add_child(badge)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 16)
	copy.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", MUTED)
	body.add_theme_font_size_override("font_size", 13)
	copy.add_child(body)
	return panel


func _build_help_rule(kind: String, illustration_name: String, title_text: String, body_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 120
	panel.add_theme_stylebox_override("panel", _dialog_content_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var illustration = RuleIllustrationScript.new()
	illustration.name = illustration_name
	illustration.configure(kind)
	row.add_child(illustration)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 5)
	row.add_child(copy)

	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 17)
	copy.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", MUTED)
	body.add_theme_font_size_override("font_size", 14)
	copy.add_child(body)
	return panel


func _build_level_select_dialog() -> void:
	var margin := MarginContainer.new()
	margin.name = "LevelSelectContent"
	margin.custom_minimum_size = Vector2(368, 86)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	level_select_content = margin

	level_select_picker = OptionButton.new()
	level_select_picker.custom_minimum_size.y = 48
	level_select_picker.focus_mode = Control.FOCUS_NONE
	level_select_picker.add_theme_font_size_override("font_size", 17)
	level_select_picker.add_theme_color_override("font_color", INK)
	level_select_picker.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 12))
	margin.add_child(level_select_picker)
	dialog_controller.register_content("level_select", level_select_content)
	_refresh_level_select_picker()


func _build_settings_dialog() -> void:
	var margin := MarginContainer.new()
	margin.name = "SettingsContent"
	margin.custom_minimum_size = Vector2(368, 126)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	settings_content = margin

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var description := Label.new()
	description.text = "选择界面和游戏提示使用的语言。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", MUTED)
	description.add_theme_font_size_override("font_size", 14)
	column.add_child(description)

	var language_row := HBoxContainer.new()
	language_row.custom_minimum_size.y = 52
	language_row.add_theme_constant_override("separation", 12)
	column.add_child(language_row)

	var language_label := Label.new()
	language_label.text = "游戏语言"
	language_label.custom_minimum_size.x = 104
	language_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	language_label.add_theme_color_override("font_color", INK)
	language_label.add_theme_font_size_override("font_size", 16)
	language_row.add_child(language_label)

	language_picker = OptionButton.new()
	language_picker.name = "LanguagePicker"
	language_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_picker.custom_minimum_size.y = 48
	language_picker.focus_mode = Control.FOCUS_ALL
	language_picker.add_theme_font_size_override("font_size", 16)
	language_picker.add_theme_color_override("font_color", INK)
	language_picker.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 12))
	language_row.add_child(language_picker)
	_refresh_language_picker()
	dialog_controller.register_content("settings", settings_content)


func _schedule_for_current_level() -> Dictionary:
	_sync_director_completed_levels()
	if not active_schedule.is_empty():
		var schedule_index := int(active_schedule.get("levelIndex", current_level_index))
		if schedule_index >= 0 and schedule_index < levels.size():
			if int(active_schedule.get("displayLevel", player_level_number)) == player_level_number:
				return active_schedule
	return LevelDirectorScript.schedule_for_display_level(levels, player_level_number, director_progress)



func _schedule_for_manual_level(index: int) -> Dictionary:
	var display := index + 1 if index < LevelDirectorScript.FIXED_OPENING_COUNT else player_level_number
	var mode := "fixed" if index < LevelDirectorScript.FIXED_OPENING_COUNT else "manual"
	return LevelDirectorScript.manual_schedule_for_level(levels, index, maxi(1, display), mode)


func _sync_director_completed_levels() -> void:
	LevelDirectorScript.normalize_progress(director_progress)
	director_progress["completedLevelIds"] = completed_levels.duplicate()


func _load_level(index: int, allow_resume: bool = false, schedule: Dictionary = {}, force_resume: bool = false) -> void:
	_cancel_opening_king_intro()
	in_tutorial = false
	if coach_panel:
		coach_panel.hide()
	_hide_tutorial_hand()
	if tutorial_skip_button:
		tutorial_skip_button.hide()
	if level_picker:
		level_picker.disabled = false
	if schedule.is_empty():
		schedule = _schedule_for_manual_level(index)
	active_schedule = schedule.duplicate(true)
	current_level_index = int(active_schedule.get("levelIndex", index))
	current_level_index = clampi(current_level_index, 0, levels.size() - 1)
	player_level_number = maxi(1, int(active_schedule.get("displayLevel", player_level_number)))
	current_level = levels[current_level_index].duplicate(true)
	_prepare_composite_level(allow_resume)
	is_completed = false
	is_failed = false
	active_hint_step.clear()
	active_hint_stage = 0
	move_history.clear()
	_stop_result_lion_animation()
	completion_overlay.hide()

	var rows := int(current_level["rows"])
	var cols := int(current_level["cols"])
	current_heart_limit = _heart_limit_for_display_level(player_level_number)
	var can_resume := allow_resume and _can_restore_saved_level(rows, cols, force_resume)
	if can_resume:
		cell_states = resume_states.duplicate(true)
		is_completed = resume_completed
		is_failed = resume_failed
		heart_count = clampi(heart_count, 0, current_heart_limit)
		if run_started_unix <= 0:
			run_started_unix = int(Time.get_unix_time_from_system())
	else:
		cell_states = _blank_states(rows, cols)
		heart_count = current_heart_limit
		run_started_unix = int(Time.get_unix_time_from_system())
		run_move_count = 0
		run_hint_count = 0
		run_coin_exchange_count = 0
	_update_active_king_positions()
	_apply_king_positions_to_state()

	level_label.text = _display_level_title()
	if help_button:
		help_button.show()
	if completion_next_button:
		completion_next_button.text = "下一关"
	if completion_replay_button:
		completion_replay_button.text = "主菜单"
		completion_replay_button.show()
	if hint_button:
		hint_button.show()
		hint_button.disabled = is_failed
	if crown_find_button:
		crown_find_button.show()
		crown_find_button.disabled = is_failed
	if clear_button:
		clear_button.show()
		clear_button.disabled = is_failed
	_update_heart_label()
	_update_crown_find_button()
	_update_level_picker()
	coach_label.text = _level_coach_text()
	coach_label.add_theme_color_override("font_color", Color("#72552B"))
	if progress_bar:
		progress_bar.max_value = int(current_level["targetCount"])
	board.set_level(current_level, cell_states, REGION_COLORS)
	_validate_and_update(false)
	_apply_composite_phase_ui()
	if not _is_assembly_phase():
		_request_opening_king_reveal()
	_update_home()
	if is_completed:
		_prepare_success_result_page()
		completion_overlay.show()
		_save_game()
	elif is_failed:
		_prepare_failure_result_page()
		completion_overlay.show()
		_save_game()


func _prepare_composite_level(allow_resume: bool) -> void:
	composite_mode = false
	composite_phase = "crown"
	composite_data.clear()
	composite_placements.clear()
	composite_final_layout.clear()
	var level_id := int(current_level.get("levelId", -1))
	var saved_matches := allow_resume and int(resume_composite_state.get("levelId", -2)) == level_id
	var saved_phase := str(resume_composite_state.get("phase", "")) if saved_matches else ""
	if saved_matches and (saved_phase == "crown" or saved_phase == "transition"):
		var final_regions = resume_composite_state.get("finalRegions", [])
		var final_solution = resume_composite_state.get("finalSolution", [])
		if _composite_final_level_is_valid(final_regions, final_solution):
			composite_mode = true
			composite_phase = "crown"
			current_level["regions"] = final_regions.duplicate(true)
			current_level["solution"] = final_solution.duplicate(true)
			composite_final_layout = {
				"signature": str(resume_composite_state.get("layoutSignature", "")),
				"regions": final_regions.duplicate(true),
				"solution": final_solution.duplicate(true)
			}
			return

	if not bool(active_schedule.get("assemblyEnabled", false)) or int(current_level.get("rows", 0)) < 6:
		return
	var seed := int(resume_composite_state.get("seed", 0)) if saved_matches else int(active_schedule.get("assemblySeed", 0))
	if seed == 0:
		seed = int(current_level.get("levelId", 1)) * 1000003 + player_level_number * 9176 + 20260722
	if saved_matches:
		composite_data = CompositeLevelScript.build(current_level, seed)
	else:
		var fallback_composite: Dictionary = {}
		for seed_offset in range(12):
			var candidate_composite: Dictionary = CompositeLevelScript.build(current_level, seed + seed_offset)
			if candidate_composite.is_empty():
				continue
			if fallback_composite.is_empty():
				fallback_composite = candidate_composite
			if candidate_composite["validLayouts"].size() >= 2:
				composite_data = candidate_composite
				break
		if composite_data.is_empty():
			composite_data = fallback_composite
	if composite_data.is_empty():
		active_schedule["assemblyEnabled"] = false
		return
	composite_mode = true
	composite_phase = "assembly"
	active_schedule["kingPositions"] = []
	if saved_matches and saved_phase == "assembly":
		composite_placements = CompositeLevelScript.sanitize_placements(composite_data, resume_composite_state.get("placements", {}))
	else:
		composite_placements = CompositeLevelScript.empty_placements()


func _composite_final_level_is_valid(regions, solution) -> bool:
	if not regions is Array or not solution is Array:
		return false
	var rows := int(current_level.get("rows", 0))
	var cols := int(current_level.get("cols", 0))
	if regions.size() != rows or solution.size() != int(current_level.get("targetCount", rows)):
		return false
	for row in regions:
		if not row is Array or row.size() != cols:
			return false
	return true


func _is_assembly_phase() -> bool:
	return composite_mode and composite_phase == "assembly"


func _assembly_allowed_origins() -> Dictionary:
	var result := {}
	if composite_data.is_empty():
		return result
	for piece in composite_data.get("pieces", []):
		var piece_id := int(piece.get("pieceId", -1))
		result[str(piece_id)] = CompositeLevelScript.allowed_origins(composite_data, composite_placements, piece_id)
	return result


func _apply_composite_phase_ui() -> void:
	if not assembly_view or not board or not action_bar or not progress_row:
		return
	if _is_assembly_phase():
		progress_row.hide()
		if assembly_stage_label:
			assembly_stage_label.show()
		board.modulate.a = 0.0
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for button in [clear_button, crown_find_button, hint_button]:
			if button:
				button.disabled = true
				button.hide()
		assembly_view.configure(composite_data, composite_placements, REGION_COLORS, _assembly_allowed_origins())
	else:
		progress_row.show()
		if assembly_stage_label:
			assembly_stage_label.hide()
		board.modulate.a = 1.0
		board.mouse_filter = Control.MOUSE_FILTER_STOP
		assembly_view.deactivate()
		for button in [clear_button, crown_find_button, hint_button]:
			if button:
				button.show()
		if clear_button:
			clear_button.disabled = _clearable_marks_empty()
		_update_crown_find_button()
		_update_hint_button()


func _on_assembly_placement_requested(piece_id: int, origin: Array) -> void:
	if not _is_assembly_phase() or origin.size() < 2:
		return
	var allowed: Array = CompositeLevelScript.allowed_origins(composite_data, composite_placements, piece_id)
	var accepted := false
	for candidate in allowed:
		if int(candidate[0]) == int(origin[0]) and int(candidate[1]) == int(origin[1]):
			accepted = true
			break
	if not accepted:
		return
	composite_placements[str(piece_id)] = [int(origin[0]), int(origin[1])]
	assembly_view.update_state(composite_placements, _assembly_allowed_origins())
	_save_game()
	var layout := CompositeLevelScript.matching_layout(composite_data, composite_placements)
	if not layout.is_empty():
		_complete_composite_assembly(layout)


func _on_assembly_return_requested(piece_id: int) -> void:
	if not _is_assembly_phase():
		return
	composite_placements.erase(str(piece_id))
	assembly_view.update_state(composite_placements, _assembly_allowed_origins())
	_save_game()


func _complete_composite_assembly(layout: Dictionary) -> void:
	if not _is_assembly_phase() or layout.is_empty():
		return
	composite_final_layout = layout.duplicate(true)
	composite_phase = "transition"
	_save_game()
	await assembly_view.play_flatten_transition()
	if composite_final_layout.is_empty():
		return
	current_level["regions"] = composite_final_layout["regions"].duplicate(true)
	current_level["solution"] = composite_final_layout["solution"].duplicate(true)
	active_schedule["assemblyLayoutSignature"] = str(composite_final_layout.get("signature", ""))
	active_king_positions.clear()
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	board.set_level(current_level, cell_states, REGION_COLORS)
	composite_phase = "crown"
	_apply_composite_phase_ui()
	_validate_and_update(false)
	_save_game()


func _composite_save_state() -> Dictionary:
	if not composite_mode or current_level.is_empty():
		return {}
	var result := {
		"levelId": int(current_level.get("levelId", -1)),
		"phase": composite_phase,
		"seed": int(composite_data.get("seed", resume_composite_state.get("seed", 0))),
		"placements": composite_placements.duplicate(true)
	}
	if not composite_final_layout.is_empty():
		result["layoutSignature"] = str(composite_final_layout.get("signature", ""))
		result["finalRegions"] = composite_final_layout.get("regions", []).duplicate(true)
		result["finalSolution"] = composite_final_layout.get("solution", []).duplicate(true)
	elif composite_phase == "crown":
		result["layoutSignature"] = str(active_schedule.get("assemblyLayoutSignature", ""))
		result["finalRegions"] = current_level.get("regions", []).duplicate(true)
		result["finalSolution"] = current_level.get("solution", []).duplicate(true)
	return result


func _maybe_play_composite_intro() -> void:
	if not _is_assembly_phase() or composite_tutorial_seen or composite_intro_running or not game_screen.visible:
		return
	composite_intro_running = true
	composite_intro_marks_seen = true
	assembly_view.play_intro()


func _on_composite_intro_finished() -> void:
	composite_intro_running = false
	if composite_intro_marks_seen:
		composite_tutorial_seen = true
		composite_intro_marks_seen = false
		_save_game()


func _can_restore_saved_level(rows: int, cols: int, force_resume: bool = false) -> bool:
	if resume_level_id != int(current_level["levelId"]):
		return false
	if not _states_match_size(resume_states, rows, cols):
		return false
	var display := int(active_schedule.get("displayLevel", player_level_number))
	if not force_resume and not resume_completed and display <= LevelDirectorScript.FIXED_OPENING_COUNT:
		return false
	return true


func _request_opening_king_reveal() -> void:
	if active_king_positions.is_empty() or is_completed or is_failed:
		opening_king_reveal_pending = false
		if board:
			board.reveal_all_prepared_kings()
		return
	opening_king_reveal_pending = true
	_play_pending_opening_king_reveal()


func _play_pending_opening_king_reveal() -> void:
	if not opening_king_reveal_pending:
		return
	if not game_screen or not game_screen.visible:
		return
	if not board or active_king_positions.is_empty():
		return
	opening_king_reveal_pending = false
	board.prepare_king_reveal(active_king_positions)
	_play_opening_king_intro(active_king_positions.duplicate())


func _play_opening_king_intro(cells: Array) -> void:
	if not opening_king_overlay or not opening_king_panel or cells.is_empty():
		board.reveal_all_prepared_kings()
		board.play_king_reveal(cells)
		return

	opening_king_animation_token += 1
	var token := opening_king_animation_token
	var total_count := int(current_level.get("targetCount", cells.size()))
	var base_progress := maxi(0, _piece_positions().size() - cells.size())
	opening_king_title.text = _t("本关需要找到 %d 个皇冠", [total_count])
	opening_king_count_label.text = _t("开局提供 %d 个提示皇冠", [cells.size()])
	opening_king_source_count_label.text = "×%d" % cells.size()
	if progress_bar:
		progress_bar.value = base_progress
	if progress_label:
		progress_label.text = "%d / %d" % [base_progress, total_count]

	opening_king_overlay.modulate.a = 0.0
	opening_king_overlay.show()
	opening_king_tween = create_tween()
	opening_king_tween.tween_property(opening_king_overlay, "modulate:a", 1.0, 0.20)
	await opening_king_tween.finished
	if token != opening_king_animation_token:
		return
	await get_tree().create_timer(0.65).timeout

	for index in range(cells.size()):
		if token != opening_king_animation_token or not game_screen.visible:
			return
		var cell: Vector2i = cells[index]
		var flyer := _piece_texture_rect(Vector2(64, 64))
		flyer.size = Vector2(64, 64)
		flyer.pivot_offset = flyer.size * 0.5
		flyer.z_index = 2
		opening_king_overlay.add_child(flyer)
		opening_king_flyers.append(flyer)
		var source_center := opening_king_source_label.get_global_rect().get_center()
		var target_center: Vector2 = board.cell_global_center(cell.y, cell.x)
		flyer.global_position = source_center - flyer.size * 0.5
		flyer.scale = Vector2.ONE
		opening_king_tween = create_tween()
		opening_king_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		opening_king_tween.set_parallel(true)
		opening_king_tween.tween_property(flyer, "global_position", target_center - flyer.size * 0.5, 0.58)
		opening_king_tween.tween_property(flyer, "scale", Vector2(0.72, 0.72), 0.58)
		await opening_king_tween.finished
		if token != opening_king_animation_token:
			return
		board.reveal_king_cell(cell)
		if progress_bar:
			progress_bar.value = base_progress + index + 1
		if progress_label:
			progress_label.text = "%d / %d" % [base_progress + index + 1, total_count]
		opening_king_flyers.erase(flyer)
		flyer.queue_free()
		await get_tree().create_timer(0.12).timeout

	await get_tree().create_timer(0.28).timeout
	if token != opening_king_animation_token:
		return
	opening_king_tween = create_tween()
	opening_king_tween.tween_property(opening_king_overlay, "modulate:a", 0.0, 0.24)
	await opening_king_tween.finished
	if token != opening_king_animation_token:
		return
	opening_king_overlay.hide()
	opening_king_overlay.modulate.a = 1.0
	_validate_and_update(false)


func _cancel_opening_king_intro(keep_pending: bool = false) -> void:
	opening_king_animation_token += 1
	if opening_king_tween and opening_king_tween.is_valid():
		opening_king_tween.kill()
	for flyer in opening_king_flyers:
		if is_instance_valid(flyer):
			flyer.queue_free()
	opening_king_flyers.clear()
	if opening_king_overlay:
		opening_king_overlay.hide()
		opening_king_overlay.modulate.a = 1.0
	if board:
		board.reveal_all_prepared_kings()
	opening_king_reveal_pending = keep_pending and not active_king_positions.is_empty() and not is_completed and not is_failed


func _level_coach_text() -> String:
	var king_info := str(current_level.get("kingInfo", "")).strip_edges()
	var prefix := _t("难度挑战： ") if bool(active_schedule.get("isMilestoneChallenge", false)) else ""
	if king_info != "":
		return prefix + _runtime_text(
			king_info,
			"请观察棋盘中保持明亮的格子，并根据行、列、颜色区域和相邻规则继续推理。"
		)
	var display := int(active_schedule.get("displayLevel", player_level_number))
	if str(active_schedule.get("mode", "")) == "fixed" and display <= 9 and not active_king_positions.is_empty():
		return prefix + _t("国王提示：开局已展示一个皇冠，请围绕它继续推理。")
	return prefix + _runtime_text(
		str(current_level.get("tutorial", "放置全部皇冠，满足行、列、颜色区域和相邻规则。")),
		"请观察棋盘中保持明亮的格子，并根据行、列、颜色区域和相邻规则继续推理。"
	)


func _display_level_title() -> String:
	if home_composite_entry_active:
		return _t("拼块挑战 · 第 %d 局", [maxi(1, home_composite_round)])
	if bool(active_schedule.get("isMilestoneChallenge", false)):
		return _t("关卡 %d · 难度挑战", [player_level_number])
	return _t("关卡 %d", [player_level_number])


func _update_active_king_positions() -> void:
	active_king_positions.clear()
	if in_tutorial:
		return
	var raw_positions = active_schedule.get("kingPositions", [])
	if not active_schedule.has("kingPositions") or not (raw_positions is Array):
		if current_level.has("kingPosition"):
			raw_positions = [current_level.get("kingPosition", [])]
	for raw in raw_positions:
		var king := _parse_king_position(raw)
		if king.x >= 0 and not active_king_positions.has(king):
			active_king_positions.append(king)


func _parse_king_position(raw) -> Vector2i:
	if not (raw is Array) or raw.size() < 2:
		return Vector2i(-1, -1)
	var row := int(raw[0])
	var col := int(raw[1])
	if row < 0 or row >= int(current_level.get("rows", 0)) or col < 0 or col >= int(current_level.get("cols", 0)):
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _apply_king_positions_to_state() -> void:
	for king in active_king_positions:
		if king.x >= 0:
			cell_states[king.y][king.x] = "king"


func _is_king_cell(row: int, col: int) -> bool:
	for king in active_king_positions:
		if king.x == col and king.y == row:
			return true
	return false


func _is_piece_state(state: String) -> bool:
	return state == "piece" or state == "hint" or state == "king"


func _on_cell_pressed(row: int, col: int) -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_cell_pressed(row, col)
		return
	if is_completed or is_failed or _is_king_cell(row, col):
		return
	var state: String = cell_states[row][col]
	if state == "hint" or state == "wrong":
		return
	active_hint_step.clear()
	active_hint_stage = 0
	board.set_guides({})
	_push_history()
	if state == "empty":
		cell_states[row][col] = "blocked"
		audio_controller.play_mark()
	elif state == "blocked":
		cell_states[row][col] = "empty"
		audio_controller.play_erase()
	elif state == "piece":
		cell_states[row][col] = "blocked"
		audio_controller.play_mark()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	run_move_count += 1
	_validate_and_update(true)
	_save_game()


func _on_cell_double_pressed(row: int, col: int) -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_cell_double_pressed(row, col)
		return
	if is_completed or is_failed or _is_king_cell(row, col):
		return
	var state: String = cell_states[row][col]
	if state == "piece" or state == "hint" or state == "wrong":
		return
	active_hint_step.clear()
	active_hint_stage = 0
	board.set_guides({})
	_push_history()
	var is_answer := _is_solution_cell(row, col)
	cell_states[row][col] = "piece" if is_answer else "wrong"
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	if is_answer:
		audio_controller.play_correct()
		_validate_and_update(true)
		coach_label.text = "已放置皇冠。继续用行、列、颜色区域和相邻规则检查其它位置。"
		coach_label.add_theme_color_override("font_color", Color("#72552B"))
	else:
		audio_controller.play_wrong()
		var crown_find_count_before_wrong := crown_find_count
		_validate_and_update(false)
		coach_label.text = "这个位置不是皇冠，已标记为 X。"
		coach_label.add_theme_color_override("font_color", Color("#B93D4D"))
		_consume_heart_for_wrong_crown()
		crown_find_count = crown_find_count_before_wrong
		_update_crown_find_button()
	_save_game()


func _on_cell_drag_started(row: int, col: int) -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_drag_started(row, col)
		return
	if is_completed or is_failed or _is_king_cell(row, col):
		drag_mode = ""
		return
	var state: String = cell_states[row][col]
	if state == "empty":
		drag_mode = "mark"
	elif state == "blocked":
		drag_mode = "erase"
	else:
		drag_mode = ""
	drag_changed = false
	drag_cells.clear()
	if drag_mode != "":
		active_hint_step.clear()
		active_hint_stage = 0
		board.set_guides({})
		_apply_drag_cell(row, col)


func _on_cell_dragged(row: int, col: int) -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_dragged(row, col)
		return
	if drag_mode == "" or is_completed or is_failed:
		return
	_apply_drag_cell(row, col)


func _on_cell_drag_ended() -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_on_tutorial_drag_ended()
		return
	if drag_mode == "":
		return
	if drag_changed:
		_validate_and_update(true)
		_save_game()
	drag_mode = ""
	drag_changed = false
	drag_cells.clear()


func _apply_drag_cell(row: int, col: int) -> void:
	var key := Vector2i(col, row)
	if drag_cells.has(key):
		return
	if _is_king_cell(row, col):
		return
	drag_cells[key] = true
	var state: String = cell_states[row][col]
	var next_state := state
	if drag_mode == "mark" and state == "empty":
		next_state = "blocked"
	elif drag_mode == "erase" and state == "blocked":
		next_state = "empty"
	else:
		return
	if not drag_changed:
		_push_history()
	drag_changed = true
	cell_states[row][col] = next_state
	if next_state == "blocked":
		audio_controller.play_mark()
	else:
		audio_controller.play_erase()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)

func _undo() -> void:
	if in_tutorial:
		_use_tutorial_undo()
		return
	if move_history.is_empty() or is_completed or is_failed:
		return
	cell_states = move_history.pop_back()
	board.set_states(cell_states)
	_validate_and_update(false)
	run_move_count += 1
	audio_controller.play_erase()
	_save_game()


func _clear_board() -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_use_tutorial_clear()
		return
	if is_completed or is_failed or _clearable_marks_empty():
		return
	_push_history()
	var locked_marks: Dictionary = {}
	for row in range(cell_states.size()):
		for col in range(cell_states[row].size()):
			var state := str(cell_states[row][col])
			if state == "hint":
				locked_marks[Vector2i(col, row)] = state
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	_apply_king_positions_to_state()
	for cell in locked_marks:
		cell_states[cell.y][cell.x] = locked_marks[cell]
	active_hint_step.clear()
	active_hint_stage = 0
	board.set_states(cell_states)
	board.set_guides({})
	_validate_and_update(false)
	run_move_count += 1
	audio_controller.play_clear()
	_save_game()
	_show_toast("已清除普通标记和错误标记，提示皇冠已保留")


func _current_tool_price(tool: String) -> int:
	if current_level.is_empty():
		return 1
	return CoinEconomyScript.tool_price(
		tool,
		int(current_level.get("rows", 5)),
		active_king_positions.size(),
		economy_progress,
		run_coin_exchange_count
	)


func _spend_coins_for_tool(tool: String) -> bool:
	var price := _current_tool_price(tool)
	if coin_count < price:
		_show_coin_shortage_dialog(tool, price)
		return false
	coin_count -= price
	run_coin_exchange_count += 1
	CoinEconomyScript.record_tool_exchange(economy_progress, tool, price)
	_update_coin_label()
	_update_hint_button()
	_update_crown_find_button()
	return true


func _show_coin_shortage_dialog(tool: String, price: int) -> void:
	pending_coin_tool = tool
	pending_coin_price = price
	pending_rewarded_coin_grant = CoinEconomyScript.rewarded_ad_coin_grant(
		price,
		coin_count,
		int(current_level.get("rows", 5)),
		active_king_positions.size()
	)
	var tool_name := "逻辑提示"
	if tool == CoinEconomyScript.TOOL_CROWN_FIND:
		tool_name = "皇冠位置提醒"
	elif tool == CoinEconomyScript.TOOL_REVIVE:
		tool_name = "保留棋盘复活"
	var shortage := maxi(0, price - coin_count)
	tool_name = _t(tool_name)
	var message := _t("%s需要 %d 金币。\n当前持有 %d，还差 %d。\n\n可购买金币，或主动观看一次激励广告补足本次需求。", [tool_name, price, coin_count, shortage])
	dialog_controller.show_dialog(
		"coin_shortage",
		"金币不足",
		message,
		"",
		[
			{"id": "later", "text": "稍后再说", "variant": "secondary"},
			{"id": "purchase", "text": "购买金币", "variant": "weak"},
			{"id": "rewarded", "text": _t("观看广告 +%d", [pending_rewarded_coin_grant]), "variant": "primary"}
		],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		false
	)


func _use_hint() -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_use_tutorial_hint()
		return
	if is_completed or is_failed:
		return

	var hint := _build_best_next_hint()
	if hint.is_empty():
		_show_toast("当前没有明显可提示的位置")
		return
	if hint_count > 0:
		hint_count -= 1
	elif not _spend_coins_for_tool(CoinEconomyScript.TOOL_HINT):
		return

	var guides: Dictionary = hint.get("guides", {})
	board.set_guides(guides)
	var target: Vector2i = hint["target"]
	if target.x >= 0:
		board.play_guide_feedback(target.y, target.x)
	else:
		board.play_guide_feedback_for_cells(guides.keys())
	_update_coin_label()
	_update_hint_button()
	run_hint_count += 1
	audio_controller.play_hint()
	_save_game()


func _use_crown_find() -> void:
	if _is_assembly_phase():
		return
	if in_tutorial:
		_use_tutorial_crown_find()
		return
	if is_completed or is_failed:
		return
	var target := _next_findable_solution_cell()
	if target.x < 0:
		_show_toast("当前已经没有可直接找到的皇冠")
		_update_crown_find_button()
		return
	var uses_free_count := crown_find_count > 0
	if not uses_free_count and not _spend_coins_for_tool(CoinEconomyScript.TOOL_CROWN_FIND):
		return

	_push_history()
	active_hint_step.clear()
	active_hint_stage = 0
	board.set_guides({})
	if uses_free_count:
		crown_find_count -= 1
	cell_states[target.y][target.x] = "hint"
	audio_controller.play_correct()
	board.set_states(cell_states)
	board.play_cell_feedback(target.y, target.x)
	_validate_and_update(true)
	run_move_count += 1
	_update_crown_find_button()
	_save_game()
	_show_toast("已直接找到一个皇冠")


func _next_findable_solution_cell() -> Vector2i:
	for coordinate in current_level.get("solution", []):
		var row := int(coordinate[0])
		var col := int(coordinate[1])
		var state: String = cell_states[row][col]
		if state == "piece" or state == "hint" or state == "king":
			continue
		return Vector2i(col, row)
	return Vector2i(-1, -1)


func _validate_and_update(allow_completion: bool) -> void:
	var pieces := _piece_positions()
	var conflicts := _find_conflicts(pieces)
	board.set_errors(conflicts if immediate_errors else {})

	if progress_bar:
		progress_bar.value = pieces.size()
	if progress_label:
		progress_label.text = "%d / %d" % [pieces.size(), int(current_level["targetCount"])]
	if undo_button:
		undo_button.disabled = move_history.is_empty()
	if clear_button:
		clear_button.disabled = _clearable_marks_empty()
		_refresh_tool_button_visual(clear_button)
	_update_crown_find_button()

	if not conflicts.is_empty() and immediate_errors:
		coach_label.text = "有冲突：红色格子违反了行、列、区域或相邻规则。"
		coach_label.add_theme_color_override("font_color", Color("#B93D4D"))
		if allow_completion:
			Input.vibrate_handheld(35)
	else:
		coach_label.text = _level_coach_text()
		coach_label.add_theme_color_override("font_color", Color("#72552B"))

	if not is_failed and allow_completion and pieces.size() == int(current_level["targetCount"]) and conflicts.is_empty():
		_complete_level()


func _find_conflicts(pieces: Array) -> Dictionary:
	var result := {}
	for i in range(pieces.size()):
		for j in range(i + 1, pieces.size()):
			var a: Vector2i = pieces[i]
			var b: Vector2i = pieces[j]
			var same_row := a.y == b.y
			var same_col := a.x == b.x
			var same_region := int(current_level["regions"][a.y][a.x]) == int(current_level["regions"][b.y][b.x])
			var adjacent := absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1
			if same_row or same_col or same_region or adjacent:
				result[a] = true
				result[b] = true
	return result


func _piece_conflicts_at(cell: Vector2i) -> bool:
	return _find_conflicts(_piece_positions()).has(cell)


func _build_best_next_hint() -> Dictionary:
	var hint := _formal_x_hint(_best_locked_candidate_hint())
	if not hint.is_empty():
		return hint
	hint = _formal_x_hint(_best_subset_lock_hint())
	if not hint.is_empty():
		return hint
	hint = _formal_x_hint(_best_lookahead_exclusion_hint())
	if not hint.is_empty():
		return hint
	hint = _formal_x_hint(_best_exclusion_hint())
	if not hint.is_empty():
		return hint
	return {}


func _formal_x_hint(source_hint: Dictionary) -> Dictionary:
	if source_hint.is_empty():
		return {}
	var source_guides: Dictionary = source_hint.get("guides", {})
	var x_guides := {}
	for raw_cell in source_guides.keys():
		if not raw_cell is Vector2i:
			continue
		var cell: Vector2i = raw_cell
		var kind := str(source_guides[cell])
		if kind != "exclude" and kind != "exclude_empty":
			continue
		if cell.y < 0 or cell.y >= cell_states.size() or cell.x < 0 or cell.x >= cell_states[cell.y].size():
			continue
		if cell_states[cell.y][cell.x] != "empty" or _is_solution_cell(cell.y, cell.x):
			continue
		x_guides[cell] = "exclude_empty"
	if x_guides.is_empty():
		return {}
	var target: Vector2i = source_hint.get("target", Vector2i(-1, -1))
	if not x_guides.has(target):
		target = x_guides.keys()[0]
	return {
		"target": target,
		"guides": x_guides,
		"message": str(source_hint.get("message", ""))
	}


func _best_single_candidate_hint() -> Dictionary:
	var best := {}
	for row in range(int(current_level["rows"])):
		if _row_has_piece(row):
			continue
		var unit_cells := _row_cells(row)
		var candidates := _available_candidates_in_cells(unit_cells)
		if candidates.size() == 1:
			best = _choose_stronger_unit_hint(best, _make_single_candidate_hint("第 %d 行" % [row + 1], candidates[0], unit_cells))

	for col in range(int(current_level["cols"])):
		if _col_has_piece(col):
			continue
		var unit_cells := _col_cells(col)
		var candidates := _available_candidates_in_cells(unit_cells)
		if candidates.size() == 1:
			best = _choose_stronger_unit_hint(best, _make_single_candidate_hint("第 %d 列" % [col + 1], candidates[0], unit_cells))

	for region_id in _region_ids():
		if _region_has_piece(region_id):
			continue
		var unit_cells := _region_cells(region_id)
		var candidates := _available_candidates_in_cells(unit_cells)
		if candidates.size() == 1:
			best = _choose_stronger_unit_hint(best, _make_single_candidate_hint(_region_name(region_id), candidates[0], unit_cells))
	return best


func _choose_stronger_unit_hint(current: Dictionary, candidate: Dictionary) -> Dictionary:
	if current.is_empty():
		return candidate
	if int(candidate.get("score", 0)) > int(current.get("score", 0)):
		return candidate
	return current


func _make_single_candidate_hint(unit_name: String, target: Vector2i, unit_cells: Array[Vector2i]) -> Dictionary:
	var exclusions := _excluded_cells_in_cells(unit_cells)
	var guides := _guides_for_unit(unit_cells, _available_candidates_in_cells(unit_cells), exclusions)
	guides[target] = "place"
	return {
		"target": target,
		"guides": guides,
		"score": exclusions.size(),
		"message": _best_single_candidate_message(unit_name, target, unit_cells, exclusions)
	}


func _best_single_candidate_message(unit_name: String, target: Vector2i, unit_cells: Array[Vector2i], exclusions: Array[Dictionary]) -> String:
	var summary := _exclusion_summary(exclusions)
	var detail := _first_exclusion_detail(exclusions)
	var target_region := int(current_level["regions"][target.y][target.x])
	var target_text := "第 %d 行第 %d 列" % [target.y + 1, target.x + 1]
	var message := "%s还需要 1 个皇冠，%s，所以只剩 %s。" % [unit_name, summary, target_text]
	message += " 这个格所在列还剩 %d 个候选，%s还剩 %d 个候选。" % [_available_candidates_in_col(target.x).size(), _region_name(target_region), _available_candidates_in_region(target_region).size()]
	if detail != "":
		message += " 例如：%s。" % detail
	return message


func _best_locked_candidate_hint() -> Dictionary:
	for row in range(int(current_level["rows"])):
		if _row_has_piece(row):
			continue
		var candidates := _available_candidates_in_row(row)
		if candidates.size() >= 2 and candidates.size() <= 3:
			var region_id := _shared_region(candidates)
			if region_id > 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_region(region_id), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint("第 %d 行" % [row + 1], candidates, _region_name(region_id), other_cells)

	for col in range(int(current_level["cols"])):
		if _col_has_piece(col):
			continue
		var candidates := _available_candidates_in_col(col)
		if candidates.size() >= 2 and candidates.size() <= 3:
			var region_id := _shared_region(candidates)
			if region_id > 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_region(region_id), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint("第 %d 列" % [col + 1], candidates, _region_name(region_id), other_cells)

	for region_id in _region_ids():
		if _region_has_piece(region_id):
			continue
		var candidates := _available_candidates_in_region(region_id)
		if candidates.size() >= 2 and candidates.size() <= 3:
			var row := _shared_row(candidates)
			if row >= 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_row(row), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint(_region_name(region_id), candidates, "第 %d 行" % [row + 1], other_cells)
			var col := _shared_col(candidates)
			if col >= 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_col(col), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint(_region_name(region_id), candidates, "第 %d 列" % [col + 1], other_cells)
	return {}


func _make_locked_hint(source_name: String, locked_cells: Array[Vector2i], target_name: String, other_cells: Array[Vector2i]) -> Dictionary:
	var guides := {}
	for cell in locked_cells:
		guides[cell] = "candidate"
	for cell in other_cells:
		guides[cell] = "exclude"
	var focus := locked_cells[0]
	return {
		"target": focus,
		"guides": guides,
		"message": "%s的皇冠只可能在这些绿色候选里，而这些候选都落在%s内。因此%s里的其它橙色候选可以先排除。" % [source_name, target_name, target_name]
	}


func _best_subset_lock_hint() -> Dictionary:
	var pairs := [
		["row", "col"],
		["col", "row"],
		["row", "region"],
		["col", "region"],
		["region", "row"],
		["region", "col"]
	]
	for pair in pairs:
		var source_kind := str(pair[0])
		var target_kind := str(pair[1])
		var units := _open_unit_candidates(source_kind)
		for group_size in range(2, 4):
			var combinations := _unit_index_combinations(units.size(), group_size)
			for combination in combinations:
				var source_names: Array[String] = []
				var source_cells: Array[Vector2i] = []
				var target_values: Array[int] = []
				for unit_position in combination:
					var unit: Dictionary = units[int(unit_position)]
					source_names.append(str(unit["name"]))
					for cell in unit["candidates"]:
						if not source_cells.has(cell):
							source_cells.append(cell)
						var value := _cell_unit_value(cell, target_kind)
						if not target_values.has(value):
							target_values.append(value)
				if target_values.size() != group_size:
					continue
				var other_cells: Array[Vector2i] = []
				for target_value in target_values:
					for cell in _available_candidates_for_unit(target_kind, target_value):
						if not source_cells.has(cell) and not other_cells.has(cell):
							other_cells.append(cell)
				if not other_cells.is_empty():
					return _make_subset_lock_hint(source_names, source_cells, target_kind, target_values, other_cells)
	return {}


func _make_subset_lock_hint(source_names: Array[String], source_cells: Array[Vector2i], target_kind: String, target_values: Array[int], other_cells: Array[Vector2i]) -> Dictionary:
	var guides := {}
	for cell in source_cells:
		guides[cell] = "candidate"
	for cell in other_cells:
		guides[cell] = "exclude"
	var target_names: Array[String] = []
	for value in target_values:
		target_names.append(_unit_name_by_kind(target_kind, value))
	return {
		"target": other_cells[0],
		"guides": guides,
		"message": "%s的皇冠只能落在%s里。因为这些单元彼此占满了这组位置，所以%s中其它橙色候选可以排除。" % ["、".join(source_names), "、".join(target_names), "、".join(target_names)]
	}


func _best_lookahead_exclusion_hint() -> Dictionary:
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var cell := Vector2i(col, row)
			if not _is_available_candidate(cell):
				continue
			var blocked_unit := _blocked_unit_after_assume(cell)
			if blocked_unit.is_empty():
				continue
			var unit_name := _unit_name_by_kind(str(blocked_unit["kind"]), int(blocked_unit["index"]))
			var guides := {}
			guides[cell] = "exclude"
			for peer in _unit_cells_by_kind(str(blocked_unit["kind"]), int(blocked_unit["index"])):
				if peer != cell:
					guides[peer] = "unit"
			return {
				"target": cell,
				"guides": guides,
				"message": "如果第 %d 行第 %d 列是皇冠，%s就没有任何可找皇冠的位置了。所以这个橙色格一定不是皇冠，可以先标 X。" % [row + 1, col + 1, unit_name]
			}
	return {}


func _best_exclusion_hint() -> Dictionary:
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var cell := Vector2i(col, row)
			if cell_states[row][col] != "empty":
				continue
			var reason := _first_conflict_reason(cell)
			if reason == "":
				continue
			var guides := {}
			guides[cell] = "exclude"
			for piece in _piece_positions():
				if _piece_conflicts_with_cell(piece, cell):
					guides[piece] = "place"
					break
			return {
				"target": cell,
				"guides": guides,
				"message": "第 %d 行第 %d 列可以排除：%s。这个格不可能是皇冠，先标 X 能减少后面的候选。" % [row + 1, col + 1, reason]
			}
	return {}


func _best_candidate_focus_hint() -> Dictionary:
	var best := Vector2i(-1, -1)
	var best_score := 999
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var cell := Vector2i(col, row)
			if not _is_available_candidate(cell):
				continue
			var score := _available_candidates_in_row(row).size() + _available_candidates_in_col(col).size() + _available_candidates_in_region(int(current_level["regions"][row][col])).size()
			if score < best_score:
				best_score = score
				best = cell
	if best.x < 0:
		return {}
	var region_id := int(current_level["regions"][best.y][best.x])
	var guides := {}
	for cell in _row_cells(best.y):
		guides[cell] = "unit"
	for cell in _available_candidates_in_row(best.y):
		guides[cell] = "candidate"
	guides[best] = "place"
	return {
		"target": best,
		"guides": guides,
		"message": "当前没有唯一答案，但第 %d 行第 %d 列最值得优先比较：它所在行剩 %d 个候选，列剩 %d 个候选，%s剩 %d 个候选。先围绕这些候选继续排除。" % [best.y + 1, best.x + 1, _available_candidates_in_row(best.y).size(), _available_candidates_in_col(best.x).size(), _region_name(region_id), _available_candidates_in_region(region_id).size()]
	}


func _guides_for_unit(unit_cells: Array[Vector2i], candidates: Array[Vector2i], exclusions: Array[Dictionary]) -> Dictionary:
	var guides := {}
	for cell in unit_cells:
		guides[cell] = "unit"
	for item in exclusions:
		guides[item["cell"]] = "exclude"
	for cell in candidates:
		guides[cell] = "candidate"
	return guides


func _exclusion_summary(exclusions: Array[Dictionary]) -> String:
	var blocked := 0
	var occupied := 0
	var conflict := 0
	for item in exclusions:
		var reason := str(item["reason"])
		if reason == "已标 X":
			blocked += 1
		elif reason == "已有皇冠":
			occupied += 1
		else:
			conflict += 1
	var parts: Array[String] = []
	if blocked > 0:
		parts.append("%d 个已被你标 X" % blocked)
	if occupied > 0:
		parts.append("%d 个已经有皇冠" % occupied)
	if conflict > 0:
		parts.append("%d 个会和已有皇冠冲突" % conflict)
	if parts.is_empty():
		return "其它格都不适合"
	return "其它格中：" + "，".join(parts)


func _first_exclusion_detail(exclusions: Array[Dictionary]) -> String:
	for item in exclusions:
		var reason := str(item["reason"])
		if reason != "已标 X" and reason != "已有皇冠":
			var cell: Vector2i = item["cell"]
			return "第 %d 行第 %d 列被排除，因为%s" % [cell.y + 1, cell.x + 1, reason]
	return ""


func _piece_conflicts_with_cell(piece: Vector2i, cell: Vector2i) -> bool:
	return piece.y == cell.y or piece.x == cell.x or int(current_level["regions"][piece.y][piece.x]) == int(current_level["regions"][cell.y][cell.x]) or (absi(piece.x - cell.x) <= 1 and absi(piece.y - cell.y) <= 1)


func _region_name(region_id: int) -> String:
	var index := region_id - 1
	if index >= 0 and index < REGION_COLOR_NAMES.size():
		return "%s区域" % REGION_COLOR_NAMES[index]
	return "这个颜色区域"


func _shared_region(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var region_id := int(current_level["regions"][cells[0].y][cells[0].x])
	for cell in cells:
		if int(current_level["regions"][cell.y][cell.x]) != region_id:
			return -1
	return region_id


func _shared_row(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var row := cells[0].y
	for cell in cells:
		if cell.y != row:
			return -1
	return row


func _shared_col(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var col := cells[0].x
	for cell in cells:
		if cell.x != col:
			return -1
	return col


func _candidate_cells_except(cells: Array[Vector2i], excluded: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if not excluded.has(cell):
			result.append(cell)
	return result


func _open_unit_candidates(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in _unit_indices_by_kind(kind):
		if _unit_has_piece(kind, index):
			continue
		var candidates := _available_candidates_for_unit(kind, index)
		if candidates.size() > 1:
			result.append({
				"index": index,
				"name": _unit_name_by_kind(kind, index),
				"candidates": candidates
			})
	return result


func _available_candidates_for_unit(kind: String, index: int) -> Array[Vector2i]:
	match kind:
		"row":
			return _available_candidates_in_row(index)
		"col":
			return _available_candidates_in_col(index)
		"region":
			return _available_candidates_in_region(index)
		_:
			return []


func _unit_indices_by_kind(kind: String) -> Array[int]:
	var result: Array[int] = []
	match kind:
		"row":
			for row in range(int(current_level["rows"])):
				result.append(row)
		"col":
			for col in range(int(current_level["cols"])):
				result.append(col)
		"region":
			return _region_ids()
	return result


func _unit_has_piece(kind: String, index: int) -> bool:
	match kind:
		"row":
			return _row_has_piece(index)
		"col":
			return _col_has_piece(index)
		"region":
			return _region_has_piece(index)
		_:
			return false


func _unit_name_by_kind(kind: String, index: int) -> String:
	match kind:
		"row":
			return "第 %d 行" % [index + 1]
		"col":
			return "第 %d 列" % [index + 1]
		"region":
			return _region_name(index)
		_:
			return "这个单元"


func _unit_cells_by_kind(kind: String, index: int) -> Array[Vector2i]:
	match kind:
		"row":
			return _row_cells(index)
		"col":
			return _col_cells(index)
		"region":
			return _region_cells(index)
		_:
			return []


func _cell_unit_value(cell: Vector2i, kind: String) -> int:
	match kind:
		"row":
			return cell.y
		"col":
			return cell.x
		"region":
			return int(current_level["regions"][cell.y][cell.x])
		_:
			return -1


func _unit_index_combinations(count: int, group_size: int) -> Array[Array]:
	var result: Array[Array] = []
	if group_size == 2:
		for a in range(count):
			for b in range(a + 1, count):
				result.append([a, b])
	elif group_size == 3:
		for a in range(count):
			for b in range(a + 1, count):
				for c in range(b + 1, count):
					result.append([a, b, c])
	return result


func _blocked_unit_after_assume(cell: Vector2i) -> Dictionary:
	var kinds := ["row", "col", "region"]
	for kind in kinds:
		for index in _unit_indices_by_kind(kind):
			if _unit_has_piece_after_assume(kind, index, cell):
				continue
			var has_candidate := false
			for unit_cell in _unit_cells_by_kind(kind, index):
				if _is_available_after_assume(unit_cell, cell):
					has_candidate = true
					break
			if not has_candidate:
				return {"kind": kind, "index": index}
	return {}


func _unit_has_piece_after_assume(kind: String, index: int, assumed: Vector2i) -> bool:
	if _cell_unit_value(assumed, kind) == index:
		return true
	return _unit_has_piece(kind, index)


func _is_available_after_assume(position: Vector2i, assumed: Vector2i) -> bool:
	if position == assumed:
		return false
	if not _is_available_candidate(position):
		return false
	if position.y == assumed.y or position.x == assumed.x:
		return false
	if int(current_level["regions"][position.y][position.x]) == int(current_level["regions"][assumed.y][assumed.x]):
		return false
	if absi(position.x - assumed.x) <= 1 and absi(position.y - assumed.y) <= 1:
		return false
	return true


func _select_prepared_hint_step() -> Dictionary:
	var steps: Array = current_level.get("hintSteps", [])
	for raw_step in steps:
		var step: Dictionary = raw_step
		if _hint_step_still_relevant(step):
			return step
	var fallback := _build_teaching_hint()
	if fallback.is_empty():
		return {}
	return {
		"target": [fallback["target"].y, fallback["target"].x],
		"unit": "row",
		"unitIndex": fallback["target"].y,
		"title": "观察第 %d 行" % [fallback["target"].y + 1],
		"technique": "候选排除"
	}


func _hint_step_still_relevant(step: Dictionary) -> bool:
	if step.is_empty() or not step.has("target"):
		return false
	var target := _step_target(step)
	if target.x < 0:
		return false
	var state: String = cell_states[target.y][target.x]
	return not _is_piece_state(state)


func _build_staged_hint(step: Dictionary, stage: int) -> Dictionary:
	if step.is_empty():
		return _build_teaching_hint()
	var target := _step_target(step)
	var unit_cells := _step_unit_cells(step)
	if unit_cells.is_empty():
		return _build_teaching_hint()

	var unit_name := _step_unit_name(step)
	var candidates := _available_candidates_in_cells(unit_cells)
	var exclusions := _excluded_cells_in_cells(unit_cells)
	var stage_number := clampi(stage + 1, 1, 3)

	if stage_number == 1:
		var guides := {}
		for cell in unit_cells:
			guides[cell] = "unit"
		return {
			"stage": stage_number,
			"target": target,
			"guides": guides,
			"message": "提示 1/3：先看%s。这个单元最终需要 1 个皇冠，先不要急着放，先找哪些格子还可能成为候选。" % unit_name
		}

	if stage_number == 2:
		var guides := {}
		for cell in candidates:
			guides[cell] = "candidate"
		for item in exclusions:
			guides[item["cell"]] = "exclude"
		return {
			"stage": stage_number,
			"target": target if candidates.has(target) else Vector2i(-1, -1),
			"guides": guides,
			"message": _candidate_breakdown_message(unit_name, candidates, exclusions, unit_cells)
		}

	var final_guides := {}
	var final_target := target
	if candidates.size() == 1:
		final_target = candidates[0]
		final_guides[final_target] = "place"
		return {
			"stage": stage_number,
			"target": final_target,
			"guides": final_guides,
			"message": "%s现在只剩 1 个合法候选：第 %d 行第 %d 列。原因是其它格已经被 X、已有皇冠或冲突规则排除了。" % [unit_name, final_target.y + 1, final_target.x + 1]
		}
	if candidates.has(target):
		final_guides[target] = "place"
		return {
			"stage": stage_number,
			"target": target,
			"guides": final_guides,
			"message": "%s还剩 %d 个候选。绿色格是预设解题路径中的下一步候选，但现在还需要你结合其它行、列或颜色区域继续验证。" % [unit_name, candidates.size()]
		}
	if not candidates.is_empty():
		final_target = candidates[0]
		final_guides[final_target] = "candidate"
		return {
			"stage": stage_number,
			"target": final_target,
			"guides": final_guides,
			"message": "%s的原提示位置已经不适合当前棋盘。先从这个仍合法的候选继续分析。" % unit_name
		}
	return _build_teaching_hint()


func _step_target(step: Dictionary) -> Vector2i:
	var target: Array = step.get("target", [])
	if target.size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(int(target[1]), int(target[0]))


func _step_unit_cells(step: Dictionary) -> Array[Vector2i]:
	var unit := str(step.get("unit", "row"))
	var unit_index := int(step.get("unitIndex", 0))
	match unit:
		"row":
			return _row_cells(unit_index)
		"col":
			return _col_cells(unit_index)
		"region":
			return _region_cells(unit_index)
		_:
			return _row_cells(_step_target(step).y)


func _step_unit_name(step: Dictionary) -> String:
	var unit := str(step.get("unit", "row"))
	var unit_index := int(step.get("unitIndex", 0))
	match unit:
		"row":
			return "第 %d 行" % [unit_index + 1]
		"col":
			return "第 %d 列" % [unit_index + 1]
		"region":
			return _region_name(unit_index)
		_:
			return "这个单元"


func _available_candidates_in_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if _is_available_candidate(cell):
			result.append(cell)
	return result


func _excluded_cells_in_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in cells:
		var state: String = cell_states[cell.y][cell.x]
		if state == "blocked":
			result.append({"cell": cell, "reason": "已标 X"})
		elif _is_piece_state(state):
			result.append({"cell": cell, "reason": "已有皇冠"})
		else:
			var reason := _first_conflict_reason(cell)
			if reason != "":
				result.append({"cell": cell, "reason": reason})
	return result


func _candidate_breakdown_message(unit_name: String, candidates: Array[Vector2i], exclusions: Array[Dictionary], unit_cells: Array[Vector2i]) -> String:
	var blocked := 0
	var occupied := 0
	var conflict := 0
	for item in exclusions:
		var reason := str(item["reason"])
		if reason == "已标 X":
			blocked += 1
		elif reason == "已有皇冠":
			occupied += 1
		else:
			conflict += 1
	var reasons: Array[String] = []
	if blocked > 0:
		reasons.append("%d 个已被你标 X" % blocked)
	if occupied > 0:
		reasons.append("%d 个已有皇冠" % occupied)
	if conflict > 0:
		reasons.append("%d 个会和已有皇冠冲突" % conflict)
	var reason_text := "目前没有明确排除格"
	if not reasons.is_empty():
		reason_text = "已经排除：" + "，".join(reasons)
	return "提示 2/3：%s共有 %d 格，%s；还剩 %d 个绿色候选。先比较这些候选的列和颜色区域。" % [unit_name, unit_cells.size(), reason_text, candidates.size()]


func _build_teaching_hint() -> Dictionary:
	var rows := int(current_level["rows"])
	var cols := int(current_level["cols"])

	for row in range(rows):
		if _row_has_piece(row):
			continue
		var row_candidates := _available_candidates_in_row(row)
		if row_candidates.size() == 1:
			var position: Vector2i = row_candidates[0]
			return {
				"kind": "place",
				"target": position,
				"message": _single_candidate_message("第 %d 行" % [row + 1], position, _row_cells(row))
			}

	for col in range(cols):
		if _col_has_piece(col):
			continue
		var col_candidates := _available_candidates_in_col(col)
		if col_candidates.size() == 1:
			var position: Vector2i = col_candidates[0]
			return {
				"kind": "place",
				"target": position,
				"message": _single_candidate_message("第 %d 列" % [col + 1], position, _col_cells(col))
			}

	for region_id in _region_ids():
		if _region_has_piece(region_id):
			continue
		var region_candidates := _available_candidates_in_region(region_id)
		if region_candidates.size() == 1:
			var position: Vector2i = region_candidates[0]
			return {
				"kind": "place",
				"target": position,
				"message": _single_candidate_message(_region_name(region_id), position, _region_cells(region_id))
			}

	var exclusion_hint := _build_exclusion_hint()
	if not exclusion_hint.is_empty():
		return exclusion_hint

	var fallback := _build_candidate_hint()
	if not fallback.is_empty():
		return fallback
	return {}


func _build_exclusion_hint() -> Dictionary:
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			if cell_states[row][col] != "empty":
				continue
			var reason := _first_conflict_reason(Vector2i(col, row))
			if reason != "":
				return {
					"kind": "exclude",
					"target": Vector2i(col, row),
					"message": "橙色格可以排除：%s。点它标记 X，可以缩小候选范围。" % reason
				}
	return {}


func _build_candidate_hint() -> Dictionary:
	var best := Vector2i(-1, -1)
	var best_score := 999
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var position := Vector2i(col, row)
			if not _is_available_candidate(position):
				continue
			var row_count := _available_candidates_in_row(row).size()
			var col_count := _available_candidates_in_col(col).size()
			var region_count := _available_candidates_in_region(int(current_level["regions"][row][col])).size()
			var score := row_count + col_count + region_count
			if score < best_score:
				best_score = score
				best = position
	if best.x < 0:
		return {}
	var region_id := int(current_level["regions"][best.y][best.x])
	return {
		"kind": "place",
		"target": best,
		"message": "绿色格目前仍是合法候选：第 %d 行还有 %d 个候选，第 %d 列还有 %d 个候选，%s还有 %d 个候选。它还不能确定，但值得重点比较。" % [best.y + 1, _available_candidates_in_row(best.y).size(), best.x + 1, _available_candidates_in_col(best.x).size(), _region_name(region_id), _available_candidates_in_region(region_id).size()]
	}


func _single_candidate_message(unit_name: String, position: Vector2i, unit_cells: Array[Vector2i]) -> String:
	var blocked := 0
	var conflict := 0
	var occupied := 0
	for cell in unit_cells:
		if cell == position:
			continue
		var state: String = cell_states[cell.y][cell.x]
		if state == "blocked":
			blocked += 1
		elif _is_piece_state(state):
			occupied += 1
		elif _first_conflict_reason(cell) != "":
			conflict += 1
	var reasons: Array[String] = []
	if blocked > 0:
		reasons.append("%d 个已被你标 X" % blocked)
	if conflict > 0:
		reasons.append("%d 个会和已有皇冠冲突" % conflict)
	if occupied > 0:
		reasons.append("%d 个已经有皇冠" % occupied)
	var reason_text := "其它格都不适合"
	if not reasons.is_empty():
		reason_text = "其它格中：" + "，".join(reasons)
	return "%s还需要一个皇冠。%s；所以只剩第 %d 行第 %d 列。" % [unit_name, reason_text, position.y + 1, position.x + 1]


func _available_candidates_in_row(row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for col in range(int(current_level["cols"])):
		var position := Vector2i(col, row)
		if _is_available_candidate(position):
			result.append(position)
	return result


func _available_candidates_in_col(col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(current_level["rows"])):
		var position := Vector2i(col, row)
		if _is_available_candidate(position):
			result.append(position)
	return result


func _available_candidates_in_region(region_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _region_cells(region_id):
		if _is_available_candidate(cell):
			result.append(cell)
	return result


func _is_available_candidate(position: Vector2i) -> bool:
	if cell_states[position.y][position.x] != "empty":
		return false
	return _first_conflict_reason(position) == ""


func _first_conflict_reason(position: Vector2i) -> String:
	for piece in _piece_positions():
		if piece.y == position.y:
			return "它和第 %d 行第 %d 列的皇冠在同一行" % [piece.y + 1, piece.x + 1]
		if piece.x == position.x:
			return "它和第 %d 行第 %d 列的皇冠在同一列" % [piece.y + 1, piece.x + 1]
		if int(current_level["regions"][piece.y][piece.x]) == int(current_level["regions"][position.y][position.x]):
			return "它和第 %d 行第 %d 列的皇冠都在%s" % [piece.y + 1, piece.x + 1, _region_name(int(current_level["regions"][position.y][position.x]))]
		if absi(piece.x - position.x) <= 1 and absi(piece.y - position.y) <= 1:
			return "它和第 %d 行第 %d 列的皇冠相邻" % [piece.y + 1, piece.x + 1]
	return ""


func _row_cells(row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for col in range(int(current_level["cols"])):
		result.append(Vector2i(col, row))
	return result


func _col_cells(col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(current_level["rows"])):
		result.append(Vector2i(col, row))
	return result


func _region_cells(region_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			if int(current_level["regions"][row][col]) == region_id:
				result.append(Vector2i(col, row))
	return result


func _region_ids() -> Array[int]:
	var result: Array[int] = []
	for row in current_level["regions"]:
		for region in row:
			var region_id := int(region)
			if not result.has(region_id):
				result.append(region_id)
	return result


func _row_has_piece(row: int) -> bool:
	for col in range(int(current_level["cols"])):
		if _is_piece_state(str(cell_states[row][col])):
			return true
	return false


func _col_has_piece(col: int) -> bool:
	for row in range(int(current_level["rows"])):
		if _is_piece_state(str(cell_states[row][col])):
			return true
	return false


func _region_has_piece(region_id: int) -> bool:
	for cell in _region_cells(region_id):
		if _is_piece_state(str(cell_states[cell.y][cell.x])):
			return true
	return false


func _piece_positions() -> Array:
	var result: Array = []
	for row in range(cell_states.size()):
		for col in range(cell_states[row].size()):
			if _is_piece_state(str(cell_states[row][col])):
				result.append(Vector2i(col, row))
	return result


func _has_blocked_cells() -> bool:
	for row in cell_states:
		if row.has("blocked"):
			return true
	return false


func _clearable_marks_empty() -> bool:
	for row in range(cell_states.size()):
		for col in range(cell_states[row].size()):
			var state: String = cell_states[row][col]
			if state == "blocked" or state == "piece" or state == "wrong":
				return false
	return true



func _start_tutorial_step(index: int) -> void:
	if dialog_controller and dialog_controller.visible:
		dialog_controller.hide_dialog(true)
	in_tutorial = true
	if coach_panel:
		coach_panel.show()
	tutorial_started = true
	tutorial_step_index = clampi(index, 0, TUTORIAL_LEVELS.size() - 1)
	tutorial_interaction_stage = TUTORIAL_PHASE_PLACE
	tutorial_button_stage = 0
	current_level = TUTORIAL_LEVELS[tutorial_step_index]
	tutorial_solution_index = 0
	tutorial_active_crown = Vector2i(-1, -1)
	tutorial_hint_target = _tutorial_solution_cells()[0]
	tutorial_hint_button_taught = false
	tutorial_crown_find_taught = false
	is_completed = false
	active_hint_step.clear()
	active_hint_stage = 0
	move_history.clear()
	completion_overlay.hide()
	_hide_tutorial_hand()
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	for coordinate in current_level.get("prefill", []):
		cell_states[int(coordinate[0])][int(coordinate[1])] = "piece"
	if _tutorial_kind() == "tools":
		_set_tutorial_button_demo_state(0)
	level_label.text = _runtime_text(str(current_level.get("title", "新手教程")))
	coach_label.text = _runtime_text(
		str(current_level["tutorial"]),
		"请观察棋盘中保持明亮的格子，并根据行、列、颜色区域和相邻规则继续推理。"
	)
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	if progress_bar:
		progress_bar.max_value = int(current_level["targetCount"])
		progress_bar.value = 0
	if progress_label:
		progress_label.text = "%d / %d" % [0, int(current_level["targetCount"])]
	if level_picker:
		level_picker.disabled = true
	if tutorial_skip_button:
		_update_tutorial_button()
	if completion_next_button:
		var final_action := "返回关卡  →" if _formal_progress_snapshot_is_valid(formal_progress_snapshot) else "进入第 1 关  →"
		completion_next_button.text = "下一步  →" if tutorial_step_index < TUTORIAL_LEVELS.size() - 1 else final_action
	if completion_replay_button:
		completion_replay_button.text = "重来本步"
		completion_replay_button.show()
	board.set_level(current_level, cell_states, REGION_COLORS)
	_set_tutorial_guides()
	_update_tutorial_action_bar()
	_show_game()
	var kind := _tutorial_kind()
	if kind == "single_map":
		call_deferred("_focus_tutorial_cell", _tutorial_solution_cells()[0], 0.36)
	elif kind == "place":
		call_deferred("_focus_tutorial_cell", _tutorial_target(), 0.36)
	elif kind == "color":
		call_deferred("_focus_tutorial_cell", _next_tutorial_color_cell(), 0.36)
	elif kind == "row_col":
		call_deferred("_focus_tutorial_cell", _next_tutorial_row_col_cell(), 0.36)
	elif kind == "adjacent":
		call_deferred("_focus_tutorial_cell", _next_tutorial_adjacent_cell(), 0.36)
	elif kind == "adjacent_row_col":
		call_deferred("_focus_tutorial_cell", _next_tutorial_adjacent_row_col_cell(), 0.36)
	elif kind == "tools":
		tutorial_button_stage = 2
		call_deferred("_focus_tutorial_control", hint_button, 0.24)
	_update_hint_button()
	_update_home()
	_save_game()


func _set_tutorial_guides() -> void:
	var guides := {}
	var target := _tutorial_target()
	match _tutorial_kind():
		"single_map":
			if tutorial_interaction_stage == TUTORIAL_PHASE_PLACE or tutorial_interaction_stage == TUTORIAL_PHASE_HINT_PLACE:
				var place_target := _current_tutorial_place_target()
				if place_target.x >= 0:
					guides[place_target] = "place"
			elif tutorial_interaction_stage == TUTORIAL_PHASE_ADJACENT or tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
				var exclusion_target := _next_tutorial_single_map_exclusion_cell()
				if exclusion_target.x >= 0:
					guides[exclusion_target] = "exclude_empty"
		"place":
			guides[target] = "place"
		"color":
			var color_cell := _next_tutorial_color_cell()
			if color_cell.x >= 0:
				guides[color_cell] = "exclude_empty"
		"row_col":
			var row_col_cell := _next_tutorial_row_col_cell()
			if row_col_cell.x >= 0:
				guides[row_col_cell] = "exclude_empty"
		"adjacent":
			var next_cell := _next_tutorial_adjacent_cell()
			if next_cell.x >= 0:
				guides[next_cell] = "exclude_empty"
		"adjacent_row_col":
			var combined_cell := _next_tutorial_adjacent_row_col_cell()
			if combined_cell.x >= 0:
				guides[combined_cell] = "exclude_empty"
		"tools":
			guides = _tutorial_button_guides()
	board.set_guides(guides)


func _update_tutorial_action_bar() -> void:
	if not hint_button:
		return
	_restore_action_button_styles()
	if crown_find_button:
		crown_find_button.visible = true
	if clear_button:
		clear_button.visible = true
		clear_button.disabled = true
		_refresh_tool_button_visual(clear_button)
	if in_tutorial and _tutorial_kind() == "single_map":
		hint_button.visible = true
		hint_button.disabled = tutorial_interaction_stage != TUTORIAL_PHASE_HINT
		_apply_action_button_style(hint_button, Color("#FFE06F") if tutorial_interaction_stage == TUTORIAL_PHASE_HINT else Color("#EAFBF0"))
		hint_button.add_theme_color_override("font_color", INK if tutorial_interaction_stage == TUTORIAL_PHASE_HINT else Color("#2D9E63"))
		_update_hint_button()
		_update_crown_find_button()
		if tutorial_interaction_stage == TUTORIAL_PHASE_HINT:
			coach_label.text = "点一下提示，看看下一步该观察哪里。"
		elif tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND:
			coach_label.text = "点击皇冠直找，直接找到一个皇冠。教程中不会消耗使用次数。"
			_apply_action_button_style(crown_find_button, Color("#FFE06F"))
			crown_find_button.add_theme_color_override("font_color", INK)
		return
	var show_actions := in_tutorial and _tutorial_kind() == "tools"
	hint_button.visible = show_actions
	if not show_actions:
		return
	hint_button.disabled = tutorial_button_stage != 2
	_update_tutorial_action_button_styles()
	if tutorial_button_stage == 2:
		coach_label.text = "点一下提示，看看下一步该观察哪里。"


func _update_tutorial_action_button_styles() -> void:
	_apply_action_button_style(hint_button, Color("#FFE06F") if tutorial_button_stage == 2 else Color("#F6FBFF"))
	hint_button.add_theme_color_override("font_color", INK)


func _restore_action_button_styles() -> void:
	if undo_button:
		_apply_action_button_style(undo_button, CARD)
	if clear_button:
		_apply_action_button_style(clear_button, Color("#EEF5FF"))
	if crown_find_button:
		_apply_action_button_style(crown_find_button, Color("#FFF4CE"))
		crown_find_button.add_theme_color_override("font_color", Color("#B97A09"))
	if hint_button:
		_apply_action_button_style(hint_button, Color("#EAFBF0"))
		hint_button.add_theme_color_override("font_color", Color("#2D9E63"))


func _tutorial_target() -> Vector2i:
	var target: Array = current_level.get("target", [0, 0])
	return Vector2i(int(target[1]), int(target[0]))


func _tutorial_kind() -> String:
	return str(current_level.get("kind", "place"))


func _on_tutorial_cell_pressed(row: int, col: int) -> void:
	if is_completed:
		return
	var target := _tutorial_target()
	var kind := _tutorial_kind()
	if kind == "single_map":
		_on_tutorial_single_map_pressed(row, col)
		return
	if kind == "color":
		_on_tutorial_color_cell_pressed(row, col, target)
		return
	if kind == "row_col":
		_on_tutorial_row_col_cell_pressed(row, col, target)
		return
	if kind == "adjacent":
		_on_tutorial_adjacent_cell_pressed(row, col, target)
		return
	if kind == "adjacent_row_col":
		_on_tutorial_adjacent_row_col_cell_pressed(row, col, target)
		return
	if kind == "tools":
		_on_tutorial_hint_target_pressed(row, col, target)
		return
	if Vector2i(col, row) != target:
		_show_toast("先跟着高亮格操作")
		_focus_tutorial_cell(target, 0.12)
		return
	if kind == "place":
		_show_toast("请双击找到皇冠")
		_focus_tutorial_cell(target, 0.12)
		return


func _on_tutorial_cell_double_pressed(row: int, col: int) -> void:
	if is_completed:
		return
	var target := _tutorial_target()
	var kind := _tutorial_kind()
	if kind == "single_map":
		_on_tutorial_single_map_double_pressed(row, col)
		return
	if kind != "place" and kind != "tools":
		_show_toast("这一步请单击高亮格标记 X")
		return
	if Vector2i(col, row) != target:
		_show_toast("请双击找到皇冠")
		_focus_tutorial_cell(target, 0.12)
		return
	if kind == "tools" and tutorial_button_stage != 3:
		_show_toast("先点击底部提示按钮")
		return
	cell_states[row][col] = "piece"
	audio_controller.play_correct()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	if kind == "tools":
		board.set_guides({})
		_hide_tutorial_hand()
		if progress_bar:
			progress_bar.value = 4
		if progress_label:
			progress_label.text = "4 / 4"
		_show_tutorial_challenge_ready()
	else:
		_validate_tutorial_step(row, col)
	_save_game()


func _on_tutorial_drag_started(row: int, col: int) -> void:
	if is_completed:
		return
	if _tutorial_kind() == "single_map":
		_on_tutorial_single_map_exclusion(row, col, true)


func _on_tutorial_dragged(row: int, col: int) -> void:
	if is_completed:
		return
	if _tutorial_kind() == "single_map":
		_on_tutorial_single_map_exclusion(row, col, true)


func _on_tutorial_drag_ended() -> void:
	pass


func _on_tutorial_color_cell_pressed(row: int, col: int, crown: Vector2i) -> void:
	var cell := Vector2i(col, row)
	if not _tutorial_color_cells(crown).has(cell):
		_show_toast("请把这个颜色区域里高亮的格子标记为 X")
		_focus_tutorial_cell(_next_tutorial_color_cell(), 0.12)
		return
	if cell_states[row][col] != "blocked":
		cell_states[row][col] = "blocked"
		audio_controller.play_mark()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_validate_tutorial_step(row, col)
	if not is_completed:
		_set_tutorial_guides()
		_focus_tutorial_cell(_next_tutorial_color_cell(), 0.15)
	_save_game()


func _on_tutorial_row_col_cell_pressed(row: int, col: int, crown: Vector2i) -> void:
	var cell := Vector2i(col, row)
	if not _tutorial_row_col_cells(crown).has(cell):
		_show_toast("请把同行同列里高亮的格子标记为 X")
		_focus_tutorial_cell(_next_tutorial_row_col_cell(), 0.12)
		return
	if cell_states[row][col] != "blocked":
		cell_states[row][col] = "blocked"
		audio_controller.play_mark()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_validate_tutorial_step(row, col)
	if not is_completed:
		_set_tutorial_guides()
		_focus_tutorial_cell(_next_tutorial_row_col_cell(), 0.15)
	_save_game()


func _on_tutorial_adjacent_cell_pressed(row: int, col: int, crown: Vector2i) -> void:
	var cell := Vector2i(col, row)
	if not _tutorial_adjacent_cells(crown).has(cell):
		_show_toast("请把皇冠周围高亮的格子标记为 X")
		_focus_tutorial_cell(_next_tutorial_adjacent_cell(), 0.12)
		return
	if cell_states[row][col] != "blocked":
		cell_states[row][col] = "blocked"
		audio_controller.play_mark()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_validate_tutorial_step(row, col)
	if not is_completed:
		_set_tutorial_guides()
		_focus_tutorial_cell(_next_tutorial_adjacent_cell(), 0.15)
	_save_game()


func _on_tutorial_adjacent_row_col_cell_pressed(row: int, col: int, crown: Vector2i) -> void:
	var cell := Vector2i(col, row)
	var expected := _next_tutorial_adjacent_row_col_cell()
	if cell != expected:
		_show_toast("请按小手指引，把当前高亮格标记为 X")
		_focus_tutorial_cell(expected, 0.12)
		return
	if cell_states[row][col] != "blocked":
		cell_states[row][col] = "blocked"
		audio_controller.play_mark()
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_validate_tutorial_step(row, col)
	if not is_completed:
		_set_tutorial_guides()
		_focus_tutorial_cell(_next_tutorial_adjacent_row_col_cell(), 0.15)
	_save_game()


func _on_tutorial_hint_target_pressed(row: int, col: int, target: Vector2i) -> void:
	if tutorial_button_stage != 3:
		_show_toast("先点击底部提示按钮")
		return
	if Vector2i(col, row) != target:
		_show_toast("请双击高亮格找到皇冠")
		_focus_tutorial_cell(target, 0.12)
		return
	_show_toast("请双击高亮格找到皇冠")
	_focus_tutorial_cell(target, 0.12)


func _on_tutorial_single_map_pressed(row: int, col: int) -> void:
	if tutorial_interaction_stage == TUTORIAL_PHASE_ADJACENT or tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
		_on_tutorial_single_map_exclusion(row, col, false)
		return
	if tutorial_interaction_stage == TUTORIAL_PHASE_HINT:
		_show_toast("先点一下提示，看看下一步该观察哪里。")
		_focus_tutorial_control(hint_button, 0.12)
		return
	if tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND:
		_show_toast("先点击底部皇冠直找按钮")
		_focus_tutorial_control(crown_find_button, 0.12)
		return
	var target := _current_tutorial_place_target()
	if Vector2i(col, row) == target:
		_show_toast("请双击找到皇冠")
	else:
		_show_toast("请先操作高亮格")
	_focus_tutorial_cell(target, 0.12)


func _on_tutorial_single_map_double_pressed(row: int, col: int) -> void:
	if tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND:
		_show_toast("这一阶段请点击底部皇冠直找按钮")
		_focus_tutorial_control(crown_find_button, 0.12)
		return
	if tutorial_interaction_stage != TUTORIAL_PHASE_PLACE and tutorial_interaction_stage != TUTORIAL_PHASE_HINT_PLACE:
		_show_toast("这一步请把高亮格标记为 X")
		_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), 0.12)
		return
	var target := _current_tutorial_place_target()
	if Vector2i(col, row) != target:
		_show_toast("请双击找到皇冠")
		_focus_tutorial_cell(target, 0.12)
		return
	_push_tutorial_history()
	cell_states[row][col] = "piece"
	audio_controller.play_correct()
	tutorial_active_crown = target
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_update_tutorial_progress()
	if tutorial_solution_index == 0:
		_show_toast("成功找到第一个皇冠")
	else:
		_show_toast("成功找到皇冠")
	tutorial_solution_index += 1
	if tutorial_solution_index >= _tutorial_solution_cells().size():
		tutorial_interaction_stage = TUTORIAL_PHASE_DONE
		board.set_guides({})
		_hide_tutorial_hand()
		_show_tutorial_challenge_ready()
		_save_game()
		return
	tutorial_interaction_stage = TUTORIAL_PHASE_ADJACENT
	if _next_tutorial_single_map_exclusion_cell().x < 0:
		_advance_tutorial_single_map_after_exclusions()
		_save_game()
		return
	coach_label.text = "皇冠不能和皇冠挨着。滑过它周围的格子，把这些位置标记为 X。"
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	_set_tutorial_guides()
	_update_tutorial_action_bar()
	_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), 0.15)
	_save_game()


func _on_tutorial_single_map_exclusion(row: int, col: int, from_drag: bool) -> void:
	if tutorial_interaction_stage != TUTORIAL_PHASE_ADJACENT and tutorial_interaction_stage != TUTORIAL_PHASE_ROW_COL:
		return
	var expected := _next_tutorial_single_map_exclusion_cell()
	if expected.x < 0:
		_advance_tutorial_single_map_after_exclusions()
		return
	var cell := Vector2i(col, row)
	var valid_cells := _tutorial_single_map_valid_exclusion_cells()
	if not valid_cells.has(cell) or cell != expected:
		if not from_drag:
			_show_toast("请点击当前高亮的格子")
			_focus_tutorial_cell(expected, 0.12)
		return
	if cell_states[row][col] == "empty":
		_push_tutorial_history()
		cell_states[row][col] = "blocked"
		audio_controller.play_mark()
	else:
		_focus_tutorial_cell(expected, 0.12)
		return
	board.set_states(cell_states)
	board.play_cell_feedback(row, col)
	_update_tutorial_progress()
	_advance_tutorial_single_map_after_exclusions()
	_save_game()


func _advance_tutorial_single_map_after_exclusions() -> void:
	if _next_tutorial_single_map_exclusion_cell().x >= 0:
		_set_tutorial_guides()
		_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), 0.16)
		_update_tutorial_action_bar()
		return
	if tutorial_interaction_stage == TUTORIAL_PHASE_ADJACENT:
		tutorial_interaction_stage = TUTORIAL_PHASE_ROW_COL
		if _next_tutorial_single_map_exclusion_cell().x < 0:
			_advance_tutorial_single_map_after_exclusions()
			return
		coach_label.text = "每行、每列都只能有一个皇冠。这个皇冠所在的行和列，其他格都可以标记 X。"
		_set_tutorial_guides()
		_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), 0.12)
		_update_tutorial_action_bar()
		return
	if _next_tutorial_solution_cell() == _tutorial_solution_cells().back():
		_show_direct_tutorial_crown_clue("每行、每列都要找到一个皇冠。现在只剩这个位置符合规则，双击找到最后一个皇冠。")
		return
	if not tutorial_hint_button_taught:
		tutorial_interaction_stage = TUTORIAL_PHASE_HINT
		coach_label.text = "点一下提示，看看下一步该观察哪里。"
		_set_tutorial_guides()
		_update_tutorial_action_bar()
		_focus_tutorial_control(hint_button, 0.18)
		return
	if not tutorial_crown_find_taught:
		tutorial_interaction_stage = TUTORIAL_PHASE_CROWN_FIND
		coach_label.text = "点击皇冠直找，直接找到一个皇冠。教程中不会消耗使用次数。"
		_set_tutorial_guides()
		_update_tutorial_action_bar()
		_focus_tutorial_control(crown_find_button, 0.18)
		return
	if tutorial_hint_button_taught:
		_show_direct_tutorial_crown_clue("每个颜色区域都要找到一个皇冠。现在这个区域只剩一个可选格，双击找到它。")
		return


func _tutorial_solution_cells() -> Array[Vector2i]:
	return [
		Vector2i(2, 2),
		Vector2i(1, 0),
		Vector2i(4, 1),
		Vector2i(3, 4),
		Vector2i(0, 3)
	]


func _current_tutorial_place_target() -> Vector2i:
	if tutorial_interaction_stage == TUTORIAL_PHASE_HINT_PLACE:
		return tutorial_hint_target
	var solution := _tutorial_solution_cells()
	if tutorial_solution_index >= 0 and tutorial_solution_index < solution.size():
		return solution[tutorial_solution_index]
	return Vector2i(-1, -1)


func _next_tutorial_solution_cell() -> Vector2i:
	var solution := _tutorial_solution_cells()
	if tutorial_solution_index >= 0 and tutorial_solution_index < solution.size():
		return solution[tutorial_solution_index]
	return Vector2i(-1, -1)


func _next_tutorial_single_map_exclusion_cell() -> Vector2i:
	var crown := tutorial_active_crown
	if crown.x < 0:
		return Vector2i(-1, -1)
	var cells := _tutorial_single_map_valid_exclusion_cells()
	for cell in cells:
		if cell_states[cell.y][cell.x] == "empty":
			return cell
	return Vector2i(-1, -1)


func _tutorial_single_map_valid_exclusion_cells() -> Array[Vector2i]:
	var crown := tutorial_active_crown
	if crown.x < 0:
		return []
	if tutorial_interaction_stage == TUTORIAL_PHASE_ADJACENT:
		return _tutorial_adjacent_cells(crown)
	if tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
		return _tutorial_row_col_cells(crown)
	return []


func _show_direct_tutorial_crown_clue(message: String) -> void:
	tutorial_hint_target = _next_tutorial_solution_cell()
	tutorial_interaction_stage = TUTORIAL_PHASE_HINT_PLACE
	coach_label.text = _runtime_text(message)
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	_set_tutorial_guides()
	_update_tutorial_action_bar()
	_focus_tutorial_cell(tutorial_hint_target, 0.18)


func _update_tutorial_progress() -> void:
	if progress_bar:
		progress_bar.value = _piece_positions().size()
	if progress_label:
		progress_label.text = "%d / %d" % [_piece_positions().size(), int(current_level["targetCount"])]

func _validate_tutorial_step(row: int, col: int) -> void:
	match _tutorial_kind():
		"place":
			if cell_states[row][col] == "piece":
				if progress_bar:
					progress_bar.value = 1
				if progress_label:
					progress_label.text = "1 / 1"
				coach_label.text = "成功找到皇冠"
				_hide_tutorial_hand()
				_complete_tutorial_step("你学会了找到皇冠。")
			else:
				coach_label.text = "这一关需要双击高亮格找到皇冠。"
		"color":
			var blocked_count := _tutorial_blocked_color_count(_tutorial_target())
			if progress_bar:
				progress_bar.value = blocked_count
			if progress_label:
				progress_label.text = "%d / 3" % blocked_count
			if blocked_count >= 3:
				_hide_tutorial_hand()
				_complete_tutorial_step("这个颜色区域只能有一个皇冠")
			else:
				coach_label.text = _runtime_text("这个颜色区域已经找到皇冠，还剩 %d 个格子可以标记为 X。" % [3 - blocked_count])
		"row_col":
			var blocked_count := _tutorial_blocked_row_col_count(_tutorial_target())
			if progress_bar:
				progress_bar.value = blocked_count
			if progress_label:
				progress_label.text = "%d / 6" % blocked_count
			if blocked_count >= 6:
				_hide_tutorial_hand()
				_complete_tutorial_step("皇冠所在的行和列都已排除")
			else:
				coach_label.text = _runtime_text("同行同列不能再有皇冠，还剩 %d 个格要排除。" % [6 - blocked_count])
		"adjacent":
			var blocked_count := _tutorial_blocked_adjacent_count(_tutorial_target())
			if progress_bar:
				progress_bar.value = blocked_count
			if progress_label:
				progress_label.text = "%d / 8" % blocked_count
			if blocked_count >= 8:
				_hide_tutorial_hand()
				_complete_tutorial_step("皇冠的周围全部被排除")
			else:
				coach_label.text = _runtime_text("继续把皇冠周围的格子点成 X，还剩 %d 个。" % [8 - blocked_count])
		"adjacent_row_col":
			var blocked_count := _tutorial_blocked_adjacent_row_col_count(_tutorial_target())
			if progress_bar:
				progress_bar.value = blocked_count
			if progress_label:
				progress_label.text = "%d / 12" % blocked_count
			if blocked_count >= 12:
				_hide_tutorial_hand()
				_complete_tutorial_step("皇冠周围和同行同列都已排除")
			elif _tutorial_blocked_adjacent_count(_tutorial_target()) >= 8:
				coach_label.text = "周围一圈已排除。现在继续排除同行同列剩下的格子。"
			else:
				coach_label.text = _runtime_text("先把皇冠周围一圈点成 X，还剩 %d 个。" % [8 - _tutorial_blocked_adjacent_count(_tutorial_target())])
		"tools":
			_show_toast("这一关请先学习提示按钮")


func _tutorial_unique_guides(piece: Vector2i) -> Dictionary:
	var guides := {}
	for cell in _row_cells(piece.y):
		if cell != piece:
			guides[cell] = "exclude"
	for cell in _col_cells(piece.x):
		if cell != piece:
			guides[cell] = "exclude"
	guides[piece] = "place"
	return guides


func _tutorial_color_cells(crown: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var region_id := int(current_level["regions"][crown.y][crown.x])
	for row in range(int(current_level["rows"])):
		for col in range(int(current_level["cols"])):
			var cell := Vector2i(col, row)
			if cell != crown and int(current_level["regions"][row][col]) == region_id:
				cells.append(cell)
	return cells


func _tutorial_row_col_cells(crown: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for col in range(int(current_level["cols"])):
		var row_cell := Vector2i(col, crown.y)
		if row_cell != crown:
			cells.append(row_cell)
	for row in range(int(current_level["rows"])):
		var col_cell := Vector2i(crown.x, row)
		if col_cell != crown:
			cells.append(col_cell)
	return cells


func _tutorial_adjacent_row_col_cells(crown: Vector2i) -> Array[Vector2i]:
	var cells := _tutorial_adjacent_cells(crown)
	for cell in _tutorial_row_col_cells(crown):
		if not cells.has(cell):
			cells.append(cell)
	return cells


func _tutorial_adjacent_cells(crown: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var clockwise_offsets := [
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0),
		Vector2i(-1, -1)
	]
	for offset in clockwise_offsets:
		var cell: Vector2i = crown + offset
		if cell.x >= 0 and cell.x < int(current_level["cols"]) and cell.y >= 0 and cell.y < int(current_level["rows"]):
			cells.append(cell)
	return cells


func _tutorial_blocked_adjacent_count(crown: Vector2i) -> int:
	var count := 0
	for cell in _tutorial_adjacent_cells(crown):
		if cell_states[cell.y][cell.x] == "blocked":
			count += 1
	return count


func _tutorial_blocked_color_count(crown: Vector2i) -> int:
	var count := 0
	for cell in _tutorial_color_cells(crown):
		if cell_states[cell.y][cell.x] == "blocked":
			count += 1
	return count


func _tutorial_blocked_row_col_count(crown: Vector2i) -> int:
	var count := 0
	for cell in _tutorial_row_col_cells(crown):
		if cell_states[cell.y][cell.x] == "blocked":
			count += 1
	return count


func _tutorial_blocked_adjacent_row_col_count(crown: Vector2i) -> int:
	var count := 0
	for cell in _tutorial_adjacent_row_col_cells(crown):
		if cell_states[cell.y][cell.x] == "blocked":
			count += 1
	return count


func _next_tutorial_color_cell() -> Vector2i:
	var crown := _tutorial_target()
	for cell in _tutorial_color_cells(crown):
		if cell_states[cell.y][cell.x] != "blocked":
			return cell
	return Vector2i(-1, -1)


func _next_tutorial_row_col_cell() -> Vector2i:
	var crown := _tutorial_target()
	for cell in _tutorial_row_col_cells(crown):
		if cell_states[cell.y][cell.x] != "blocked":
			return cell
	return Vector2i(-1, -1)


func _next_tutorial_adjacent_row_col_cell() -> Vector2i:
	var crown := _tutorial_target()
	for cell in _tutorial_adjacent_row_col_cells(crown):
		if cell_states[cell.y][cell.x] != "blocked":
			return cell
	return Vector2i(-1, -1)


func _next_tutorial_adjacent_cell() -> Vector2i:
	var crown := _tutorial_target()
	for cell in _tutorial_adjacent_cells(crown):
		if cell_states[cell.y][cell.x] != "blocked":
			return cell
	return Vector2i(-1, -1)


func _show_tutorial_hand_for_cell(cell: Vector2i) -> void:
	if not in_tutorial or cell.x < 0 or cell.y < 0 or not board or not tutorial_hand_label:
		return
	board.set_tutorial_focus(cell, true)
	tutorial_hand_cell = cell
	tutorial_hand_control = null
	_position_tutorial_hand()
	tutorial_hand_label.show()
	tutorial_hand_label.modulate.a = 1.0
	tutorial_hand_label.scale = Vector2.ONE
	if tutorial_hand_tween and tutorial_hand_tween.is_valid():
		tutorial_hand_tween.kill()
	tutorial_hand_token += 1
	_loop_tutorial_hand_demo(cell, tutorial_hand_token)


func _show_tutorial_hand_for_control(control: Control) -> void:
	if not in_tutorial or not control or not tutorial_hand_label:
		return
	if board:
		board.set_tutorial_focus(Vector2i(-1, -1), false)
	tutorial_hand_cell = Vector2i(-1, -1)
	tutorial_hand_control = control
	_position_tutorial_hand()
	tutorial_hand_label.show()
	tutorial_hand_label.modulate.a = 1.0
	tutorial_hand_label.scale = Vector2.ONE
	if tutorial_hand_tween and tutorial_hand_tween.is_valid():
		tutorial_hand_tween.kill()
	tutorial_hand_token += 1
	_loop_tutorial_control_demo(control, tutorial_hand_token)


func _focus_tutorial_cell(cell: Vector2i, delay: float = 0.36) -> void:
	if not in_tutorial or cell.x < 0 or cell.y < 0 or not board:
		return
	_hide_tutorial_hand()
	tutorial_focus_token += 1
	var token := tutorial_focus_token
	board.set_tutorial_focus(cell, true)
	if _tutorial_kind() == "single_map" and tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
		board.play_guide_feedback_for_cells(_tutorial_row_col_cells(tutorial_active_crown))
	else:
		board.play_guide_feedback(cell.y, cell.x)
	await get_tree().create_timer(delay).timeout
	if token == tutorial_focus_token and in_tutorial and not is_completed:
		_show_tutorial_hand_for_cell(cell)


func _focus_tutorial_control(control: Control, delay: float = 0.24) -> void:
	if not in_tutorial or not control:
		return
	_hide_tutorial_hand()
	tutorial_focus_token += 1
	var token := tutorial_focus_token
	await get_tree().create_timer(delay).timeout
	if token == tutorial_focus_token and in_tutorial and not is_completed and control.visible:
		_show_tutorial_hand_for_control(control)


func _position_tutorial_hand() -> void:
	if not board or not tutorial_hand_label:
		return
	if tutorial_hand_control and tutorial_hand_control.is_inside_tree():
		var rect := tutorial_hand_control.get_global_rect()
		var target_point := rect.position + Vector2(rect.size.x * 0.76, rect.size.y * 0.55)
		tutorial_hand_label.global_position = target_point - Vector2(46, 18)
		return
	if tutorial_hand_cell.x < 0 or tutorial_hand_cell.y < 0:
		return
	tutorial_hand_label.global_position = _tutorial_hand_position_for_cell(tutorial_hand_cell)


func _tutorial_hand_position_for_cell(cell: Vector2i) -> Vector2:
	var geometry: Dictionary = board._board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cell_size"]
	var target_point: Vector2 = board.global_position + board_rect.position + Vector2(cell.x + 0.75, cell.y + 0.75) * cell_size
	return target_point - Vector2(48, 22)


func _tutorial_hand_anchor_position() -> Vector2:
	if tutorial_hand_control and tutorial_hand_control.is_inside_tree():
		var rect := tutorial_hand_control.get_global_rect()
		var target_point := rect.position + Vector2(rect.size.x * 0.76, rect.size.y * 0.55)
		return target_point - Vector2(46, 18)
	if tutorial_hand_cell.x >= 0 and tutorial_hand_cell.y >= 0:
		return _tutorial_hand_position_for_cell(tutorial_hand_cell)
	return tutorial_hand_label.global_position


func _loop_tutorial_hand_demo(cell: Vector2i, token: int) -> void:
	while token == tutorial_hand_token and tutorial_hand_label and tutorial_hand_label.visible:
		if _tutorial_kind() == "single_map" and tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
			board.play_guide_feedback_for_cells(_tutorial_row_col_cells(tutorial_active_crown))
		else:
			board.play_guide_feedback(cell.y, cell.x)
		var action := _tutorial_hand_cell_action()
		if action == "slide":
			await _animate_tutorial_hand_slide(cell, token)
		elif action == "double":
			await _animate_tutorial_hand_taps(2, token)
		else:
			await _animate_tutorial_hand_taps(1, token)
		await get_tree().create_timer(1.5).timeout


func _loop_tutorial_control_demo(control: Control, token: int) -> void:
	while token == tutorial_hand_token and tutorial_hand_label and tutorial_hand_label.visible and control and control.visible:
		_position_tutorial_hand()
		await _animate_tutorial_hand_taps(1, token)
		await get_tree().create_timer(1.5).timeout


func _tutorial_hand_cell_action() -> String:
	if _tutorial_kind() == "single_map":
		if tutorial_interaction_stage == TUTORIAL_PHASE_PLACE or tutorial_interaction_stage == TUTORIAL_PHASE_HINT_PLACE:
			return "double"
		if tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
			return "single"
		if tutorial_interaction_stage == TUTORIAL_PHASE_ADJACENT:
			return "slide"
	return "single"


func _animate_tutorial_hand_taps(count: int, token: int) -> void:
	for index in range(count):
		if token != tutorial_hand_token or not tutorial_hand_label or not tutorial_hand_label.visible:
			return
		var base_position := _tutorial_hand_anchor_position()
		tutorial_hand_label.global_position = base_position
		tutorial_hand_label.scale = Vector2.ONE
		tutorial_hand_tween = create_tween()
		tutorial_hand_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tutorial_hand_tween.parallel().tween_property(tutorial_hand_label, "scale", Vector2(0.84, 0.84), 0.13)
		tutorial_hand_tween.parallel().tween_property(tutorial_hand_label, "global_position", base_position + Vector2(0, 8), 0.13)
		tutorial_hand_tween.tween_property(tutorial_hand_label, "scale", Vector2(1.10, 1.10), 0.16)
		tutorial_hand_tween.parallel().tween_property(tutorial_hand_label, "global_position", base_position, 0.16)
		tutorial_hand_tween.tween_property(tutorial_hand_label, "scale", Vector2.ONE, 0.12)
		await tutorial_hand_tween.finished
		if token == tutorial_hand_token and tutorial_hand_label and tutorial_hand_label.visible:
			tutorial_hand_label.global_position = base_position
			tutorial_hand_label.scale = Vector2.ONE
		if index < count - 1:
			await get_tree().create_timer(0.20).timeout


func _animate_tutorial_hand_slide(cell: Vector2i, token: int) -> void:
	var end_cell := _tutorial_slide_end_cell(cell)
	var start_position := _tutorial_hand_position_for_cell(cell)
	var end_position := _tutorial_hand_position_for_cell(end_cell)
	tutorial_hand_label.global_position = start_position
	tutorial_hand_label.scale = Vector2.ONE
	tutorial_hand_tween = create_tween()
	tutorial_hand_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tutorial_hand_tween.tween_property(tutorial_hand_label, "scale", Vector2(0.94, 0.94), 0.18)
	tutorial_hand_tween.tween_property(tutorial_hand_label, "global_position", end_position, 0.92)
	tutorial_hand_tween.parallel().tween_property(tutorial_hand_label, "scale", Vector2(1.07, 1.07), 0.92)
	tutorial_hand_tween.tween_property(tutorial_hand_label, "scale", Vector2.ONE, 0.18)
	await tutorial_hand_tween.finished
	if token == tutorial_hand_token and tutorial_hand_label and tutorial_hand_label.visible:
		tutorial_hand_label.global_position = start_position


func _tutorial_slide_end_cell(start_cell: Vector2i) -> Vector2i:
	for cell in _tutorial_single_map_valid_exclusion_cells():
		if cell != start_cell and cell_states[cell.y][cell.x] == "empty":
			return cell
	var rows := int(current_level.get("rows", 0))
	var cols := int(current_level.get("cols", 0))
	var fallback := Vector2i(clampi(start_cell.x + 1, 0, cols - 1), clampi(start_cell.y + 1, 0, rows - 1))
	return fallback


func _hide_tutorial_hand() -> void:
	tutorial_focus_token += 1
	tutorial_hand_token += 1
	tutorial_hand_cell = Vector2i(-1, -1)
	tutorial_hand_control = null
	if tutorial_hand_tween and tutorial_hand_tween.is_valid():
		tutorial_hand_tween.kill()
	if tutorial_hand_label:
		tutorial_hand_label.hide()
		tutorial_hand_label.scale = Vector2.ONE
	if board:
		board.set_tutorial_focus(Vector2i(-1, -1), false)


func _tutorial_undo_demo_cell() -> Vector2i:
	return Vector2i(1, 1)


func _tutorial_clear_demo_cells() -> Array[Vector2i]:
	return [Vector2i(0, 0), Vector2i(2, 1), Vector2i(3, 3)]


func _set_tutorial_button_demo_state(stage: int) -> void:
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	if stage == 0:
		var undo_cell := _tutorial_undo_demo_cell()
		cell_states[undo_cell.y][undo_cell.x] = "blocked"
	elif stage == 1:
		var cells := _tutorial_clear_demo_cells()
		cell_states[cells[0].y][cells[0].x] = "blocked"
		cell_states[cells[1].y][cells[1].x] = "piece"
		cell_states[cells[2].y][cells[2].x] = "blocked"


func _tutorial_button_guides() -> Dictionary:
	var guides := {}
	if tutorial_button_stage == 0:
		guides[_tutorial_undo_demo_cell()] = "exclude"
	elif tutorial_button_stage == 1:
		for cell in _tutorial_clear_demo_cells():
			guides[cell] = "place" if cell_states[cell.y][cell.x] == "piece" else "exclude"
	else:
		guides[_tutorial_target()] = "candidate"
	return guides


func _refresh_tutorial_button_demo() -> void:
	board.set_states(cell_states)
	board.set_guides(_tutorial_button_guides())
	if progress_bar:
		progress_bar.value = tutorial_button_stage
	if progress_label:
		progress_label.text = "%d / 4" % tutorial_button_stage


func _use_tutorial_undo() -> void:
	if _tutorial_kind() == "single_map":
		if move_history.is_empty():
			_show_toast("暂无可撤销的操作")
			return
		var snapshot: Dictionary = move_history.pop_back()
		cell_states = snapshot["states"]
		tutorial_interaction_stage = int(snapshot["phase"])
		tutorial_solution_index = int(snapshot["solutionIndex"])
		tutorial_active_crown = snapshot["activeCrown"]
		tutorial_hint_target = snapshot["hintTarget"]
		tutorial_hint_button_taught = bool(snapshot.get("hintButtonTaught", tutorial_hint_button_taught))
		tutorial_crown_find_taught = bool(snapshot.get("crownFindTaught", tutorial_crown_find_taught))
		board.set_states(cell_states)
		audio_controller.play_erase()
		_update_tutorial_progress()
		_set_tutorial_guides()
		_update_tutorial_action_bar()
		_focus_current_single_map_tutorial_target(0.12)
		_save_game()
		return
	if _tutorial_kind() != "tools":
		_show_toast("教程关卡中请按高亮格操作")
		return
	if tutorial_button_stage != 0:
		_show_toast("先按当前高亮的按钮")
		return
	tutorial_button_stage = 1
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	_refresh_tutorial_button_demo()
	board.play_guide_feedback(_tutorial_undo_demo_cell().y, _tutorial_undo_demo_cell().x)
	_show_toast("撤销：X 已恢复为空白。")
	await get_tree().create_timer(0.45).timeout
	_set_tutorial_button_demo_state(1)
	_refresh_tutorial_button_demo()
	_update_tutorial_action_bar()
	_focus_tutorial_control(hint_button, 0.18)


func _use_tutorial_clear() -> void:
	if _tutorial_kind() == "single_map":
		_show_toast("新手教程里请跟随高亮完成操作")
		return
	if _tutorial_kind() != "tools":
		_start_tutorial_step(tutorial_step_index)
		_show_toast("已重来本步教程")
		return
	if tutorial_button_stage != 1:
		_show_toast("先按当前高亮的按钮")
		return
	tutorial_button_stage = 2
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	audio_controller.play_clear()
	_refresh_tutorial_button_demo()
	_show_toast("清除：所有尝试标记已清空。")
	_update_tutorial_action_bar()
	_focus_tutorial_control(hint_button, 0.18)


func _use_tutorial_crown_find() -> void:
	if _tutorial_kind() != "single_map":
		_show_toast("请跟随当前教程步骤操作")
		return
	if tutorial_interaction_stage != TUTORIAL_PHASE_CROWN_FIND:
		_show_toast("皇冠直找会在稍后的教程步骤中解锁")
		_focus_current_single_map_tutorial_target(0.12)
		return
	var target := _next_tutorial_solution_cell()
	if target.x < 0:
		_show_toast("当前已经没有可直接找到的皇冠")
		return
	_push_tutorial_history()
	tutorial_crown_find_taught = true
	tutorial_active_crown = target
	cell_states[target.y][target.x] = "hint"
	audio_controller.play_correct()
	tutorial_solution_index += 1
	board.set_states(cell_states)
	board.play_cell_feedback(target.y, target.x)
	_update_tutorial_progress()
	_show_toast("皇冠直找：已直接找到并锁定一个皇冠")
	if tutorial_solution_index >= _tutorial_solution_cells().size():
		tutorial_interaction_stage = TUTORIAL_PHASE_DONE
		board.set_guides({})
		_hide_tutorial_hand()
		_show_tutorial_challenge_ready()
		_save_game()
		return
	tutorial_interaction_stage = TUTORIAL_PHASE_ADJACENT
	if _next_tutorial_single_map_exclusion_cell().x >= 0:
		coach_label.text = "皇冠直找会直接找到并锁定皇冠。继续把皇冠周围的格子标记为 X。"
		_set_tutorial_guides()
		_update_tutorial_action_bar()
		_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), 0.18)
	else:
		tutorial_interaction_stage = TUTORIAL_PHASE_ROW_COL
		if _next_tutorial_single_map_exclusion_cell().x >= 0:
			coach_label.text = "皇冠直找已直接找到并锁定皇冠，周围位置已经排除。继续排除同行同列。"
			_set_tutorial_guides()
			_update_tutorial_action_bar()
			_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), 0.18)
		else:
			_advance_tutorial_single_map_after_exclusions()
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	_save_game()


func _use_tutorial_hint() -> void:
	if _tutorial_kind() == "single_map":
		if tutorial_interaction_stage != TUTORIAL_PHASE_HINT:
			_show_toast("现在先完成高亮格操作，之后再使用提示。")
			_focus_current_single_map_tutorial_target(0.12)
			return
		tutorial_hint_button_taught = true
		audio_controller.play_hint()
		_show_direct_tutorial_crown_clue("每个颜色区域都要找到一个皇冠。现在这个区域只剩一个可选格，双击找到它。")
		_save_game()
		return
	if _tutorial_kind() != "tools":
		_show_toast("教程里会演示提示的观察方式")
		return
	if tutorial_button_stage != 2:
		_show_toast("先学习撤销和清除，再使用提示")
		return
	var target := _tutorial_target()
	audio_controller.play_hint()
	cell_states = _blank_states(int(current_level["rows"]), int(current_level["cols"]))
	board.set_states(cell_states)
	board.set_guides({
		target: "place"
	})
	board.play_guide_feedback(target.y, target.x)
	_focus_tutorial_cell(target, 0.18)
	coach_label.text = "每个颜色区域都要找到一个皇冠。现在这个区域只剩一个可选格，双击找到它。"
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	tutorial_button_stage = 3
	_update_tutorial_action_bar()
	if progress_bar:
		progress_bar.value = 3
	if progress_label:
		progress_label.text = "3 / 4"
	_save_game()


func _focus_current_single_map_tutorial_target(delay: float = 0.18) -> void:
	if tutorial_interaction_stage == TUTORIAL_PHASE_PLACE or tutorial_interaction_stage == TUTORIAL_PHASE_HINT_PLACE:
		_focus_tutorial_cell(_current_tutorial_place_target(), delay)
	elif tutorial_interaction_stage == TUTORIAL_PHASE_ADJACENT or tutorial_interaction_stage == TUTORIAL_PHASE_ROW_COL:
		_focus_tutorial_cell(_next_tutorial_single_map_exclusion_cell(), delay)
	elif tutorial_interaction_stage == TUTORIAL_PHASE_HINT:
		_focus_tutorial_control(hint_button, delay)
	elif tutorial_interaction_stage == TUTORIAL_PHASE_CROWN_FIND:
		_focus_tutorial_control(crown_find_button, delay)


func _push_tutorial_history() -> void:
	move_history.append({
		"states": cell_states.duplicate(true),
		"phase": tutorial_interaction_stage,
		"solutionIndex": tutorial_solution_index,
		"activeCrown": tutorial_active_crown,
		"hintTarget": tutorial_hint_target,
		"hintButtonTaught": tutorial_hint_button_taught,
		"crownFindTaught": tutorial_crown_find_taught
	})
	if move_history.size() > 100:
		move_history.pop_front()


func _show_tutorial_challenge_ready() -> void:
	is_completed = true
	result_overlay_mode = "tutorial"
	coach_label.text = "已经了解全部规则，开始真正的挑战吧！"
	coach_label.add_theme_color_override("font_color", Color("#31506D"))
	coach_label.add_theme_font_size_override("font_size", COACH_TUTORIAL_SIZE)
	board.play_victory()
	if undo_button:
		undo_button.hide()
	if clear_button:
		clear_button.hide()
	if hint_button:
		hint_button.hide()
	if crown_find_button:
		crown_find_button.hide()
	completion_title.text = "已经了解全部规则"
	reward_label.text = "开始真正的挑战吧！"
	if result_icon_label:
		result_icon_label.hide()
	if result_piece_icon:
		result_piece_icon.texture = LION_KING_VICTORY_ICON
		result_piece_icon.show()
	if result_reward_label:
		result_reward_label.text = "新手教程完成"
		result_reward_label.show()
	if result_tip_label:
		result_tip_label.text = "返回进入教程前的关卡现场" if _formal_progress_snapshot_is_valid(formal_progress_snapshot) else "进入第 1 关，开始真正的挑战"
	completion_next_button.text = "返回关卡" if _formal_progress_snapshot_is_valid(formal_progress_snapshot) else "开始挑战"
	if completion_replay_button:
		completion_replay_button.hide()
	completion_overlay.show()
	completion_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(completion_overlay, "modulate:a", 1.0, 0.2)
	call_deferred("_play_result_lion_animation")


func _complete_tutorial_step(message: String) -> void:
	is_completed = true
	board.play_victory()
	audio_controller.play_victory()
	_save_game()
	if _tutorial_kind() == "adjacent":
		_show_tutorial_center_popup("皇冠的周围全部被排除")
	else:
		_show_toast("%s 完成：%s" % [str(current_level["title"]), message])
	await get_tree().create_timer(2.0).timeout
	if in_tutorial and is_completed:
		_next_tutorial_step()


func _next_tutorial_step() -> void:
	if tutorial_step_index >= TUTORIAL_LEVELS.size() - 1:
		_finish_tutorial(false)
	else:
		_start_tutorial_step(tutorial_step_index + 1)


func _request_skip_tutorial() -> void:
	if in_tutorial:
		var destination := "返回进入教程前的关卡现场。" if _formal_progress_snapshot_is_valid(formal_progress_snapshot) else "直接进入第 1 关。"
		dialog_controller.show_dialog(
			"tutorial_skip",
			"跳过新手教程？",
			"跳过后会%s之后不再自动显示新手教程。" % destination,
			"",
			[
				{"id": "continue", "text": "继续教程", "variant": "secondary"},
				{"id": "skip", "text": "确认跳过", "variant": "primary"}
			],
			UITokensScript.DIALOG_STANDARD_WIDTH,
			false
		)


func _on_tutorial_button_pressed() -> void:
	if in_tutorial:
		_request_skip_tutorial()
	else:
		_start_tutorial_step(0)


func _finish_tutorial(skipped: bool) -> void:
	tutorial_completed = true
	tutorial_started = false
	in_tutorial = false
	_hide_tutorial_hand()
	tutorial_step_index = 0
	tutorial_button_stage = 0
	var restored_formal_progress := _restore_formal_progress_snapshot()
	if not restored_formal_progress:
		player_level_number = 1
		active_schedule = LevelDirectorScript.schedule_for_display_level(levels, player_level_number, director_progress)
		_load_level(int(active_schedule.get("levelIndex", 0)), false, active_schedule)
	_show_game()
	_save_game()
	if restored_formal_progress:
		_show_toast("已跳过教程，返回之前的关卡" if skipped else "新手教程完成，返回之前的关卡")
	else:
		_show_toast("已跳过教程，进入第 1 关" if skipped else "新手教程完成，进入第 1 关")


func _complete_level() -> void:
	if is_completed or is_failed:
		return
	is_completed = true
	if home_composite_entry_active:
		board.play_victory()
		audio_controller.play_victory()
		_save_game()
		await get_tree().create_timer(0.55).timeout
		_prepare_success_result_page()
		completion_overlay.show()
		completion_overlay.modulate.a = 0.0
		var entry_tween := create_tween()
		entry_tween.tween_property(completion_overlay, "modulate:a", 1.0, 0.2)
		return
	var level_id := int(current_level["levelId"])
	if not completed_levels.has(level_id):
		completed_levels.append(level_id)
	var mistake_count := maxi(0, current_heart_limit - heart_count)
	var reward := CoinEconomyScript.completion_reward(int(current_level.get("rows", 5)), active_king_positions.size(), mistake_count)
	coin_count += reward
	CoinEconomyScript.record_completion(
		economy_progress,
		level_id,
		int(current_level.get("rows", 5)),
		active_king_positions.size(),
		mistake_count,
		reward,
		run_coin_exchange_count
	)
	_record_level_result()
	_update_coin_label()
	_update_home()
	board.play_victory()
	audio_controller.play_victory()
	_save_game()
	await get_tree().create_timer(0.55).timeout
	_prepare_success_result_page(reward)
	completion_overlay.show()
	completion_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(completion_overlay, "modulate:a", 1.0, 0.2)


func _prepare_success_result_page(reward: int = 0) -> void:
	result_overlay_mode = "success"
	completion_title.text = "太棒了！"
	reward_label.text = _t("拼块挑战 · 第 %d 局完成", [maxi(1, home_composite_round)]) if home_composite_entry_active else _t("第 %d 关 已完成", [player_level_number])
	if result_icon_label:
		result_icon_label.hide()
	if result_piece_icon:
		result_piece_icon.texture = LION_KING_VICTORY_ICON
		result_piece_icon.show()
	if result_reward_label:
		result_reward_label.hide()
	if result_tip_label:
		result_tip_label.text = "主线进度保持不变" if home_composite_entry_active else ("金币 +%d" % reward if reward > 0 else "本关已完成，继续挑战")
	if completion_next_button:
		completion_next_button.text = _t("下一局") if home_composite_entry_active else "下一关"
	if completion_replay_button:
		completion_replay_button.text = "主菜单"
		completion_replay_button.show()
	call_deferred("_play_result_lion_animation")


func _prepare_failure_result_page() -> void:
	result_overlay_mode = "failure"
	_stop_result_lion_animation()
	completion_title.text = "挑战失败"
	reward_label.text = _t("拼块挑战 · 第 %d 局未完成", [maxi(1, home_composite_round)]) if home_composite_entry_active else _t("第 %d 关 未完成", [player_level_number])
	if result_icon_label:
		result_icon_label.text = "♥"
		result_icon_label.add_theme_color_override("font_color", Color("#F25D72"))
		result_icon_label.add_theme_color_override("font_shadow_color", Color("#B92E4A"))
		result_icon_label.show()
	if result_piece_icon:
		result_piece_icon.hide()
	if result_reward_label:
		result_reward_label.text = "红心已用完"
		result_reward_label.show()
	if result_tip_label:
		result_tip_label.text = "可以重新挑战，或返回首页继续主线" if home_composite_entry_active else "复活会保留当前棋盘，并恢复 1 颗红心"
	if completion_next_button:
		completion_next_button.text = "重新挑战" if home_composite_entry_active else _t("金币复活  -%d", [_current_tool_price(CoinEconomyScript.TOOL_REVIVE)])
	if completion_replay_button:
		completion_replay_button.text = "主菜单" if home_composite_entry_active else "重新挑战"
		completion_replay_button.show()


func _play_result_lion_animation() -> void:
	if result_overlay_mode != "success" and result_overlay_mode != "tutorial":
		return
	if not completion_overlay.visible or not result_piece_icon or not result_piece_icon.visible:
		return
	_stop_result_lion_animation()
	result_piece_icon.scale = Vector2.ONE
	result_piece_icon.rotation = 0.0
	result_piece_icon.modulate.a = 0.0
	result_lion_tween = create_tween()
	result_lion_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	result_lion_tween.tween_property(result_piece_icon, "modulate:a", 1.0, 0.20)
	await result_lion_tween.finished
	if not completion_overlay.visible or result_overlay_mode == "failure":
		return
	_start_random_result_lion_animation()


func _start_random_result_lion_animation() -> void:
	var animation_index := randi_range(0, 2)
	if animation_index == 0:
		_start_result_lion_frame_sequence(
			"wave",
			[
				LION_KING_VICTORY_IN_ICON,
				LION_KING_VICTORY_WAVE_IN_MID_ICON,
				LION_KING_VICTORY_ICON,
				LION_KING_VICTORY_WAVE_OUT_MID_ICON,
				LION_KING_VICTORY_OUT_ICON,
				LION_KING_VICTORY_WAVE_OUT_MID_ICON,
				LION_KING_VICTORY_ICON,
				LION_KING_VICTORY_WAVE_IN_MID_ICON
			],
			[0.18, 0.08, 0.07, 0.08, 0.19, 0.08, 0.09, 0.08],
			0.34
		)
	elif animation_index == 1:
		_start_result_lion_frame_sequence(
			"tongue",
			[
				LION_KING_VICTORY_ICON,
				LION_KING_VICTORY_TONGUE_PEEK_ICON,
				LION_KING_VICTORY_ICON,
				LION_KING_VICTORY_TONGUE_OUT_ICON,
				LION_KING_VICTORY_ICON,
				LION_KING_VICTORY_TONGUE_PEEK_ICON
			],
			[0.34, 0.10, 0.09, 0.38, 0.12, 0.10],
			0.52
		)
	else:
		_start_result_lion_frame_sequence(
			"funny",
			[
				LION_KING_VICTORY_ICON,
				LION_KING_VICTORY_WINK_ICON,
				LION_KING_VICTORY_FUNNY_ICON,
				LION_KING_VICTORY_WINK_ICON,
				LION_KING_VICTORY_ICON
			],
			[0.28, 0.12, 0.46, 0.13, 0.18],
			0.60
		)


func _start_result_lion_frame_sequence(animation_name: String, frames: Array, durations: Array, pause: float) -> void:
	result_lion_animation_name = animation_name
	result_lion_wave_tween = create_tween().set_loops()
	for frame_index in range(frames.size()):
		result_lion_wave_tween.tween_callback(_set_result_lion_frame.bind(frames[frame_index]))
		result_lion_wave_tween.tween_interval(float(durations[frame_index]))
	result_lion_wave_tween.tween_interval(pause)


func _set_result_lion_frame(frame: Texture2D) -> void:
	if result_piece_icon:
		result_piece_icon.texture = frame


func _stop_result_lion_animation() -> void:
	if result_lion_tween and result_lion_tween.is_valid():
		result_lion_tween.kill()
	result_lion_tween = null
	if result_lion_wave_tween and result_lion_wave_tween.is_valid():
		result_lion_wave_tween.kill()
	result_lion_wave_tween = null
	result_lion_animation_name = ""
	if result_piece_icon:
		result_piece_icon.texture = LION_KING_VICTORY_ICON
		result_piece_icon.scale = Vector2.ONE
		result_piece_icon.rotation = 0.0
		result_piece_icon.modulate = Color.WHITE


func _record_level_result() -> void:
	_sync_director_completed_levels()
	var completed_unix := int(Time.get_unix_time_from_system())
	var elapsed := maxf(1.0, float(completed_unix - run_started_unix))
	LevelDirectorScript.record_completion(director_progress, current_level, active_schedule, elapsed, run_move_count, run_hint_count, _today_string(), completed_unix)
	_sync_director_completed_levels()


func _next_level() -> void:
	if in_tutorial:
		_next_tutorial_step()
		return
	player_level_number += 1
	var next_schedule := LevelDirectorScript.schedule_for_display_level(levels, player_level_number, director_progress)
	var next_index := int(next_schedule.get("levelIndex", 0))
	_load_level(next_index, false, next_schedule)
	LevelDirectorScript.record_next_level_opened(director_progress)
	_save_game()
	if bool(next_schedule.get("isMilestoneChallenge", false)):
		_show_toast("难度挑战：本关根据最近表现安排")


func _completion_primary_pressed() -> void:
	if home_composite_entry_active:
		completion_overlay.hide()
		if result_overlay_mode == "success":
			_start_next_home_composite_round()
		else:
			_replay_level()
			_show_game()
		return
	match result_overlay_mode:
		"tutorial":
			_next_level()
		"failure":
			_revive_current_level()
		_:
			_next_level()


func _completion_secondary_pressed() -> void:
	if home_composite_entry_active:
		completion_overlay.hide()
		_show_home()
		return
	if result_overlay_mode == "failure":
		completion_overlay.hide()
		_replay_level()
	elif result_overlay_mode == "success":
		completion_overlay.hide()
		_show_home()
		_save_game()
	else:
		_replay_level()


func _revive_current_level() -> void:
	if not is_failed:
		return
	if not _spend_coins_for_tool(CoinEconomyScript.TOOL_REVIVE):
		return
	is_failed = false
	heart_count = 1
	completion_overlay.hide()
	if hint_button:
		hint_button.disabled = false
	_update_heart_label()
	_validate_and_update(false)
	_update_hint_button()
	_update_crown_find_button()
	_save_game()
	_show_toast("复活成功：保留棋盘并恢复 1 颗红心")


func _replay_level() -> void:
	if in_tutorial:
		_start_tutorial_step(tutorial_step_index)
		return
	_load_level(current_level_index, false, active_schedule)


func _on_coin_plus() -> void:
	coin_count += 10
	_update_coin_label()
	_update_home()
	_save_game()
	_show_toast("演示奖励：金币 +10")


func _on_settings() -> void:
	if not dialog_controller or not language_picker:
		return
	_refresh_language_picker()
	dialog_controller.show_dialog(
		"settings",
		"语言设置",
		"",
		"settings",
		[
			{"id": "cancel", "text": "取消", "variant": "secondary"},
			{"id": "apply", "text": "应用", "variant": "primary"}
		],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		true
	)


func _on_help() -> void:
	if not dialog_controller:
		return
	if help_tabs:
		help_tabs.current_tab = 1 if _is_assembly_phase() else 0
	dialog_controller.show_dialog(
		"help",
		"玩法帮助" if _is_assembly_phase() else "消除规则",
		"",
		"help_rules",
		[{"id": "close", "text": "知道了", "variant": "primary"}],
		UITokensScript.DIALOG_RICH_WIDTH,
		true
	)


func _replay_composite_intro_from_help() -> void:
	if not _is_assembly_phase() or not assembly_view:
		_show_toast("进入拼块阶段后可以重播演示")
		return
	dialog_controller.hide_dialog(true)
	composite_intro_marks_seen = false
	composite_intro_running = true
	assembly_view.play_intro()


func _show_tutorial_resume_dialog() -> void:
	if not dialog_controller:
		return
	dialog_controller.show_dialog(
		"tutorial_resume",
		"继续新手教程？",
		"检测到你还没有完成新手教程。",
		"",
		[
			{"id": "restart", "text": "重新开始", "variant": "secondary"},
			{"id": "continue", "text": "继续教程", "variant": "primary"}
		],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		false
	)


func _on_dialog_action_selected(dialog_id: String, action_id: String) -> void:
	match dialog_id:
		"level_select":
			if action_id == "enter":
				_confirm_level_select()
		"tutorial_skip":
			if action_id == "skip":
				_finish_tutorial(true)
		"tutorial_resume":
			if action_id == "continue":
				_start_tutorial_step(tutorial_step_index)
			elif action_id == "restart":
				_start_tutorial_step(0)
		"coin_shortage":
			if action_id == "rewarded":
				_show_toast("激励广告入口占位：SDK 回调成功后发放 %d 金币" % pending_rewarded_coin_grant)
			elif action_id == "purchase":
				_show_toast("金币购买入口占位：接入支付后开放")
		"settings":
			if action_id == "apply":
				_apply_selected_language()


func _on_dialog_cancelled(dialog_id: String) -> void:
	if dialog_id == "tutorial_resume":
		_start_tutorial_step(0)


func _refresh_language_picker() -> void:
	if not language_picker or not localization:
		return
	language_picker.clear()
	for option in localization.language_options():
		var option_index := language_picker.item_count
		language_picker.add_item(str(option["name"]))
		language_picker.set_item_metadata(option_index, str(option["code"]))
	language_picker.select(localization.locale_index(selected_language))


func _apply_selected_language() -> void:
	if not language_picker or language_picker.selected < 0:
		return
	var locale := str(language_picker.get_item_metadata(language_picker.selected))
	localization.set_locale(locale)
	selected_language = localization.current_locale
	_save_game()


func _on_locale_changed(locale: String) -> void:
	selected_language = locale
	_apply_layout_direction()
	_refresh_localized_ui()


func _apply_layout_direction() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if localization and localization.is_rtl() else Control.LAYOUT_DIRECTION_LTR


func _refresh_localized_ui() -> void:
	_update_home()
	_update_hint_button()
	_update_crown_find_button()
	_refresh_level_select_picker()
	if in_tutorial:
		level_label.text = _t("新手教程")
		_update_tutorial_action_bar()
	elif not current_level.is_empty():
		level_label.text = _display_level_title()
		coach_label.text = _level_coach_text()
	if completion_overlay and completion_overlay.visible:
		if result_overlay_mode == "success":
			_prepare_success_result_page()
		elif result_overlay_mode == "failure":
			_prepare_failure_result_page()


func _open_level_select() -> void:
	if in_tutorial:
		_show_toast("完成新手教程后即可选择关卡")
		return
	_refresh_level_select_picker()
	level_select_picker.select(current_level_index)
	dialog_controller.show_dialog(
		"level_select",
		"关卡选择",
		"",
		"level_select",
		[
			{"id": "cancel", "text": "取消", "variant": "secondary"},
			{"id": "enter", "text": "进入关卡", "variant": "primary"}
		],
		UITokensScript.DIALOG_STANDARD_WIDTH,
		true
	)


func _refresh_level_select_picker() -> void:
	if not level_select_picker:
		return
	level_select_picker.clear()
	for index in range(levels.size()):
		var level: Dictionary = levels[index]
		var completed_mark := "✓ " if completed_levels.has(int(level["levelId"])) else ""
		level_select_picker.add_item("%s%s" % [completed_mark, _t("关卡 %d · %s", [int(level["levelId"]), _t(str(level.get("difficulty", "normal")))])], index)
	if levels.size() > 0:
		level_select_picker.select(clampi(current_level_index, 0, levels.size() - 1))


func _confirm_level_select() -> void:
	var selected_index := level_select_picker.get_selected_id()
	if selected_index < 0:
		selected_index = level_select_picker.selected
	selected_index = clampi(selected_index, 0, levels.size() - 1)
	tutorial_completed = true
	tutorial_started = false
	tutorial_step_index = 0
	_load_level(selected_index)
	_show_game()
	_save_game()
	_show_toast(_t("已进入关卡 %d", [int(current_level["levelId"])]))


func _open_level_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/level_editor.tscn")


func _on_level_selected(index: int) -> void:
	if index == current_level_index:
		return
	active_schedule = _schedule_for_manual_level(index)
	_load_level(index, false, active_schedule)
	_show_game()
	_save_game()
	_show_toast("调试切换：levelId %d" % int(current_level["levelId"]))


func _is_solution_cell(row: int, col: int) -> bool:
	for coordinate in current_level.get("solution", []):
		if int(coordinate[0]) == row and int(coordinate[1]) == col:
			return true
	return false


func _push_history() -> void:
	move_history.append(cell_states.duplicate(true))
	if move_history.size() > 100:
		move_history.pop_front()


func _blank_states(rows: int, cols: int) -> Array:
	var states: Array = []
	for row in range(rows):
		var line: Array = []
		line.resize(cols)
		line.fill("empty")
		states.append(line)
	return states


func _states_match_size(states: Array, rows: int, cols: int) -> bool:
	if states.size() != rows:
		return false
	for row in states:
		if not row is Array or row.size() != cols:
			return false
	return true


func _today_string() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date["year"]), int(date["month"]), int(date["day"])]


func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	current_level_index = int(data.get("currentLevelIndex", 0))
	player_level_number = maxi(1, int(data.get("playerLevelNumber", current_level_index + 1)))
	coin_count = int(data.get("coinCount", 55))
	if int(data.get("saveVersion", 1)) >= 2:
		hint_count = maxi(0, int(data.get("hintCount", INITIAL_HINT_COUNT)))
	else:
		# Version 1 stored the number of hints used, not the remaining count.
		hint_count = INITIAL_HINT_COUNT
	crown_find_count = clampi(int(data.get("crownFindCount", INITIAL_CROWN_FIND_COUNT)), 0, INITIAL_CROWN_FIND_COUNT)
	completed_levels.assign(data.get("completedLevels", []))
	heart_count = maxi(0, int(data.get("heartCount", INITIAL_HEART_COUNT)))
	for index in range(completed_levels.size()):
		completed_levels[index] = int(completed_levels[index])
	resume_level_id = int(data.get("currentLevelId", -1))
	resume_states = data.get("cellStates", [])
	resume_completed = bool(data.get("isCompleted", false))
	resume_failed = bool(data.get("isFailed", false))
	var loaded_schedule = data.get("activeSchedule", {})
	active_schedule = loaded_schedule if loaded_schedule is Dictionary else {}
	var loaded_progress = data.get("directorProgress", {})
	director_progress = loaded_progress if loaded_progress is Dictionary else {}
	LevelDirectorScript.normalize_progress(director_progress)
	var loaded_economy = data.get("economyProgress", {})
	economy_progress = loaded_economy if loaded_economy is Dictionary else CoinEconomyScript.default_progress()
	CoinEconomyScript.normalize_progress(economy_progress)
	run_started_unix = int(data.get("runStartedUnix", 0))
	run_move_count = int(data.get("runMoveCount", 0))
	run_hint_count = int(data.get("runHintCount", 0))
	run_coin_exchange_count = maxi(0, int(data.get("runCoinExchangeCount", 0)))
	immediate_errors = bool(data.get("immediateErrors", true))
	selected_language = str(data.get("selectedLanguage", ""))
	tutorial_completed = bool(data.get("tutorialCompleted", false))
	tutorial_started = bool(data.get("tutorialStarted", false))
	tutorial_step_index = clampi(int(data.get("tutorialStepIndex", 0)), 0, TUTORIAL_LEVELS.size() - 1)
	var loaded_formal_snapshot = data.get("formalProgressSnapshot", {})
	formal_progress_snapshot = loaded_formal_snapshot.duplicate(true) if loaded_formal_snapshot is Dictionary else {}
	home_composite_entry_active = bool(data.get("homeCompositeEntryActive", false))
	home_composite_round = maxi(0, int(data.get("homeCompositeRound", 0)))
	var loaded_home_composite_snapshot = data.get("homeCompositeProgressSnapshot", {})
	home_composite_progress_snapshot = loaded_home_composite_snapshot.duplicate(true) if loaded_home_composite_snapshot is Dictionary else {}
	var loaded_composite_state = data.get("compositeState", {})
	resume_composite_state = loaded_composite_state.duplicate(true) if loaded_composite_state is Dictionary else {}
	composite_tutorial_seen = bool(data.get("compositeTutorialSeen", false))


func _capture_formal_progress_snapshot() -> bool:
	if in_tutorial or current_level.is_empty() or int(current_level.get("levelId", -1)) < 0:
		return false
	formal_progress_snapshot = {
		"currentLevelIndex": current_level_index,
		"currentLevelId": int(current_level["levelId"]),
		"playerLevelNumber": player_level_number,
		"activeSchedule": active_schedule.duplicate(true),
		"directorProgress": director_progress.duplicate(true),
		"economyProgress": economy_progress.duplicate(true),
		"completedLevels": completed_levels.duplicate(),
		"cellStates": cell_states.duplicate(true),
		"isCompleted": is_completed,
		"isFailed": is_failed,
		"coinCount": coin_count,
		"heartCount": heart_count,
		"hintCount": hint_count,
		"crownFindCount": crown_find_count,
		"runStartedUnix": run_started_unix,
		"runMoveCount": run_move_count,
		"runHintCount": run_hint_count,
		"runCoinExchangeCount": run_coin_exchange_count,
		"compositeState": _composite_save_state(),
		"compositeTutorialSeen": composite_tutorial_seen
	}
	return true


func _formal_progress_snapshot_is_valid(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var level_index := int(snapshot.get("currentLevelIndex", -1))
	if level_index < 0 or level_index >= levels.size():
		return false
	var level: Dictionary = levels[level_index]
	if int(snapshot.get("currentLevelId", -1)) != int(level.get("levelId", -2)):
		return false
	var states = snapshot.get("cellStates", [])
	if not states is Array:
		return false
	return _states_match_size(states, int(level["rows"]), int(level["cols"]))


func _restore_formal_progress_snapshot() -> bool:
	var snapshot := formal_progress_snapshot.duplicate(true)
	if not _formal_progress_snapshot_is_valid(snapshot):
		formal_progress_snapshot.clear()
		return false
	current_level_index = int(snapshot["currentLevelIndex"])
	player_level_number = maxi(1, int(snapshot.get("playerLevelNumber", current_level_index + 1)))
	var snapshot_schedule = snapshot.get("activeSchedule", {})
	active_schedule = snapshot_schedule.duplicate(true) if snapshot_schedule is Dictionary else {}
	var snapshot_progress = snapshot.get("directorProgress", {})
	director_progress = snapshot_progress.duplicate(true) if snapshot_progress is Dictionary else {}
	LevelDirectorScript.normalize_progress(director_progress)
	var snapshot_economy = snapshot.get("economyProgress", {})
	economy_progress = snapshot_economy.duplicate(true) if snapshot_economy is Dictionary else CoinEconomyScript.default_progress()
	CoinEconomyScript.normalize_progress(economy_progress)
	completed_levels.assign(snapshot.get("completedLevels", []))
	for index in range(completed_levels.size()):
		completed_levels[index] = int(completed_levels[index])
	resume_level_id = int(snapshot["currentLevelId"])
	resume_states = snapshot["cellStates"].duplicate(true)
	resume_completed = bool(snapshot.get("isCompleted", false))
	resume_failed = bool(snapshot.get("isFailed", false))
	coin_count = int(snapshot.get("coinCount", coin_count))
	heart_count = maxi(0, int(snapshot.get("heartCount", INITIAL_HEART_COUNT)))
	hint_count = maxi(0, int(snapshot.get("hintCount", hint_count)))
	crown_find_count = clampi(int(snapshot.get("crownFindCount", crown_find_count)), 0, INITIAL_CROWN_FIND_COUNT)
	run_started_unix = int(snapshot.get("runStartedUnix", 0))
	run_move_count = maxi(0, int(snapshot.get("runMoveCount", 0)))
	run_hint_count = maxi(0, int(snapshot.get("runHintCount", 0)))
	run_coin_exchange_count = maxi(0, int(snapshot.get("runCoinExchangeCount", 0)))
	var snapshot_composite = snapshot.get("compositeState", {})
	resume_composite_state = snapshot_composite.duplicate(true) if snapshot_composite is Dictionary else {}
	composite_tutorial_seen = bool(snapshot.get("compositeTutorialSeen", composite_tutorial_seen))
	formal_progress_snapshot.clear()
	_load_level(current_level_index, true, active_schedule, true)
	return true


func _restore_home_composite_progress() -> bool:
	var snapshot := home_composite_progress_snapshot.duplicate(true)
	if not _formal_progress_snapshot_is_valid(snapshot):
		home_composite_progress_snapshot.clear()
		home_composite_entry_active = false
		home_composite_round = 0
		return false
	var preserved_tutorial_snapshot := formal_progress_snapshot.duplicate(true)
	var tutorial_seen_in_entry := composite_tutorial_seen
	formal_progress_snapshot = snapshot
	home_composite_progress_snapshot.clear()
	home_composite_entry_active = false
	home_composite_round = 0
	composite_intro_running = false
	composite_intro_marks_seen = false
	var restored := _restore_formal_progress_snapshot()
	formal_progress_snapshot = preserved_tutorial_snapshot
	composite_tutorial_seen = composite_tutorial_seen or tutorial_seen_in_entry
	return restored


func _save_game() -> void:
	if current_level.is_empty():
		return
	_sync_director_completed_levels()
	var data := {
		"saveVersion": SAVE_VERSION,
		"currentLevelIndex": current_level_index,
		"currentLevelId": int(current_level["levelId"]),
		"playerLevelNumber": player_level_number,
		"activeSchedule": active_schedule,
		"directorProgress": director_progress,
		"economyProgress": economy_progress,
		"runStartedUnix": run_started_unix,
		"runMoveCount": run_move_count,
		"runHintCount": run_hint_count,
		"runCoinExchangeCount": run_coin_exchange_count,
		"coinCount": coin_count,
		"heartCount": heart_count,
		"crownFindCount": crown_find_count,
		"completedLevels": completed_levels,
		"selectedTheme": "crown",
		"hintCount": hint_count,
		"immediateErrors": immediate_errors,
		"selectedLanguage": selected_language,
		"isCompleted": is_completed,
		"isFailed": is_failed,
		"cellStates": cell_states,
		"tutorialCompleted": tutorial_completed,
		"tutorialStarted": tutorial_started,
		"tutorialStepIndex": tutorial_step_index,
		"formalProgressSnapshot": formal_progress_snapshot,
		"homeCompositeEntryActive": home_composite_entry_active,
		"homeCompositeRound": home_composite_round,
		"homeCompositeProgressSnapshot": home_composite_progress_snapshot,
		"compositeState": _composite_save_state(),
		"compositeTutorialSeen": composite_tutorial_seen
	}
	resume_composite_state = data["compositeState"].duplicate(true)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _update_coin_label() -> void:
	if coin_label:
		coin_label.text = str(coin_count)
	if home_coin_label:
		home_coin_label.text = str(coin_count)


func _update_heart_label() -> void:
	_stop_heart_tweens()
	if not level_heart_slots.is_empty():
		for index in range(level_heart_slots.size()):
			var heart := level_heart_slots[index]
			heart.visible = index < current_heart_limit
			var is_full := index < heart_count
			heart.text = "♥"
			heart.add_theme_color_override("font_color", HEART_ACTIVE_COLOR if is_full else HEART_EMPTY_COLOR)
			heart.add_theme_font_size_override("font_size", 30)
			heart.scale = Vector2.ONE
			heart.pivot_offset = heart.custom_minimum_size * 0.5
			var pulse_tween: Tween = null
			if heart.visible and is_full and not in_tutorial:
				pulse_tween = heart.create_tween().set_loops()
				pulse_tween.set_trans(Tween.TRANS_SINE)
				var initial_delay := float(index) * HEART_PULSE_STAGGER_SECONDS
				if initial_delay > 0.0:
					pulse_tween.tween_interval(initial_delay)
				pulse_tween.tween_property(heart, "scale", Vector2(1.13, 1.13), 0.12).set_ease(Tween.EASE_OUT)
				pulse_tween.tween_property(heart, "scale", Vector2.ONE, 0.13).set_ease(Tween.EASE_IN)
				pulse_tween.tween_property(heart, "scale", Vector2(1.08, 1.08), 0.10).set_ease(Tween.EASE_OUT)
				pulse_tween.tween_property(heart, "scale", Vector2.ONE, 0.13).set_ease(Tween.EASE_IN)
				pulse_tween.tween_interval(0.86)
			level_heart_tweens.append(pulse_tween)
	if home_heart_label:
		home_heart_label.text = "♥  %d" % heart_count


func _stop_heart_tweens() -> void:
	for tween in level_heart_tweens:
		if tween and tween.is_valid():
			tween.kill()
	level_heart_tweens.clear()
	for heart in level_heart_slots:
		if heart:
			heart.scale = Vector2.ONE


func _heart_limit_for_display_level(display_level: int) -> int:
	if display_level <= 10:
		return 3
	if display_level <= 30:
		return 2
	return 1


func _consume_heart_for_wrong_crown() -> void:
	if heart_count > 0:
		heart_count -= 1
		audio_controller.play_heart_lost()
	_update_heart_label()
	_update_home()
	if heart_count <= 0:
		_fail_level()
	else:
		_show_toast("皇冠位置错误，红心 -1")


func _fail_level() -> void:
	if is_completed or is_failed:
		return
	is_failed = true
	active_hint_step.clear()
	active_hint_stage = 0
	board.set_guides({})
	if hint_button:
		hint_button.disabled = true
		_refresh_tool_button_visual(hint_button)
	if crown_find_button:
		crown_find_button.disabled = true
		_refresh_tool_button_visual(crown_find_button)
	if clear_button:
		clear_button.disabled = true
		_refresh_tool_button_visual(clear_button)
	coach_label.text = "红心已用完，本关挑战失败。"
	coach_label.add_theme_color_override("font_color", Color("#B93D4D"))
	_prepare_failure_result_page()
	_save_game()
	completion_overlay.show()
	completion_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(completion_overlay, "modulate:a", 1.0, 0.2)


func _update_hint_button() -> void:
	if not hint_button:
		return
	if in_tutorial:
		if hint_button_label:
			hint_button_label.text = "提示"
			_refresh_tool_button_visual(hint_button)
		return
	hint_button.disabled = is_completed or is_failed or _is_assembly_phase()
	if hint_count > 0:
		if hint_button_label:
			hint_button_label.text = _t("提示 ×%d", [hint_count])
	else:
		if hint_button_label:
			hint_button_label.text = _t("提示 -%d", [_current_tool_price(CoinEconomyScript.TOOL_HINT)])
	_refresh_tool_button_visual(hint_button)


func _update_crown_find_button() -> void:
	if not crown_find_button:
		return
	if in_tutorial:
		if crown_find_button_label:
			crown_find_button_label.text = "皇冠直找"
		crown_find_button.disabled = tutorial_interaction_stage != TUTORIAL_PHASE_CROWN_FIND
		_refresh_tool_button_visual(crown_find_button)
		return
	var has_target := not current_level.is_empty() and _next_findable_solution_cell().x >= 0
	if crown_find_button_label:
		crown_find_button_label.text = _t("直找 ×%d", [crown_find_count]) if crown_find_count > 0 else _t("直找 -%d", [_current_tool_price(CoinEconomyScript.TOOL_CROWN_FIND)])
	crown_find_button.disabled = is_completed or is_failed or not has_target
	_refresh_tool_button_visual(crown_find_button)


func _update_level_picker() -> void:
	if level_picker and level_picker.selected != current_level_index:
		level_picker.select(current_level_index)


func _show_home() -> void:
	_hide_tutorial_hand()
	_cancel_opening_king_intro(true)
	_stop_result_lion_animation()
	_stop_heart_tweens()
	if home_composite_entry_active:
		_restore_home_composite_progress()
		_save_game()
	if home_screen:
		home_screen.show()
	if game_screen:
		game_screen.hide()
	if completion_overlay:
		completion_overlay.hide()
	_update_home()


func _start_current_flow() -> void:
	if tutorial_completed:
		if is_completed:
			_next_level()
		_show_game()
	elif tutorial_started:
		_show_tutorial_resume_dialog()
	else:
		_start_tutorial_step(0)


func _start_home_composite_flow() -> void:
	if not tutorial_completed:
		_start_current_flow()
		return
	var candidate := _home_composite_candidate(1)
	if candidate.is_empty():
		_show_toast("暂时没有可用的 6×6 拼块关卡")
		return
	if not _capture_formal_progress_snapshot():
		_show_toast("当前关卡现场暂时无法保存")
		return
	home_composite_progress_snapshot = formal_progress_snapshot.duplicate(true)
	formal_progress_snapshot.clear()
	home_composite_entry_active = true
	home_composite_round = 1
	resume_level_id = -1
	resume_states.clear()
	resume_composite_state.clear()
	var schedule: Dictionary = candidate["schedule"]
	_load_level(int(candidate["levelIndex"]), false, schedule)
	if not _is_assembly_phase():
		_restore_home_composite_progress()
		_show_toast("拼块关卡生成失败，请重试")
		return
	_show_game()
	_save_game()


func _start_next_home_composite_round() -> void:
	var next_round := home_composite_round + 1
	var candidate := _home_composite_candidate(next_round)
	if candidate.is_empty():
		_show_toast("下一局生成失败，请重试")
		completion_overlay.show()
		return
	home_composite_round = next_round
	resume_level_id = -1
	resume_states.clear()
	resume_composite_state.clear()
	_load_level(int(candidate["levelIndex"]), false, candidate["schedule"])
	if not _is_assembly_phase():
		home_composite_round -= 1
		_show_toast("下一局生成失败，请重试")
		completion_overlay.show()
		return
	_show_game()
	_save_game()


func _home_composite_candidate(round_number: int = 1) -> Dictionary:
	var candidate_indices: Array[int] = []
	for index in range(levels.size()):
		var level: Dictionary = levels[index]
		if int(level.get("rows", 0)) == 6 and int(level.get("cols", 0)) == 6:
			candidate_indices.append(index)
	if candidate_indices.is_empty():
		return {}
	var safe_round := maxi(1, round_number)
	var start_offset := posmod(safe_round - 1, candidate_indices.size())
	for candidate_offset in range(candidate_indices.size()):
		var index := candidate_indices[(start_offset + candidate_offset) % candidate_indices.size()]
		var level: Dictionary = levels[index]
		var seed := int(level.get("levelId", 1)) * 1000003 + safe_round * 7919 + 20260722
		for seed_offset in range(12):
			var resolved_seed := seed + seed_offset
			if CompositeLevelScript.build(level, resolved_seed).is_empty():
				continue
			var schedule := LevelDirectorScript.manual_schedule_for_level(levels, index, 1, "home_composite")
			schedule["assemblyEnabled"] = true
			schedule["assemblySeed"] = resolved_seed
			schedule["homeCompositeRound"] = safe_round
			return {"levelIndex": index, "schedule": schedule}
	return {}


func _replay_tutorial_preserving_progress() -> void:
	_capture_formal_progress_snapshot()
	tutorial_completed = false
	tutorial_started = false
	tutorial_step_index = 0
	tutorial_interaction_stage = 0
	completion_overlay.hide()
	_start_tutorial_step(0)
	_show_toast("已进入新手教程，正式关卡进度已保存")


func _simulate_new_user_flow() -> void:
	_replay_tutorial_preserving_progress()


func _show_game() -> void:
	if home_screen:
		home_screen.hide()
	if game_screen:
		game_screen.show()
	_update_tutorial_button()
	if board:
		board.queue_redraw()
	if _is_assembly_phase():
		_apply_composite_phase_ui()
		call_deferred("_maybe_play_composite_intro")
	else:
		_play_pending_opening_king_reveal()


func _update_tutorial_button() -> void:
	if not tutorial_skip_button:
		return
	if in_tutorial:
		tutorial_skip_button.text = "跳过"
		tutorial_skip_button.tooltip_text = "跳过新手教程"
		tutorial_skip_button.show()
	else:
		tutorial_skip_button.hide()
	if top_home_button:
		top_home_button.show()
	if level_select_button:
		level_select_button.visible = not in_tutorial and not home_composite_entry_active
	if help_button:
		help_button.show()
	if level_heart_label:
		level_heart_label.show()
	if in_tutorial:
		_stop_heart_tweens()
	else:
		_update_heart_label()
	if crown_find_button:
		crown_find_button.visible = not _is_assembly_phase()
	if clear_button:
		clear_button.visible = not _is_assembly_phase()
	if hint_button:
		hint_button.visible = not _is_assembly_phase()


func _update_home() -> void:
	if not home_screen or levels.is_empty():
		return

	if home_coin_label:
		home_coin_label.text = str(coin_count)
	if home_heart_label:
		home_heart_label.text = "♥  %d" % heart_count
	if home_star_label:
		home_star_label.text = "★  %d" % completed_levels.size()
	if home_start_button:
		if tutorial_completed:
			home_start_button.text = _t("开始第 %d 关", [player_level_number])
		elif tutorial_started:
			home_start_button.text = "继续新手教程"
		else:
			home_start_button.text = "开始新手教程"
	if home_composite_button:
		home_composite_button.text = _t("拼块玩法")
		home_composite_button.disabled = not tutorial_completed
	_refresh_level_select_picker()


func _show_toast(message: String) -> void:
	toast_label.text = _runtime_text(message)
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.14)
	toast_tween.tween_interval(1.55)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.24)


func _show_tutorial_center_popup(message: String) -> void:
	tutorial_center_popup.text = _runtime_text(message)
	if tutorial_center_tween and tutorial_center_tween.is_valid():
		tutorial_center_tween.kill()
	tutorial_center_popup.modulate.a = 0.0
	tutorial_center_tween = create_tween()
	tutorial_center_tween.tween_property(tutorial_center_popup, "modulate:a", 1.0, 0.14)
	tutorial_center_tween.tween_interval(1.45)
	tutorial_center_tween.tween_property(tutorial_center_popup, "modulate:a", 0.0, 0.28)


func _show_fatal_error(message: String) -> void:
	var label := Label.new()
	label.text = message
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)


func _small_button(text: String, minimum_size: Vector2 = Vector2(40, 40), font_size: int = 18) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 13))
	button.add_theme_stylebox_override("hover", _button_style(Color("#E7EDF2"), 13))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#DDE5EC"), 13))
	return button


func _resource_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(88, 42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_stylebox_override("normal", _card_style(CARD, 18, true, 8))
	return label


func _coin_value_label(value: int) -> Label:
	var label := Label.new()
	label.name = "CoinValue"
	label.text = str(value)
	label.custom_minimum_size = Vector2(42, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#C98212"))
	label.add_theme_font_size_override("font_size", 18)
	return label


func _coin_resource_badge(value_label: Label) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(94, 42)
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 18, true, 8))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.name = "CoinIcon"
	icon.texture = COIN_ICON
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.add_child(value_label)
	return panel


func _piece_texture_rect(minimum_size: Vector2, texture: Texture2D = LION_KING_ICON) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _tool_button(kind: String, caption: String, color: Color, accent: Color) -> Dictionary:
	var button := _action_button("", color)
	button.name = "%sToolButton" % kind.capitalize()
	button.custom_minimum_size.y = 94
	button.size_flags_stretch_ratio = 1.0

	var margin := MarginContainer.new()
	margin.name = "ToolContent"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var icon: Control
	if kind == "crown":
		icon = _piece_texture_rect(Vector2(48, 48))
	else:
		var custom_icon = ToolIconScript.new()
		custom_icon.configure(ToolIconScript.CLEAR if kind == "clear" else ToolIconScript.HINT, accent)
		icon = custom_icon
	icon.name = "ToolIcon"
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)

	var label := Label.new()
	label.name = "ToolLabel"
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", accent)
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	return {"button": button, "icon": icon, "label": label}


func _refresh_tool_button_visual(button: Button) -> void:
	if not button:
		return
	var content := button.get_node_or_null("ToolContent")
	if content:
		content.modulate = Color(1.0, 1.0, 1.0, 0.38) if button.disabled else Color.WHITE


func _floating_home_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(52, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", _card_style(Color("#FFFFFF"), 18, true))
	button.add_theme_stylebox_override("hover", _card_style(Color("#F5F8FC"), 18, true))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#DFE8F2"), 18))
	return button


func _royal_home_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.24))
	button.add_theme_constant_override("shadow_offset_y", 3)
	button.add_theme_stylebox_override("normal", _card_style(color, 22, true))
	button.add_theme_stylebox_override("hover", _card_style(color.lightened(0.08), 22, true))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), 22))
	return button


func _nav_button(icon: String, label_text: String) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [icon, label_text]
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#DCEBFF"))
	button.add_theme_stylebox_override("normal", _button_style(Color("#2189E6"), 12))
	button.add_theme_stylebox_override("hover", _button_style(Color("#3297F0"), 12))
	button.add_theme_stylebox_override("pressed", _button_style(Color("#1069B7"), 12))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#0F63B1"), 12))
	return button


func _apply_action_button_style(button: Button, color: Color) -> void:
	if not button:
		return
	button.add_theme_stylebox_override("normal", _card_style(color, 20, true))
	button.add_theme_stylebox_override("hover", _card_style(color.lightened(0.04), 20, true))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.05), 20))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#EEECE8"), 20))


func _action_button(text: String, color: Color = CARD) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#B9BEC6"))
	button.add_theme_stylebox_override("normal", _card_style(color, 20, true))
	button.add_theme_stylebox_override("hover", _card_style(color.lightened(0.04), 20, true))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.05), 20))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#EEECE8"), 20))
	return button


func _t(source: String, values: Array = []) -> String:
	if not localization:
		return source % values if not values.is_empty() else source
	return localization.text(source, values)


func _runtime_text(source: String, generic_source: String = "请跟随高亮提示继续操作。") -> String:
	if not localization:
		return source
	return localization.runtime_text(source, generic_source)


func _button_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _card_style(color: Color, radius: int, shadow: bool = false, padding: int = 0) -> StyleBoxFlat:
	var style := _button_style(color, radius)
	if shadow:
		style.shadow_color = Color(0.20, 0.23, 0.30, 0.12)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 3)
	if padding > 0:
		style.content_margin_left = padding
		style.content_margin_right = padding
		style.content_margin_top = padding
		style.content_margin_bottom = padding
	return style


func _dialog_content_style() -> StyleBoxFlat:
	var style := _card_style(UITokensScript.DIALOG_CONTENT_SURFACE, 16, false, 8)
	style.border_color = UITokensScript.DIALOG_CONTENT_BORDER
	style.set_border_width_all(1)
	return style


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_H:
				_use_hint()
