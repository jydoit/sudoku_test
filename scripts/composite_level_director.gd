class_name CompositeLevelDirector
extends RefCounted

const LevelDirectorScript = preload("res://scripts/level_director.gd")
const CompositePlacementEngineScript = preload("res://scripts/rules/composite_placement_engine.gd")
const RecommendationFeaturesScript = preload("res://scripts/composite_recommendation_features.gd")

const PATTERNS := ["simple", "medium", "hard"]
const MIN_BOARD_SIZE := 6
const EXPLORATION_START := 0.50
const EXPLORATION_END := 0.20
const FULL_EVIDENCE_TOTAL := 30
const FULL_EVIDENCE_PER_PATTERN := 6
const MAX_RUN_HISTORY := 40
const OPENING_PATTERN_CYCLE := ["simple", "medium", "simple", "medium"]


static func normalize_progress(progress: Dictionary) -> Dictionary:
	if not progress.has("levelRecommendationProgress") or not progress["levelRecommendationProgress"] is Dictionary:
		progress["levelRecommendationProgress"] = {}
	LevelDirectorScript.normalize_progress(progress["levelRecommendationProgress"])
	if not progress.has("patternAlphaBySize") or not progress["patternAlphaBySize"] is Dictionary:
		progress["patternAlphaBySize"] = {}
	if not progress.has("patternStatsBySize") or not progress["patternStatsBySize"] is Dictionary:
		progress["patternStatsBySize"] = {}
	if not progress.has("recentRuns") or not progress["recentRuns"] is Array:
		progress["recentRuns"] = []
	if not progress.has("statsByFeature") or not progress["statsByFeature"] is Dictionary:
		progress["statsByFeature"] = {}
	return progress


static func recommend(
	levels: Array,
	composite_entries,
	round_number: int,
	formal_display_level: int,
	progress: Dictionary
) -> Dictionary:
	normalize_progress(progress)
	var catalog_levels: Array = []
	for source_index in range(levels.size()):
		var level: Dictionary = levels[source_index]
		if int(level.get("rows", 0)) < MIN_BOARD_SIZE:
			continue
		if _available_patterns(composite_entries, int(level.get("levelId", -1))).is_empty():
			continue
		var catalog_level := level.duplicate(false)
		catalog_level["compositeSourceIndex"] = source_index
		catalog_levels.append(catalog_level)
	if catalog_levels.is_empty():
		return {}

	var available_sizes: Array = []
	for level in catalog_levels:
		var size := int(level.get("rows", 0))
		if not available_sizes.has(size):
			available_sizes.append(size)
	available_sizes.sort()
	var unlocked_sizes: Array = []
	var minimum_composite_display := LevelDirectorScript.minimum_display_for_size(MIN_BOARD_SIZE)
	for raw_size in LevelDirectorScript.unlocked_sizes(maxi(minimum_composite_display, formal_display_level)):
		var size := int(raw_size)
		if size >= MIN_BOARD_SIZE and available_sizes.has(size):
			unlocked_sizes.append(size)
	if unlocked_sizes.is_empty():
		unlocked_sizes.append(int(available_sizes[0]))

	var recommendation_display := maxi(minimum_composite_display, formal_display_level)
	var selector_progress: Dictionary = progress["levelRecommendationProgress"]
	var base_schedule := LevelDirectorScript.recommend_level_for_sizes(
		catalog_levels,
		unlocked_sizes,
		recommendation_display,
		selector_progress
	)
	if base_schedule.is_empty():
		return {}
	var catalog_index := int(base_schedule.get("levelIndex", -1))
	if catalog_index < 0 or catalog_index >= catalog_levels.size():
		return {}
	var selected_level: Dictionary = catalog_levels[catalog_index]
	var source_index := int(selected_level.get("compositeSourceIndex", -1))
	if source_index < 0 or source_index >= levels.size():
		return {}
	var level_id := int(selected_level.get("levelId", -1))
	var patterns := _available_patterns(composite_entries, level_id)
	if patterns.is_empty():
		return {}
	var size := int(selected_level.get("rows", 0))
	var pattern := ""
	var offline_data: Dictionary = {}
	var exploration := 0.0
	var selection_mode := "opening_cycle"
	var feature_selection := {}
	var feature_quality_fallback := false
	if round_number >= 1 and round_number <= OPENING_PATTERN_CYCLE.size():
		var preferred_pattern := str(OPENING_PATTERN_CYCLE[round_number - 1])
		if round_number == 1:
			var opening := _opening_two_piece_candidate(
				catalog_levels, composite_entries, selected_level, preferred_pattern
			)
			if opening.is_empty():
				return {}
			selected_level = opening["level"]
			source_index = int(selected_level.get("compositeSourceIndex", -1))
			level_id = int(selected_level.get("levelId", -1))
			size = int(selected_level.get("rows", 0))
			patterns = _available_patterns(composite_entries, level_id)
			pattern = str(opening["pattern"])
			offline_data = opening["data"]
		else:
			pattern = preferred_pattern if patterns.has(preferred_pattern) else _opening_fallback_pattern(patterns)
			offline_data = _find_entry(composite_entries, level_id, pattern)
	else:
		var pools := _feature_candidate_pools(catalog_levels, composite_entries, selected_level, selector_progress)
		var qualified: Dictionary = pools["qualified"]
		if qualified.is_empty():
			# Keep the selected size/base difficulty and the existing dedupe tier.
			# A depleted catalog is explicit. Prefer a basic pattern rather than
			# presenting a degenerate two-piece cut as a Hard challenge.
			var fallback_pools: Dictionary = pools["fallback"]
			for fallback_pattern in PATTERNS:
				if fallback_pools.has(fallback_pattern):
					qualified = {fallback_pattern: fallback_pools[fallback_pattern]}
					break
			feature_quality_fallback = true
		patterns = PATTERNS.filter(func(value: String) -> bool: return qualified.has(value))
		if patterns.is_empty():
			return {}
		var rng := RandomNumberGenerator.new()
		rng.seed = _recommendation_seed(round_number, formal_display_level, progress)
		exploration = exploration_probability(progress, size)
		selection_mode = "random_exploration"
		if rng.randf() < exploration:
			pattern = str(patterns[rng.randi_range(0, patterns.size() - 1)])
		else:
			selection_mode = "posterior_multinomial"
			pattern = _sample_pattern_from_posterior(progress, size, patterns, rng)
		feature_selection = RecommendationFeaturesScript.select(
			qualified[pattern], pattern, selection_mode == "random_exploration", progress, size, rng
		)
		if feature_selection.is_empty():
			return {}
		var candidate: Dictionary = feature_selection["candidate"]
		selected_level = candidate["level"]
		source_index = int(selected_level["compositeSourceIndex"])
		level_id = int(selected_level["levelId"])
		offline_data = candidate["data"]
	if offline_data.is_empty():
		return {}
	_ensure_pattern_size(progress, size, patterns)

	var schedule := LevelDirectorScript.manual_schedule_for_level(levels, source_index, 1, "home_composite")
	schedule["assemblySeed"] = int(offline_data.get("seed", 0))
	schedule["assemblyDifficultyPattern"] = pattern
	schedule["homeCompositeRound"] = maxi(1, round_number)
	schedule["compositeBaseDifficultyClass"] = str(selected_level.get("difficulty", "simple"))
	schedule["compositeBaseRecommendationMode"] = str(base_schedule.get("mode", "bayes"))
	schedule["compositeBaseRecommendationReason"] = str(base_schedule.get("recommendationReason", "bayes"))
	schedule["compositeRecommendationDisplay"] = recommendation_display
	schedule["compositePatternSelectionMode"] = selection_mode
	schedule["compositeExplorationProbability"] = exploration
	schedule["assemblyRecommendationFeatures"] = RecommendationFeaturesScript.measure(offline_data)
	schedule["assemblyFeatureVersion"] = RecommendationFeaturesScript.BUCKET_VERSION
	schedule["assemblyFeatureBuckets"] = RecommendationFeaturesScript.feature_buckets(schedule["assemblyRecommendationFeatures"])
	schedule["assemblyFeatureSampledReward"] = feature_selection.get("sampledReward", 0.0)
	schedule["assemblyFeatureExplorationDimension"] = feature_selection.get("explorationDimension", "")
	schedule["assemblyFeatureExplorationBucket"] = feature_selection.get("explorationBucket", "")
	schedule["assemblyFeatureQualityFallback"] = feature_quality_fallback
	return {
		"levelIndex": source_index,
		"difficultyPattern": pattern,
		"schedule": schedule
	}


static func _feature_candidate_pools(
	catalog_levels: Array, entries, selected_level: Dictionary, selector_progress: Dictionary
) -> Dictionary:
	var index := LevelDirectorScript.build_level_index(catalog_levels)
	var completed := LevelDirectorScript._completed_ids(selector_progress)
	var recent := LevelDirectorScript._recent_level_ids(selector_progress, LevelDirectorScript.DEDUPE_HISTORY_WINDOW)
	var eligible: Array = []
	# Reuse the ordinary director's exact dedupe tiers; re-ranking must not
	# resurrect filtered candidates or widen the selected recommendation arm.
	for relaxation in [[false, false], [true, false], [true, true]]:
		eligible = LevelDirectorScript._candidate_indices(
			catalog_levels, index, [int(selected_level.get("rows", 0))], [str(selected_level.get("difficulty", ""))],
			completed, recent, relaxation[0], relaxation[1]
		)
		if not eligible.is_empty():
			break
	var qualified := {}
	var fallback := {}
	for candidate_index in eligible:
		var level: Dictionary = catalog_levels[int(candidate_index)]
		var level_id := int(level.get("levelId", -1))
		for pattern in _available_patterns(entries, level_id):
			var data := _find_entry(entries, level_id, str(pattern))
			var features := RecommendationFeaturesScript.measure(data)
			if RecommendationFeaturesScript.feature_buckets(features).is_empty():
				continue
			var candidate := {"level": level, "data": data, "features": features}
			if not fallback.has(pattern):
				fallback[pattern] = []
			fallback[pattern].append(candidate)
			if RecommendationFeaturesScript.meets_minimum(features, str(pattern)):
				if not qualified.has(pattern):
					qualified[pattern] = []
				qualified[pattern].append(candidate)
	return {"qualified": qualified, "fallback": fallback}


static func _opening_two_piece_candidate(
	catalog_levels: Array,
	composite_entries,
	preferred_level: Dictionary,
	preferred_pattern: String
) -> Dictionary:
	var candidates := catalog_levels.duplicate(false)
	var preferred_size := int(preferred_level.get("rows", 0))
	var preferred_source := int(preferred_level.get("compositeSourceIndex", -1))
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_size_penalty := 0 if int(first.get("rows", 0)) == preferred_size else 1
		var second_size_penalty := 0 if int(second.get("rows", 0)) == preferred_size else 1
		if first_size_penalty != second_size_penalty:
			return first_size_penalty < second_size_penalty
		return absi(int(first.get("compositeSourceIndex", -1)) - preferred_source) < absi(int(second.get("compositeSourceIndex", -1)) - preferred_source)
	)
	for level in candidates:
		var level_id := int(level.get("levelId", -1))
		var patterns := _available_patterns(composite_entries, level_id)
		var ordered_patterns: Array = []
		if patterns.has(preferred_pattern):
			ordered_patterns.append(preferred_pattern)
		for fallback in ["simple", "medium"]:
			if patterns.has(fallback) and not ordered_patterns.has(fallback):
				ordered_patterns.append(fallback)
		for pattern in ordered_patterns:
			var data := _find_entry(composite_entries, level_id, str(pattern))
			if data.is_empty() or (data.get("pieces", []) as Array).size() != 2:
				continue
			var targets := CompositePlacementEngineScript.tutorial_demo_targets(data)
			if targets.has("wrong") and targets.has("correct"):
				return {"level": level, "pattern": str(pattern), "data": data}
	return {}


static func _opening_fallback_pattern(patterns: Array) -> String:
	for fallback in ["simple", "medium"]:
		if patterns.has(fallback):
			return fallback
	return ""


static func record_result(
	progress: Dictionary,
	level: Dictionary,
	schedule: Dictionary,
	completed: bool,
	elapsed_seconds: float,
	moves: int,
	hints: int,
	completed_date: String = "",
	completed_unix: int = 0,
	direct_finds: int = 0
) -> void:
	normalize_progress(progress)
	var selector_progress: Dictionary = progress["levelRecommendationProgress"]
	var selector_schedule := schedule.duplicate(true)
	selector_schedule["displayLevel"] = int(schedule.get("compositeRecommendationDisplay", schedule.get("displayLevel", 1)))
	selector_schedule["mode"] = str(schedule.get("compositeBaseRecommendationMode", "bayes"))
	selector_schedule["selectedSize"] = int(level.get("rows", schedule.get("selectedSize", 0)))
	selector_schedule["selectedDifficulty"] = str(level.get("difficulty", schedule.get("selectedDifficulty", "simple")))
	selector_schedule["isMilestoneChallenge"] = false
	if completed:
		LevelDirectorScript.record_completion(
			selector_progress, level, selector_schedule, elapsed_seconds, moves, hints,
			completed_date, completed_unix, direct_finds
		)
	else:
		LevelDirectorScript.record_failure(
			selector_progress, level, selector_schedule, elapsed_seconds, moves, hints,
			completed_date, completed_unix, direct_finds
		)
	# Attach immutable structural evidence to the authoritative reward run.
	# Later engagement callbacks update this very run, not whichever level is
	# currently on screen. Old runs without measurements are not guessed/backfilled.
	var reward_run: Dictionary = selector_progress["recentRuns"].back()
	reward_run["homeCompositeRound"] = int(schedule.get("homeCompositeRound", 1))
	reward_run["assemblyDifficultyPattern"] = str(schedule.get("assemblyDifficultyPattern", "medium"))
	reward_run["assemblyFeatureVersion"] = RecommendationFeaturesScript.BUCKET_VERSION
	reward_run["assemblyFeatureBuckets"] = RecommendationFeaturesScript.feature_buckets(schedule.get("assemblyRecommendationFeatures", {}))
	RecommendationFeaturesScript.observe_run(progress, reward_run)

	var size := int(level.get("rows", schedule.get("selectedSize", 0)))
	var pattern := str(schedule.get("assemblyDifficultyPattern", "medium"))
	_ensure_pattern_size(progress, size, PATTERNS)
	var size_key := str(size)
	var alpha_by_size: Dictionary = progress["patternAlphaBySize"]
	var alpha: Dictionary = alpha_by_size[size_key]
	alpha_by_size[size_key] = LevelDirectorScript.update_multinomial_posterior(
		alpha,
		pattern,
		1.0 if completed else 0.0,
		1.0
	)
	progress["patternAlphaBySize"] = alpha_by_size

	var stats_by_size: Dictionary = progress["patternStatsBySize"]
	var size_stats: Dictionary = stats_by_size.get(size_key, {})
	var stats: Dictionary = size_stats.get(pattern, {})
	stats["plays"] = int(stats.get("plays", 0)) + 1
	stats["wins" if completed else "failures"] = int(stats.get("wins" if completed else "failures", 0)) + 1
	size_stats[pattern] = stats
	stats_by_size[size_key] = size_stats
	progress["patternStatsBySize"] = stats_by_size

	var runs: Array = progress["recentRuns"]
	runs.append({
		"round": int(schedule.get("homeCompositeRound", 1)),
		"levelId": int(level.get("levelId", -1)),
		"size": size,
		"baseDifficultyClass": str(level.get("difficulty", "simple")),
		"pattern": pattern,
		"selectionMode": str(schedule.get("compositePatternSelectionMode", "")),
		"explorationProbability": float(schedule.get("compositeExplorationProbability", EXPLORATION_START)),
		"completed": completed,
		"elapsedSeconds": elapsed_seconds,
		"moves": moves,
		"hints": hints,
		"directFinds": direct_finds,
		"assemblyFeatures": schedule.get("assemblyRecommendationFeatures", {}).duplicate(true),
		"assemblyFeatureBuckets": reward_run["assemblyFeatureBuckets"].duplicate(true),
		"featureExplorationDimension": str(schedule.get("assemblyFeatureExplorationDimension", "")),
		"featureExplorationBucket": str(schedule.get("assemblyFeatureExplorationBucket", "")),
		"featureQualityFallback": bool(schedule.get("assemblyFeatureQualityFallback", false))
	})
	while runs.size() > MAX_RUN_HISTORY:
		runs.pop_front()


static func record_next_round_opened(progress: Dictionary, round_number: int, now_unix: int = 0) -> void:
	normalize_progress(progress)
	var selector: Dictionary = progress["levelRecommendationProgress"]
	var runs: Array = selector["recentRuns"]
	if runs.is_empty():
		return
	var previous: Dictionary = runs.back()
	if not bool(previous.get("completed", false)) or int(previous.get("homeCompositeRound", -1)) != round_number - 1:
		return
	if bool(previous.get("nextLevelObserved", false)):
		return
	var completed_unix := int(previous.get("completedUnix", 0))
	if now_unix > 0 and completed_unix > 0 and now_unix - completed_unix >= LevelDirectorScript.NEXT_LEVEL_WINDOW_SECONDS:
		previous["nextLevelObserved"] = true
		LevelDirectorScript._update_run_metric(selector, previous, "nextLevel", false)
	else:
		LevelDirectorScript.record_next_level_opened(selector)
	RecommendationFeaturesScript.observe_run(progress, previous)


static func record_retention_if_needed(progress: Dictionary, today: String, now_unix: int) -> bool:
	normalize_progress(progress)
	var selector: Dictionary = progress["levelRecommendationProgress"]
	var changed := LevelDirectorScript.record_retention_if_needed(selector, today, now_unix)
	for run in selector["recentRuns"]:
		if run is Dictionary:
			changed = RecommendationFeaturesScript.observe_run(progress, run) or changed
	return changed


static func exploration_probability(progress: Dictionary, size: int) -> float:
	normalize_progress(progress)
	var size_stats: Dictionary = progress["patternStatsBySize"].get(str(size), {})
	var total := 0
	var minimum_pattern_plays := 0
	for pattern_index in range(PATTERNS.size()):
		var plays := int(size_stats.get(PATTERNS[pattern_index], {}).get("plays", 0))
		total += plays
		if pattern_index == 0 or plays < minimum_pattern_plays:
			minimum_pattern_plays = plays
	var total_coverage := clampf(float(total) / float(FULL_EVIDENCE_TOTAL), 0.0, 1.0)
	var pattern_coverage := clampf(float(minimum_pattern_plays) / float(FULL_EVIDENCE_PER_PATTERN), 0.0, 1.0)
	var evidence_coverage := minf(total_coverage, pattern_coverage)
	return lerpf(EXPLORATION_START, EXPLORATION_END, evidence_coverage)


static func _ensure_pattern_size(progress: Dictionary, size: int, patterns: Array) -> void:
	var size_key := str(size)
	var alpha_by_size: Dictionary = progress["patternAlphaBySize"]
	var alpha: Dictionary = alpha_by_size.get(size_key, {})
	for pattern in patterns:
		if not alpha.has(str(pattern)):
			alpha[str(pattern)] = LevelDirectorScript.DIRICHLET_PRIOR_ALPHA
	alpha_by_size[size_key] = alpha
	progress["patternAlphaBySize"] = alpha_by_size


static func _sample_pattern_from_posterior(
	progress: Dictionary,
	size: int,
	patterns: Array,
	rng: RandomNumberGenerator
) -> String:
	var alpha: Dictionary = progress["patternAlphaBySize"].get(str(size), {})
	var total := 0.0
	for pattern in patterns:
		total += maxf(0.01, float(alpha.get(str(pattern), LevelDirectorScript.DIRICHLET_PRIOR_ALPHA)))
	if total <= 0.0:
		return str(patterns[rng.randi_range(0, patterns.size() - 1)])
	var roll := rng.randf() * total
	var cursor := 0.0
	for pattern in patterns:
		cursor += maxf(0.01, float(alpha.get(str(pattern), LevelDirectorScript.DIRICHLET_PRIOR_ALPHA)))
		if roll <= cursor:
			return str(pattern)
	return str(patterns.back())


static func _available_patterns(entries, level_id: int) -> Array:
	if entries is CompositeLevelStore:
		return entries.available_patterns(level_id)
	var result: Array = []
	for pattern in PATTERNS:
		var data = entries.get(_entry_key(level_id, pattern), {})
		if data is Dictionary and not data.is_empty():
			result.append(pattern)
	return result


static func _find_entry(entries, level_id: int, pattern: String) -> Dictionary:
	if entries is CompositeLevelStore:
		return entries.find_entry(level_id, pattern)
	var data = entries.get(_entry_key(level_id, pattern), {}) if entries is Dictionary else {}
	return data if data is Dictionary else {}


static func _entry_key(level_id: int, pattern: String) -> String:
	return "%d:%s" % [level_id, pattern]


static func _recommendation_seed(round_number: int, formal_display_level: int, progress: Dictionary) -> int:
	var evidence := 0
	for size_stats in progress.get("patternStatsBySize", {}).values():
		if not size_stats is Dictionary:
			continue
		for stats in size_stats.values():
			if stats is Dictionary:
				evidence += int(stats.get("plays", 0))
	return maxi(1, maxi(1, round_number) * 1000003 + maxi(1, formal_display_level) * 7919 + evidence * 9176 + 20260806)
