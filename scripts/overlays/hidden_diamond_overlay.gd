extends Control

signal dismissed

const UI = preload("res://scripts/ui_tokens.gd")
const Policy = preload("res://scripts/services/hidden_diamond_policy.gd")
const LION = preload("res://assets/ui/lion_king.svg")
const DIAMOND = preload("res://assets/ui/diamond.svg")
const CLOCK = preload("res://assets/ui/challenge_clock.svg")
const MOVES = preload("res://assets/ui/challenge_moves.svg")
const ReliefPanel = preload("res://scripts/components/relief_panel.gd")

var _localizer: Callable
var _animation_root: Control
var _card: PanelContainer
var _title: Label
var _target: Label
var _constraint: Label
var _reward: Label
var _constraint_icon: TextureRect
var _tween: Tween


func configure(localizer: Callable) -> void:
	_localizer = localizer
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var shade := ColorRect.new()
	shade.color = UI.DIALOG_SCRIM
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_animation_root = Control.new()
	_animation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_animation_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_animation_root.add_child(center)
	_card = ReliefPanel.new()
	_card.name = "ChallengeAnnouncementCard"
	_card.configure("cream", Vector2(16, 16), 26)
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_card.add_child(column)
	var title_panel := ReliefPanel.new()
	title_panel.configure("blue", Vector2(12, 10))
	column.add_child(title_panel)
	_title = _label(26)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_color_override("font_color", Color("#FFF9DF"))
	_title.add_theme_color_override("font_outline_color", UI.RELIEF_BLUE_EDGE)
	_title.add_theme_constant_override("outline_size", 3)
	title_panel.add_child(_title)
	var goals := HBoxContainer.new()
	goals.alignment = BoxContainer.ALIGNMENT_CENTER
	goals.add_theme_constant_override("separation", 12)
	var target_row := HBoxContainer.new()
	target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	target_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	target_row.add_theme_constant_override("separation", 8)
	target_row.add_child(_icon(LION, 48))
	_target = _label(28)
	_target.text_direction = Control.TEXT_DIRECTION_LTR
	target_row.add_child(_target)
	goals.add_child(target_row)
	var constraint_panel := ReliefPanel.new()
	constraint_panel.configure("blue", Vector2(14, 9))
	constraint_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goals.add_child(constraint_panel)
	var constraint_row := HBoxContainer.new()
	constraint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	constraint_row.add_theme_constant_override("separation", 5)
	constraint_panel.add_child(constraint_row)
	_constraint_icon = _icon(CLOCK, 34)
	constraint_row.add_child(_constraint_icon)
	_constraint = _label(25)
	_constraint.add_theme_color_override("font_color", Color("#FFF9DF"))
	_constraint.add_theme_color_override("font_outline_color", UI.RELIEF_BLUE_EDGE)
	_constraint.add_theme_constant_override("outline_size", 2)
	constraint_row.add_child(_constraint)
	column.add_child(goals)
	var reward_center := CenterContainer.new()
	column.add_child(reward_center)
	var reward_panel := ReliefPanel.new()
	reward_panel.configure("teal", Vector2(24, 14), 24)
	reward_center.add_child(reward_panel)
	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	reward_row.add_theme_constant_override("separation", 12)
	reward_row.add_child(_icon(DIAMOND, 68))
	_reward = _label(36)
	_reward.text_direction = Control.TEXT_DIRECTION_LTR
	_reward.add_theme_color_override("font_color", Color.WHITE)
	_reward.add_theme_color_override("font_outline_color", Color("#24718D"))
	_reward.add_theme_constant_override("outline_size", 3)
	reward_row.add_child(_reward)
	reward_panel.add_child(reward_row)
	resized.connect(_fit_card)
	_fit_card()


func present(event: Dictionary) -> void:
	dismiss()
	_title.text = _t("限时挑战" if event["kind"] == "time" else "限步挑战")
	_target.text = "× %d" % int(event["target"])
	_constraint.text = _t("%d 秒" if event["kind"] == "time" else "%d 步", [int(event["limit"])])
	_constraint_icon.texture = CLOCK if event["kind"] == "time" else MOVES
	_reward.text = "× %d" % int(event["reward"])
	_fit_card()
	show()
	_animation_root.position.y = -32.0
	_animation_root.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_animation_root, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_animation_root, "modulate:a", 1.0, 0.18)
	_tween.chain().tween_interval(Policy.INTRO_SECONDS - 0.18 - 0.15)
	_tween.chain().tween_property(_animation_root, "modulate:a", 0.0, 0.15)
	_tween.chain().tween_callback(_finish)


func dismiss() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	hide()


func _finish() -> void:
	dismiss()
	dismissed.emit()


func _fit_card() -> void:
	if _card:
		_card.custom_minimum_size.x = clampf(size.x - 48.0, 280.0, 380.0)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UI.INK)
	label.add_theme_color_override("font_outline_color", UI.INK)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _icon(texture: Texture2D, side: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _t(source: String, values: Array = []) -> String:
	if _localizer.is_valid():
		return str(_localizer.call(source, values))
	return source % values if not values.is_empty() else source
