class_name CompositeLevelStore
extends RefCounted

const RUNTIME_MANIFEST_PATH := "res://data/runtime/composite_manifest.res"

var _bundle_paths_by_size: Dictionary = {}
var _size_by_entry: Dictionary = {}
var _available_patterns_by_level: Dictionary = {}
var _loaded_size_entries: Dictionary = {}
var _threaded_size_paths: Dictionary = {}


static func load_entries():
	var store := CompositeLevelStore.new()
	if not store._load_runtime_manifest():
		push_warning("Runtime composite catalog is missing. Rebuild it with scripts/tools/build_runtime_level_bundles.gd")
	return store


static func find(entries, level_id: int, difficulty: String) -> Dictionary:
	if entries is CompositeLevelStore:
		return entries.find_entry(level_id, difficulty)
	if entries is Dictionary:
		var raw_data = entries.get(entry_key(level_id, difficulty), {})
		return raw_data if raw_data is Dictionary else {}
	return {}


static func entry_key(level_id: int, difficulty: String) -> String:
	return "%d:%s" % [level_id, difficulty]


func is_empty() -> bool:
	return _size_by_entry.is_empty()


func entry_count() -> int:
	return _size_by_entry.size()


func loaded_sizes() -> Array:
	var result: Array = []
	for raw_size in _loaded_size_entries.keys():
		result.append(int(raw_size))
	result.sort()
	return result


func available_patterns(level_id: int) -> Array:
	var patterns = _available_patterns_by_level.get(str(level_id), [])
	return patterns if patterns is Array else []


func has_entry(level_id: int, difficulty: String) -> bool:
	return _size_by_entry.has(entry_key(level_id, difficulty))


func load_size(size: int) -> bool:
	var size_key := str(size)
	if _loaded_size_entries.has(size_key):
		return true
	var path := str(_bundle_paths_by_size.get(size_key, ""))
	if path.is_empty():
		return false
	var bundle = null
	if _threaded_size_paths.has(size_key):
		bundle = ResourceLoader.load_threaded_get(path)
		_threaded_size_paths.erase(size_key)
	else:
		bundle = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return _store_loaded_bundle(size_key, bundle)


func request_size_async(size: int) -> bool:
	var size_key := str(size)
	if _loaded_size_entries.has(size_key) or _threaded_size_paths.has(size_key):
		return true
	var path := str(_bundle_paths_by_size.get(size_key, ""))
	if path.is_empty():
		return false
	var error := ResourceLoader.load_threaded_request(path, "", true, ResourceLoader.CACHE_MODE_IGNORE)
	if error != OK:
		return false
	_threaded_size_paths[size_key] = path
	return true


func finish_pending_loads() -> void:
	# Godot keeps a threaded resource request alive until its result is collected.
	# Drain outstanding requests when the owning game tree exits so tests, editor
	# restarts and fast app shutdowns do not leave loader RefCounted instances.
	for raw_size_key in _threaded_size_paths.keys():
		var size_key := str(raw_size_key)
		var path := str(_threaded_size_paths.get(size_key, ""))
		if path.is_empty():
			continue
		_store_loaded_bundle(size_key, ResourceLoader.load_threaded_get(path))
	_threaded_size_paths.clear()


func find_entry(level_id: int, difficulty: String) -> Dictionary:
	var key := entry_key(level_id, difficulty)
	var size := int(_size_by_entry.get(key, 0))
	if size <= 0 or not load_size(size):
		return {}
	var data = (_loaded_size_entries[str(size)] as Dictionary).get(key, {})
	return data if data is Dictionary else {}


func _load_runtime_manifest() -> bool:
	if not ResourceLoader.exists(RUNTIME_MANIFEST_PATH):
		return false
	var manifest = ResourceLoader.load(RUNTIME_MANIFEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not manifest:
		return false
	var paths = manifest.get("bundle_paths_by_size")
	var sizes = manifest.get("size_by_entry")
	var patterns = manifest.get("available_patterns_by_level")
	if not paths is Dictionary or not sizes is Dictionary or not patterns is Dictionary:
		return false
	_bundle_paths_by_size = paths
	_size_by_entry = sizes
	_available_patterns_by_level = patterns
	return not _size_by_entry.is_empty()


func _store_loaded_bundle(size_key: String, bundle) -> bool:
	if not bundle or not bundle.get("entries") is Dictionary:
		push_warning("Unable to load composite runtime data for size %s" % size_key)
		return false
	_loaded_size_entries[size_key] = bundle.get("entries")
	return true


static func normalize_for_runtime(data: Dictionary) -> void:
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
