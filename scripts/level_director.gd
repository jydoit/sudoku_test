class_name LevelDirector
extends RefCounted

const FIXED_OPENING_COUNT := 10
const RECENT_WINDOW := 5
const DEDUPE_HISTORY_WINDOW := 50
const MILESTONE_RECENT_WINDOW := 15
const MAX_RUN_HISTORY := 40
const CHALLENGE_INTERVAL := 5
const MILESTONE_INTERVAL := 10
const OPTIONAL_CHALLENGE_START_DISPLAY := 31
const OPTIONAL_CHALLENGE_PROBABILITY := 0.5
const MAX_REWARD_ELAPSED_SECONDS := 15.0 * 60.0
const RETENTION_WINDOW_SECONDS := 24 * 60 * 60
const NEXT_LEVEL_WINDOW_SECONDS := 30 * 60
const NEXT_LEVEL_OPEN_BONUS := 0.08
const RETENTION_BONUS := 0.15
const BETA_PRIOR_A := 1.0
const BETA_PRIOR_B := 1.0
const DIRICHLET_PRIOR_ALPHA := 1.0
const DIRICHLET_RELEASE_DECAY := 0.2
const DIRICHLET_POSITIVE_RATE := 1.0
const DIRICHLET_NEGATIVE_RATE := 0.35
const MIN_SIZE_EXPOSURE := 12
const MIN_COMBO_EXPOSURE := 6
const NEW_SIZE_BOOST := 4.0
const EXTRA_EXPLORATION_PROBABILITY := 0.08
const TOOL_FIND_PROBABILITY := 0.15
const TOOL_HINT_PROBABILITY := 0.25
const TOOL_REWARD_BASE_WEIGHT := 0.08
const TOOL_REWARD_MAX_WEIGHT := 0.28
const NO_TOOL_DIFFICULTY_STREAK := 3
const KING_SOLUTION_ORDINALS := [2, 4, 6, 8]
const DIFFICULTY_ORDER := ["simple", "medium", "hard", "challenge"]
const SIZE_UNLOCK_DISPLAY_LEVELS := {
	5: 1,
	6: 11,
	7: 80,
	8: 160,
	9: 240
}
const FIXED_OPENING_PLAN := [
	{"size": 5, "difficulty": "simple", "ordinal": 1},
	{"size": 5, "difficulty": "simple", "ordinal": 2},
	{"size": 5, "difficulty": "simple", "ordinal": 3},
	{"size": 5, "difficulty": "simple", "ordinal": 4},
	{"size": 5, "difficulty": "simple", "ordinal": 5},
	{"size": 5, "difficulty": "medium", "ordinal": 1},
	{"size": 5, "difficulty": "medium", "ordinal": 2},
	{"size": 5, "difficulty": "medium", "ordinal": 3},
	{"size": 5, "difficulty": "simple", "ordinal": 6},
	{"size": 5, "difficulty": "hard", "ordinal": 1}
]


static func normalize_progress(progress: Dictionary) -> Dictionary:
	if not progress.has("recentRuns") or not progress["recentRuns"] is Array:
		progress["recentRuns"] = []
	if not progress.has("statsByArm") or not progress["statsByArm"] is Dictionary:
		progress["statsByArm"] = {}
	if not progress.has("completedLevelIds") or not progress["completedLevelIds"] is Array:
		progress["completedLevelIds"] = []
	if not progress.has("banditState") or not progress["banditState"] is Dictionary:
		progress["banditState"] = {}
	return progress


static func schedule_for_display_level(levels: Array, display_level: int, progress: Dictionary) -> Dictionary:
	normalize_progress(progress)
	var display := maxi(1, display_level)
	if levels.is_empty():
		return {}
	var level_index := build_level_index(levels)

	if display <= FIXED_OPENING_COUNT:
		return _fixed_opening_schedule(levels, level_index, display)

	var allowed_sizes := unlocked_sizes(display)
	var is_milestone := is_challenge_display(display, progress)
	var rng := _make_rng(display, "schedule:%d" % _progress_signature(progress))
	var completed_ids := _completed_ids(progress)
	var recent_ids := _recent_level_ids(progress, DEDUPE_HISTORY_WINDOW)
	var arm := {}
	var mode := "rule"

	if is_milestone:
		arm = _milestone_arm(progress, allowed_sizes, display, rng)
		mode = "challenge"
	elif _previous_run_is_challenge(progress):
		arm = _post_challenge_arm(progress, allowed_sizes)
		mode = "post_challenge"
	else:
		arm = _recommended_arm(levels, level_index, allowed_sizes, completed_ids, progress, display, rng)
		mode = str(arm.get("mode", "bayes"))

	var selected_size := int(arm.get("size", allowed_sizes[0]))
	var selected_difficulty := str(arm.get("difficulty", "simple"))
	var index := _choose_level_index(levels, level_index, selected_size, selected_difficulty, completed_ids, recent_ids, rng)
	if index < 0:
		index = _choose_any_level_index(levels, level_index, allowed_sizes, completed_ids, recent_ids, rng)
	if index < 0:
		index = clampi(display - 1, 0, levels.size() - 1)

	var level: Dictionary = levels[index]
	var schedule := _make_schedule(
		level,
		index,
		display,
		mode,
		is_milestone,
		allowed_sizes,
		int(level.get("rows", selected_size)),
		str(level.get("difficulty", selected_difficulty))
	)
	schedule["recommendationReason"] = str(arm.get("reason", mode))
	schedule["toolFindProbability"] = TOOL_FIND_PROBABILITY
	schedule["toolHintProbability"] = TOOL_HINT_PROBABILITY
	schedule["toolRewardWeight"] = float(arm.get("toolRewardWeight", TOOL_REWARD_BASE_WEIGHT))
	return schedule


static func recommend_level_for_sizes(levels: Array, allowed_sizes: Array, display_level: int, progress: Dictionary) -> Dictionary:
	normalize_progress(progress)
	if levels.is_empty() or allowed_sizes.is_empty():
		return {}
	var level_index := build_level_index(levels)
	var supported_sizes: Array = []
	for raw_size in allowed_sizes:
		var size := int(raw_size)
		if level_index.has(size) and not supported_sizes.has(size):
			supported_sizes.append(size)
	if supported_sizes.is_empty():
		return {}
	supported_sizes.sort()
	var display := maxi(FIXED_OPENING_COUNT + 1, display_level)
	var rng := _make_rng(display, "catalog:%d" % _progress_signature(progress))
	var completed_ids := _completed_ids(progress)
	var recent_ids := _recent_level_ids(progress, DEDUPE_HISTORY_WINDOW)
	var arm := _recommended_arm(levels, level_index, supported_sizes, completed_ids, progress, display, rng)
	var selected_size := int(arm.get("size", supported_sizes[0]))
	var selected_difficulty := str(arm.get("difficulty", "simple"))
	var index := _choose_level_index(levels, level_index, selected_size, selected_difficulty, completed_ids, recent_ids, rng)
	if index < 0:
		index = _choose_any_level_index(levels, level_index, supported_sizes, completed_ids, recent_ids, rng)
	if index < 0:
		return {}
	var level: Dictionary = levels[index]
	var schedule := _make_schedule(
		level,
		index,
		display,
		str(arm.get("mode", "bayes")),
		false,
		supported_sizes,
		int(level.get("rows", selected_size)),
		str(level.get("difficulty", selected_difficulty))
	)
	schedule["recommendationReason"] = str(arm.get("reason", schedule["mode"]))
	return schedule


static func build_level_index(levels: Array) -> Dictionary:
	var result := {}
	for index in range(levels.size()):
		var level: Dictionary = levels[index]
		var size := int(level.get("rows", 0))
		var difficulty := str(level.get("difficulty", "normal"))
		if not result.has(size):
			result[size] = {}
		if not result[size].has(difficulty):
			result[size][difficulty] = []
		result[size][difficulty].append(index)
	return result


static func manual_schedule_for_level(levels: Array, index: int, display_level: int, mode: String = "manual") -> Dictionary:
	if levels.is_empty():
		return {}
	var safe_index := clampi(index, 0, levels.size() - 1)
	var display := maxi(1, display_level)
	var level: Dictionary = levels[safe_index]
	var size := int(level.get("rows", 0))
	var difficulty := str(level.get("difficulty", "normal"))
	return _make_schedule(
		level,
		safe_index,
		display,
		mode,
		is_challenge_display(display),
		[size],
		size,
		difficulty
	)


static func _fixed_opening_schedule(levels: Array, level_index: Dictionary, display_level: int) -> Dictionary:
	var display := maxi(1, display_level)
	var plan_index := clampi(display - 1, 0, FIXED_OPENING_PLAN.size() - 1)
	var plan: Dictionary = FIXED_OPENING_PLAN[plan_index]
	var selected_size := int(plan.get("size", 5))
	var selected_difficulty := str(plan.get("difficulty", "simple"))
	var ordinal := int(plan.get("ordinal", 1))
	var index := _find_nth_level_index(level_index, selected_size, selected_difficulty, ordinal)
	if index < 0:
		index = clampi(display - 1, 0, levels.size() - 1)
	var level: Dictionary = levels[index]
	return _make_schedule(
		level,
		index,
		display,
		"fixed",
		is_challenge_display(display),
		[selected_size],
		int(level.get("rows", selected_size)),
		str(level.get("difficulty", selected_difficulty))
	)


static func _find_nth_level_index(level_index: Dictionary, size: int, difficulty: String, ordinal: int) -> int:
	var bucket := _indexed_bucket(level_index, size, difficulty)
	var safe_ordinal := maxi(1, ordinal)
	if bucket.size() >= safe_ordinal:
		return int(bucket[safe_ordinal - 1])
	return -1


static func minimum_display_for_size(size: int) -> int:
	return maxi(1, int(SIZE_UNLOCK_DISPLAY_LEVELS.get(size, 1)))


static func is_size_unlocked(size: int, display_level: int) -> bool:
	return maxi(1, display_level) >= minimum_display_for_size(size)


static func is_challenge_display(display_level: int, progress: Dictionary = {}) -> bool:
	var display := maxi(1, display_level)
	if display % MILESTONE_INTERVAL == 0:
		return true
	if display < OPTIONAL_CHALLENGE_START_DISPLAY:
		return false
	if display % CHALLENGE_INTERVAL != 0:
		return false
	var rng := _make_rng(display, "optional_challenge:%d" % _progress_signature(progress))
	return rng.randf() < OPTIONAL_CHALLENGE_PROBABILITY


static func unlocked_sizes(display_level: int) -> Array:
	var display := maxi(1, display_level)
	if display >= minimum_display_for_size(9):
		return [6, 7, 8, 9]
	if display >= minimum_display_for_size(8):
		return [6, 7, 8]
	if display >= minimum_display_for_size(7):
		return [5,6, 7]
	if display >= minimum_display_for_size(6):
		return [5, 6]
	if display >= minimum_display_for_size(5):
		return [5]
	return [5]


static func record_completion(progress: Dictionary, level: Dictionary, schedule: Dictionary, elapsed_seconds: float, moves: int, hints: int, completed_date: String = "", completed_unix: int = 0, direct_finds: int = 0) -> void:
	normalize_progress(progress)
	var size := int(level.get("rows", schedule.get("selectedSize", 0)))
	var difficulty := str(level.get("difficulty", schedule.get("selectedDifficulty", "normal")))
	var arm_key := _arm_key(size, difficulty)
	var stats: Dictionary = progress["statsByArm"].get(arm_key, {})
	var plays := int(stats.get("plays", 0)) + 1
	var wins := int(stats.get("wins", 0)) + 1
	var capped_elapsed := minf(elapsed_seconds, MAX_REWARD_ELAPSED_SECONDS)
	var reward := _completion_reward(size, difficulty, capped_elapsed, moves, hints)
	stats["plays"] = plays
	stats["wins"] = wins
	stats["elapsedTotal"] = float(stats.get("elapsedTotal", 0.0)) + capped_elapsed
	stats["movesTotal"] = int(stats.get("movesTotal", 0)) + moves
	stats["hintsTotal"] = int(stats.get("hintsTotal", 0)) + hints
	stats["directFindsTotal"] = int(stats.get("directFindsTotal", 0)) + direct_finds
	stats["toolUsesTotal"] = int(stats.get("toolUsesTotal", 0)) + hints + direct_finds
	stats["rewardTotal"] = float(stats.get("rewardTotal", 0.0)) + reward
	_update_beta_metric(stats, "completion", true)
	progress["statsByArm"][arm_key] = stats
	_update_dirichlet_feedback(progress, size, difficulty, 1.0, 1.0)

	var runs: Array = progress["recentRuns"]
	runs.append({
		"displayLevel": int(schedule.get("displayLevel", 1)),
		"levelIndex": int(schedule.get("levelIndex", -1)),
		"levelId": int(level.get("levelId", -1)),
		"size": size,
		"difficulty": difficulty,
		"mode": str(schedule.get("mode", "")),
		"isMilestoneChallenge": bool(schedule.get("isMilestoneChallenge", false)),
		"elapsedSeconds": capped_elapsed,
		"moves": moves,
		"hints": hints,
		"directFinds": direct_finds,
		"toolUses": hints + direct_finds,
		"completed": true,
		"reward": reward,
		"openedNextLevel": false,
		"retainedNextDay": false,
		"completedDate": completed_date,
		"completedUnix": completed_unix
	})
	while runs.size() > MAX_RUN_HISTORY:
		runs.pop_front()


static func record_failure(progress: Dictionary, level: Dictionary, schedule: Dictionary, elapsed_seconds: float, moves: int, hints: int, completed_date: String = "", completed_unix: int = 0, direct_finds: int = 0) -> void:
	normalize_progress(progress)
	var size := int(level.get("rows", schedule.get("selectedSize", 0)))
	var difficulty := str(level.get("difficulty", schedule.get("selectedDifficulty", "normal")))
	var arm_key := _arm_key(size, difficulty)
	var stats: Dictionary = progress["statsByArm"].get(arm_key, {})
	stats["plays"] = int(stats.get("plays", 0)) + 1
	stats["failures"] = int(stats.get("failures", 0)) + 1
	stats["elapsedTotal"] = float(stats.get("elapsedTotal", 0.0)) + minf(elapsed_seconds, MAX_REWARD_ELAPSED_SECONDS)
	stats["movesTotal"] = int(stats.get("movesTotal", 0)) + moves
	stats["hintsTotal"] = int(stats.get("hintsTotal", 0)) + hints
	stats["directFindsTotal"] = int(stats.get("directFindsTotal", 0)) + direct_finds
	stats["toolUsesTotal"] = int(stats.get("toolUsesTotal", 0)) + hints + direct_finds
	_update_beta_metric(stats, "completion", false)
	progress["statsByArm"][arm_key] = stats
	_update_dirichlet_feedback(progress, size, difficulty, 0.0, 1.0)

	var runs: Array = progress["recentRuns"]
	runs.append({
		"displayLevel": int(schedule.get("displayLevel", 1)),
		"levelIndex": int(schedule.get("levelIndex", -1)),
		"levelId": int(level.get("levelId", -1)),
		"size": size,
		"difficulty": difficulty,
		"mode": str(schedule.get("mode", "")),
		"isMilestoneChallenge": bool(schedule.get("isMilestoneChallenge", false)),
		"elapsedSeconds": minf(elapsed_seconds, MAX_REWARD_ELAPSED_SECONDS),
		"moves": moves,
		"hints": hints,
		"directFinds": direct_finds,
		"toolUses": hints + direct_finds,
		"completed": false,
		"reward": 0.0,
		"openedNextLevel": false,
		"retainedNextDay": false,
		"completedDate": completed_date,
		"completedUnix": completed_unix
	})
	while runs.size() > MAX_RUN_HISTORY:
		runs.pop_front()


static func record_next_level_opened(progress: Dictionary) -> void:
	normalize_progress(progress)
	var runs: Array = progress["recentRuns"]
	if runs.is_empty():
		return
	var run: Dictionary = runs[runs.size() - 1]
	if not bool(run.get("nextLevelObserved", false)):
		run["nextLevelObserved"] = true
		_update_run_metric(progress, run, "nextLevel", true)
	_add_reward_bonus(progress, run, NEXT_LEVEL_OPEN_BONUS, "openedNextLevel")


static func record_retention_if_needed(progress: Dictionary, today: String, now_unix: int = 0) -> void:
	normalize_progress(progress)
	var runs: Array = progress["recentRuns"]
	if runs.is_empty() or now_unix <= 0:
		return
	for run in runs:
		if not run is Dictionary:
			continue
		var completed_date := str(run.get("completedDate", ""))
		var completed_unix := int(run.get("completedUnix", 0))
		var age_seconds := now_unix - completed_unix
		if bool(run.get("retentionObserved", false)) or completed_unix <= 0:
			continue
		if completed_date != "" and completed_date != today and age_seconds >= 0 and age_seconds < RETENTION_WINDOW_SECONDS:
			run["retentionObserved"] = true
			_update_run_metric(progress, run, "retention", true)
			_add_reward_bonus(progress, run, RETENTION_BONUS, "retainedNextDay")
		elif age_seconds >= RETENTION_WINDOW_SECONDS:
			run["retentionObserved"] = true
			_update_run_metric(progress, run, "retention", false)

		if not bool(run.get("nextLevelObserved", false)) and age_seconds >= NEXT_LEVEL_WINDOW_SECONDS:
			run["nextLevelObserved"] = true
			_update_run_metric(progress, run, "nextLevel", false)


static func _make_schedule(level: Dictionary, index: int, display: int, mode: String, is_milestone: bool, allowed_sizes: Array, selected_size: int, selected_difficulty: String) -> Dictionary:
	var assembly_enabled := is_milestone and display % MILESTONE_INTERVAL == 0 and selected_size >= 6
	return {
		"displayLevel": display,
		"levelIndex": index,
		"levelId": int(level.get("levelId", -1)),
		"mode": mode,
		"isMilestoneChallenge": is_milestone,
		"assemblyEnabled": assembly_enabled,
		"allowedSizes": allowed_sizes.duplicate(),
		"selectedSize": selected_size,
		"selectedDifficulty": selected_difficulty,
		"kingPositions": [] if is_milestone else _opening_king_positions(level, display, index, mode == "fixed")
	}


static func _opening_king_positions(level: Dictionary, display: int, level_index: int, is_fixed: bool) -> Array:
	if is_fixed:
		if display <= 9 and level.has("kingPosition"):
			var fixed = level.get("kingPosition", [])
			if fixed is Array and fixed.size() >= 2:
				return [[int(fixed[0]), int(fixed[1])]]
		if display <= 9:
			var solution_king := _first_solution_position(level)
			if not solution_king.is_empty():
				return [solution_king]
		return []
	if not _should_reveal_dynamic_kings(display):
		return []

	var solution: Array = level.get("solution", [])
	var candidates: Array = []
	for ordinal in KING_SOLUTION_ORDINALS:
		var solution_index := int(ordinal) - 1
		if solution_index >= 0 and solution_index < solution.size():
			var coordinate = solution[solution_index]
			if coordinate is Array and coordinate.size() >= 2:
				candidates.append([int(coordinate[0]), int(coordinate[1])])
	if candidates.is_empty():
		return []

	var rng := _make_rng(display, "king:%d:%d" % [int(level.get("levelId", -1)), level_index])
	var count := mini(candidates.size(), _opening_king_count_for_size(int(level.get("rows", 5)), rng))
	var available := candidates.duplicate(true)
	var result: Array = []
	while result.size() < count and not available.is_empty():
		var pick := rng.randi_range(0, available.size() - 1)
		result.append(available[pick])
		available.remove_at(pick)
	return result


static func _opening_king_count_for_size(size: int, rng: RandomNumberGenerator) -> int:
	if size <= 5:
		return 1
	var roll := rng.randf()
	if size == 6:
		return 1 if roll < 0.9 else 2
	if size >= 7 and size <=8:
		if roll < 0.5:
			return 1
		return 2 if roll < 0.9 else 3
	if size >=9:
		if roll < 0.3:
			return 1
		return 2 if roll < 0.7 else 3
	return 1 



static func _should_reveal_dynamic_kings(display: int) -> bool:
	if display <= FIXED_OPENING_COUNT:
		return false
	return true


static func _first_solution_position(level: Dictionary) -> Array:
	var solution: Array = level.get("solution", [])
	if solution.is_empty():
		return []
	var coordinate = solution[0]
	if coordinate is Array and coordinate.size() >= 2:
		return [int(coordinate[0]), int(coordinate[1])]
	return []


static func _rule_arm(display: int, allowed_sizes: Array, rng: RandomNumberGenerator) -> Dictionary:
	var picked_size = _weighted_pick(_size_weights(display, allowed_sizes), rng)
	var picked_difficulty = _weighted_pick(_difficulty_weights(display), rng)
	return {"size": int(picked_size), "difficulty": str(picked_difficulty)}


static func _size_weights(display: int, allowed_sizes: Array) -> Dictionary:
	var weights := {}
	for size in allowed_sizes:
		weights[int(size)] = 1.0

	if display < 20 and weights.has(6):
		weights[5] = 0.82
		weights[6] = 1.18
	elif display < 40:
		for size in weights.keys():
			weights[size] = 0.82 + float(size - 5) * 0.16
	else:
		for size in weights.keys():
			weights[size] = 0.72 + float(size - 5) * 0.18
	return weights


static func _difficulty_weights(display: int) -> Dictionary:
	if display < 20:
		return {"simple": 0.46, "medium": 0.36, "hard": 0.18, "challenge": 0.0}
	if display < 40:
		return {"simple": 0.22, "medium": 0.34, "hard": 0.31, "challenge": 0.13}
	return {"simple": 0.14, "medium": 0.25, "hard": 0.36, "challenge": 0.25}


static func _recommended_arm(levels: Array, level_index: Dictionary, allowed_sizes: Array, completed_ids: Array, progress: Dictionary, display: int, rng: RandomNumberGenerator) -> Dictionary:
	_ensure_bandit_state(progress, level_index)
	_apply_size_release_policy(progress, allowed_sizes)
	var arms := _available_arms(level_index, allowed_sizes)
	if arms.is_empty():
		return {"size": int(allowed_sizes[0]), "difficulty": "simple", "mode": "bayes", "reason": "fallback"}

	var recent := _last_runs(progress, RECENT_WINDOW)
	var recent_mode_size := _most_common_recent_size(recent, int(allowed_sizes[0]))
	var new_size_arm := _new_size_medium_probe(arms, progress, recent_mode_size)
	if not new_size_arm.is_empty():
		return {
			"size": int(new_size_arm["size"]),
			"difficulty": str(new_size_arm["difficulty"]),
			"mode": "new_size_probe",
			"reason": "higher_than_recent_mode",
			"toolRewardWeight": TOOL_REWARD_BASE_WEIGHT
		}

	var recent_max_arm := _recent_max_size_probe(arms, progress, recent)
	if not recent_max_arm.is_empty():
		var recent_max_tool_weight := TOOL_REWARD_MAX_WEIGHT if _no_tool_streak(progress) >= NO_TOOL_DIFFICULTY_STREAK else TOOL_REWARD_BASE_WEIGHT
		return {
			"size": int(recent_max_arm["size"]),
			"difficulty": str(recent_max_arm["difficulty"]),
			"mode": "recent_size_probe",
			"reason": "recent_max_size",
			"toolRewardWeight": recent_max_tool_weight
		}

	var unseen := _arms_with_max_plays(arms, progress, 0)
	if not unseen.is_empty():
		return _weighted_arm_choice(unseen, progress, rng, "unseen_combo_probe", TOOL_REWARD_BASE_WEIGHT)

	var under_size_quota := _arms_for_size_quota(arms, progress)
	if not under_size_quota.is_empty():
		return _weighted_arm_choice(under_size_quota, progress, rng, "size_quota_probe", TOOL_REWARD_MAX_WEIGHT)

	var under_quota: Array = []
	for arm in arms:
		var plays := _arm_plays(progress, int(arm["size"]), str(arm["difficulty"]))
		if plays < MIN_COMBO_EXPOSURE:
			under_quota.append(arm)
	if not under_quota.is_empty():
		return _weighted_arm_choice(under_quota, progress, rng, "combo_quota_probe", TOOL_REWARD_MAX_WEIGHT)

	var tool_weight := TOOL_REWARD_MAX_WEIGHT
	var sampled_arm := _thompson_arm(arms, progress, rng, display, tool_weight)
	if not sampled_arm.is_empty() and rng.randf() >= EXTRA_EXPLORATION_PROBABILITY:
		sampled_arm["mode"] = "thompson_sampling"
		sampled_arm["reason"] = "posterior_reward"
		sampled_arm["toolRewardWeight"] = tool_weight
		return sampled_arm

	var random_arm := _weighted_arm_choice(arms, progress, rng, "posterior_exploration", tool_weight)
	return random_arm


static func _available_arms(level_index: Dictionary, allowed_sizes: Array) -> Array:
	var arms: Array = []
	for raw_size in allowed_sizes:
		var size := int(raw_size)
		var by_difficulty: Dictionary = level_index.get(size, {})
		for difficulty in DIFFICULTY_ORDER:
			if not by_difficulty.get(difficulty, []).is_empty():
				arms.append({"size": size, "difficulty": difficulty})
	return arms


static func _arms_with_max_plays(arms: Array, progress: Dictionary, maximum_plays: int) -> Array:
	var result: Array = []
	for arm in arms:
		if _arm_plays(progress, int(arm["size"]), str(arm["difficulty"])) <= maximum_plays:
			result.append(arm)
	return result


static func _new_size_medium_probe(arms: Array, progress: Dictionary, recent_mode_size: int) -> Dictionary:
	var candidate_sizes: Array = []
	for arm in arms:
		var size := int(arm["size"])
		if size > recent_mode_size and _arm_plays(progress, size, str(arm["difficulty"])) == 0 and not candidate_sizes.has(size):
			candidate_sizes.append(size)
	if candidate_sizes.is_empty():
		return {}
	candidate_sizes.sort()
	var selected_size := int(candidate_sizes[0])
	for arm in arms:
		if int(arm["size"]) == selected_size and str(arm["difficulty"]) == "medium" and _arm_plays(progress, selected_size, "medium") == 0:
			return arm
	for arm in arms:
		if int(arm["size"]) == selected_size and _arm_plays(progress, selected_size, str(arm["difficulty"])) == 0:
			return arm
	return {}


static func _recent_max_size_probe(arms: Array, progress: Dictionary, recent: Array) -> Dictionary:
	if recent.is_empty():
		return {}
	var max_size := 0
	for run in recent:
		max_size = maxi(max_size, int(run.get("size", 0)))
	if max_size <= 0:
		return {}
	var preferred := ["medium", "hard", "simple", "challenge"]
	if _no_tool_streak(progress) >= NO_TOOL_DIFFICULTY_STREAK:
		preferred = ["hard", "medium", "challenge", "simple"]
	for difficulty in preferred:
		for arm in arms:
			if int(arm["size"]) == max_size and str(arm["difficulty"]) == difficulty and _arm_plays(progress, max_size, difficulty) == 0:
				return arm
	return {}


static func _arms_for_size_quota(arms: Array, progress: Dictionary) -> Array:
	var size_plays: Dictionary = {}
	for arm in arms:
		var size := int(arm["size"])
		size_plays[size] = _size_plays(progress, size)
	var under_quota_sizes: Array = []
	for size in size_plays.keys():
		if int(size_plays[size]) < MIN_SIZE_EXPOSURE:
			under_quota_sizes.append(int(size))
	if under_quota_sizes.is_empty():
		return []
	var selected_size: int = int(under_quota_sizes[0])
	for size in under_quota_sizes:
		if int(size_plays[size]) < int(size_plays[selected_size]):
			selected_size = size
	var result: Array = []
	for arm in arms:
		if int(arm["size"]) == int(selected_size):
			result.append(arm)
	return result


static func _weighted_arm_choice(arms: Array, progress: Dictionary, rng: RandomNumberGenerator, reason: String, tool_weight: float) -> Dictionary:
	var weights: Array[float] = []
	var total := 0.0
	for arm in arms:
		var size := int(arm["size"])
		var difficulty := str(arm["difficulty"])
		var plays := _arm_plays(progress, size, difficulty)
		var gap := float(maxi(1, MIN_COMBO_EXPOSURE - plays))
		var novelty := 1.0 if plays == 0 else 0.35
		var weight := gap * novelty * _dirichlet_arm_mean(progress, size, difficulty)
		weights.append(maxf(0.001, weight))
		total += weights.back()
	if total <= 0.0:
		return arms[rng.randi_range(0, arms.size() - 1)].duplicate(true)
	var roll := rng.randf() * total
	var cursor := 0.0
	for index in range(arms.size()):
		cursor += weights[index]
		if roll <= cursor:
			var result: Dictionary = arms[index].duplicate(true)
			result["mode"] = reason
			result["reason"] = reason
			result["toolRewardWeight"] = tool_weight
			return result
	return arms.back().duplicate(true)


static func _thompson_arm(arms: Array, progress: Dictionary, rng: RandomNumberGenerator, display: int, tool_weight: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for arm in arms:
		var size := int(arm["size"])
		var difficulty := str(arm["difficulty"])
		var stats: Dictionary = progress["statsByArm"].get(_arm_key(size, difficulty), {})
		var completion := _beta_sample(stats, "completion", rng)
		var next_level := _beta_sample(stats, "nextLevel", rng)
		var retention := _beta_sample(stats, "retention", rng)
		var score := completion * 0.20 + next_level * 0.45 + retention * 0.35
		score += tool_weight * _expected_tool_value(size, difficulty)
		if _no_tool_streak(progress) >= NO_TOOL_DIFFICULTY_STREAK:
			score += _difficulty_score(difficulty) * 0.08
		score += _dirichlet_arm_sample(progress, size, difficulty, rng) * 0.08
		if score > best_score:
			best_score = score
			best = arm.duplicate(true)
	return best


static func _milestone_arm(progress: Dictionary, allowed_sizes: Array, display: int, rng: RandomNumberGenerator) -> Dictionary:
	var recent := _last_runs(progress, MILESTONE_RECENT_WINDOW)
	if recent.is_empty():
		return {"size": int(allowed_sizes[allowed_sizes.size() - 1]), "difficulty": "hard"}

	var best: Dictionary = recent[0]
	var best_score := -INF
	for run in recent:
		var difficulty := str(run.get("difficulty", "simple"))
		var score := _difficulty_score(difficulty) * 100.0
		score += float(run.get("elapsedSeconds", 0.0)) * 0.03
		score += float(run.get("hints", 0)) * 4.0
		score += float(run.get("moves", 0)) * 0.12
		score += float(run.get("size", 5)) * 2.0
		if score > best_score:
			best_score = score
			best = run

	var size := int(best.get("size", allowed_sizes[0]))
	if not allowed_sizes.has(size):
		size = int(allowed_sizes[allowed_sizes.size() - 1])
	var difficulty := str(best.get("difficulty", "hard"))
	var action = _weighted_pick(_milestone_action_weights(display), rng)
	if str(action) == "size_up":
		return {"size": _next_size(size, allowed_sizes), "difficulty": difficulty}
	return {"size": size, "difficulty": _next_difficulty(difficulty)}


static func _previous_run_is_challenge(progress: Dictionary) -> bool:
	var runs := _last_runs(progress, 1)
	if runs.is_empty():
		return false
	var run: Dictionary = runs[0]
	if run.has("isMilestoneChallenge"):
		return bool(run.get("isMilestoneChallenge", false))
	var display := int(run.get("displayLevel", 0))
	return display > 0 and display % MILESTONE_INTERVAL == 0


static func _post_challenge_arm(progress: Dictionary, allowed_sizes: Array) -> Dictionary:
	var previous: Dictionary = _last_runs(progress, 1)[0]
	var size := int(previous.get("size", allowed_sizes[0]))
	if not allowed_sizes.has(size):
		size = int(allowed_sizes[allowed_sizes.size() - 1])
	return {"size": size, "difficulty": _previous_difficulty(str(previous.get("difficulty", "medium")))}


static func _choose_level_index(levels: Array, level_index: Dictionary, size: int, difficulty: String, completed_ids: Array, recent_ids: Array, rng: RandomNumberGenerator) -> int:
	var candidates := _candidate_indices(levels, level_index, [size], [difficulty], completed_ids, recent_ids, false, false)
	if candidates.is_empty():
		candidates = _candidate_indices(levels, level_index, [size], [difficulty], completed_ids, recent_ids, true, false)
	if candidates.is_empty():
		candidates = _candidate_indices(levels, level_index, [size], [difficulty], completed_ids, recent_ids, true, true)
	if candidates.is_empty():
		return -1
	return int(candidates[rng.randi_range(0, candidates.size() - 1)])


static func _choose_any_level_index(levels: Array, level_index: Dictionary, allowed_sizes: Array, completed_ids: Array, recent_ids: Array, rng: RandomNumberGenerator) -> int:
	var candidates := _candidate_indices(levels, level_index, allowed_sizes, DIFFICULTY_ORDER, completed_ids, recent_ids, false, false)
	if candidates.is_empty():
		candidates = _candidate_indices(levels, level_index, allowed_sizes, DIFFICULTY_ORDER, completed_ids, recent_ids, true, false)
	if candidates.is_empty():
		candidates = _candidate_indices(levels, level_index, allowed_sizes, DIFFICULTY_ORDER, completed_ids, recent_ids, true, true)
	if candidates.is_empty():
		return -1
	return int(candidates[rng.randi_range(0, candidates.size() - 1)])


static func _candidate_indices(levels: Array, level_index: Dictionary, sizes: Array, difficulties: Array, completed_ids: Array, recent_ids: Array, allow_completed: bool, allow_recent: bool) -> Array:
	var result: Array = []
	for size in sizes:
		for difficulty in difficulties:
			for index in _indexed_bucket(level_index, int(size), str(difficulty)):
				var level: Dictionary = levels[int(index)]
				var level_id := int(level.get("levelId", -1))
				if not allow_completed and completed_ids.has(level_id):
					continue
				if not allow_recent and recent_ids.has(level_id):
					continue
				result.append(int(index))
	return result


static func _prefer_not_recent(candidates: Array, levels: Array, progress: Dictionary) -> Array:
	if candidates.is_empty():
		return candidates
	var recent_ids := _recent_level_ids(progress, DEDUPE_HISTORY_WINDOW)
	var filtered: Array = []
	for index in candidates:
		var level: Dictionary = levels[int(index)]
		if not recent_ids.has(int(level.get("levelId", -1))):
			filtered.append(index)
	return filtered if not filtered.is_empty() else candidates


static func _indexed_bucket(level_index: Dictionary, size: int, difficulty: String) -> Array:
	var by_size: Dictionary = level_index.get(size, {})
	return by_size.get(difficulty, [])


static func _milestone_action_weights(display: int) -> Dictionary:
	if display < 50:
		return {"difficulty_up": 0.6, "size_up": 0.4}
	if display < 100:
		return {"difficulty_up": 0.5, "size_up": 0.5}
	return {"difficulty_up": 0.4, "size_up": 0.6}


static func _next_difficulty(difficulty: String) -> String:
	var index := DIFFICULTY_ORDER.find(difficulty)
	if index < 0:
		return "medium"
	return DIFFICULTY_ORDER[mini(index + 1, DIFFICULTY_ORDER.size() - 1)]


static func _previous_difficulty(difficulty: String) -> String:
	var index := DIFFICULTY_ORDER.find(difficulty)
	if index <= 0:
		return "simple"
	return DIFFICULTY_ORDER[index - 1]


static func _next_size(size: int, allowed_sizes: Array) -> int:
	var result := size
	for allowed in allowed_sizes:
		var allowed_size := int(allowed)
		if allowed_size > size:
			return allowed_size
		result = allowed_size
	return result


static func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator):
	var total := 0.0
	for value in weights.values():
		total += maxf(0.0, float(value))
	if total <= 0.0:
		return weights.keys()[0]
	var roll := rng.randf() * total
	var cursor := 0.0
	for key in weights.keys():
		cursor += maxf(0.0, float(weights[key]))
		if roll <= cursor:
			return key
	return weights.keys()[weights.size() - 1]


static func _ensure_bandit_state(progress: Dictionary, level_index: Dictionary) -> void:
	normalize_progress(progress)
	var state: Dictionary = progress["banditState"]
	var size_alpha: Dictionary = state.get("sizeAlpha", {})
	var difficulty_alpha: Dictionary = state.get("difficultyAlpha", {})
	for raw_size in level_index.keys():
		var size_key := str(int(raw_size))
		if not size_alpha.has(size_key):
			size_alpha[size_key] = DIRICHLET_PRIOR_ALPHA
		var by_difficulty: Dictionary = difficulty_alpha.get(size_key, {})
		var indexed: Dictionary = level_index[raw_size]
		for difficulty in DIFFICULTY_ORDER:
			if not indexed.get(difficulty, []).is_empty() and not by_difficulty.has(difficulty):
				by_difficulty[difficulty] = DIRICHLET_PRIOR_ALPHA
		difficulty_alpha[size_key] = by_difficulty
	state["sizeAlpha"] = size_alpha
	state["difficultyAlpha"] = difficulty_alpha
	if not state.has("releaseEpoch"):
		state["releaseEpoch"] = 0
	if not state.has("lastKnownSizes"):
		state["lastKnownSizes"] = []
	progress["banditState"] = state


static func _apply_size_release_policy(progress: Dictionary, allowed_sizes: Array) -> void:
	var state: Dictionary = progress.get("banditState", {})
	var known: Array = state.get("lastKnownSizes", [])
	var size_alpha: Dictionary = state.get("sizeAlpha", {})
	var difficulty_alpha: Dictionary = state.get("difficultyAlpha", {})
	var newly_allowed: Array = []
	for raw_size in allowed_sizes:
		var size := int(raw_size)
		if not known.has(size):
			newly_allowed.append(size)
	if newly_allowed.is_empty():
		return
	for key in size_alpha.keys():
		if newly_allowed.has(int(key)):
			continue
		size_alpha[key] = DIRICHLET_PRIOR_ALPHA + (float(size_alpha[key]) - DIRICHLET_PRIOR_ALPHA) * DIRICHLET_RELEASE_DECAY
	for size in newly_allowed:
		var size_key := str(size)
		size_alpha[size_key] = DIRICHLET_PRIOR_ALPHA + NEW_SIZE_BOOST
		var by_difficulty: Dictionary = difficulty_alpha.get(size_key, {})
		for difficulty in by_difficulty.keys():
			by_difficulty[difficulty] = DIRICHLET_PRIOR_ALPHA + NEW_SIZE_BOOST * 0.35
		difficulty_alpha[size_key] = by_difficulty
		known.append(size)
	state["lastKnownSizes"] = known
	state["releaseEpoch"] = int(state.get("releaseEpoch", 0)) + newly_allowed.size()
	state["sizeAlpha"] = size_alpha
	state["difficultyAlpha"] = difficulty_alpha
	progress["banditState"] = state


static func _arm_plays(progress: Dictionary, size: int, difficulty: String) -> int:
	var stats: Dictionary = progress.get("statsByArm", {}).get(_arm_key(size, difficulty), {})
	return int(stats.get("plays", 0))


static func _size_plays(progress: Dictionary, size: int) -> int:
	var total := 0
	for difficulty in DIFFICULTY_ORDER:
		total += _arm_plays(progress, size, difficulty)
	return total


static func _beta_sample(stats: Dictionary, metric: String, rng: RandomNumberGenerator) -> float:
	var a := maxf(0.05, float(stats.get(metric + "A", BETA_PRIOR_A)))
	var b := maxf(0.05, float(stats.get(metric + "B", BETA_PRIOR_B)))
	var x := _sample_gamma(a, rng)
	var y := _sample_gamma(b, rng)
	if x + y <= 0.0:
		return 0.5
	return clampf(x / (x + y), 0.0, 1.0)


static func _sample_gamma(shape: float, rng: RandomNumberGenerator) -> float:
	if shape < 1.0:
		return _sample_gamma(shape + 1.0, rng) * pow(maxf(0.000001, rng.randf()), 1.0 / shape)
	var d := shape - 1.0 / 3.0
	var c := 1.0 / sqrt(9.0 * d)
	for _attempt in range(64):
		var normal := rng.randfn(0.0, 1.0)
		var v := 1.0 + c * normal
		if v <= 0.0:
			continue
		v = v * v * v
		var roll := maxf(0.000001, rng.randf())
		if roll < 1.0 - 0.0331 * pow(normal, 4.0) or log(roll) < 0.5 * normal * normal + d * (1.0 - v + log(v)):
			return d * v
	return maxf(0.000001, d)


static func _dirichlet_arm_mean(progress: Dictionary, size: int, difficulty: String) -> float:
	var state: Dictionary = progress.get("banditState", {})
	var size_alpha: Dictionary = state.get("sizeAlpha", {})
	var difficulty_alpha: Dictionary = state.get("difficultyAlpha", {})
	var size_total := 0.0
	for value in size_alpha.values():
		size_total += maxf(0.01, float(value))
	var difficulty_values: Dictionary = difficulty_alpha.get(str(size), {})
	var difficulty_total := 0.0
	for value in difficulty_values.values():
		difficulty_total += maxf(0.01, float(value))
	if size_total <= 0.0 or difficulty_total <= 0.0:
		return 1.0
	return maxf(0.001, float(size_alpha.get(str(size), DIRICHLET_PRIOR_ALPHA)) / size_total * float(difficulty_values.get(difficulty, DIRICHLET_PRIOR_ALPHA)) / difficulty_total)


static func _dirichlet_arm_sample(progress: Dictionary, size: int, difficulty: String, rng: RandomNumberGenerator) -> float:
	var state: Dictionary = progress.get("banditState", {})
	var size_alpha: Dictionary = state.get("sizeAlpha", {})
	var difficulty_alpha: Dictionary = state.get("difficultyAlpha", {})
	var size_keys := size_alpha.keys()
	var size_values: Array[float] = []
	for key in size_keys:
		size_values.append(maxf(0.05, float(size_alpha[key])))
	var size_samples := _sample_dirichlet(size_values, rng)
	var size_index := size_keys.find(str(size))
	if size_index < 0:
		return 0.0
	var difficulty_values: Dictionary = difficulty_alpha.get(str(size), {})
	var difficulty_keys := difficulty_values.keys()
	var difficulty_shapes: Array[float] = []
	for key in difficulty_keys:
		difficulty_shapes.append(maxf(0.05, float(difficulty_values[key])))
	var difficulty_samples := _sample_dirichlet(difficulty_shapes, rng)
	var difficulty_index := difficulty_keys.find(difficulty)
	if difficulty_index < 0:
		return float(size_samples[size_index])
	return float(size_samples[size_index]) * float(difficulty_samples[difficulty_index])


static func _sample_dirichlet(shapes: Array[float], rng: RandomNumberGenerator) -> Array[float]:
	var samples: Array[float] = []
	var total := 0.0
	for shape in shapes:
		var value := _sample_gamma(maxf(0.05, shape), rng)
		samples.append(value)
		total += value
	if total <= 0.0:
		var uniform := 1.0 / float(maxi(1, shapes.size()))
		for index in range(samples.size()):
			samples[index] = uniform
		return samples
	for index in range(samples.size()):
		samples[index] /= total
	return samples


static func _expected_tool_value(size: int, difficulty: String) -> float:
	var intensity := clampf(float(size - 5) * 0.12 + _difficulty_score(difficulty) * 0.18, 0.25, 1.4)
	return (TOOL_FIND_PROBABILITY * 1.0 + TOOL_HINT_PROBABILITY * 0.8) * intensity


static func _update_beta_metric(stats: Dictionary, metric: String, succeeded: bool) -> void:
	var a_key := metric + "A"
	var b_key := metric + "B"
	if succeeded:
		stats[a_key] = float(stats.get(a_key, BETA_PRIOR_A)) + 1.0
	else:
		stats[b_key] = float(stats.get(b_key, BETA_PRIOR_B)) + 1.0


static func _update_run_metric(progress: Dictionary, run: Dictionary, metric: String, succeeded: bool) -> void:
	var size := int(run.get("size", 0))
	var difficulty := str(run.get("difficulty", "normal"))
	var key := _arm_key(size, difficulty)
	var stats: Dictionary = progress["statsByArm"].get(key, {})
	_update_beta_metric(stats, metric, succeeded)
	progress["statsByArm"][key] = stats
	_update_dirichlet_feedback(progress, size, difficulty, 1.0 if succeeded else 0.0, 0.8)


static func _update_dirichlet_feedback(progress: Dictionary, size: int, difficulty: String, quality: float, evidence_weight: float) -> void:
	var state: Dictionary = progress.get("banditState", {})
	var size_alpha: Dictionary = state.get("sizeAlpha", {})
	var difficulty_alpha: Dictionary = state.get("difficultyAlpha", {})
	var size_key := str(size)
	if not size_alpha.has(size_key):
		size_alpha[size_key] = DIRICHLET_PRIOR_ALPHA
	if not difficulty_alpha.has(size_key):
		difficulty_alpha[size_key] = {}
	var difficulty_values: Dictionary = difficulty_alpha[size_key]
	if not difficulty_values.has(difficulty):
		difficulty_values[difficulty] = DIRICHLET_PRIOR_ALPHA
	size_alpha = update_multinomial_posterior(size_alpha, size_key, quality, evidence_weight)
	difficulty_values = update_multinomial_posterior(difficulty_values, difficulty, quality, evidence_weight)
	difficulty_alpha[size_key] = difficulty_values
	state["sizeAlpha"] = size_alpha
	state["difficultyAlpha"] = difficulty_alpha
	progress["banditState"] = state


static func update_multinomial_posterior(raw_alpha: Dictionary, selected_key, quality: float, evidence_weight: float = 1.0) -> Dictionary:
	var alpha := raw_alpha.duplicate(true)
	if not alpha.has(selected_key):
		alpha[selected_key] = DIRICHLET_PRIOR_ALPHA
	var positive := maxf(0.0, quality - 0.5) * 2.0
	var negative := maxf(0.0, 0.5 - quality) * 2.0
	if positive > 0.0:
		alpha[selected_key] = float(alpha[selected_key]) + DIRICHLET_POSITIVE_RATE * evidence_weight * positive
	elif negative > 0.0:
		var share := 1.0 / float(maxi(1, alpha.size() - 1))
		for other_key in alpha.keys():
			if other_key != selected_key:
				alpha[other_key] = float(alpha[other_key]) + DIRICHLET_NEGATIVE_RATE * evidence_weight * negative * share
	return alpha


static func _no_tool_streak(progress: Dictionary) -> int:
	var streak := 0
	var runs := _last_runs(progress, RECENT_WINDOW)
	for index in range(runs.size() - 1, -1, -1):
		if int(runs[index].get("toolUses", 0)) > 0:
			break
		streak += 1
	return streak


static func _most_common_recent_size(runs: Array, fallback: int) -> int:
	if runs.is_empty():
		return fallback
	var counts: Dictionary = {}
	for run in runs:
		var size := int(run.get("size", fallback))
		counts[size] = int(counts.get(size, 0)) + 1
	var best_size := fallback
	var best_count := -1
	for size in counts.keys():
		if int(counts[size]) > best_count or (int(counts[size]) == best_count and int(size) > best_size):
			best_size = int(size)
			best_count = int(counts[size])
	return best_size


static func _completion_reward(size: int, difficulty: String, elapsed_seconds: float, moves: int, hints: int) -> float:
	var expected := _expected_seconds(size, difficulty)
	var time_score := clampf(expected / maxf(1.0, elapsed_seconds), 0.15, 1.8)
	var hint_score := clampf(1.0 - float(hints) / float(maxi(1, size)), 0.2, 1.0)
	var move_score := clampf(expected / maxf(1.0, float(moves) * 7.0), 0.2, 1.3)
	return time_score * 0.58 + hint_score * 0.22 + move_score * 0.12 + _difficulty_score(difficulty) * 0.08


static func _expected_seconds(size: int, difficulty: String) -> float:
	var base := float(size * size) * 2.6
	return base * _difficulty_score(difficulty)


static func _difficulty_score(difficulty: String) -> float:
	match difficulty:
		"simple":
			return 1.0
		"medium":
			return 1.35
		"hard":
			return 1.85
		"challenge":
			return 2.35
		_:
			return 1.2


static func _total_arm_plays(progress: Dictionary) -> int:
	normalize_progress(progress)
	var total := 0
	for stats in progress["statsByArm"].values():
		if stats is Dictionary:
			total += int(stats.get("plays", 0))
	return total


static func _arm_key(size: int, difficulty: String) -> String:
	return "%d|%s" % [size, difficulty]


static func _add_reward_bonus(progress: Dictionary, run: Dictionary, amount: float, flag: String) -> void:
	if bool(run.get(flag, false)):
		return
	run[flag] = true
	run["reward"] = float(run.get("reward", 0.0)) + amount
	var key := _arm_key(int(run.get("size", 0)), str(run.get("difficulty", "normal")))
	var stats: Dictionary = progress["statsByArm"].get(key, {})
	stats["rewardTotal"] = float(stats.get("rewardTotal", 0.0)) + amount
	progress["statsByArm"][key] = stats


static func _completed_ids(progress: Dictionary) -> Array:
	var result: Array = []
	var raw = progress.get("completedLevelIds", [])
	if raw is Array:
		for value in raw:
			result.append(int(value))
	return result


static func _last_runs(progress: Dictionary, count: int) -> Array:
	var runs: Array = progress.get("recentRuns", [])
	var result: Array = []
	var start := maxi(0, runs.size() - count)
	for index in range(start, runs.size()):
		if runs[index] is Dictionary:
			result.append(runs[index])
	return result


static func _recent_level_ids(progress: Dictionary, count: int) -> Array:
	var result: Array = []
	for run in _last_runs(progress, count):
		result.append(int(run.get("levelId", -1)))
	return result


static func _progress_signature(progress: Dictionary) -> int:
	var runs: Array = progress.get("recentRuns", [])
	var total := runs.size() * 31
	for run in _last_runs(progress, RECENT_WINDOW):
		total += int(run.get("levelId", 0)) * 7
		total += int(run.get("moves", 0))
		total += int(run.get("hints", 0)) * 13
	return total


static func _make_rng(display: int, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var raw_seed := ("%s:%d" % [salt, display]).hash()
	rng.seed = absi(raw_seed)
	return rng
