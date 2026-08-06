class_name CompositeCoinPolicy
extends RefCounted

const DAILY_FREE_ROUNDS := 5
const MIN_ROUND_REWARD := 2
const MAX_ROUND_REWARD := 8
const ROUNDS_PER_REWARD_STEP := 10
const MIN_ENTRY_COST := 2
const PAID_REWARD_BONUS_RATE := 0.50
const MIN_PAID_REWARD_BONUS := 2


static func default_progress() -> Dictionary:
	return {
		"dailyDate": "",
		"dailyFreeRoundsUsed": 0,
		"totalPaidRounds": 0,
		"totalEntryCoinsSpent": 0,
		"totalRewardCoinsEarned": 0
	}


static func normalize_progress(progress: Dictionary, today: String = "") -> Dictionary:
	if today.is_empty():
		today = str(progress.get("dailyDate", ""))
	if str(progress.get("dailyDate", "")) != today:
		progress["dailyDate"] = today
		progress["dailyFreeRoundsUsed"] = 0
	progress["dailyFreeRoundsUsed"] = clampi(int(progress.get("dailyFreeRoundsUsed", 0)), 0, DAILY_FREE_ROUNDS)
	progress["totalPaidRounds"] = maxi(0, int(progress.get("totalPaidRounds", 0)))
	progress["totalEntryCoinsSpent"] = maxi(0, int(progress.get("totalEntryCoinsSpent", 0)))
	progress["totalRewardCoinsEarned"] = maxi(0, int(progress.get("totalRewardCoinsEarned", 0)))
	return progress


static func base_reward_for_round(round_number: int) -> int:
	var step := int((maxi(1, round_number) - 1) / ROUNDS_PER_REWARD_STEP)
	return clampi(MIN_ROUND_REWARD + step, MIN_ROUND_REWARD, MAX_ROUND_REWARD)


static func entry_cost_for_round(round_number: int) -> int:
	return maxi(MIN_ENTRY_COST, base_reward_for_round(round_number) - 2)


static func paid_reward_bonus(entry_cost: int) -> int:
	return maxi(MIN_PAID_REWARD_BONUS, int(ceil(float(maxi(0, entry_cost)) * PAID_REWARD_BONUS_RATE)))


static func round_quote(round_number: int, progress: Dictionary, today: String) -> Dictionary:
	normalize_progress(progress, today)
	var free_used := int(progress.get("dailyFreeRoundsUsed", 0))
	var paid := free_used >= DAILY_FREE_ROUNDS
	var base_reward := base_reward_for_round(round_number)
	var entry_cost := entry_cost_for_round(round_number) if paid else 0
	return {
		"round": maxi(1, round_number),
		"paid": paid,
		"entryCost": entry_cost,
		"baseReward": base_reward,
		"reward": base_reward + paid_reward_bonus(entry_cost) if paid else base_reward,
		"dailyFreeRemaining": maxi(0, DAILY_FREE_ROUNDS - free_used)
	}


static func record_round_started(progress: Dictionary, today: String, quote: Dictionary) -> void:
	normalize_progress(progress, today)
	if bool(quote.get("paid", false)):
		progress["totalPaidRounds"] = int(progress.get("totalPaidRounds", 0)) + 1
		progress["totalEntryCoinsSpent"] = int(progress.get("totalEntryCoinsSpent", 0)) + maxi(0, int(quote.get("entryCost", 0)))
	else:
		progress["dailyFreeRoundsUsed"] = mini(
			DAILY_FREE_ROUNDS,
			int(progress.get("dailyFreeRoundsUsed", 0)) + 1
		)


static func record_round_completed(progress: Dictionary, reward: int) -> void:
	normalize_progress(progress)
	progress["totalRewardCoinsEarned"] = int(progress.get("totalRewardCoinsEarned", 0)) + maxi(0, reward)
