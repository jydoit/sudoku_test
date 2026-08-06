class_name CompositeLevelDirector
extends RefCounted

const LevelDirectorScript = preload("res://scripts/level_director.gd")

const PATTERNS := ["simple", "medium", "hard"]
const MIN_BOARD_SIZE := 6
const EXPLORATION_START := 0.50
const EXPLORATION_END := 0.20
const FULL_EVIDENCE_TOTAL := 30
const FULL_EVIDENCE_PER_PATTERN := 6
const MAX_RUN_HISTORY := 40


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
	return progress


static func recommend(
	levels: Array,
	composite_entries: Dictionary,
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
	_ensure_pattern_size(progress, size, patterns)
	var rng := RandomNumberGenerator.new()
	rng.seed = _recommendation_seed(round_number, formal_display_level, progress)
	var exploration := exploration_probability(progress, size)
	var selection_mode := "random_exploration"
	var pattern := ""
	if rng.randf() < exploration:
		pattern = str(patterns[rng.randi_range(0, patterns.size() - 1)])
	else:
		selection_mode = "posterior_multinomial"
		pattern = _sample_pattern_from_posterior(progress, size, patterns, rng)
	var offline_data = composite_entries.get(_entry_key(level_id, pattern), {})
	if not offline_data is Dictionary or offline_data.is_empty():
		return {}

	var schedule := LevelDirectorScript.manual_schedule_for_level(levels, source_index, 1, "home_composite")
	schedule["assemblyEnabled"] = true
	schedule["assemblySeed"] = int(offline_data.get("seed", 0))
	schedule["assemblyDifficultyPattern"] = pattern
	schedule["homeCompositeRound"] = maxi(1, round_number)
	schedule["compositeBaseDifficultyClass"] = str(selected_level.get("difficulty", "simple"))
	schedule["compositeBaseRecommendationMode"] = str(base_schedule.get("mode", "bayes"))
	schedule["compositeBaseRecommendationReason"] = str(base_schedule.get("recommendationReason", "bayes"))
	schedule["compositeRecommendationDisplay"] = recommendation_display
	schedule["compositePatternSelectionMode"] = selection_mode
	schedule["compositeExplorationProbability"] = exploration
	return {
		"levelIndex": source_index,
		"difficultyPattern": pattern,
		"schedule": schedule
	}


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
		"directFinds": direct_finds
	})
	while runs.size() > MAX_RUN_HISTORY:
		runs.pop_front()


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


static func _available_patterns(entries: Dictionary, level_id: int) -> Array:
	var result: Array = []
	for pattern in PATTERNS:
		var data = entries.get(_entry_key(level_id, pattern), {})
		if data is Dictionary and not data.is_empty():
			result.append(pattern)
	return result


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
