class_name CoinEconomy
extends RefCounted

const TOOL_HINT := "hint"
const TOOL_CROWN_FIND := "crown_find"
const TOOL_REVIVE := "revive"
const RECENT_COMPLETION_WINDOW := 3
const MAX_COMPLETION_HISTORY := 20
const OPENING_KING_REWARD_MULTIPLIER := 0.80
const MISTAKE_PENALTY_PER_COUNT := 0.25
const MIN_REWARD_MULTIPLIER := 0.50
const INACTIVE_TOOL_DISCOUNT_RATE := 0.20
const DISCOUNT_RECOVERY_EXCHANGES := 3

const SIZE_BASE_REWARDS := {
	5: 10,
	6: 14,
	7: 18,
	8: 23,
	9: 28
}


static func default_progress() -> Dictionary:
	return {
		"recentCompletions": [],
		"toolExchangeCounts": {},
		"totalCoinEarned": 0,
		"totalCoinSpent": 0
	}


static func normalize_progress(progress: Dictionary) -> void:
	if not progress.has("recentCompletions") or not progress.get("recentCompletions") is Array:
		progress["recentCompletions"] = []
	if not progress.has("toolExchangeCounts") or not progress.get("toolExchangeCounts") is Dictionary:
		progress["toolExchangeCounts"] = {}
	progress["totalCoinEarned"] = maxi(0, int(progress.get("totalCoinEarned", 0)))
	progress["totalCoinSpent"] = maxi(0, int(progress.get("totalCoinSpent", 0)))
	var recent: Array = progress["recentCompletions"]
	while recent.size() > MAX_COMPLETION_HISTORY:
		recent.pop_front()


static func size_base_reward(size: int) -> int:
	return int(SIZE_BASE_REWARDS.get(size, SIZE_BASE_REWARDS[9]))


static func level_base_reward(size: int, opening_king_count: int) -> int:
	var base := size_base_reward(size)
	if opening_king_count > 0:
		return maxi(1, int(round(float(base) * OPENING_KING_REWARD_MULTIPLIER)))
	return base


static func completion_reward(size: int, opening_king_count: int, mistake_count: int) -> int:
	var base := level_base_reward(size, opening_king_count)
	var multiplier := maxf(MIN_REWARD_MULTIPLIER, 1.0 - float(maxi(0, mistake_count)) * MISTAKE_PENALTY_PER_COUNT)
	return maxi(1, int(round(float(base) * multiplier)))


static func standard_tool_price(tool: String, size: int, opening_king_count: int) -> int:
	var base := level_base_reward(size, opening_king_count)
	if tool == TOOL_CROWN_FIND:
		return base * 3
	if tool == TOOL_REVIVE:
		return base * 2
	return base


static func tool_price(tool: String, size: int, opening_king_count: int, progress: Dictionary, current_run_exchanges: int) -> int:
	normalize_progress(progress)
	var standard := standard_tool_price(tool, size, opening_king_count)
	if not _last_three_completions_have_no_exchange(progress):
		return standard
	var base := level_base_reward(size, opening_king_count)
	var full_discount := maxi(1, int(round(float(base) * INACTIVE_TOOL_DISCOUNT_RATE)))
	var remaining_ratio := clampf(1.0 - float(maxi(0, current_run_exchanges)) / float(DISCOUNT_RECOVERY_EXCHANGES), 0.0, 1.0)
	var discount := int(round(float(full_discount) * remaining_ratio))
	return maxi(1, standard - discount)


static func rewarded_ad_coin_grant(tool_price: int, coin_balance: int, size: int, opening_king_count: int) -> int:
	var shortage := maxi(0, tool_price - maxi(0, coin_balance))
	return mini(tool_price, maxi(level_base_reward(size, opening_king_count), shortage))


static func record_tool_exchange(progress: Dictionary, tool: String, price: int) -> void:
	normalize_progress(progress)
	var counts: Dictionary = progress["toolExchangeCounts"]
	counts[tool] = int(counts.get(tool, 0)) + 1
	progress["totalCoinSpent"] = int(progress["totalCoinSpent"]) + maxi(0, price)


static func record_completion(progress: Dictionary, level_id: int, size: int, opening_king_count: int, mistake_count: int, reward: int, run_coin_exchanges: int) -> void:
	normalize_progress(progress)
	var recent: Array = progress["recentCompletions"]
	recent.append({
		"levelId": level_id,
		"size": size,
		"openingKingCount": opening_king_count,
		"mistakeCount": mistake_count,
		"reward": reward,
		"coinExchanges": maxi(0, run_coin_exchanges)
	})
	while recent.size() > MAX_COMPLETION_HISTORY:
		recent.pop_front()
	progress["totalCoinEarned"] = int(progress["totalCoinEarned"]) + maxi(0, reward)


static func _last_three_completions_have_no_exchange(progress: Dictionary) -> bool:
	var recent: Array = progress.get("recentCompletions", [])
	if recent.size() < RECENT_COMPLETION_WINDOW:
		return false
	for index in range(recent.size() - RECENT_COMPLETION_WINDOW, recent.size()):
		var completion = recent[index]
		if completion is Dictionary and int(completion.get("coinExchanges", 0)) > 0:
			return false
	return true
