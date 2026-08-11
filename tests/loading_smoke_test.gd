extends SceneTree

const LevelStoreScript = preload("res://scripts/level_store.gd")
const CompositeLevelStoreScript = preload("res://scripts/composite_level_store.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var started_usec := Time.get_ticks_usec()
	var levels := LevelStoreScript.load_levels()
	var ordinary_elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	assert(levels.size() == 3270, "Runtime ordinary catalog should include every offline level")

	started_usec = Time.get_ticks_usec()
	var composite_store = CompositeLevelStoreScript.load_entries()
	var manifest_elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	assert(composite_store is CompositeLevelStore, "Composite catalog should use the lazy runtime store")
	assert(composite_store.entry_count() == 6000, "Composite manifest should expose every offline entry")
	assert(composite_store.loaded_sizes().is_empty(), "Loading the manifest must not load any size bundle")

	var sample_level: Dictionary = levels.filter(func(level: Dictionary) -> bool:
		return int(level.get("rows", 0)) >= 6 and composite_store.has_entry(int(level.get("levelId", -1)), "simple")
	)[0]
	started_usec = Time.get_ticks_usec()
	var sample: Dictionary = composite_store.find_entry(int(sample_level["levelId"]), "simple")
	var first_bundle_elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	assert(not sample.is_empty(), "A manifest entry should load its binary bundle")
	assert(sample.has("constructionIndexSet"), "Runtime cache must be generated offline")
	assert(sample.get("pieces", [])[0].has("candidateOrigins"), "Piece candidates must be generated offline")
	assert(composite_store.loaded_sizes() == [int(sample_level["rows"])], "The first lookup should load the complete selected size only")
	var next_size := 7 if int(sample_level["rows"]) == 6 else 6
	assert(composite_store.request_size_async(next_size), "A second size should support background loading")
	assert(composite_store.load_size(next_size), "A requested background size should become available on demand")
	assert(composite_store.loaded_sizes().has(next_size), "The asynchronously requested size should be retained")

	print(
		"LOADING SMOKE PASSED: ordinary=%.2fms manifest=%.2fms first_bundle=%.2fms loaded_sizes=%d"
		% [ordinary_elapsed_ms, manifest_elapsed_ms, first_bundle_elapsed_ms, composite_store.loaded_sizes().size()]
	)
	quit(0)
