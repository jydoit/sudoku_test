extends RefCounted

const PHASE_PLACE := 0
const PHASE_ADJACENT := 1
const PHASE_ROW_COL := 2
const PHASE_HINT := 3
const PHASE_HINT_PLACE := 4
const PHASE_CROWN_FIND := 5
const PHASE_DONE := 6

var completed := false
var started := false
var step_index := 0
var interaction_stage := PHASE_PLACE
var button_stage := 0
var solution_index := 0
var active_crown := Vector2i(-1, -1)
var hint_target := Vector2i(-1, -1)
var hint_button_taught := false
var crown_find_taught := false
var active := false
var focus_token := 0
var history: Array = []
var _level: Dictionary = {}
var _states: Array = []


func bind(level: Dictionary, states: Array) -> void:
	_level = level
	_states = states


func restore(save_data: Dictionary, step_count: int) -> void:
	completed = bool(save_data.get("tutorialCompleted", false))
	started = bool(save_data.get("tutorialStarted", false))
	step_index = clampi(int(save_data.get("tutorialStepIndex", 0)), 0, maxi(0, step_count - 1))
	active = false


func write_save(save_data: Dictionary) -> void:
	save_data["tutorialCompleted"] = completed
	save_data["tutorialStarted"] = started
	save_data["tutorialStepIndex"] = step_index


func begin_step(index: int, step_count: int, first_hint_target: Vector2i) -> void:
	active = true
	started = true
	step_index = clampi(index, 0, maxi(0, step_count - 1))
	interaction_stage = PHASE_PLACE
	button_stage = 0
	solution_index = 0
	active_crown = Vector2i(-1, -1)
	hint_target = first_hint_target
	hint_button_taught = false
	crown_find_taught = false
	history.clear()
	focus_token += 1


func reset_for_replay() -> void:
	completed = false
	started = false
	active = false
	step_index = 0
	interaction_stage = PHASE_PLACE
	button_stage = 0
	focus_token += 1


func finish() -> void:
	completed = true
	started = false
	active = false
	step_index = 0
	button_stage = 0
	focus_token += 1


func guides() -> Dictionary:
	var result := {}
	if interaction_stage == PHASE_PLACE or interaction_stage == PHASE_HINT_PLACE:
		var place_target := current_place_target()
		if place_target.x >= 0:
			result[place_target] = "place"
	elif interaction_stage == PHASE_ADJACENT or interaction_stage == PHASE_ROW_COL:
		var exclusion_target := next_single_map_exclusion_cell()
		if exclusion_target.x >= 0:
			result[exclusion_target] = "exclude_empty"
	return result


func press(cell: Vector2i, from_drag: bool = false) -> Dictionary:
	if interaction_stage != PHASE_ADJACENT and interaction_stage != PHASE_ROW_COL:
		return {"valid": false, "reason": "phase", "focus": focus_target()}
	var expected := next_single_map_exclusion_cell()
	if expected.x < 0:
		return {"valid": false, "reason": "settle", "focus": expected}
	if cell != expected or not valid_exclusion_cells().has(cell):
		return {
			"valid": false,
			"reason": "unexpected",
			"silent": from_drag,
			"focus": expected
		}
	if str(_states[cell.y][cell.x]) != "empty":
		return {"valid": false, "reason": "occupied", "focus": expected}
	_push_history()
	_states[cell.y][cell.x] = "blocked"
	return {"valid": true, "cell": cell, "states": _states}


func double_press(cell: Vector2i) -> Dictionary:
	if interaction_stage == PHASE_CROWN_FIND:
		return {"valid": false, "reason": "use_crown_find", "focus": cell}
	if interaction_stage != PHASE_PLACE and interaction_stage != PHASE_HINT_PLACE:
		return {"valid": false, "reason": "exclude", "focus": focus_target()}
	var target := current_place_target()
	if cell != target:
		return {"valid": false, "reason": "unexpected", "focus": target}
	_push_history()
	_states[cell.y][cell.x] = "piece"
	active_crown = target
	var was_first := solution_index == 0
	solution_index += 1
	if solution_index >= solution_cells().size():
		interaction_stage = PHASE_DONE
	else:
		interaction_stage = PHASE_ADJACENT
	return {
		"valid": true,
		"cell": cell,
		"states": _states,
		"first": was_first,
		"completed": interaction_stage == PHASE_DONE
	}


func settle_after_exclusions() -> Dictionary:
	var exclusion_target := next_single_map_exclusion_cell()
	if exclusion_target.x >= 0:
		return {"action": "exclude", "target": exclusion_target, "phase": interaction_stage}
	if interaction_stage == PHASE_ADJACENT:
		interaction_stage = PHASE_ROW_COL
		exclusion_target = next_single_map_exclusion_cell()
		if exclusion_target.x >= 0:
			return {"action": "exclude", "target": exclusion_target, "phase": interaction_stage}
	var next_solution := next_solution_cell()
	var solutions := solution_cells()
	if not solutions.is_empty() and next_solution == solutions.back():
		return _activate_direct_clue("final")
	if not hint_button_taught:
		interaction_stage = PHASE_HINT
		return {"action": "hint", "phase": interaction_stage}
	if not crown_find_taught:
		interaction_stage = PHASE_CROWN_FIND
		return {"action": "crown_find", "phase": interaction_stage}
	return _activate_direct_clue("color")


func use_hint() -> Dictionary:
	if interaction_stage != PHASE_HINT:
		return {"valid": false, "focus": focus_target()}
	hint_button_taught = true
	var result := _activate_direct_clue("color")
	result["valid"] = true
	return result


func use_crown_find() -> Dictionary:
	if interaction_stage != PHASE_CROWN_FIND:
		return {"valid": false, "focus": focus_target()}
	var target := next_solution_cell()
	if target.x < 0:
		return {"valid": false, "reason": "empty", "focus": target}
	_push_history()
	crown_find_taught = true
	active_crown = target
	_states[target.y][target.x] = "hint"
	solution_index += 1
	interaction_stage = PHASE_DONE if solution_index >= solution_cells().size() else PHASE_ADJACENT
	return {
		"valid": true,
		"cell": target,
		"states": _states,
		"completed": interaction_stage == PHASE_DONE
	}


func undo() -> Dictionary:
	if history.is_empty():
		return {}
	var snapshot: Dictionary = history.pop_back()
	_states = snapshot.get("states", []).duplicate(true)
	interaction_stage = int(snapshot.get("phase", PHASE_PLACE))
	solution_index = int(snapshot.get("solutionIndex", 0))
	active_crown = snapshot.get("activeCrown", Vector2i(-1, -1))
	hint_target = snapshot.get("hintTarget", Vector2i(-1, -1))
	hint_button_taught = bool(snapshot.get("hintButtonTaught", false))
	crown_find_taught = bool(snapshot.get("crownFindTaught", false))
	return {"states": _states, "focus": focus_target()}


func focus_target() -> Vector2i:
	if interaction_stage == PHASE_PLACE or interaction_stage == PHASE_HINT_PLACE:
		return current_place_target()
	if interaction_stage == PHASE_ADJACENT or interaction_stage == PHASE_ROW_COL:
		return next_single_map_exclusion_cell()
	return Vector2i(-1, -1)


func _activate_direct_clue(reason: String) -> Dictionary:
	hint_target = next_solution_cell()
	interaction_stage = PHASE_HINT_PLACE
	return {
		"action": "direct_clue",
		"reason": reason,
		"target": hint_target,
		"phase": interaction_stage
	}


func _push_history() -> void:
	history.append({
		"states": _states.duplicate(true),
		"phase": interaction_stage,
		"solutionIndex": solution_index,
		"activeCrown": active_crown,
		"hintTarget": hint_target,
		"hintButtonTaught": hint_button_taught,
		"crownFindTaught": crown_find_taught
	})
	if history.size() > 100:
		history.pop_front()


func hand_action(tutorial_kind: String) -> String:
	if tutorial_kind == "single_map":
		if interaction_stage == PHASE_PLACE or interaction_stage == PHASE_HINT_PLACE:
			return "double"
		if interaction_stage == PHASE_ROW_COL:
			return "single"
		if interaction_stage == PHASE_ADJACENT:
			return "slide"
	return "single"


func next_focus_token() -> int:
	focus_token += 1
	return focus_token


func invalidate_focus() -> void:
	focus_token += 1


func tutorial_kind() -> String:
	return str(_level.get("kind", "place"))


func tutorial_target() -> Vector2i:
	var target: Array = _level.get("target", [0, 0])
	return Vector2i(int(target[1]), int(target[0]))


func solution_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coordinate in _level.get("solution", []):
		if coordinate is Array and coordinate.size() >= 2:
			result.append(Vector2i(int(coordinate[1]), int(coordinate[0])))
	return result


func current_place_target() -> Vector2i:
	if interaction_stage == PHASE_HINT_PLACE:
		return hint_target
	return next_solution_cell()


func next_solution_cell() -> Vector2i:
	var solution := solution_cells()
	return solution[solution_index] if solution_index >= 0 and solution_index < solution.size() else Vector2i(-1, -1)


func valid_exclusion_cells() -> Array[Vector2i]:
	if active_crown.x < 0:
		return []
	if interaction_stage == PHASE_ADJACENT:
		return adjacent_cells(active_crown)
	if interaction_stage == PHASE_ROW_COL:
		return row_col_cells(active_crown)
	return []


func next_single_map_exclusion_cell() -> Vector2i:
	for cell in valid_exclusion_cells():
		if _states[cell.y][cell.x] == "empty":
			return cell
	return Vector2i(-1, -1)


func unique_guides(piece: Vector2i) -> Dictionary:
	var guides := {}
	for cell in row_col_cells(piece):
		guides[cell] = "exclude"
	guides[piece] = "place"
	return guides


func color_cells(crown: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var region_id := int(_level["regions"][crown.y][crown.x])
	for row in range(int(_level["rows"])):
		for col in range(int(_level["cols"])):
			var cell := Vector2i(col, row)
			if cell != crown and int(_level["regions"][row][col]) == region_id:
				cells.append(cell)
	return cells


func row_col_cells(crown: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for col in range(int(_level["cols"])):
		var row_cell := Vector2i(col, crown.y)
		if row_cell != crown:
			cells.append(row_cell)
	for row in range(int(_level["rows"])):
		var col_cell := Vector2i(crown.x, row)
		if col_cell != crown:
			cells.append(col_cell)
	return cells


func adjacent_cells(crown: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in [
		Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
		Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)
	]:
		var cell: Vector2i = crown + offset
		if cell.x >= 0 and cell.x < int(_level["cols"]) and cell.y >= 0 and cell.y < int(_level["rows"]):
			cells.append(cell)
	return cells


func adjacent_row_col_cells(crown: Vector2i) -> Array[Vector2i]:
	var cells := adjacent_cells(crown)
	for cell in row_col_cells(crown):
		if not cells.has(cell):
			cells.append(cell)
	return cells


func blocked_count(cells: Array[Vector2i]) -> int:
	var count := 0
	for cell in cells:
		if _states[cell.y][cell.x] == "blocked":
			count += 1
	return count


func next_unblocked(cells: Array[Vector2i]) -> Vector2i:
	for cell in cells:
		if _states[cell.y][cell.x] != "blocked":
			return cell
	return Vector2i(-1, -1)
