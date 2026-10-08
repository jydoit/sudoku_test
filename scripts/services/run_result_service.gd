extends RefCounted

const CoinRewardPolicyScript = preload("res://scripts/coin_reward_policy.gd")
const CompositeCoinPolicyScript = preload("res://scripts/composite_coin_policy.gd")
const CompositeLevelDirectorScript = preload("res://scripts/composite_level_director.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")


static func formal_completion(display_level: int, heart_limit: int, remaining_hearts: int, accuracy: Dictionary = {}) -> Dictionary:
	return {
		"reward": CoinRewardPolicyScript.completion_reward(display_level, heart_limit, remaining_hearts, accuracy),
		"excellent": CoinRewardPolicyScript.is_excellent_completion(heart_limit, remaining_hearts, accuracy)
	}



static func composite_completion(active_schedule: Dictionary, _heart_limit: int, remaining_hearts: int, accuracy: Dictionary = {}) -> Dictionary:
	var excellent := CompositeCoinPolicyScript.is_excellent_completion(remaining_hearts, accuracy)
	var entry_cost := maxi(0, int(active_schedule.get("compositeEntryCost", 0)))
	var paid_entry := bool(active_schedule.get("compositePaidEntry", false))
	return {
		"reward": CompositeCoinPolicyScript.completion_reward(excellent, entry_cost, paid_entry) if remaining_hearts > 0 else 0,
		"excellent": excellent,
		"entryCost": entry_cost,
		"paidEntry": paid_entry
	}


static func save_coin_settlement(schedule: Dictionary, result: Dictionary, transaction: Dictionary) -> void:
	var receipt := result.duplicate(true)
	receipt["version"] = 1
	receipt["balanceBefore"] = int(transaction["balanceBefore"])
	receipt["balanceAfter"] = int(transaction["balanceAfter"])
	schedule["coinSettlement"] = receipt


static func record_formal(
	completed: bool,
	progress: Dictionary,
	level: Dictionary,
	schedule: Dictionary,
	run_context: Dictionary
) -> void:
	var completed_unix := int(run_context.get("finishedUnix", Time.get_unix_time_from_system()))
	var elapsed := maxf(1.0, float(completed_unix - int(run_context.get("startedUnix", completed_unix))))
	if completed:
		LevelDirectorScript.record_completion(
			progress, level, schedule, elapsed,
			int(run_context.get("moveCount", 0)),
			int(run_context.get("hintCount", 0)),
			str(run_context.get("today", "")),
			completed_unix,
			int(run_context.get("directFindCount", 0)),
			run_context.get("lostLife")
		)
	else:
		LevelDirectorScript.record_failure(
			progress, level, schedule, elapsed,
			int(run_context.get("moveCount", 0)),
			int(run_context.get("hintCount", 0)),
			str(run_context.get("today", "")),
			completed_unix,
			int(run_context.get("directFindCount", 0))
		)


static func record_composite(
	progress: Dictionary,
	level: Dictionary,
	schedule: Dictionary,
	completed: bool,
	run_context: Dictionary
) -> void:
	var completed_unix := int(run_context.get("finishedUnix", Time.get_unix_time_from_system()))
	var elapsed := maxf(1.0, float(completed_unix - int(run_context.get("startedUnix", completed_unix))))
	CompositeLevelDirectorScript.record_result(
		progress,
		level,
		schedule,
		completed,
		elapsed,
		int(run_context.get("moveCount", 0)),
		int(run_context.get("hintCount", 0)),
		str(run_context.get("today", "")),
		completed_unix,
		int(run_context.get("directFindCount", 0))
	)
