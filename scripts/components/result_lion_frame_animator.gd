class_name ResultLionFrameAnimator
extends TextureRect

const FRAME_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/lion_king_center_full_wave_00.png"),
]
const COIN_TOSS_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/lion_king_center_coin_toss_00.png"),
	preload("res://assets/ui/lion_king_center_coin_toss_01.png"),
	preload("res://assets/ui/lion_king_center_coin_toss_02.png"),
	preload("res://assets/ui/lion_king_center_coin_toss_03.png"),
	preload("res://assets/ui/lion_king_center_coin_toss_04.png"),
	preload("res://assets/ui/lion_king_center_coin_toss_05.png"),
	preload("res://assets/ui/lion_king_center_coin_toss_06.png"),
]
const IDLE_FRAME_INDEX := 0
const ACTION_SEQUENCES := {
	# Dedicated full-character art: cradle the pile, lift with both hands, release
	# overhead, then recover empty-handed. Never reverse coin-bearing frames.
	"coin_toss": [0, 1, 2, 3, 4, 5, 6],
}
const ACTION_FRAME_STEPS := {
	"coin_toss": 0.085,
}

var animation_player: AnimationPlayer
var _animation_library: AnimationLibrary


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_build_animation_library()
	set_idle_pose()


func _build_animation_library() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = NodePath("..")
	add_child(animation_player)
	_animation_library = AnimationLibrary.new()
	for action_name in ACTION_SEQUENCES:
		_add_discrete_clip(
			action_name,
			ACTION_SEQUENCES[action_name],
			float(ACTION_FRAME_STEPS[action_name])
		)
	animation_player.add_animation_library(&"", _animation_library)


func _add_discrete_clip(action_name: StringName, sequence: Array, frame_step: float) -> void:
	var animation := Animation.new()
	animation.resource_name = action_name
	animation.length = frame_step * float(sequence.size())
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(".:texture"))
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	var action_textures := _action_textures(action_name)
	for key_index in range(sequence.size()):
		animation.track_insert_key(
			track,
			float(key_index) * frame_step,
			action_textures[int(sequence[key_index])]
		)
	_animation_library.add_animation(action_name, animation)


func _action_textures(action_name: StringName) -> Array[Texture2D]:
	return COIN_TOSS_TEXTURES if action_name == &"coin_toss" else []


func play_action(action_name: String, requested_duration: float = -1.0) -> void:
	if not ACTION_SEQUENCES.has(action_name):
		return
	var authored_length := action_length(action_name)
	animation_player.speed_scale = (
		authored_length / requested_duration
		if requested_duration > 0.0
		else 1.0
	)
	animation_player.play(action_name)


func action_length(action_name: String) -> float:
	if not ACTION_SEQUENCES.has(action_name):
		return 0.0
	return float(ACTION_SEQUENCES[action_name].size()) * float(ACTION_FRAME_STEPS[action_name])


func set_idle_pose() -> void:
	if animation_player:
		animation_player.stop()
		animation_player.speed_scale = 1.0
	set_frame_index(IDLE_FRAME_INDEX)


func set_frame_index(frame_index: int) -> void:
	texture = FRAME_TEXTURES[clampi(frame_index, 0, FRAME_TEXTURES.size() - 1)]
	scale = Vector2.ONE


func set_coin_toss_progress(progress: float) -> void:
	if animation_player:
		animation_player.stop()
	var frame_index := mini(
		floori(clampf(progress, 0.0, 1.0) * float(COIN_TOSS_TEXTURES.size())),
		COIN_TOSS_TEXTURES.size() - 1
	)
	texture = COIN_TOSS_TEXTURES[frame_index]
	scale = Vector2.ONE


func current_frame_index() -> int:
	return FRAME_TEXTURES.find(texture)


func current_action_frame_index(action_name: StringName) -> int:
	return _action_textures(action_name).find(texture)


func frames_keep_fixed_registration() -> bool:
	if not scale.is_equal_approx(Vector2.ONE):
		return false
	for frame in FRAME_TEXTURES:
		if frame.get_size() != Vector2(400, 400):
			return false
	return true


func coin_toss_frames_keep_fixed_registration() -> bool:
	for frame in COIN_TOSS_TEXTURES:
		if frame.get_size() != Vector2(400, 400):
			return false
	return true
