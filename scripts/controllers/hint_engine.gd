extends RefCounted

const CrownRuleEngineScript = preload("res://scripts/rules/crown_rule_engine.gd")

var active_step: Dictionary = {}
var active_stage := 0
var _level: Dictionary = {}
var _states: Array = []


func prepare(level: Dictionary, states: Array) -> void:
	# Hint evaluation is read-only. Keep references to the current immutable
	# level definition and live state array instead of duplicating either tree.
	_level = level
	_states = states


func reset_session() -> void:
	active_step.clear()
	active_stage = 0


func build_formal_x_hint() -> Dictionary:
	for strategy in [
		Callable(self, "_best_locked_candidate_hint"),
		Callable(self, "_best_subset_lock_hint"),
		Callable(self, "_best_lookahead_exclusion_hint"),
		Callable(self, "_best_exclusion_hint"),
	]:
		var raw_hint: Dictionary = strategy.call()
		var hint := filter_formal_x_hint(raw_hint, _states, _level.get("solution", []))
		if not hint.is_empty():
			return hint
	return {}


func filter_formal_x_hint(source_hint: Dictionary, cell_states: Array, solution: Array) -> Dictionary:
	if source_hint.is_empty():
		return {}
	var solution_cells := {}
	for coordinate in solution:
		if coordinate is Array and coordinate.size() >= 2:
			solution_cells[Vector2i(int(coordinate[1]), int(coordinate[0]))] = true
	var source_guides: Dictionary = source_hint.get("guides", {})
	var x_guides := {}
	for raw_cell in source_guides.keys():
		if not raw_cell is Vector2i:
			continue
		var cell: Vector2i = raw_cell
		var kind := str(source_guides[cell])
		if kind != "exclude" and kind != "exclude_empty":
			continue
		if cell.y < 0 or cell.y >= cell_states.size() or cell.x < 0 or cell.x >= cell_states[cell.y].size():
			continue
		if cell_states[cell.y][cell.x] != "empty" or solution_cells.has(cell):
			continue
		x_guides[cell] = "exclude_empty"
	if x_guides.is_empty():
		return {}
	var target: Vector2i = source_hint.get("target", Vector2i(-1, -1))
	if not x_guides.has(target):
		target = x_guides.keys()[0]
	return {
		"target": target,
		"guides": x_guides
	}


func _best_locked_candidate_hint() -> Dictionary:
	for row in range(int(_level["rows"])):
		if _row_has_piece(row):
			continue
		var candidates := _available_candidates_in_row(row)
		if candidates.size() >= 2 and candidates.size() <= 3:
			var region_id := _shared_region(candidates)
			if region_id > 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_region(region_id), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint(candidates, other_cells)
	for col in range(int(_level["cols"])):
		if _col_has_piece(col):
			continue
		var candidates := _available_candidates_in_col(col)
		if candidates.size() >= 2 and candidates.size() <= 3:
			var region_id := _shared_region(candidates)
			if region_id > 0:
				var other_cells := _candidate_cells_except(_available_candidates_in_region(region_id), candidates)
				if not other_cells.is_empty():
					return _make_locked_hint(candidates, other_cells)
	for region_id in _region_ids():
		if _region_has_piece(region_id):
			continue
		var candidates := _available_candidates_in_region(region_id)
		if candidates.size() < 2 or candidates.size() > 3:
			continue
		var row := _shared_row(candidates)
		if row >= 0:
			var other_cells := _candidate_cells_except(_available_candidates_in_row(row), candidates)
			if not other_cells.is_empty():
				return _make_locked_hint(candidates, other_cells)
		var col := _shared_col(candidates)
		if col >= 0:
			var other_cells := _candidate_cells_except(_available_candidates_in_col(col), candidates)
			if not other_cells.is_empty():
				return _make_locked_hint(candidates, other_cells)
	return {}


func _make_locked_hint(locked_cells: Array[Vector2i], other_cells: Array[Vector2i]) -> Dictionary:
	var guides := {}
	for cell in locked_cells:
		guides[cell] = "candidate"
	for cell in other_cells:
		guides[cell] = "exclude"
	return {
		"target": other_cells[0],
		"guides": guides
	}


func _best_subset_lock_hint() -> Dictionary:
	var pairs := [
		["row", "col"], ["col", "row"], ["row", "region"],
		["col", "region"], ["region", "row"], ["region", "col"]
	]
	for pair in pairs:
		var source_kind := str(pair[0])
		var target_kind := str(pair[1])
		var units := _open_unit_candidates(source_kind)
		for group_size in range(2, 4):
			for combination in _unit_index_combinations(units.size(), group_size):
				var source_cells: Array[Vector2i] = []
				var target_values: Array[int] = []
				for unit_position in combination:
					var unit: Dictionary = units[int(unit_position)]
					for cell in unit["candidates"]:
						if not source_cells.has(cell):
							source_cells.append(cell)
						var value := _cell_unit_value(cell, target_kind)
						if not target_values.has(value):
							target_values.append(value)
				if target_values.size() != group_size:
					continue
				var other_cells: Array[Vector2i] = []
				for target_value in target_values:
					for cell in _available_candidates_for_unit(target_kind, target_value):
						if not source_cells.has(cell) and not other_cells.has(cell):
							other_cells.append(cell)
				if not other_cells.is_empty():
					return _make_subset_lock_hint(source_cells, other_cells)
	return {}


func _make_subset_lock_hint(source_cells: Array[Vector2i], other_cells: Array[Vector2i]) -> Dictionary:
	var guides := {}
	for cell in source_cells:
		guides[cell] = "candidate"
	for cell in other_cells:
		guides[cell] = "exclude"
	return {
		"target": other_cells[0],
		"guides": guides
	}


func _best_lookahead_exclusion_hint() -> Dictionary:
	for row in range(int(_level["rows"])):
		for col in range(int(_level["cols"])):
			var cell := Vector2i(col, row)
			if not _is_available_candidate(cell):
				continue
			var blocked_unit := _blocked_unit_after_assume(cell)
			if blocked_unit.is_empty():
				continue
			var kind := str(blocked_unit["kind"])
			var index := int(blocked_unit["index"])
			var guides := {cell: "exclude"}
			for peer in _unit_cells_by_kind(kind, index):
				if peer != cell:
					guides[peer] = "unit"
			return {
				"target": cell,
				"guides": guides
			}
	return {}


func _best_exclusion_hint() -> Dictionary:
	for row in range(int(_level["rows"])):
		for col in range(int(_level["cols"])):
			var cell := Vector2i(col, row)
			if _states[row][col] != "empty":
				continue
			var conflicting_piece := _first_conflicting_piece(cell)
			if conflicting_piece.x < 0:
				continue
			var guides := {cell: "exclude", conflicting_piece: "place"}
			return {
				"target": cell,
				"guides": guides
			}
	return {}


func _shared_region(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var region_id := int(_level["regions"][cells[0].y][cells[0].x])
	for cell in cells:
		if int(_level["regions"][cell.y][cell.x]) != region_id:
			return -1
	return region_id


func _shared_row(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var row := cells[0].y
	for cell in cells:
		if cell.y != row:
			return -1
	return row


func _shared_col(cells: Array[Vector2i]) -> int:
	if cells.is_empty():
		return -1
	var col := cells[0].x
	for cell in cells:
		if cell.x != col:
			return -1
	return col


func _candidate_cells_except(cells: Array[Vector2i], excluded: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if not excluded.has(cell):
			result.append(cell)
	return result


func _open_unit_candidates(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in _unit_indices_by_kind(kind):
		if _unit_has_piece(kind, index):
			continue
		var candidates := _available_candidates_for_unit(kind, index)
		if candidates.size() > 1:
			result.append({"candidates": candidates})
	return result


func _available_candidates_for_unit(kind: String, index: int) -> Array[Vector2i]:
	match kind:
		"row": return _available_candidates_in_row(index)
		"col": return _available_candidates_in_col(index)
		"region": return _available_candidates_in_region(index)
		_: return []


func _unit_indices_by_kind(kind: String) -> Array[int]:
	var result: Array[int] = []
	match kind:
		"row":
			for row in range(int(_level["rows"])):
				result.append(row)
		"col":
			for col in range(int(_level["cols"])):
				result.append(col)
		"region":
			return _region_ids()
	return result


func _unit_has_piece(kind: String, index: int) -> bool:
	match kind:
		"row": return _row_has_piece(index)
		"col": return _col_has_piece(index)
		"region": return _region_has_piece(index)
		_: return false


func _unit_cells_by_kind(kind: String, index: int) -> Array[Vector2i]:
	match kind:
		"row": return _row_cells(index)
		"col": return _col_cells(index)
		"region": return _region_cells(index)
		_: return []


func _cell_unit_value(cell: Vector2i, kind: String) -> int:
	match kind:
		"row": return cell.y
		"col": return cell.x
		"region": return int(_level["regions"][cell.y][cell.x])
		_: return -1


func _unit_index_combinations(count: int, group_size: int) -> Array[Array]:
	var result: Array[Array] = []
	if group_size == 2:
		for a in range(count):
			for b in range(a + 1, count):
				result.append([a, b])
	elif group_size == 3:
		for a in range(count):
			for b in range(a + 1, count):
				for c in range(b + 1, count):
					result.append([a, b, c])
	return result


func _blocked_unit_after_assume(cell: Vector2i) -> Dictionary:
	for kind in ["row", "col", "region"]:
		for index in _unit_indices_by_kind(kind):
			if _unit_has_piece_after_assume(kind, index, cell):
				continue
			var has_candidate := false
			for unit_cell in _unit_cells_by_kind(kind, index):
				if _is_available_after_assume(unit_cell, cell):
					has_candidate = true
					break
			if not has_candidate:
				return {"kind": kind, "index": index}
	return {}


func _unit_has_piece_after_assume(kind: String, index: int, assumed: Vector2i) -> bool:
	return _cell_unit_value(assumed, kind) == index or _unit_has_piece(kind, index)


func _is_available_after_assume(position: Vector2i, assumed: Vector2i) -> bool:
	if position == assumed or not _is_available_candidate(position):
		return false
	if position.y == assumed.y or position.x == assumed.x:
		return false
	if int(_level["regions"][position.y][position.x]) == int(_level["regions"][assumed.y][assumed.x]):
		return false
	return absi(position.x - assumed.x) > 1 or absi(position.y - assumed.y) > 1


func _available_candidates_in_row(row: int) -> Array[Vector2i]:
	return CrownRuleEngineScript.available_candidates_for_unit(_level, _states, "row", row)


func _available_candidates_in_col(col: int) -> Array[Vector2i]:
	return CrownRuleEngineScript.available_candidates_for_unit(_level, _states, "col", col)


func _available_candidates_in_region(region_id: int) -> Array[Vector2i]:
	return CrownRuleEngineScript.available_candidates_for_unit(_level, _states, "region", region_id)


func _is_available_candidate(position: Vector2i) -> bool:
	return CrownRuleEngineScript.is_available_candidate(_level, _states, position)


func _first_conflicting_piece(position: Vector2i) -> Vector2i:
	return CrownRuleEngineScript.first_conflicting_piece(_level, _states, position)


func _piece_positions() -> Array[Vector2i]:
	return CrownRuleEngineScript.piece_positions(_states)


func _piece_conflicts_with_cell(piece: Vector2i, cell: Vector2i) -> bool:
	return CrownRuleEngineScript.piece_conflicts(_level, piece, cell)


func _row_cells(row: int) -> Array[Vector2i]:
	return CrownRuleEngineScript.row_cells(_level, row)


func _col_cells(col: int) -> Array[Vector2i]:
	return CrownRuleEngineScript.column_cells(_level, col)


func _region_cells(region_id: int) -> Array[Vector2i]:
	return CrownRuleEngineScript.region_cells(_level, region_id)


func _region_ids() -> Array[int]:
	return CrownRuleEngineScript.region_ids(_level)


func _row_has_piece(row: int) -> bool:
	return CrownRuleEngineScript.unit_has_piece(_level, _states, "row", row)


func _col_has_piece(col: int) -> bool:
	return CrownRuleEngineScript.unit_has_piece(_level, _states, "col", col)


func _region_has_piece(region_id: int) -> bool:
	return CrownRuleEngineScript.unit_has_piece(_level, _states, "region", region_id)


func _is_piece_state(state: String) -> bool:
	return CrownRuleEngineScript.is_piece_state(state)
