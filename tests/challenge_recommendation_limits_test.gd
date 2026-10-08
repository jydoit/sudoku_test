extends SceneTree

## Pure scheduler regression: runtime catalog only, no main scene or user save I/O.
const Director = preload("res://scripts/level_director.gd")
const Store = preload("res://scripts/level_store.gd")
const DIFFICULTIES := ["simple", "medium", "hard", "challenge"]
var _checks := 0
var _failures := 0
var _levels: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(message)


func _run() -> void:
	_levels = Store.load_levels()
	_expect(not _levels.is_empty(), "The shipping binary level catalog must load")
	if _levels.is_empty():
		quit(1)
		return
	_test_fixed_opening()
	_test_size_quota_and_optional_challenges()
	_test_priority_layers()
	_test_unlock_boundaries()
	_test_sparse_catalog_and_exhaustion()
	_test_difficulty_cap()
	_test_permanent_played_history()
	_test_upgrade_direction_fallbacks()
	_test_pending_challenge_lifecycle()
	_test_read_only_scheduling()
	_test_recovery_after_corrected_challenge()
	print("CHALLENGE RECOMMENDATION LIMITS: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _stats(plays_five: int = 12, plays_six: int = 12) -> Dictionary:
	var stats := {}
	for size in [5, 6, 7, 8, 9]:
		for difficulty in DIFFICULTIES:
			stats["%d|%s" % [size, difficulty]] = {"plays": plays_five if size == 5 else plays_six}
	return stats


func _progress(stats: Dictionary, runs: Array = []) -> Dictionary:
	return {"statsByArm": stats, "recentRuns": runs, "completedLevelIds": []}


func _run_record(size: int, difficulty: String, salt: int = 0) -> Dictionary:
	return {
		"displayLevel": 39, "levelId": 100000 + salt, "size": size,
		"difficulty": difficulty, "moves": 14 + salt, "hints": 1,
		"toolUses": 1, "elapsedSeconds": 40.0, "isMilestoneChallenge": false
	}


func _check_pool(levels: Array, display: int, progress: Dictionary, label: String) -> Dictionary:
	var expected_progress := Director.normalize_progress(progress.duplicate(true))
	var context: Dictionary = Director._recommendation_context(
		Director.build_level_index(levels), Director.unlocked_sizes(display), expected_progress
	)
	var schedule: Dictionary = Director.schedule_for_display_level(levels, display, progress.duplicate(true))
	var arms: Array = context["arms"]
	if arms.is_empty():
		_expect(schedule.is_empty(), label + ": no eligible arm must not fall back outside the pool")
		return schedule
	_expect(not schedule.is_empty(), label + ": a legal candidate must produce a schedule")
	if schedule.is_empty():
		return schedule
	var selected := {"size": int(schedule["selectedSize"]), "difficulty": str(schedule["selectedDifficulty"])}
	_expect(arms.has(selected), label + ": selected pair must belong to the current recommendation pool")
	_expect(schedule.get("recommendableArms", []) == arms, label + ": diagnostics must report the same ordinary recommendation pool")
	_expect(str(schedule.get("recommendationConstraint", "")) == str(context["reason"]), label + ": candidate-priority diagnostics must match")
	var actual: Dictionary = levels[int(schedule["levelIndex"])]
	_expect(int(actual["rows"]) == int(selected["size"]) and str(actual["difficulty"]) == str(selected["difficulty"]), label + ": actual level must match the selected pair")
	_expect(Director.unlocked_sizes(display).has(int(actual["rows"])), label + ": selected size must be unlocked")
	_expect(not schedule.has("assemblyEnabled"), label + ": ordinary milestones must not enable block gameplay")
	if Director.is_challenge_display(display, progress) or bool(progress.get("pendingChallenge", false)):
		var fresh_arms := _fresh_arms(levels, arms, expected_progress["playedLevelIds"])
		_expect(schedule.get("challengeEligibleArms", []) == fresh_arms, label + ": challenge diagnostics must remove exhausted arms without enlarging the ordinary pool")
		if fresh_arms.is_empty():
			_expect(not bool(schedule["isMilestoneChallenge"]) and str(schedule["mode"]) != "challenge", label + ": exhausted challenge pool must produce an ordinary level")
			_expect(bool(schedule.get("challengeDeferred", false)), label + ": exhausted challenge pool must defer its challenge")
		else:
			_expect(bool(schedule["isMilestoneChallenge"]) and str(schedule["mode"]) == "challenge", label + ": challenge identity must remain intact")
			_expect(not bool(schedule.get("challengeDeferred", false)), label + ": a fresh challenge must not be deferred")
			_expect(fresh_arms.has(selected), label + ": challenge selection must belong to the fresh legal arms")
			_expect(not expected_progress["playedLevelIds"].has(int(schedule["levelId"])), label + ": a challenge must never recommend a started, failed, exited or completed level again")
			_expect(schedule.get("kingPositions", []).is_empty(), label + ": challenges must not reveal opening lions")
	return schedule


func _fresh_arms(levels: Array, arms: Array, played_ids: Array) -> Array:
	var result: Array = []
	for arm in arms:
		for level in levels:
			if int(level["rows"]) == int(arm["size"]) and str(level["difficulty"]) == str(arm["difficulty"]) and not played_ids.has(int(level["levelId"])):
				result.append(arm)
				break
	return result


func _test_fixed_opening() -> void:
	var expected := ["simple", "simple", "simple", "simple", "simple", "medium", "medium", "medium", "simple", "hard"]
	for display in range(1, 11):
		var schedule: Dictionary = Director.schedule_for_display_level(_levels, display, {})
		_expect(int(schedule["selectedSize"]) == 5 and str(schedule["selectedDifficulty"]) == expected[display - 1], "Opening %d must keep its fixed size and difficulty" % display)
		_expect(str(schedule["mode"]) == "fixed", "Opening %d must keep its fixed scheduling mode" % display)
	var first_challenge: Dictionary = Director.schedule_for_display_level(_levels, 10, {})
	_expect(int(first_challenge["levelId"]) == 7, "A new account must retain the authored first hard challenge")
	var played_opening := {"playedLevelIds": [int(first_challenge["levelId"])]}
	var replacement: Dictionary = Director.schedule_for_display_level(_levels, 10, played_opening)
	_expect(bool(replacement["isMilestoneChallenge"]), "The fixed first challenge should find another unplayed hard level")
	_expect(int(replacement["levelId"]) != int(first_challenge["levelId"]), "The fixed first challenge must not repeat a previously started authored level")
	_expect(int(replacement["selectedSize"]) == 5 and str(replacement["selectedDifficulty"]) == "hard", "The fixed first challenge replacement must stay inside its authored 5x5 hard range")
	var one_hard := _subset(["5|hard"], true)
	var exhausted: Dictionary = Director.schedule_for_display_level(one_hard, 10, {"playedLevelIds": [int(one_hard[0]["levelId"])]})
	_expect(not bool(exhausted["isMilestoneChallenge"]) and bool(exhausted.get("challengeDeferred", false)), "An exhausted fixed first challenge must become ordinary and defer, never repeat as a challenge")


func _test_size_quota_and_optional_challenges() -> void:
	var optional_count := 0
	for salt in range(64):
		# The old milestone score preferred the hinted 5x5 challenge over 6x6.
		var old_small := _run_record(5, "challenge")
		old_small["elapsedSeconds"] = 227.0
		old_small["displayLevel"] = 30
		old_small["isMilestoneChallenge"] = true
		var recent_large := _run_record(6, "challenge", salt)
		recent_large["hints"] = 0
		recent_large["toolUses"] = 0
		recent_large["elapsedSeconds"] = 157.0
		recent_large["moves"] = 34
		var progress := _progress(_stats(12, 1), [old_small, recent_large])
		var schedule := _check_pool(_levels, 40, progress, "40/size quota/salt %d" % salt)
		_expect(int(schedule.get("selectedSize", 0)) == 6, "Level 40 must not escape the under-exposed 6x6 recommendation pool")
		if Director.is_challenge_display(35, progress):
			optional_count += 1
			var optional := _check_pool(_levels, 35, progress, "35/optional/salt %d" % salt)
			_expect(int(optional.get("selectedSize", 0)) == 6, "Optional challenges must share the same 6x6 quota restriction")
	_expect(optional_count > 0 and optional_count < 64, "Deterministic salts must exercise optional challenge successes and misses")


func _test_priority_layers() -> void:
	var cold_stats := _stats()
	for difficulty in DIFFICULTIES:
		cold_stats["6|" + difficulty] = {"plays": 0}
	var cold := _check_pool(_levels, 40, _progress(cold_stats, [_run_record(5, "challenge")]), "new size singleton")
	_expect(int(cold.get("selectedSize", 0)) == 6 and str(cold.get("selectedDifficulty", "")) == "medium", "A new-size medium-only pool must not be overridden by a hard-coded challenge floor")

	var recent_stats := _stats()
	recent_stats["6|hard"] = {"plays": 0}
	var recent_runs: Array = []
	for salt in range(3):
		var run := _run_record(6, "medium", salt)
		run["toolUses"] = 0
		run["hints"] = 0
		recent_runs.append(run)
	var recent := _check_pool(_levels, 40, _progress(recent_stats, recent_runs), "recent max size probe")
	_expect(int(recent.get("selectedSize", 0)) == 6 and str(recent.get("selectedDifficulty", "")) == "hard", "Recent max-size hard probe must remain binding on milestones")

	var unseen_stats := _stats()
	unseen_stats["5|medium"] = {"plays": 0}
	var unseen := _check_pool(_levels, 40, _progress(unseen_stats, [_run_record(6, "challenge")]), "unseen combo")
	_expect(int(unseen.get("selectedSize", 0)) == 5 and str(unseen.get("selectedDifficulty", "")) == "medium", "A legitimate smaller-board unseen combo must remain eligible; do not hard-code a 6x6 minimum")

	var combo_stats := _stats()
	combo_stats["6|hard"] = {"plays": 2}
	var combo := _check_pool(_levels, 40, _progress(combo_stats, [_run_record(5, "challenge")]), "combo exposure quota")
	_expect(int(combo.get("selectedSize", 0)) == 6 and str(combo.get("selectedDifficulty", "")) == "hard", "Combination exposure quotas must remain binding on milestones")


func _test_unlock_boundaries() -> void:
	for display in [20, 30, 40, 70, 80, 150, 160, 230, 240]:
		_check_pool(_levels, display, _progress(_stats()), "unlock boundary %d" % display)
		_check_pool(_levels, display, {}, "cold unlock boundary %d" % display)


func _subset(pairs: Array, one_per_pair: bool = false) -> Array:
	var result: Array = []
	var added: Array = []
	for level in _levels:
		var pair := "%d|%s" % [int(level["rows"]), str(level["difficulty"])]
		if pairs.has(pair) and (not one_per_pair or not added.has(pair)):
			result.append(level)
			added.append(pair)
	return result


func _test_sparse_catalog_and_exhaustion() -> void:
	var sparse := _subset(["5|hard", "5|challenge", "6|challenge"])
	var progress := _progress(_stats(12, 1), [_run_record(5, "challenge")])
	var schedule := _check_pool(sparse, 40, progress, "missing 6x6 hard bucket")
	_expect(int(schedule.get("selectedSize", 0)) == 6 and str(schedule.get("selectedDifficulty", "")) == "challenge", "A missing hard bucket must not send a milestone outside the legal 6x6 pool")

	var only_ineligible := _subset(["5|simple", "7|hard"])
	var no_tool_runs: Array = []
	for salt in range(6):
		var run := _run_record(5, "medium", salt)
		run["toolUses"] = 0
		run["hints"] = 0
		no_tool_runs.append(run)
	_check_pool(only_ineligible, 40, _progress(_stats(), no_tool_runs), "empty pool with hard floor and locked 7x7")

	var exhausted := _subset(["5|hard", "6|challenge"], true)
	var repeated_progress := _progress(_stats(12, 1))
	for level in exhausted:
		var id := int(level["levelId"])
		repeated_progress["completedLevelIds"].append(id)
		var run := _run_record(int(level["rows"]), str(level["difficulty"]))
		run["levelId"] = id
		repeated_progress["recentRuns"].append(run)
	var repeated := _check_pool(exhausted, 40, repeated_progress, "dedupe exhaustion")
	_expect(int(repeated.get("selectedSize", 0)) == 6 and str(repeated.get("selectedDifficulty", "")) == "challenge", "An exhausted pool may repeat as an ordinary level only inside the eligible pair")
	_expect(not bool(repeated.get("isMilestoneChallenge", true)), "Dedupe exhaustion must never silently repeat a challenge")
	var ordinary: Dictionary = Director.schedule_for_display_level(exhausted, 42, repeated_progress)
	_expect(not ordinary.is_empty() and not bool(ordinary["isMilestoneChallenge"]), "Ordinary recommendations retain their existing exhausted-pool repeat fallback")


func _test_difficulty_cap() -> void:
	var levels := _subset(["5|challenge", "6|challenge", "7|challenge"])
	for salt in range(16):
		var progress := _progress(_stats(), [_run_record(5, "challenge", salt)])
		var schedule := _check_pool(levels, 40, progress, "difficulty cap %d" % salt)
		_expect(int(schedule.get("selectedSize", 0)) == 6, "Difficulty cap must try an available size upgrade, without reaching locked 7x7")
	var size_locked_pool := _subset(["5|challenge", "7|challenge"])
	var fallback := _check_pool(size_locked_pool, 40, _progress(_stats(), [_run_record(5, "challenge")]), "difficulty and eligible size capped")
	_expect(int(fallback.get("selectedSize", 0)) == 5, "A fully capped pool must remain valid without inventing an unavailable larger pair")


func _test_permanent_played_history() -> void:
	var migration := {
		"playedLevelIds": [700001, "700001", 700002.0, "invalid", -4, 0, {}],
		"completedLevelIds": [700003.0],
		"recentRuns": [{"levelId": 700004, "completed": false}, {"levelId": 700005, "completed": true}]
	}
	Director.normalize_progress(migration)
	_expect(migration["playedLevelIds"].size() == 5, "Migration must merge valid started, completed and failed identifiers without duplicates or invalid IDs")
	for id in range(700001, 700006):
		_expect(migration["playedLevelIds"].has(id), "Migration must preserve historical level %d" % id)
	var restored: Dictionary = Director.normalize_progress(JSON.parse_string(JSON.stringify(migration)))
	_expect(restored["playedLevelIds"] == migration["playedLevelIds"], "JSON number conversion must preserve canonical permanent played IDs")

	var hard_levels := _subset(["5|hard"])
	var progress := Director.normalize_progress(_progress(_stats()))
	var exited_id := int(hard_levels[0]["levelId"])
	var failed_id := int(hard_levels[1]["levelId"])
	_expect(Director.record_level_started(progress, exited_id, {"mode": "rule"}), "Entering a level must immediately register it even if the user exits before an outcome")
	_expect(not Director.record_level_started(progress, exited_id, {"mode": "rule"}), "Restarting or restoring the same level must be idempotent")
	_expect(not Director.record_level_started(progress, -1, {"mode": "rule"}), "Invalid level IDs must not enter the permanent ledger")
	for index in range(1, 47):
		Director.record_failure(progress, hard_levels[index], {"displayLevel": 11 + index, "mode": "rule", "isMilestoneChallenge": false}, 35.0, 15, 1)
	_expect(progress["recentRuns"].size() == Director.MAX_RUN_HISTORY, "Test must advance beyond the bounded recent-run history")
	var recent_ids: Array = []
	for run in progress["recentRuns"]:
		recent_ids.append(int(run["levelId"]))
	_expect(not recent_ids.has(failed_id), "The old failed fixture must have left recent history")
	_expect(progress["playedLevelIds"].has(exited_id) and progress["playedLevelIds"].has(failed_id), "Exited and failed levels must remain permanently excluded after recent history rolls over")
	_expect(not progress["completedLevelIds"].has(exited_id) and not progress["completedLevelIds"].has(failed_id), "Exclusion must not rely on completion records")
	var selective_catalog: Array = [hard_levels[0], hard_levels[1], hard_levels[47]]
	var next := _check_pool(selective_catalog, 40, progress, "permanent failures and exits")
	_expect(int(next.get("levelId", -1)) == int(hard_levels[47]["levelId"]), "The only fresh candidate must win over exited and expired-history failed candidates")


func _test_upgrade_direction_fallbacks() -> void:
	for base_difficulty in ["medium", "hard"]:
		var up_difficulty := "hard" if base_difficulty == "medium" else "challenge"
		var pairs := ["5|" + base_difficulty, "5|" + up_difficulty, "6|" + base_difficulty]
		var catalog := _subset(pairs, true)
		var difficulty_id := -1
		var size_id := -1
		for level in catalog:
			if int(level["rows"]) == 6:
				size_id = int(level["levelId"])
			elif str(level["difficulty"]) == up_difficulty:
				difficulty_id = int(level["levelId"])
		var saw_size_upgrade := false
		var saw_difficulty_upgrade := false
		for salt in range(24):
			var progress := _progress(_stats(), [_run_record(5, base_difficulty, salt)])
			var baseline := _check_pool(catalog, 40, progress, "upgrade directions/%s/%d" % [base_difficulty, salt])
			saw_size_upgrade = saw_size_upgrade or int(baseline.get("selectedSize", 0)) == 6
			saw_difficulty_upgrade = saw_difficulty_upgrade or str(baseline.get("selectedDifficulty", "")) == up_difficulty
			var difficulty_exhausted := progress.duplicate(true)
			difficulty_exhausted["playedLevelIds"] = [difficulty_id]
			var size_upgrade := _check_pool(catalog, 40, difficulty_exhausted, "difficulty direction exhausted/%s/%d" % [base_difficulty, salt])
			_expect(int(size_upgrade.get("levelId", -1)) == size_id, "An exhausted same-size difficulty upgrade must switch to the legal fresh size upgrade")
			var size_exhausted := progress.duplicate(true)
			size_exhausted["playedLevelIds"] = [size_id]
			var difficulty_upgrade := _check_pool(catalog, 40, size_exhausted, "size direction exhausted/%s/%d" % [base_difficulty, salt])
			_expect(int(difficulty_upgrade.get("levelId", -1)) == difficulty_id, "An exhausted size upgrade must switch to the legal fresh difficulty upgrade")
		_expect(saw_size_upgrade and saw_difficulty_upgrade, "Both weighted upgrade directions must remain reachable for " + base_difficulty)
	var ceiling_catalog := _subset(["5|simple", "5|challenge"], true)
	var ceiling := _check_pool(ceiling_catalog, 40, _progress(_stats(), [_run_record(5, "simple")]), "sparse same-size upgrade")
	_expect(str(ceiling.get("selectedDifficulty", "")) == "challenge" and str(ceiling.get("challengeStrategy", "")) == "difficulty_up", "A missing intermediate difficulty must not block a legal same-size challenge upgrade")
	var size_chain := _subset(["5|hard", "6|hard", "7|hard"], true)
	for salt in range(16):
		var progress := _progress(_stats(), [_run_record(5, "hard", salt)])
		progress["playedLevelIds"] = [int(size_chain[0]["levelId"])]
		var one_step := _check_pool(size_chain, 80, progress, "exhausted baseline must not skip size/%d" % salt)
		_expect(int(one_step.get("selectedSize", 0)) == 6 and str(one_step.get("challengeStrategy", "")) == "size_up", "Filtering the old 5x5 bucket must preserve its historical baseline and upgrade one legal size, not jump to 7x7")
	var fallback_catalog := _subset(["5|simple", "5|hard", "6|challenge", "7|challenge"], true)
	var fallback_progress := _progress(_stats(), [_run_record(5, "hard")])
	for level in fallback_catalog:
		if int(level["rows"]) == 5 and str(level["difficulty"]) == "hard":
			fallback_progress["playedLevelIds"] = [int(level["levelId"])]
	var hardest := _check_pool(fallback_catalog, 80, fallback_progress, "both upgrade directions unavailable")
	_expect(int(hardest.get("selectedSize", 0)) == 7 and str(hardest.get("selectedDifficulty", "")) == "challenge", "With neither upgrade direction executable, choose the hardest fresh pair and then the larger size on a tie")
	_expect(str(hardest.get("challengeStrategy", "")) == "pool_ceiling", "Exhausted upgrade directions must be explicitly diagnosed as a pool-ceiling fallback")


func _test_pending_challenge_lifecycle() -> void:
	# 6x6 is still an unexposed-medium-only probe; the fresh 5x5 hard is out of range.
	var catalog := _subset(["5|hard", "6|medium"], true)
	var progress := _progress(_stats(), [_run_record(5, "hard")])
	progress["statsByArm"]["6|medium"] = {"plays": 0}
	var medium_id := -1
	for level in catalog:
		if int(level["rows"]) == 6:
			medium_id = int(level["levelId"])
	progress["playedLevelIds"] = [medium_id]
	Director.normalize_progress(progress)
	var deferred := _check_pool(catalog, 40, progress, "defer rather than use fresh out-of-pool level")
	_expect(int(deferred.get("levelId", -1)) == medium_id, "The temporary ordinary level must obey the same singleton recommendation pool")
	_expect(not bool(progress["pendingChallenge"]), "Previewing a deferred level must not enqueue a challenge before entry")
	Director.record_level_started(progress, medium_id, deferred)
	_expect(bool(progress["pendingChallenge"]), "Entering the ordinary replacement must persist its pending challenge")
	var restored: Dictionary = Director.normalize_progress(JSON.parse_string(JSON.stringify(progress)))
	_expect(bool(restored["pendingChallenge"]), "A pending challenge must survive a save/load JSON round trip")
	var again := _check_pool(catalog, 41, restored, "pending remains exhausted on ordinary display")
	_expect(bool(again.get("challengeDeferred", false)), "A still-exhausted pending challenge must remain deferred on a non-milestone display")
	_expect(bool(restored["pendingChallenge"]), "Scheduling alone must not clear pending state")
	Director.record_level_started(restored, int(again["levelId"]), again)
	_expect(bool(restored["pendingChallenge"]), "Entering another exhausted ordinary replacement must retain pending state")
	# A fresh level becomes available in the same allowed pair, without expanding the pool.
	var expanded_catalog := _subset(["5|hard", "6|medium"])
	var retried := _check_pool(expanded_catalog, 42, restored, "pending retry outside modulo interval")
	_expect(bool(retried.get("isMilestoneChallenge", false)), "A deferred challenge must retry when a fresh legal level becomes available, including display 42")
	_expect(int(retried.get("selectedSize", 0)) == 6 and str(retried.get("selectedDifficulty", "")) == "medium", "A pending retry must not force hard outside the current medium-only pool")
	_expect(bool(restored["pendingChallenge"]), "Previewing a valid retry must not consume pending state")
	Director.record_level_started(restored, int(retried["levelId"]), retried)
	_expect(not bool(restored["pendingChallenge"]), "Only entering a real challenge should consume pending state")
	var clean_restored: Dictionary = Director.normalize_progress(JSON.parse_string(JSON.stringify(restored)))
	_expect(not bool(clean_restored["pendingChallenge"]) and clean_restored["playedLevelIds"].has(int(retried["levelId"])), "Both pending consumption and permanent played ID must survive persistence")
	var resume_schedule: Dictionary = JSON.parse_string(JSON.stringify(retried))
	var count_before: int = clean_restored["playedLevelIds"].size()
	_expect(not Director.record_level_started(clean_restored, int(resume_schedule["levelId"]), resume_schedule), "Retry/resume of the same challenge must not consume or add another recommendation")
	_expect(clean_restored["playedLevelIds"].size() == count_before, "Retry/resume must keep a single permanent played entry")


func _test_read_only_scheduling() -> void:
	var progress := Director.normalize_progress(_progress(_stats(), [_run_record(5, "hard")]))
	progress["pendingChallenge"] = true
	var original_played: Array = progress["playedLevelIds"].duplicate()
	var first: Dictionary = Director.schedule_for_display_level(_levels, 42, progress)
	var second: Dictionary = Director.schedule_for_display_level(_levels, 42, progress)
	_expect(first == second, "Repeated candidate queries must be deterministic and must not reserve their selected level")
	_expect(progress["playedLevelIds"] == original_played and bool(progress["pendingChallenge"]), "Read-only scheduling must neither mark the proposed level as played nor consume pending state")
	_expect(not original_played.has(int(first["levelId"])), "Read-only fixture must actually propose a fresh challenge")
	Director.record_level_started(progress, int(first["levelId"]), first)
	_expect(progress["playedLevelIds"].has(int(first["levelId"])) and not bool(progress["pendingChallenge"]), "Entering the proposal must mark played and consume pending atomically")


func _test_recovery_after_corrected_challenge() -> void:
	var progress := _progress(_stats(12, 1), [_run_record(5, "challenge")])
	var milestone: Dictionary = Director.schedule_for_display_level(_levels, 40, progress)
	if milestone.is_empty():
		_expect(false, "Recovery fixture requires a legal milestone")
		return
	Director.record_completion(progress, _levels[int(milestone["levelIndex"])], milestone, 60.0, 24, 1)
	var recovery: Dictionary = Director.schedule_for_display_level(_levels, 41, progress)
	_expect(str(recovery.get("mode", "")) == "post_challenge", "The next level must retain its recovery branch")
	_expect(int(recovery.get("selectedSize", 0)) == 6, "Recovery must follow the corrected challenge's actual 6x6 size")
	_expect(recovery.get("kingPositions", []).size() in [0, 1], "6x6 recovery must obey the zero/one opening hint limit")
