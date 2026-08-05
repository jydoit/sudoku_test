class_name CompositeLevelStore
extends RefCounted

const COMPOSITE_LEVELS_PATH := "res://data/composite_levels.json"


static func load_entries() -> Dictionary:
	if not FileAccess.file_exists(COMPOSITE_LEVELS_PATH):
		push_warning("Offline composite level data is missing: %s" % COMPOSITE_LEVELS_PATH)
		return {}
	var file := FileAccess.open(COMPOSITE_LEVELS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Offline composite level data could not be opened")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not (parsed.get("entries", []) is Array):
		push_warning("Offline composite level data has an invalid payload")
		return {}
	var result := {}
	for raw_entry in parsed["entries"]:
		if not raw_entry is Dictionary:
			continue
		var level_id := int(raw_entry.get("levelId", -1))
		var difficulty := str(raw_entry.get("difficulty", ""))
		var data = raw_entry.get("data", {})
		if level_id < 0 or difficulty.is_empty() or not data is Dictionary:
			continue
		if data.get("pieces", []).is_empty() or data.get("validLayouts", []).is_empty():
			continue
		var normalized: Dictionary = data.duplicate(true)
		_normalize_data(normalized)
		result[_key(level_id, difficulty)] = normalized
	return result


static func find(entries: Dictionary, level_id: int, difficulty: String) -> Dictionary:
	var raw_data = entries.get(_key(level_id, difficulty), {})
	return raw_data.duplicate(true) if raw_data is Dictionary else {}


static func _key(level_id: int, difficulty: String) -> String:
	return "%d:%s" % [level_id, difficulty]


static func _normalize_data(data: Dictionary) -> void:
	data["version"] = int(data.get("version", 0))
	data["seed"] = int(data.get("seed", 0))
	data["rows"] = int(data.get("rows", 0))
	data["cols"] = int(data.get("cols", 0))
	for key in ["baseRegions"]:
		var matrix = data.get(key, [])
		if matrix is Array:
			for row_index in range(matrix.size()):
				if matrix[row_index] is Array:
					for col_index in range(matrix[row_index].size()):
						matrix[row_index][col_index] = int(matrix[row_index][col_index])
	for key in ["clueCells", "constructionCells", "selectedRegionIds", "lockedRegionIds"]:
		var values = data.get(key, [])
		if values is Array:
			for index in range(values.size()):
				if values[index] is Array:
					values[index] = [int(values[index][0]), int(values[index][1])]
				else:
					values[index] = int(values[index])
	for piece in data.get("pieces", []):
		if not piece is Dictionary:
			continue
		piece["pieceId"] = int(piece.get("pieceId", -1))
		piece["regionId"] = int(piece.get("regionId", -1))
		piece["trayIndex"] = int(piece.get("trayIndex", piece["pieceId"]))
		piece["cells"] = _normalize_pairs(piece.get("cells", []))
		piece["initialOrigin"] = _normalize_pair(piece.get("initialOrigin", [0, 0]))
	for layout in data.get("validLayouts", []):
		if not layout is Dictionary:
			continue
		layout["regions"] = _normalize_matrix(layout.get("regions", []))
		layout["solution"] = _normalize_pairs(layout.get("solution", []))
		var placements = layout.get("placements", {})
		if placements is Dictionary:
			for piece_id in placements.keys():
				placements[piece_id] = _normalize_pair(placements[piece_id])
	for step in data.get("solutionOrder", []):
		if not step is Dictionary:
			continue
		step["pieceId"] = int(step.get("pieceId", -1))
		step["candidateCount"] = int(step.get("candidateCount", 0))
		step["origin"] = _normalize_pair(step.get("origin", [0, 0]))


static func _normalize_pair(raw_value) -> Array:
	if raw_value is Array and raw_value.size() >= 2:
		return [int(raw_value[0]), int(raw_value[1])]
	return [0, 0]


static func _normalize_pairs(raw_values) -> Array:
	var result: Array = []
	if raw_values is Array:
		for value in raw_values:
			result.append(_normalize_pair(value))
	return result


static func _normalize_matrix(raw_matrix) -> Array:
	var result: Array = []
	if raw_matrix is Array:
		for raw_row in raw_matrix:
			var row: Array = []
			if raw_row is Array:
				for value in raw_row:
					row.append(int(value))
			result.append(row)
	return result
