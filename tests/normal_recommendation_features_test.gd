extends SceneTree

const Features = preload("res://scripts/normal_recommendation_features.gd")
const Director = preload("res://scripts/level_director.gd")
const Store = preload("res://scripts/level_store.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	_measurement()
	_learning()
	_feedback()
	_integration()
	print("NORMAL RECOMMENDATION FEATURES: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func _fixture(mixed: bool) -> Dictionary:
	var regions: Array = []
	for row in range(6):
		var line: Array = []
		for col in range(6):
			line.append((row + col) % 2 if mixed else int(col >= 3))
		regions.append(line)
	return {"levelId": 2 if mixed else 1, "rows": 6, "cols": 6, "difficulty": "medium", "regions": regions, "solution": [[0, 1], [1, 3], [2, 5], [3, 0], [4, 2], [5, 4]]}


func _measurement() -> void:
	var compact := Features.measure(_fixture(false))
	var mixed := Features.measure(_fixture(true))
	check(mixed["spatialEntropy"] > compact["spatialEntropy"], "Equal global color area must not imply equal spatial entropy")
	check(mixed["boundaryDensity"] > compact["boundaryDensity"], "More touching different-color pairs must increase boundary density")
	var relabeled := _fixture(false)
	for row in range(6):
		for col in range(6):
			relabeled["regions"][row][col] += 90
	check(Features.measure(relabeled) == compact, "Region ID/color palette changes cannot change complexity")
	var rotated := _fixture(false)
	var original: Array = rotated["regions"].duplicate(true)
	for row in range(6):
		for col in range(6):
			rotated["regions"][row][col] = original[5 - col][row]
	var rotation := Features.measure(rotated)
	check(is_equal_approx(rotation["spatialEntropy"], compact["spatialEntropy"]) and rotation["boundaryDensity"] == compact["boundaryDensity"], "Rotation must preserve both spatial descriptors")
	check(Features.measure({}).is_empty(), "Incomplete catalog data must not fabricate a feature")


func _good() -> Dictionary:
	return {"completionA": 1.0, "completionB": 200.0, "nextLevelA": 200.0, "nextLevelB": 1.0, "retentionA": 200.0, "retentionB": 1.0}


func _bad() -> Dictionary:
	return {"completionA": 200.0, "completionB": 1.0, "nextLevelA": 1.0, "nextLevelB": 200.0, "retentionA": 1.0, "retentionB": 200.0}


func _learning() -> void:
	var levels := [_fixture(false), _fixture(true)]
	var low := Features.buckets(Features.measure(levels[0]), 6)
	var high := Features.buckets(Features.measure(levels[1]), 6)
	var progress := {"normalFeatureStats": {}, "openingHintStats": {}}
	for dimension in Features.DIMENSIONS:
		check(low[dimension] != high[dimension], "The two spatial fixtures must occupy different buckets")
		progress["normalFeatureStats"][Features.stats_key(6, "medium", dimension, low[dimension])] = _bad()
		progress["normalFeatureStats"][Features.stats_key(6, "medium", dimension, high[dimension])] = _good()
	var rng := RandomNumberGenerator.new()
	for seed_value in range(8):
		rng.seed = seed_value
		check(Features.select_index(levels, [0, 1], progress, rng, Director.sample_engagement_reward) == 1, "Spatial choice must learn continuation/retention instead of maximizing completion")
	for dimension in Features.DIMENSIONS:
		progress["normalFeatureStats"][Features.stats_key(6, "medium", dimension, low[dimension])] = _good()
		progress["normalFeatureStats"][Features.stats_key(6, "medium", dimension, high[dimension])] = _bad()
	rng.seed = 5
	check(Features.select_index(levels, [0, 1], progress, rng, Director.sample_engagement_reward) == 0, "Lower spatial complexity may have higher learned reward")
	for count in [1, 2]:
		progress["openingHintStats"][Features.hint_key(6, "medium", low["spatialEntropy"], count)] = _good() if count == 2 else _bad()
	rng.seed = 3
	check(Features.choose_hint_count(levels[0], low, progress, rng, Director.sample_engagement_reward) == 2, "Post-selection hints must learn from the same reward")
	var index := Director.build_level_index(levels)
	check(Director._choose_level_index(levels, index, 6, "medium", [1], [], rng, false, progress) == 1, "Structural reward cannot reintroduce a filtered level")
	check(Director._choose_level_index(levels, index, 6, "medium", [1, 2], [], rng, false, progress) == -1, "Strict challenges must stay exhausted instead of relaxing filters")


func _feedback() -> void:
	var level := _fixture(false)
	var features := Features.measure(level)
	var buckets := Features.buckets(features, 6)
	var schedule := {"displayLevel": 41, "mode": "bayes", "normalFeatureVersion": 1, "normalFeatures": features, "kingPositions": [[0, 1], [1, 3]], "openingKingPolicy": "engagement_posterior"}
	var progress := {}
	var stamp := int(Time.get_unix_time_from_datetime_string("2026-10-07T23:59:00"))
	Director.record_completion(progress, level, schedule, 60, 20, 1, "2026-10-07", stamp)
	var hint_key := Features.hint_key(6, "medium", buckets["spatialEntropy"], 2)
	check(progress["normalFeatureStats"].size() == 2 and progress["openingHintStats"].size() == 1, "Attach actual structure and actual displayed count only")
	check(progress["openingHintStats"][hint_key]["completionA"] == 2.0, "Tool-assisted wins remain positive completion feedback")
	check(not progress["openingHintStats"][hint_key].has("nextLevelB"), "Pending engagement is not failure")
	Director.record_next_level_opened(progress, stamp + 10)
	Director.record_next_level_opened(progress, stamp + 20)
	Director.record_retention_if_needed(progress, "2026-10-08", stamp + 60)
	check(progress["openingHintStats"][hint_key]["nextLevelA"] == 2.0 and progress["openingHintStats"][hint_key]["retentionA"] == 2.0, "Delayed engagement must update the original hint action exactly once")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(progress))
	var before := JSON.stringify(restored["openingHintStats"])
	Director.record_retention_if_needed(restored, "2026-10-08", stamp + 120)
	check(JSON.stringify(restored["openingHintStats"]) == before, "Receipts must survive save/load")
	var legacy := {}
	Director.record_completion(legacy, level, {"mode": "fixed"}, 60, 20, 0, "2026-10-07", stamp)
	check(legacy["normalFeatureStats"].is_empty() and legacy["openingHintStats"].is_empty(), "Never invent feature/action evidence for legacy or fixed runs")
	var negative := {}
	Director.record_failure(negative, level, schedule, 60, 20, 0, "2026-10-07", stamp)
	Director.record_retention_if_needed(negative, "2026-10-08", stamp + 60)
	Director.record_retention_if_needed(negative, "2026-10-08", stamp + Director.NEXT_LEVEL_WINDOW_SECONDS)
	check(negative["openingHintStats"][hint_key]["completionB"] == 2.0 and negative["openingHintStats"][hint_key]["nextLevelB"] == 2.0, "Early retention must not strand the later next-level timeout")
	var late := {}
	Director.record_completion(late, level, schedule, 60, 20, 0, "2026-10-07", stamp)
	Director.record_next_level_opened(late, stamp + Director.NEXT_LEVEL_WINDOW_SECONDS)
	check(late["openingHintStats"][hint_key]["nextLevelB"] == 2.0 and not late["openingHintStats"][hint_key].has("nextLevelA"), "Late next-level open must not be rewarded as timely")


func _integration() -> void:
	var levels := Store.load_levels()
	if "--profile-spatial" in OS.get_cmdline_user_args():
		var profiles := {}
		for level in levels:
			var size: int = int(level["rows"])
			if not profiles.has(size):
				profiles[size] = {"spatialEntropy": [], "boundaryDensity": []}
			var features := Features.measure(level)
			for dimension in Features.DIMENSIONS:
				profiles[size][dimension].append(features[dimension])
		for size in profiles:
			for dimension in Features.DIMENSIONS:
				var values: Array = profiles[size][dimension]
				values.sort()
				print("Spatial profile ", size, " ", dimension, " min/P33/P67/max ", [values[0], values[values.size() / 3], values[values.size() * 2 / 3], values.back()])
	var distribution := {"spatialEntropy": {}, "boundaryDensity": {}}
	for level in levels:
		if int(level["rows"]) != 6 or str(level["difficulty"]) != "medium":
			continue
		var measured := Features.buckets(Features.measure(level), 6)
		for dimension in Features.DIMENSIONS:
			var bucket: String = measured[dimension]
			distribution[dimension][bucket] = int(distribution[dimension].get(bucket, 0)) + 1
	for dimension in Features.DIMENSIONS:
		check(distribution[dimension].size() > 1, "Production 6x6 medium levels must expose more than one structural bucket")
	print("6x6 medium spatial buckets: ", distribution)
	for display in [11, 41, 81, 161, 241]:
		var first := Director.schedule_for_display_level(levels, display, {})
		var level: Dictionary = levels[int(first["levelIndex"])]
		check(first["normalFeatures"] == Features.measure(level), "The selected runtime board supplies the recorded measurements")
		check(first["kingPositions"].size() in [1, 2], "Ordinary post-selection action is one or two opening lions")
		var progress := Director.normalize_progress({})
		for count in [1, 2]:
			var key := Features.hint_key(int(level["rows"]), str(level["difficulty"]), first["normalFeatureBuckets"]["spatialEntropy"], count)
			progress["openingHintStats"][key] = _good() if count == 2 else _bad()
		var second := Director.schedule_for_display_level(levels, display, progress)
		check(first["levelId"] == second["levelId"] and first["recommendableArms"] == second["recommendableArms"], "Changing only hint feedback cannot change selected level/arm")
		check(second["kingPositions"].size() == 2, "Hint policy executes after level selection")
		for cell in second["kingPositions"]:
			check(level["solution"].any(func(answer: Array) -> bool: return int(answer[0]) == int(cell[0]) and int(answer[1]) == int(cell[1])), "Opening hints must be actual solution lions")
	var challenge := Director.schedule_for_display_level(levels, 40, {})
	check(challenge["kingPositions"].is_empty(), "Challenge zero-hint rule stays intact")
	var opening := Director.schedule_for_display_level(levels, 9, {})
	check(opening["kingPositions"].size() == 1 and not opening.has("normalFeatureVersion"), "Authored opening stays unchanged and is not learned as an adaptive choice")
	var composite := Director.recommend_level_for_sizes(levels, [6], 41, {})
	check(not composite.has("normalFeatureVersion"), "Composite base selection must not accidentally acquire ordinary feature learning")
