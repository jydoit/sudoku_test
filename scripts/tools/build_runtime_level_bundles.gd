extends SceneTree

const LevelStoreScript = preload("res://scripts/level_store.gd")
const CompositeLevelStoreScript = preload("res://scripts/composite_level_store.gd")
const CompositeLevelScript = preload("res://scripts/composite_level.gd")
const LevelCatalogResourceScript = preload("res://scripts/resources/level_catalog_resource.gd")
const CompositeLevelBundleResourceScript = preload("res://scripts/resources/composite_level_bundle_resource.gd")
const CompositeLevelManifestResourceScript = preload("res://scripts/resources/composite_level_manifest_resource.gd")

const LEVELS_SOURCE_PATH := "res://data/levels.json"
const COMPOSITE_SOURCE_PATH := "res://data/composite_levels.json"
const OUTPUT_DIRECTORY := "res://data/runtime"
const LEVEL_CATALOG_PATH := OUTPUT_DIRECTORY + "/level_catalog.res"
const COMPOSITE_MANIFEST_PATH := OUTPUT_DIRECTORY + "/composite_manifest.res"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	var error := DirAccess.make_dir_recursive_absolute(output_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Unable to create runtime level directory: %s" % error_string(error))
		quit(1)
		return
	_remove_previous_runtime_resources()
	if not _build_level_catalog() or not _build_composite_catalog():
		quit(1)
		return
	print("RUNTIME LEVEL BUNDLES BUILT")
	quit(0)


func _build_level_catalog() -> bool:
	var payload = _read_json(LEVELS_SOURCE_PATH)
	if not payload is Dictionary or not payload.get("levels", []) is Array:
		push_error("Invalid ordinary level source")
		return false
	var levels: Array[Dictionary] = []
	for raw_level in payload["levels"]:
		if not raw_level is Dictionary:
			continue
		var level: Dictionary = raw_level
		LevelStoreScript.normalize_for_runtime(level)
		LevelStoreScript.validate_for_runtime(level)
		levels.append(level)
	var catalog = LevelCatalogResourceScript.new()
	catalog.levels = levels
	var save_error := ResourceSaver.save(catalog, LEVEL_CATALOG_PATH, ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		push_error("Unable to save ordinary runtime catalog: %s" % error_string(save_error))
		return false
	print("Saved %d ordinary levels" % levels.size())
	return true


func _build_composite_catalog() -> bool:
	var payload = _read_json(COMPOSITE_SOURCE_PATH)
	if not payload is Dictionary or not payload.get("entries", []) is Array:
		push_error("Invalid composite level source")
		return false
	var grouped_by_size: Dictionary = {}
	var available_patterns_by_level: Dictionary = {}
	for raw_entry in payload["entries"]:
		if not raw_entry is Dictionary:
			continue
		var level_id := int(raw_entry.get("levelId", -1))
		var difficulty := str(raw_entry.get("difficulty", ""))
		var data = raw_entry.get("data", {})
		if level_id < 0 or difficulty.is_empty() or not data is Dictionary:
			continue
		if data.get("pieces", []).is_empty() or data.get("validLayouts", []).is_empty():
			continue
		CompositeLevelStoreScript.normalize_for_runtime(data)
		CompositeLevelScript._prepare_runtime_cache(data)
		var size_key := str(int(data.get("rows", 0)))
		if not grouped_by_size.has(size_key):
			grouped_by_size[size_key] = []
		grouped_by_size[size_key].append({"level_id": level_id, "difficulty": difficulty, "data": data})
		var level_key := str(level_id)
		if not available_patterns_by_level.has(level_key):
			available_patterns_by_level[level_key] = []
		if not available_patterns_by_level[level_key].has(difficulty):
			available_patterns_by_level[level_key].append(difficulty)

	var manifest = CompositeLevelManifestResourceScript.new()
	manifest.available_patterns_by_level = available_patterns_by_level
	var bundle_paths_by_size: Dictionary = {}
	var size_by_entry: Dictionary = {}
	var bundle_count := 0
	var entry_count := 0
	var size_keys: Array = grouped_by_size.keys()
	size_keys.sort()
	for raw_size_key in size_keys:
		var size_key := str(raw_size_key)
		var entries: Array = grouped_by_size[size_key]
		entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			var first_id := int(first["level_id"])
			var second_id := int(second["level_id"])
			if first_id == second_id:
				return str(first["difficulty"]) < str(second["difficulty"])
			return first_id < second_id
		)
		var bundle = CompositeLevelBundleResourceScript.new()
		var bundle_entries: Dictionary = {}
		for entry in entries:
			var entry_key := CompositeLevelStoreScript.entry_key(int(entry["level_id"]), str(entry["difficulty"]))
			bundle_entries[entry_key] = entry["data"]
			size_by_entry[entry_key] = int(size_key)
		bundle.entries = bundle_entries
		var bundle_path := "%s/composite_size_%s.res" % [OUTPUT_DIRECTORY, size_key]
		var save_error := ResourceSaver.save(bundle, bundle_path, ResourceSaver.FLAG_COMPRESS)
		if save_error != OK:
			push_error("Unable to save composite bundle %s: %s" % [bundle_path, error_string(save_error)])
			return false
		bundle_paths_by_size[size_key] = bundle_path
		entry_count += bundle_entries.size()
		bundle_count += 1
	manifest.bundle_paths_by_size = bundle_paths_by_size
	manifest.size_by_entry = size_by_entry
	manifest.entry_count = entry_count
	manifest.bundle_count = bundle_count
	var manifest_error := ResourceSaver.save(manifest, COMPOSITE_MANIFEST_PATH, ResourceSaver.FLAG_COMPRESS)
	if manifest_error != OK:
		push_error("Unable to save composite manifest: %s" % error_string(manifest_error))
		return false
	print("Saved %d composite entries in %d lazy bundles" % [entry_count, bundle_count])
	return true


func _remove_previous_runtime_resources() -> void:
	var directory := DirAccess.open(OUTPUT_DIRECTORY)
	if not directory:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".res"):
			directory.remove(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		push_error("Missing source data: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Unable to open source data: %s" % path)
		return null
	return JSON.parse_string(file.get_as_text())
