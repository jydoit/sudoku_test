class_name CompositeLevel
extends RefCounted

const MAX_VALID_LAYOUTS := 6
const MAX_SEARCH_NODES := 60000
const MIN_REGION_CELLS := 3
const MIN_STANDARD_PIECE_CELLS := 2
const SPLIT_ATTEMPTS := 3
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


static func build(level: Dictionary, seed: int) -> Dictionary:
	var rows := int(level.get("rows", 0))
	var cols := int(level.get("cols", 0))
	if rows < 6 or rows != cols:
		return {}
	var base_regions: Array = level.get("regions", [])
	if base_regions.size() != rows:
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var difficulty := _normalize_difficulty(str(level.get("difficulty", "medium")))
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
		var split_result := _split_region_with_clue(cells, rng, difficulty)
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
		"version": 3,
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
	data["validLayouts"] = _enumerate_valid_layouts(data, level.get("solution", []))
	if data["validLayouts"].is_empty():
		return {}
	return data


static func empty_placements() -> Dictionary:
	return {}


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
	var result: Array = []
	var seen := {}
	var piece_key := str(piece_id)
	for layout in data.get("validLayouts", []):
		var layout_placements: Dictionary = layout.get("placements", {})
		var compatible := true
		for placed_key in placements.keys():
			if str(placed_key) == piece_key:
				continue
			if not layout_placements.has(str(placed_key)) or not _origins_equal(layout_placements[str(placed_key)], placements[placed_key]):
				compatible = false
				break
		if not compatible or not layout_placements.has(piece_key):
			continue
		var origin: Array = layout_placements[piece_key]
		var origin_key := _array_origin_key(origin)
		if not seen.has(origin_key):
			seen[origin_key] = true
			result.append([int(origin[0]), int(origin[1])])
	return result


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
	return {}


static func _select_regions(region_cells: Dictionary, regions: Array, rng: RandomNumberGenerator, raw_difficulty: String = "medium") -> Array:
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


static func _select_clue_cell(cells: Array, raw_difficulty: String, rng: RandomNumberGenerator) -> Vector2i:
	var difficulty := _normalize_difficulty(raw_difficulty)
	var cell_set := _cell_set(cells)
	var edge_cells: Array = []
	var interior_cells: Array = []
	for cell in cells:
		var interior := true
		for direction in ORTHOGONAL:
			if not cell_set.has(_cell_key(cell + direction)):
				interior = false
				break
		if interior:
			interior_cells.append(cell)
		else:
			edge_cells.append(cell)

	var interior_probability := 0.0
	if difficulty == "medium":
		interior_probability = 0.40
	elif difficulty == "hard":
		interior_probability = 0.70
	var candidates: Array = interior_cells if not interior_cells.is_empty() and rng.randf() < interior_probability else edge_cells
	if candidates.is_empty():
		candidates = interior_cells if not interior_cells.is_empty() else cells

	var best_score := -1
	var best: Array = []
	for cell in candidates:
		var score := _same_color_neighbor_count(cell, cell_set)
		if score > best_score:
			best_score = score
			best = [cell]
		elif score == best_score:
			best.append(cell)
	return best[rng.randi_range(0, best.size() - 1)]


static func _same_color_neighbor_count(cell: Vector2i, cell_set: Dictionary) -> int:
	var result := 0
	for direction in SURROUNDING:
		if cell_set.has(_cell_key(cell + direction)):
			result += 1
	return result


static func _desired_piece_count(cell_count: int, raw_difficulty: String, rng: RandomNumberGenerator) -> int:
	var difficulty := _normalize_difficulty(raw_difficulty)
	var desired := 1
	if difficulty == "simple":
		if cell_count >= 4 and rng.randf() < 0.45:
			desired = 2
	elif difficulty == "medium":
		desired = 2
		if cell_count >= 7 and rng.randf() < 0.35:
			desired = 3
	else:
		desired = 3 if cell_count >= 6 else 2
	var maximum_without_unit := maxi(1, floori(float(cell_count) / float(MIN_STANDARD_PIECE_CELLS)))
	return clampi(desired, 1, maximum_without_unit)


static func _split_region_with_clue(cells: Array, rng: RandomNumberGenerator, difficulty: String) -> Dictionary:
	if cells.size() < MIN_REGION_CELLS:
		return {}
	var clue := _select_clue_cell(cells, difficulty, rng)
	var remaining := _subtract_cells(cells, [clue])
	var desired_count := _desired_piece_count(remaining.size(), difficulty, rng)
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
		return [cells.duplicate()]
	var remaining: Array = cells.duplicate()
	var result: Array = []
	var filled: Array = [clue]
	for index in range(piece_count - 1):
		if remaining.size() <= 1:
			break
		var candidates := _template_cut_candidates(remaining, filled, difficulty)
		if candidates.is_empty():
			var fallback := _random_growth_cut(remaining, filled, rng)
			if fallback.is_empty():
				return []
			candidates.append(fallback)
		var picked: Array = candidates[_weighted_candidate_index(candidates, difficulty, rng)].get("cells", [])
		result.append(picked)
		remaining = _subtract_cells(remaining, picked)
		filled.append_array(picked)
	if remaining.is_empty() or (remaining.size() == 1 and not allow_singleton):
		return []
	result.append(remaining)
	return result


static func _template_cut_candidates(remaining: Array, filled: Array, difficulty: String) -> Array:
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
			if rotated.size() >= remaining.size():
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


static func _random_growth_cut(remaining: Array, filled: Array, rng: RandomNumberGenerator) -> Dictionary:
	for _attempt in range(80):
		var starts: Array = []
		for cell in remaining:
			if _touches_any([cell], filled):
				starts.append(cell)
		if starts.is_empty():
			return {}
		var maximum := remaining.size() - 1
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


static func _enumerate_valid_layouts(data: Dictionary, original_solution: Array) -> Array:
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
	var state := {"nodes": 0, "signatures": {}}
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
	if layouts.size() >= MAX_VALID_LAYOUTS or int(state["nodes"]) >= MAX_SEARCH_NODES:
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
		if layouts.size() >= MAX_VALID_LAYOUTS:
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
