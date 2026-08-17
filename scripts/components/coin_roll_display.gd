extends HBoxContainer

signal roll_finished(value: int)
signal reel_notch(value: int, step_index: int, step_count: int)

const CoinIconResourceScript = preload("res://scripts/components/coin_icon_resource.gd")
const MAX_CONTINUOUS_ROLL_STEPS := 10

var coin_icon: TextureRect
var content_gap_spacer: Control
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
var _dynamic_digit_sizing := false
var _digit_profiles: Dictionary = {}
var _overflow_font_size := 23
var _content_gap := 0.0
var _displayed_value := 0
var _primary_active := true
var _queued_steps: Array[Dictionary] = []
var _step_animation_active := false
var _active_step_target := 0


func configure(options: Dictionary = {}) -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	alignment = BoxContainer.ALIGNMENT_CENTER
	_content_gap = maxf(0.0, float(options.get("content_gap", 0.0)))
	add_theme_constant_override("separation", 0 if _content_gap > 0.0 else int(options.get("separation", 5)))
	_font_size = int(options.get("font_size", 24))
	_minimum_counter_width = float(options.get("minimum_counter_width", 62.0))
	_minimum_counter_height = float(options.get("minimum_counter_height", 44.0))
	_minimum_digits = maxi(1, int(options.get("minimum_digits", 5)))
	_horizontal_padding = float(options.get("horizontal_padding", 6.0))
	_vertical_padding = float(options.get("vertical_padding", 4.0))
	_shadow_offset_y = int(options.get("shadow_offset_y", 2))
	_dynamic_digit_sizing = bool(options.get("dynamic_digit_sizing", false))
	_digit_profiles = options.get("digit_profiles", {}).duplicate()
	_overflow_font_size = int(options.get("overflow_font_size", _font_size))

	coin_icon = TextureRect.new()
	coin_icon.name = "CoinIcon"
	coin_icon.texture = options.get("icon", CoinIconResourceScript.texture())
	coin_icon.custom_minimum_size = options.get("icon_size", Vector2(30, 30))
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin_icon)

	if _content_gap > 0.0:
		content_gap_spacer = Control.new()
		content_gap_spacer.name = "CoinNumberGap"
		content_gap_spacer.custom_minimum_size.x = _content_gap
		content_gap_spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content_gap_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(content_gap_spacer)

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
		roll_finished.emit(target)
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


func animate_reel_to(value: int, total_duration: float, max_visual_steps: int = 5) -> void:
	var target := maxi(0, value)
	stop_animation(true)
	_refresh_geometry(_displayed_value, target)
	if target == _displayed_value:
		set_value(target)
		roll_finished.emit(target)
		return
	var start_value := _displayed_value
	var direction := 1 if target > start_value else -1
	var value_distance := absi(target - start_value)
	var visual_step_limit := maxi(1, max_visual_steps)
	var visual_step_count := mini(value_distance, visual_step_limit)
	if value_distance >= 4:
		visual_step_count = mini(visual_step_count, maxi(3, ceili(sqrt(float(value_distance)))))
	var values: Array[int] = []
	var previous_value := start_value
	for step_index in range(visual_step_count):
		var remaining_steps := visual_step_count - step_index - 1
		var progress := float(step_index + 1) / float(visual_step_count)
		var eased_progress := 1.0 - pow(1.0 - progress, 2.0)
		var next_value := roundi(lerpf(float(start_value), float(target), eased_progress))
		if direction > 0:
			next_value = clampi(next_value, previous_value + 1, target - remaining_steps)
		else:
			next_value = clampi(next_value, target + remaining_steps, previous_value - 1)
		values.append(next_value)
		previous_value = next_value
	values[values.size() - 1] = target

	var duration_weights: Array[float] = []
	var total_weight := 0.0
	for step_index in range(visual_step_count):
		var progress := float(step_index + 1) / float(visual_step_count)
		var weight := lerpf(0.55, 1.85, pow(progress, 1.35))
		duration_weights.append(weight)
		total_weight += weight

	var starts_with_primary := _primary_active
	roll_tween = create_tween()
	for step_index in range(visual_step_count):
		var outgoing := primary_label if (step_index % 2 == 0) == starts_with_primary else secondary_label
		var incoming := secondary_label if outgoing == primary_label else primary_label
		var next_value: int = values[step_index]
		var step_duration := maxf(0.01, total_duration * duration_weights[step_index] / total_weight)
		roll_tween.tween_callback(_prepare_roll_step.bind(outgoing, incoming, next_value, direction))
		var outgoing_roll := roll_tween.tween_property(
			outgoing,
			"position:y",
			-float(direction) * _counter_size.y,
			step_duration
		)
		var incoming_roll := roll_tween.parallel().tween_property(incoming, "position:y", 0.0, step_duration)
		if step_index == visual_step_count - 1:
			outgoing_roll.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			incoming_roll.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			outgoing_roll.set_trans(Tween.TRANS_LINEAR)
			incoming_roll.set_trans(Tween.TRANS_LINEAR)
		roll_tween.tween_callback(
			_finish_reel_step.bind(incoming, next_value, step_index, visual_step_count)
		)
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


func active_font_size() -> int:
	return _font_size


func active_digit_count() -> int:
	return _geometry_digit_count


func configured_content_gap() -> float:
	return _content_gap


func visual_gap_from_icon_to_number() -> float:
	if not coin_icon or not clip:
		return 0.0
	return clip.position.x + _horizontal_padding - coin_icon.position.x - coin_icon.size.x


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
	label.horizontal_alignment = int(options.get("number_alignment", HORIZONTAL_ALIGNMENT_CENTER)) as HorizontalAlignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font_color: Color = options.get("font_color", Color("#C98212"))
	label.add_theme_color_override("font_color", font_color)
	var outline_size := maxi(0, int(options.get("outline_size", 0)))
	if outline_size > 0:
		label.add_theme_color_override("font_outline_color", options.get("outline_color", font_color))
		label.add_theme_constant_override("outline_size", outline_size)
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
	var profile := _profile_for_digit_count(digit_count)
	var profile_font_size := int(profile.get("font_size", _font_size))
	var profile_minimum_width := float(profile.get("minimum_width", _minimum_counter_width))
	if digit_count == _geometry_digit_count and profile_font_size == _font_size:
		return
	_font_size = profile_font_size
	for label in [primary_label, secondary_label]:
		label.add_theme_font_size_override("font_size", _font_size)
	var sample := ""
	for _index in range(digit_count):
		sample += "8"
	var font := primary_label.get_theme_font("font")
	var measured_width := font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size).x
	var measured_height := font.get_height(_font_size)
	_counter_size = Vector2(
		ceilf(maxf(profile_minimum_width, measured_width + _horizontal_padding * 2.0)),
		ceilf(maxf(_minimum_counter_height, measured_height + _vertical_padding * 2.0 + absf(float(_shadow_offset_y))))
	)
	_geometry_digit_count = digit_count
	clip.custom_minimum_size = _counter_size
	clip.size = _counter_size
	custom_minimum_size.y = maxf(coin_icon.custom_minimum_size.y, _counter_size.y)
	for label in [primary_label, secondary_label]:
		label.size = _counter_size
		label.custom_minimum_size = _counter_size


func _profile_for_digit_count(digit_count: int) -> Dictionary:
	if not _dynamic_digit_sizing:
		return {"font_size": _font_size, "minimum_width": _minimum_counter_width}
	if _digit_profiles.has(digit_count):
		var configured_profile = _digit_profiles[digit_count]
		if configured_profile is Dictionary:
			return configured_profile
	var fallback_width := _minimum_counter_width
	if not _digit_profiles.is_empty():
		var largest_profile_digits := 0
		for raw_digits in _digit_profiles.keys():
			largest_profile_digits = maxi(largest_profile_digits, int(raw_digits))
		var largest_profile = _digit_profiles.get(largest_profile_digits, {})
		if largest_profile is Dictionary:
			fallback_width = float(largest_profile.get("minimum_width", fallback_width))
	return {"font_size": _overflow_font_size, "minimum_width": fallback_width}


func _prepare_label(label: Label, value: int, y_position: float) -> void:
	label.text = str(maxi(0, value))
	label.position = Vector2(_horizontal_padding, y_position)
	label.size = Vector2(maxf(1.0, _counter_size.x - _horizontal_padding * 2.0), _counter_size.y)
	label.scale = Vector2.ONE


func _prepare_roll_step(outgoing: Label, incoming: Label, value: int, direction: int) -> void:
	_prepare_label(outgoing, _displayed_value, 0.0)
	_prepare_label(incoming, value, float(direction) * _counter_size.y)
	outgoing.show()
	incoming.show()


func _finish_roll_step(incoming: Label, value: int) -> void:
	_displayed_value = maxi(0, value)
	_primary_active = incoming == primary_label


func _finish_reel_step(incoming: Label, value: int, step_index: int, step_count: int) -> void:
	_finish_roll_step(incoming, value)
	reel_notch.emit(_displayed_value, step_index, step_count)


func _finish_queued_step(incoming: Label, value: int) -> void:
	_finish_roll_step(incoming, value)
	_normalize_to_primary()
	roll_tween = null
	_step_animation_active = false
	_start_next_queued_step()


func _finish_animation(value: int) -> void:
	_displayed_value = maxi(0, value)
	# The reel keeps the larger of the start/end layouts while moving. Only
	# after it stops do we shrink to the final balance profile.
	_refresh_geometry(_displayed_value, _displayed_value)
	_normalize_to_primary()
	roll_tween = null
	roll_finished.emit(_displayed_value)


func _normalize_to_primary() -> void:
	_primary_active = true
	_prepare_label(primary_label, _displayed_value, 0.0)
	primary_label.show()
	_prepare_label(secondary_label, _displayed_value, 0.0)
	secondary_label.hide()
