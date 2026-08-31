extends ColorRect

signal primary_requested
signal secondary_requested
signal music_requested(kind: String)
signal music_stop_requested
signal sound_requested(kind: String)

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const CoinRollDisplayScript = preload("res://scripts/components/coin_roll_display.gd")
const CoinIconResourceScript = preload("res://scripts/components/coin_icon_resource.gd")
const LION_KING_CENTER_BODY = preload("res://assets/ui/lion_king_center_body.svg")
const LION_KING_CENTER_ARM_00 = preload("res://assets/ui/lion_king_center_arm_00.svg")
const LION_KING_CENTER_ARM_01 = preload("res://assets/ui/lion_king_center_arm_01.svg")
const LION_KING_CENTER_ARM_02 = preload("res://assets/ui/lion_king_center_arm_02.svg")
const LION_KING_CENTER_ARM_03 = preload("res://assets/ui/lion_king_center_arm_03.svg")
const LION_KING_CENTER_ARM_04 = preload("res://assets/ui/lion_king_center_arm_04.svg")
const LION_KING_CENTER_ARM_05 = preload("res://assets/ui/lion_king_center_arm_05.svg")
const LION_KING_CENTER_ARM_06 = preload("res://assets/ui/lion_king_center_arm_06.svg")
const LION_KING_CENTER_ARM_07 = preload("res://assets/ui/lion_king_center_arm_07.svg")
const LION_KING_CENTER_ARM_08 = preload("res://assets/ui/lion_king_center_arm_08.svg")
const LION_KING_CENTER_ARM_09 = preload("res://assets/ui/lion_king_center_arm_09.svg")
const LION_KING_CENTER_ARM_10 = preload("res://assets/ui/lion_king_center_arm_10.svg")
const LION_KING_CENTER_ARM_11 = preload("res://assets/ui/lion_king_center_arm_11.svg")
const LION_KING_CENTER_ARM_12 = preload("res://assets/ui/lion_king_center_arm_12.svg")
const LION_BOTTOM_ENTRY_00 = preload("res://assets/ui/lion_bottom_entry_00.svg")
const LION_BOTTOM_ENTRY_01 = preload("res://assets/ui/lion_bottom_entry_01.svg")
const LION_BOTTOM_ENTRY_02 = preload("res://assets/ui/lion_bottom_entry_02.svg")
const LION_BOTTOM_ENTRY_03 = preload("res://assets/ui/lion_bottom_entry_03.svg")
const LION_BOTTOM_ENTRY_04 = preload("res://assets/ui/lion_bottom_entry_04.svg")
const LION_BOTTOM_ENTRY_05 = preload("res://assets/ui/lion_bottom_entry_05.svg")
const LION_BOTTOM_ENTRY_06 = preload("res://assets/ui/lion_bottom_entry_06.svg")
const LION_BOTTOM_ENTRY_07 = preload("res://assets/ui/lion_bottom_entry_07.svg")
const LION_BOTTOM_ENTRY_08 = preload("res://assets/ui/lion_bottom_entry_08.svg")
const LION_BOTTOM_ENTRY_09 = preload("res://assets/ui/lion_bottom_entry_09.svg")
const LION_BOTTOM_ENTRY_10 = preload("res://assets/ui/lion_bottom_entry_10.svg")
const LION_BOTTOM_JUMP_00 = preload("res://assets/ui/lion_bottom_jump_00.svg")
const LION_BOTTOM_JUMP_01 = preload("res://assets/ui/lion_bottom_jump_01.svg")
const LION_BOTTOM_JUMP_02 = preload("res://assets/ui/lion_bottom_jump_02.svg")
const LION_BOTTOM_JUMP_03 = preload("res://assets/ui/lion_bottom_jump_03.svg")
const LION_BOTTOM_JUMP_04 = preload("res://assets/ui/lion_bottom_jump_04.svg")
const LION_BOTTOM_JUMP_05 = preload("res://assets/ui/lion_bottom_jump_05.svg")
const LION_BOTTOM_JUMP_06 = preload("res://assets/ui/lion_bottom_jump_06.svg")
const LION_BOTTOM_JUMP_07 = preload("res://assets/ui/lion_bottom_jump_07.svg")
const LION_BOTTOM_JUMP_08 = preload("res://assets/ui/lion_bottom_jump_08.svg")
const LION_LEFT_ENTRY_00 = preload("res://assets/ui/lion_left_entry_00.svg")
const LION_LEFT_ENTRY_01 = preload("res://assets/ui/lion_left_entry_01.svg")
const LION_LEFT_ENTRY_02 = preload("res://assets/ui/lion_left_entry_02.svg")
const LION_LEFT_ENTRY_03 = preload("res://assets/ui/lion_left_entry_03.svg")
const LION_LEFT_ENTRY_04 = preload("res://assets/ui/lion_left_entry_04.svg")
const LION_LEFT_ENTRY_05 = preload("res://assets/ui/lion_left_entry_05.svg")
const LION_LEFT_ENTRY_06 = preload("res://assets/ui/lion_left_entry_06.svg")
const LION_LEFT_ENTRY_07 = preload("res://assets/ui/lion_left_entry_07.svg")
const LION_LEFT_ENTRY_08 = preload("res://assets/ui/lion_left_entry_08.svg")
const LION_LEFT_ENTRY_09 = preload("res://assets/ui/lion_left_entry_09.svg")
const LION_LEFT_ENTRY_10 = preload("res://assets/ui/lion_left_entry_10.svg")
const LION_LEFT_ENTRY_11 = preload("res://assets/ui/lion_left_entry_11.svg")
const LION_LEFT_ENTRY_12 = preload("res://assets/ui/lion_left_entry_12.svg")
const LION_LEFT_ENTRY_13 = preload("res://assets/ui/lion_left_entry_13.svg")
const LION_LEFT_ENTRY_14 = preload("res://assets/ui/lion_left_entry_14.svg")
const LION_LEFT_ENTRY_15 = preload("res://assets/ui/lion_left_entry_15.svg")
const LION_RIGHT_ENTRY_00 = preload("res://assets/ui/lion_right_entry_00.svg")
const LION_RIGHT_ENTRY_01 = preload("res://assets/ui/lion_right_entry_01.svg")
const LION_RIGHT_ENTRY_02 = preload("res://assets/ui/lion_right_entry_02.svg")
const LION_RIGHT_ENTRY_03 = preload("res://assets/ui/lion_right_entry_03.svg")
const LION_RIGHT_ENTRY_04 = preload("res://assets/ui/lion_right_entry_04.svg")
const LION_RIGHT_ENTRY_05 = preload("res://assets/ui/lion_right_entry_05.svg")
const LION_RIGHT_ENTRY_06 = preload("res://assets/ui/lion_right_entry_06.svg")
const LION_RIGHT_ENTRY_07 = preload("res://assets/ui/lion_right_entry_07.svg")
const LION_RIGHT_ENTRY_08 = preload("res://assets/ui/lion_right_entry_08.svg")
const LION_RIGHT_ENTRY_09 = preload("res://assets/ui/lion_right_entry_09.svg")
const LION_RIGHT_ENTRY_10 = preload("res://assets/ui/lion_right_entry_10.svg")
const LION_RIGHT_ENTRY_11 = preload("res://assets/ui/lion_right_entry_11.svg")
const LION_RIGHT_ENTRY_12 = preload("res://assets/ui/lion_right_entry_12.svg")
const LION_RIGHT_ENTRY_13 = preload("res://assets/ui/lion_right_entry_13.svg")
const LION_RIGHT_ENTRY_14 = preload("res://assets/ui/lion_right_entry_14.svg")
const LION_RIGHT_ENTRY_15 = preload("res://assets/ui/lion_right_entry_15.svg")
const LION_BOTTOM_PEEK_BLINK = preload("res://assets/ui/lion_bottom_peek_blink.svg")
const LION_LEFT_PEEK_BLINK = preload("res://assets/ui/lion_left_peek_blink.svg")
const LION_RIGHT_PEEK_BLINK = preload("res://assets/ui/lion_right_peek_blink.svg")
const LION_KING_CENTER_LANDING = preload("res://assets/ui/lion_king_center_landing.svg")
const RESULT_PETAL_TEXTURE = preload("res://assets/ui/petal_neutral.svg")
const HEART_ICON: Texture2D = preload("res://assets/ui/heart.svg")
const WARNING_ICON: Texture2D = preload("res://assets/ui/warning.svg")
const CARD := UITokensScript.SURFACE_CARD
const INK := UITokensScript.INK
const RESULT_COIN_START_DELAY := 0.00
const RESULT_COIN_MIN_DURATION := 2.15
const RESULT_COIN_MAX_DURATION := 3.30
const RESULT_COIN_FLIGHT_DURATION := 0.72
const RESULT_COIN_FLIGHT_MIN_STAGGER := 0.08
const RESULT_COIN_FLIGHT_MAX_STAGGER := 0.16
const RESULT_COIN_REEL_DURATION := 1.00
const RESULT_COIN_REEL_SETTLE_HOLD := 0.08
const RESULT_COIN_FLYER_SIZE := Vector2(29, 29)
const RESULT_COIN_BALANCE_GAP := 28.0
const RESULT_PETAL_COUNT := 32
const RESULT_PETAL_DELAY_MAX := 0.55
const RESULT_PETAL_DURATION_MIN := 3.35
const RESULT_PETAL_DURATION_MAX := 4.20
const RESULT_PETAL_FADE_FRACTION := 0.14
const RESULT_PETAL_SEQUENCE_DURATION := RESULT_PETAL_DELAY_MAX + RESULT_PETAL_DURATION_MAX + 0.05
const RESULT_LION_PEEK_DURATION := 1.55
const RESULT_LION_PEEK_REVEAL_FRACTION := 0.52
const RESULT_LION_PEEK_TEASE_END_FRACTION := 0.88
const RESULT_LION_PEEK_TEASE_STEPS := 6
const RESULT_LION_SQUAT_DURATION := 0.30
const RESULT_LION_JUMP_DURATION := 0.48
const RESULT_LION_LAND_DURATION := 0.22
const RESULT_LION_ARRIVAL_DURATION := 0.72
const RESULT_LION_ENTRY_VARIANTS := ["peek_left", "peek_right", "peek_bottom"]
const RESULT_LION_LEFT_SUPPORT_RATIO := 0.06
const RESULT_LION_RIGHT_SUPPORT_RATIO := 0.94
const RESULT_LION_BOTTOM_SUPPORT_RATIO := 0.94
# The authored contact poses are registered against the screen edge while the
# airborne poses are centered on their 400px canvas. Keep the first airborne
# silhouette on the same visual contact point, then release the compensation
# during the opening part of the jump.
const RESULT_LION_JUMP_REGISTRATION_RELEASE := 0.28
const RESULT_LION_JUMP_REGISTRATION_OFFSETS := {
	"peek_left": Vector2(-0.1900, -0.0025),
	"peek_right": Vector2(0.22125, 0.0),
	"peek_bottom": Vector2(0.0, 0.2150),
}
const RESULT_LION_LEFT_PEEK_FRAMES := [
	LION_LEFT_ENTRY_00,
	LION_LEFT_ENTRY_01,
	LION_LEFT_ENTRY_02,
	LION_LEFT_ENTRY_03,
	LION_LEFT_ENTRY_04,
	LION_LEFT_ENTRY_05,
	LION_LEFT_ENTRY_06,
	LION_LEFT_ENTRY_07,
]
const RESULT_LION_LEFT_BRACE_FRAMES := [
	LION_LEFT_ENTRY_08,
	LION_LEFT_ENTRY_09,
	LION_LEFT_ENTRY_10,
]
const RESULT_LION_LEFT_JUMP_FRAMES := [
	LION_LEFT_ENTRY_11,
	LION_LEFT_ENTRY_12,
	LION_LEFT_ENTRY_13,
	LION_LEFT_ENTRY_14,
	LION_LEFT_ENTRY_15,
]
const RESULT_LION_RIGHT_PEEK_FRAMES := [
	LION_RIGHT_ENTRY_00,
	LION_RIGHT_ENTRY_01,
	LION_RIGHT_ENTRY_02,
	LION_RIGHT_ENTRY_03,
	LION_RIGHT_ENTRY_04,
	LION_RIGHT_ENTRY_05,
	LION_RIGHT_ENTRY_06,
	LION_RIGHT_ENTRY_07,
]
const RESULT_LION_RIGHT_BRACE_FRAMES := [
	LION_RIGHT_ENTRY_08,
	LION_RIGHT_ENTRY_09,
	LION_RIGHT_ENTRY_10,
]
const RESULT_LION_RIGHT_JUMP_FRAMES := [
	LION_RIGHT_ENTRY_11,
	LION_RIGHT_ENTRY_12,
	LION_RIGHT_ENTRY_13,
	LION_RIGHT_ENTRY_14,
	LION_RIGHT_ENTRY_15,
]
const RESULT_LION_BOTTOM_PEEK_FRAMES := [
	LION_BOTTOM_ENTRY_00,
	LION_BOTTOM_ENTRY_01,
	LION_BOTTOM_ENTRY_02,
	LION_BOTTOM_ENTRY_03,
	LION_BOTTOM_ENTRY_04,
	LION_BOTTOM_ENTRY_05,
	LION_BOTTOM_ENTRY_06,
	LION_BOTTOM_ENTRY_07,
]
const RESULT_LION_BOTTOM_BRACE_FRAMES := [
	LION_BOTTOM_ENTRY_08,
	LION_BOTTOM_ENTRY_09,
	LION_BOTTOM_ENTRY_10,
]
const RESULT_LION_BOTTOM_JUMP_FRAMES := [
	LION_BOTTOM_JUMP_00,
	LION_BOTTOM_JUMP_01,
	LION_BOTTOM_JUMP_02,
	LION_BOTTOM_JUMP_03,
	LION_BOTTOM_JUMP_04,
	LION_BOTTOM_JUMP_05,
	LION_BOTTOM_JUMP_06,
	LION_BOTTOM_JUMP_07,
	LION_BOTTOM_JUMP_08,
]
const RESULT_LION_WAVE_ARM_FRAMES := [
	LION_KING_CENTER_ARM_00,
	LION_KING_CENTER_ARM_01,
	LION_KING_CENTER_ARM_02,
	LION_KING_CENTER_ARM_03,
	LION_KING_CENTER_ARM_04,
	LION_KING_CENTER_ARM_05,
	LION_KING_CENTER_ARM_06,
	LION_KING_CENTER_ARM_07,
	LION_KING_CENTER_ARM_08,
	LION_KING_CENTER_ARM_09,
	LION_KING_CENTER_ARM_10,
	LION_KING_CENTER_ARM_11,
	LION_KING_CENTER_ARM_12,
	LION_KING_CENTER_ARM_11,
	LION_KING_CENTER_ARM_10,
	LION_KING_CENTER_ARM_09,
	LION_KING_CENTER_ARM_08,
	LION_KING_CENTER_ARM_07,
	LION_KING_CENTER_ARM_06,
	LION_KING_CENTER_ARM_05,
	LION_KING_CENTER_ARM_04,
	LION_KING_CENTER_ARM_03,
	LION_KING_CENTER_ARM_02,
	LION_KING_CENTER_ARM_01,
	LION_KING_CENTER_ARM_00,
]
const RESULT_LION_WAVE_DURATIONS := [
	0.10,
	0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04,
	0.13,
	0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04,
	0.13,
]
const RESULT_LION_WAVE_LOOP_PAUSE := 0.12
const RESULT_LION_IDLE_MIN_DURATION := 1.50
const RESULT_LION_IDLE_MAX_DURATION := 2.70
const RESULT_PETAL_COLORS := [
	Color("#FFD45F"),
	Color("#FF8D9F"),
	Color("#F29AD2"),
	Color("#BFA7F2"),
	Color("#8EDBC4"),
	Color("#87CFF3"),
	Color("#FFAE73")
]

var completion_overlay: ColorRect
var completion_title: Label
var reward_label: Label
var result_status_icon: TextureRect
var result_piece_icon: TextureRect
var result_lion_arm_icon: TextureRect
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
var result_lion_entry_layer: Control
var result_lion_runner: TextureRect
var completion_next_button: Button
var completion_replay_button: Button
var overlay_mode := "success"
var result_coin_pulse_tween: Tween
var result_page_fade_tween: Tween
var result_lion_tween: Tween
var result_lion_wave_tween: Tween
var result_coin_tween: Tween
var result_lion_coin_arm_tween: Tween
var result_success_sequence_tween: Tween
var result_coin_flight_tweens: Array[Tween] = []
var result_petal_tweens: Array[Tween] = []
var result_lion_animation_name := ""
var result_lion_entry_name := ""
var result_lion_entry_active := false
var result_lion_celebration_variant := 0
var result_lion_last_animation_index := -1
var result_lion_generation := 0
var result_coin_arrival_sound_values: Dictionary = {}
var result_is_excellent := false
var result_sequence_generation := 0
var pending_result_coin_request: Dictionary = {}
var _localizer: Callable
var _safe_area: MarginContainer

func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	completion_overlay = self
	completion_overlay.color = UITokensScript.ROYAL_FLOOR
	completion_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	completion_overlay.z_index = 10
	completion_overlay.hide()
	completion_overlay.visibility_changed.connect(_on_result_visibility_changed)

	var background := TextureRect.new()
	background.name = "RoyalScreenBackground"
	background.texture = UITokensScript.royal_screen_gradient_texture()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	completion_overlay.add_child(background)

	result_lion_entry_layer = Control.new()
	result_lion_entry_layer.name = "ResultLionEntryLayer"
	result_lion_entry_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_lion_entry_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_lion_entry_layer.z_index = 15
	completion_overlay.add_child(result_lion_entry_layer)

	result_petals_layer = Control.new()
	result_petals_layer.name = "ResultPetalsLayer"
	result_petals_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_petals_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_petals_layer.z_index = 20
	result_petals_layer.hide()
	completion_overlay.add_child(result_petals_layer)

	result_coin_flight_layer = Control.new()
	result_coin_flight_layer.name = "ResultCoinFlightLayer"
	result_coin_flight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_coin_flight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_coin_flight_layer.z_index = 30
	completion_overlay.add_child(result_coin_flight_layer)

	_safe_area = MarginContainer.new()
	_safe_area.name = "ResultSafeArea"
	_safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	completion_overlay.add_child(_safe_area)
	_safe_area.add_theme_constant_override("margin_left", 30)
	_safe_area.add_theme_constant_override("margin_top", 56)
	_safe_area.add_theme_constant_override("margin_right", 30)
	_safe_area.add_theme_constant_override("margin_bottom", 24)
	if is_inside_tree():
		_start_safe_area_tracking()
	else:
		tree_entered.connect(_start_safe_area_tracking, CONNECT_ONE_SHOT)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = 0
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_safe_area.add_child(column)

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

	result_piece_icon = _piece_texture_rect(Vector2(164, 164), LION_KING_CENTER_BODY)
	showcase_column.add_child(result_piece_icon)
	result_lion_arm_icon = _piece_texture_rect(Vector2.ZERO, LION_KING_CENTER_ARM_00)
	result_lion_arm_icon.name = "ResultLionArm"
	result_piece_icon.add_child(result_lion_arm_icon)
	result_lion_arm_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_lion_arm_icon.show_behind_parent = true
	result_lion_arm_icon.hide()

	result_status_icon = TextureRect.new()
	result_status_icon.name = "ResultStatusIcon"
	result_status_icon.texture = HEART_ICON
	result_status_icon.custom_minimum_size = Vector2(84, 84)
	result_status_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_status_icon.modulate = Color("#F25D72")
	result_status_icon.hide()
	showcase_column.add_child(result_status_icon)

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
		"minimum_counter_width": 42.0,
		"minimum_counter_height": 52.0,
		"minimum_digits": 1,
		"horizontal_padding": 8.0,
		"vertical_padding": 4.0,
		"icon_size": Vector2(44, 44),
		"content_gap": RESULT_COIN_BALANCE_GAP,
		"dynamic_digit_sizing": true,
		"digit_profiles": {
			1: {"font_size": 38, "minimum_width": 42.0},
			2: {"font_size": 36, "minimum_width": 58.0},
			3: {"font_size": 34, "minimum_width": 76.0},
			4: {"font_size": 32, "minimum_width": 94.0},
			5: {"font_size": 29, "minimum_width": 108.0},
			6: {"font_size": 26, "minimum_width": 122.0},
		},
		"overflow_font_size": 23,
		"font_color": Color("#D88916"),
		"number_alignment": HORIZONTAL_ALIGNMENT_LEFT,
		"outline_size": 1,
		"outline_color": Color("#D88916"),
		"shadow_offset_y": 2,
	})
	result_coin_roll_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_coin_roll_display.roll_finished.connect(_on_result_balance_roll_finished)
	result_coin_roll_display.reel_notch.connect(_on_result_coin_reel_notch)
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


func _apply_safe_area_margins() -> void:
	if not is_instance_valid(_safe_area):
		return
	var insets := UITokensScript.display_safe_insets(get_viewport_rect().size)
	_safe_area.add_theme_constant_override("margin_left", maxi(30, int(ceil(insets.x + 12.0))))
	_safe_area.add_theme_constant_override("margin_top", maxi(56, int(ceil(insets.y + 12.0))))
	_safe_area.add_theme_constant_override("margin_right", maxi(30, int(ceil(insets.z + 12.0))))
	_safe_area.add_theme_constant_override("margin_bottom", maxi(24, int(ceil(insets.w + 12.0))))


func _start_safe_area_tracking() -> void:
	_apply_safe_area_margins()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_apply_safe_area_margins):
		viewport.size_changed.connect(_apply_safe_area_margins)


func present_success(data: Dictionary) -> void:
	overlay_mode = "success"
	completion_next_button.icon = null
	var excellent := bool(data.get("excellent", false))
	music_stop_requested.emit()
	stop_success_sequence()
	stop_petals()
	result_is_excellent = excellent
	var composite := bool(data.get("composite", false))
	var reward := maxi(0, int(data.get("reward", 0)))
	var balance_after := maxi(0, int(data.get("coinBalance", reward)))
	var balance_before := maxi(0, int(data.get("coinBalanceBefore", balance_after - reward)))
	completion_title.text = _t("EXCELLENT") if excellent else _t("GOOD")
	reward_label.text = (
		_t("拼块挑战 · 第 %d 局完成", [maxi(1, int(data.get("round", 1)))])
		if composite else _t("第 %d 关 已完成", [maxi(1, int(data.get("displayLevel", 1)))])
	)
	result_status_icon.hide()
	_show_center_result_lion_idle()
	result_piece_icon.show()
	stop_coin_animation()
	result_reward_label.hide()
	if result_coin_roll_display:
		# The reward row becomes visible before the deferred celebration sequence.
		# Seed it now so its first rendered frame never exposes the component's
		# construction default or a balance left behind by the previous result.
		result_coin_roll_display.set_value(balance_before)
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
	call_deferred("play_lion_animation")
	call_deferred(
		"play_success_sequence",
		excellent,
		reward,
		balance_before,
		balance_after
	)


func present_failure(data: Dictionary) -> void:
	overlay_mode = "failure"
	completion_next_button.icon = null
	result_is_excellent = false
	stop_all_animations()
	var composite := bool(data.get("composite", false))
	completion_title.text = _t("挑战失败")
	reward_label.text = (
		_t("拼块挑战 · 第 %d 局未完成", [maxi(1, int(data.get("round", 1)))])
		if composite else _t("第 %d 关 未完成", [maxi(1, int(data.get("displayLevel", 1)))])
	)
	result_status_icon.texture = HEART_ICON
	result_status_icon.modulate = Color("#F25D72")
	result_status_icon.show()
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
	completion_next_button.icon = null
	result_is_excellent = false
	stop_all_animations()
	completion_title.text = _t("拼块死局")
	reward_label.text = _t("同色区域已被隔离")
	result_status_icon.texture = WARNING_ICON
	result_status_icon.modulate = Color.WHITE
	result_status_icon.show()
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
	result_is_excellent = false
	stop_all_animations()
	completion_title.text = _t("已经了解全部规则")
	reward_label.text = _t("开始真正的挑战吧！")
	result_status_icon.hide()
	_show_center_result_lion_idle()
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
	if result_page_fade_tween and result_page_fade_tween.is_valid():
		result_page_fade_tween.kill()
	show()
	modulate.a = 0.0
	result_page_fade_tween = create_tween()
	result_page_fade_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	result_page_fade_tween.tween_callback(func() -> void: result_page_fade_tween = null)


func _on_result_visibility_changed() -> void:
	if not visible:
		stop_all_animations()


func _t(source: String, values: Array = []) -> String:
	if _localizer.is_valid():
		return str(_localizer.call(source, values))
	return source % values if not values.is_empty() else source



func play_coin_animation(reward: int, balance_before: int, balance_after: int) -> void:
	if not result_coin_roll_display or reward <= 0 or overlay_mode != "success":
		return
	stop_coin_animation()
	_pause_result_lion_for_coins()
	result_coin_arrival_sound_values = _coin_arrival_sound_milestones(reward)
	result_coin_roll_display.show()
	balance_before = maxi(0, balance_before)
	balance_after = maxi(0, balance_after)
	result_coin_roll_display.set_value(balance_before)
	result_reward_coin_icon.scale = Vector2.ONE
	result_reward_coin_icon.pivot_offset = result_reward_coin_icon.size * 0.5
	# `set_value()` may expand the rolling-number clip for a larger balance. Wait
	# until both containers have applied the new minimum size before resolving the
	# receiving target; otherwise the icon can move after the flight path is built.
	result_coin_roll_display.queue_sort()
	await get_tree().process_frame
	if not result_coin_roll_display or not result_coin_roll_display.visible or overlay_mode != "success":
		return
	await get_tree().process_frame
	if not result_reward_coin_icon or not result_reward_coin_icon.visible or overlay_mode != "success":
		return
	result_reward_coin_icon.pivot_offset = result_reward_coin_icon.size * 0.5
	var source := _control_point_in_flight_layer(
		result_piece_icon,
		Vector2(result_piece_icon.size.x * 0.70, result_piece_icon.size.y * 0.50 + 4.0)
	)
	var target := _control_center_in_flight_layer(result_reward_coin_icon)
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
	var sequence_duration := (
		RESULT_COIN_START_DELAY
		+ flight_sequence_duration
		+ RESULT_COIN_REEL_DURATION
	)
	var completion_hold := maxf(RESULT_COIN_REEL_SETTLE_HOLD, RESULT_COIN_MIN_DURATION - sequence_duration)
	_start_result_lion_coin_arm_toss(flight_sequence_duration)
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


func _control_center_in_flight_layer(control: Control) -> Vector2:
	if not control:
		return Vector2.ZERO
	return _control_point_in_flight_layer(control, control.size * 0.5)


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
	if result_coin_arrival_sound_values.has(value):
		sound_requested.emit("coin_arrive")
	if result_reward_coin_icon:
		if result_coin_pulse_tween and result_coin_pulse_tween.is_valid():
			result_coin_pulse_tween.kill()
		result_reward_coin_icon.scale = Vector2.ONE
		result_coin_pulse_tween = result_reward_coin_icon.create_tween()
		result_coin_pulse_tween.tween_property(result_reward_coin_icon, "scale", Vector2(1.16, 1.16), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		result_coin_pulse_tween.tween_property(result_reward_coin_icon, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if value >= reward:
		_show_center_result_lion_idle()
		_start_result_balance_reel(balance_after)


func _start_result_lion_coin_arm_toss(duration: float) -> void:
	if result_lion_coin_arm_tween and result_lion_coin_arm_tween.is_valid():
		result_lion_coin_arm_tween.kill()
	result_lion_coin_arm_tween = create_tween()
	result_lion_coin_arm_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	result_lion_coin_arm_tween.tween_method(
		_set_result_lion_coin_arm_progress,
		0.0,
		1.0,
		maxf(0.28, duration)
	)
	result_lion_coin_arm_tween.tween_callback(func() -> void:
		result_lion_coin_arm_tween = null
		_set_result_lion_arm_frame(LION_KING_CENTER_ARM_00)
	)


func _set_result_lion_coin_arm_progress(progress: float) -> void:
	# One complete outward-and-return gesture owns the entire group of flying
	# coins. It remains smooth even when a reward contains only two coins.
	var gesture := sin(clampf(progress, 0.0, 1.0) * PI)
	var frame_index := clampi(roundi(gesture * 12.0), 0, 12)
	_set_result_lion_arm_frame(RESULT_LION_WAVE_ARM_FRAMES[frame_index])


func _start_result_balance_reel(balance_after: int) -> void:
	if not result_coin_roll_display or not self.visible or overlay_mode != "success":
		return
	sound_requested.emit("coin_reel")
	result_coin_roll_display.animate_reel_to(balance_after, RESULT_COIN_REEL_DURATION)


func _on_result_coin_reel_notch(_value: int, step_index: int, step_count: int) -> void:
	# The final notch is owned by the dedicated settle sound. Intermediate
	# notches follow the reel's real weighted step timing instead of a fixed loop.
	if visible and overlay_mode == "success" and step_index < step_count - 1:
		sound_requested.emit("coin_reel")


func _on_result_balance_roll_finished(_balance: int) -> void:
	if visible and overlay_mode == "success":
		sound_requested.emit("coin_settle")
		music_stop_requested.emit()


func play_success_sequence(excellent: bool, reward: int, balance_before: int, balance_after: int) -> void:
	stop_success_sequence()
	var sequence_generation := result_sequence_generation
	# The result page is built from nested Containers. Let them complete two layout
	# passes before resolving the lion's global center, otherwise the petal target
	# can still point at the header's previous layout position.
	await get_tree().process_frame
	await get_tree().process_frame
	if (
		sequence_generation != result_sequence_generation
		or not visible
		or overlay_mode != "success"
	):
		return
	if reward > 0:
		pending_result_coin_request = {
			"reward": reward,
			"balance_before": balance_before,
			"balance_after": balance_after,
			"ready": not excellent,
		}
	if excellent:
		play_petals()
		result_success_sequence_tween = create_tween()
		result_success_sequence_tween.tween_interval(RESULT_PETAL_SEQUENCE_DURATION)
		result_success_sequence_tween.tween_callback(_finish_petals_phase)
		if reward > 0:
			result_success_sequence_tween.tween_callback(_release_pending_result_coin_animation)
		else:
			result_success_sequence_tween.tween_callback(func() -> void: music_stop_requested.emit())
		return
	if reward > 0:
		_flush_pending_result_coin_animation()


func stop_success_sequence() -> void:
	result_sequence_generation += 1
	if result_success_sequence_tween and result_success_sequence_tween.is_valid():
		result_success_sequence_tween.kill()
	result_success_sequence_tween = null
	pending_result_coin_request.clear()


func _release_pending_result_coin_animation() -> void:
	if pending_result_coin_request.is_empty():
		return
	pending_result_coin_request["ready"] = true
	_flush_pending_result_coin_animation()


func _flush_pending_result_coin_animation() -> bool:
	if (
		pending_result_coin_request.is_empty()
		or not bool(pending_result_coin_request.get("ready", false))
		or result_lion_entry_active
		or not visible
		or overlay_mode != "success"
	):
		return false
	var request := pending_result_coin_request.duplicate()
	pending_result_coin_request.clear()
	play_coin_animation(
		int(request["reward"]),
		int(request["balance_before"]),
		int(request["balance_after"])
	)
	return true


func _finish_petals_phase() -> void:
	stop_petals()


func stop_coin_animation() -> void:
	if result_coin_tween and result_coin_tween.is_valid():
		result_coin_tween.kill()
	result_coin_tween = null
	if result_lion_coin_arm_tween and result_lion_coin_arm_tween.is_valid():
		result_lion_coin_arm_tween.kill()
	result_lion_coin_arm_tween = null
	result_coin_arrival_sound_values.clear()
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
	if result_piece_icon and result_piece_icon.visible:
		_set_result_lion_arm_frame(LION_KING_CENTER_ARM_00)


func _coin_arrival_sound_milestones(reward: int) -> Dictionary:
	var milestones := {}
	if reward <= 0:
		return milestones
	milestones[1] = true
	if reward >= 3:
		milestones[int(ceil(float(reward) * 0.5))] = true
	milestones[reward] = true
	return milestones



func play_lion_animation() -> void:
	if overlay_mode != "success" and overlay_mode != "tutorial":
		return
	if not self.visible or not result_piece_icon or not result_piece_icon.visible:
		return
	stop_lion_animation()
	_show_center_result_lion_idle()
	result_piece_icon.modulate.a = 0.0
	if overlay_mode == "success":
		result_lion_entry_active = true
		var generation := result_lion_generation
		# Containers need two rendered layout passes before the runner can target the
		# exact center of the stationary showcase lion.
		await get_tree().process_frame
		await get_tree().process_frame
		if generation != result_lion_generation or not visible or overlay_mode != "success":
			return
		_start_random_result_lion_entry(generation)
		return
	result_lion_tween = create_tween()
	result_lion_tween.tween_property(result_piece_icon, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	result_lion_tween.tween_callback(_start_random_result_lion_animation)


func _start_random_result_lion_entry(generation: int) -> void:
	if generation != result_lion_generation or not result_lion_entry_layer or not result_piece_icon:
		return
	result_lion_entry_name = RESULT_LION_ENTRY_VARIANTS[randi_range(0, RESULT_LION_ENTRY_VARIANTS.size() - 1)]
	result_lion_celebration_variant = randi_range(0, 2)
	result_lion_animation_name = result_lion_entry_name
	var peek_frames := _result_lion_entry_frames(result_lion_entry_name, "peek")
	var runner_requested_edge := 210.0
	var runner_start_texture: Texture2D = peek_frames[0]
	result_lion_runner = _piece_texture_rect(Vector2.ONE * runner_requested_edge, runner_start_texture)
	result_lion_runner.name = "ResultLionRunner"
	result_lion_entry_layer.add_child(result_lion_runner)
	var runner_edge := minf(runner_requested_edge, result_piece_icon.size.y * 1.28)
	if runner_edge <= 1.0:
		runner_edge = runner_requested_edge
	var runner_size := Vector2.ONE * runner_edge
	result_lion_runner.size = runner_size
	result_lion_runner.pivot_offset = runner_size * 0.5
	result_lion_runner.modulate = Color.WHITE
	result_lion_runner.material = null
	var runner_arm := _piece_texture_rect(Vector2.ZERO, LION_KING_CENTER_ARM_00)
	runner_arm.name = "ResultLionRunnerArm"
	result_lion_runner.add_child(runner_arm)
	runner_arm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	runner_arm.show_behind_parent = true
	runner_arm.hide()
	var peek_blink := _piece_texture_rect(
		Vector2.ZERO,
		_result_lion_peek_blink_texture(result_lion_entry_name)
	)
	peek_blink.name = "ResultLionPeekBlink"
	result_lion_runner.add_child(peek_blink)
	peek_blink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	peek_blink.hide()
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport_rect().size
	var target := _control_center_in_layer(result_piece_icon, result_lion_entry_layer)
	var support := Vector2.ZERO
	var launch := Vector2.ZERO
	var curve := Vector2.ZERO
	match result_lion_entry_name:
		"peek_left":
			var edge_y := clampf(target.y + randf_range(-118.0, 118.0), 152.0, viewport_size.y - 178.0)
			support = Vector2(0.0, edge_y)
			launch = Vector2(runner_edge * (0.5 - RESULT_LION_LEFT_SUPPORT_RATIO), edge_y)
			curve = Vector2(lerpf(launch.x, target.x, 0.52), minf(launch.y, target.y) - 142.0)
		"peek_right":
			var edge_y := clampf(target.y + randf_range(-118.0, 118.0), 152.0, viewport_size.y - 178.0)
			support = Vector2(viewport_size.x, edge_y)
			launch = Vector2(viewport_size.x - runner_edge * (RESULT_LION_RIGHT_SUPPORT_RATIO - 0.5), edge_y)
			curve = Vector2(lerpf(launch.x, target.x, 0.48), minf(launch.y, target.y) - 142.0)
		_:
			var edge_x := clampf(target.x + randf_range(-142.0, 142.0), 104.0, viewport_size.x - 104.0)
			support = Vector2(edge_x, viewport_size.y)
			launch = Vector2(edge_x, viewport_size.y - runner_edge * (RESULT_LION_BOTTOM_SUPPORT_RATIO - 0.5))
			curve = Vector2(lerpf(launch.x, target.x, 0.50) + randf_range(-36.0, 36.0), target.y - 168.0)
	_set_result_lion_entry_peek_progress(0.0, result_lion_runner, support, result_lion_entry_name)
	result_lion_tween = create_tween()
	result_lion_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	result_lion_tween.tween_method(
		_set_result_lion_entry_peek_progress.bind(result_lion_runner, support, result_lion_entry_name),
		0.0,
		1.0,
		RESULT_LION_PEEK_DURATION
	)
	result_lion_tween.tween_method(
		_set_result_lion_entry_brace_progress.bind(result_lion_runner, support, result_lion_entry_name),
		0.0,
		1.0,
		RESULT_LION_SQUAT_DURATION
	)
	result_lion_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	result_lion_tween.tween_method(
		_set_result_lion_entry_jump_progress.bind(result_lion_runner, launch, curve, target, result_lion_entry_name),
		0.0,
		1.0,
		RESULT_LION_JUMP_DURATION
	)
	result_lion_tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	result_lion_tween.tween_method(
		_set_result_lion_land_progress.bind(
			result_lion_runner,
			target,
			result_lion_entry_name
		),
		0.0,
		1.0,
		RESULT_LION_LAND_DURATION
	)
	result_lion_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	result_lion_tween.tween_method(
		_set_result_lion_arrival_progress.bind(result_lion_runner, target, result_lion_celebration_variant),
		0.0,
		1.0,
		RESULT_LION_ARRIVAL_DURATION
	)
	result_lion_tween.tween_callback(_finish_result_lion_entry.bind(generation))


func _result_lion_entry_frames(variant: String, phase: String) -> Array:
	match variant:
		"peek_left":
			match phase:
				"brace": return RESULT_LION_LEFT_BRACE_FRAMES
				"jump": return RESULT_LION_LEFT_JUMP_FRAMES
				_: return RESULT_LION_LEFT_PEEK_FRAMES
		"peek_right":
			match phase:
				"brace": return RESULT_LION_RIGHT_BRACE_FRAMES
				"jump": return RESULT_LION_RIGHT_JUMP_FRAMES
				_: return RESULT_LION_RIGHT_PEEK_FRAMES
		_:
			match phase:
				"brace": return RESULT_LION_BOTTOM_BRACE_FRAMES
				"jump": return RESULT_LION_BOTTOM_JUMP_FRAMES
				_: return RESULT_LION_BOTTOM_PEEK_FRAMES


func result_lion_entry_duration() -> float:
	return (
		RESULT_LION_PEEK_DURATION
		+ RESULT_LION_SQUAT_DURATION
		+ RESULT_LION_JUMP_DURATION
		+ RESULT_LION_LAND_DURATION
		+ RESULT_LION_ARRIVAL_DURATION
	)


func _result_lion_peek_frame_index(progress: float, frame_count: int, variant: String = "peek_bottom") -> int:
	var clamped := clampf(progress, 0.0, 1.0)
	var open_frame_index := _result_lion_peek_open_frame_index(variant, frame_count)
	if clamped < RESULT_LION_PEEK_REVEAL_FRACTION:
		# The authored final contact pair contains one open body and one wink body.
		# Reveal through the first six poses, then settle on the open body; the wink
		# is rendered later as an eye-only overlay so the paws never crouch with it.
		var reveal_step := mini(
			int(floor(clamped / RESULT_LION_PEEK_REVEAL_FRACTION * float(frame_count - 1))),
			frame_count - 2
		)
		return open_frame_index if reveal_step >= frame_count - 2 else reveal_step
	return open_frame_index


func _result_lion_peek_open_frame_index(variant: String, frame_count: int = 8) -> int:
	if variant == "peek_left":
		return frame_count - 1
	return frame_count - 2


func _result_lion_peek_is_blinking(progress: float) -> bool:
	var clamped := clampf(progress, 0.0, 1.0)
	if clamped < RESULT_LION_PEEK_REVEAL_FRACTION or clamped >= RESULT_LION_PEEK_TEASE_END_FRACTION:
		return false
	var tease_progress := inverse_lerp(
		RESULT_LION_PEEK_REVEAL_FRACTION,
		RESULT_LION_PEEK_TEASE_END_FRACTION,
		clamped
	)
	var tease_step := mini(
		int(floor(tease_progress * float(RESULT_LION_PEEK_TEASE_STEPS))),
		RESULT_LION_PEEK_TEASE_STEPS - 1
	)
	# Two adjacent hold samples form one readable blink, not two separate blinks.
	return tease_step == 2 or tease_step == 3


func _result_lion_peek_blink_texture(variant: String) -> Texture2D:
	match variant:
		"peek_left": return LION_LEFT_PEEK_BLINK
		"peek_right": return LION_RIGHT_PEEK_BLINK
		_: return LION_BOTTOM_PEEK_BLINK


func _set_result_lion_edge_frame(
	runner: TextureRect,
	support: Vector2,
	variant: String,
	texture: Texture2D
) -> void:
	if not is_instance_valid(runner):
		return
	runner.texture = texture
	_set_result_lion_runner_arm_visible(runner, false)
	_set_result_lion_peek_blink_visible(runner, false)
	match variant:
		"peek_left":
			runner.position = Vector2(
				support.x - runner.size.x * RESULT_LION_LEFT_SUPPORT_RATIO,
				support.y - runner.size.y * 0.5
			)
		"peek_right":
			runner.position = Vector2(
				support.x - runner.size.x * RESULT_LION_RIGHT_SUPPORT_RATIO,
				support.y - runner.size.y * 0.5
			)
		_:
			runner.position = Vector2(
				support.x - runner.size.x * 0.5,
				support.y - runner.size.y * RESULT_LION_BOTTOM_SUPPORT_RATIO
			)
	runner.scale = Vector2.ONE
	runner.rotation = 0.0
	runner.material = null


func _set_result_lion_entry_peek_progress(
	progress: float,
	runner: TextureRect,
	support: Vector2,
	variant: String
) -> void:
	var frames := _result_lion_entry_frames(variant, "peek")
	var frame_index := _result_lion_peek_frame_index(progress, frames.size(), variant)
	_set_result_lion_edge_frame(runner, support, variant, frames[frame_index])
	var peek_blink := runner.get_node_or_null("ResultLionPeekBlink") as TextureRect
	if peek_blink:
		peek_blink.texture = _result_lion_peek_blink_texture(variant)
	_set_result_lion_peek_blink_visible(runner, _result_lion_peek_is_blinking(progress))


func _set_result_lion_entry_brace_progress(
	progress: float,
	runner: TextureRect,
	support: Vector2,
	variant: String
) -> void:
	var frames := _result_lion_entry_frames(variant, "brace")
	var frame_index := mini(
		int(floor(clampf(progress, 0.0, 1.0) * float(frames.size()))),
		frames.size() - 1
	)
	_set_result_lion_edge_frame(runner, support, variant, frames[frame_index])


func _set_result_lion_entry_jump_progress(
	progress: float,
	runner: TextureRect,
	start: Vector2,
	curve: Vector2,
	target: Vector2,
	variant: String
) -> void:
	if not is_instance_valid(runner):
		return
	var clamped := clampf(progress, 0.0, 1.0)
	var inverse := 1.0 - clamped
	var center := inverse * inverse * start + 2.0 * inverse * clamped * curve + clamped * clamped * target
	var frames := _result_lion_entry_frames(variant, "jump")
	var frame_index := mini(
		int(floor(clamped * float(frames.size()))),
		frames.size() - 1
	)
	runner.texture = frames[frame_index]
	_set_result_lion_runner_arm_visible(runner, false)
	_set_result_lion_peek_blink_visible(runner, false)
	var registration_ratio: Vector2 = RESULT_LION_JUMP_REGISTRATION_OFFSETS.get(variant, Vector2.ZERO)
	var registration_release := 1.0 - smoothstep(
		0.0,
		RESULT_LION_JUMP_REGISTRATION_RELEASE,
		clamped
	)
	runner.position = center - runner.size * 0.5 + registration_ratio * runner.size * registration_release
	runner.scale = Vector2.ONE
	runner.rotation = 0.0
	runner.self_modulate = Color.WHITE
	runner.material = null


func _set_result_lion_land_progress(
	progress: float,
	runner: TextureRect,
	target: Vector2,
	variant: String
) -> void:
	if not is_instance_valid(runner):
		return
	var clamped := clampf(progress, 0.0, 1.0)
	var settle := sin(clamped * PI) * 7.0
	var target_scale := _result_lion_runner_target_scale(runner)
	runner.position = target - runner.size * 0.5 + Vector2(0.0, settle)
	runner.scale = Vector2.ONE * lerpf(1.0, target_scale, smoothstep(0.0, 1.0, clamped))
	runner.rotation = 0.0
	var landing_frames := _result_lion_landing_frames(variant)
	var frame_index := mini(
		int(floor(clamped * float(landing_frames.size()))),
		landing_frames.size() - 1
	)
	runner.texture = landing_frames[frame_index]
	_set_result_lion_runner_arm_visible(runner, false)
	_set_result_lion_peek_blink_visible(runner, false)
	runner.self_modulate = Color.WHITE
	runner.material = null


func _result_lion_landing_frames(_variant: String) -> Array:
	# Landing is a transform-only settle on one opaque registered pose. Morphing
	# directional art into the centre lion baked a translucent second arm/tail
	# into intermediate textures and read as a flash. Direction only controls the
	# preceding jump; after contact every route converges on this same pose.
	return [LION_KING_CENTER_LANDING]


func _result_lion_runner_target_scale(runner: TextureRect) -> float:
	if not is_instance_valid(runner) or runner.size.y <= 1.0 or not result_piece_icon:
		return 1.0
	return clampf(result_piece_icon.size.y / runner.size.y, 0.1, 1.0)


func _set_result_lion_arrival_progress(progress: float, runner: TextureRect, target: Vector2, celebration_variant: int) -> void:
	if not is_instance_valid(runner):
		return
	var clamped := clampf(progress, 0.0, 1.0)
	var target_scale := _result_lion_runner_target_scale(runner)
	# Landing owns the only positional settle. Once the runner reaches the showcase,
	# keep its transform identical to the centered lion and celebrate with the
	# independently registered arm frames only. This prevents a second up/down arc
	# from reading as a late position jump immediately before ownership handoff.
	runner.position = target - runner.size * 0.5
	runner.scale = Vector2.ONE * target_scale
	runner.rotation = 0.0
	_set_result_lion_runner_center_pose(runner)
	var runner_arm := runner.get_node_or_null("ResultLionRunnerArm") as TextureRect
	if runner_arm:
		runner_arm.texture = RESULT_LION_WAVE_ARM_FRAMES[
			_result_lion_arrival_arm_frame_index(clamped, celebration_variant)
		]
	# Hand ownership over only on the exact final frame. Even an opaque runner over
	# a fading duplicate changes antialiased outline pixels and produces a halo.
	runner.modulate.a = 0.0 if clamped >= 1.0 else 1.0
	if result_piece_icon:
		result_piece_icon.modulate.a = 1.0 if clamped >= 1.0 else 0.0


func _result_lion_arrival_arm_frame_index(progress: float, celebration_variant: int) -> int:
	var peak_frame: int = [12, 10, 8][clampi(celebration_variant, 0, 2)]
	var clamped := clampf(progress, 0.0, 1.0)
	if clamped <= 0.32:
		return clampi(roundi(lerpf(12.0, 0.0, smoothstep(0.0, 0.32, clamped))), 0, 12)
	if clamped <= 0.66:
		return clampi(roundi(lerpf(0.0, float(peak_frame), smoothstep(0.32, 0.66, clamped))), 0, peak_frame)
	return clampi(roundi(lerpf(float(peak_frame), 0.0, smoothstep(0.66, 1.0, clamped))), 0, peak_frame)


func _set_result_lion_runner_center_pose(runner: TextureRect) -> void:
	if not is_instance_valid(runner):
		return
	_set_result_lion_peek_blink_visible(runner, false)
	runner.self_modulate = Color.WHITE
	runner.texture = LION_KING_CENTER_BODY
	var runner_arm := runner.get_node_or_null("ResultLionRunnerArm") as TextureRect
	if runner_arm:
		runner_arm.texture = LION_KING_CENTER_ARM_00
		runner_arm.show()

func _set_result_lion_runner_arm_visible(runner: TextureRect, is_visible: bool) -> void:
	if not is_instance_valid(runner):
		return
	var runner_arm := runner.get_node_or_null("ResultLionRunnerArm") as TextureRect
	if runner_arm:
		runner_arm.visible = is_visible


func _set_result_lion_peek_blink_visible(runner: TextureRect, is_visible: bool) -> void:
	if not is_instance_valid(runner):
		return
	var peek_blink := runner.get_node_or_null("ResultLionPeekBlink") as TextureRect
	if peek_blink:
		peek_blink.visible = is_visible


func _finish_result_lion_entry(generation: int) -> void:
	if generation != result_lion_generation:
		return
	if is_instance_valid(result_lion_runner):
		result_lion_runner.queue_free()
	result_lion_runner = null
	result_lion_tween = null
	result_lion_entry_active = false
	if not result_piece_icon:
		return
	_show_center_result_lion_idle()
	result_piece_icon.modulate = Color.WHITE
	if visible and overlay_mode == "success":
		if _flush_pending_result_coin_animation():
			return
		if not pending_result_coin_request.is_empty():
			result_lion_animation_name = "waiting_for_reward"
		elif result_coin_tween and result_coin_tween.is_valid():
			result_lion_animation_name = "coin_toss"
		else:
			_start_random_result_lion_animation()


func _pause_result_lion_for_coins() -> void:
	if result_lion_wave_tween and result_lion_wave_tween.is_valid():
		result_lion_wave_tween.kill()
	result_lion_wave_tween = null
	result_lion_animation_name = "coin_toss"
	_show_center_result_lion_idle()


func _start_random_result_lion_animation() -> void:
	if not visible or (overlay_mode != "success" and overlay_mode != "tutorial") or not result_piece_icon:
		return
	if result_lion_wave_tween and result_lion_wave_tween.is_valid():
		result_lion_wave_tween.kill()
	result_lion_wave_tween = null
	var animation_index := randi_range(0, 2)
	if animation_index == result_lion_last_animation_index:
		animation_index = (animation_index + randi_range(1, 2)) % 3
	result_lion_last_animation_index = animation_index
	if animation_index == 0:
		_start_result_lion_arm_sequence(
			RESULT_LION_WAVE_ARM_FRAMES,
			RESULT_LION_WAVE_DURATIONS,
			RESULT_LION_WAVE_LOOP_PAUSE
		)
	elif animation_index == 1:
		_start_result_lion_cheer_sequence()
	else:
		_start_result_lion_playful_sequence()


func _start_result_lion_arm_sequence(frames: Array, durations: Array, pause: float) -> void:
	result_lion_animation_name = "wave"
	_show_center_result_lion_idle()
	result_lion_wave_tween = create_tween()
	for frame_index in range(frames.size()):
		result_lion_wave_tween.tween_callback(_set_result_lion_arm_frame.bind(frames[frame_index]))
		result_lion_wave_tween.tween_interval(float(durations[frame_index]))
	result_lion_wave_tween.tween_interval(pause)
	_append_result_lion_idle_restart(result_lion_wave_tween)


func _start_result_lion_cheer_sequence() -> void:
	result_lion_animation_name = "cheer"
	_show_center_result_lion_idle()
	result_lion_wave_tween = create_tween()
	result_lion_wave_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	result_lion_wave_tween.tween_method(_set_result_lion_cheer_progress, 0.0, 1.0, 0.82)
	_append_result_lion_idle_restart(result_lion_wave_tween)


func _start_result_lion_playful_sequence() -> void:
	result_lion_animation_name = "playful"
	_show_center_result_lion_idle()
	result_lion_wave_tween = create_tween()
	result_lion_wave_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	result_lion_wave_tween.tween_method(_set_result_lion_playful_progress, 0.0, 1.0, 0.96)
	_append_result_lion_idle_restart(result_lion_wave_tween)


func _set_result_lion_cheer_progress(progress: float) -> void:
	var clamped := clampf(progress, 0.0, 1.0)
	var outward := 1.0 - absf(clamped * 2.0 - 1.0)
	var frame_index := clampi(roundi(outward * 12.0), 0, 12)
	_set_result_lion_arm_frame(RESULT_LION_WAVE_ARM_FRAMES[frame_index])


func _set_result_lion_playful_progress(progress: float) -> void:
	var clamped := clampf(progress, 0.0, 1.0)
	var gesture := sin(clamped * PI)
	var frame_index := clampi(roundi(gesture * 7.0), 0, 7)
	_set_result_lion_arm_frame(RESULT_LION_WAVE_ARM_FRAMES[frame_index])


func _append_result_lion_idle_restart(tween: Tween) -> void:
	tween.tween_callback(_set_result_lion_idle_pose)
	tween.tween_interval(randf_range(RESULT_LION_IDLE_MIN_DURATION, RESULT_LION_IDLE_MAX_DURATION))
	tween.tween_callback(_restart_result_lion_animation_cycle)


func _set_result_lion_idle_pose() -> void:
	_show_center_result_lion_idle()
	result_lion_animation_name = "idle"


func _restart_result_lion_animation_cycle() -> void:
	result_lion_wave_tween = null
	_start_random_result_lion_animation()


func _show_center_result_lion_idle() -> void:
	if result_piece_icon:
		result_piece_icon.texture = LION_KING_CENTER_BODY
		result_piece_icon.pivot_offset = result_piece_icon.size * 0.5
		result_piece_icon.scale = Vector2.ONE
		result_piece_icon.rotation = 0.0
	if result_lion_arm_icon:
		result_lion_arm_icon.texture = LION_KING_CENTER_ARM_00
		result_lion_arm_icon.show()


func _set_result_lion_arm_frame(frame: Texture2D) -> void:
	if result_piece_icon:
		result_piece_icon.texture = LION_KING_CENTER_BODY
	if result_lion_arm_icon:
		result_lion_arm_icon.texture = frame
		result_lion_arm_icon.show()


func stop_lion_animation() -> void:
	result_lion_generation += 1
	if result_lion_tween and result_lion_tween.is_valid():
		result_lion_tween.kill()
	result_lion_tween = null
	if result_lion_wave_tween and result_lion_wave_tween.is_valid():
		result_lion_wave_tween.kill()
	result_lion_wave_tween = null
	if result_lion_entry_layer:
		for child in result_lion_entry_layer.get_children():
			child.queue_free()
	result_lion_runner = null
	result_lion_animation_name = ""
	result_lion_entry_name = ""
	result_lion_entry_active = false
	result_lion_last_animation_index = -1
	if result_piece_icon:
		_show_center_result_lion_idle()
		result_piece_icon.scale = Vector2.ONE
		result_piece_icon.rotation = 0.0
		result_piece_icon.modulate = Color.WHITE



func play_petals() -> void:
	if not result_petals_layer or not self.visible or overlay_mode != "success" or not result_is_excellent:
		return
	stop_petals()
	music_requested.emit("celebration")
	result_petals_layer.show()
	var viewport_size := self.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var receiver := _result_petal_receiver(viewport_size)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var colors: Array[Color] = _shuffled_result_petal_colors(rng)
	for index in range(RESULT_PETAL_COUNT):
		if index > 0 and index % colors.size() == 0:
			colors = _shuffled_result_petal_colors(rng)
		var petal := Sprite2D.new()
		petal.name = "Petal%02d" % index
		petal.texture = RESULT_PETAL_TEXTURE
		var scale_factor := rng.randf_range(0.48, 0.76)
		var mirror := -1.0 if rng.randf() < 0.5 else 1.0
		var base_scale := Vector2(scale_factor * rng.randf_range(0.78, 0.98) * mirror, scale_factor)
		petal.scale = base_scale
		petal.modulate = colors[index % colors.size()]
		petal.position = Vector2(rng.randf_range(8.0, viewport_size.x - 8.0), rng.randf_range(-110.0, -18.0))
		petal.rotation = rng.randf_range(-PI, PI)
		petal.visible = false
		result_petals_layer.add_child(petal)
		var delay := rng.randf_range(0.0, RESULT_PETAL_DELAY_MAX)
		var duration := rng.randf_range(RESULT_PETAL_DURATION_MIN, RESULT_PETAL_DURATION_MAX)
		var start_position := petal.position
		var end_position := receiver + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-22.0, 22.0))
		var curve_position := Vector2(
			lerpf(start_position.x, end_position.x, 0.48) + rng.randf_range(-58.0, 58.0),
			minf(end_position.y - 48.0, lerpf(start_position.y, end_position.y, 0.56))
		)
		var flutter_phase := rng.randf_range(0.0, TAU)
		var flutter_cycles := rng.randf_range(2.2, 4.2)
		var turn_direction := -1.0 if rng.randf() < 0.5 else 1.0
		var petal_tween := petal.create_tween()
		petal_tween.tween_interval(delay)
		petal_tween.tween_callback(petal.show)
		petal_tween.tween_method(
			_set_result_petal_progress.bind(
				petal,
				start_position,
				curve_position,
				end_position,
				base_scale,
				flutter_phase,
				flutter_cycles
			),
			0.0,
			1.0,
			duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		petal_tween.parallel().tween_property(
			petal,
			"rotation",
			petal.rotation + rng.randf_range(PI * 1.2, PI * 3.2) * turn_direction,
			duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		petal_tween.parallel().tween_property(
			petal,
			"modulate:a",
			0.0,
			duration * RESULT_PETAL_FADE_FRACTION
		).set_delay(duration * (1.0 - RESULT_PETAL_FADE_FRACTION))
		petal_tween.tween_callback(petal.queue_free)
		result_petal_tweens.append(petal_tween)


func _set_result_petal_progress(
	progress: float,
	petal: Sprite2D,
	start: Vector2,
	curve: Vector2,
	target: Vector2,
	base_scale: Vector2,
	flutter_phase: float,
	flutter_cycles: float
) -> void:
	if not is_instance_valid(petal):
		return
	var inverse := 1.0 - progress
	petal.position = inverse * inverse * start + 2.0 * inverse * progress * curve + progress * progress * target
	var flutter := absf(sin(flutter_phase + progress * flutter_cycles * TAU))
	var fall_envelope := sin(progress * PI)
	petal.scale = Vector2(
		base_scale.x * lerpf(0.38, 1.0, flutter),
		base_scale.y * (1.0 + fall_envelope * 0.05)
	)


func _shuffled_result_petal_colors(rng: RandomNumberGenerator) -> Array[Color]:
	var colors: Array[Color] = []
	for color in RESULT_PETAL_COLORS:
		colors.append(color)
	for index in range(colors.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held := colors[index]
		colors[index] = colors[swap_index]
		colors[swap_index] = held
	return colors


func _control_center_in_layer(control: Control, layer: Control) -> Vector2:
	if not control or not layer:
		return Vector2.ZERO
	var canvas_point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	return layer.get_global_transform_with_canvas().affine_inverse() * canvas_point


func _result_petal_receiver(viewport_size: Vector2) -> Vector2:
	if result_piece_icon and result_piece_icon.visible:
		return _control_center_in_layer(result_piece_icon, result_petals_layer)
	return Vector2(viewport_size.x * 0.5, viewport_size.y * 0.50)


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
	music_stop_requested.emit()
	if result_page_fade_tween and result_page_fade_tween.is_valid():
		result_page_fade_tween.kill()
	result_page_fade_tween = null
	modulate.a = 1.0
	stop_success_sequence()
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
