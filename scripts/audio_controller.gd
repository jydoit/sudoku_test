extends Node
class_name AudioController

const MARK_STREAMS = [
	preload("res://assets/audio/candidates/metal_mark_01.wav"),
	preload("res://assets/audio/candidates/metal_mark_02.wav")
]
const ERASE_STREAM = preload("res://assets/audio/candidates/paper_erase.wav")
const CORRECT_STREAM = preload("res://assets/audio/candidates/wood_correct.wav")
const WRONG_STREAM = preload("res://assets/audio/candidates/wood_wrong.wav")
const HEART_LOST_STREAM = preload("res://assets/audio/candidates/wood_heart_lost.wav")
const HINT_STREAM = preload("res://assets/audio/candidates/wood_hint.wav")
const CLEAR_STREAM = preload("res://assets/audio/candidates/paper_clear.wav")
const VICTORY_STREAM = preload("res://assets/audio/candidates/wood_victory.wav")
const UI_TAP_STREAM = preload("res://assets/audio/candidates/wood_ui_tap.wav")

const POOL_SIZE := 4
const MARK_INTERVAL_MS := 160

var players: Array[AudioStreamPlayer] = []
var next_player := 0
var last_mark_ms := -MARK_INTERVAL_MS


func _ready() -> void:
	for _index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		players.append(player)


func play_mark() -> void:
	var now := Time.get_ticks_msec()
	if now - last_mark_ms < MARK_INTERVAL_MS:
		return
	last_mark_ms = now
	var stream = MARK_STREAMS[randi() % MARK_STREAMS.size()]
	_play(stream, -1.5, randf_range(0.97, 1.03))


func play_erase() -> void:
	_play(ERASE_STREAM, -1.5, randf_range(0.98, 1.02))


func play_correct() -> void:
	_play(CORRECT_STREAM)


func play_wrong() -> void:
	_play(WRONG_STREAM)


func play_heart_lost() -> void:
	_play(HEART_LOST_STREAM, -1.0)


func play_hint() -> void:
	_play(HINT_STREAM, -1.0)


func play_clear() -> void:
	_play(CLEAR_STREAM, -1.5)


func play_victory() -> void:
	_play(VICTORY_STREAM)


func play_ui_tap() -> void:
	_play(UI_TAP_STREAM, -2.0)


func _play(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if players.is_empty():
		return
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
