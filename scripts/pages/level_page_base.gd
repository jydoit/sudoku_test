extends Control

signal home_requested
signal help_requested
signal settings_requested
signal level_select_requested
signal tutorial_requested
signal clear_requested
signal crown_find_requested
signal hint_requested
signal cell_pressed(row: int, col: int)
signal cell_double_pressed(row: int, col: int)
signal cell_drag_started(row: int, col: int)
signal cell_dragged(row: int, col: int)
signal cell_drag_ended
signal assembly_placement_requested(piece_id: int, origin: Array)
signal assembly_return_requested(piece_id: int, preferred_slot_index: int)
signal assembly_intro_finished

const GameBoardScript = preload("res://scripts/game_board.gd")
const AssemblyViewScript = preload("res://scripts/assembly_view.gd")
const ToolIconScript = preload("res://scripts/tool_icon.gd")
const CoinRollDisplayScript = preload("res://scripts/components/coin_roll_display.gd")
const CoinIconResourceScript = preload("res://scripts/components/coin_icon_resource.gd")
const UITokensScript = preload("res://scripts/ui_tokens.gd")
const LION_KING_ICON = preload("res://assets/ui/lion_king.png")
const INITIAL_HEART_COUNT := 3
const COIN_BALANCE_ROLL_DURATION := 1.35
const COIN_FEEDBACK_FADE_IN := 0.18
const COIN_FEEDBACK_HOLD := 0.82
const COIN_FEEDBACK_FADE_OUT := 0.42
const CARD := UITokensScript.SURFACE_CARD
const INK := UITokensScript.INK

var board
var assembly_view
var assembly_tray_target: Control
var action_bar: Control
var progress_row: Control
var progress_bar: ProgressBar
var progress_label: Label
var level_label: Label
var assembly_stage_label: Label
var coach_panel: PanelContainer
var coach_label: Label
var top_home_button: Button
var help_button: Button
var settings_button: Button
var level_select_button: Button
var tutorial_skip_button: Button
var coin_label: Label
var coin_roll_display: HBoxContainer
var coin_balance_roll_clip: Control
var coin_balance_roll_secondary: Label
var level_heart_label: Control
var level_heart_slots: Array[Label] = []
var clear_button: Button
var clear_button_label: Label
var clear_status_panel: PanelContainer
var clear_status_icon: TextureRect
var clear_status_label: Label
var crown_find_button: Button
var crown_find_button_label: Label
var crown_find_status_panel: PanelContainer
var crown_find_status_icon: TextureRect
var crown_find_status_label: Label
var hint_button: Button
var hint_button_label: Label
var hint_status_panel: PanelContainer
var hint_status_icon: TextureRect
var hint_status_label: Label
var coin_delta_panel: PanelContainer
var coin_delta_label: Label
var coin_delta_tween: Tween
var heart_tweens: Array = []
var _localizer: Callable
var _level_select_enabled := true


func setup(initial_coins: int, include_assembly: bool, localizer: Callable = Callable(), enable_level_select: bool = true) -> void:
	_localizer = localizer
	_level_select_enabled = enable_level_select
	name = "CompositeLevelPage" if include_assembly else "FormalLevelPage"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_margin.add_theme_constant_override("margin_left", 6)
	safe_margin.add_theme_constant_override("margin_right", 6)
	safe_margin.add_theme_constant_override("margin_top", 16)
	safe_margin.add_theme_constant_override("margin_bottom", 12)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	safe_margin.add_child(content)
	content.add_child(_build_top_bar(initial_coins))
	content.add_child(_build_level_header())
	progress_row = _build_progress_row()
	content.add_child(progress_row)
	content.add_child(_build_coach())

	assembly_tray_target = Control.new()
	assembly_tray_target.name = "AssemblyTrayTop"
	assembly_tray_target.custom_minimum_size.y = 118
	assembly_tray_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assembly_tray_target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	assembly_tray_target.hide()
	content.add_child(assembly_tray_target)

	board = GameBoardScript.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.cell_pressed.connect(func(row: int, col: int) -> void: cell_pressed.emit(row, col))
	board.cell_double_pressed.connect(func(row: int, col: int) -> void: cell_double_pressed.emit(row, col))
	board.cell_drag_started.connect(func(row: int, col: int) -> void: cell_drag_started.emit(row, col))
	board.cell_dragged.connect(func(row: int, col: int) -> void: cell_dragged.emit(row, col))
	board.cell_drag_ended.connect(func() -> void: cell_drag_ended.emit())
	content.add_child(board)

	action_bar = _build_action_bar()
	content.add_child(action_bar)
	add_child(safe_margin)
	_build_coin_delta_feedback()

	if include_assembly:
		assembly_view = AssemblyViewScript.new()
		if localizer.is_valid():
			assembly_view.set_localizer(localizer)
		assembly_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		assembly_view.z_index = 4
		assembly_view.placement_requested.connect(func(piece_id: int, origin: Array) -> void: assembly_placement_requested.emit(piece_id, origin))
		assembly_view.return_requested.connect(func(piece_id: int, preferred_slot_index: int = -1) -> void: assembly_return_requested.emit(piece_id, preferred_slot_index))
		assembly_view.intro_finished.connect(func() -> void: assembly_intro_finished.emit())
		add_child(assembly_view)
		assembly_view.bind_targets(board, assembly_tray_target)


func set_coin_balance(value: int) -> void:
	if coin_roll_display:
		coin_roll_display.set_value(maxi(0, value))


func set_progress(current: int, target: int) -> void:
	if progress_bar:
		progress_bar.max_value = maxi(0, target)
		progress_bar.value = maxi(0, current)
	if progress_label:
		progress_label.text = "%d / %d" % [maxi(0, current), maxi(0, target)]


func set_level_copy(title_text: String, coach_text: String, coach_color: Color, coach_size: int = 16) -> void:
	if level_label:
		level_label.text = title_text
	if coach_label:
		coach_label.text = coach_text
		coach_label.add_theme_color_override("font_color", coach_color)
		coach_label.add_theme_font_size_override("font_size", coach_size)


func set_hearts(current: int, limit: int) -> void:
	stop_heart_animation()
	for index in range(level_heart_slots.size()):
		var heart := level_heart_slots[index]
		heart.visible = index < limit
		var is_full := index < current
		heart.text = "♥"
		heart.add_theme_color_override("font_color", Color("#F25D72") if is_full else Color("#C8CDD5"))
		heart.add_theme_font_size_override("font_size", 30)
		heart.scale = Vector2.ONE
		heart.pivot_offset = heart.custom_minimum_size * 0.5


func stop_heart_animation() -> void:
	for tween in heart_tweens:
		if tween and tween.is_valid():
			tween.kill()
	heart_tweens.clear()
	for heart in level_heart_slots:
		if heart:
			heart.scale = Vector2.ONE


func present_tool(kind: String, data: Dictionary) -> void:
	var parts := _tool_parts(kind)
	if parts.is_empty():
		return
	var button: Button = parts["button"]
	var label: Label = parts["label"]
	button.visible = bool(data.get("visible", true))
	button.disabled = bool(data.get("disabled", false))
	label.text = _t(str(data.get("label", label.text)))
	_set_tool_status(
		parts["status_panel"],
		parts["status_icon"],
		parts["status_label"],
		str(data.get("status", "free_forever")),
		int(data.get("value", 0))
	)
	var color: Color = data.get("highlight", _tool_base_color(kind))
	_apply_action_button_style(button, color)
	if data.has("font_color"):
		button.add_theme_color_override("font_color", data["font_color"])
	_refresh_tool_button_visual(button)


func set_all_tools_visible(value: bool) -> void:
	for button in [clear_button, crown_find_button, hint_button]:
		if button:
			button.visible = value


func reset_tool_styles() -> void:
	_apply_action_button_style(clear_button, _tool_base_color("clear"))
	_apply_action_button_style(crown_find_button, _tool_base_color("crown"))
	crown_find_button.add_theme_color_override("font_color", Color("#B97A09"))
	_apply_action_button_style(hint_button, _tool_base_color("hint"))
	hint_button.add_theme_color_override("font_color", Color("#2D9E63"))


func _tool_parts(kind: String) -> Dictionary:
	match kind:
		"clear":
			return {"button": clear_button, "label": clear_button_label, "status_panel": clear_status_panel, "status_icon": clear_status_icon, "status_label": clear_status_label}
		"crown":
			return {"button": crown_find_button, "label": crown_find_button_label, "status_panel": crown_find_status_panel, "status_icon": crown_find_status_icon, "status_label": crown_find_status_label}
		"hint":
			return {"button": hint_button, "label": hint_button_label, "status_panel": hint_status_panel, "status_icon": hint_status_icon, "status_label": hint_status_label}
	return {}


func _tool_base_color(kind: String) -> Color:
	match kind:
		"clear": return Color("#EEF5FF")
		"crown": return Color("#FFF4CE")
		"hint": return Color("#EAFBF0")
	return CARD


func _set_tool_status(panel: PanelContainer, icon: TextureRect, label: Label, mode: String, value: int) -> void:
	if not panel or not icon or not label:
		return
	icon.visible = mode == "paid"
	var free_color: Color = panel.get_meta("free_color", Color("#EFF2F5"))
	var free_text_color: Color = panel.get_meta("free_text_color", Color("#526070"))
	var paid_color: Color = panel.get_meta("paid_color", Color("#FFD978"))
	var paid_text_color: Color = panel.get_meta("paid_text_color", Color("#9B6400"))
	var paid_border_color: Color = panel.get_meta("paid_border_color", paid_color.darkened(0.14))
	match mode:
		"paid":
			label.text = str(maxi(0, value))
			label.add_theme_color_override("font_color", paid_text_color)
			panel.add_theme_stylebox_override("panel", _tool_status_style(paid_color, paid_border_color))
		"free":
			label.text = _t("免费 ×%d", [maxi(0, value)])
			label.add_theme_color_override("font_color", free_text_color)
			panel.add_theme_stylebox_override("panel", _tool_status_style(free_color))
		"tutorial":
			label.text = _t("教程免费")
			label.add_theme_color_override("font_color", free_text_color)
			panel.add_theme_stylebox_override("panel", _tool_status_style(free_color))
		_:
			label.text = _t("免费")
			label.add_theme_color_override("font_color", free_text_color)
			panel.add_theme_stylebox_override("panel", _tool_status_style(free_color))


func _tool_status_style(color: Color, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := _button_style(color, 11)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	if border_color.a > 0.0:
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = border_color
	return style


func _refresh_tool_button_visual(button: Button) -> void:
	if not button:
		return
	var content := button.get_node_or_null("ToolContent")
	if content:
		content.modulate = Color(1.0, 1.0, 1.0, 0.38) if button.disabled else Color.WHITE


func _apply_action_button_style(button: Button, color: Color) -> void:
	if not button:
		return
	button.add_theme_stylebox_override("normal", _card_style(color, 20, true))
	button.add_theme_stylebox_override("hover", _card_style(color.lightened(0.04), 20, true))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.05), 20))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#EEECE8"), 20))


func _t(source: String, values: Array = []) -> String:
	if not _localizer.is_valid():
		return source % values if not values.is_empty() else source
	return str(_localizer.call(source, values))


func play_coin_deduction(balance_before: int, balance_after: int, amount: int) -> void:
	if not coin_roll_display or amount <= 0:
		return
	if coin_delta_tween and coin_delta_tween.is_valid():
		coin_delta_tween.kill()
	coin_roll_display.set_value(balance_before)
	coin_roll_display.animate_to(balance_after, COIN_BALANCE_ROLL_DURATION)
	var badge_rect: Rect2 = coin_roll_display.get_global_rect()
	var page_origin: Vector2 = get_global_rect().position
	var start_position := Vector2(
		badge_rect.get_center().x - page_origin.x - coin_delta_panel.size.x * 0.5,
		badge_rect.end.y - page_origin.y + 4.0
	)
	coin_delta_label.text = "−%d" % amount
	coin_delta_panel.position = start_position
	coin_delta_panel.modulate.a = 0.0
	coin_delta_panel.show()
	coin_delta_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	coin_delta_tween.tween_property(coin_delta_panel, "modulate:a", 1.0, COIN_FEEDBACK_FADE_IN)
	coin_delta_tween.parallel().tween_property(coin_delta_panel, "position", start_position - Vector2(0, 8), COIN_FEEDBACK_FADE_IN)
	coin_delta_tween.tween_interval(COIN_FEEDBACK_HOLD)
	coin_delta_tween.tween_property(coin_delta_panel, "modulate:a", 0.0, COIN_FEEDBACK_FADE_OUT)
	coin_delta_tween.parallel().tween_property(coin_delta_panel, "position", start_position - Vector2(0, 28), COIN_FEEDBACK_FADE_OUT)
	coin_delta_tween.tween_callback(func() -> void: coin_delta_panel.hide())
func _build_coin_delta_feedback() -> void:
	coin_delta_panel = PanelContainer.new()
	coin_delta_panel.name = "CoinDeductionFeedback"
	coin_delta_panel.custom_minimum_size = Vector2(92, 36)
	coin_delta_panel.size = Vector2(92, 36)
	coin_delta_panel.z_index = 40
	coin_delta_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_delta_panel.add_theme_stylebox_override("panel", _card_style(Color("#FFF1BD"), 18, true, 5))
	add_child(coin_delta_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_delta_panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = CoinIconResourceScript.texture()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	coin_delta_label = Label.new()
	coin_delta_label.name = "CoinDeductionAmount"
	coin_delta_label.add_theme_color_override("font_color", Color("#B86D10"))
	coin_delta_label.add_theme_font_size_override("font_size", 17)
	coin_delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin_delta_label)
	coin_delta_panel.hide()


func _build_top_bar(initial_coins: int) -> Control:
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
	top_home_button.pressed.connect(func() -> void: home_requested.emit())
	row.add_child(top_home_button)
	coin_roll_display = CoinRollDisplayScript.new()
	coin_roll_display.name = "LevelCoinRollDisplay"
	coin_roll_display.configure({
		"initial_value": initial_coins,
		"font_size": 24,
		"minimum_counter_width": 62.0,
		"minimum_counter_height": 44.0,
		"minimum_digits": 5,
		"horizontal_padding": 6.0,
		"vertical_padding": 4.0,
		"icon_size": Vector2(30, 30),
		"separation": 5,
		"font_color": Color("#C98212"),
		"shadow_offset_y": 2,
	})
	coin_label = coin_roll_display.primary_label
	coin_balance_roll_clip = coin_roll_display.clip
	coin_balance_roll_secondary = coin_roll_display.secondary_label
	row.add_child(_coin_resource_badge(coin_roll_display))
	level_heart_label = _build_heart_display()
	row.add_child(level_heart_label)
	tutorial_skip_button = _small_button("跳")
	tutorial_skip_button.tooltip_text = "跳过新手教程"
	tutorial_skip_button.pressed.connect(func() -> void: tutorial_requested.emit())
	tutorial_skip_button.hide()
	row.add_child(tutorial_skip_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	help_button = _small_button("?", Vector2(46, 46), 24)
	help_button.tooltip_text = "查看消除规则"
	help_button.pressed.connect(func() -> void: help_requested.emit())
	row.add_child(help_button)
	settings_button = _small_button("⚙", Vector2(46, 46), 22)
	settings_button.tooltip_text = "设置"
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	row.add_child(settings_button)
	if _level_select_enabled:
		level_select_button = _small_button("选关")
		level_select_button.tooltip_text = "选择关卡"
		level_select_button.pressed.connect(func() -> void: level_select_requested.emit())
		row.add_child(level_select_button)
	return panel


func _build_level_header() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 46
	level_label = Label.new()
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.add_theme_color_override("font_color", INK)
	level_label.add_theme_font_size_override("font_size", 27)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_label.clip_text = true
	level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(level_label)
	assembly_stage_label = Label.new()
	assembly_stage_label.text = "先拼好颜色区域"
	assembly_stage_label.size_flags_horizontal = Control.SIZE_SHRINK_END
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
	row.add_child(_piece_texture_rect(Vector2(38, 38)))
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
	row.custom_minimum_size.y = 98
	row.add_theme_constant_override("separation", 10)
	var clear_tool := _tool_button("clear", "清除", Color("#EEF5FF"), Color("#477DB7"))
	clear_button = clear_tool["button"]
	clear_button_label = clear_tool["label"]
	clear_status_panel = clear_tool["status_panel"]
	clear_status_icon = clear_tool["status_icon"]
	clear_status_label = clear_tool["status_label"]
	clear_button.pressed.connect(func() -> void: clear_requested.emit())
	row.add_child(clear_button)
	var crown_tool := _tool_button("crown", "直找", Color("#FFF4CE"), Color("#B97A09"))
	crown_find_button = crown_tool["button"]
	crown_find_button_label = crown_tool["label"]
	crown_find_status_panel = crown_tool["status_panel"]
	crown_find_status_icon = crown_tool["status_icon"]
	crown_find_status_label = crown_tool["status_label"]
	crown_find_button.pressed.connect(func() -> void: crown_find_requested.emit())
	row.add_child(crown_find_button)
	var hint_tool := _tool_button("hint", "提示", Color("#EAF8F0"), Color("#23845C"))
	hint_button = hint_tool["button"]
	hint_button_label = hint_tool["label"]
	hint_status_panel = hint_tool["status_panel"]
	hint_status_icon = hint_tool["status_icon"]
	hint_status_label = hint_tool["status_label"]
	hint_button.pressed.connect(func() -> void: hint_requested.emit())
	row.add_child(hint_button)
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


func _coin_resource_badge(display: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "LevelCoinBadge"
	panel.custom_minimum_size = Vector2(122, 48)
	panel.add_theme_stylebox_override("panel", _card_style(CARD, 18, true, 8))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(display)
	return panel


func _piece_texture_rect(minimum_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = LION_KING_ICON
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _tool_button(kind: String, caption: String, color: Color, accent: Color) -> Dictionary:
	var button := _action_button("", color)
	button.name = "%sToolButton" % kind.capitalize()
	button.custom_minimum_size.y = 98
	button.size_flags_stretch_ratio = 1.0
	var margin := MarginContainer.new()
	margin.name = "ToolContent"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
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
	icon.custom_minimum_size = Vector2(44, 44)
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
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	var status_panel := PanelContainer.new()
	status_panel.name = "ToolStatusPill"
	status_panel.custom_minimum_size = Vector2(72, 20)
	status_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.set_meta("free_color", color.darkened(0.045))
	status_panel.set_meta("free_text_color", accent)
	status_panel.set_meta("paid_color", Color("#CFF4E0") if kind == "hint" else Color("#FFD978"))
	status_panel.set_meta("paid_text_color", Color("#1F7A55") if kind == "hint" else Color("#9B6400"))
	status_panel.set_meta("paid_border_color", Color("#91D8B5") if kind == "hint" else Color("#E6B045"))
	column.add_child(status_panel)
	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 3)
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(status_row)
	var status_icon := TextureRect.new()
	status_icon.name = "ToolStatusCoinIcon"
	status_icon.texture = CoinIconResourceScript.texture()
	status_icon.custom_minimum_size = Vector2(16, 16)
	status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(status_icon)
	var status_label := Label.new()
	status_label.name = "ToolStatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(status_label)
	_set_initial_free_status(status_panel, status_icon, status_label)
	return {"button": button, "label": label, "status_panel": status_panel, "status_icon": status_icon, "status_label": status_label}


func _set_initial_free_status(panel: PanelContainer, icon: TextureRect, label: Label) -> void:
	icon.hide()
	label.text = "免费"
	label.add_theme_color_override("font_color", panel.get_meta("free_text_color", Color("#526070")))
	var style := _button_style(panel.get_meta("free_color", Color("#EFF2F5")), 11)
	style.content_margin_left = 8
	style.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", style)


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
