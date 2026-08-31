extends SceneTree

const LevelDirectorScript = preload("res://scripts/level_director.gd")
const OpeningKingHintControllerScript = preload("res://scripts/controllers/opening_king_hint_controller.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var three_no_tool := _progress_with_no_tool_wins(3)
	assert(OpeningKingHintControllerScript.consecutive_no_tool_wins(three_no_tool) == 3, "Three no-tool wins should activate hint reduction")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(1, 5, three_no_tool, 0.99) == 0, "Boards below size six should hide decided hints after three no-tool wins")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(2, 6, three_no_tool, 0.69) == 0, "Size six should hide all hints for the lower seventy-percent roll")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(2, 6, three_no_tool, 0.70) == 2, "Size six should preserve the decided count for the upper thirty-percent roll")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(1, 7, three_no_tool, 0.49) == 0, "A single size-seven hint should be hidden half of the time")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(1, 7, three_no_tool, 0.50) == 1, "A single size-seven hint should survive the upper half roll")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(2, 7, three_no_tool, 0.69) == 1, "Two size-seven hints should reduce to one with seventy-percent probability")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(2, 7, three_no_tool, 0.70) == 2, "Two size-seven hints should remain two with thirty-percent probability")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(3, 8, three_no_tool, 0.79) == 2, "Higher decided counts should reduce by one with eighty-percent probability")
	assert(OpeningKingHintControllerScript.adjusted_hint_count(3, 8, three_no_tool, 0.80) == 3, "Higher decided counts should remain unchanged with twenty-percent probability")

	var tool_used := _progress_with_no_tool_wins(2)
	tool_used["recentRuns"].append({"completed": true, "toolUses": 1})
	assert(OpeningKingHintControllerScript.adjusted_hint_count(2, 7, tool_used, 0.0) == 2, "Any recent tool use should preserve the decided hint count")
	var recent_failure := _progress_with_no_tool_wins(2)
	recent_failure["recentRuns"].append({"completed": false, "toolUses": 0})
	assert(OpeningKingHintControllerScript.adjusted_hint_count(2, 7, recent_failure, 0.0) == 2, "A recent failure should not be treated as no-tool mastery")

	assert(LevelDirectorScript._difficulty_floor_for_no_tool_streak(2) == "", "Two no-tool wins should not impose a difficulty floor")
	assert(LevelDirectorScript._difficulty_floor_for_no_tool_streak(3) == "medium", "Three no-tool wins should remove Simple recommendations")
	assert(LevelDirectorScript._difficulty_floor_for_no_tool_streak(6) == "hard", "Six no-tool wins should impose a Hard floor")
	assert(LevelDirectorScript._difficulty_pressure_multiplier([5], "hard", 0) > 1.0, "Hard should receive extra pressure before size six unlocks")
	assert(LevelDirectorScript._difficulty_pressure_multiplier([5], "challenge", 0) > LevelDirectorScript._difficulty_pressure_multiplier([5], "hard", 0), "Challenge should receive the largest pre-size-six pressure")
	assert(is_equal_approx(LevelDirectorScript._difficulty_pressure_multiplier([5, 6], "hard", 0), 1.0), "The pre-size-six multiplier should stop after size six unlocks")

	var payload = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var levels: Array = payload.get("levels", [])
	var fixed_nine := LevelDirectorScript.schedule_for_display_level(levels, 9, three_no_tool)
	assert(str(fixed_nine.get("mode", "")) == "fixed" and fixed_nine.get("kingPositions", []).size() == 1, "The first ten fixed schedules must remain unchanged")

	var skilled_progress := _progress_with_no_tool_wins(6)
	var normal_schedule := LevelDirectorScript.schedule_for_display_level(levels, 15, skilled_progress)
	assert(["hard", "challenge"].has(str(normal_schedule.get("selectedDifficulty", ""))), "A six-win no-tool streak should keep ordinary pre-size-six recommendations at Hard or above")
	assert(int(normal_schedule.get("openingKingDecidedCount", -1)) == 1, "Hint policy should run after the existing size-five count decision")
	assert(int(normal_schedule.get("openingKingDisplayedCount", -1)) == 0 and normal_schedule.get("kingPositions", []).is_empty(), "A skilled size-five player should receive no opening king on ordinary dynamic levels")

	var post_challenge_progress := _progress_with_no_tool_wins(2)
	post_challenge_progress["recentRuns"].append({
		"displayLevel": 10,
		"levelId": 7,
		"size": 5,
		"difficulty": "hard",
		"isMilestoneChallenge": true,
		"completed": true,
		"toolUses": 0,
	})
	var recovery_schedule := LevelDirectorScript.schedule_for_display_level(levels, 11, post_challenge_progress)
	assert(str(recovery_schedule.get("mode", "")) == "post_challenge", "The level after a ten-step milestone should keep the recovery branch")
	assert(recovery_schedule.get("kingPositions", []).size() == 1 and str(recovery_schedule.get("openingKingPolicy", "")) == "post_challenge_preserved", "The hint controller must not alter post-challenge recovery hints")

	var milestone_schedule := LevelDirectorScript.schedule_for_display_level(levels, 20, skilled_progress)
	assert(bool(milestone_schedule.get("isMilestoneChallenge", false)) and milestone_schedule.get("kingPositions", []).is_empty(), "Ten-step milestone challenge handling must remain unchanged")
	print("RECOMMENDATION HINT POLICY TEST PASSED: difficulty pressure, hint probabilities and milestone guards")
	quit()


func _progress_with_no_tool_wins(count: int) -> Dictionary:
	var runs: Array = []
	for index in range(count):
		runs.append({
			"displayLevel": index + 1,
			"levelId": index + 1,
			"size": 5,
			"difficulty": "medium",
			"isMilestoneChallenge": false,
			"completed": true,
			"toolUses": 0,
			"hints": 0,
			"directFinds": 0,
		})
	return {"completedLevelIds": [], "recentRuns": runs, "statsByArm": {}}
