extends RefCounted

const CoinRewardPolicyScript = preload("res://scripts/coin_reward_policy.gd")
const CompositeCoinPolicyScript = preload("res://scripts/composite_coin_policy.gd")
const CompositeLevelDirectorScript = preload("res://scripts/composite_level_director.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")


static func formal_completion(display_level: int, heart_limit: int, remaining_hearts: int) -> Dictionary:
	return {
		"reward": CoinRewardPolicyScript.completion_reward(display_level, heart_limit, remaining_hearts),
		"excellent": CoinRewardPolicyScript.is_excellent_completion(heart_limit, remaining_hearts)
	}



static func composite_completion(active_schedule: Dictionary, heart_limit: int, remaining_hearts: int) -> Dictionary:
	var excellent := CoinRewardPolicyScript.is_excellent_completion(heart_limit, remaining_hearts)
	return {
		"reward": CompositeCoinPolicyScript.completion_reward(excellent),
		"excellent": excellent,
		"entryCost": int(active_schedule.get("compositeEntryCost", 0)),
		"paidEntry": bool(active_schedule.get("compositePaidEntry", false))
	}


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
			int(run_context.get("directFindCount", 0))
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
