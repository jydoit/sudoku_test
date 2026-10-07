extends PanelContainer

const UI = preload("res://scripts/ui_tokens.gd")
const LION = preload("res://assets/ui/lion_king.svg")
const DIAMOND = preload("res://assets/ui/diamond.svg")
const CLOCK = preload("res://assets/ui/challenge_clock.svg")
const MOVES = preload("res://assets/ui/challenge_moves.svg")
const ReliefPanel = preload("res://scripts/components/relief_panel.gd")

var _localizer: Callable
var _limit: Label
var _lions: Label
var _reward: Label
var _limit_panel: PanelContainer
var _limit_icon: TextureRect
var _pulse: Tween
var _last_remaining := -1
var _last_kind := ""
var _urgent := false


func configure(localizer: Callable) -> void:
	_localizer = localizer
	name = "HiddenDiamondHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 72
	var style := StyleBoxEmpty.new()
	style.content_margin_bottom = 3
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var target_panel := _plate("cream", "ChallengeTarget")
	row.add_child(target_panel)
	var target_row := _row(target_panel)
	target_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	target_row.add_child(_icon(LION))
	_lions = _label()
	_lions.text_direction = Control.TEXT_DIRECTION_LTR
	target_row.add_child(_lions)
	_limit_panel = _plate("blue", "ChallengeLimit")
	_limit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_limit_panel)
	var limit_row := _row(_limit_panel)
	# Numeric time stays LTR even inside the Arabic UI.
	limit_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_limit_icon = _icon(CLOCK)
	_limit_icon.custom_minimum_size = Vector2(38, 38)
	limit_row.add_child(_limit_icon)
	_limit = _label()
	_limit.name = "ChallengeDigits"
	_limit.add_theme_font_size_override("font_size", 28)
	_limit.custom_minimum_size.x = 100
	_limit.add_theme_color_override("font_color", Color("#FFF9DF"))
	_limit.add_theme_color_override("font_outline_color", UI.RELIEF_BLUE_EDGE)
	_limit.add_theme_constant_override("outline_size", 3)
	_limit.add_theme_color_override("font_shadow_color", Color(0.07, 0.18, 0.32, 0.5))
	_limit.add_theme_constant_override("shadow_offset_y", 2)
	_limit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	limit_row.add_child(_limit)
	var reward_panel := _plate("teal", "ChallengeReward")
	row.add_child(reward_panel)
	var reward_row := _row(reward_panel)
	reward_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	reward_row.add_child(_icon(DIAMOND))
	_reward = _label()
	_reward.text_direction = Control.TEXT_DIRECTION_LTR
	_reward.add_theme_color_override("font_color", Color.WHITE)
	_reward.add_theme_color_override("font_outline_color", Color("#24718D"))
	_reward.add_theme_constant_override("outline_size", 2)
	reward_row.add_child(_reward)
	visibility_changed.connect(_on_visibility_changed)
	hide()


func present(data: Dictionary) -> void:
	visible = not data.is_empty()
	if data.is_empty():
		_stop_pulse()
		_last_remaining = -1
		_last_kind = ""
		_urgent = false
		_limit.text = ""
		_lions.text = ""
		_reward.text = ""
		return
	var remaining := int(data["remaining"])
	var kind := str(data["kind"])
	_lions.text = "× %d" % int(data["lions"])
	_reward.text = "× %d" % int(data["reward"])
	_limit_icon.texture = CLOCK if kind == "time" else MOVES
	_limit.text_direction = Control.TEXT_DIRECTION_LTR if kind == "time" else Control.TEXT_DIRECTION_AUTO
	if kind == "time":
		_limit.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	else:
		_limit.text = str(_localizer.call("%d 步", [remaining])) if _localizer.is_valid() else "%d 步" % remaining
	var urgent := remaining <= (10 if kind == "time" else 3)
	_limit_panel.set_variant("urgent" if urgent else "blue")
	_limit.add_theme_color_override("font_outline_color", Color("#813436") if urgent else UI.RELIEF_BLUE_EDGE)
	if _last_remaining >= 0 and kind == _last_kind and remaining < _last_remaining:
		if kind == "moves" or (urgent and not _urgent) or (kind == "time" and remaining <= 3):
			_pulse_digits()
	_last_remaining = remaining
	_last_kind = kind
	_urgent = urgent


func _plate(variant: String, node_name: String) -> PanelContainer:
	var panel := ReliefPanel.new()
	panel.name = node_name
	panel.configure(variant, Vector2(12, 2))
	panel.custom_minimum_size.x = 112
	return panel


func _row(panel: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	return row


func _pulse_digits() -> void:
	_stop_pulse()
	if not is_visible_in_tree():
		return
	_limit.pivot_offset = _limit.size * 0.5
	_pulse = create_tween()
	_pulse.tween_property(_limit, "scale", Vector2.ONE * 1.06, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(_limit, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse:
		_pulse.kill()
		_pulse = null
	if _limit:
		_limit.scale = Vector2.ONE


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_stop_pulse()


func _label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", UI.INK)
	label.add_theme_color_override("font_outline_color", UI.INK)
	label.add_theme_constant_override("outline_size", 1)
	return label


func _icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(32, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
