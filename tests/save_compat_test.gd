extends SceneTree

const SAVE_PATH := "user://save_compat_test_save.json"


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
	await _verify_version_one_migration()

	_restore_save(had_save, previous_save)
	print("PASS SAVE-001 current save round trip")
	print("PASS SAVE-002 previous save migration")
	print("PASS SAVE-003 new user defaults")
	quit()


func _verify_new_user_defaults() -> void:
	_remove_save()
	var game = await _new_game()
	assert(game.coin_count == game.INITIAL_COIN_COUNT, "SAVE-003 should grant the configured initial coins")
	assert(game.coin_count == 10, "SAVE-003 new users should start with 10 coins")
	game.queue_free()
	await process_frame


func _verify_current_round_trip() -> void:
	_remove_save()
	var game = await _new_game()
	game.tutorial_completed = true
	game.tutorial_started = false
	game.in_tutorial = false
	game.player_level_number = 2
	game.coin_count = 73
	game.hint_count = 2
	game.crown_find_count = 1
	game.music_enabled = false
	game.sfx_enabled = false
	game.haptics_enabled = false
	game.composite_coin_progress["dailyDate"] = game._today_string()
	game.composite_coin_progress["dailyFreeRoundsUsed"] = 3
	game.composite_coin_progress["totalPaidRounds"] = 2
	game._load_level(1)
	var editable := _first_editable_cell(game)
	game.cell_states[editable.y][editable.x] = "blocked"
	game._save_game()
	var expected_level_id := int(game.current_level["levelId"])
	game.queue_free()
	await process_frame

	var restored = await _new_game()
	assert(restored.coin_count == 73, "SAVE-001 should restore coins")
	assert(restored.hint_count == 2, "SAVE-001 should restore hint uses")
	assert(restored.crown_find_count == 1, "SAVE-001 should restore lion-finder uses")
	assert(not restored.music_enabled, "SAVE-001 should restore the music preference")
	assert(not restored.sfx_enabled, "SAVE-001 should restore the sound-effects preference")
	assert(not restored.haptics_enabled, "SAVE-001 should restore the haptics preference")
	assert(int(restored.composite_coin_progress.get("dailyFreeRoundsUsed", -1)) == 3, "SAVE-001 should restore today's used free block rounds")
	assert(int(restored.composite_coin_progress.get("totalPaidRounds", -1)) == 2, "SAVE-001 should restore cumulative paid block rounds")
	assert(restored.resume_level_id == expected_level_id, "SAVE-001 should restore the current level id")
	assert(restored.resume_states[editable.y][editable.x] == "blocked", "SAVE-001 should restore ordinary X marks")
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
	assert(restored.hint_count == restored.INITIAL_HINT_COUNT, "SAVE-002 should migrate v1 used-hint data to the default remaining count")
	assert(restored.crown_find_count == 2, "SAVE-002 should keep compatible lion-finder data")
	assert(restored.music_enabled and restored.sfx_enabled and restored.haptics_enabled, "SAVE-002 should enable audio and haptics for legacy saves")
	assert(int(restored.composite_coin_progress.get("dailyFreeRoundsUsed", -1)) == 0, "SAVE-002 should initialize the missing block coin policy")
	assert(restored.tutorial_completed, "SAVE-002 should preserve tutorial completion")
	restored.queue_free()
	await process_frame


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
