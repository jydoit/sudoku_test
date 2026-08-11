extends HBoxContainer

const CoinIconResourceScript = preload("res://scripts/components/coin_icon_resource.gd")
const MAX_CONTINUOUS_ROLL_STEPS := 10

var coin_icon: TextureRect
var clip: Control
var primary_label: Label
var secondary_label: Label
var roll_tween: Tween

var _font_size := 24
var _minimum_counter_width := 62.0
var _minimum_counter_height := 44.0
var _minimum_digits := 5
var _horizontal_padding := 6.0
var _vertical_padding := 4.0
var _shadow_offset_y := 2
var _counter_size := Vector2(62, 44)
var _geometry_digit_count := 0
var _displayed_value := 0
var _primary_active := true
var _queued_steps: Array[Dictionary] = []
var _step_animation_active := false
var _active_step_target := 0


func configure(options: Dictionary = {}) -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", int(options.get("separation", 5)))
	_font_size = int(options.get("font_size", 24))
	_minimum_counter_width = float(options.get("minimum_counter_width", 62.0))
	_minimum_counter_height = float(options.get("minimum_counter_height", 44.0))
	_minimum_digits = maxi(1, int(options.get("minimum_digits", 5)))
	_horizontal_padding = float(options.get("horizontal_padding", 6.0))
	_vertical_padding = float(options.get("vertical_padding", 4.0))
	_shadow_offset_y = int(options.get("shadow_offset_y", 2))

	coin_icon = TextureRect.new()
	coin_icon.name = "CoinIcon"
	coin_icon.texture = options.get("icon", CoinIconResourceScript.texture())
	coin_icon.custom_minimum_size = options.get("icon_size", Vector2(30, 30))
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin_icon)

	clip = Control.new()
	clip.name = "CoinRollClip"
	clip.clip_contents = true
	clip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)

	primary_label = _build_label(options)
	primary_label.name = "CoinRollPrimary"
	clip.add_child(primary_label)
	secondary_label = _build_label(options)
	secondary_label.name = "CoinRollSecondary"
	secondary_label.hide()
	clip.add_child(secondary_label)

	set_value(int(options.get("initial_value", 0)))


func set_value(value: int) -> void:
	stop_animation(false)
	_displayed_value = maxi(0, value)
	_primary_active = true
	_refresh_geometry(_displayed_value, _displayed_value)
	_normalize_to_primary()


func animate_to(value: int, total_duration: float) -> void:
	var target := maxi(0, value)
	stop_animation(true)
	_refresh_geometry(_displayed_value, target)
	if target == _displayed_value:
		set_value(target)
		return
	var start_value := _displayed_value
	var direction := 1 if target > start_value else -1
	var step_count := absi(target - start_value)
	var visual_step_count := mini(step_count, MAX_CONTINUOUS_ROLL_STEPS)
	var step_duration := maxf(0.01, total_duration / float(visual_step_count))
	var starts_with_primary := _primary_active
	roll_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	for step_index in range(visual_step_count):
		var outgoing := primary_label if (step_index % 2 == 0) == starts_with_primary else secondary_label
		var incoming := secondary_label if outgoing == primary_label else primary_label
		var progress := float(step_index + 1) / float(visual_step_count)
		var next_value := roundi(lerpf(float(start_value), float(target), progress))
		roll_tween.tween_callback(_prepare_roll_step.bind(outgoing, incoming, next_value, direction))
		roll_tween.tween_property(outgoing, "position:y", -float(direction) * _counter_size.y, step_duration)
		roll_tween.parallel().tween_property(incoming, "position:y", 0.0, step_duration)
		roll_tween.tween_callback(_finish_roll_step.bind(incoming, next_value))
	roll_tween.tween_callback(_finish_animation.bind(target))


func roll_step_to(value: int, duration: float) -> void:
	var target := maxi(0, value)
	_refresh_geometry(_displayed_value, target)
	var latest_target := _active_step_target if _step_animation_active else _displayed_value
	if not _queued_steps.is_empty():
		latest_target = int(_queued_steps.back().get("value", latest_target))
	if target == latest_target:
		return
	_queued_steps.append({"value": target, "duration": maxf(0.01, duration)})
	if not _step_animation_active:
		_start_next_queued_step()


func _start_next_queued_step() -> void:
	if _queued_steps.is_empty():
		_step_animation_active = false
		roll_tween = null
		return
	var step: Dictionary = _queued_steps.pop_front()
	var target := maxi(0, int(step.get("value", _displayed_value)))
	var duration := maxf(0.01, float(step.get("duration", 0.18)))
	if target == _displayed_value:
		_start_next_queued_step()
		return
	_step_animation_active = true
	_active_step_target = target
	var direction := 1 if target > _displayed_value else -1
	var outgoing := primary_label if _primary_active else secondary_label
	var incoming := secondary_label if _primary_active else primary_label
	_prepare_roll_step(outgoing, incoming, target, direction)
	roll_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	roll_tween.tween_property(outgoing, "position:y", -float(direction) * _counter_size.y, duration)
	roll_tween.parallel().tween_property(incoming, "position:y", 0.0, duration)
	roll_tween.tween_callback(_finish_queued_step.bind(incoming, target))


func stop_animation(reset_position: bool = true) -> void:
	if roll_tween and roll_tween.is_valid():
		roll_tween.kill()
	roll_tween = null
	_queued_steps.clear()
	_step_animation_active = false
	_active_step_target = _displayed_value
	if reset_position and primary_label and secondary_label:
		_normalize_to_primary()


func counter_height() -> float:
	return _counter_size.y


func counter_width() -> float:
	return _counter_size.x


func displayed_value() -> int:
	return _displayed_value


func queued_step_count() -> int:
	return _queued_steps.size() + int(_step_animation_active)


func labels_fit_clip() -> bool:
	if not clip or not primary_label or not secondary_label:
		return false
	return (
		primary_label.size.x <= clip.size.x + 0.5
		and primary_label.size.y <= clip.size.y + 0.5
		and secondary_label.size.x <= clip.size.x + 0.5
		and secondary_label.size.y <= clip.size.y + 0.5
	)


func _build_label(options: Dictionary) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", options.get("font_color", Color("#C98212")))
	label.add_theme_color_override("font_shadow_color", options.get("shadow_color", Color(0.44, 0.28, 0.05, 0.16)))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", _shadow_offset_y)
	label.add_theme_font_size_override("font_size", _font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh_geometry(first_value: int, second_value: int) -> void:
	var first_text := str(maxi(0, first_value))
	var second_text := str(maxi(0, second_value))
	var digit_count := maxi(_minimum_digits, maxi(first_text.length(), second_text.length()))
	if digit_count == _geometry_digit_count:
		return
	var sample := ""
	for _index in range(digit_count):
		sample += "8"
	var font := primary_label.get_theme_font("font")
	var measured_width := font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size).x
	var measured_height := font.get_height(_font_size)
	_counter_size = Vector2(
		ceilf(maxf(_minimum_counter_width, measured_width + _horizontal_padding * 2.0)),
		ceilf(maxf(_minimum_counter_height, measured_height + _vertical_padding * 2.0 + absf(float(_shadow_offset_y))))
	)
	_geometry_digit_count = digit_count
	clip.custom_minimum_size = _counter_size
	clip.size = _counter_size
	custom_minimum_size.y = maxf(coin_icon.custom_minimum_size.y, _counter_size.y)
	for label in [primary_label, secondary_label]:
		label.size = _counter_size
		label.custom_minimum_size = _counter_size


func _prepare_label(label: Label, value: int, y_position: float) -> void:
	label.text = str(maxi(0, value))
	label.position = Vector2(0, y_position)
	label.size = _counter_size
	label.scale = Vector2.ONE


func _prepare_roll_step(outgoing: Label, incoming: Label, value: int, direction: int) -> void:
	_prepare_label(outgoing, _displayed_value, 0.0)
	_prepare_label(incoming, value, float(direction) * _counter_size.y)
	outgoing.show()
	incoming.show()


func _finish_roll_step(incoming: Label, value: int) -> void:
	_displayed_value = maxi(0, value)
	_primary_active = incoming == primary_label


func _finish_queued_step(incoming: Label, value: int) -> void:
	_finish_roll_step(incoming, value)
	_normalize_to_primary()
	roll_tween = null
	_step_animation_active = false
	_start_next_queued_step()


func _finish_animation(value: int) -> void:
	_displayed_value = maxi(0, value)
	_normalize_to_primary()
	roll_tween = null


func _normalize_to_primary() -> void:
	_primary_active = true
	_prepare_label(primary_label, _displayed_value, 0.0)
	primary_label.show()
	_prepare_label(secondary_label, _displayed_value, 0.0)
	secondary_label.hide()
