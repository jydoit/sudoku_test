extends CanvasLayer
class_name SplashOverlay

signal boot_started
signal splash_ready
signal splash_finished
signal splash_skipped
signal sound_requested(kind: String)

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const SplashAssemblyBoardScript = preload("res://scripts/overlays/splash_assembly_board.gd")
const SPLASH_LION = preload("res://assets/ui/splash/splash_lion_peek.png")
const SPLASH_TITLE = preload("res://assets/ui/splash/color_king_title.svg")

const SPLASH_REVEAL_DURATION := 5.55
const SPLASH_REDUCED_DURATION := 1.65
const SPLASH_FINISH_DURATION := 0.45
const SPLASH_SKIP_UNLOCK_TIME := 3.94
const SPLASH_PIECE_COUNT := 5
const SPLASH_ANIMATED_PIECE_COUNT := 2
const SPLASH_KING_COUNT := 6
const PREVIEW_STAGE_COUNT := 7
const ASSEMBLY_SIZE := Vector2(440, 440)
const LION_FINAL_TOP := -306.0
const LION_FINAL_BOTTOM := -132.0
const LION_START_OFFSET := 42.0
const TITLE_HEIGHT := 104.0
const SPLASH_SKY_TOP := Color("#4A82AA")
const SPLASH_SKY_MIDDLE := Color("#6AAED7")
const SPLASH_SKY_HAZE := Color("#C4DFEA")
const SPLASH_SKY_BOTTOM := Color("#A9D1E1")

var root: Control
var background: TextureRect
var lion_rect: TextureRect
var assembly_board
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
	assembly_board.reset_visuals()
	lion_rect.offset_top = LION_FINAL_TOP + LION_START_OFFSET
	lion_rect.offset_bottom = LION_FINAL_BOTTOM + LION_START_OFFSET
	lion_rect.modulate = Color(1, 1, 1, 0)
	title_art.modulate = Color(1, 1, 1, 0)
	boot_started.emit()
	animation_player.play(&"splash_reduced" if reduced_motion else &"splash_brand_reveal")


func mark_ready_to_enter() -> void:
	_ready_to_enter = true
	if _reveal_complete:
		_start_finish()


func preview_stage(stage_index: int) -> void:
	if not root:
		configure()
	var resolved := clampi(stage_index, 0, PREVIEW_STAGE_COUNT - 1)
	assembly_board.reset_visuals()
	if resolved <= SPLASH_ANIMATED_PIECE_COUNT:
		assembly_board.assembly_progress = float(resolved)
	else:
		assembly_board.assembly_progress = float(SPLASH_ANIMATED_PIECE_COUNT)
	if resolved >= 3:
		assembly_board.flatten_amount = 1.0
	if resolved == 4:
		assembly_board.king_reveal_progress = 3.0
	elif resolved >= 5:
		assembly_board.king_reveal_progress = float(SPLASH_KING_COUNT)
	if resolved >= 5:
		assembly_board.victory_progress = 1.0
	var show_brand := resolved == PREVIEW_STAGE_COUNT - 1
	lion_rect.offset_top = LION_FINAL_TOP
	lion_rect.offset_bottom = LION_FINAL_BOTTOM
	lion_rect.modulate = Color.WHITE if show_brand else Color(1, 1, 1, 0)
	title_art.modulate = Color.WHITE if show_brand else Color(1, 1, 1, 0)
	root.modulate = Color.WHITE
	root.show()


func current_placed_piece_count() -> int:
	return assembly_board.completed_piece_count()


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
	background.texture = _splash_background_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	lion_rect = TextureRect.new()
	lion_rect.name = "SplashLion"
	lion_rect.set_anchors_preset(Control.PRESET_CENTER)
	lion_rect.offset_left = -87
	lion_rect.offset_top = LION_FINAL_TOP
	lion_rect.offset_right = 87
	lion_rect.offset_bottom = LION_FINAL_BOTTOM
	lion_rect.texture = SPLASH_LION
	lion_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lion_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lion_rect.z_index = 2
	root.add_child(lion_rect)

	assembly_board = SplashAssemblyBoardScript.new()
	assembly_board.name = "SplashAssembly"
	assembly_board.set_anchors_preset(Control.PRESET_CENTER)
	assembly_board.offset_left = -ASSEMBLY_SIZE.x * 0.5
	assembly_board.offset_top = -ASSEMBLY_SIZE.y * 0.5 + 18
	assembly_board.offset_right = ASSEMBLY_SIZE.x * 0.5
	assembly_board.offset_bottom = ASSEMBLY_SIZE.y * 0.5 + 18
	assembly_board.pivot_offset = ASSEMBLY_SIZE * 0.5
	assembly_board.z_index = 1
	root.add_child(assembly_board)

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
	title_art.z_index = 3
	root.add_child(title_art)
	_apply_safe_layout()

	animation_player = AnimationPlayer.new()
	animation_player.name = "SplashAnimationPlayer"
	animation_player.root_node = NodePath("..")
	animation_player.animation_finished.connect(_on_animation_finished)
	add_child(animation_player)


func _splash_background_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.52, 0.76, 0.90, 1.0])
	gradient.colors = PackedColorArray([
		SPLASH_SKY_TOP,
		SPLASH_SKY_MIDDLE,
		SPLASH_SKY_HAZE,
		UITokensScript.ROYAL_FLOOR,
		UITokensScript.ROYAL_FLOOR,
		SPLASH_SKY_BOTTOM,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1
	texture.height = 256
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	return texture


func _apply_safe_layout() -> void:
	if not root or not title_art:
		return
	var safe := UITokensScript.display_safe_insets(root.size)
	title_art.offset_top = maxf(60.0, safe.y + 24.0)
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
	_add_root_fade_in_track(animation, 0.24)
	_add_value_track(
		animation,
		NodePath("SplashRoot/SplashAssembly:assembly_progress"),
		[0.00, 0.24, 2.00],
		[0.0, 0.0, float(SPLASH_ANIMATED_PIECE_COUNT)],
		Animation.INTERPOLATION_LINEAR
	)
	_add_value_track(
		animation,
		NodePath("SplashRoot/SplashAssembly:flatten_amount"),
		[0.00, 2.00, 2.34],
		[0.0, 0.0, 1.0],
		Animation.INTERPOLATION_CUBIC
	)
	_add_value_track(
		animation,
		NodePath("SplashRoot/SplashAssembly:king_reveal_progress"),
		[0.00, 2.36, 3.16],
		[0.0, 0.0, float(SPLASH_KING_COUNT)],
		Animation.INTERPOLATION_LINEAR
	)
	_add_value_track(
		animation,
		NodePath("SplashRoot/SplashAssembly:victory_progress"),
		[0.00, 3.16, 3.86],
		[0.0, 0.0, 1.0],
		Animation.INTERPOLATION_LINEAR
	)
	_add_title_track(animation, 3.22, 3.86)
	_add_lion_track(animation, 3.22, 3.86)
	var scale_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(scale_track, NodePath("SplashRoot/SplashAssembly:scale"))
	animation.track_set_interpolation_type(scale_track, Animation.INTERPOLATION_CUBIC)
	animation.track_insert_key(scale_track, 0.00, Vector2.ONE)
	animation.track_insert_key(scale_track, 2.00, Vector2.ONE)
	animation.track_insert_key(scale_track, 2.17, Vector2.ONE * 1.025)
	animation.track_insert_key(scale_track, 2.37, Vector2.ONE * 0.992)
	animation.track_insert_key(scale_track, 2.55, Vector2.ONE)
	_add_method_key(animation, 1.12, &"_animation_sound", ["crystal_place"])
	_add_method_key(animation, 2.00, &"_animation_sound", ["crystal_place_final"])
	_add_method_key(animation, 2.34, &"_animation_sound", ["assembly_complete"])
	_add_method_key(animation, 3.16, &"_animation_sound", ["crown"])
	_add_method_key(animation, SPLASH_SKIP_UNLOCK_TIME, &"_unlock_skip")
	return animation


func _reduced_animation() -> Animation:
	var animation := Animation.new()
	animation.length = SPLASH_REDUCED_DURATION
	animation.loop_mode = Animation.LOOP_NONE
	_add_root_fade_in_track(animation, 0.24)
	_add_discrete_track(
		animation,
		NodePath("SplashRoot/SplashAssembly:assembly_progress"),
		[0.00, 0.52],
		[0.0, float(SPLASH_ANIMATED_PIECE_COUNT)]
	)
	_add_value_track(
		animation,
		NodePath("SplashRoot/SplashAssembly:flatten_amount"),
		[0.00, 0.52, 0.82],
		[0.0, 0.0, 1.0],
		Animation.INTERPOLATION_LINEAR
	)
	_add_discrete_track(
		animation,
		NodePath("SplashRoot/SplashAssembly:king_reveal_progress"),
		[0.00, 0.94],
		[0.0, float(SPLASH_KING_COUNT)]
	)
	_add_discrete_track(
		animation,
		NodePath("SplashRoot/SplashAssembly:victory_progress"),
		[0.00, 1.04],
		[0.0, 1.0]
	)
	_add_title_track(animation, 0.88, 1.24)
	_add_lion_track(animation, 0.88, 1.24)
	_add_method_key(animation, 0.55, &"_animation_sound", ["assembly_complete"])
	_add_method_key(animation, 1.00, &"_animation_sound", ["crown"])
	_add_method_key(animation, 1.04, &"_unlock_skip")
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


func _add_value_track(
	animation: Animation,
	path: NodePath,
	times: Array,
	values: Array,
	interpolation: Animation.InterpolationType
) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_set_interpolation_type(track, interpolation)
	for key_index in range(mini(times.size(), values.size())):
		animation.track_insert_key(track, float(times[key_index]), values[key_index])


func _add_discrete_track(animation: Animation, path: NodePath, times: Array, values: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for key_index in range(mini(times.size(), values.size())):
		animation.track_insert_key(track, float(times[key_index]), values[key_index])


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
		animation.track_set_path(position_track, NodePath("SplashRoot/SplashLion:%s" % property_name))
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
	assembly_board.show_stable_final()
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
