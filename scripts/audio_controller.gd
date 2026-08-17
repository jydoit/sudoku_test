extends Node
class_name AudioController

const MARK_STREAMS = [
	preload("res://assets/audio/candidates/metal_mark_01.wav"),
	preload("res://assets/audio/candidates/metal_mark_02.wav")
]
const ERASE_STREAM = preload("res://assets/audio/candidates/paper_erase.wav")
const CORRECT_STREAM = preload("res://assets/audio/candidates/wood_correct.wav")
const FINAL_CORRECT_STREAM = preload("res://assets/audio/candidates/wood_correct_final.wav")
const WRONG_HEART_STREAM = preload("res://assets/audio/candidates/wood_wrong_heart.wav")
const HINT_STREAM = preload("res://assets/audio/candidates/wood_hint.wav")
const CLEAR_STREAM = preload("res://assets/audio/candidates/paper_clear.wav")
const VICTORY_STREAM = preload("res://assets/audio/candidates/wood_victory_v2.wav")
const UI_TAP_STREAM = preload("res://assets/audio/candidates/wood_ui_tap.wav")
const CROWN_REVEAL_STREAM = preload("res://assets/audio/candidates/crown_reveal.wav")
const BLOCK_PICKUP_STREAMS = [
	preload("res://assets/audio/candidates/block_pickup_01.wav"),
	preload("res://assets/audio/candidates/block_pickup_02.wav")
]
const BLOCK_SNAP_STREAM = preload("res://assets/audio/candidates/block_snap.wav")
const BLOCK_PLACE_SMALL_STREAM = preload("res://assets/audio/candidates/block_place_small.wav")
const BLOCK_PLACE_MEDIUM_STREAM = preload("res://assets/audio/candidates/block_place_medium.wav")
const BLOCK_PLACE_LARGE_STREAM = preload("res://assets/audio/candidates/block_place_large.wav")
const BLOCK_REJECT_STREAM = preload("res://assets/audio/candidates/block_reject.wav")
const BLOCK_RETURN_STREAM = preload("res://assets/audio/candidates/block_return.wav")
const BLOCK_REGION_COMPLETE_STREAM = preload("res://assets/audio/candidates/block_region_complete.wav")
const BLOCK_DEADLOCK_STREAM = preload("res://assets/audio/candidates/block_deadlock.wav")
const BLOCK_REVIVE_STREAM = preload("res://assets/audio/candidates/block_revive.wav")
const BLOCK_ASSEMBLY_COMPLETE_STREAM = preload("res://assets/audio/candidates/block_assembly_complete.wav")
const BLOCK_CLEAR_STREAM = preload("res://assets/audio/candidates/block_clear.wav")
const COIN_ARRIVE_STREAM = preload("res://assets/audio/candidates/coin_arrive.wav")
const COIN_REEL_STREAM = preload("res://assets/audio/candidates/coin_reel.wav")
const COIN_SETTLE_STREAM = preload("res://assets/audio/candidates/coin_settle.wav")
const RESULT_MUSIC_PATHS := {
	"celebration": "res://assets/audio/candidates/result_cheerful.wav",
}

const GAMEPLAY_POOL_SIZE := 7
const UI_POOL_SIZE := 4
const CELEBRATION_POOL_SIZE := 2
const MARK_INTERVAL_MS := 110
const ERASE_INTERVAL_MS := 105
const SNAP_INTERVAL_MS := 90
const DEADLOCK_INTERVAL_MS := 500
const CELEBRATION_DUCK_DB := -3.5
const CELEBRATION_DUCK_IN := 0.10
const CELEBRATION_DUCK_OUT := 0.30
const GAMEPLAY_BUS := &"GameplaySFX"
const UI_BUS := &"UISFX"
const CELEBRATION_BUS := &"CelebrationSFX"
const RESULT_MUSIC_BUS := &"ResultMusic"
const RESULT_MUSIC_VOLUME_DB := -5.0
const RESULT_MUSIC_SILENT_DB := -42.0
const RESULT_MUSIC_FADE_IN := 0.28
const RESULT_MUSIC_FADE_OUT := 0.55
const MASTER_LIMITER_CEILING_DB := -1.0

var gameplay_players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []
var celebration_players: Array[AudioStreamPlayer] = []
var next_gameplay_player := 0
var next_ui_player := 0
var next_celebration_player := 0
var last_mark_ms := -MARK_INTERVAL_MS
var last_erase_ms := -ERASE_INTERVAL_MS
var last_snap_ms := -SNAP_INTERVAL_MS
var last_deadlock_ms := -DEADLOCK_INTERVAL_MS
var celebration_duck_tween: Tween
var result_music_player: AudioStreamPlayer
var result_music_tween: Tween
var result_music_streams: Dictionary = {}
var result_music_kind := ""
var music_enabled := true
var sfx_enabled := true
var haptics_enabled := true


func _ready() -> void:
	_ensure_bus(GAMEPLAY_BUS)
	_ensure_bus(UI_BUS)
	_ensure_bus(CELEBRATION_BUS)
	_ensure_bus(RESULT_MUSIC_BUS)
	_ensure_master_limiter()
	gameplay_players = _build_pool(GAMEPLAY_POOL_SIZE, GAMEPLAY_BUS)
	ui_players = _build_pool(UI_POOL_SIZE, UI_BUS)
	celebration_players = _build_pool(CELEBRATION_POOL_SIZE, CELEBRATION_BUS)
	result_music_player = AudioStreamPlayer.new()
	result_music_player.bus = RESULT_MUSIC_BUS
	add_child(result_music_player)
	_apply_audio_preferences()
	if not music_enabled:
		stop_result_music(true)


func set_audio_preferences(enable_music: bool, enable_sfx: bool, enable_haptics: bool) -> void:
	music_enabled = enable_music
	sfx_enabled = enable_sfx
	haptics_enabled = enable_haptics
	_apply_audio_preferences()
	if not music_enabled:
		stop_result_music(true)


func audio_preferences() -> Dictionary:
	return {
		"musicEnabled": music_enabled,
		"sfxEnabled": sfx_enabled,
		"hapticsEnabled": haptics_enabled,
	}


func play_mark() -> void:
	var now := Time.get_ticks_msec()
	if now - last_mark_ms < MARK_INTERVAL_MS:
		return
	last_mark_ms = now
	var stream = MARK_STREAMS[randi() % MARK_STREAMS.size()]
	_play_gameplay(stream, -1.0, randf_range(0.98, 1.02))


func play_erase(throttled: bool = false) -> void:
	if throttled:
		var now := Time.get_ticks_msec()
		if now - last_erase_ms < ERASE_INTERVAL_MS:
			return
		last_erase_ms = now
	_play_gameplay(ERASE_STREAM, -1.0, randf_range(0.99, 1.01))


func play_correct() -> void:
	play_crown_place(1, 1, false)


func play_crown_place(found_count: int, total_count: int, completes_level: bool = false) -> void:
	var denominator := maxi(1, total_count - 1)
	var progress := clampf(float(maxi(1, found_count) - 1) / float(denominator), 0.0, 1.0)
	var pitch := lerpf(0.98, 1.10, progress)
	# The victory phrase owns the long tail on the final crown. Keep this as a
	# compact tactile confirmation so both sounds remain readable.
	if completes_level:
		_play_gameplay(FINAL_CORRECT_STREAM, -3.0, pitch)
	else:
		_play_gameplay(CORRECT_STREAM, 0.5, pitch)


func play_crown_reveal() -> void:
	_play_gameplay(CROWN_REVEAL_STREAM, 0.0, 1.0)


func play_wrong_crown(heart_lost: bool = true) -> void:
	# Formal levels always consume a heart on a wrong crown. Keep the argument
	# for a stable semantic API while using one authored, non-overlapping phrase.
	var pitch := 1.0 if heart_lost else 1.04
	_play_gameplay(WRONG_HEART_STREAM, 0.0, pitch)


func play_hint() -> void:
	_play_gameplay(HINT_STREAM, -0.5, 1.02)


func play_clear() -> void:
	_play_gameplay(CLEAR_STREAM, -1.5)


func play_victory() -> void:
	_play_celebration(VICTORY_STREAM, 0.0)


func play_ui_tap() -> void:
	_play_ui(UI_TAP_STREAM, -2.0)


func play_block_pickup(piece_size: int = 1) -> void:
	var stream = BLOCK_PICKUP_STREAMS[randi() % BLOCK_PICKUP_STREAMS.size()]
	var pitch := clampf(1.05 - float(maxi(1, piece_size) - 1) * 0.018, 0.92, 1.05)
	_play_gameplay(stream, -2.0, pitch)


func play_block_snap() -> void:
	var now := Time.get_ticks_msec()
	if now - last_snap_ms < SNAP_INTERVAL_MS:
		return
	last_snap_ms = now
	_play_gameplay(BLOCK_SNAP_STREAM, -3.0, randf_range(0.98, 1.02))


func play_block_place(piece_size: int = 1) -> void:
	var stream: AudioStream = BLOCK_PLACE_SMALL_STREAM
	if piece_size >= 6:
		stream = BLOCK_PLACE_LARGE_STREAM
	elif piece_size >= 3:
		stream = BLOCK_PLACE_MEDIUM_STREAM
	_play_gameplay(stream, -0.5, randf_range(0.98, 1.02))


func play_block_reject() -> void:
	_play_gameplay(BLOCK_REJECT_STREAM, -2.0)


func play_block_return() -> void:
	_play_gameplay(BLOCK_RETURN_STREAM, -1.5, randf_range(0.98, 1.02))


func play_block_region_complete(piece_size: int = 0) -> void:
	# Keep the physical landing readable, then layer the region's rising phrase.
	if piece_size > 0:
		play_block_place(piece_size)
	_play_gameplay(BLOCK_REGION_COMPLETE_STREAM, 0.0)


func play_block_deadlock() -> void:
	var now := Time.get_ticks_msec()
	if now - last_deadlock_ms < DEADLOCK_INTERVAL_MS:
		return
	last_deadlock_ms = now
	_play_celebration(BLOCK_DEADLOCK_STREAM, -1.0)


func play_block_revive() -> void:
	_play_celebration(BLOCK_REVIVE_STREAM, 0.0)


func play_assembly_complete() -> void:
	_play_celebration(BLOCK_ASSEMBLY_COMPLETE_STREAM, 0.0)


func play_block_clear() -> void:
	_play_gameplay(BLOCK_CLEAR_STREAM, -1.5)


func play_result_sound(kind: String) -> void:
	match kind:
		"coin_arrive":
			_play_ui(COIN_ARRIVE_STREAM, -1.5, randf_range(0.99, 1.01))
		"coin_reel":
			_play_ui(COIN_REEL_STREAM, -0.5)
		"coin_settle":
			_play_ui(COIN_SETTLE_STREAM, -1.0)


func play_result_music(kind: String) -> void:
	if not result_music_player or not music_enabled or not RESULT_MUSIC_PATHS.has(kind):
		return
	if result_music_player.playing and result_music_kind == kind:
		return
	if result_music_tween and result_music_tween.is_valid():
		result_music_tween.kill()
	result_music_player.stop()
	if not result_music_streams.has(kind):
		var stream := load(str(RESULT_MUSIC_PATHS[kind])) as AudioStream
		if not stream:
			return
		result_music_streams[kind] = stream
	result_music_kind = kind
	result_music_player.stream = result_music_streams[kind]
	result_music_player.volume_db = RESULT_MUSIC_SILENT_DB
	result_music_player.play()
	result_music_tween = create_tween()
	result_music_tween.tween_property(
		result_music_player,
		"volume_db",
		RESULT_MUSIC_VOLUME_DB,
		RESULT_MUSIC_FADE_IN
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func stop_result_music(immediate: bool = false) -> void:
	result_music_kind = ""
	if result_music_tween and result_music_tween.is_valid():
		result_music_tween.kill()
	result_music_tween = null
	if not result_music_player or not result_music_player.playing:
		return
	if immediate:
		result_music_player.stop()
		return
	result_music_tween = create_tween()
	result_music_tween.tween_property(
		result_music_player,
		"volume_db",
		RESULT_MUSIC_SILENT_DB,
		RESULT_MUSIC_FADE_OUT
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	result_music_tween.tween_callback(result_music_player.stop)

func _play_gameplay(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	next_gameplay_player = _play_from_pool(gameplay_players, next_gameplay_player, stream, volume_db, pitch_scale)


func _play_ui(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	next_ui_player = _play_from_pool(ui_players, next_ui_player, stream, volume_db, pitch_scale)


func _play_celebration(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	next_celebration_player = _play_from_pool(celebration_players, next_celebration_player, stream, volume_db, pitch_scale)
	_begin_celebration_duck(stream.get_length() / maxf(0.01, pitch_scale))


func _play_from_pool(
	pool: Array[AudioStreamPlayer],
	next_index: int,
	stream: AudioStream,
	volume_db: float,
	pitch_scale: float
) -> int:
	if pool.is_empty():
		return 0
	var selected_index := next_index % pool.size()
	for offset in range(pool.size()):
		var candidate_index := (next_index + offset) % pool.size()
		if not pool[candidate_index].playing:
			selected_index = candidate_index
			break
	var player := pool[selected_index]
	if player.playing:
		player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	return (selected_index + 1) % pool.size()


func _build_pool(size: int, bus_name: StringName) -> Array[AudioStreamPlayer]:
	var pool: Array[AudioStreamPlayer] = []
	for _index in range(size):
		var player := AudioStreamPlayer.new()
		player.bus = bus_name
		add_child(player)
		pool.append(player)
	return pool


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus_name)


func _ensure_master_limiter() -> void:
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index < 0:
		return
	for effect_index in range(AudioServer.get_bus_effect_count(master_index)):
		if AudioServer.get_bus_effect(master_index, effect_index) is AudioEffectLimiter:
			return
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = MASTER_LIMITER_CEILING_DB
	limiter.threshold_db = -6.0
	limiter.soft_clip_db = 2.0
	AudioServer.add_bus_effect(master_index, limiter)


func _apply_audio_preferences() -> void:
	for bus_name in [GAMEPLAY_BUS, UI_BUS, CELEBRATION_BUS]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_mute(bus_index, not sfx_enabled)
	var music_bus_index := AudioServer.get_bus_index(RESULT_MUSIC_BUS)
	if music_bus_index >= 0:
		AudioServer.set_bus_mute(music_bus_index, not music_enabled)


func _begin_celebration_duck(duration: float) -> void:
	var gameplay_bus_index := AudioServer.get_bus_index(GAMEPLAY_BUS)
	if gameplay_bus_index < 0:
		return
	if celebration_duck_tween and celebration_duck_tween.is_valid():
		celebration_duck_tween.kill()
	AudioServer.set_bus_volume_db(gameplay_bus_index, 0.0)
	celebration_duck_tween = create_tween()
	celebration_duck_tween.tween_method(
		_set_gameplay_bus_volume.bind(gameplay_bus_index),
		0.0,
		CELEBRATION_DUCK_DB,
		CELEBRATION_DUCK_IN
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	celebration_duck_tween.tween_interval(maxf(0.0, duration - CELEBRATION_DUCK_IN - CELEBRATION_DUCK_OUT))
	celebration_duck_tween.tween_method(
		_set_gameplay_bus_volume.bind(gameplay_bus_index),
		CELEBRATION_DUCK_DB,
		0.0,
		CELEBRATION_DUCK_OUT
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	celebration_duck_tween.finished.connect(func() -> void:
		AudioServer.set_bus_volume_db(gameplay_bus_index, 0.0)
		celebration_duck_tween = null
	)


func _set_gameplay_bus_volume(value: float, bus_index: int) -> void:
	if bus_index >= 0 and bus_index < AudioServer.bus_count:
		AudioServer.set_bus_volume_db(bus_index, value)
