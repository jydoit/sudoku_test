class_name CompositeLevel
extends RefCounted

const MAX_VALID_LAYOUTS := 6
const MAX_SEARCH_NODES := 60000
const DATA_VERSION := 9
const MIN_REGION_CELLS := 3
const MIN_STANDARD_PIECE_CELLS := 2
const SPLIT_ATTEMPTS := 3
const PIECE_COUNT_FACTORS := {
	"simple": 0.5,
	"medium": 0.6,
	"hard": 0.8
}
const ORTHOGONAL := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const SURROUNDING := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
]

const SHAPE_TEMPLATES := [
	{"family": "bar", "cells": [[0, 0], [0, 1]]},
	{"family": "bar", "cells": [[0, 0], [0, 1], [0, 2]]},
	{"family": "bar", "cells": [[0, 0], [0, 1], [0, 2], [0, 3]]},
	{"family": "rectangle", "cells": [[0, 0], [0, 1], [1, 0], [1, 1]]},
	{"family": "l", "cells": [[0, 0], [1, 0], [1, 1]]},
	{"family": "l", "cells": [[0, 0], [1, 0], [2, 0], [2, 1]]},
	{"family": "t", "cells": [[0, 0], [0, 1], [0, 2], [1, 1]]},
	{"family": "z", "cells": [[0, 0], [0, 1], [1, 1], [1, 2]]},
	{"family": "z", "cells": [[0, 1], [0, 2], [1, 0], [1, 1]]},
	{"family": "irregular", "cells": [[0, 0], [1, 0], [1, 1], [2, 1], [2, 2]]}
]


static func build(
	level: Dictionary,
	seed: int,
	raw_difficulty_pattern: String = "",
	max_valid_layouts: int = MAX_VALID_LAYOUTS
) -> Dictionary:
	var rows := int(level.get("rows", 0))
	var cols := int(level.get("cols", 0))
	if rows < 6 or rows != cols:
		return {}
	var base_regions: Array = level.get("regions", [])
	if base_regions.size() != rows:
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var difficulty_source := raw_difficulty_pattern if not raw_difficulty_pattern.is_empty() else str(level.get("difficulty", "medium"))
	var difficulty := _normalize_difficulty(difficulty_source)
	var region_cells := _cells_by_region(base_regions)
	var selected_ids := _select_regions(region_cells, base_regions, rng, difficulty)
	if selected_ids.is_empty():
		return {}

	var pieces: Array = []
	var clue_cells: Array = []
	var construction_cells: Array = []
	var next_piece_id := 0
	for region_id in selected_ids:
		var cells: Array = region_cells.get(int(region_id), [])
		var split_result := _split_region_with_clue(cells, base_regions, int(region_id), rng, difficulty)
		var split: Array = split_result.get("pieces", [])
		if split.is_empty():
			return {}
		clue_cells.append_array(split_result.get("clueCells", []))
		for raw_piece in split:
			var absolute_cells: Array = raw_piece
			construction_cells.append_array(absolute_cells)
			var normalized := _normalize_cells(absolute_cells)
			pieces.append({
				"pieceId": next_piece_id,
				"regionId": int(region_id),
				"cells": _cells_to_arrays(normalized["cells"]),
				"initialOrigin": [int(normalized["origin"].y), int(normalized["origin"].x)],
				"trayIndex": next_piece_id,
				"family": _shape_family(normalized["cells"])
			})
			next_piece_id += 1

	construction_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	clue_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)

	var data := {
		"version": DATA_VERSION,
		"seed": seed,
		"difficulty": difficulty,
		"rows": rows,
		"cols": cols,
		"baseRegions": base_regions.duplicate(true),
		"lockedRegionIds": _locked_region_ids(region_cells, selected_ids),
		"selectedRegionIds": selected_ids.duplicate(),
		"clueCells": _cells_to_arrays(clue_cells),
		"constructionCells": _cells_to_arrays(construction_cells),
		"pieces": pieces,
		"validLayouts": []
	}
	_prepare_runtime_cache(data)
	data["validLayouts"] = _enumerate_valid_layouts(data, level.get("solution", []), max_valid_layouts)
	if data["validLayouts"].is_empty():
		return {}
	return data


static func empty_placements() -> Dictionary:
	return {}


static func sanitize_tray_slots(data: Dictionary, placements: Dictionary, raw_slots = []) -> Array:
	var pieces: Array = data.get("pieces", [])
	var region_sizes := {}
	for raw_cell in data.get("constructionCells", []):
		if not raw_cell is Array or raw_cell.size() < 2:
			continue
		var row := int(raw_cell[0])
		var col := int(raw_cell[1])
		var base_regions: Array = data.get("baseRegions", [])
		if row < 0 or row >= base_regions.size() or col < 0 or col >= base_regions[row].size():
			continue
		var region_id := int(base_regions[row][col])
		region_sizes[region_id] = int(region_sizes.get(region_id, 0)) + 1

	var ordered_pieces: Array = pieces.duplicate(true)
	ordered_pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := int(a.get("pieceId", -1))
		var b_id := int(b.get("pieceId", -1))
		var a_placed := placements.has(str(a_id))
		var b_placed := placements.has(str(b_id))
		if a_placed != b_placed:
			return not a_placed
		var a_region := int(a.get("regionId", -1))
		var b_region := int(b.get("regionId", -1))
		var a_region_size := int(region_sizes.get(a_region, 0))
		var b_region_size := int(region_sizes.get(b_region, 0))
		if a_region_size != b_region_size:
			return a_region_size < b_region_size
		if a_region != b_region:
			return a_region < b_region
		var a_cells := (a.get("cells", []) as Array).size()
		var b_cells := (b.get("cells", []) as Array).size()
		if a_cells != b_cells:
			return a_cells < b_cells
		return int(a.get("trayIndex", a_id)) < int(b.get("trayIndex", b_id))
	)
	var result: Array = []
	for piece in ordered_pieces:
		result.append(int(piece.get("pieceId", -1)))
	return result


static func sanitize_placements(data: Dictionary, raw_placements) -> Dictionary:
	var result := {}
	if not raw_placements is Dictionary:
		return result
	for piece in data.get("pieces", []):
		var key := str(int(piece.get("pieceId", -1)))
		var raw = raw_placements.get(key, [])
		if raw is Array and raw.size() >= 2:
			result[key] = [int(raw[0]), int(raw[1])]
	return result


static func allowed_origins(data: Dictionary, placements: Dictionary, piece_id: int) -> Array:
	var occupancy := _placement_occupancy(data, placements)
	if not bool(occupancy.get("valid", false)):
		return []
	return _allowed_origins_from_occupancy(data, piece_id, occupancy.get("owners", {}))


static func allowed_origins_for_all(data: Dictionary, placements: Dictionary) -> Dictionary:
	var occupancy := _placement_occupancy(data, placements)
	if not bool(occupancy.get("valid", false)):
		return {}
	return _allowed_origins_for_all_from_occupancy(data, occupancy.get("owners", {}))


static func matching_layout(data: Dictionary, placements: Dictionary) -> Dictionary:
	if placements.size() != data.get("pieces", []).size():
		return {}
	for layout in data.get("validLayouts", []):
		var layout_placements: Dictionary = layout.get("placements", {})
		var matches := true
		for key in placements.keys():
			if not layout_placements.has(str(key)) or not _origins_equal(layout_placements[str(key)], placements[key]):
				matches = false
				break
		if matches:
			return layout.duplicate(true)
	return _make_layout(data, placements, [])


static func has_valid_completion(data: Dictionary, placements: Dictionary) -> bool:
	var evaluation := evaluate_placement_state(data, placements, false)
	return bool(evaluation.get("valid", false)) and not bool(evaluation.get("deadlocked", true))


static func evaluate_placement_state(
	data: Dictionary,
	placements: Dictionary,
	include_allowed_origins: bool = true
) -> Dictionary:
	var pieces: Array = data.get("pieces", [])
	var occupancy := _placement_occupancy(data, placements)
	if not bool(occupancy.get("valid", false)):
		return {"valid": false, "deadlocked": false, "layout": {}, "allowedByPiece": {}}
	var owners: Dictionary = occupancy.get("owners", {})
	var regions: Dictionary = occupancy.get("regions", {})
	var remaining: Array = []
	for piece in pieces:
		var piece_id := int(piece.get("pieceId", -1))
		var key := str(piece_id)
		if not placements.has(key):
			remaining.append(piece)
	if remaining.is_empty():
		var layout := matching_layout(data, placements)
		return {
			"valid": true,
			"deadlocked": layout.is_empty(),
			"layout": layout,
			"allowedByPiece": {}
		}

	if not _placed_regions_can_still_connect(data, regions):
		return {"valid": true, "deadlocked": true, "layout": {}, "allowedByPiece": {}}
	var allowed := {}
	if include_allowed_origins:
		allowed = _allowed_origins_for_all_from_occupancy(data, owners)
		for piece in remaining:
			var piece_key := str(int(piece.get("pieceId", -1)))
			if allowed.get(piece_key, []).is_empty():
				return {"valid": true, "deadlocked": true, "layout": {}, "allowedByPiece": allowed}
	else:
		for piece in remaining:
			var has_space := false
			var piece_id := int(piece.get("pieceId", -1))
			for origin in _piece_candidate_origins(piece, data.get("constructionCells", [])):
				if _candidate_fits_occupancy(data, piece, origin, owners, piece_id):
					has_space = true
					break
			if not has_space:
				return {"valid": true, "deadlocked": true, "layout": {}, "allowedByPiece": {}}
	return {"valid": true, "deadlocked": false, "layout": {}, "allowedByPiece": allowed}


static func placement_disconnects_same_color(
	data: Dictionary,
	placements: Dictionary,
	piece_id: int,
	origin: Array
) -> bool:
	if origin.size() < 2:
		return false
	var candidate := placements.duplicate(true)
	candidate[str(piece_id)] = [int(origin[0]), int(origin[1])]
	var occupancy := _placement_occupancy(data, candidate)
	if not bool(occupancy.get("valid", false)):
		return false
	return not _placed_regions_can_still_connect(data, occupancy.get("regions", {}))


static func _placed_regions_can_still_connect(data: Dictionary, occupied_regions: Dictionary) -> bool:
	var base_regions: Array = data.get("baseRegions", [])
	var rows := int(data.get("rows", base_regions.size()))
	var cols := int(data.get("cols", base_regions[0].size() if not base_regions.is_empty() else 0))
	var construction_set: Dictionary = data.get("constructionIndexSet", {})
	if construction_set.is_empty():
		construction_set = _construction_index_set(data)
	var fixed_by_region: Dictionary = data.get("fixedIndicesBySelectedRegion", {})
	if fixed_by_region.is_empty():
		for raw_region_id in data.get("selectedRegionIds", []):
			fixed_by_region[str(int(raw_region_id))] = []
		for row in range(base_regions.size()):
			for col in range(base_regions[row].size()):
				var region_id := int(base_regions[row][col])
				var key := str(region_id)
				var index := row * cols + col
				if fixed_by_region.has(key) and not construction_set.has(index):
					fixed_by_region[key].append(index)
	for raw_region_id in data.get("selectedRegionIds", []):
		var region_id := int(raw_region_id)
		var mandatory: Array = fixed_by_region.get(str(region_id), []).duplicate()
		var passable := {}
		for index in mandatory:
			passable[int(index)] = true
		for raw_index in construction_set.keys():
			var index := int(raw_index)
			if not occupied_regions.has(index) or int(occupied_regions[index]) == region_id:
				passable[index] = true
			if occupied_regions.has(index) and int(occupied_regions[index]) == region_id:
				mandatory.append(index)
		if mandatory.size() <= 1:
			continue
		var visited := {int(mandatory[0]): true}
		var queue: Array = [int(mandatory[0])]
		var cursor := 0
		while cursor < queue.size():
			var current := int(queue[cursor])
			cursor += 1
			var row := int(current / cols)
			var col := current % cols
			var neighbors: Array = []
			if row > 0:
				neighbors.append(current - cols)
			if row + 1 < rows:
				neighbors.append(current + cols)
			if col > 0:
				neighbors.append(current - 1)
			if col + 1 < cols:
				neighbors.append(current + 1)
			for neighbor in neighbors:
				var neighbor_index := int(neighbor)
				if passable.has(neighbor_index) and not visited.has(neighbor_index):
					visited[neighbor_index] = true
					queue.append(neighbor_index)
		for index in mandatory:
			if not visited.has(int(index)):
				return false
	return true


static func _prepare_runtime_cache(data: Dictionary) -> void:
	var cols := int(data.get("cols", 0))
	var construction_set := _construction_index_set(data)
	data["constructionIndexSet"] = construction_set
	var fixed_by_region := {}
	var selected := {}
	for raw_region_id in data.get("selectedRegionIds", []):
		var region_id := int(raw_region_id)
		selected[region_id] = true
		fixed_by_region[str(region_id)] = []
	var base_regions: Array = data.get("baseRegions", [])
	for row in range(base_regions.size()):
		for col in range(base_regions[row].size()):
			var region_id := int(base_regions[row][col])
			var index := row * cols + col
			if selected.has(region_id) and not construction_set.has(index):
				fixed_by_region[str(region_id)].append(index)
	data["fixedIndicesBySelectedRegion"] = fixed_by_region

	var pieces: Array = data.get("pieces", [])
	for piece_index in range(pieces.size()):
		var piece: Dictionary = pieces[piece_index]
		var origins := _compute_piece_candidate_origins(piece, data.get("constructionCells", []))
		var cells_by_origin := {}
		for origin in origins:
			var indices: Array = []
			for cell in _piece_absolute_cells(piece, origin):
				indices.append(_cell_index(cell, cols))
			cells_by_origin[_array_origin_key(origin)] = indices
		piece["candidateOrigins"] = origins
		piece["candidateCellIndices"] = cells_by_origin
		pieces[piece_index] = piece
	data["pieces"] = pieces


static func _construction_index_set(data: Dictionary) -> Dictionary:
	var cols := int(data.get("cols", 0))
	var result := {}
	for cell in _arrays_to_cells(data.get("constructionCells", [])):
		result[_cell_index(cell, cols)] = true
	return result


static func _placement_occupancy(data: Dictionary, placements: Dictionary) -> Dictionary:
	var owners := {}
	var regions := {}
	var placed_piece_count := 0
	for piece in data.get("pieces", []):
		var piece_id := int(piece.get("pieceId", -1))
		var key := str(piece_id)
		if not placements.has(key):
			continue
		var origin = placements[key]
		if not origin is Array or origin.size() < 2:
			return {"valid": false}
		var indices := _candidate_indices_for_origin(data, piece, origin)
		if indices.is_empty():
			return {"valid": false}
		for raw_index in indices:
			var index := int(raw_index)
			if owners.has(index):
				return {"valid": false}
			owners[index] = piece_id
			regions[index] = int(piece.get("regionId", -1))
		placed_piece_count += 1
	if placed_piece_count != placements.size():
		return {"valid": false}
	return {
		"valid": true,
		"owners": owners,
		"regions": regions
	}


static func _allowed_origins_for_all_from_occupancy(data: Dictionary, owners: Dictionary) -> Dictionary:
	var result := {}
	for piece in data.get("pieces", []):
		var piece_id := int(piece.get("pieceId", -1))
		result[str(piece_id)] = _allowed_origins_from_occupancy(data, piece_id, owners)
	return result


static func _allowed_origins_from_occupancy(data: Dictionary, piece_id: int, owners: Dictionary) -> Array:
	var piece := _piece_by_id(data.get("pieces", []), piece_id)
	if piece.is_empty():
		return []
	var result: Array = []
	for origin in _piece_candidate_origins(piece, data.get("constructionCells", [])):
		if _candidate_fits_occupancy(data, piece, origin, owners, piece_id):
			result.append([int(origin[0]), int(origin[1])])
	return result


static func _candidate_fits_occupancy(
	data: Dictionary,
	piece: Dictionary,
	origin: Array,
	owners: Dictionary,
	piece_id: int
) -> bool:
	var indices := _candidate_indices_for_origin(data, piece, origin)
	if indices.is_empty():
		return false
	for raw_index in indices:
		var index := int(raw_index)
		if owners.has(index) and int(owners[index]) != piece_id:
			return false
	return true


static func _candidate_indices_for_origin(data: Dictionary, piece: Dictionary, origin: Array) -> Array:
	if not origin is Array or origin.size() < 2:
		return []
	var cached = piece.get("candidateCellIndices", {})
	var key := _array_origin_key(origin)
	if cached is Dictionary and cached.has(key):
		return cached[key]
	var construction_set: Dictionary = data.get("constructionIndexSet", {})
	if construction_set.is_empty():
		construction_set = _construction_index_set(data)
	var cols := int(data.get("cols", 0))
	var result: Array = []
	for cell in _piece_absolute_cells(piece, origin):
		var index := _cell_index(cell, cols)
		if not construction_set.has(index):
			return []
		result.append(index)
	return result


static func _cell_index(cell: Vector2i, cols: int) -> int:
	return cell.y * cols + cell.x


static func _select_regions(
	region_cells: Dictionary,
	regions: Array,
	rng: RandomNumberGenerator,
	raw_difficulty: String = "medium"
) -> Array:
	var difficulty := _normalize_difficulty(raw_difficulty)
	var eligible_ids: Array = []
	for region_id in region_cells.keys():
		if region_cells[region_id].size() >= MIN_REGION_CELLS:
			eligible_ids.append(int(region_id))
	if eligible_ids.is_empty():
		return []
	eligible_ids.sort()

	if difficulty == "simple" and (eligible_ids.size() < 2 or rng.randf() < 0.55):
		return [_largest_region_id(eligible_ids, region_cells, rng)]

	var desired_count := 3 if difficulty == "hard" else 2
	if eligible_ids.size() < desired_count:
		return [_largest_region_id(eligible_ids, region_cells, rng)] if difficulty == "simple" else []
	var adjacency := _region_adjacency(regions, eligible_ids)
	var groups := _adjacent_region_groups(eligible_ids, adjacency, desired_count)
	if groups.is_empty():
		return [_largest_region_id(eligible_ids, region_cells, rng)] if difficulty == "simple" else []

	var scored: Array = []
	for ids in groups:
		var coverage := 0
		var combined: Array = []
		var spread := 0.0
		for region_id in ids:
			coverage += region_cells[int(region_id)].size()
			combined.append_array(region_cells[int(region_id)])
		for first_index in range(ids.size()):
			for second_index in range(first_index + 1, ids.size()):
				spread += _cells_center(region_cells[int(ids[first_index])]).distance_to(
					_cells_center(region_cells[int(ids[second_index])])
				)
		var bounds := _cell_bounds(combined)
		spread += float(bounds.size.x + bounds.size.y)
		scored.append({"ids": ids.duplicate(), "coverage": coverage, "score": float(coverage) + spread})

	if difficulty == "simple":
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["coverage"]) < int(b["coverage"])
		)
		var minimum_coverage := int(scored[0]["coverage"])
		var smallest: Array = scored.filter(func(candidate: Dictionary) -> bool:
			return int(candidate["coverage"]) == minimum_coverage
		)
		return smallest[rng.randi_range(0, smallest.size() - 1)]["ids"]

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	var best_score := float(scored[0]["score"])
	var best: Array = scored.filter(func(candidate: Dictionary) -> bool:
		return is_equal_approx(float(candidate["score"]), best_score)
	)
	return best[rng.randi_range(0, best.size() - 1)]["ids"]


static func _largest_region_id(region_ids: Array, region_cells: Dictionary, rng: RandomNumberGenerator) -> int:
	var largest_size := 0
	var largest_ids: Array = []
	for region_id in region_ids:
		var cell_count: int = region_cells[int(region_id)].size()
		if cell_count > largest_size:
			largest_size = cell_count
			largest_ids = [int(region_id)]
		elif cell_count == largest_size:
			largest_ids.append(int(region_id))
	return int(largest_ids[rng.randi_range(0, largest_ids.size() - 1)])


static func _region_adjacency(regions: Array, eligible_ids: Array) -> Dictionary:
	var eligible := {}
	var adjacency := {}
	for region_id in eligible_ids:
		eligible[int(region_id)] = true
		adjacency[int(region_id)] = {}
	for row in range(regions.size()):
		for col in range(regions[row].size()):
			var first := int(regions[row][col])
			if not eligible.has(first):
				continue
			for offset in [Vector2i.RIGHT, Vector2i.DOWN]:
				var neighbor: Vector2i = Vector2i(col, row) + offset
				if neighbor.y >= regions.size() or neighbor.x >= regions[neighbor.y].size():
					continue
				var second := int(regions[neighbor.y][neighbor.x])
				if first == second or not eligible.has(second):
					continue
				adjacency[first][second] = true
				adjacency[second][first] = true
	return adjacency


static func _adjacent_region_groups(region_ids: Array, adjacency: Dictionary, desired_count: int) -> Array:
	var combinations: Array = []
	_collect_region_combinations(region_ids, desired_count, 0, [], combinations)
	var result: Array = []
	for ids in combinations:
		if _region_group_connected(ids, adjacency):
			result.append(ids)
	return result


static func _collect_region_combinations(values: Array, desired_count: int, start: int, current: Array, result: Array) -> void:
	if current.size() == desired_count:
		result.append(current.duplicate())
		return
	var remaining_needed := desired_count - current.size()
	for index in range(start, values.size() - remaining_needed + 1):
		current.append(int(values[index]))
		_collect_region_combinations(values, desired_count, index + 1, current, result)
		current.pop_back()


static func _region_group_connected(region_ids: Array, adjacency: Dictionary) -> bool:
	if region_ids.is_empty():
		return false
	var allowed := {}
	for region_id in region_ids:
		allowed[int(region_id)] = true
	var visited := {int(region_ids[0]): true}
	var queue: Array = [int(region_ids[0])]
	while not queue.is_empty():
		var current := int(queue.pop_front())
		for raw_neighbor in adjacency.get(current, {}).keys():
			var neighbor := int(raw_neighbor)
			if allowed.has(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return visited.size() == allowed.size()


static func _select_clue_cell(cells: Array, regions: Array, region_id: int, rng: RandomNumberGenerator) -> Vector2i:
	var cell_set := _cell_set(cells)
	var edge_cells: Array = []
	for cell in cells:
		var is_edge := false
		for direction in ORTHOGONAL:
			if not cell_set.has(_cell_key(cell + direction)):
				is_edge = true
				break
		if is_edge and not _is_articulation_cell(cells, cell):
			edge_cells.append(cell)
	if edge_cells.is_empty():
		return Vector2i(-1, -1)
	var candidates: Array = edge_cells

	var best_score := -1
	var best_same_color_score := -1
	var best: Array = []
	for cell in candidates:
		var score := _row_column_different_color_max(cell, regions, region_id)
		var same_color_score := _same_color_neighbor_count(cell, cell_set)
		if score > best_score or (score == best_score and same_color_score > best_same_color_score):
			best_score = score
			best_same_color_score = same_color_score
			best = [cell]
		elif score == best_score and same_color_score == best_same_color_score:
			best.append(cell)
	return best[rng.randi_range(0, best.size() - 1)]


static func _is_articulation_cell(cells: Array, cell: Vector2i) -> bool:
	var remaining := _subtract_cells(cells, [cell])
	return not remaining.is_empty() and not _cells_connected(remaining)


static func _row_column_different_color_max(cell: Vector2i, regions: Array, region_id: int) -> int:
	var row_count := 0
	for col in range(regions[cell.y].size()):
		if col != cell.x and int(regions[cell.y][col]) != region_id:
			row_count += 1
	var column_count := 0
	for row in range(regions.size()):
		if row != cell.y and cell.x < regions[row].size() and int(regions[row][cell.x]) != region_id:
			column_count += 1
	return maxi(row_count, column_count)


static func _same_color_neighbor_count(cell: Vector2i, cell_set: Dictionary) -> int:
	var result := 0
	for direction in SURROUNDING:
		if cell_set.has(_cell_key(cell + direction)):
			result += 1
	return result


static func _desired_piece_count(cell_count: int, raw_difficulty: String) -> int:
	if cell_count <= 0:
		return 0
	var difficulty := _normalize_difficulty(raw_difficulty)
	var factor := float(PIECE_COUNT_FACTORS[difficulty])
	var desired := ceili((float(cell_count) / float(MIN_STANDARD_PIECE_CELLS)) * factor)
	var maximum_without_unit := maxi(1, floori(float(cell_count) / float(MIN_STANDARD_PIECE_CELLS)))
	return clampi(desired, 1, maximum_without_unit)


static func _split_region_with_clue(
	cells: Array,
	regions: Array,
	region_id: int,
	rng: RandomNumberGenerator,
	difficulty: String
) -> Dictionary:
	if cells.size() < MIN_REGION_CELLS:
		return {}
	var clue := _select_clue_cell(cells, regions, region_id, rng)
	if clue.x < 0 or clue.y < 0:
		return {}
	var remaining := _subtract_cells(cells, [clue])
	var desired_count := _desired_piece_count(remaining.size(), difficulty)
	for _attempt in range(SPLIT_ATTEMPTS):
		var split := _split_region_from_clue(remaining, clue, desired_count, rng, difficulty, false)
		if not split.is_empty():
			return {"clueCells": [clue], "pieces": split}
	var singleton_fallback := _split_region_from_clue(remaining, clue, desired_count, rng, difficulty, true)
	if singleton_fallback.is_empty():
		singleton_fallback = [remaining]
	return {"clueCells": [clue], "pieces": singleton_fallback}


static func _split_region_from_clue(
	cells: Array,
	clue: Vector2i,
	piece_count: int,
	rng: RandomNumberGenerator,
	difficulty: String,
	allow_singleton: bool
) -> Array:
	if cells.is_empty() or piece_count < 1:
		return []
	if piece_count == 1:
		return [cells.duplicate()] if _cells_connected(cells) else []
	var remaining: Array = cells.duplicate()
	var result: Array = []
	var filled: Array = [clue]
	for index in range(piece_count - 1):
		var remaining_piece_count := piece_count - index - 1
		var minimum_remaining := remaining_piece_count * MIN_STANDARD_PIECE_CELLS
		if allow_singleton:
			minimum_remaining -= 1
		var max_take := remaining.size() - minimum_remaining
		if max_take < MIN_STANDARD_PIECE_CELLS:
			return []
		var candidates := _template_cut_candidates(remaining, filled, difficulty, max_take)
		if candidates.is_empty():
			var fallback := _random_growth_cut(remaining, filled, max_take, rng)
			if fallback.is_empty():
				return []
			candidates.append(fallback)
		var picked: Array = candidates[_weighted_candidate_index(candidates, difficulty, rng)].get("cells", [])
		result.append(picked)
		remaining = _subtract_cells(remaining, picked)
		filled.append_array(picked)
	if remaining.is_empty() or (remaining.size() == 1 and not allow_singleton):
		return []
	if not _cells_connected(remaining):
		return []
	result.append(remaining)
	return result


static func _template_cut_candidates(remaining: Array, filled: Array, difficulty: String, max_take: int) -> Array:
	var remaining_set := _cell_set(remaining)
	var min_row := 999
	var min_col := 999
	var max_row := -1
	var max_col := -1
	for cell in remaining:
		min_row = mini(min_row, cell.y)
		max_row = maxi(max_row, cell.y)
		min_col = mini(min_col, cell.x)
		max_col = maxi(max_col, cell.x)
	var candidates: Array = []
	var seen := {}
	for template in SHAPE_TEMPLATES:
		var family := str(template.get("family", "irregular"))
		for rotated in _rotations(_arrays_to_cells(template.get("cells", []))):
			if rotated.size() > max_take:
				continue
			var bounds := _cell_bounds(rotated)
			for row in range(min_row - int(bounds.position.y), max_row - int(bounds.end.y) + 2):
				for col in range(min_col - int(bounds.position.x), max_col - int(bounds.end.x) + 2):
					var placed: Array = []
					var fits := true
					for local_cell in rotated:
						var absolute := Vector2i(col + local_cell.x, row + local_cell.y)
						if not remaining_set.has(_cell_key(absolute)):
							fits = false
							break
						placed.append(absolute)
					if not fits:
						continue
					if not _touches_any(placed, filled):
						continue
					var key := _cells_signature(placed)
					if seen.has(key):
						continue
					seen[key] = true
					candidates.append({"cells": placed, "family": family, "weight": _family_weight(family, difficulty)})
	return candidates


static func _random_growth_cut(remaining: Array, filled: Array, max_take: int, rng: RandomNumberGenerator) -> Dictionary:
	for _attempt in range(80):
		var starts: Array = []
		for cell in remaining:
			if _touches_any([cell], filled):
				starts.append(cell)
		if starts.is_empty():
			return {}
		var maximum := mini(max_take, remaining.size() - 1)
		if maximum < MIN_STANDARD_PIECE_CELLS:
			return {}
		var target_size := rng.randi_range(MIN_STANDARD_PIECE_CELLS, maximum)
		var selected: Array = [starts[rng.randi_range(0, starts.size() - 1)]]
		var selected_set := _cell_set(selected)
		while selected.size() < target_size:
			var frontier: Array = []
			for cell in selected:
				for direction in ORTHOGONAL:
					var candidate: Vector2i = cell + direction
					if _array_has_cell(remaining, candidate) and not selected_set.has(_cell_key(candidate)):
						frontier.append(candidate)
			if frontier.is_empty():
				break
			var next: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
			selected.append(next)
			selected_set[_cell_key(next)] = true
		if selected.size() >= MIN_STANDARD_PIECE_CELLS and selected.size() < remaining.size():
			return {"cells": selected, "family": "irregular", "weight": 1.0}
	return {}


static func _touches_any(cells: Array, other_cells: Array) -> bool:
	var other_set := _cell_set(other_cells)
	for cell in cells:
		for direction in ORTHOGONAL:
			if other_set.has(_cell_key(cell + direction)):
				return true
	return false


static func _enumerate_valid_layouts(
	data: Dictionary,
	original_solution: Array,
	max_valid_layouts: int = MAX_VALID_LAYOUTS
) -> Array:
	var layout_limit := clampi(max_valid_layouts, 1, MAX_VALID_LAYOUTS)
	var layouts: Array = []
	var initial_placements := {}
	for piece in data.get("pieces", []):
		initial_placements[str(int(piece["pieceId"]))] = piece["initialOrigin"].duplicate()
	var initial := _make_layout(data, initial_placements, original_solution)
	if not initial.is_empty():
		layouts.append(initial)

	var candidate_origins := {}
	for piece in data.get("pieces", []):
		candidate_origins[str(int(piece["pieceId"]))] = _piece_candidate_origins(piece, data.get("constructionCells", []))
	var order: Array = data.get("pieces", []).duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return candidate_origins[str(int(a["pieceId"]))].size() < candidate_origins[str(int(b["pieceId"]))].size()
	)
	var state := {
		"nodes": 0,
		"signatures": {},
		"maxLayouts": layout_limit,
		"maxNodes": MAX_SEARCH_NODES
	}
	for layout in layouts:
		state["signatures"][str(layout.get("signature", ""))] = true
	_search_layouts(data, order, 0, {}, {}, candidate_origins, layouts, state)
	return layouts


static func _search_layouts(
	data: Dictionary,
	order: Array,
	index: int,
	placements: Dictionary,
	occupied: Dictionary,
	candidate_origins: Dictionary,
	layouts: Array,
	state: Dictionary
) -> void:
	var layout_limit := int(state.get("maxLayouts", MAX_VALID_LAYOUTS))
	var node_limit := int(state.get("maxNodes", MAX_SEARCH_NODES))
	if layouts.size() >= layout_limit or int(state["nodes"]) >= node_limit:
		return
	state["nodes"] = int(state["nodes"]) + 1
	if index >= order.size():
		var layout := _make_layout(data, placements, [])
		if layout.is_empty():
			return
		var signature := str(layout["signature"])
		if not state["signatures"].has(signature):
			state["signatures"][signature] = true
			layouts.append(layout)
		return

	var piece: Dictionary = order[index]
	var piece_key := str(int(piece["pieceId"]))
	for origin in candidate_origins[piece_key]:
		var occupied_cells := _piece_absolute_cells(piece, origin)
		var overlaps := false
		for cell in occupied_cells:
			if occupied.has(_cell_key(cell)):
				overlaps = true
				break
		if overlaps:
			continue
		placements[piece_key] = [int(origin[0]), int(origin[1])]
		for cell in occupied_cells:
			occupied[_cell_key(cell)] = true
		_search_layouts(data, order, index + 1, placements, occupied, candidate_origins, layouts, state)
		for cell in occupied_cells:
			occupied.erase(_cell_key(cell))
		placements.erase(piece_key)
		if layouts.size() >= layout_limit:
			return


static func _make_layout(data: Dictionary, placements: Dictionary, known_solution: Array) -> Dictionary:
	if placements.size() != data.get("pieces", []).size():
		return {}
	var regions: Array = data.get("baseRegions", []).duplicate(true)
	var construction_set := _cell_set(_arrays_to_cells(data.get("constructionCells", [])))
	var filled := {}
	for piece in data.get("pieces", []):
		var key := str(int(piece["pieceId"]))
		if not placements.has(key):
			return {}
		for cell in _piece_absolute_cells(piece, placements[key]):
			var cell_key := _cell_key(cell)
			if not construction_set.has(cell_key) or filled.has(cell_key):
				return {}
			filled[cell_key] = true
			regions[cell.y][cell.x] = int(piece["regionId"])
	if filled.size() != construction_set.size():
		return {}
	for region_id in data.get("selectedRegionIds", []):
		if not _region_connected(regions, int(region_id)):
			return {}

	var solutions: Array = []
	if not known_solution.is_empty() and _solution_valid(regions, known_solution):
		solutions = _solve_regions(regions, 2)
	else:
		solutions = _solve_regions(regions, 2)
	if solutions.size() != 1:
		return {}
	var serialized_placements := {}
	for key in placements.keys():
		var origin: Array = placements[key]
		serialized_placements[str(key)] = [int(origin[0]), int(origin[1])]
	return {
		"signature": _regions_signature(regions),
		"placements": serialized_placements,
		"regions": regions,
		"solution": solutions[0]
	}


static func _solve_regions(regions: Array, limit: int = 2) -> Array:
	var rows: int = regions.size()
	if rows == 0:
		return []
	var cols: int = regions[0].size()
	if rows != cols:
		return []
	var state := {
		"assignedRows": {},
		"usedCols": {},
		"usedRegions": {},
		"placedByRow": {},
		"solutions": [],
		"limit": limit
	}
	_search_crowns(regions, state, 0)
	return state["solutions"]


static func _search_crowns(regions: Array, state: Dictionary, depth: int) -> void:
	if state["solutions"].size() >= int(state["limit"]):
		return
	var rows := regions.size()
	if depth == rows:
		if state["usedRegions"].size() != rows:
			return
		var solution: Array = []
		for row in range(rows):
			solution.append([row, int(state["placedByRow"][row])])
		state["solutions"].append(solution)
		return

	var next_row := -1
	var next_options: Array = []
	for row in range(rows):
		if state["assignedRows"].has(row):
			continue
		var options: Array = []
		for col in range(regions[row].size()):
			if state["usedCols"].has(col):
				continue
			var region_id := int(regions[row][col])
			if state["usedRegions"].has(region_id):
				continue
			var adjacent := false
			for placed_row in state["placedByRow"].keys():
				if absi(int(placed_row) - row) <= 1 and absi(int(state["placedByRow"][placed_row]) - col) <= 1:
					adjacent = true
					break
			if not adjacent:
				options.append(col)
		if options.is_empty():
			return
		if next_row < 0 or options.size() < next_options.size():
			next_row = row
			next_options = options

	state["assignedRows"][next_row] = true
	for col in next_options:
		var region_id := int(regions[next_row][col])
		state["usedCols"][col] = true
		state["usedRegions"][region_id] = true
		state["placedByRow"][next_row] = col
		_search_crowns(regions, state, depth + 1)
		state["placedByRow"].erase(next_row)
		state["usedRegions"].erase(region_id)
		state["usedCols"].erase(col)
		if state["solutions"].size() >= int(state["limit"]):
			break
	state["assignedRows"].erase(next_row)


static func _piece_candidate_origins(piece: Dictionary, construction_arrays: Array) -> Array:
	if piece.has("candidateOrigins"):
		return piece.get("candidateOrigins", [])
	return _compute_piece_candidate_origins(piece, construction_arrays)


static func _compute_piece_candidate_origins(piece: Dictionary, construction_arrays: Array) -> Array:
	var construction := _arrays_to_cells(construction_arrays)
	var construction_set := _cell_set(construction)
	var local_cells := _arrays_to_cells(piece.get("cells", []))
	var result: Array = []
	var seen := {}
	for target in construction:
		for local_anchor in local_cells:
			var origin: Vector2i = target - local_anchor
			var fits := true
			for local_cell in local_cells:
				if not construction_set.has(_cell_key(origin + local_cell)):
					fits = false
					break
			if fits:
				var key := _cell_key(origin)
				if not seen.has(key):
					seen[key] = true
					result.append([origin.y, origin.x])
	return result


static func _piece_by_id(pieces: Array, piece_id: int) -> Dictionary:
	for piece in pieces:
		if int(piece.get("pieceId", -1)) == piece_id:
			return piece
	return {}


static func _piece_absolute_cells(piece: Dictionary, origin_array: Array) -> Array:
	var origin := Vector2i(int(origin_array[1]), int(origin_array[0]))
	var result: Array = []
	for local_cell in _arrays_to_cells(piece.get("cells", [])):
		result.append(origin + local_cell)
	return result


static func _solution_valid(regions: Array, solution: Array) -> bool:
	if solution.size() != regions.size():
		return false
	var rows := {}
	var cols := {}
	var region_ids := {}
	var positions: Array = []
	for raw in solution:
		if not raw is Array or raw.size() < 2:
			return false
		var row := int(raw[0])
		var col := int(raw[1])
		if row < 0 or row >= regions.size() or col < 0 or col >= regions[row].size():
			return false
		var region_id := int(regions[row][col])
		if rows.has(row) or cols.has(col) or region_ids.has(region_id):
			return false
		for position in positions:
			if absi(position.y - row) <= 1 and absi(position.x - col) <= 1:
				return false
		rows[row] = true
		cols[col] = true
		region_ids[region_id] = true
		positions.append(Vector2i(col, row))
	return true


static func _cells_by_region(regions: Array) -> Dictionary:
	var result := {}
	for row in range(regions.size()):
		for col in range(regions[row].size()):
			var region_id := int(regions[row][col])
			if not result.has(region_id):
				result[region_id] = []
			result[region_id].append(Vector2i(col, row))
	return result


static func _cells_center(cells: Array) -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for cell in cells:
		total += Vector2(cell.x, cell.y)
	return total / float(cells.size())


static func _locked_region_ids(region_cells: Dictionary, selected_ids: Array) -> Array:
	var result: Array = []
	for region_id in region_cells.keys():
		if not selected_ids.has(int(region_id)):
			result.append(int(region_id))
	result.sort()
	return result


static func _region_connected(regions: Array, region_id: int) -> bool:
	var cells: Array = []
	for row in range(regions.size()):
		for col in range(regions[row].size()):
			if int(regions[row][col]) == region_id:
				cells.append(Vector2i(col, row))
	return _cells_connected(cells)


static func _cells_connected(cells: Array) -> bool:
	if cells.is_empty():
		return false
	var allowed := _cell_set(cells)
	var visited := {_cell_key(cells[0]): true}
	var queue: Array = [cells[0]]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction in ORTHOGONAL:
			var neighbor: Vector2i = cell + direction
			var key := _cell_key(neighbor)
			if allowed.has(key) and not visited.has(key):
				visited[key] = true
				queue.append(neighbor)
	return visited.size() == allowed.size()


static func _normalize_cells(cells: Array) -> Dictionary:
	var min_col := 999
	var min_row := 999
	for cell in cells:
		min_col = mini(min_col, cell.x)
		min_row = mini(min_row, cell.y)
	var normalized: Array = []
	for cell in cells:
		normalized.append(Vector2i(cell.x - min_col, cell.y - min_row))
	normalized.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return {"origin": Vector2i(min_col, min_row), "cells": normalized}


static func _rotations(cells: Array) -> Array:
	var result: Array = []
	var seen := {}
	var current: Array = cells.duplicate()
	for _turn in range(4):
		var normalized: Array = _normalize_cells(current)["cells"]
		var signature := _cells_signature(normalized)
		if not seen.has(signature):
			seen[signature] = true
			result.append(normalized)
		var rotated: Array = []
		for cell in current:
			rotated.append(Vector2i(-cell.y, cell.x))
		current = rotated
	return result


static func _shape_family(cells: Array) -> String:
	var normalized_signature := _cells_signature(_normalize_cells(cells)["cells"])
	for template in SHAPE_TEMPLATES:
		var family := str(template.get("family", "irregular"))
		if family != "z":
			continue
		for rotation in _rotations(_arrays_to_cells(template.get("cells", []))):
			if _cells_signature(rotation) == normalized_signature:
				return "z"
	var bounds := _cell_bounds(cells)
	if cells.size() == int(bounds.size.x * bounds.size.y):
		return "rectangle" if bounds.size.x > 1 and bounds.size.y > 1 else "bar"
	if cells.size() >= 3:
		var degrees: Array = []
		var set := _cell_set(cells)
		for cell in cells:
			var degree := 0
			for direction in ORTHOGONAL:
				if set.has(_cell_key(cell + direction)):
					degree += 1
			degrees.append(degree)
		if degrees.has(3):
			return "t"
		if bounds.size.x >= 2 and bounds.size.y >= 2 and degrees.count(1) == 2:
			return "l"
	return "irregular"


static func _family_weight(family: String, difficulty: String) -> float:
	if difficulty == "simple":
		return 4.0 if family == "rectangle" or family == "bar" else 1.2
	if difficulty == "hard":
		return 3.4 if family == "l" or family == "z" or family == "irregular" else 1.4
	return 2.6 if family == "l" or family == "z" else 2.0


static func _normalize_difficulty(raw_difficulty: String) -> String:
	var difficulty := raw_difficulty.to_lower()
	if difficulty == "simple":
		return "simple"
	if difficulty == "hard" or difficulty == "challenge":
		return "hard"
	return "medium"


static func _weighted_candidate_index(candidates: Array, difficulty: String, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for candidate in candidates:
		total += float(candidate.get("weight", _family_weight(str(candidate.get("family", "irregular")), difficulty)))
	var pick := rng.randf() * maxf(total, 0.001)
	for index in range(candidates.size()):
		pick -= float(candidates[index].get("weight", 1.0))
		if pick <= 0.0:
			return index
	return candidates.size() - 1


static func _subtract_cells(source: Array, removed: Array) -> Array:
	var removed_set := _cell_set(removed)
	var result: Array = []
	for cell in source:
		if not removed_set.has(_cell_key(cell)):
			result.append(cell)
	return result


static func _cell_bounds(cells: Array) -> Rect2i:
	var min_col := 999
	var min_row := 999
	var max_col := -1
	var max_row := -1
	for cell in cells:
		min_col = mini(min_col, cell.x)
		min_row = mini(min_row, cell.y)
		max_col = maxi(max_col, cell.x)
		max_row = maxi(max_row, cell.y)
	return Rect2i(min_col, min_row, max_col - min_col + 1, max_row - min_row + 1)


static func _cell_set(cells: Array) -> Dictionary:
	var result := {}
	for cell in cells:
		result[_cell_key(cell)] = true
	return result


static func _array_has_cell(cells: Array, target: Vector2i) -> bool:
	for cell in cells:
		if cell == target:
			return true
	return false


static func _cells_signature(cells: Array) -> String:
	var keys: Array[String] = []
	for cell in cells:
		keys.append(_cell_key(cell))
	keys.sort()
	return ";".join(keys)


static func _regions_signature(regions: Array) -> String:
	var rows: Array[String] = []
	for row in regions:
		var values: Array[String] = []
		for value in row:
			values.append(str(int(value)))
		rows.append(",".join(values))
	return "|".join(rows)


static func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.y, cell.x]


static func _array_origin_key(origin: Array) -> String:
	return "%d,%d" % [int(origin[0]), int(origin[1])]


static func _origins_equal(first, second) -> bool:
	return first is Array and second is Array and first.size() >= 2 and second.size() >= 2 and int(first[0]) == int(second[0]) and int(first[1]) == int(second[1])


static func _arrays_to_cells(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value is Array and value.size() >= 2:
			result.append(Vector2i(int(value[1]), int(value[0])))
	return result


static func _cells_to_arrays(cells: Array) -> Array:
	var result: Array = []
	for cell in cells:
		result.append([cell.y, cell.x])
	return result
