extends RefCounted

const CoinEconomyScript = preload("res://scripts/coin_economy.gd")
const CompositeCoinPolicyScript = preload("res://scripts/composite_coin_policy.gd")
const CompositeLevelDirectorScript = preload("res://scripts/composite_level_director.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")


static func normalize_loaded(data: Dictionary, defaults: Dictionary, today: String) -> Dictionary:
	if data.is_empty():
		return {}
	var save_version := int(data.get("saveVersion", 1))
	var level_index := int(data.get("currentLevelIndex", 0))
	var completed_levels: Array = data.get("completedLevels", []).duplicate()
	for index in range(completed_levels.size()):
		completed_levels[index] = int(completed_levels[index])
	var director_progress := _dictionary_or(data.get("directorProgress", {}), {})
	LevelDirectorScript.normalize_progress(director_progress)
	var composite_director_progress := _dictionary_or(data.get("compositeDirectorProgress", {}), {})
	CompositeLevelDirectorScript.normalize_progress(composite_director_progress)
	var composite_coin_progress := _dictionary_or(
		data.get("compositeCoinProgress", {}), CompositeCoinPolicyScript.default_progress()
	)
	CompositeCoinPolicyScript.normalize_progress(composite_coin_progress, today)
	var economy_progress := _dictionary_or(data.get("economyProgress", {}), CoinEconomyScript.default_progress())
	CoinEconomyScript.normalize_progress(economy_progress)
	return {
		"currentLevelIndex": level_index,
		"playerLevelNumber": maxi(1, int(data.get("playerLevelNumber", level_index + 1))),
		"coinCount": int(data.get("coinCount", defaults.get("coinCount", 10))),
		"hintCount": maxi(0, int(data.get("hintCount", defaults.get("hintCount", 5)))) if save_version >= 2 else int(defaults.get("hintCount", 5)),
		"crownFindCount": clampi(int(data.get("crownFindCount", defaults.get("crownFindCount", 3))), 0, int(defaults.get("crownFindCount", 3))),
		"completedLevels": completed_levels,
		"heartCount": maxi(0, int(data.get("heartCount", defaults.get("heartCount", 3)))),
		"currentLevelId": int(data.get("currentLevelId", -1)),
		"cellStates": data.get("cellStates", []),
		"isCompleted": bool(data.get("isCompleted", false)),
		"isFailed": bool(data.get("isFailed", false)),
		"activeSchedule": _dictionary_or(data.get("activeSchedule", {}), {}),
		"directorProgress": director_progress,
		"compositeDirectorProgress": composite_director_progress,
		"compositeCoinProgress": composite_coin_progress,
		"economyProgress": economy_progress,
		"runStartedUnix": int(data.get("runStartedUnix", 0)),
		"runMoveCount": maxi(0, int(data.get("runMoveCount", 0))),
		"runHintCount": maxi(0, int(data.get("runHintCount", 0))),
		"runDirectFindCount": maxi(0, int(data.get("runDirectFindCount", 0))),
		"runCoinExchangeCount": maxi(0, int(data.get("runCoinExchangeCount", 0))),
		"immediateErrors": bool(data.get("immediateErrors", true)),
		"selectedLanguage": str(data.get("selectedLanguage", "")),
		"formalProgressSnapshot": _dictionary_or(data.get("formalProgressSnapshot", {}), {}).duplicate(true),
		"homeCompositeEntryActive": bool(data.get("homeCompositeEntryActive", false)),
		"homeCompositeRound": maxi(0, int(data.get("homeCompositeRound", 0))),
		"homeCompositeProgressSnapshot": _dictionary_or(data.get("homeCompositeProgressSnapshot", {}), {}).duplicate(true),
		"homeCompositeHistory": _dictionary_or(data.get("homeCompositeHistory", {}), {}).duplicate(true),
		"compositeState": _dictionary_or(data.get("compositeState", {}), {}).duplicate(true),
		"compositeTutorialSeen": bool(data.get("compositeTutorialSeen", false)),
		"tutorialCompleted": bool(data.get("tutorialCompleted", false)),
		"tutorialStarted": bool(data.get("tutorialStarted", false)),
		"tutorialStepIndex": int(data.get("tutorialStepIndex", 0))
	}


static func capture_formal(context: Dictionary, composite_state: Dictionary) -> Dictionary:
	return {
		"currentLevelIndex": int(context["currentLevelIndex"]),
		"currentLevelId": int(context["currentLevelId"]),
		"playerLevelNumber": int(context["playerLevelNumber"]),
		"activeSchedule": (context["activeSchedule"] as Dictionary).duplicate(true),
		"directorProgress": (context["directorProgress"] as Dictionary).duplicate(true),
		"economyProgress": (context["economyProgress"] as Dictionary).duplicate(true),
		"completedLevels": (context["completedLevels"] as Array).duplicate(),
		"cellStates": (context["cellStates"] as Array).duplicate(true),
		"isCompleted": bool(context["isCompleted"]),
		"isFailed": bool(context["isFailed"]),
		"coinCount": int(context["coinCount"]),
		"heartCount": int(context["heartCount"]),
		"hintCount": int(context["hintCount"]),
		"crownFindCount": int(context["crownFindCount"]),
		"runStartedUnix": int(context["runStartedUnix"]),
		"runMoveCount": int(context["runMoveCount"]),
		"runHintCount": int(context["runHintCount"]),
		"runDirectFindCount": int(context["runDirectFindCount"]),
		"runCoinExchangeCount": int(context["runCoinExchangeCount"]),
		"compositeState": composite_state,
		"compositeTutorialSeen": bool(context["compositeTutorialSeen"])
	}


static func formal_snapshot_is_valid(snapshot: Dictionary, levels: Array) -> bool:
	if snapshot.is_empty():
		return false
	var level_index := int(snapshot.get("currentLevelIndex", -1))
	if level_index < 0 or level_index >= levels.size():
		return false
	var level: Dictionary = levels[level_index]
	return (
		int(snapshot.get("currentLevelId", -1)) == int(level.get("levelId", -2))
		and snapshot.get("cellStates", []) is Array
		and states_match_size(snapshot.get("cellStates", []), int(level["rows"]), int(level["cols"]))
	)


static func build_home_composite_history(context: Dictionary, composite_state: Dictionary) -> Dictionary:
	var schedule: Dictionary = (context["activeSchedule"] as Dictionary).duplicate(true)
	schedule.erase("assemblyPrebuiltData")
	return {
		"version": 1,
		"round": maxi(1, int(context["round"])),
		"levelIndex": int(context["levelIndex"]),
		"levelId": int(context["levelId"]),
		"activeSchedule": schedule,
		"compositeState": composite_state,
		"cellStates": (context["cellStates"] as Array).duplicate(true),
		"isCompleted": bool(context["isCompleted"]),
		"isFailed": bool(context["isFailed"]),
		"heartCount": int(context["heartCount"]),
		"hintCount": int(context["hintCount"]),
		"crownFindCount": int(context["crownFindCount"]),
		"runStartedUnix": int(context["runStartedUnix"]),
		"runMoveCount": int(context["runMoveCount"]),
		"runHintCount": int(context["runHintCount"]),
		"runDirectFindCount": int(context["runDirectFindCount"]),
		"runCoinExchangeCount": int(context["runCoinExchangeCount"])
	}


static func home_composite_history_is_valid(history: Dictionary, levels: Array) -> bool:
	if history.is_empty() or int(history.get("round", 0)) < 1:
		return false
	var level_index := int(history.get("levelIndex", -1))
	if level_index < 0 or level_index >= levels.size():
		return false
	var level: Dictionary = levels[level_index]
	var schedule = history.get("activeSchedule", {})
	var composite_state = history.get("compositeState", {})
	return (
		int(history.get("levelId", -1)) == int(level.get("levelId", -2))
		and schedule is Dictionary and bool(schedule.get("assemblyEnabled", false))
		and composite_state is Dictionary and int(composite_state.get("seed", 0)) != 0
		and history.get("cellStates", []) is Array
		and states_match_size(history.get("cellStates", []), int(level["rows"]), int(level["cols"]))
	)


static func build_save(context: Dictionary, tutorial_controller, composite_state: Dictionary) -> Dictionary:
	var data := context.duplicate(true)
	data["compositeState"] = composite_state
	tutorial_controller.write_save(data)
	return data


static func blank_states(rows: int, cols: int) -> Array:
	var states: Array = []
	for _row in range(rows):
		var line: Array = []
		line.resize(cols)
		line.fill("empty")
		states.append(line)
	return states


static func states_match_size(states: Array, rows: int, cols: int) -> bool:
	if states.size() != rows:
		return false
	for row in states:
		if not row is Array or row.size() != cols:
			return false
	return true


static func _dictionary_or(value, fallback: Dictionary) -> Dictionary:
	return value if value is Dictionary else fallback
