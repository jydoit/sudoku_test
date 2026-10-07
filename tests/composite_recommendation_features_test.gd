extends SceneTree

const Features = preload("res://scripts/composite_recommendation_features.gd")
const Director = preload("res://scripts/composite_level_director.gd")
const BaseDirector = preload("res://scripts/level_director.gd")
const Store = preload("res://scripts/composite_level_store.gd")
const Levels = preload("res://scripts/level_store.gd")

var failures := 0


func _check(condition: bool, message: String = "Recommendation assertion failed") -> void:
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_measurement()
	_test_feature_exploration()
	_test_reward_learning()
	_test_delayed_feedback()
	_test_filter_scope()
	_test_runtime_recommendations()
	print("COMPOSITE RECOMMENDATION FEATURES ", "PASSED" if failures == 0 else "FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)


func _test_measurement() -> void:
	var data := {
		"rows": 6, "cols": 6,
		"constructionCells": [[0, 0], [0, 1], [1, 0], [1, 1]],
		"pieces": [
			{"pieceId": 0, "regionId": 0, "cells": [[0, 0], [0, 1]]},
			{"pieceId": 1, "regionId": 1, "cells": [[0, 0], [0, 1]]}
		],
		"cutQuality": {"candidatePositionCount": 2, "spatialCandidatePositionCount": 999},
		"solutionOrder": [{"candidateCount": 1}, {"candidateCount": 1}]
	}
	var measured: Dictionary = Features.measure(data)
	_check(int(measured["pieceCount"]) == 2)
	_check(is_equal_approx(float(measured["fillRatio"]), 4.0 / 36.0), "Fill must exclude fixed cells and use the full board denominator")
	_check(is_equal_approx(float(measured["placementAmbiguity"]), 2.0), "Ambiguity must count visible geometric origins, not hidden target colors or solution order")
	for piece in data["pieces"]:
		piece["candidateOrigins"] = [[0, 0], [1, 0]]
	_check(Features.measure(data) == measured, "Runtime cached geometry and uncached source data must agree")
	_check(Features.meets_minimum(measured, "simple"))
	_check(not Features.meets_minimum(measured, "medium"))
	_check(not Features.meets_minimum({"pieceCount": 2, "fillRatio": 0.8, "placementAmbiguity": 20.0}, "hard"), "Large area or ambiguity must not disguise a two-piece Hard")
	_check(not Features.meets_minimum({"pieceCount": 8, "fillRatio": 0.1, "placementAmbiguity": 20.0}, "hard"))
	_check(not Features.meets_minimum({"pieceCount": 8, "fillRatio": 0.5, "placementAmbiguity": 1.0}, "hard"))
	_check(Features.measure({}).is_empty())


func _test_feature_exploration() -> void:
	var candidates: Array = []
	for index in range(9):
		candidates.append({"id": index, "features": {
			"pieceCount": index + 3, "fillRatio": 0.15 + index * 0.05, "placementAmbiguity": 1.0 + index
		}})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var baseline: Dictionary = Features.select(candidates, "medium", false, {}, 6, rng)
	_check(str(baseline["explorationDimension"]).is_empty())
	var progress := {"recentRuns": []}
	for iteration in range(3):
		var selected: Dictionary = Features.select(candidates, "medium", true, progress, 6, rng)
		_check(selected["buckets"][selected["explorationDimension"]] == selected["explorationBucket"], "Exploration must actually expose the requested structural bucket")
		for previous in progress["recentRuns"]:
			_check(str(previous["featureExplorationDimension"]) != str(selected["explorationDimension"]), "Prefer an unexposed structural axis")
		progress["recentRuns"].append({"size": 6, "featureExplorationDimension": selected["explorationDimension"]})
	progress = {"recentRuns": [
		{"size": 6, "featureExplorationDimension": "fillRatio"},
		{"size": 6, "featureExplorationDimension": "placementAmbiguity"}
	], "statsByFeature": {
		Features.stats_key(6, "medium", "pieceCount", "low"): {"plays": 10},
		Features.stats_key(6, "medium", "pieceCount", "high"): {"plays": 10}
	}}
	var probe := Features.select(candidates, "medium", true, progress, 6, rng)
	_check(probe["explorationDimension"] == "pieceCount" and probe["explorationBucket"] == "medium", "Reuse exploration for an underexposed feature bucket, not a fixed quantile")
	var repeated_rng := RandomNumberGenerator.new()
	repeated_rng.seed = 7
	_check(Features.select(candidates, "medium", false, {}, 6, repeated_rng) == baseline, "Identical seed and progress must not flicker")
	var single := Features.select([candidates[0]], "hard", true, {}, 6, rng)
	_check(single["candidate"] == candidates[0] and str(single["explorationDimension"]).is_empty())


func _test_reward_learning() -> void:
	var lower := {"pieceCount": 3.0, "fillRatio": 0.15, "placementAmbiguity": 1.1}
	var higher := {"pieceCount": 9.0, "fillRatio": 0.55, "placementAmbiguity": 8.0}
	for dimension in Features.DIMENSIONS:
		var low := {"pieceCount": 5.0, "fillRatio": 0.35, "placementAmbiguity": 3.0}
		var high := low.duplicate()
		low[dimension] = lower[dimension]
		high[dimension] = higher[dimension]
		var candidates := [{"id": "low", "features": low}, {"id": "high", "features": high}]
		var engagement := {"completionA": 1.0, "completionB": 200.0, "nextLevelA": 200.0, "nextLevelB": 1.0, "retentionA": 200.0, "retentionB": 1.0}
		var easy_wins := {"completionA": 200.0, "completionB": 1.0, "nextLevelA": 1.0, "nextLevelB": 200.0, "retentionA": 1.0, "retentionB": 200.0}
		var progress := {"statsByFeature": {
			Features.stats_key(6, "medium", dimension, "low"): easy_wins,
			Features.stats_key(6, "medium", dimension, "high"): engagement
		}}
		var rng := RandomNumberGenerator.new()
		for seed_value in range(8):
			rng.seed = seed_value
			_check(Features.select(candidates, "medium", false, progress, 6, rng)["candidate"]["id"] == "high", "Next-round and retention reward must beat completion-only evidence for %s" % dimension)
		progress["statsByFeature"][Features.stats_key(6, "medium", dimension, "low")] = engagement
		progress["statsByFeature"][Features.stats_key(6, "medium", dimension, "high")] = easy_wins
		rng.seed = 1
		_check(Features.select(candidates, "medium", false, progress, 6, rng)["candidate"]["id"] == "low", "Better retention may favor fewer pieces/less area; no hardcoded difficulty escalation")
		rng.seed = 55
		var shared := BaseDirector.sample_engagement_reward(engagement, rng)
		rng.seed = 55
		var original := BaseDirector._beta_sample(engagement, "completion", rng) * 0.20 + BaseDirector._beta_sample(engagement, "nextLevel", rng) * 0.45 + BaseDirector._beta_sample(engagement, "retention", rng) * 0.35
		_check(is_equal_approx(shared, original), "Refactoring must retain the base framework's exact reward weights and RNG order")


func _test_delayed_feedback() -> void:
	var timestamp := int(Time.get_unix_time_from_datetime_string("2026-10-07T20:00:00"))
	var level := {"levelId": 100, "rows": 6, "difficulty": "medium"}
	var features := {"pieceCount": 5, "fillRatio": 0.35, "placementAmbiguity": 3.0}
	var schedule := {"homeCompositeRound": 1, "assemblyDifficultyPattern": "medium", "assemblyRecommendationFeatures": features}
	var progress := {}
	Director.record_result(progress, level, schedule, true, 60, 10, 0, "2026-10-07", timestamp)
	var key := Features.stats_key(6, "medium", "pieceCount", "medium")
	_check(progress["statsByFeature"].size() == 3, "Store marginal statistics, not a Cartesian feature arm")
	_check(float(progress["statsByFeature"][key]["completionA"]) == 2.0)
	_check(not progress["statsByFeature"][key].has("retentionB") and not progress["statsByFeature"][key].has("nextLevelB"), "Pending delayed outcomes are not failures")
	Director.record_next_round_opened(progress, 1)
	_check(not progress["statsByFeature"][key].has("nextLevelA"), "Resuming the same round is not opening a new round")
	Director.record_next_round_opened(progress, 2)
	Director.record_next_round_opened(progress, 2)
	_check(float(progress["statsByFeature"][key]["nextLevelA"]) == 2.0, "Opening the next round credits its predecessor exactly once")
	var next_schedule := schedule.duplicate(true)
	next_schedule["homeCompositeRound"] = 2
	next_schedule["assemblyRecommendationFeatures"] = {"pieceCount": 9, "fillRatio": 0.55, "placementAmbiguity": 8.0}
	Director.record_result(progress, {"levelId": 101, "rows": 6, "difficulty": "medium"}, next_schedule, true, 90, 10, 0, "2026-10-08", timestamp + 13 * 3600)
	Director.record_retention_if_needed(progress, "2026-10-08", timestamp + 13 * 3600 + 60)
	_check(float(progress["statsByFeature"][key]["retentionA"]) == 2.0, "Retention must credit the saved preceding run's buckets")
	var next_key := Features.stats_key(6, "medium", "pieceCount", "high")
	_check(not progress["statsByFeature"][next_key].has("retentionA"), "Today's newer run must not receive yesterday's retention")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(progress))
	var before := JSON.stringify(restored["statsByFeature"])
	Director.record_retention_if_needed(restored, "2026-10-08", timestamp + 13 * 3600 + 120)
	_check(JSON.stringify(restored["statsByFeature"]) == before, "Delayed receipts must survive restart without duplicate reward")
	var negative := {}
	Director.record_result(negative, level, schedule, true, 60, 10, 0, "2026-10-07", timestamp)
	Director.record_retention_if_needed(negative, "2026-10-07", timestamp + 60)
	_check(not negative["statsByFeature"][key].has("nextLevelB"))
	Director.record_retention_if_needed(negative, "2026-10-08", timestamp + 25 * 3600)
	_check(float(negative["statsByFeature"][key]["retentionB"]) == 2.0 and float(negative["statsByFeature"][key]["nextLevelB"]) == 2.0, "Reuse original expiry rules for negative delayed feedback")
	var legacy := {}
	Director.record_result(legacy, level, {"homeCompositeRound": 1}, true, 60, 10, 0, "2026-10-07", timestamp)
	Director.record_retention_if_needed(legacy, "2026-10-08", timestamp + 25 * 3600)
	_check(legacy["statsByFeature"].is_empty(), "Legacy runs without structural evidence must not fabricate feature credit")
	var failed := {}
	Director.record_result(failed, level, schedule, false, 60, 10, 0, "2026-10-07", timestamp)
	_check(float(failed["statsByFeature"][key]["completionB"]) == 2.0)
	Director.record_next_round_opened(failed, 2)
	_check(not failed["statsByFeature"][key].has("nextLevelA"))
	var midnight := {}
	var midnight_stamp := timestamp + 4 * 3600 - 60
	Director.record_result(midnight, level, schedule, true, 60, 10, 0, "2026-10-07", midnight_stamp)
	Director.record_retention_if_needed(midnight, "2026-10-08", midnight_stamp + 60)
	_check(float(midnight["statsByFeature"][key]["retentionA"]) == 2.0 and not midnight["statsByFeature"][key].has("nextLevelB"))
	Director.record_retention_if_needed(midnight, "2026-10-08", midnight_stamp + BaseDirector.NEXT_LEVEL_WINDOW_SECONDS)
	_check(float(midnight["statsByFeature"][key]["nextLevelB"]) == 2.0, "Settling retention early must not strand next-round timeout feedback")
	var late := {}
	Director.record_result(late, level, schedule, true, 60, 10, 0, "2026-10-07", timestamp)
	Director.record_next_round_opened(late, 2, timestamp + BaseDirector.NEXT_LEVEL_WINDOW_SECONDS)
	_check(float(late["statsByFeature"][key]["nextLevelB"]) == 2.0 and not late["statsByFeature"][key].has("nextLevelA"), "An expired next-round window cannot be credited as timely continuation")


func _test_filter_scope() -> void:
	var levels: Array = []
	var entries := {}
	for id in range(1, 6):
		levels.append({"levelId": id, "rows": 6 if id < 5 else 7, "difficulty": "medium" if id < 4 else "hard", "compositeSourceIndex": id - 1})
		entries["%d:medium" % id] = _fixture_data(6, 4)
	var progress := {"completedLevelIds": [1], "recentRuns": [{"levelId": 2}]}
	var pools: Dictionary = Director._feature_candidate_pools(levels, entries, levels[0], progress)
	_check(pools["qualified"]["medium"].size() == 1)
	_check(int(pools["qualified"]["medium"][0]["level"]["levelId"]) == 3, "Only fresh levels in the selected size/base difficulty may be re-ranked")
	progress["recentRuns"].append({"levelId": 3})
	pools = Director._feature_candidate_pools(levels, entries, levels[0], progress)
	_check(int(pools["qualified"]["medium"][0]["level"]["levelId"]) == 1, "Fallback order must match the ordinary director: relax completed before recent")
	entries["1:medium"] = _fixture_data(6, 1)
	pools = Director._feature_candidate_pools(levels, entries, levels[0], progress)
	_check(pools["qualified"].is_empty() and pools["fallback"]["medium"].size() == 1, "Quality filtering must not widen the arm or revive more recently excluded levels")
	var fallback := Director.recommend([levels[0]], {"1:medium": entries["1:medium"]}, 5, 30, {})
	_check(not fallback.is_empty() and bool(fallback["schedule"]["assemblyFeatureQualityFallback"]), "Depleted structural quality needs an explicit fallback, not an empty paid round")


func _fixture_data(size: int, piece_count: int) -> Dictionary:
	var pieces: Array = []
	for index in range(piece_count):
		pieces.append({"pieceId": index, "cells": [[0, 0], [0, 1]], "candidateOrigins": [[0, 0], [1, 0]]})
	return {"rows": size, "cols": size, "pieces": pieces, "seed": 10}


func _test_runtime_recommendations() -> void:
	var levels: Array = Levels.load_levels()
	var store = Store.load_entries()
	var catalog: Array = []
	for index in range(levels.size()):
		if int(levels[index].get("rows", 0)) >= 6 and not store.available_patterns(int(levels[index]["levelId"])).is_empty():
			catalog.append(levels[index])
	for opening_round in range(1, 5):
		var opening: Dictionary = Director.recommend(levels, store, opening_round, 30, {})
		_check(not opening.is_empty())
		_check(str(opening["schedule"]["compositePatternSelectionMode"]) == "opening_cycle")
		_check(["simple", "medium"].has(opening["difficultyPattern"]))
		if opening_round == 1:
			_check(int(opening["schedule"]["assemblyRecommendationFeatures"]["pieceCount"]) == 2)

	var progress := {}
	var feature_axes := {}
	var sampled_patterns := {}
	for round_number in range(5, 35):
		var base_progress: Dictionary = progress.get("levelRecommendationProgress", {}).duplicate(true)
		var base := BaseDirector.recommend_level_for_sizes(catalog, [6], 34, base_progress)
		var expected: Dictionary = catalog[int(base["levelIndex"])]
		var recommended: Dictionary = Director.recommend(levels, store, round_number, 34, progress)
		_check(not recommended.is_empty())
		var level: Dictionary = levels[int(recommended["levelIndex"])]
		var schedule: Dictionary = recommended["schedule"]
		_check(int(level["rows"]) == 6 and str(level["difficulty"]) == str(expected["difficulty"]), "Feature re-ranking must retain the existing director's recommendation arm")
		_check(str(schedule["compositeBaseRecommendationMode"]) == str(base["mode"]))
		_check(not bool(schedule["assemblyFeatureQualityFallback"]))
		var pattern := str(recommended["difficultyPattern"])
		var data: Dictionary = store.find_entry(int(level["levelId"]), pattern)
		var measured: Dictionary = Features.measure(data)
		_check(schedule["assemblyRecommendationFeatures"] == measured)
		_check(Features.meets_minimum(measured, pattern))
		sampled_patterns[pattern] = true
		var axis := str(schedule["assemblyFeatureExplorationDimension"])
		if not axis.is_empty():
			_check(str(schedule["compositePatternSelectionMode"]) == "random_exploration")
			feature_axes[axis] = true
		Director.record_result(progress, level, schedule, true, 60.0, 15, 0)
		_check(progress["recentRuns"].back()["assemblyFeatures"] == measured)
	_check(sampled_patterns.size() == 3 and feature_axes.size() == 3, "The existing exploration branch should expose all three structural dimensions and patterns")
	_check(store.loaded_sizes() == [6], "Recommendation must not eagerly load locked size bundles")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(progress))
	for index in range(progress["recentRuns"].size()):
		for dimension in Features.DIMENSIONS:
			_check(is_equal_approx(float(progress["recentRuns"][index]["assemblyFeatures"][dimension]), float(restored["recentRuns"][index]["assemblyFeatures"][dimension])), "Feature evidence must survive JSON save/load")
	var pools := Director._feature_candidate_pools(catalog, store, catalog[0], progress["levelRecommendationProgress"])
	var candidates: Array = pools["qualified"][pools["qualified"].keys()[0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var original_next: Dictionary = Features.select(candidates, "medium", true, progress, 6, rng)
	rng.seed = 314
	var restored_next: Dictionary = Features.select(candidates, "medium", true, restored, 6, rng)
	_check(original_next == restored_next, "Within an unchanged base arm, feature exploration must survive save/load without changing its choice")
	# The existing base director samples dictionary-order-dependent Dirichlet
	# arrays. Its cross-serialization RNG behavior is outside this feature layer.
	print("Runtime sampling: ", sampled_patterns.keys(), "; explored axes: ", feature_axes.keys())
	for size in [6, 7, 8, 9]:
		for difficulty in ["simple", "medium", "hard", "challenge"]:
			var quality_pools := Director._feature_candidate_pools(catalog, store, {"rows": size, "difficulty": difficulty}, {})
			if quality_pools["qualified"].is_empty():
				# Do not hide a catalog gap by widening the base arm or weakening
				# Hard floors. Adding qualified data later should not break this test.
				var limited_catalog := levels.filter(func(level: Dictionary) -> bool: return int(level["rows"]) == size and str(level["difficulty"]) == difficulty)
				var limited := Director.recommend(limited_catalog, store, 5, BaseDirector.minimum_display_for_size(size), {})
				_check(bool(limited["schedule"]["assemblyFeatureQualityFallback"]))
				_check(str(limited["difficultyPattern"]) == "simple", "All-low-quality fallback must not sell a two-piece cut as Hard")
				print("Catalog quality fallback: %dx%d / %s" % [size, size, difficulty])
			for pattern in quality_pools["qualified"]:
				for candidate in quality_pools["qualified"][pattern]:
					_check(Features.meets_minimum(candidate["features"], pattern))
