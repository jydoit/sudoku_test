class_name OpeningKingHintController
extends RefCounted

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
