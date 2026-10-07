extends SceneTree

const SAVE_PATH := "user://save_compat_test_save.json"
const GameSaveServiceScript = preload("res://scripts/storage/game_save_service.gd")


func _initialize() -> void:
	ProjectSettings.set_setting("color_king/testing/save_path", SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	call_deferred("_run")


func _run() -> void:
	var previous_save := ""
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		previous_save = FileAccess.get_file_as_string(SAVE_PATH)

	await _verify_new_user_defaults()
	await _verify_current_round_trip()
	await _verify_legacy_accuracy_resume()
	await _verify_version_one_migration()
	_verify_retired_formal_assembly_migration()
	_verify_played_history_migration()
	_verify_run_accuracy_storage()
	await _verify_formal_entry_history()

	_restore_save(had_save, previous_save)
	print("PASS SAVE-001 current save round trip")
	print("PASS SAVE-002 previous save migration")
	print("PASS SAVE-003 new user defaults")
	print("PASS SAVE-004 permanent played history migration and snapshot isolation")
	print("PASS SAVE-005 formal entry persistence, retry and deferred challenge lifecycle")
	print("PASS SAVE-006 run accuracy migration, round trip and snapshot isolation")
	quit()


func _verify_new_user_defaults() -> void:
	_remove_save()
	var game = await _new_game()
	assert(game.coin_count == game.INITIAL_COIN_COUNT, "SAVE-003 should grant the configured initial coins")
	assert(game.coin_count == 2, "SAVE-003 new users should start with 2 coins")
	assert(game.hint_count == 2, "SAVE-003 new users should start with 2 hints")
	assert(game.crown_find_count == 1, "SAVE-003 new users should start with 1 crown find")
	game.queue_free()
	await process_frame


func _verify_current_round_trip() -> void:
	_remove_save()
	var game = await _new_game()
	game.tutorial_completed = true
	game.tutorial_started = false
	game.in_tutorial = false
	# Fixed-opening boards deliberately restart on app load; use a resumable
	# formal round to verify the saved board and attempt accuracy together.
	game.player_level_number = 20
	game.coin_count = 73
	game.player_wallet.diamond_balance = 4
	game.hidden_diamond_controller.offered_ids = ["normal_level_20"]
	game.hint_count = 2
	game.crown_find_count = 1
	game.music_enabled = false
	game.sfx_enabled = false
	game.haptics_enabled = false
	game.composite_coin_progress["dailyDate"] = game._today_string()
	game.composite_coin_progress["dailyFreeRoundsUsed"] = 3
	game.composite_coin_progress["totalPaidRounds"] = 2
	game._load_level(10)
	game.run_accuracy.restore({"tracked": true, "excludedLion": true, "wrongCrown": false})
	var editable := _first_editable_cell(game)
	game.cell_states[editable.y][editable.x] = "blocked"
	game._save_game()
	var expected_level_id := int(game.current_level["levelId"])
	game.queue_free()
	await process_frame

	var restored = await _new_game()
	assert(restored.coin_count == 73, "SAVE-001 should restore coins")
	assert(restored.player_wallet.diamond_balance == 4, "SAVE-001 should restore diamonds")
	assert(restored.hidden_diamond_event_ids.has("normal_level_20"), "SAVE-001 should remember claimed hidden diamond events")
	assert(restored.hint_count == 2, "SAVE-001 should restore hint uses")
	assert(restored.crown_find_count == 1, "SAVE-001 should restore lion-finder uses")
	assert(not restored.music_enabled, "SAVE-001 should restore the music preference")
	assert(not restored.sfx_enabled, "SAVE-001 should restore the sound-effects preference")
	assert(not restored.haptics_enabled, "SAVE-001 should restore the haptics preference")
	assert(int(restored.composite_coin_progress.get("dailyFreeRoundsUsed", -1)) == 3, "SAVE-001 should restore today's used free block rounds")
	assert(int(restored.composite_coin_progress.get("totalPaidRounds", -1)) == 2, "SAVE-001 should restore cumulative paid block rounds")
	assert(restored.resume_level_id == expected_level_id, "SAVE-001 should restore the current level id")
	assert(restored.resume_states[editable.y][editable.x] == "blocked", "SAVE-001 should restore ordinary X marks")
	assert(restored.run_accuracy.save_state() == {"tracked": true, "excludedLion": true, "wrongCrown": false}, "SAVE-001 should restore current run accuracy without clearing prior mistakes")
	restored.queue_free()
	await process_frame


func _verify_legacy_accuracy_resume() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	legacy["saveVersion"] = 20
	legacy.erase("runAccuracy")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var restored = await _new_game()
	assert(not restored.run_accuracy.save_state()["tracked"], "Resuming a legacy run must not invent accuracy evidence")
	assert(int(restored.current_level["levelId"]) == int(legacy["currentLevelId"]) and restored.cell_states == legacy["cellStates"], "Accuracy migration must preserve the legacy board instead of restarting it")
	restored._replay_level()
	assert(restored.run_accuracy.save_state() == {"tracked": true, "excludedLion": false, "wrongCrown": false}, "An explicit retry must start a newly tracked clean attempt")
	restored.queue_free()
	await process_frame


func _verify_version_one_migration() -> void:
	var legacy := {
		"saveVersion": 1,
		"currentLevelIndex": 0,
		"currentLevelId": 1,
		"playerLevelNumber": 1,
		"coinCount": 42,
		"hintCount": 99,
		"crownFindCount": 2,
		"completedLevels": [],
		"tutorialCompleted": true,
		"tutorialStarted": false,
		"cellStates": []
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var restored = await _new_game()
	assert(restored.coin_count == 42, "SAVE-002 should keep legacy coins")
	assert(restored.player_wallet.diamond_balance == 0, "SAVE-002 should default legacy diamond balance to zero")
	assert(restored.hint_count == restored.INITIAL_HINT_COUNT, "SAVE-002 should migrate v1 used-hint data to the default remaining count")
	assert(restored.crown_find_count == 2, "SAVE-002 should keep compatible lion-finder data")
	assert(restored.music_enabled and restored.sfx_enabled and restored.haptics_enabled, "SAVE-002 should enable audio and haptics for legacy saves")
	assert(int(restored.composite_coin_progress.get("dailyFreeRoundsUsed", -1)) == 0, "SAVE-002 should initialize the missing block coin policy")
	assert(restored.tutorial_completed, "SAVE-002 should preserve tutorial completion")
	assert(FileAccess.file_exists("%s.pre-v%d.bak" % [SAVE_PATH, restored.SAVE_VERSION]), "Save upgrades must preserve the original file before migration")
	restored.queue_free()
	await process_frame


func _verify_retired_formal_assembly_migration() -> void:
	var legacy := {
		"saveVersion": 17,
		"coinCount": 73,
		"diamondCount": 4,
		"activeSchedule": {"mode": "challenge", "assemblyEnabled": true, "assemblySeed": 42},
		"compositeState": {"phase": "crown", "finalRegions": [[0]], "finalSolution": [[0, 0]]},
		"cellStates": [["blocked"]],
		"homeCompositeEntryActive": false
	}
	var migrated := GameSaveServiceScript.normalize_loaded(legacy, {}, "2026-10-05")
	assert(not migrated["activeSchedule"].has("assemblyEnabled") and migrated["compositeState"].is_empty(), "Retired mainline assembly flags must not reactivate gameplay")
	assert(migrated["activeSchedule"]["boardLayout"]["regions"] == [[0]], "An already assembled board should survive as ordinary puzzle data")
	assert(migrated["cellStates"] == legacy["cellStates"] and migrated["coinCount"] == 73 and migrated["diamondCount"] == 4, "Migration must preserve board marks and account balances")
	legacy["homeCompositeEntryActive"] = true
	var independent := GameSaveServiceScript.normalize_loaded(legacy, {}, "2026-10-05")
	assert(independent["compositeState"] == legacy["compositeState"], "Independent block saves must keep their phase and final board")


func _verify_played_history_migration() -> void:
	var legacy := {
		"saveVersion": 19,
		"coinCount": 73,
		"diamondCount": 4,
		"completedLevels": [11, 12.0, "12", -1],
		"currentLevelId": 16,
		"activeSchedule": {"levelId": 17.0, "isMilestoneChallenge": true},
		"cellStates": [["blocked", "king"]],
		"directorProgress": {
			"playedLevelIds": [10.0, "10"],
			"completedLevelIds": [13.0],
			"recentRuns": [{"levelId": 14.0, "success": false}, {"levelId": "15", "abandoned": true}, {"levelId": -101}],
			"pendingChallenge": true
		},
		"formalProgressSnapshot": _played_snapshot(20),
		"homeCompositeProgressSnapshot": _played_snapshot(30)
	}
	var original := legacy.duplicate(true)
	var migrated := GameSaveServiceScript.normalize_loaded(legacy, {}, "2026-10-06")
	_assert_played_ids(migrated["directorProgress"], [10, 11, 12, 13, 14, 15, 16, 17])
	_assert_played_ids(migrated["formalProgressSnapshot"]["directorProgress"], [21, 22, 23, 24, 25])
	_assert_played_ids(migrated["homeCompositeProgressSnapshot"]["directorProgress"], [31, 32, 33, 34, 35])
	assert(migrated["directorProgress"]["pendingChallenge"], "A migration must not consume a pending challenge when restoring its active schedule")
	assert(migrated["formalProgressSnapshot"]["directorProgress"]["pendingChallenge"], "Formal snapshot migration must preserve its pending challenge")
	assert(migrated["homeCompositeProgressSnapshot"]["directorProgress"]["pendingChallenge"], "Block-entry snapshot migration must preserve its pending challenge")
	assert(migrated["cellStates"] == original["cellStates"] and migrated["coinCount"] == 73 and migrated["diamondCount"] == 4, "Played-history migration must not change marks or balances")
	assert(legacy["directorProgress"] == original["directorProgress"] and legacy["formalProgressSnapshot"] == original["formalProgressSnapshot"], "Played-history migration must not mutate its source or original snapshots")
	for key in ["formalProgressSnapshot", "homeCompositeProgressSnapshot"]:
		assert(migrated[key]["cellStates"] == original[key]["cellStates"] and migrated[key]["coinCount"] == original[key]["coinCount"], "Each formal snapshot must retain its own board and balance")

	# Godot JSON parses numeric IDs as floats; normalization must remain integer,
	# unique, and stable through subsequent launches without inventing old runs.
	migrated["saveVersion"] = 20
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(migrated))
	var repeated := GameSaveServiceScript.normalize_loaded(round_trip, {}, "2026-10-06")
	_assert_played_ids(repeated["directorProgress"], [10, 11, 12, 13, 14, 15, 16, 17])
	_assert_played_ids(repeated["formalProgressSnapshot"]["directorProgress"], [21, 22, 23, 24, 25])
	_assert_played_ids(repeated["homeCompositeProgressSnapshot"]["directorProgress"], [31, 32, 33, 34, 35])
	assert(repeated["directorProgress"]["playedLevelIds"] == migrated["directorProgress"]["playedLevelIds"], "Repeated migrations must be idempotent")
	assert(repeated["directorProgress"]["pendingChallenge"], "JSON round trips must preserve deferred challenges")
	repeated["formalProgressSnapshot"]["directorProgress"]["playedLevelIds"].append(999)
	assert(not repeated["directorProgress"]["playedLevelIds"].has(999) and not repeated["homeCompositeProgressSnapshot"]["directorProgress"]["playedLevelIds"].has(999), "Snapshot played histories must not share mutable arrays")

	var independent := original.duplicate(true)
	independent["homeCompositeEntryActive"] = true
	independent["currentLevelId"] = 900
	independent["activeSchedule"] = {"levelId": 901, "mode": "home_composite"}
	independent["homeCompositeHistory"] = {"levelId": 902, "activeSchedule": {"levelId": 902, "mode": "home_composite"}}
	var independent_loaded := GameSaveServiceScript.normalize_loaded(independent, {}, "2026-10-06")
	_assert_played_ids(independent_loaded["directorProgress"], [10, 11, 12, 13, 14, 15])
	_assert_played_ids(independent_loaded["homeCompositeProgressSnapshot"]["directorProgress"], [31, 32, 33, 34, 35])
	assert(independent_loaded["homeCompositeHistory"]["levelId"] == 902, "Migration must not discard independent block history")
	independent["homeCompositeEntryActive"] = false
	var mode_guard := GameSaveServiceScript.normalize_loaded(independent, {}, "2026-10-06")
	_assert_played_ids(mode_guard["directorProgress"], [10, 11, 12, 13, 14, 15])

	var tutorial := {"saveVersion": 19, "currentLevelId": -100, "activeSchedule": {"levelId": -100}, "completedLevels": [-100]}
	var tutorial_loaded := GameSaveServiceScript.normalize_loaded(tutorial, {}, "2026-10-06")
	_assert_played_ids(tutorial_loaded["directorProgress"], [])
	var preloaded := {
		"saveVersion": 20, "currentLevelId": 701,
		"activeSchedule": {"levelId": 701},
		"directorProgress": {"playedLevelIds": [700], "pendingChallenge": true},
		"formalProgressSnapshot": {
			"currentLevelId": 702, "activeSchedule": {"levelId": 702},
			"directorProgress": {"playedLevelIds": [700], "pendingChallenge": true}
		}
	}
	var preloaded_restored := GameSaveServiceScript.normalize_loaded(preloaded, {}, "2026-10-06")
	_assert_played_ids(preloaded_restored["directorProgress"], [700])
	_assert_played_ids(preloaded_restored["formalProgressSnapshot"]["directorProgress"], [700])
	assert(preloaded_restored["directorProgress"]["pendingChallenge"], "Reloading a modern preloaded board must preserve its pending challenge without marking it played")


func _played_snapshot(base: int) -> Dictionary:
	return {
		"completedLevels": [base + 1],
		"currentLevelId": base + 2,
		"activeSchedule": {"levelId": base + 3, "isMilestoneChallenge": true},
		"directorProgress": {
			"completedLevelIds": [base + 4],
			"recentRuns": [{"levelId": base + 5, "success": false}],
			"pendingChallenge": true
		},
		"cellStates": [["blocked", "empty"]],
		"coinCount": base
	}


func _assert_played_ids(progress: Dictionary, expected: Array) -> void:
	var actual: Array = progress["playedLevelIds"].duplicate()
	assert(actual.size() == expected.size(), "Played history must have exactly the IDs supported by saved evidence: %s / %s" % [actual, expected])
	for level_id in actual:
		assert(level_id is int and int(level_id) > 0, "Played IDs must normalize to positive integers")
	actual.sort()
	var sorted_expected := expected.duplicate()
	sorted_expected.sort()
	assert(actual == sorted_expected, "Played history must include completed, failed, abandoned and current formal levels: %s / %s" % [actual, sorted_expected])


func _verify_formal_entry_history() -> void:
	_remove_save()
	var game = await _new_game()
	var initial_played: Array = game.director_progress["playedLevelIds"].duplicate()
	game._show_game()
	assert(game.director_progress["playedLevelIds"] == initial_played, "Entering a tutorial must not record a formal played level")
	game.tutorial_completed = true
	game.tutorial_started = false
	game.in_tutorial = false
	var deferred: Dictionary = game._schedule_for_manual_level(10)
	deferred["mode"] = "recommended"
	deferred["displayLevel"] = 20
	deferred["isMilestoneChallenge"] = false
	deferred["challengeDeferred"] = true
	game._load_level(10, false, deferred)
	var level_id := int(game.current_level["levelId"])
	assert(not game.director_progress["playedLevelIds"].has(level_id), "Preloading a board must not count as playing it")
	game._show_game()
	var first_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert(_saved_played_contains(first_save, level_id), "Entering a formal board must persist its played ID immediately")
	assert(first_save["directorProgress"]["pendingChallenge"], "Entering a deferred ordinary board must persist its pending challenge")
	var played_after_entry: Array = game.director_progress["playedLevelIds"].duplicate()
	game._show_game()
	assert(game.director_progress["playedLevelIds"] == played_after_entry, "Repeated show-game calls must not duplicate played IDs")
	game._replay_level()
	game._show_game()
	assert(int(game.current_level["levelId"]) == level_id and game.director_progress["playedLevelIds"] == played_after_entry, "Retrying a played board must keep its level and not reschedule it")
	var editable := _first_editable_cell(game)
	game.cell_states[editable.y][editable.x] = "blocked"
	game._save_game()
	game.queue_free()
	await process_frame

	var restored = await _new_game()
	assert(restored.director_progress["pendingChallenge"], "Restarting the app must retain the deferred challenge")
	assert(int(restored.current_level["levelId"]) == level_id and restored.cell_states[editable.y][editable.x] == "blocked", "Restoring a played current board must preserve its ID and marks")
	restored._show_game()
	assert(restored.director_progress["pendingChallenge"], "Resuming the deferred ordinary board must not consume its pending challenge")
	var challenge: Dictionary = restored._schedule_for_manual_level(11)
	challenge["mode"] = "challenge"
	challenge["displayLevel"] = 21
	challenge["isMilestoneChallenge"] = true
	challenge["challengeDeferred"] = false
	restored._load_level(11, false, challenge)
	assert(restored.director_progress["pendingChallenge"], "Preloading a challenge must not consume pending state")
	restored._show_game()
	var challenge_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert(not challenge_save["directorProgress"]["pendingChallenge"], "Entering the next challenge must persist the consumed pending state")
	assert(_saved_played_contains(challenge_save, int(restored.current_level["levelId"])), "The new challenge's played ID must be saved with its pending-state update")
	var formal_played: Array = restored.director_progress["playedLevelIds"].duplicate()
	restored.home_composite_entry_active = true
	restored.current_level = restored.levels[12].duplicate(true)
	restored.active_schedule = {"mode": "home_composite", "levelId": restored.current_level["levelId"]}
	restored._show_game()
	assert(restored.director_progress["playedLevelIds"] == formal_played, "Independent block entry must not add a formal played level")
	restored.queue_free()
	await process_frame


func _saved_played_contains(data: Dictionary, level_id: int) -> bool:
	for raw_id in data["directorProgress"].get("playedLevelIds", []):
		if int(raw_id) == level_id:
			return true
	return false


func _verify_run_accuracy_storage() -> void:
	var perfect := {"tracked": true, "excludedLion": false, "wrongCrown": false}
	var excluded := {"tracked": true, "excludedLion": true, "wrongCrown": false}
	var wrong := {"tracked": true, "excludedLion": false, "wrongCrown": true}
	var untracked := {"tracked": false, "excludedLion": false, "wrongCrown": false}
	var context := _run_accuracy_context()
	context["runAccuracy"] = excluded
	context["formalProgressSnapshot"] = {"currentLevelId": 41, "runAccuracy": perfect}
	context["homeCompositeProgressSnapshot"] = {"currentLevelId": 42, "runAccuracy": wrong}
	context["homeCompositeHistory"] = {"levelId": 43, "runAccuracy": untracked}
	var loaded := GameSaveServiceScript.normalize_loaded(context, {}, "2026-10-06")
	assert(loaded["runAccuracy"] == excluded, "Load must retain evidence of an incorrectly excluded lion")
	assert(loaded["formalProgressSnapshot"]["runAccuracy"] == perfect, "Tutorial-return snapshot must keep its own accuracy")
	assert(loaded["homeCompositeProgressSnapshot"]["runAccuracy"] == wrong, "Block-entry snapshot must keep its own accuracy")
	assert(loaded["homeCompositeHistory"]["runAccuracy"] == untracked, "Independent block history must preserve whether accuracy was tracked")
	loaded["runAccuracy"]["excludedLion"] = false
	loaded["formalProgressSnapshot"]["runAccuracy"]["excludedLion"] = true
	loaded["homeCompositeProgressSnapshot"]["runAccuracy"]["wrongCrown"] = false
	loaded["homeCompositeHistory"]["runAccuracy"]["tracked"] = true
	assert(excluded["excludedLion"] and not perfect["excludedLion"] and wrong["wrongCrown"] and not untracked["tracked"], "Loading accuracy must not alias any source snapshot or live dictionary")
	assert(not loaded["runAccuracy"]["excludedLion"] and loaded["formalProgressSnapshot"]["runAccuracy"]["excludedLion"], "Different runs must not share the same accuracy dictionary")

	var snapshot := GameSaveServiceScript.capture_formal(context)
	var history := GameSaveServiceScript.build_home_composite_history(context, {})
	var tutorial = load("res://scripts/controllers/tutorial_controller.gd").new()
	var written := GameSaveServiceScript.build_save(context, tutorial, {})
	assert(snapshot["runAccuracy"] == excluded and history["runAccuracy"] == excluded and written["runAccuracy"] == excluded, "All save/capture entry points must carry current run evidence")
	snapshot["runAccuracy"]["wrongCrown"] = true
	history["runAccuracy"]["tracked"] = false
	written["runAccuracy"]["excludedLion"] = false
	assert(not excluded["wrongCrown"] and excluded["tracked"] and excluded["excludedLion"], "Save/capture/history accuracy must be independent deep copies")
	assert(snapshot["runAccuracy"]["tracked"] and history["runAccuracy"]["excludedLion"] and not written["runAccuracy"]["wrongCrown"], "Mutating one captured run must not alter another captured run")

	var serialized := GameSaveServiceScript.build_save(context, tutorial, {})
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(serialized))
	var restored := GameSaveServiceScript.normalize_loaded(round_trip, {}, "2026-10-06")
	assert(restored["runAccuracy"] == excluded, "JSON round trip must keep run accuracy boolean evidence")
	for key in ["formalProgressSnapshot", "homeCompositeProgressSnapshot", "homeCompositeHistory"]:
		assert(restored[key]["runAccuracy"] == context[key]["runAccuracy"], "JSON round trip must preserve %s accuracy independently" % key)
	assert(restored["cellStates"] == context["cellStates"] and restored["coinCount"] == 73 and restored["diamondCount"] == 4, "Accuracy persistence must not change board marks or account balances")

	var legacy := context.duplicate(true)
	legacy["saveVersion"] = 20
	legacy.erase("runAccuracy")
	for key in ["formalProgressSnapshot", "homeCompositeProgressSnapshot", "homeCompositeHistory"]:
		legacy[key].erase("runAccuracy")
	_assert_unknown_run_accuracy(GameSaveServiceScript.normalize_loaded(legacy, {}, "2026-10-06"))
	assert(GameSaveServiceScript.capture_formal(legacy)["runAccuracy"].is_empty(), "Capturing old accuracy must not infer flawless play from full hearts")
	assert(GameSaveServiceScript.build_home_composite_history(legacy, {})["runAccuracy"].is_empty(), "Old independent block history must remain untracked")
	assert(GameSaveServiceScript.build_save(legacy, tutorial, {})["runAccuracy"].is_empty(), "Saving old accuracy must not manufacture history")
	var malformed: Array = [null, false, 1, "true", [], {}, {"tracked": true}, {"tracked": true, "excludedLion": 0, "wrongCrown": false}, {"tracked": "true", "excludedLion": false, "wrongCrown": false}, {"tracked": true, "excludedLion": false, "wrongCrown": null}]
	for value in malformed:
		var bad := context.duplicate(true)
		bad["runAccuracy"] = value
		for key in ["formalProgressSnapshot", "homeCompositeProgressSnapshot", "homeCompositeHistory"]:
			bad[key]["runAccuracy"] = value
		_assert_unknown_run_accuracy(GameSaveServiceScript.normalize_loaded(bad, {}, "2026-10-06"))
		assert(GameSaveServiceScript.capture_formal(bad)["runAccuracy"].is_empty(), "Malformed accuracy must not become valid while capturing a formal snapshot")
		assert(GameSaveServiceScript.build_home_composite_history(bad, {})["runAccuracy"].is_empty(), "Malformed accuracy must not become valid while capturing a block history")
		assert(GameSaveServiceScript.build_save(bad, tutorial, {})["runAccuracy"].is_empty(), "Malformed accuracy must not become valid while saving")


func _run_accuracy_context() -> Dictionary:
	return {
		"saveVersion": 21, "currentLevelIndex": 0, "currentLevelId": 40,
		"playerLevelNumber": 40, "levelIndex": 0, "levelId": 40, "round": 1,
		"activeSchedule": {}, "directorProgress": {}, "economyProgress": {},
		"completedLevels": [], "cellStates": [["blocked", "king"]],
		"isCompleted": false, "isFailed": false, "coinCount": 73, "diamondCount": 4,
		"heartCount": 1, "hintCount": 2, "crownFindCount": 1,
		"runStartedUnix": 0, "runMoveCount": 5, "runHintCount": 1,
		"runDirectFindCount": 1, "runCoinExchangeCount": 0
	}


func _assert_unknown_run_accuracy(data: Dictionary) -> void:
	assert(data["runAccuracy"].is_empty(), "Missing or malformed current run accuracy must stay unknown")
	for key in ["formalProgressSnapshot", "homeCompositeProgressSnapshot", "homeCompositeHistory"]:
		assert(data[key]["runAccuracy"].is_empty(), "Missing or malformed %s accuracy must stay unknown" % key)


func _new_game():
	var packed: PackedScene = load("res://scenes/main.tscn")
	assert(packed != null, "Main scene must load for save validation")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	return game


func _first_editable_cell(game) -> Vector2i:
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if not game._is_king_cell(row, col):
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _restore_save(had_save: bool, contents: String) -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(contents)
	else:
		_remove_save()
