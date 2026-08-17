extends RefCounted

const CompositeLevelScript = preload("res://scripts/composite_level.gd")


static func prebuilt_matches(raw_data, level: Dictionary, seed: int, difficulty_pattern: String) -> bool:
	if not raw_data is Dictionary or raw_data.is_empty():
		return false
	var data := raw_data as Dictionary
	return (
		int(data.get("seed", 0)) == seed
		and int(data.get("rows", 0)) == int(level.get("rows", 0))
		and int(data.get("cols", 0)) == int(level.get("cols", 0))
		and (difficulty_pattern.is_empty() or str(data.get("difficulty", "")) == CompositeLevelScript._normalize_difficulty(difficulty_pattern))
		and not data.get("pieces", []).is_empty()
		and not data.get("validLayouts", []).is_empty()
	)


static func final_level_is_valid(level: Dictionary, regions, solution) -> bool:
	if not regions is Array or not solution is Array:
		return false
	var rows := int(level.get("rows", 0))
	var cols := int(level.get("cols", 0))
	if regions.size() != rows or solution.size() != int(level.get("targetCount", rows)):
		return false
	for row in regions:
		if not row is Array or row.size() != cols:
			return false
	return true


static func sanitize_placement_history(raw_history, placements: Dictionary) -> Array:
	var result: Array = []
	if raw_history is Array:
		for raw_piece_id in raw_history:
			var piece_id := int(raw_piece_id)
			if placements.has(str(piece_id)) and not result.has(piece_id):
				result.append(piece_id)
	for raw_key in placements.keys():
		var piece_id := int(str(raw_key))
		if not result.has(piece_id):
			result.append(piece_id)
	return result


static func allowed_origins(data: Dictionary, placements: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	return CompositeLevelScript.allowed_origins_for_all(data, placements)


static func compatible_layouts(data: Dictionary, placements: Dictionary) -> Array:
	var result: Array = []
	for raw_layout in data.get("validLayouts", []):
		if not raw_layout is Dictionary:
			continue
		var layout: Dictionary = raw_layout
		var layout_placements: Dictionary = layout.get("placements", {})
		var matches := true
		for raw_key in placements.keys():
			var key := str(raw_key)
			if not layout_placements.has(key) or not origins_equal(layout_placements[key], placements[raw_key]):
				matches = false
				break
		if matches:
			result.append(layout)
	return result


static func compatible_layout(data: Dictionary, placements: Dictionary) -> Dictionary:
	var layouts := compatible_layouts(data, placements)
	return layouts[0] if not layouts.is_empty() else {}


static func remaining_cells_for_region(data: Dictionary, placements: Dictionary, region_id: int) -> int:
	var remaining := 0
	for piece in data.get("pieces", []):
		var piece_id := int(piece.get("pieceId", -1))
		if int(piece.get("regionId", -1)) == region_id and not placements.has(str(piece_id)):
			remaining += (piece.get("cells", []) as Array).size()
	return remaining


static func direct_find_target(data: Dictionary, placements: Dictionary) -> Dictionary:
	var layout := compatible_layout(data, placements)
	if layout.is_empty():
		return {}
	var selected_region := -1
	var smallest_remaining := 1 << 30
	for raw_region_id in data.get("selectedRegionIds", []):
		var region_id := int(raw_region_id)
		var remaining := remaining_cells_for_region(data, placements, region_id)
		if remaining > 0 and remaining < smallest_remaining:
			smallest_remaining = remaining
			selected_region = region_id
	if selected_region < 0:
		return {}
	var target_pieces: Array[int] = []
	var layout_placements: Dictionary = layout.get("placements", {})
	for piece in data.get("pieces", []):
		var piece_id := int(piece.get("pieceId", -1))
		if int(piece.get("regionId", -1)) != selected_region or placements.has(str(piece_id)):
			continue
		if not layout_placements.has(str(piece_id)):
			return {}
		target_pieces.append(piece_id)
	return {} if target_pieces.is_empty() else {
		"layout": layout,
		"regionId": selected_region,
		"pieceIds": target_pieces
	}


static func hint_target(data: Dictionary, placements: Dictionary) -> Dictionary:
	var compatible := compatible_layouts(data, placements)
	var allowed_by_piece := allowed_origins(data, placements)
	var open_candidates: Array[Dictionary] = []
	for layout in compatible:
		var layout_placements: Dictionary = layout.get("placements", {})
		for piece in data.get("pieces", []):
			var piece_id := int(piece.get("pieceId", -1))
			var key := str(piece_id)
			if placements.has(key) or not layout_placements.has(key):
				continue
			var expected: Array = layout_placements[key]
			var allowed: Array = allowed_by_piece.get(key, [])
			if origin_in_list(expected, allowed):
				open_candidates.append({
					"pieceId": piece_id,
					"origin": Vector2i(int(expected[1]), int(expected[0])),
					"spaceCount": allowed.size(),
					"pieceSize": (piece.get("cells", []) as Array).size(),
					"regionId": int(piece.get("regionId", -1))
				})
	open_candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		for key in ["spaceCount", "pieceSize", "regionId", "pieceId"]:
			if int(first[key]) != int(second[key]):
				return int(first[key]) < int(second[key])
		return false
	)
	if not open_candidates.is_empty():
		return open_candidates[0]

	var fallback_layouts: Array = compatible if not compatible.is_empty() else data.get("validLayouts", [])
	var best_fallback: Dictionary = {}
	var best_match_count := -1
	for raw_layout in fallback_layouts:
		if not raw_layout is Dictionary:
			continue
		var layout: Dictionary = raw_layout
		var layout_placements: Dictionary = layout.get("placements", {})
		var match_count := 0
		for raw_key in placements.keys():
			var key := str(raw_key)
			if layout_placements.has(key) and origins_equal(layout_placements[key], placements[raw_key]):
				match_count += 1
		if match_count > best_match_count:
			best_match_count = match_count
			best_fallback = layout
	if best_fallback.is_empty():
		return {}
	var fallback_placements: Dictionary = best_fallback.get("placements", {})
	for piece in data.get("pieces", []):
		var piece_id := int(piece.get("pieceId", -1))
		var key := str(piece_id)
		if placements.has(key) and fallback_placements.has(key) and not origins_equal(placements[key], fallback_placements[key]):
			var expected: Array = fallback_placements[key]
			return {"pieceId": piece_id, "origin": Vector2i(int(expected[1]), int(expected[0]))}
	for piece in data.get("pieces", []):
		var piece_id := int(piece.get("pieceId", -1))
		var key := str(piece_id)
		if not placements.has(key) and fallback_placements.has(key):
			var expected: Array = fallback_placements[key]
			return {"pieceId": piece_id, "origin": Vector2i(int(expected[1]), int(expected[0]))}
	return {}


static func evaluate_candidate(data: Dictionary, placements: Dictionary, piece_id: int, origin: Array) -> Dictionary:
	if origin.size() < 2:
		return {"valid": false, "placements": placements}
	var candidate := placements.duplicate(true)
	candidate[str(piece_id)] = [int(origin[0]), int(origin[1])]
	var evaluation := CompositeLevelScript.evaluate_placement_state(data, candidate, true)
	evaluation["placements"] = candidate
	return evaluation


static func tutorial_demo_targets(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var open_origins := allowed_origins(data, {})
	var correct_candidates: Array[Dictionary] = []
	for raw_layout in data.get("validLayouts", []):
		if not raw_layout is Dictionary:
			continue
		var layout: Dictionary = raw_layout
		var layout_placements: Dictionary = layout.get("placements", {})
		for piece in data.get("pieces", []):
			var piece_id := int(piece.get("pieceId", -1))
			var key := str(piece_id)
			if piece_id < 0 or not layout_placements.has(key):
				continue
			var origin = layout_placements[key]
			if not origin is Array or not origin_in_list(origin, open_origins.get(key, [])):
				continue
			var touching_cells := _fixed_same_color_neighbors(data, piece, origin)
			if touching_cells.is_empty():
				continue
			correct_candidates.append({
				"pieceId": piece_id,
				"origin": [int(origin[0]), int(origin[1])],
				"regionId": int(piece.get("regionId", -1)),
				"touchingCells": touching_cells,
				"cellCount": (piece.get("cells", []) as Array).size()
			})
	if correct_candidates.is_empty():
		return {}

	correct_candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if int(first["cellCount"]) != int(second["cellCount"]):
			return int(first["cellCount"]) < int(second["cellCount"])
		return int(first["pieceId"]) < int(second["pieceId"])
	)
	for correct in correct_candidates:
		var piece_id := int(correct["pieceId"])
		var wrong := _wrong_connectivity_target(data, piece_id, open_origins.get(str(piece_id), []), correct["origin"])
		if not wrong.is_empty():
			return {"wrong": wrong, "correct": correct}
	for correct in correct_candidates:
		for piece in data.get("pieces", []):
			var piece_id := int(piece.get("pieceId", -1))
			var wrong := _wrong_connectivity_target(data, piece_id, open_origins.get(str(piece_id), []), [])
			if not wrong.is_empty():
				return {"wrong": wrong, "correct": correct}
	return {}


static func _wrong_connectivity_target(
	data: Dictionary,
	piece_id: int,
	origins: Array,
	excluded_origin
) -> Dictionary:
	for raw_origin in origins:
		if not raw_origin is Array or raw_origin.size() < 2:
			continue
		if excluded_origin is Array and origins_equal(raw_origin, excluded_origin):
			continue
		if CompositeLevelScript.placement_disconnects_same_color(data, {}, piece_id, raw_origin):
			var piece := _piece_by_id(data, piece_id)
			return {
				"pieceId": piece_id,
				"origin": [int(raw_origin[0]), int(raw_origin[1])],
				"regionId": int(piece.get("regionId", -1)),
				"cellCount": (piece.get("cells", []) as Array).size()
			}
	return {}


static func _fixed_same_color_neighbors(data: Dictionary, piece: Dictionary, origin: Array) -> Array:
	var result: Array = []
	if origin.size() < 2:
		return result
	var rows := int(data.get("rows", 0))
	var cols := int(data.get("cols", 0))
	var base_regions: Array = data.get("baseRegions", [])
	var construction := {}
	for raw_cell in data.get("constructionCells", []):
		if raw_cell is Array and raw_cell.size() >= 2:
			construction["%d,%d" % [int(raw_cell[0]), int(raw_cell[1])]] = true
	var region_id := int(piece.get("regionId", -1))
	var seen := {}
	for raw_cell in piece.get("cells", []):
		if not raw_cell is Array or raw_cell.size() < 2:
			continue
		var row := int(origin[0]) + int(raw_cell[0])
		var col := int(origin[1]) + int(raw_cell[1])
		for direction in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
			var neighbor_row := row + int(direction[0])
			var neighbor_col := col + int(direction[1])
			if neighbor_row < 0 or neighbor_col < 0 or neighbor_row >= rows or neighbor_col >= cols:
				continue
			var key := "%d,%d" % [neighbor_row, neighbor_col]
			if construction.has(key) or seen.has(key):
				continue
			if neighbor_row < base_regions.size() and neighbor_col < (base_regions[neighbor_row] as Array).size() and int(base_regions[neighbor_row][neighbor_col]) == region_id:
				seen[key] = true
				result.append([neighbor_row, neighbor_col])
	return result


static func _piece_by_id(data: Dictionary, piece_id: int) -> Dictionary:
	for piece in data.get("pieces", []):
		if int(piece.get("pieceId", -1)) == piece_id:
			return piece
	return {}


static func origin_in_list(origin: Array, origins: Array) -> bool:
	for raw_origin in origins:
		if origins_equal(origin, raw_origin):
			return true
	return false


static func origins_equal(first, second) -> bool:
	return (
		first is Array and second is Array
		and first.size() >= 2 and second.size() >= 2
		and int(first[0]) == int(second[0])
		and int(first[1]) == int(second[1])
	)
