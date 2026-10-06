extends Node

signal announcement_requested(event: Dictionary)
signal hud_changed(data: Dictionary)
signal settled(won: bool, reward: int)
signal progress_changed

const Policy = preload("res://scripts/services/hidden_diamond_policy.gd")

var progress: Dictionary = Policy.normalize({})
var offered_ids: Array = []
var phase := "idle"
var event: Dictionary = {}
var _context: Dictionary = {}
var _playing := false
var _considered := false
var _measure_valid := false
var _elapsed := 0.0
var _measure_started_msec := -1
var _assisted := false
var _moves := 0
var _found := 0
var _deadline_msec := 0
var _last_seconds := -1
var _pending_cell := Vector2i(-1, -1)
var _pending_until := 0


func restore(saved: Dictionary, ids: Array, legacy_runs: Array) -> void:
	progress = Policy.normalize(saved)
	offered_ids = ids.duplicate()
	if int(saved.get("timeBaselineVersion", 0)) < Policy.TIME_BASELINE_VERSION:
		Policy.import_legacy_times(progress, legacy_runs)
	var interrupted: Dictionary = progress["pending"]
	if not interrupted.is_empty():
		Policy.record_outcome(progress, interrupted, false)
		progress["pending"] = {}


func prepare_board(context: Dictionary, measure_valid: bool) -> void:
	leave_board()
	_context = context.duplicate(true)
	_found = int(context.get("found", 0))
	_measure_valid = measure_valid
	_considered = false
	_elapsed = 0.0
	_measure_started_msec = -1
	_assisted = false
	_moves = 0
	phase = "idle"


func present_board(untouched: bool = true) -> void:
	if _context.is_empty():
		return
	_playing = true
	if _considered:
		return
	_considered = true
	_context["untouched"] = untouched
	event = Policy.consider(progress, _context, offered_ids)
	if event.is_empty():
		_measure_started_msec = Time.get_ticks_msec()
		progress_changed.emit()
		return
	phase = "intro"
	offered_ids.append(event["id"])
	progress["pending"] = event.duplicate(true)
	# Persist before showing the prompt; an interrupted event cannot be rerolled.
	progress_changed.emit()
	announcement_requested.emit(event.duplicate(true))


func begin_challenge() -> void:
	if phase != "intro" or not _playing:
		return
	phase = "active"
	_measure_started_msec = Time.get_ticks_msec()
	_deadline_msec = Time.get_ticks_msec() + int(event["limit"]) * 1000 if event["kind"] == "time" else 0
	_publish_hud()


func intro_blocks_input() -> bool:
	return phase == "intro"


func record_action(found: int, kind: String = "action", cell: Vector2i = Vector2i(-1, -1), double_tap_window_ms: int = 320) -> void:
	if not _playing or phase == "intro" or _context.is_empty():
		return
	if kind == "assist":
		_assisted = true
	if kind == "double" and cell == _pending_cell and Time.get_ticks_msec() <= _pending_until:
		_found = found
		_clear_pending_tap()
		_commit_move()
		return
	_flush_pending_tap()
	_found = found
	if kind == "tap":
		_pending_cell = cell
		_pending_until = Time.get_ticks_msec() + double_tap_window_ms
		_publish_hud()
	else:
		_commit_move()


func _commit_move() -> void:
	_moves += 1
	if phase != "active":
		return
	if _time_expired():
		_resolve(false)
	elif _found >= int(event["target"]):
		_resolve(true)
	elif event["kind"] == "moves" and _moves >= int(event["limit"]):
		_resolve(false)
	else:
		_publish_hud()


func complete_board() -> void:
	_flush_pending_tap()
	if phase == "active":
		_resolve(not _time_expired() and _found >= int(event["target"]))
	if _measure_valid and not _context.is_empty():
		_elapsed = _measured_seconds()
		var seconds := 0.0 if _assisted or str(_context.get("schedule_mode", "")) == "manual" else _elapsed
		Policy.record_best(progress, str(_context["mode"]), int(_context["size"]), seconds, _moves)
	_measure_valid = false
	_playing = false
	progress_changed.emit()


func suspend() -> void:
	_flush_pending_tap()
	if phase in ["intro", "active"]:
		_resolve(false)
	if _playing:
		_measure_valid = false
	_playing = false
	_clear_pending_tap()
	hud_changed.emit({})


func leave_board() -> void:
	suspend()
	_context = {}
	event = {}
	phase = "idle"


func _measured_seconds() -> float:
	return maxf(0.0, float(Time.get_ticks_msec() - _measure_started_msec) / 1000.0) if _measure_started_msec != -1 else 0.0


func _process(_delta: float) -> void:
	if not _playing or phase == "intro":
		return
	# Use the same monotonic clock as the deadline, not frame deltas, which can
	# be clamped under stalls or scaled by Engine.time_scale.
	_elapsed = _measured_seconds()
	if _pending_until > 0 and Time.get_ticks_msec() > _pending_until:
		_flush_pending_tap()
	if phase != "active":
		return
	if _time_expired():
		_resolve(false)
	elif event["kind"] == "time" and _seconds_left() != _last_seconds:
		_publish_hud()


func _resolve(won: bool) -> void:
	if not phase in ["intro", "active"]:
		return
	phase = "resolved"
	_deadline_msec = 0
	Policy.record_outcome(progress, event, won)
	progress["pending"] = {}
	hud_changed.emit({})
	# The receiver saves the outcome and reward together, in one transaction.
	settled.emit(won, int(event["reward"]) if won else 0)


func _time_expired() -> bool:
	return phase == "active" and event["kind"] == "time" and Time.get_ticks_msec() >= _deadline_msec


func _seconds_left() -> int:
	return maxi(0, ceili(float(_deadline_msec - Time.get_ticks_msec()) / 1000.0))


func _publish_hud() -> void:
	if phase != "active":
		return
	_last_seconds = _seconds_left() if event["kind"] == "time" else -1
	hud_changed.emit({
		"kind": event["kind"], "remaining": _last_seconds if event["kind"] == "time" else maxi(0, int(event["limit"]) - _moves - int(_pending_until > 0)),
		"lions": maxi(0, int(event["target"]) - _found), "reward": int(event["reward"])
	})


func _flush_pending_tap() -> void:
	if _pending_until > 0:
		_clear_pending_tap()
		_commit_move()


func _clear_pending_tap() -> void:
	_pending_cell = Vector2i(-1, -1)
	_pending_until = 0
