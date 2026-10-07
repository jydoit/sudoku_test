extends SceneTree

const Accuracy = preload("res://scripts/controllers/run_accuracy.gd")
const Reward = preload("res://scripts/coin_reward_policy.gd")
const Results = preload("res://scripts/services/run_result_service.gd")
const Director = preload("res://scripts/level_director.gd")
const Rules = preload("res://scripts/rules/crown_rule_engine.gd")
const SAVE_PATH := "user://single_heart_rating_test_save.json"
var checks := 0
var failures := 0


func _initialize() -> void:
	ProjectSettings.set_setting("color_king/testing/save_path", SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _excellent(game) -> bool:
	return Reward.is_excellent_completion(game.current_heart_limit, game.heart_count, game.run_accuracy.save_state())


func _fresh(game) -> void:
	game.tutorial_completed = true
	game.tutorial_started = false
	game.in_tutorial = false
	game.home_composite_entry_active = false
	var schedule := Director.manual_schedule_for_level(game.levels, 10, 31, "manual")
	schedule["kingPositions"] = []
	game._load_level(10, false, schedule)
	game._cancel_opening_king_intro()
	game._cancel_hidden_diamond_event()
	game.board._clear_recent_tap()


func _new_game():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	return game


func _run() -> void:
	var accuracy = Accuracy.new()
	_check(not Reward.is_excellent_completion(1, 1, accuracy.save_state()), "Unknown old history stays Good")
	accuracy.reset()
	_check(Reward.is_excellent_completion(1, 1, accuracy.save_state()), "A clean tracked single-heart attempt is Excellent")
	_check(not Reward.is_excellent_completion(1, 0, accuracy.save_state()), "Failure is never Excellent")
	_check(Reward.completion_reward(31, 1, 1, accuracy.save_state()) == 3, "Single-heart Excellent gets ceil(2*1.3)")
	# Every answer position, not merely the final lion, participates in the ledger.
	for row in range(9):
		for col in range(9):
			accuracy.reset()
			accuracy.record_mark(Vector2i(col, row), true, true)
			_check(not Reward.is_excellent_completion(1, 1, accuracy.save_state()), "Any answer coordinate marked X disqualifies")
			accuracy.record_mark(Vector2i(col, row), true, false)
			accuracy.record_double(Vector2i(col, row), true)
			_check(not Reward.is_excellent_completion(1, 1, accuracy.save_state()), "Erasing or finding a previously excluded answer cannot erase history")
	accuracy.reset()
	accuracy.record_mark(Vector2i(1, 1), false, true)
	_check(Reward.is_excellent_completion(1, 1, accuracy.save_state()), "Correct exclusions do not lower rating")
	accuracy.record_mark(Vector2i(2, 2), true, true, true)
	var interrupted := accuracy.save_state()
	_check(interrupted["excludedLion"], "Save mid-gesture retains the visible X")
	accuracy.record_double(Vector2i(2, 2), true)
	_check(Reward.is_excellent_completion(1, 1, accuracy.save_state()), "Normal double-tap provisional X is exempt even after saving")
	accuracy.restore(interrupted)
	accuracy.record_double(Vector2i(2, 2), true)
	_check(not Reward.is_excellent_completion(1, 1, accuracy.save_state()), "Restart cannot resurrect an interrupted gesture exemption")
	accuracy.reset()
	accuracy.record_mark(Vector2i(2, 2), true, true, true)
	accuracy._pending_until = Time.get_ticks_msec() - 1
	accuracy.record_double(Vector2i(2, 2), true)
	_check(not Reward.is_excellent_completion(1, 1, accuracy.save_state()), "An expired tap is a real exclusion")
	accuracy.reset()
	accuracy.record_double(Vector2i(0, 0), false)
	_check(not Reward.is_excellent_completion(1, 1, accuracy.save_state()), "Revived wrong guesses remain Good")
	_check(Reward.is_excellent_completion(3, 3, accuracy.save_state()), "Multi-heart rating ignores new ledger and keeps old full-heart rule")
	_check(not Reward.is_excellent_completion(3, 2, accuracy.save_state()), "Multi-heart heart loss still gives Good")
	_check(Results.composite_completion({}, 3, 3, accuracy.save_state())["reward"] == 4, "Independent block reward remains unchanged")

	var game = await _new_game()
	_fresh(game)
	_check(game.current_heart_limit == 1 and _excellent(game), "New level 31 starts a tracked single-heart attempt")
	var answer := Vector2i(int(game.current_level["solution"][0][1]), int(game.current_level["solution"][0][0]))
	var safe := Vector2i(-1, -1)
	for row in range(int(game.current_level["rows"])):
		for col in range(int(game.current_level["cols"])):
			if not Rules.is_solution_cell(game.current_level, Vector2i(col, row)):
				safe = Vector2i(col, row)
	# Exercise actual board gesture dispatch (the first release emits an X).
	game.board._handle_tap_release(answer, Vector2(100, 100))
	_check(game.cell_states[answer.y][answer.x] == "blocked", "First release renders provisional X")
	# Input uses monotonic milliseconds; SceneTree timers in headless tests can
	# advance faster than wall time. Set the first release timestamp explicitly.
	game.board.recent_tap_released_at_msec = Time.get_ticks_msec() - 100
	game.board._handle_tap_release(answer, Vector2(100, 100))
	_check(game.cell_states[answer.y][answer.x] == "piece" and _excellent(game), "Actual double tap must keep Excellent eligibility")
	game._undo()
	_check(not _excellent(game), "Undo restoring a provisional X makes it an actual board exclusion")
	_fresh(game)
	game._on_cell_pressed(safe.y, safe.x)
	_check(_excellent(game), "A legal non-answer X keeps eligibility")
	game._on_cell_pressed(answer.y, answer.x)
	game._on_cell_pressed(answer.y, answer.x)
	_check(not _excellent(game), "Manually canceling a real exclusion does not reset rating")
	game._clear_board()
	_check(not _excellent(game), "Clear cannot wash out a previous exclusion")
	game._undo()
	_check(not _excellent(game), "Undo cannot wash out a previous exclusion")
	game._save_game()
	game.queue_free()
	await process_frame
	game = await _new_game()
	_check(game.player_level_number == 31 and not _excellent(game), "Restart restores the current attempt's exclusion history")
	game._replay_level()
	_check(_excellent(game), "Retry resets the ledger for a genuinely new attempt")
	game._cancel_opening_king_intro()
	game._on_cell_drag_started(answer.y, answer.x)
	game._on_cell_drag_ended()
	game._clear_board()
	_check(not _excellent(game), "Drag across a lion is remembered even after clear")
	_fresh(game)
	game._on_cell_double_pressed(safe.y, safe.x)
	_check(game.is_failed and game.run_accuracy.save_state()["wrongCrown"], "Wrong guesses are recorded before failure")
	game.coin_count = 1000
	game._revive_current_level()
	_check(game.heart_count == 1 and not _excellent(game), "Revive does not turn the failed attempt back into Excellent")
	game._clear_board()
	_check(not _excellent(game), "Removing a wrong marker after revival still retains mistake history")
	_fresh(game)
	game._capture_formal_progress_snapshot()
	var clean_snapshot: Dictionary = game.formal_progress_snapshot.duplicate(true)
	game._on_cell_pressed(answer.y, answer.x)
	game.run_accuracy.commit_pending()
	game._capture_formal_progress_snapshot()
	var excluded_snapshot: Dictionary = game.formal_progress_snapshot.duplicate(true)
	game.formal_progress_snapshot = clean_snapshot
	game._restore_formal_progress_snapshot()
	_check(_excellent(game), "Separate clean snapshot restores its own ledger")
	game.formal_progress_snapshot = excluded_snapshot
	game._restore_formal_progress_snapshot()
	_check(not _excellent(game), "Tutorial/block return restores excluded formal snapshot independently")
	_fresh(game)
	game.run_accuracy.restore({})
	_check(not _excellent(game), "Legacy resumed attempt cannot manufacture perfect history")
	game._replay_level()
	game._cancel_opening_king_intro()
	_check(_excellent(game), "Legacy attempt can use new rule after retry")
	game.hint_count = 10
	game._use_hint()
	_check(_excellent(game), "Using a hint does not lower accuracy")
	# Paid direct finds are allowed, and all settlement consumers must agree.
	game.coin_count = 1000
	game.crown_find_count = 0
	for _lion in range(int(game.current_level["targetCount"])):
		game._use_crown_find()
	_check(game.is_completed, "Direct finds may complete a single-heart board")
	var completion: Dictionary = game.economy_progress["recentCompletions"].back()
	_check(completion["excellent"] and completion["reward"] == 3, "Ledger, wallet settlement and Excellent reward must agree after paid tools")
	_check(completion["runAccuracy"] == game.run_accuracy.save_state(), "Economy record preserves the exact rating evidence")
	await create_timer(2.8).timeout
	_check(game.result_page.result_is_excellent, "Result page displays the same Excellent settlement")
	game.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("SINGLE HEART RATING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
