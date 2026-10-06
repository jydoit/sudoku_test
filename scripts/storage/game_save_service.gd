extends RefCounted

const CoinEconomyScript = preload("res://scripts/coin_economy.gd")
const CompositeCoinPolicyScript = preload("res://scripts/composite_coin_policy.gd")
const CompositeLevelDirectorScript = preload("res://scripts/composite_level_director.gd")
const LevelDirectorScript = preload("res://scripts/level_director.gd")
const RunAccuracyScript = preload("res://scripts/controllers/run_accuracy.gd")


static func normalize_loaded(data: Dictionary, defaults: Dictionary, today: String) -> Dictionary:
	if data.is_empty():
		return {}
	var save_version := int(data.get("saveVersion", 1))
	var level_index := int(data.get("currentLevelIndex", 0))
	var completed_levels: Array = data.get("completedLevels", []).duplicate()
	for index in range(completed_levels.size()):
		completed_levels[index] = int(completed_levels[index])
	var director_progress := _migrate_played_progress(data)
	var composite_director_progress := _dictionary_or(data.get("compositeDirectorProgress", {}), {})
	CompositeLevelDirectorScript.normalize_progress(composite_director_progress)
	var composite_coin_progress := _dictionary_or(
		data.get("compositeCoinProgress", {}), CompositeCoinPolicyScript.default_progress()
	)
	CompositeCoinPolicyScript.normalize_progress(composite_coin_progress, today)
	var economy_progress := _dictionary_or(data.get("economyProgress", {}), CoinEconomyScript.default_progress())
	CoinEconomyScript.normalize_progress(economy_progress)
	var independent_composite := bool(data.get("homeCompositeEntryActive", false))
	var composite_state := _dictionary_or(data.get("compositeState", {}), {})
	var schedule := _dictionary_or(data.get("activeSchedule", {}), {})
	var history := _dictionary_or(data.get("homeCompositeHistory", {}), {}).duplicate(true)
	if not history.is_empty():
		history["activeSchedule"] = clean_schedule(_dictionary_or(history.get("activeSchedule", {}), {}))
		history["runAccuracy"] = RunAccuracyScript.normalize_state(history.get("runAccuracy"))
	return {
		"currentLevelIndex": level_index,
		"playerLevelNumber": maxi(1, int(data.get("playerLevelNumber", level_index + 1))),
		"coinCount": int(data.get("coinCount", defaults.get("coinCount", 2))),
		"diamondCount": maxi(0, int(data.get("diamondCount", defaults.get("diamondCount", 0)))),
		"hiddenDiamondEventIds": _string_array_or(data.get("hiddenDiamondEventIds", [])),
		"hiddenDiamondProgress": _dictionary_or(data.get("hiddenDiamondProgress", {}), {}).duplicate(true),
		"hintCount": maxi(0, int(data.get("hintCount", defaults.get("hintCount", 2)))) if save_version >= 2 else int(defaults.get("hintCount", 2)),
		"crownFindCount": maxi(0, int(data.get("crownFindCount", defaults.get("crownFindCount", 1)))),
		"completedLevels": completed_levels,
		"heartCount": maxi(0, int(data.get("heartCount", defaults.get("heartCount", 3)))),
		"currentLevelId": int(data.get("currentLevelId", -1)),
		"cellStates": data.get("cellStates", []),
		"isCompleted": bool(data.get("isCompleted", false)),
		"isFailed": bool(data.get("isFailed", false)),
		"activeSchedule": clean_schedule(schedule) if independent_composite else formal_schedule(schedule, composite_state),
		"directorProgress": director_progress,
		"compositeDirectorProgress": composite_director_progress,
		"compositeCoinProgress": composite_coin_progress,
		"economyProgress": economy_progress,
		"runStartedUnix": int(data.get("runStartedUnix", 0)),
		"runMoveCount": maxi(0, int(data.get("runMoveCount", 0))),
		"runHintCount": maxi(0, int(data.get("runHintCount", 0))),
		"runDirectFindCount": maxi(0, int(data.get("runDirectFindCount", 0))),
		"runCoinExchangeCount": maxi(0, int(data.get("runCoinExchangeCount", 0))),
		"runAccuracy": RunAccuracyScript.normalize_state(data.get("runAccuracy")),
		"immediateErrors": bool(data.get("immediateErrors", true)),
		"selectedLanguage": str(data.get("selectedLanguage", "")),
		"musicEnabled": bool(data.get("musicEnabled", true)),
		"sfxEnabled": bool(data.get("sfxEnabled", true)),
		"hapticsEnabled": bool(data.get("hapticsEnabled", true)),
		"formalProgressSnapshot": _formal_snapshot(_dictionary_or(data.get("formalProgressSnapshot", {}), {})),
		"homeCompositeEntryActive": independent_composite,
		"homeCompositeRound": maxi(0, int(data.get("homeCompositeRound", 0))),
		"homeCompositeProgressSnapshot": _formal_snapshot(_dictionary_or(data.get("homeCompositeProgressSnapshot", {}), {})),
		"homeCompositeHistory": history,
		"compositeState": composite_state.duplicate(true) if independent_composite else {},
		"compositeTutorialSeen": bool(data.get("compositeTutorialSeen", false)),
		"tutorialCompleted": bool(data.get("tutorialCompleted", false)),
		"tutorialStarted": bool(data.get("tutorialStarted", false)),
		"tutorialStepIndex": int(data.get("tutorialStepIndex", 0))
	}


static func capture_formal(context: Dictionary) -> Dictionary:
	return {
		"currentLevelIndex": int(context["currentLevelIndex"]),
		"currentLevelId": int(context["currentLevelId"]),
		"playerLevelNumber": int(context["playerLevelNumber"]),
		"activeSchedule": formal_schedule(context["activeSchedule"]),
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
		"runAccuracy": RunAccuracyScript.normalize_state(context.get("runAccuracy"))
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
	var schedule := clean_schedule(context["activeSchedule"])
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
		"runCoinExchangeCount": int(context["runCoinExchangeCount"]),
		"runAccuracy": RunAccuracyScript.normalize_state(context.get("runAccuracy"))
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
		and schedule is Dictionary and str(schedule.get("mode", "")) == "home_composite"
		and composite_state is Dictionary and int(composite_state.get("seed", 0)) != 0
		and history.get("cellStates", []) is Array
		and states_match_size(history.get("cellStates", []), int(level["rows"]), int(level["cols"]))
	)


static func build_save(context: Dictionary, tutorial_controller, composite_state: Dictionary) -> Dictionary:
	var data := context.duplicate(true)
	data["runAccuracy"] = RunAccuracyScript.normalize_state(context.get("runAccuracy"))
	data["compositeState"] = composite_state if bool(context.get("homeCompositeEntryActive", false)) else {}
	tutorial_controller.write_save(data)
	return data


static func clean_schedule(schedule: Dictionary) -> Dictionary:
	var clean := schedule.duplicate(true)
	# Read-time migration only: no gameplay code consumes these retired flags.
	clean.erase("assemblyEnabled")
	clean.erase("assemblyPrebuiltData")
	return clean


static func formal_schedule(schedule: Dictionary, legacy_composite: Dictionary = {}) -> Dictionary:
	var clean := clean_schedule(schedule)
	for key in ["assemblySeed", "assemblyDifficultyPattern", "assemblyLayoutSignature", "homeCompositeRound"]:
		clean.erase(key)
	# Preserve an already assembled legacy board and its marks as a normal lion
	# puzzle, without retaining the old assembly controller or entry route.
	var regions = legacy_composite.get("finalRegions", [])
	var solution = legacy_composite.get("finalSolution", [])
	if str(legacy_composite.get("phase", "")) in ["crown", "transition"] and regions is Array and solution is Array and not regions.is_empty() and not solution.is_empty():
		clean["boardLayout"] = {"regions": regions.duplicate(true), "solution": solution.duplicate(true)}
	return clean


static func _formal_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	var clean := snapshot.duplicate(true)
	clean["directorProgress"] = _migrate_played_progress(snapshot)
	clean["runAccuracy"] = RunAccuracyScript.normalize_state(snapshot.get("runAccuracy"))
	clean["activeSchedule"] = formal_schedule(
		_dictionary_or(snapshot.get("activeSchedule", {}), {}),
		_dictionary_or(snapshot.get("compositeState", {}), {})
	)
	clean.erase("compositeState")
	clean.erase("compositeTutorialSeen")
	return clean


static func _migrate_played_progress(context: Dictionary) -> Dictionary:
	var progress := _dictionary_or(context.get("directorProgress", {}), {}).duplicate(true)
	var stored_played = progress.get("playedLevelIds", [])
	var played: Array = stored_played.duplicate() if stored_played is Array else []
	var completed = context.get("completedLevels", [])
	if completed is Array:
		played.append_array(completed)
	var schedule := _dictionary_or(context.get("activeSchedule", {}), {})
	# Modern saves know which boards were actually entered. Do not turn a board
	# merely preloaded behind the home screen into a played board on every load.
	# Snapshots have no outer saveVersion, but carry their own entered-ID ledger.
	var tracks_entries := progress.has("playedLevelIds") and (not context.has("saveVersion") or int(context["saveVersion"]) >= 20)
	if not tracks_entries and not bool(context.get("homeCompositeEntryActive", false)) and str(schedule.get("mode", "")) != "home_composite":
		played.append(context.get("currentLevelId", -1))
		played.append(schedule.get("levelId", -1))
	progress["playedLevelIds"] = played
	# A read-time migration records evidence only. Starting a run here would
	# incorrectly consume a deferred challenge or couple independent snapshots.
	return LevelDirectorScript.normalize_progress(progress)


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


static func _string_array_or(value) -> Array:
	var result: Array = []
	if value is Array:
		for entry in value:
			if entry is String and not str(entry).is_empty() and not result.has(entry):
				result.append(entry)
	return result
