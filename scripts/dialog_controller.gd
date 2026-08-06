class_name DialogController
extends Control

signal action_selected(dialog_id: String, action_id: String)
signal cancelled(dialog_id: String)
signal closed(dialog_id: String)

const UITokensScript = preload("res://scripts/ui_tokens.gd")

var current_dialog_id := ""
var _registered_contents: Dictionary = {}
var _active_tween: Tween
var _localizer: Callable

var _scrim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _close_button: Button
var _message_label: Label
var _content_host: VBoxContainer
var _action_row: HBoxContainer
var _primary_button: Button


func _ready() -> void:
	_build_ui()
	hide()


func register_content(content_id: String, content: Control) -> void:
	if content_id.is_empty() or not content:
		return
	if content.get_parent():
		content.get_parent().remove_child(content)
	_content_host.add_child(content)
	content.hide()
	_registered_contents[content_id] = content


func set_localizer(localizer: Callable) -> void:
	_localizer = localizer


func show_dialog(
	dialog_id: String,
	title_text: String,
	message_text: String = "",
	content_id: String = "",
	actions: Array = [],
	preferred_width: int = UITokensScript.DIALOG_STANDARD_WIDTH,
	show_close: bool = true
) -> void:
	if visible:
		hide_dialog(true)
	current_dialog_id = dialog_id
	_title_label.text = _localized(title_text)
	_close_button.visible = show_close
	_message_label.text = _localized(message_text)
	_message_label.visible = not message_text.is_empty()
	for registered_content in _registered_contents.values():
		(registered_content as Control).hide()
	if _registered_contents.has(content_id):
		(_registered_contents[content_id] as Control).show()
	_build_actions(actions)
	var viewport_width := get_viewport_rect().size.x
	_card.custom_minimum_size.x = minf(float(preferred_width), maxf(280.0, viewport_width - UITokensScript.DIALOG_SCREEN_MARGIN * 2.0))
	show()
	move_to_front()
	_scrim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.96, 0.96)
	call_deferred("_play_open_animation")


func hide_dialog(immediate: bool = false) -> void:
	if not visible:
		return
	var closing_dialog_id := current_dialog_id
	current_dialog_id = ""
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	if immediate:
		hide()
		closed.emit(closing_dialog_id)
		return
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_scrim, "modulate:a", 0.0, 0.14)
	_active_tween.tween_property(_card, "modulate:a", 0.0, 0.14)
	_active_tween.tween_property(_card, "scale", Vector2(0.98, 0.98), 0.14)
	_active_tween.chain().tween_callback(func() -> void:
		hide()
		closed.emit(closing_dialog_id)
	)


func is_dialog_open(dialog_id: String = "") -> bool:
	return visible and (dialog_id.is_empty() or current_dialog_id == dialog_id)


func content(content_id: String) -> Control:
	return _registered_contents.get(content_id) as Control


func _build_ui() -> void:
	name = "DialogController"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

	_scrim = ColorRect.new()
	_scrim.name = "DialogScrim"
	_scrim.color = UITokensScript.DIALOG_SCRIM
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.name = "DialogCard"
	_card.custom_minimum_size.x = UITokensScript.DIALOG_STANDARD_WIDTH
	_card.add_theme_stylebox_override("panel", _dialog_card_style())
	center.add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 44
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)

	_title_label = Label.new()
	_title_label.name = "DialogTitle"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", UITokensScript.INK)
	_title_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = "DialogCloseButton"
	_close_button.text = "×"
	_close_button.custom_minimum_size = Vector2(44, 44)
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.add_theme_font_size_override("font_size", 24)
	_close_button.add_theme_color_override("font_color", UITokensScript.INK)
	_close_button.add_theme_stylebox_override("normal", _button_style(UITokensScript.DIALOG_SECONDARY_BUTTON))
	_close_button.add_theme_stylebox_override("hover", _button_style(UITokensScript.SOFT_BLUE))
	_close_button.add_theme_stylebox_override("pressed", _button_style(UITokensScript.SOFT_BLUE.darkened(0.06)))
	_close_button.pressed.connect(_request_cancel)
	header.add_child(_close_button)

	_message_label = Label.new()
	_message_label.name = "DialogMessage"
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_color_override("font_color", UITokensScript.INK)
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.add_theme_constant_override("line_spacing", 5)
	column.add_child(_message_label)

	_content_host = VBoxContainer.new()
	_content_host.name = "DialogContentHost"
	column.add_child(_content_host)

	_action_row = HBoxContainer.new()
	_action_row.name = "DialogActionRow"
	_action_row.add_theme_constant_override("separation", 12)
	column.add_child(_action_row)


func _build_actions(actions: Array) -> void:
	for child in _action_row.get_children():
		child.queue_free()
	_primary_button = null
	for action in actions:
		if not action is Dictionary:
			continue
		var action_data: Dictionary = action
		var action_id := str(action_data.get("id", ""))
		var button := Button.new()
		button.name = "DialogAction_%s" % action_id
		button.text = _localized(str(action_data.get("text", "")))
		button.custom_minimum_size.y = UITokensScript.DIALOG_BUTTON_HEIGHT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		_apply_button_variant(button, str(action_data.get("variant", "secondary")))
		button.pressed.connect(func() -> void: _activate_action(action_id))
		_action_row.add_child(button)
		if str(action_data.get("variant", "secondary")) == "primary":
			_primary_button = button
	_action_row.visible = not actions.is_empty()


func _localized(source: String) -> String:
	if source.is_empty() or not _localizer.is_valid():
		return source
	return str(_localizer.call(source))


func _apply_button_variant(button: Button, variant: String) -> void:
	var color := UITokensScript.DIALOG_SECONDARY_BUTTON
	var font_color := UITokensScript.INK
	if variant == "primary":
		color = UITokensScript.PRIMARY_BLUE
		font_color = Color.WHITE
	elif variant == "danger":
		color = UITokensScript.DANGER_RED
		font_color = Color.WHITE
	elif variant == "weak":
		color = UITokensScript.SOFT_BLUE
		font_color = UITokensScript.PRIMARY_BLUE
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.04)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.06)))


func _play_open_animation() -> void:
	if not visible:
		return
	_card.pivot_offset = _card.size * 0.5
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_scrim, "modulate:a", 1.0, 0.18)
	_active_tween.tween_property(_card, "modulate:a", 1.0, 0.18)
	_active_tween.tween_property(_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _primary_button:
		_primary_button.grab_focus()


func _activate_action(action_id: String) -> void:
	var dialog_id := current_dialog_id
	hide_dialog(true)
	action_selected.emit(dialog_id, action_id)


func _request_cancel() -> void:
	var dialog_id := current_dialog_id
	hide_dialog()
	cancelled.emit(dialog_id)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_request_cancel()
		get_viewport().set_input_as_handled()


func _dialog_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITokensScript.DIALOG_SURFACE
	style.border_color = UITokensScript.DIALOG_BORDER
	style.set_border_width_all(UITokensScript.DIALOG_BORDER_WIDTH)
	style.set_corner_radius_all(UITokensScript.DIALOG_RADIUS)
	style.shadow_color = UITokensScript.DIALOG_SHADOW_COLOR
	style.shadow_size = UITokensScript.DIALOG_SHADOW_SIZE
	style.shadow_offset = UITokensScript.DIALOG_SHADOW_OFFSET
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(UITokensScript.DIALOG_BUTTON_RADIUS)
	return style
