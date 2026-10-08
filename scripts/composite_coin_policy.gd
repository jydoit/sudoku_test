class_name CompositeCoinPolicy
extends RefCounted

const DAILY_FREE_ROUNDS := 3
const PAID_ENTRY_COST := 2
const MIN_COMPLETION_REWARD := 1
const FREE_EXCELLENT_REWARD := 2


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


static func is_excellent_completion(remaining_hearts: int, accuracy: Dictionary) -> bool:
	return remaining_hearts > 0 and bool(accuracy.get("tracked", false)) and not bool(accuracy.get("excludedLion", true))


static func completion_reward(excellent: bool, entry_cost: int = 0, paid_entry: bool = false) -> int:
	if not paid_entry:
		return FREE_EXCELLENT_REWARD if excellent else MIN_COMPLETION_REWARD
	var paid := maxi(0, entry_cost)
	if excellent:
		return maxi(MIN_COMPLETION_REWARD, paid)
	return maxi(MIN_COMPLETION_REWARD, floori(float(paid) * 0.5))


static func entry_cost_for_round(_round_number: int) -> int:
	return PAID_ENTRY_COST


static func round_quote(round_number: int, progress: Dictionary, today: String) -> Dictionary:
	normalize_progress(progress, today)
	var free_used := int(progress.get("dailyFreeRoundsUsed", 0))
	var paid := free_used >= DAILY_FREE_ROUNDS
	var entry_cost := entry_cost_for_round(round_number) if paid else 0
	return {
		"round": maxi(1, round_number),
		"paid": paid,
		"entryCost": entry_cost,
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
