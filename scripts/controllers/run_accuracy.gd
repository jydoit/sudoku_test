extends RefCounted

# This ledger is deliberately outside board undo history. A cancelled X or a
# revive must not erase a genuine mistake made earlier in the same attempt.
var _tracked := false
var _excluded_lion := false
var _wrong_crown := false
var _pending_cell := Vector2i(-1, -1)
var _pending_until := 0


static func normalize_state(value) -> Dictionary:
	if not value is Dictionary:
		return {}
	for key in ["tracked", "excludedLion", "wrongCrown"]:
		if not value.get(key) is bool:
			return {}
	return {
		"tracked": value["tracked"],
		"excludedLion": value["excludedLion"],
		"wrongCrown": value["wrongCrown"]
	}


func reset() -> void:
	restore({"tracked": true, "excludedLion": false, "wrongCrown": false})


func restore(state: Dictionary) -> void:
	var normalized := normalize_state(state)
	_tracked = bool(normalized.get("tracked", false))
	_excluded_lion = bool(normalized.get("excludedLion", false))
	_wrong_crown = bool(normalized.get("wrongCrown", false))
	_clear_pending()


func save_state() -> Dictionary:
	# A first tap is a real X if the app closes before the second tap arrives.
	# Serializing must not commit it in memory: a normal double tap can still
	# cancel only this provisional mark, never an earlier genuine exclusion.
	return {
		"tracked": _tracked,
		"excludedLion": _excluded_lion or _pending_cell.x >= 0,
		"wrongCrown": _wrong_crown
	}


func record_mark(cell: Vector2i, is_solution: bool, is_blocked: bool, is_tap: bool = false, double_tap_window_ms: int = 320) -> void:
	commit_pending()
	if not is_solution or not is_blocked:
		return
	if is_tap:
		_pending_cell = cell
		_pending_until = Time.get_ticks_msec() + double_tap_window_ms
	else:
		_excluded_lion = true


func record_double(cell: Vector2i, correct: bool) -> void:
	if correct and cell == _pending_cell and Time.get_ticks_msec() <= _pending_until:
		_clear_pending()
	else:
		commit_pending()
	if not correct:
		_wrong_crown = true


func commit_pending() -> void:
	if _pending_cell.x >= 0:
		_excluded_lion = true
	_clear_pending()


func _clear_pending() -> void:
	_pending_cell = Vector2i(-1, -1)
	_pending_until = 0
