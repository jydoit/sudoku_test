class_name OpeningKingHintController
extends RefCounted

const REQUIRED_NO_TOOL_WINS := 3


static func consecutive_no_tool_wins(progress: Dictionary, maximum_runs: int = 40) -> int:
	var runs = progress.get("recentRuns", [])
	if not runs is Array or runs.is_empty():
		return 0
	var streak := 0
	var first_index: int = maxi(0, runs.size() - maxi(1, maximum_runs))
	for index in range(runs.size() - 1, first_index - 1, -1):
		var run = runs[index]
		if not run is Dictionary or not bool(run.get("completed", true)):
			break
		var tool_uses := int(run.get(
			"toolUses",
			int(run.get("hints", 0)) + int(run.get("directFinds", 0))
		))
		if tool_uses > 0:
			break
		streak += 1
	return streak


static func adjusted_hint_count(decided_count: int, size: int, progress: Dictionary, random_roll: float) -> int:
	var original_count := maxi(0, decided_count)
	if original_count == 0:
		return 0
	if consecutive_no_tool_wins(progress) < REQUIRED_NO_TOOL_WINS:
		return original_count

	var roll := clampf(random_roll, 0.0, 1.0)
	if size < 6:
		return 0
	if size < 7:
		return 0 if roll < 0.70 else original_count
	if original_count == 1:
		return 0 if roll < 0.50 else 1
	if original_count == 2:
		return 1 if roll < 0.70 else 2
	return original_count - 1 if roll < 0.80 else original_count
