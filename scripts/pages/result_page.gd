extends ColorRect

signal primary_requested
signal secondary_requested

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const CoinRollDisplayScript = preload("res://scripts/components/coin_roll_display.gd")
const CoinIconResourceScript = preload("res://scripts/components/coin_icon_resource.gd")
const LION_KING_VICTORY_ICON = preload("res://assets/ui/lion_king_victory.png")
const LION_KING_VICTORY_OUT_ICON = preload("res://assets/ui/lion_king_victory_out.png")
const LION_KING_VICTORY_IN_ICON = preload("res://assets/ui/lion_king_victory_in.png")
const LION_KING_VICTORY_WAVE_OUT_MID_ICON = preload("res://assets/ui/lion_king_victory_wave_out_mid.png")
const LION_KING_VICTORY_WAVE_IN_MID_ICON = preload("res://assets/ui/lion_king_victory_wave_in_mid.png")
const LION_KING_VICTORY_TONGUE_PEEK_ICON = preload("res://assets/ui/lion_king_victory_tongue_peek.png")
const LION_KING_VICTORY_TONGUE_OUT_ICON = preload("res://assets/ui/lion_king_victory_tongue_out.png")
const LION_KING_VICTORY_WINK_ICON = preload("res://assets/ui/lion_king_victory_wink.png")
const LION_KING_VICTORY_FUNNY_ICON = preload("res://assets/ui/lion_king_victory_funny.png")
const CARD := UITokensScript.SURFACE_CARD
const INK := UITokensScript.INK
const RESULT_COIN_START_DELAY := 0.45
const RESULT_COIN_MIN_DURATION := 2.15
const RESULT_COIN_MAX_DURATION := 3.30
const RESULT_COIN_FLIGHT_DURATION := 0.72
const RESULT_COIN_FLIGHT_MIN_STAGGER := 0.08
const RESULT_COIN_FLIGHT_MAX_STAGGER := 0.16
const RESULT_COIN_REEL_DURATION := 1.00
const RESULT_COIN_REEL_SETTLE_HOLD := 0.08
const RESULT_COIN_FLYER_SIZE := Vector2(29, 29)

var completion_overlay: ColorRect
var completion_title: Label
var reward_label: Label
var result_icon_label: Label
var result_piece_icon: TextureRect
var result_reward_label: Label
var result_coin_roll_row: HBoxContainer
var result_coin_roll_display: HBoxContainer
var result_reward_coin_icon: TextureRect
var result_coin_roll_clip: Control
var result_coin_roll_primary: Label
var result_coin_roll_secondary: Label
var result_coin_flight_layer: Control
var result_tip_label: Label
var result_petals_layer: Control
var completion_next_button: Button
var completion_replay_button: Button
var overlay_mode := "success"
var result_coin_pulse_tween: Tween
var result_lion_tween: Tween
var result_lion_wave_tween: Tween
var result_coin_tween: Tween
var result_coin_flight_tweens: Array[Tween] = []
var result_petal_tweens: Array[Tween] = []
var result_lion_animation_name := ""
var _localizer: Callable

func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	completion_overlay = self
	completion_overlay.color = Color("#DDF5FF")
	completion_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	completion_overlay.z_index = 10
	completion_overlay.hide()

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

	result_petals_layer = Control.new()
	result_petals_layer.name = "ResultPetalsLayer"
	result_petals_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_petals_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_petals_layer.hide()
	completion_overlay.add_child(result_petals_layer)

	result_coin_flight_layer = Control.new()
	result_coin_flight_layer.name = "ResultCoinFlightLayer"
	result_coin_flight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_coin_flight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_coin_flight_layer.z_index = 30
	completion_overlay.add_child(result_coin_flight_layer)

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 30)
	safe_area.add_theme_constant_override("margin_right", 30)
	safe_area.add_theme_constant_override("margin_top", 56)
	safe_area.add_theme_constant_override("margin_bottom", 24)
	completion_overlay.add_child(safe_area)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = 0
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	safe_area.add_child(column)

	completion_title = Label.new()
	completion_title.text = "太棒了！"
	completion_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_title.add_theme_color_override("font_color", Color("#FFE06F"))
	completion_title.add_theme_color_override("font_shadow_color", Color(0.10, 0.23, 0.45, 0.30))
	completion_title.add_theme_constant_override("shadow_offset_x", 0)
	completion_title.add_theme_constant_override("shadow_offset_y", 4)
	completion_title.add_theme_font_size_override("font_size", 44)
	completion_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	completion_title.custom_minimum_size.x = 0
	completion_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(completion_title)

	reward_label = Label.new()
	reward_label.text = "第 1 关 已完成"
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_color_override("font_color", Color.WHITE)
	reward_label.add_theme_color_override("font_shadow_color", Color(0.10, 0.23, 0.45, 0.26))
	reward_label.add_theme_constant_override("shadow_offset_x", 0)
	reward_label.add_theme_constant_override("shadow_offset_y", 3)
	reward_label.add_theme_font_size_override("font_size", 23)
	reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_label.custom_minimum_size.x = 0
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reward_label)

	var showcase := PanelContainer.new()
	showcase.custom_minimum_size = Vector2(0, 210)
	showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.add_theme_stylebox_override("panel", _card_style(CARD, 32, true, 18))
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
	result_icon_label.add_theme_font_size_override("font_size", 84)
	result_icon_label.hide()
	showcase_column.add_child(result_icon_label)

	result_reward_label = Label.new()
	result_reward_label.text = ""
	result_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_reward_label.add_theme_color_override("font_color", Color("#2F73D9"))
	result_reward_label.add_theme_font_size_override("font_size", 20)
	result_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_reward_label.custom_minimum_size.x = 0
	result_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_reward_label.hide()
	showcase_column.add_child(result_reward_label)

	result_coin_roll_display = CoinRollDisplayScript.new()
	result_coin_roll_display.name = "ResultCoinRoll"
	result_coin_roll_display.configure({
		"initial_value": 0,
		"font_size": 32,
		"minimum_counter_width": 104.0,
		"minimum_counter_height": 52.0,
		"minimum_digits": 5,
		"horizontal_padding": 4.0,
		"vertical_padding": 4.0,
		"icon_size": Vector2(44, 44),
		"separation": 3,
		"font_color": Color("#D88916"),
		"number_alignment": HORIZONTAL_ALIGNMENT_LEFT,
		"outline_size": 1,
		"outline_color": Color("#D88916"),
		"shadow_offset_y": 2,
	})
	result_coin_roll_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_coin_roll_display.hide()
	showcase_column.add_child(result_coin_roll_display)
	# Keep the established page API while both locations share one display component.
	result_coin_roll_row = result_coin_roll_display
	result_reward_coin_icon = result_coin_roll_display.coin_icon
	result_reward_coin_icon.name = "ResultRewardCoinIcon"
	result_coin_roll_clip = result_coin_roll_display.clip
	result_coin_roll_primary = result_coin_roll_display.primary_label
	result_coin_roll_secondary = result_coin_roll_display.secondary_label

	result_tip_label = Label.new()
	result_tip_label.text = "继续前进，收集更多皇冠"
	result_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_tip_label.add_theme_color_override("font_color", Color("#6A82A6"))
	result_tip_label.add_theme_font_size_override("font_size", 16)
	result_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_tip_label.custom_minimum_size.x = 0
	result_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	showcase_column.add_child(result_tip_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	column.add_child(spacer)

	completion_next_button = _action_button("下一关", Color("#3E8DFF"))
	completion_next_button.custom_minimum_size.y = 58
	completion_next_button.add_theme_color_override("font_color", Color.WHITE)
	completion_next_button.add_theme_font_size_override("font_size", 24)
	completion_next_button.pressed.connect(func() -> void: primary_requested.emit())
	column.add_child(completion_next_button)

	completion_replay_button = _action_button("主菜单", CARD)
	completion_replay_button.custom_minimum_size.y = 54
	completion_replay_button.add_theme_color_override("font_color", Color("#287BFF"))
	completion_replay_button.add_theme_font_size_override("font_size", 22)
	completion_replay_button.pressed.connect(func() -> void: secondary_requested.emit())
	column.add_child(completion_replay_button)


func present_success(data: Dictionary) -> void:
	overlay_mode = "success"
	var excellent := bool(data.get("excellent", false))
	var composite := bool(data.get("composite", false))
	var reward := maxi(0, int(data.get("reward", 0)))
	completion_title.text = _t("EXCELLENT") if excellent else _t("GOOD")
	reward_label.text = (
		_t("拼块挑战 · 第 %d 局完成", [maxi(1, int(data.get("round", 1)))])
		if composite else _t("第 %d 关 已完成", [maxi(1, int(data.get("displayLevel", 1)))])
	)
	result_icon_label.hide()
	result_piece_icon.texture = LION_KING_VICTORY_ICON
	result_piece_icon.show()
	stop_coin_animation()
	result_reward_label.hide()
	result_coin_roll_row.visible = reward > 0
	if composite and reward > 0:
		var entry_cost := int(data.get("entryCost", 0))
		if bool(data.get("paidEntry", false)) and entry_cost > 0:
			result_tip_label.text = _t(
				"入场扣除 %d 金币 · 通关奖励 %d 金币\n本局净增加 %d 金币",
				[entry_cost, reward, reward - entry_cost]
			)
		else:
			result_tip_label.text = _t("本局使用每日免费额度 · 未扣除金币\n通关奖励 %d 金币", [reward])
	else:
		result_tip_label.text = _t("奖励已加入金币余额") if reward > 0 else _t("本关已完成，继续挑战")
	if composite and bool(data.get("nextPaid", false)):
		completion_next_button.text = _t("下一局 -%d", [int(data.get("nextEntryCost", 0))])
	else:
		completion_next_button.text = _t("下一局") if composite else _t("下一关")
	completion_replay_button.text = _t("主菜单")
	completion_replay_button.show()
	stop_petals()
	if excellent:
		call_deferred("play_petals")
	call_deferred("play_lion_animation")
	if reward > 0:
		call_deferred("play_coin_animation", reward, int(data.get("coinBalance", reward)))


func present_failure(data: Dictionary) -> void:
	overlay_mode = "failure"
	stop_all_animations()
	var composite := bool(data.get("composite", false))
	completion_title.text = _t("挑战失败")
	reward_label.text = (
		_t("拼块挑战 · 第 %d 局未完成", [maxi(1, int(data.get("round", 1)))])
		if composite else _t("第 %d 关 未完成", [maxi(1, int(data.get("displayLevel", 1)))])
	)
	result_icon_label.text = "♥"
	result_icon_label.add_theme_color_override("font_color", Color("#F25D72"))
	result_icon_label.add_theme_color_override("font_shadow_color", Color("#B92E4A"))
	result_icon_label.show()
	result_piece_icon.hide()
	result_reward_label.text = _t("红心已用完")
	result_reward_label.show()
	result_coin_roll_row.hide()
	result_tip_label.text = _t("可以重新挑战，或返回首页继续主线") if composite else _t("复活会保留当前棋盘，并恢复 1 颗红心")
	completion_next_button.text = _t("重新挑战") if composite else _t("金币复活  -%d", [int(data.get("revivePrice", 0))])
	completion_replay_button.text = _t("主菜单") if composite else _t("重新挑战")
	completion_replay_button.show()


func present_deadlock(revive_price: int) -> void:
	overlay_mode = "assembly_deadlock"
	stop_all_animations()
	completion_title.text = _t("拼块死局")
	reward_label.text = _t("同色区域已被隔离")
	result_icon_label.text = "!"
	result_icon_label.add_theme_color_override("font_color", Color("#F2A93B"))
	result_icon_label.add_theme_color_override("font_shadow_color", Color("#A86812"))
	result_icon_label.show()
	result_piece_icon.hide()
	result_reward_label.text = _t("当前摆法已经无法完成颜色区域")
	result_reward_label.show()
	result_coin_roll_row.hide()
	result_tip_label.text = _t("金币复活会自动放回最后一个放置的方块")
	completion_next_button.text = _t("金币复活  -%d", [revive_price])
	completion_replay_button.text = _t("重新开始本局")
	completion_replay_button.show()


func present_tutorial_complete(has_saved_progress: bool) -> void:
	overlay_mode = "tutorial"
	stop_all_animations()
	completion_title.text = _t("已经了解全部规则")
	reward_label.text = _t("开始真正的挑战吧！")
	result_icon_label.hide()
	result_piece_icon.texture = LION_KING_VICTORY_ICON
	result_piece_icon.show()
	result_reward_label.text = _t("新手教程完成")
	result_reward_label.show()
	result_coin_roll_row.hide()
	result_tip_label.text = _t("返回进入教程前的关卡现场") if has_saved_progress else _t("进入第 1 关，开始真正的挑战")


func composite_coin_text(reward: int, entry_cost: int, paid_entry: bool) -> String:
	if paid_entry and entry_cost > 0:
		return _t(
			"入场扣除 %d 金币 · 通关奖励 %d 金币\n本局净增加 %d 金币",
			[entry_cost, reward, reward - entry_cost]
		)
	return _t("本局使用每日免费额度 · 未扣除金币\n通关奖励 %d 金币", [reward])


func show_animated() -> void:
	show()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _t(source: String, values: Array = []) -> String:
	if _localizer.is_valid():
		return str(_localizer.call(source, values))
	return source % values if not values.is_empty() else source



func play_coin_animation(reward: int, balance_after: int) -> void:
	if not result_coin_roll_display or reward <= 0 or overlay_mode != "success":
		return
	stop_coin_animation()
	result_coin_roll_display.show()
	balance_after = maxi(0, balance_after)
	var balance_before := maxi(0, balance_after - reward)
	result_coin_roll_display.set_value(balance_before)
	result_reward_coin_icon.scale = Vector2.ONE
	result_reward_coin_icon.pivot_offset = result_reward_coin_icon.size * 0.5
	var source := _control_point_in_flight_layer(
		result_piece_icon,
		Vector2(result_piece_icon.size.x * 0.70, result_piece_icon.size.y * 0.50 + 4.0)
	)
	var target := _control_point_in_flight_layer(
		result_reward_coin_icon,
		result_reward_coin_icon.size * 0.5
	)
	var stagger := RESULT_COIN_FLIGHT_MAX_STAGGER
	if reward > 1:
		stagger = minf(
			RESULT_COIN_FLIGHT_MAX_STAGGER,
			maxf(
				RESULT_COIN_FLIGHT_MIN_STAGGER,
				(
					RESULT_COIN_MAX_DURATION
					- RESULT_COIN_START_DELAY
					- RESULT_COIN_FLIGHT_DURATION
					- RESULT_COIN_REEL_DURATION
					- RESULT_COIN_REEL_SETTLE_HOLD
				) / float(reward - 1)
			)
		)
	var flight_sequence_duration := RESULT_COIN_FLIGHT_DURATION + stagger * float(maxi(0, reward - 1))
	var sequence_duration := RESULT_COIN_START_DELAY + flight_sequence_duration + RESULT_COIN_REEL_DURATION
	var completion_hold := maxf(RESULT_COIN_REEL_SETTLE_HOLD, RESULT_COIN_MIN_DURATION - sequence_duration)
	result_coin_tween = create_tween()
	result_coin_tween.tween_interval(RESULT_COIN_START_DELAY)
	for index in range(reward):
		result_coin_tween.tween_callback(
			_launch_result_coin_flyer.bind(index, reward, balance_after, source, target)
		)
		if index < reward - 1:
			result_coin_tween.tween_interval(stagger)
	result_coin_tween.tween_interval(RESULT_COIN_FLIGHT_DURATION)
	result_coin_tween.tween_interval(RESULT_COIN_REEL_DURATION + completion_hold)
	result_coin_tween.tween_callback(func() -> void:
		result_coin_roll_display.set_value(balance_after)
		result_reward_coin_icon.scale = Vector2.ONE
		_start_random_result_lion_animation()
	)


func _control_point_in_flight_layer(control: Control, local_point: Vector2) -> Vector2:
	if not control or not result_coin_flight_layer:
		return Vector2.ZERO
	var canvas_point := control.get_global_transform_with_canvas() * local_point
	return result_coin_flight_layer.get_global_transform_with_canvas().affine_inverse() * canvas_point


func _launch_result_coin_flyer(index: int, reward: int, balance_after: int, source: Vector2, target: Vector2) -> void:
	if not result_coin_flight_layer or not self.visible or overlay_mode != "success":
		return
	var flyer := TextureRect.new()
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.texture = CoinIconResourceScript.texture()
	flyer.custom_minimum_size = RESULT_COIN_FLYER_SIZE
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_coin_flight_layer.add_child(flyer)
	flyer.size = RESULT_COIN_FLYER_SIZE
	flyer.pivot_offset = RESULT_COIN_FLYER_SIZE * 0.5
	var side := -1.0 if index % 2 == 0 else 1.0
	var start := source + Vector2(side * float(7 + index % 3 * 4), float((index % 3) - 1) * 5.0)
	var curve := (start + target) * 0.5 + Vector2(side * (44.0 + float(index % 3) * 9.0), -58.0 - float(index % 2) * 14.0)
	flyer.position = start - RESULT_COIN_FLYER_SIZE * 0.5
	flyer.scale = Vector2(0.56, 0.56)
	flyer.modulate.a = 0.0
	_set_result_lion_frame(LION_KING_VICTORY_OUT_ICON if index % 2 == 0 else LION_KING_VICTORY_WAVE_OUT_MID_ICON)
	var flight_tween := flyer.create_tween()
	result_coin_flight_tweens.append(flight_tween)
	flight_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight_tween.tween_method(
		_set_result_coin_flyer_progress.bind(flyer, start, curve, target),
		0.0,
		1.0,
		RESULT_COIN_FLIGHT_DURATION
	)
	flight_tween.parallel().tween_property(flyer, "modulate:a", 1.0, 0.12)
	flight_tween.parallel().tween_property(flyer, "scale", Vector2.ONE, 0.20).set_ease(Tween.EASE_OUT)
	flight_tween.tween_callback(_on_result_coin_flyer_arrived.bind(flyer, index + 1, reward, balance_after))


func _set_result_coin_flyer_progress(progress: float, flyer: TextureRect, start: Vector2, curve: Vector2, target: Vector2) -> void:
	if not is_instance_valid(flyer):
		return
	var inverse := 1.0 - progress
	var center := inverse * inverse * start + 2.0 * inverse * progress * curve + progress * progress * target
	flyer.position = center - RESULT_COIN_FLYER_SIZE * 0.5
	flyer.rotation = progress * TAU * 1.15
	if progress > 0.78:
		flyer.scale = Vector2.ONE * lerpf(1.0, 0.72, (progress - 0.78) / 0.22)


func _on_result_coin_flyer_arrived(flyer: TextureRect, value: int, reward: int, balance_after: int) -> void:
	if is_instance_valid(flyer):
		flyer.queue_free()
	if not self.visible or overlay_mode != "success":
		return
	if result_reward_coin_icon:
		if result_coin_pulse_tween and result_coin_pulse_tween.is_valid():
			result_coin_pulse_tween.kill()
		result_reward_coin_icon.scale = Vector2.ONE
		result_coin_pulse_tween = result_reward_coin_icon.create_tween()
		result_coin_pulse_tween.tween_property(result_reward_coin_icon, "scale", Vector2(1.16, 1.16), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		result_coin_pulse_tween.tween_property(result_reward_coin_icon, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if value >= reward:
		_set_result_lion_frame(LION_KING_VICTORY_ICON)
		_start_result_balance_reel(balance_after)


func _start_result_balance_reel(balance_after: int) -> void:
	if not result_coin_roll_display or not self.visible or overlay_mode != "success":
		return
	result_coin_roll_display.animate_reel_to(balance_after, RESULT_COIN_REEL_DURATION)


func stop_coin_animation() -> void:
	if result_coin_tween and result_coin_tween.is_valid():
		result_coin_tween.kill()
	result_coin_tween = null
	if result_coin_pulse_tween and result_coin_pulse_tween.is_valid():
		result_coin_pulse_tween.kill()
	result_coin_pulse_tween = null
	if result_coin_roll_display:
		result_coin_roll_display.stop_animation(true)
	for flight_tween in result_coin_flight_tweens:
		if flight_tween and flight_tween.is_valid():
			flight_tween.kill()
	result_coin_flight_tweens.clear()
	if result_coin_flight_layer:
		for flyer in result_coin_flight_layer.get_children():
			flyer.queue_free()
	if result_reward_coin_icon:
		result_reward_coin_icon.scale = Vector2.ONE
	if result_coin_roll_row:
		result_coin_roll_row.hide()



func play_lion_animation() -> void:
	if overlay_mode != "success" and overlay_mode != "tutorial":
		return
	if not self.visible or not result_piece_icon or not result_piece_icon.visible:
		return
	stop_lion_animation()
	result_piece_icon.scale = Vector2.ONE
	result_piece_icon.rotation = 0.0
	result_piece_icon.modulate.a = 0.0
	result_lion_tween = create_tween()
	result_lion_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	result_lion_tween.tween_property(result_piece_icon, "modulate:a", 1.0, 0.20)
	await result_lion_tween.finished
	if not self.visible or overlay_mode == "failure":
		return
	if overlay_mode == "success" and result_coin_tween and result_coin_tween.is_valid():
		result_lion_animation_name = "coin_toss"
		return
	_start_random_result_lion_animation()


func _start_random_result_lion_animation() -> void:
	if result_lion_wave_tween and result_lion_wave_tween.is_valid():
		result_lion_wave_tween.kill()
	result_lion_wave_tween = null
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


func stop_lion_animation() -> void:
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



func play_petals() -> void:
	if not result_petals_layer or not self.visible or overlay_mode != "success":
		return
	stop_petals()
	result_petals_layer.show()
	var viewport_size := self.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var colors := [Color("#FFD86B"), Color("#FF8FA8"), Color("#F7A7D8"), Color("#FFF3C4"), Color("#A8E6CF")]
	for index in range(24):
		var petal := Polygon2D.new()
		var scale_factor := rng.randf_range(0.72, 1.22)
		petal.polygon = PackedVector2Array([
			Vector2(-4, 1), Vector2(-3, -5), Vector2(0, -9),
			Vector2(4, -5), Vector2(5, 1), Vector2(0, 7)
		])
		petal.scale = Vector2.ONE * scale_factor
		petal.color = colors[index % colors.size()]
		petal.position = Vector2(rng.randf_range(8.0, viewport_size.x - 8.0), rng.randf_range(-110.0, -18.0))
		petal.rotation = rng.randf_range(-PI, PI)
		petal.visible = false
		result_petals_layer.add_child(petal)
		var delay := rng.randf_range(0.0, 0.95)
		var duration := rng.randf_range(1.85, 2.75)
		var end_position := Vector2(
			clampf(petal.position.x + rng.randf_range(-90.0, 90.0), 8.0, viewport_size.x - 8.0),
			viewport_size.y + 35.0
		)
		var petal_tween := petal.create_tween()
		petal_tween.tween_interval(delay)
		petal_tween.tween_callback(petal.show)
		petal_tween.tween_property(petal, "position", end_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		petal_tween.parallel().tween_property(petal, "rotation", petal.rotation + rng.randf_range(PI * 2.0, PI * 5.0), duration)
		petal_tween.parallel().tween_property(petal, "modulate:a", 0.08, duration * 0.28).set_delay(duration * 0.72)
		petal_tween.tween_callback(petal.queue_free)
		result_petal_tweens.append(petal_tween)


func stop_petals() -> void:
	for petal_tween in result_petal_tweens:
		if petal_tween and petal_tween.is_valid():
			petal_tween.kill()
	result_petal_tweens.clear()
	if not result_petals_layer:
		return
	for child in result_petals_layer.get_children():
		child.queue_free()
	result_petals_layer.hide()



func stop_all_animations() -> void:
	stop_coin_animation()
	stop_lion_animation()
	stop_petals()


func _piece_texture_rect(minimum_size: Vector2, texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


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
