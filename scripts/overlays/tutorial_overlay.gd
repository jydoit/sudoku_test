extends Control

const HAND_POINTER_TEXTURE: Texture2D = preload("res://assets/ui/hand_pointer.svg")

var center_popup: Label
var hand_label: TextureRect

var _board
var _hand_cell := Vector2i(-1, -1)
var _hand_control: Control
var _hand_action := "single"
var _slide_end_cell := Vector2i(-1, -1)
var _guide_feedback: Callable
var _hand_token := 0
var _hand_tween: Tween
var _center_tween: Tween

var focused_control: Control:
	get: return _hand_control


func configure() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 21
	_build_center_popup()
	_build_hand_pointer()


func set_board(board) -> void:
	_board = board
	if _board and not _board.resized.is_connected(_on_board_resized):
		_board.resized.connect(_on_board_resized)


func show_message(message: String) -> void:
	center_popup.text = message
	if _center_tween and _center_tween.is_valid():
		_center_tween.kill()
	center_popup.modulate.a = 0.0
	_center_tween = create_tween()
	_center_tween.tween_property(center_popup, "modulate:a", 1.0, 0.14)
	_center_tween.tween_interval(1.45)
	_center_tween.tween_property(center_popup, "modulate:a", 0.0, 0.28)


func show_for_cell(cell: Vector2i, action: String, slide_end_cell: Vector2i, guide_feedback: Callable = Callable()) -> void:
	if not _board or cell.x < 0 or cell.y < 0:
		return
	_hand_cell = cell
	_hand_control = null
	_hand_action = action
	_slide_end_cell = slide_end_cell
	_guide_feedback = guide_feedback
	_reposition_hand()
	hand_label.show()
	hand_label.modulate.a = 1.0
	hand_label.scale = Vector2.ONE
	_stop_hand_tween()
	_hand_token += 1
	_loop_cell_demo(_hand_token)


func show_for_control(control: Control) -> void:
	if not control:
		return
	_hand_cell = Vector2i(-1, -1)
	_hand_control = control
	_hand_action = "single"
	_slide_end_cell = Vector2i(-1, -1)
	_guide_feedback = Callable()
	_reposition_hand()
	hand_label.show()
	hand_label.modulate.a = 1.0
	hand_label.scale = Vector2.ONE
	_stop_hand_tween()
	_hand_token += 1
	_loop_control_demo(control, _hand_token)


func hide_pointer() -> void:
	_hand_token += 1
	_hand_cell = Vector2i(-1, -1)
	_hand_control = null
	_guide_feedback = Callable()
	_stop_hand_tween()
	if hand_label:
		hand_label.hide()
		hand_label.scale = Vector2.ONE


func reposition() -> void:
	_reposition_hand()


func _build_center_popup() -> void:
	center_popup = Label.new()
	center_popup.set_anchors_preset(Control.PRESET_CENTER)
	center_popup.position = Vector2(-210, -44)
	center_popup.size = Vector2(420, 88)
	center_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_popup.add_theme_color_override("font_color", Color.WHITE)
	center_popup.add_theme_font_size_override("font_size", 22)
	center_popup.add_theme_stylebox_override("normal", _card_style(Color("#2F3B50"), 18, true, 18))
	center_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_popup.modulate.a = 0.0
	add_child(center_popup)


func _build_hand_pointer() -> void:
	hand_label = TextureRect.new()
	hand_label.name = "TutorialHandPointer"
	hand_label.texture = HAND_POINTER_TEXTURE
	hand_label.size = Vector2(96, 96)
	hand_label.pivot_offset = Vector2(48, 48)
	hand_label.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand_label.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_label.z_index = 1
	hand_label.hide()
	add_child(hand_label)


func _loop_cell_demo(token: int) -> void:
	while token == _hand_token and hand_label and hand_label.visible:
		if _guide_feedback.is_valid():
			_guide_feedback.call()
		if _hand_action == "slide":
			await _animate_slide(token)
		elif _hand_action == "double":
			await _animate_taps(2, token)
		else:
			await _animate_taps(1, token)
		await get_tree().create_timer(1.5).timeout


func _loop_control_demo(control: Control, token: int) -> void:
	while token == _hand_token and hand_label and hand_label.visible and control and control.visible:
		_reposition_hand()
		await _animate_taps(1, token)
		await get_tree().create_timer(1.5).timeout


func _animate_taps(count: int, token: int) -> void:
	for index in range(count):
		if token != _hand_token or not hand_label or not hand_label.visible:
			return
		var base_position := _hand_anchor_position()
		hand_label.global_position = base_position
		hand_label.scale = Vector2.ONE
		_hand_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hand_tween.parallel().tween_property(hand_label, "scale", Vector2(0.84, 0.84), 0.13)
		_hand_tween.parallel().tween_property(hand_label, "global_position", base_position + Vector2(0, 8), 0.13)
		_hand_tween.tween_property(hand_label, "scale", Vector2(1.10, 1.10), 0.16)
		_hand_tween.parallel().tween_property(hand_label, "global_position", base_position, 0.16)
		_hand_tween.tween_property(hand_label, "scale", Vector2.ONE, 0.12)
		await _hand_tween.finished
		if token == _hand_token and hand_label and hand_label.visible:
			hand_label.global_position = base_position
			hand_label.scale = Vector2.ONE
		if index < count - 1:
			await get_tree().create_timer(0.20).timeout


func _animate_slide(token: int) -> void:
	var end_cell := _slide_end_cell if _slide_end_cell.x >= 0 else _hand_cell
	var start_position := _hand_position_for_cell(_hand_cell)
	var end_position := _hand_position_for_cell(end_cell)
	hand_label.global_position = start_position
	hand_label.scale = Vector2.ONE
	_hand_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hand_tween.tween_property(hand_label, "scale", Vector2(0.94, 0.94), 0.18)
	_hand_tween.tween_property(hand_label, "global_position", end_position, 0.92)
	_hand_tween.parallel().tween_property(hand_label, "scale", Vector2(1.07, 1.07), 0.92)
	_hand_tween.tween_property(hand_label, "scale", Vector2.ONE, 0.18)
	await _hand_tween.finished
	if token == _hand_token and hand_label and hand_label.visible:
		hand_label.global_position = start_position


func _reposition_hand() -> void:
	if not hand_label:
		return
	if _hand_control and _hand_control.is_inside_tree():
		var rect := _hand_control.get_global_rect()
		var target_point := rect.position + Vector2(rect.size.x * 0.76, rect.size.y * 0.55)
		hand_label.global_position = target_point - Vector2(46, 18)
		return
	if _hand_cell.x >= 0 and _hand_cell.y >= 0 and _board:
		hand_label.global_position = _hand_position_for_cell(_hand_cell)


func _hand_position_for_cell(cell: Vector2i) -> Vector2:
	var geometry: Dictionary = _board._board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cell_size"]
	var target_point: Vector2 = _board.global_position + board_rect.position + Vector2(cell.x + 0.75, cell.y + 0.75) * cell_size
	return target_point - Vector2(48, 22)


func _hand_anchor_position() -> Vector2:
	if _hand_control and _hand_control.is_inside_tree():
		var rect := _hand_control.get_global_rect()
		var target_point := rect.position + Vector2(rect.size.x * 0.76, rect.size.y * 0.55)
		return target_point - Vector2(46, 18)
	if _hand_cell.x >= 0 and _hand_cell.y >= 0:
		return _hand_position_for_cell(_hand_cell)
	return hand_label.global_position


func _stop_hand_tween() -> void:
	if _hand_tween and _hand_tween.is_valid():
		_hand_tween.kill()


func _on_board_resized() -> void:
	if hand_label and hand_label.visible:
		_reposition_hand()


func _card_style(color_value: Color, radius: int, shadow: bool, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color_value
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	if shadow:
		style.shadow_color = Color(0.16, 0.23, 0.34, 0.18)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 4)
	return style
