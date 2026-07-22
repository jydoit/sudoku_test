class_name LevelDirector
extends RefCounted

const FIXED_OPENING_COUNT := 10
const RECENT_WINDOW := 5
const DEDUPE_HISTORY_WINDOW := 50
const MILESTONE_RECENT_WINDOW := 15
const MAX_RUN_HISTORY := 40
const MILESTONE_INTERVAL := 10
const UCB_BOOTSTRAP_RUNS := 18
const UCB_EXPLORATION := 0.72
const MAX_REWARD_ELAPSED_SECONDS := 15.0 * 60.0
const RETENTION_WINDOW_SECONDS := 24 * 60 * 60
const NEXT_LEVEL_OPEN_BONUS := 0.08
const RETENTION_BONUS := 0.15
const KING_SOLUTION_ORDINALS := [2, 4, 6, 8]
const DIFFICULTY_ORDER := ["simple", "medium", "hard", "challenge"]
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
	var is_milestone := display % MILESTONE_INTERVAL == 0
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
	elif _total_arm_plays(progress) >= UCB_BOOTSTRAP_RUNS:
		arm = _ucb_arm(levels, level_index, allowed_sizes, completed_ids, progress)
		mode = "ucb"
	else:
		arm = _rule_arm(display, allowed_sizes, rng)
		mode = "rule"

	var selected_size := int(arm.get("size", allowed_sizes[0]))
	var selected_difficulty := str(arm.get("difficulty", "simple"))
	var index := _choose_level_index(levels, level_index, selected_size, selected_difficulty, completed_ids, recent_ids, rng)
	if index < 0:
		index = _choose_any_level_index(levels, level_index, allowed_sizes, completed_ids, recent_ids, rng)
	if index < 0:
		index = clampi(display - 1, 0, levels.size() - 1)

	var level: Dictionary = levels[index]
	return _make_schedule(
		level,
		index,
		display,
		mode,
		is_milestone,
		allowed_sizes,
		int(level.get("rows", selected_size)),
		str(level.get("difficulty", selected_difficulty))
	)


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
		display % MILESTONE_INTERVAL == 0,
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
		display % MILESTONE_INTERVAL == 0,
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


static func unlocked_sizes(display_level: int) -> Array:
	var display := maxi(1, display_level)
	if display >= 450:
		return [6, 7, 8,9]
	if display >= 300:
		return [6, 7, 8]
	if display >= 180:
		return [5, 6, 7]
	if display >= 80:
		return [5, 6]
	if display >= 30:
		return [5]
	return [5]


static func record_completion(progress: Dictionary, level: Dictionary, schedule: Dictionary, elapsed_seconds: float, moves: int, hints: int, completed_date: String = "", completed_unix: int = 0) -> void:
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
	stats["rewardTotal"] = float(stats.get("rewardTotal", 0.0)) + reward
	progress["statsByArm"][arm_key] = stats

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
		"reward": reward,
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
		if completed_date != "" and completed_date != today and completed_unix > 0 and age_seconds >= 0 and age_seconds < RETENTION_WINDOW_SECONDS:
			_add_reward_bonus(progress, run, RETENTION_BONUS, "retainedNextDay")


static func _make_schedule(level: Dictionary, index: int, display: int, mode: String, is_milestone: bool, allowed_sizes: Array, selected_size: int, selected_difficulty: String) -> Dictionary:
	var assembly_enabled := is_milestone and selected_size >= 6
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
		"kingPositions": [] if assembly_enabled else _opening_king_positions(level, display, index, mode == "fixed")
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
		return 1 if roll < 0.7 else 2
	if size == 7:
		if roll < 0.5:
			return 1
		return 2 if roll < 0.9 else 3
	if roll < 0.3:
		return 1
	return 2 if roll < 0.7 else 3


static func _should_reveal_dynamic_kings(display: int) -> bool:
	if display <= FIXED_OPENING_COUNT:
		return false
	if display <= 50:
		return true
	return display % 5 != 0


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


static func _ucb_arm(levels: Array, level_index: Dictionary, allowed_sizes: Array, completed_ids: Array, progress: Dictionary) -> Dictionary:
	var total_plays := maxi(1, _total_arm_plays(progress))
	var best_score := -INF
	var best_arm := {"size": int(allowed_sizes[0]), "difficulty": "simple"}
	for size in allowed_sizes:
		for difficulty in DIFFICULTY_ORDER:
			if _candidate_indices(levels, level_index, [int(size)], [difficulty], completed_ids, [], true, true).is_empty():
				continue
			var stats: Dictionary = progress["statsByArm"].get(_arm_key(int(size), difficulty), {})
			var plays := int(stats.get("plays", 0))
			var average_reward := 0.0
			if plays > 0:
				average_reward = float(stats.get("rewardTotal", 0.0)) / float(plays)
			else:
				average_reward = 0.72
			var exploration := sqrt(log(float(total_plays + 1)) / float(maxi(1, plays)))
			var cold_start_bonus := 0.18 if plays == 0 else 0.0
			var score := average_reward + UCB_EXPLORATION * exploration + cold_start_bonus
			if score > best_score:
				best_score = score
				best_arm = {"size": int(size), "difficulty": difficulty}
	return best_arm


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
	return bool(run.get("isMilestoneChallenge", false)) or int(run.get("displayLevel", 0)) % MILESTONE_INTERVAL == 0


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
