extends RefCounted


static func is_piece_state(state: String) -> bool:
	return state == "piece" or state == "hint" or state == "king"


static func piece_positions(states: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(states.size()):
		for col in range(states[row].size()):
			if is_piece_state(str(states[row][col])):
				result.append(Vector2i(col, row))
	return result


static func piece_conflicts(level: Dictionary, first: Vector2i, second: Vector2i) -> bool:
	return (
		first.y == second.y
		or first.x == second.x
		or region_id_at(level, first) == region_id_at(level, second)
		or (absi(first.x - second.x) <= 1 and absi(first.y - second.y) <= 1)
	)


static func find_conflicts(level: Dictionary, pieces: Array) -> Dictionary:
	var result := {}
	for first_index in range(pieces.size()):
		for second_index in range(first_index + 1, pieces.size()):
			var first: Vector2i = pieces[first_index]
			var second: Vector2i = pieces[second_index]
			if piece_conflicts(level, first, second):
				result[first] = true
				result[second] = true
	return result


static func is_solution_cell(level: Dictionary, cell: Vector2i) -> bool:
	for coordinate in level.get("solution", []):
		if coordinate is Array and coordinate.size() >= 2:
			if int(coordinate[0]) == cell.y and int(coordinate[1]) == cell.x:
				return true
	return false


static func region_id_at(level: Dictionary, cell: Vector2i) -> int:
	return int(level["regions"][cell.y][cell.x])


static func row_cells(level: Dictionary, row: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for col in range(int(level["cols"])):
		result.append(Vector2i(col, row))
	return result


static func column_cells(level: Dictionary, col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(level["rows"])):
		result.append(Vector2i(col, row))
	return result


static func region_cells(level: Dictionary, region_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in range(int(level["rows"])):
		for col in range(int(level["cols"])):
			if int(level["regions"][row][col]) == region_id:
				result.append(Vector2i(col, row))
	return result


static func region_ids(level: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for row in level.get("regions", []):
		for raw_region_id in row:
			var region_id := int(raw_region_id)
			if not result.has(region_id):
				result.append(region_id)
	return result


static func unit_cells(level: Dictionary, kind: String, index: int) -> Array[Vector2i]:
	match kind:
		"row":
			return row_cells(level, index)
		"col":
			return column_cells(level, index)
		"region":
			return region_cells(level, index)
		_:
			return []


static func unit_indices(level: Dictionary, kind: String) -> Array[int]:
	var result: Array[int] = []
	match kind:
		"row":
			for row in range(int(level["rows"])):
				result.append(row)
		"col":
			for col in range(int(level["cols"])):
				result.append(col)
		"region":
			return region_ids(level)
	return result


static func cell_unit_value(level: Dictionary, cell: Vector2i, kind: String) -> int:
	match kind:
		"row":
			return cell.y
		"col":
			return cell.x
		"region":
			return region_id_at(level, cell)
		_:
			return -1


static func unit_has_piece(level: Dictionary, states: Array, kind: String, index: int) -> bool:
	for cell in unit_cells(level, kind, index):
		if is_piece_state(str(states[cell.y][cell.x])):
			return true
	return false


static func first_conflicting_piece(level: Dictionary, states: Array, cell: Vector2i) -> Vector2i:
	for piece in piece_positions(states):
		if piece_conflicts(level, piece, cell):
			return piece
	return Vector2i(-1, -1)


static func is_available_candidate(level: Dictionary, states: Array, cell: Vector2i) -> bool:
	return (
		cell.y >= 0
		and cell.y < states.size()
		and cell.x >= 0
		and cell.x < states[cell.y].size()
		and states[cell.y][cell.x] == "empty"
		and first_conflicting_piece(level, states, cell).x < 0
	)


static func available_candidates(level: Dictionary, states: Array, cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		if is_available_candidate(level, states, cell):
			result.append(cell)
	return result


static func available_candidates_for_unit(level: Dictionary, states: Array, kind: String, index: int) -> Array[Vector2i]:
	return available_candidates(level, states, unit_cells(level, kind, index))


static func is_completed(level: Dictionary, states: Array) -> bool:
	var pieces := piece_positions(states)
	return pieces.size() == int(level.get("targetCount", 0)) and find_conflicts(level, pieces).is_empty()
