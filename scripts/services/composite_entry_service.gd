extends RefCounted

const CompositeCoinPolicyScript = preload("res://scripts/composite_coin_policy.gd")
const CompositeLevelDirectorScript = preload("res://scripts/composite_level_director.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")


static func quote(round_number: int, progress: Dictionary, today: String) -> Dictionary:
	return CompositeCoinPolicyScript.round_quote(maxi(1, round_number), progress, today)


static func can_afford(round_quote: Dictionary, coin_balance: int) -> bool:
	return not bool(round_quote.get("paid", false)) or coin_balance >= int(round_quote.get("entryCost", 0))


static func schedule_with_quote(raw_schedule: Dictionary, round_quote: Dictionary) -> Dictionary:
	var schedule := raw_schedule.duplicate(true)
	schedule["compositeCoinGoodReward"] = int(round_quote.get("goodReward", CompositeCoinPolicyScript.GOOD_COMPLETION_REWARD))
	schedule["compositeCoinExcellentReward"] = int(round_quote.get("excellentReward", CompositeCoinPolicyScript.EXCELLENT_COMPLETION_REWARD))
	schedule["compositeEntryCost"] = int(round_quote.get("entryCost", 0))
	schedule["compositePaidEntry"] = bool(round_quote.get("paid", false))
	return schedule


static func apply_entry(round_quote: Dictionary, wallet, progress: Dictionary, today: String) -> Dictionary:
	var transaction := {
		"success": true,
		"amount": 0,
		"balanceBefore": int(wallet.balance),
		"balanceAfter": int(wallet.balance),
		"reason": "composite_entry"
	}
	if bool(round_quote.get("paid", false)):
		transaction = wallet.spend(int(round_quote.get("entryCost", 0)), "composite_entry")
		if not bool(transaction.get("success", false)):
			return transaction
	CompositeCoinPolicyScript.record_round_started(progress, today, round_quote)
	return transaction


static func unlock_display_level() -> int:
	return LevelDirectorScript.minimum_display_for_size(CompositeLevelDirectorScript.MIN_BOARD_SIZE)


static func is_unlocked(formal_display_level: int) -> bool:
	return LevelDirectorScript.is_size_unlocked(
		CompositeLevelDirectorScript.MIN_BOARD_SIZE,
		maxi(1, formal_display_level)
	)
