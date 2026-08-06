class_name CoinRewardPolicy
extends RefCounted

const LevelDirectorScript = preload("res://scripts/level_director.gd")

const EXCELLENT_REWARD_MULTIPLIER := 1.30


static func base_reward_for_display_level(display_level: int) -> int:
	var reward := 1
	for size in [6, 7, 8, 9]:
		if LevelDirectorScript.is_size_unlocked(size, display_level):
			reward += 1
	return clampi(reward, 1, 5)


static func is_excellent_completion(heart_limit: int, remaining_hearts: int) -> bool:
	return heart_limit > 1 and remaining_hearts >= heart_limit


static func completion_reward(display_level: int, heart_limit: int, remaining_hearts: int) -> int:
	var base := base_reward_for_display_level(display_level)
	if is_excellent_completion(heart_limit, remaining_hearts):
		return int(ceil(float(base) * EXCELLENT_REWARD_MULTIPLIER))
	return base
