extends CanvasLayer
class_name SplashOverlay

signal boot_started
signal splash_ready
signal splash_finished
signal splash_skipped
signal sound_requested(kind: String)

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const SPLASH_FRAME_00 = preload("res://assets/ui/splash/splash_assembly_00.svg")
const SPLASH_FRAME_01 = preload("res://assets/ui/splash/splash_assembly_01.svg")
const SPLASH_FRAME_02 = preload("res://assets/ui/splash/splash_assembly_02.svg")
const SPLASH_FRAME_03 = preload("res://assets/ui/splash/splash_assembly_03.svg")
const SPLASH_FRAME_04 = preload("res://assets/ui/splash/splash_assembly_04.svg")
const SPLASH_FRAME_05 = preload("res://assets/ui/splash/splash_assembly_05.svg")
const SPLASH_FRAME_06 = preload("res://assets/ui/splash/splash_assembly_06.svg")
const SPLASH_FRAME_07 = preload("res://assets/ui/splash/splash_assembly_07.svg")
const SPLASH_FRAME_08 = preload("res://assets/ui/splash/splash_assembly_08.svg")
const SPLASH_FRAME_09 = preload("res://assets/ui/splash/splash_assembly_09.svg")
const SPLASH_FRAME_10 = preload("res://assets/ui/splash/splash_assembly_10.svg")
const SPLASH_FRAME_11 = preload("res://assets/ui/splash/splash_assembly_11.svg")
const SPLASH_FRAME_12 = preload("res://assets/ui/splash/splash_assembly_12.svg")
const SPLASH_FRAME_13 = preload("res://assets/ui/splash/splash_assembly_13.svg")
const SPLASH_FRAME_14 = preload("res://assets/ui/splash/splash_assembly_14.svg")
const SPLASH_FRAME_15 = preload("res://assets/ui/splash/splash_assembly_15.svg")
const SPLASH_LION = preload("res://assets/ui/lion_king_center_body.svg")
const SPLASH_TITLE = preload("res://assets/ui/splash/color_king_title.svg")

const SPLASH_FRAMES := [
	SPLASH_FRAME_00,
	SPLASH_FRAME_01,
	SPLASH_FRAME_02,
	SPLASH_FRAME_03,
	SPLASH_FRAME_04,
	SPLASH_FRAME_05,
	SPLASH_FRAME_06,
	SPLASH_FRAME_07,
	SPLASH_FRAME_08,
	SPLASH_FRAME_09,
	SPLASH_FRAME_10,
	SPLASH_FRAME_11,
	SPLASH_FRAME_12,
	SPLASH_FRAME_13,
	SPLASH_FRAME_14,
	SPLASH_FRAME_15,
]
const SPLASH_FRAME_TIMES := [
	0.00, 0.20, 0.40, 0.60,
	0.80, 1.00, 1.20, 1.40,
	1.60, 1.80, 2.00, 2.20,
	2.45, 2.70, 2.95, 3.15,
]
const SPLASH_REVEAL_DURATION := 3.75
const SPLASH_REDUCED_DURATION := 1.65
const SPLASH_FINISH_DURATION := 0.35
const SPLASH_SKIP_UNLOCK_TIME := 2.45
const FRAME_SIZE := Vector2(440, 440)
const LION_FINAL_TOP := -218.0
const LION_FINAL_BOTTOM := -68.0
const LION_START_OFFSET := 24.0
const TITLE_HEIGHT := 118.0

var root: Control
var background: TextureRect
var lion_rect: TextureRect
var frame_rect: TextureRect
var title_art: TextureRect
var animation_player: AnimationPlayer
var _ready_to_enter := false
var _reveal_complete := false
var _skip_unlocked := false
var _skip_requested := false
var _finishing := false
var _finished_emitted := false


func configure() -> void:
	layer = 100
	_build_ui()
	_build_animations()
	root.hide()


func begin(reduced_motion: bool = false) -> void:
	if not root or not animation_player:
		configure()
	animation_player.stop()
	_ready_to_enter = false
	_reveal_complete = false
	_skip_unlocked = false
	_skip_requested = false
	_finishing = false
	_finished_emitted = false
	root.modulate = Color.WHITE
	root.show()
	root.grab_focus()
	frame_rect.texture = SPLASH_FRAME_00
	frame_rect.scale = Vector2.ONE
	lion_rect.modulate = Color(1, 1, 1, 0)
	title_art.modulate = Color(1, 1, 1, 0)
	boot_started.emit()
	animation_player.play(&"splash_reduced" if reduced_motion else &"splash_brand_reveal")


func mark_ready_to_enter() -> void:
	_ready_to_enter = true
	if _reveal_complete:
		_start_finish()


func preview_frame(frame_index: int) -> void:
	if not root:
		configure()
	var resolved_index := clampi(frame_index, 0, SPLASH_FRAMES.size() - 1)
	frame_rect.texture = SPLASH_FRAMES[resolved_index]
	lion_rect.modulate = Color.WHITE if resolved_index == SPLASH_FRAMES.size() - 1 else Color(1, 1, 1, 0)
	title_art.modulate = Color.WHITE if resolved_index == SPLASH_FRAMES.size() - 1 else Color(1, 1, 1, 0)
	root.modulate = Color.WHITE
	root.show()


func current_frame_index() -> int:
	return SPLASH_FRAMES.find(frame_rect.texture) if frame_rect else -1


func _build_ui() -> void:
	root = Control.new()
	root.name = "SplashRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.focus_mode = Control.FOCUS_ALL
	root.gui_input.connect(_on_gui_input)
	root.resized.connect(_apply_safe_layout)
	add_child(root)

	background = TextureRect.new()
	background.name = "SplashBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = UITokensScript.royal_screen_gradient_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	lion_rect = TextureRect.new()
	lion_rect.name = "SplashLion"
	lion_rect.set_anchors_preset(Control.PRESET_CENTER)
	lion_rect.offset_left = -75
	lion_rect.offset_top = LION_FINAL_TOP
	lion_rect.offset_right = 75
	lion_rect.offset_bottom = LION_FINAL_BOTTOM
	lion_rect.texture = SPLASH_LION
	lion_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lion_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lion_rect)

	frame_rect = TextureRect.new()
	frame_rect.name = "SplashFrame"
	frame_rect.set_anchors_preset(Control.PRESET_CENTER)
	frame_rect.offset_left = -FRAME_SIZE.x * 0.5
	frame_rect.offset_top = -FRAME_SIZE.y * 0.5 + 18
	frame_rect.offset_right = FRAME_SIZE.x * 0.5
	frame_rect.offset_bottom = FRAME_SIZE.y * 0.5 + 18
	frame_rect.pivot_offset = FRAME_SIZE * 0.5
	frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame_rect)

	title_art = TextureRect.new()
	title_art.name = "SplashTitle"
	title_art.texture = SPLASH_TITLE
	title_art.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_art.offset_left = 36
	title_art.offset_right = -36
	title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_art)
	_apply_safe_layout()

	animation_player = AnimationPlayer.new()
	animation_player.name = "SplashAnimationPlayer"
	animation_player.root_node = NodePath("..")
	animation_player.animation_finished.connect(_on_animation_finished)
	add_child(animation_player)


func _apply_safe_layout() -> void:
	if not root or not title_art:
		return
	var safe := UITokensScript.display_safe_insets(root.size)
	title_art.offset_top = maxf(78.0, safe.y + 38.0)
	title_art.offset_bottom = title_art.offset_top + TITLE_HEIGHT


func _build_animations() -> void:
	var library := AnimationLibrary.new()
	library.add_animation(&"splash_brand_reveal", _brand_reveal_animation())
	library.add_animation(&"splash_reduced", _reduced_animation())
	library.add_animation(&"splash_finish", _finish_animation())
	animation_player.add_animation_library(&"", library)


func _brand_reveal_animation() -> Animation:
	var animation := Animation.new()
	animation.length = SPLASH_REVEAL_DURATION
	animation.loop_mode = Animation.LOOP_NONE
	_add_frame_track(animation, SPLASH_FRAME_TIMES, range(SPLASH_FRAMES.size()))
	_add_root_fade_in_track(animation, 0.24)
	_add_title_track(animation, 2.85, 3.15)
	_add_lion_track(animation, 2.85, 3.15)
	var scale_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(scale_track, NodePath("SplashRoot/SplashFrame:scale"))
	animation.track_set_interpolation_type(scale_track, Animation.INTERPOLATION_CUBIC)
	animation.track_insert_key(scale_track, 0.00, Vector2.ONE)
	animation.track_insert_key(scale_track, 2.20, Vector2.ONE)
	animation.track_insert_key(scale_track, 2.36, Vector2.ONE * 1.025)
	animation.track_insert_key(scale_track, 2.53, Vector2.ONE * 0.992)
	animation.track_insert_key(scale_track, 2.70, Vector2.ONE)
	_add_method_key(animation, 0.60, &"_animation_sound", ["snap"])
	_add_method_key(animation, 1.20, &"_animation_sound", ["snap"])
	_add_method_key(animation, 2.20, &"_animation_sound", ["snap_final"])
	_add_method_key(animation, 2.45, &"_animation_sound", ["assembly_complete"])
	_add_method_key(animation, 3.15, &"_animation_sound", ["crown"])
	_add_method_key(animation, SPLASH_SKIP_UNLOCK_TIME, &"_unlock_skip")
	return animation


func _reduced_animation() -> Animation:
	var animation := Animation.new()
	animation.length = SPLASH_REDUCED_DURATION
	animation.loop_mode = Animation.LOOP_NONE
	_add_frame_track(
		animation,
		[0.00, 0.55, 1.05],
		[0, 12, 15]
	)
	_add_root_fade_in_track(animation, 0.24)
	_add_title_track(animation, 1.00, 1.30)
	_add_lion_track(animation, 1.00, 1.30)
	_add_method_key(animation, 0.55, &"_animation_sound", ["assembly_complete"])
	_add_method_key(animation, 1.05, &"_animation_sound", ["crown"])
	_add_method_key(animation, 1.05, &"_unlock_skip")
	return animation


func _finish_animation() -> Animation:
	var animation := Animation.new()
	animation.length = SPLASH_FINISH_DURATION
	animation.loop_mode = Animation.LOOP_NONE
	var fade_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(fade_track, NodePath("SplashRoot:modulate"))
	animation.track_set_interpolation_type(fade_track, Animation.INTERPOLATION_LINEAR)
	animation.track_insert_key(fade_track, 0.00, Color.WHITE)
	animation.track_insert_key(fade_track, SPLASH_FINISH_DURATION, Color(1, 1, 1, 0))
	return animation


func _add_frame_track(animation: Animation, times: Array, frame_indices: Array) -> void:
	var frame_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(frame_track, NodePath("SplashRoot/SplashFrame:texture"))
	animation.track_set_interpolation_type(frame_track, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(frame_track, Animation.UPDATE_DISCRETE)
	for key_index in range(mini(times.size(), frame_indices.size())):
		animation.track_insert_key(
			frame_track,
			times[key_index],
			SPLASH_FRAMES[int(frame_indices[key_index])]
		)


func _add_root_fade_in_track(animation: Animation, end_time: float) -> void:
	var fade_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(fade_track, NodePath("SplashRoot:modulate"))
	animation.track_set_interpolation_type(fade_track, Animation.INTERPOLATION_LINEAR)
	animation.track_insert_key(fade_track, 0.00, Color(1, 1, 1, 0))
	animation.track_insert_key(fade_track, end_time, Color.WHITE)


func _add_title_track(animation: Animation, start_time: float, end_time: float) -> void:
	var title_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(title_track, NodePath("SplashRoot/SplashTitle:modulate"))
	animation.track_set_interpolation_type(title_track, Animation.INTERPOLATION_LINEAR)
	animation.track_insert_key(title_track, 0.00, Color(1, 1, 1, 0))
	animation.track_insert_key(title_track, start_time, Color(1, 1, 1, 0))
	animation.track_insert_key(title_track, end_time, Color.WHITE)


func _add_lion_track(animation: Animation, start_time: float, end_time: float) -> void:
	var modulate_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(modulate_track, NodePath("SplashRoot/SplashLion:modulate"))
	animation.track_set_interpolation_type(modulate_track, Animation.INTERPOLATION_LINEAR)
	animation.track_insert_key(modulate_track, 0.00, Color(1, 1, 1, 0))
	animation.track_insert_key(modulate_track, start_time, Color(1, 1, 1, 0))
	animation.track_insert_key(modulate_track, end_time, Color.WHITE)
	for property_name in ["offset_top", "offset_bottom"]:
		var position_track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(
			position_track,
			NodePath("SplashRoot/SplashLion:%s" % property_name)
		)
		animation.track_set_interpolation_type(position_track, Animation.INTERPOLATION_CUBIC)
		var final_value: float = LION_FINAL_TOP if property_name == "offset_top" else LION_FINAL_BOTTOM
		animation.track_insert_key(position_track, 0.00, final_value + LION_START_OFFSET)
		animation.track_insert_key(position_track, start_time, final_value + LION_START_OFFSET)
		animation.track_insert_key(position_track, end_time, final_value)


func _add_method_key(animation: Animation, time: float, method: StringName, args: Array = []) -> void:
	var method_track := -1
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) == Animation.TYPE_METHOD:
			method_track = track_index
			break
	if method_track < 0:
		method_track = animation.add_track(Animation.TYPE_METHOD)
		animation.track_set_path(method_track, NodePath("."))
	animation.track_insert_key(method_track, time, {"method": method, "args": args})


func _animation_sound(kind: String) -> void:
	if not _finishing:
		sound_requested.emit(kind)


func _unlock_skip() -> void:
	_skip_unlocked = true


func _on_gui_input(event: InputEvent) -> void:
	var pressed: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
		or (event is InputEventKey and event.pressed and not event.echo)
	)
	if pressed and _skip_unlocked and not _skip_requested and not _finishing:
		_skip_requested = true
		splash_skipped.emit()
		if _ready_to_enter:
			_start_finish()
		else:
			_show_stable_final()
		root.accept_event()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"splash_brand_reveal" or animation_name == &"splash_reduced":
		_reveal_complete = true
		_skip_unlocked = true
		splash_ready.emit()
		if _ready_to_enter:
			_start_finish()
	elif animation_name == &"splash_finish":
		_finish_once()


func _start_finish() -> void:
	if _finishing or _finished_emitted:
		return
	_finishing = true
	animation_player.play(&"splash_finish")


func _show_stable_final() -> void:
	animation_player.stop()
	frame_rect.texture = SPLASH_FRAME_15
	frame_rect.scale = Vector2.ONE
	lion_rect.offset_top = LION_FINAL_TOP
	lion_rect.offset_bottom = LION_FINAL_BOTTOM
	lion_rect.modulate = Color.WHITE
	title_art.modulate = Color.WHITE
	root.modulate = Color.WHITE
	_reveal_complete = true
	_skip_unlocked = true
	splash_ready.emit()


func _finish_once() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	root.hide()
	splash_finished.emit()
