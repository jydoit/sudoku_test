extends RefCounted

const CrownRuleEngineScript = preload("res://scripts/rules/crown_rule_engine.gd")

var move_history: Array = []
var drag_mode := ""
var drag_changed := false
var drag_cells := {}

var _level: Dictionary = {}
var _states: Array = []
var _king_positions: Array = []
var _completed := false
var _failed := false


func bind(level: Dictionary, states: Array, king_positions: Array, completed: bool, failed: bool) -> void:
	_level = level
	_states = states
	_king_positions = king_positions
	_completed = completed
	_failed = failed


func press(row: int, col: int) -> Dictionary:
	if _completed or _failed or is_king_cell(row, col):
		return {}
	var state := str(_states[row][col])
	if state == "hint" or state == "wrong":
		return {}
	push_history(_states)
	var next_state := state
	if state == "empty":
		next_state = "blocked"
	elif state == "blocked":
		next_state = "empty"
	elif state == "piece":
		next_state = "blocked"
	else:
		move_history.pop_back()
		return {}
	_states[row][col] = next_state
	return {"cell": Vector2i(col, row), "state": next_state, "states": _states}


func double_press(row: int, col: int) -> Dictionary:
	if _completed or _failed or is_king_cell(row, col):
		return {}
	var state := str(_states[row][col])
	if state == "piece" or state == "hint" or state == "wrong":
		return {}
	push_history(_states)
	var is_answer := CrownRuleEngineScript.is_solution_cell(_level, Vector2i(col, row))
	_states[row][col] = "piece" if is_answer else "wrong"
	return {
		"cell": Vector2i(col, row),
		"correct": is_answer,
		"states": _states
	}


func begin_drag(row: int, col: int) -> Dictionary:
	drag_mode = ""
	drag_changed = false
	drag_cells.clear()
	if _completed or _failed or is_king_cell(row, col):
		return {}
	var state := str(_states[row][col])
	if state == "empty":
		drag_mode = "mark"
	elif state == "blocked":
		drag_mode = "erase"
	if drag_mode.is_empty():
		return {}
	return drag_to(row, col)


func drag_to(row: int, col: int) -> Dictionary:
	if drag_mode.is_empty() or _completed or _failed:
		return {}
	var cell := Vector2i(col, row)
	if drag_cells.has(cell) or is_king_cell(row, col):
		return {}
	drag_cells[cell] = true
	var state := str(_states[row][col])
	var next_state := state
	if drag_mode == "mark" and state == "empty":
		next_state = "blocked"
	elif drag_mode == "erase" and state == "blocked":
		next_state = "empty"
	else:
		return {}
	if not drag_changed:
		push_history(_states)
	drag_changed = true
	_states[row][col] = next_state
	return {"cell": cell, "state": next_state, "states": _states}


func end_drag() -> bool:
	var changed := drag_changed
	drag_mode = ""
	drag_changed = false
	drag_cells.clear()
	return changed


func undo() -> Dictionary:
	if move_history.is_empty() or _completed or _failed:
		return {}
	_states = move_history.pop_back()
	return {"states": _states}


func clear_board() -> Dictionary:
	if _completed or _failed or clearable_marks_empty(_states):
		return {}
	push_history(_states)
	var next_states: Array = []
	for row in range(int(_level["rows"])):
		var row_states: Array = []
		for col in range(int(_level["cols"])):
			row_states.append("empty")
		next_states.append(row_states)
	for row in range(_states.size()):
		for col in range(_states[row].size()):
			if str(_states[row][col]) == "hint":
				next_states[row][col] = "hint"
	for king in _king_positions:
		if king is Vector2i and king.x >= 0:
			next_states[king.y][king.x] = "king"
	_states = next_states
	return {"states": _states}


func push_history(states: Array) -> void:
	move_history.append(states.duplicate(true))
	if move_history.size() > 100:
		move_history.pop_front()


func next_findable_solution_cell() -> Vector2i:
	for coordinate in _level.get("solution", []):
		var cell := Vector2i(int(coordinate[1]), int(coordinate[0]))
		if not CrownRuleEngineScript.is_piece_state(str(_states[cell.y][cell.x])):
			return cell
	return Vector2i(-1, -1)


func validation() -> Dictionary:
	var pieces := CrownRuleEngineScript.piece_positions(_states)
	var conflicts := CrownRuleEngineScript.find_conflicts(_level, pieces)
	return {
		"pieces": pieces,
		"conflicts": conflicts,
		"completed": pieces.size() == int(_level.get("targetCount", 0)) and conflicts.is_empty()
	}


func is_king_cell(row: int, col: int) -> bool:
	for king in _king_positions:
		if king is Vector2i and king.x == col and king.y == row:
			return true
	return false


static func clearable_marks_empty(states: Array) -> bool:
	for row in states:
		for state in row:
			if state == "blocked" or state == "piece" or state == "wrong":
				return false
	return true
