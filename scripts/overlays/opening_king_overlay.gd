extends ColorRect

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const LION_KING_ICON = preload("res://assets/ui/lion_king.svg")

var panel: PanelContainer
var title_label: Label
var count_label: Label
var source_row: HBoxContainer
var source_count_label: Label

var _control_localizer: Callable
var _animation_tween: Tween
var _flyers: Array[TextureRect] = []
var _animation_token := 0


func configure(control_localizer: Callable = Callable()) -> void:
	_control_localizer = control_localizer
	color = UITokensScript.OPENING_OVERLAY_SCRIM
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 9
	_build_card()
	hide()


func play(cells: Array, total_count: int, base_progress: int, board, progress_bar: ProgressBar, progress_label: Label) -> bool:
	if cells.is_empty() or not board:
		return false
	_animation_token += 1
	var token := _animation_token
	_set_control_text(title_label, "本关需要找到 %d 个皇冠", [total_count])
	_set_control_text(count_label, "开局提供 %d 个提示皇冠", [cells.size()])
	source_count_label.text = "×%d" % cells.size()
	if progress_bar:
		progress_bar.value = base_progress
	if progress_label:
		progress_label.text = "%d / %d" % [base_progress, total_count]

	modulate.a = 0.0
	show()
	_animation_tween = create_tween()
	_animation_tween.tween_property(self, "modulate:a", 1.0, 0.20)
	await _animation_tween.finished
	if token != _animation_token:
		return false
	await get_tree().create_timer(0.65).timeout

	for index in range(cells.size()):
		if token != _animation_token or not board.is_visible_in_tree():
			return false
		var cell: Vector2i = cells[index]
		var flyer := _piece_texture_rect(Vector2(64, 64))
		flyer.size = Vector2(64, 64)
		flyer.pivot_offset = flyer.size * 0.5
		flyer.z_index = 2
		add_child(flyer)
		_flyers.append(flyer)
		var source_center := source_row.get_global_rect().get_center()
		var target_center: Vector2 = board.cell_global_center(cell.y, cell.x)
		flyer.global_position = source_center - flyer.size * 0.5
		flyer.scale = Vector2.ONE
		_animation_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_animation_tween.set_parallel(true)
		_animation_tween.tween_property(flyer, "global_position", target_center - flyer.size * 0.5, 0.58)
		_animation_tween.tween_property(flyer, "scale", Vector2(0.72, 0.72), 0.58)
		await _animation_tween.finished
		if token != _animation_token:
			return false
		board.reveal_king_cell(cell)
		if progress_bar:
			progress_bar.value = base_progress + index + 1
		if progress_label:
			progress_label.text = "%d / %d" % [base_progress + index + 1, total_count]
		_flyers.erase(flyer)
		flyer.queue_free()
		await get_tree().create_timer(0.12).timeout

	await get_tree().create_timer(0.28).timeout
	if token != _animation_token:
		return false
	_animation_tween = create_tween()
	_animation_tween.tween_property(self, "modulate:a", 0.0, 0.24)
	await _animation_tween.finished
	if token != _animation_token:
		return false
	hide()
	modulate.a = 1.0
	return true


func cancel() -> void:
	_animation_token += 1
	if _animation_tween and _animation_tween.is_valid():
		_animation_tween.kill()
	for flyer in _flyers:
		if is_instance_valid(flyer):
			flyer.queue_free()
	_flyers.clear()
	hide()
	modulate.a = 1.0


func _build_card() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-180, 112)
	panel.size = Vector2(360, 190)
	panel.custom_minimum_size = Vector2(360, 190)
	panel.add_theme_stylebox_override("panel", _card_style(UITokensScript.OPENING_OVERLAY_CARD, 24, true, 22))
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", UITokensScript.INK)
	title_label.add_theme_font_size_override("font_size", 24)
	column.add_child(title_label)
	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", UITokensScript.MUTED)
	count_label.add_theme_font_size_override("font_size", 17)
	column.add_child(count_label)
	source_row = HBoxContainer.new()
	source_row.custom_minimum_size.y = 64
	source_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_row.alignment = BoxContainer.ALIGNMENT_CENTER
	source_row.add_theme_constant_override("separation", 6)
	source_row.add_child(_piece_texture_rect(Vector2(58, 58)))
	source_count_label = Label.new()
	source_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source_count_label.add_theme_color_override("font_color", UITokensScript.INK)
	source_count_label.add_theme_font_size_override("font_size", 28)
	source_row.add_child(source_count_label)
	column.add_child(source_row)


func _piece_texture_rect(minimum_size: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = LION_KING_ICON
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _set_control_text(control: Control, source: String, values: Array = []) -> void:
	if _control_localizer.is_valid():
		_control_localizer.call(control, source, values)
	elif control is Label:
		control.text = source % values if not values.is_empty() else source


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
