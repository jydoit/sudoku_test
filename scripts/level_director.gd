class_name LevelDirector
extends RefCounted

const FIXED_OPENING_COUNT := 10
const RECENT_WINDOW := 5
const MAX_RUN_HISTORY := 40
const MILESTONE_INTERVAL := 10
const UCB_BOOTSTRAP_RUNS := 18
const UCB_EXPLORATION := 0.72
const KING_SOLUTION_ORDINALS := [2, 4, 6, 8]
const DIFFICULTY_ORDER := ["simple", "medium", "hard", "challenge"]


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

	if display <= FIXED_OPENING_COUNT:
		var fixed_index := clampi(display - 1, 0, levels.size() - 1)
		return manual_schedule_for_level(levels, fixed_index, display, "fixed")

	var allowed_sizes := unlocked_sizes(display)
	var is_milestone := display % MILESTONE_INTERVAL == 0
	var rng := _make_rng(display, "schedule:%d" % _progress_signature(progress))
	var completed_ids := _completed_ids(progress)
	var arm := {}
	var mode := "rule"

	if is_milestone:
		arm = _milestone_arm(progress, allowed_sizes)
		mode = "challenge"
	elif _total_arm_plays(progress) >= UCB_BOOTSTRAP_RUNS:
		arm = _ucb_arm(levels, allowed_sizes, completed_ids, progress)
		mode = "ucb"
	else:
		arm = _rule_arm(display, allowed_sizes, rng)
		mode = "rule"

	var selected_size := int(arm.get("size", allowed_sizes[0]))
	var selected_difficulty := str(arm.get("difficulty", "simple"))
	var index := _choose_level_index(levels, selected_size, selected_difficulty, completed_ids, progress, rng)
	if index < 0:
		index = _choose_any_level_index(levels, allowed_sizes, completed_ids, progress, rng)
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


static func unlocked_sizes(display_level: int) -> Array:
	var display := maxi(1, display_level)
	if display >= 40:
		return [5, 6, 7, 8, 9]
	if display >= 20:
		return [5, 6, 7, 8]
	if display >= 10:
		return [5, 6]
	return [5]


static func record_completion(progress: Dictionary, level: Dictionary, schedule: Dictionary, elapsed_seconds: float, moves: int, hints: int) -> void:
	normalize_progress(progress)
	var size := int(level.get("rows", schedule.get("selectedSize", 0)))
	var difficulty := str(level.get("difficulty", schedule.get("selectedDifficulty", "normal")))
	var arm_key := _arm_key(size, difficulty)
	var stats: Dictionary = progress["statsByArm"].get(arm_key, {})
	var plays := int(stats.get("plays", 0)) + 1
	var wins := int(stats.get("wins", 0)) + 1
	var reward := _completion_reward(size, difficulty, elapsed_seconds, moves, hints)
	stats["plays"] = plays
	stats["wins"] = wins
	stats["elapsedTotal"] = float(stats.get("elapsedTotal", 0.0)) + elapsed_seconds
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
		"elapsedSeconds": elapsed_seconds,
		"moves": moves,
		"hints": hints,
		"reward": reward
	})
	while runs.size() > MAX_RUN_HISTORY:
		runs.pop_front()


static func _make_schedule(level: Dictionary, index: int, display: int, mode: String, is_milestone: bool, allowed_sizes: Array, selected_size: int, selected_difficulty: String) -> Dictionary:
	return {
		"displayLevel": display,
		"levelIndex": index,
		"levelId": int(level.get("levelId", -1)),
		"mode": mode,
		"isMilestoneChallenge": is_milestone,
		"allowedSizes": allowed_sizes.duplicate(),
		"selectedSize": selected_size,
		"selectedDifficulty": selected_difficulty,
		"kingPositions": _opening_king_positions(level, display, index, mode == "fixed")
	}


static func _opening_king_positions(level: Dictionary, display: int, level_index: int, is_fixed: bool) -> Array:
	if is_fixed:
		if display <= 9 and level.has("kingPosition"):
			var fixed = level.get("kingPosition", [])
			if fixed is Array and fixed.size() >= 2:
				return [[int(fixed[0]), int(fixed[1])]]
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
	var count := mini(candidates.size(), rng.randi_range(1, 3))
	var available := candidates.duplicate(true)
	var result: Array = []
	while result.size() < count and not available.is_empty():
		var pick := rng.randi_range(0, available.size() - 1)
		result.append(available[pick])
		available.remove_at(pick)
	return result


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


static func _ucb_arm(levels: Array, allowed_sizes: Array, completed_ids: Array, progress: Dictionary) -> Dictionary:
	var total_plays := maxi(1, _total_arm_plays(progress))
	var best_score := -INF
	var best_arm := {"size": int(allowed_sizes[0]), "difficulty": "simple"}
	for size in allowed_sizes:
		for difficulty in DIFFICULTY_ORDER:
			if _candidate_indices(levels, [int(size)], [difficulty], completed_ids, true).is_empty():
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


static func _milestone_arm(progress: Dictionary, allowed_sizes: Array) -> Dictionary:
	var recent := _last_runs(progress, RECENT_WINDOW)
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
	return {"size": size, "difficulty": str(best.get("difficulty", "hard"))}


static func _choose_level_index(levels: Array, size: int, difficulty: String, completed_ids: Array, progress: Dictionary, rng: RandomNumberGenerator) -> int:
	var candidates := _candidate_indices(levels, [size], [difficulty], completed_ids, false)
	candidates = _prefer_not_recent(candidates, levels, progress)
	if candidates.is_empty():
		candidates = _candidate_indices(levels, [size], [difficulty], completed_ids, true)
	if candidates.is_empty():
		return -1
	return int(candidates[rng.randi_range(0, candidates.size() - 1)])


static func _choose_any_level_index(levels: Array, allowed_sizes: Array, completed_ids: Array, progress: Dictionary, rng: RandomNumberGenerator) -> int:
	var candidates := _candidate_indices(levels, allowed_sizes, DIFFICULTY_ORDER, completed_ids, false)
	candidates = _prefer_not_recent(candidates, levels, progress)
	if candidates.is_empty():
		candidates = _candidate_indices(levels, allowed_sizes, DIFFICULTY_ORDER, completed_ids, true)
	if candidates.is_empty():
		return -1
	return int(candidates[rng.randi_range(0, candidates.size() - 1)])


static func _candidate_indices(levels: Array, sizes: Array, difficulties: Array, completed_ids: Array, allow_completed: bool) -> Array:
	var result: Array = []
	for index in range(levels.size()):
		var level: Dictionary = levels[index]
		var level_id := int(level.get("levelId", -1))
		if not allow_completed and completed_ids.has(level_id):
			continue
		if not sizes.has(int(level.get("rows", 0))):
			continue
		if not difficulties.has(str(level.get("difficulty", "normal"))):
			continue
		result.append(index)
	return result


static func _prefer_not_recent(candidates: Array, levels: Array, progress: Dictionary) -> Array:
	if candidates.is_empty():
		return candidates
	var recent_ids := _recent_level_ids(progress)
	var filtered: Array = []
	for index in candidates:
		var level: Dictionary = levels[int(index)]
		if not recent_ids.has(int(level.get("levelId", -1))):
			filtered.append(index)
	return filtered if not filtered.is_empty() else candidates


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


static func _recent_level_ids(progress: Dictionary) -> Array:
	var result: Array = []
	for run in _last_runs(progress, RECENT_WINDOW):
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
