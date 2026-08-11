class_name LevelStore
extends RefCounted

const RUNTIME_LEVELS_PATH := "res://data/runtime/level_catalog.res"


static func load_levels() -> Array:
	if ResourceLoader.exists(RUNTIME_LEVELS_PATH):
		var catalog = ResourceLoader.load(RUNTIME_LEVELS_PATH)
		if catalog and catalog.get("levels") is Array:
			return catalog.get("levels")
		push_error("Invalid runtime level catalog")
		return []
	push_error("Runtime level catalog is missing. Rebuild it with scripts/tools/build_runtime_level_bundles.gd")
	return []


static func normalize_for_runtime(level: Dictionary) -> void:
	var rows := int(level.get("rows", 0))
	var cols := int(level.get("cols", rows))
	if not level.has("cols") and rows > 0:
		level["cols"] = rows
	if not level.has("targetCount"):
		level["targetCount"] = level.get("solution", []).size()
	if not level.has("name") or str(level.get("name", "")).strip_edges() == "":
		var size_text := "%dx%d" % [rows, cols]
		var difficulty := str(level.get("difficulty", "")).capitalize()
		level["name"] = "%s %s" % [difficulty, size_text] if difficulty != "" else size_text
	if not level.has("tutorial") or str(level.get("tutorial", "")).strip_edges() == "":
		level["tutorial"] = "找出全部小狮子，满足行、列、颜色区域和相邻规则。"
	if not level.has("difficulty") or str(level.get("difficulty", "")).strip_edges() == "":
		level["difficulty"] = "normal"


static func validate_for_runtime(level: Dictionary) -> void:
	var rows := int(level.get("rows", 0))
	var cols := int(level.get("cols", 0))
	var regions: Array = level.get("regions", [])
	assert(rows > 0 and cols > 0, "Level dimensions must be positive")
	assert(regions.size() == rows, "Region row count does not match level")
	for row in regions:
		assert(row.size() == cols, "Region column count does not match level")
	assert(level.get("solution", []).size() == int(level.get("targetCount", 0)), "Solution size does not match target")
	if level.has("kingPosition"):
		var king: Array = level.get("kingPosition", [])
		assert(king.size() >= 2, "King position must use [row, col]")
		var king_row := int(king[0])
		var king_col := int(king[1])
		assert(king_row >= 0 and king_row < rows and king_col >= 0 and king_col < cols, "King position must be inside the board")
		var in_solution := false
		for coordinate in level.get("solution", []):
			if int(coordinate[0]) == king_row and int(coordinate[1]) == king_col:
				in_solution = true
				break
		assert(in_solution, "King position must be one of the solution cells")
