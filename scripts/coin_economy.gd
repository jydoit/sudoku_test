class_name CoinEconomy
extends RefCounted

const CoinRewardPolicyScript = preload("res://scripts/coin_reward_policy.gd")

const TOOL_HINT := "hint"
const TOOL_CROWN_FIND := "crown_find"
const TOOL_REVIVE := "revive"
const MAX_COMPLETION_HISTORY := 20
const REWARD_SCHEMA_VERSION := 2
const HINT_REWARD_WINDOW := 3
const CROWN_FIND_REWARD_WINDOW := 6


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


static func standard_tool_price(tool: String, display_level: int) -> int:
	if tool == TOOL_HINT:
		return _fallback_reward_sum(display_level, HINT_REWARD_WINDOW)
	if tool == TOOL_CROWN_FIND:
		return _fallback_reward_sum(display_level, CROWN_FIND_REWARD_WINDOW)
	if tool == TOOL_REVIVE:
		return CoinRewardPolicyScript.base_reward_for_display_level(display_level) * 2
	return 0


static func tool_price(tool: String, display_level: int, progress: Dictionary, _current_run_exchanges: int) -> int:
	normalize_progress(progress)
	if tool == TOOL_HINT:
		return _recent_reward_sum(progress, display_level, HINT_REWARD_WINDOW)
	if tool == TOOL_CROWN_FIND:
		return _recent_reward_sum(progress, display_level, CROWN_FIND_REWARD_WINDOW)
	return standard_tool_price(tool, display_level)


static func rewarded_ad_coin_grant(tool_price: int, coin_balance: int, display_level: int) -> int:
	var shortage := maxi(0, tool_price - maxi(0, coin_balance))
	return mini(tool_price, maxi(CoinRewardPolicyScript.base_reward_for_display_level(display_level), shortage))


static func record_tool_exchange(progress: Dictionary, tool: String, price: int) -> void:
	normalize_progress(progress)
	var counts: Dictionary = progress["toolExchangeCounts"]
	counts[tool] = int(counts.get(tool, 0)) + 1
	progress["totalCoinSpent"] = int(progress["totalCoinSpent"]) + maxi(0, price)


static func record_completion(
	progress: Dictionary,
	level_id: int,
	display_level: int,
	size: int,
	heart_limit: int,
	remaining_hearts: int,
	reward: int,
	run_coin_exchanges: int
) -> void:
	normalize_progress(progress)
	var recent: Array = progress["recentCompletions"]
	recent.append({
		"rewardSchemaVersion": REWARD_SCHEMA_VERSION,
		"levelId": level_id,
		"displayLevel": maxi(1, display_level),
		"size": size,
		"heartLimit": maxi(1, heart_limit),
		"remainingHearts": maxi(0, remaining_hearts),
		"excellent": CoinRewardPolicyScript.is_excellent_completion(heart_limit, remaining_hearts),
		"reward": maxi(0, reward),
		"coinExchanges": maxi(0, run_coin_exchanges)
	})
	while recent.size() > MAX_COMPLETION_HISTORY:
		recent.pop_front()
	progress["totalCoinEarned"] = int(progress["totalCoinEarned"]) + maxi(0, reward)


static func _recent_reward_sum(progress: Dictionary, display_level: int, window: int) -> int:
	var recent: Array = progress.get("recentCompletions", [])
	var rewards: Array[int] = []
	for index in range(recent.size() - 1, -1, -1):
		var completion = recent[index]
		if not completion is Dictionary:
			continue
		if int(completion.get("rewardSchemaVersion", 0)) != REWARD_SCHEMA_VERSION:
			continue
		rewards.append(maxi(1, int(completion.get("reward", 1))))
		if rewards.size() >= window:
			break
	var total := 0
	for reward in rewards:
		total += reward
	for offset in range(rewards.size() + 1, window + 1):
		total += CoinRewardPolicyScript.base_reward_for_display_level(maxi(1, display_level - offset))
	return maxi(1, total)


static func _fallback_reward_sum(display_level: int, window: int) -> int:
	var total := 0
	for offset in range(1, window + 1):
		total += CoinRewardPolicyScript.base_reward_for_display_level(maxi(1, display_level - offset))
	return maxi(1, total)
