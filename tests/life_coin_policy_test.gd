extends SceneTree

const Reward = preload("res://scripts/coin_reward_policy.gd")
const Composite = preload("res://scripts/composite_coin_policy.gd")
const Results = preload("res://scripts/services/run_result_service.gd")
const Entry = preload("res://scripts/services/composite_entry_service.gd")
const Director = preload("res://scripts/level_director.gd")
const Save = preload("res://scripts/storage/game_save_service.gd")
const Accuracy = preload("res://scripts/controllers/run_accuracy.gd")
const SAVE_PATH := "user://life_coin_policy_test_save.json"
var checks := 0
var failures := 0


func _initialize() -> void:
	ProjectSettings.set_setting("color_king/testing/save_path", SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	_policies()
	await _runtime()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("LIFE AND COIN POLICY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _policies() -> void:
	var clean := {"tracked": true, "excludedLion": false, "wrongCrown": false}
	var excluded := {"tracked": true, "excludedLion": true, "wrongCrown": false}
	check(Reward.completion_reward(10, 3, 3, clean) == 2, "First ten ordinary Excellent rewards stay unchanged")
	check(Reward.completion_reward(10, 3, 2, clean) == 1, "First ten ordinary Good rewards stay unchanged")
	for display in [11, 20, 21, 80, 240]:
		var base := Reward.base_reward_for_display_level(display)
		check(Reward.completion_reward(display, 1, 1, excluded) == base, "Ordinary Good retains its original progression reward")
		check(Reward.completion_reward(display, 1, 1, clean) == ceili(float(base) * 1.3), "Ordinary Excellent retains its original 1.3x rounded-up reward")
	check(Composite.is_excellent_completion(1, clean), "Clean lion exclusions are the composite Excellent criterion")
	check(not Composite.is_excellent_completion(2, excluded), "Full hearts do not hide a lion marked X")
	check(Composite.is_excellent_completion(1, {"tracked": true, "excludedLion": false, "wrongCrown": true}), "Heart loss alone does not override the requested composite criterion")
	check(not Composite.is_excellent_completion(1, {}), "Unknown history cannot manufacture composite Excellent")
	var ledger = Accuracy.new()
	ledger.reset()
	ledger.record_mark(Vector2i(1, 1), true, true)
	ledger.record_mark(Vector2i(1, 1), true, false)
	check(not Composite.is_excellent_completion(2, ledger.save_state()), "Canceling an answer X cannot erase it")
	ledger.restore(JSON.parse_string(JSON.stringify(ledger.save_state())))
	check(not Composite.is_excellent_completion(2, ledger.save_state()), "Exclusion evidence survives serialization")
	var paid := {"compositePaidEntry": true, "compositeEntryCost": 2}
	check(Results.composite_completion({}, 2, 2, excluded)["reward"] == 1, "Free Good grants one coin")
	check(Results.composite_completion({}, 2, 2, clean)["reward"] == 2, "Free Excellent grants two coins")
	check(Results.composite_completion(paid, 2, 2, excluded)["reward"] == 1, "Two-coin paid Good returns half the actual entry cost")
	check(Results.composite_completion(paid, 2, 1, clean)["reward"] == 2, "Paid Excellent returns the full actual entry cost")
	check(Results.composite_completion(paid, 1, 0, clean)["reward"] == 0, "Failed block rounds cannot earn completion coins")
	for entry_cost in [0, 1, 2, 4, 7, 10]:
		check(Composite.completion_reward(false, entry_cost, true) == maxi(1, floori(float(entry_cost) * 0.5)), "Good uses half the actual fee, rounded down and at least one")
		check(Composite.completion_reward(true, entry_cost, true) == maxi(1, entry_cost), "Excellent uses the actual fee, not a fixed payout")
	var progress := Composite.default_progress()
	for round_number in range(1, 4):
		var quote := Entry.quote(round_number, progress, "2026-10-08")
		check(not quote["paid"], "Daily first three new rounds remain free")
		Composite.record_round_started(progress, "2026-10-08", quote)
	check(Entry.quote(4, progress, "2026-10-08")["entryCost"] == 2, "The fourth entry still costs two coins")
	var cleaned := Save.clean_schedule({"compositeCoinGoodReward": 2, "compositeCoinExcellentReward": 4})
	check(cleaned.is_empty(), "Retired fixed-reward quote fields are removed from old schedules")


func _runtime() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.tutorial_completed = true
	game.tutorial_started = false
	game.in_tutorial = false
	game.coin_count = 100
	game.composite_coin_progress = Composite.default_progress()
	for display in [10, 11, 20, 21]:
		game._load_level(0, false, Director.manual_schedule_for_level(game.levels, 0, display, "manual"))
		check(game.current_heart_limit == (3 if display == 10 else (2 if display <= 20 else 1)), "Ordinary heart boundary uses the display level")
	game._start_home_composite_flow()
	await process_frame
	check(game.home_composite_entry_active and game.composite_mode, "Runtime fixture enters a real independent block round")
	if not game.composite_mode:
		game.queue_free()
		await process_frame
		return
	check(game.current_heart_limit == 2 and game.heart_count == 2, "Block round one gets two hearts despite formal level 21")
	for round_number in [5, 6]:
		game.home_composite_round = round_number
		game._load_level(game.current_level_index, false, game.active_schedule)
		check(game.current_heart_limit == (2 if round_number == 5 else 1), "Block heart boundary uses its independent round number")
	game.composite_coin_progress["dailyFreeRoundsUsed"] = 3
	var quote: Dictionary = game._home_composite_round_quote(6)
	var schedule := Entry.schedule_with_quote(game.active_schedule, quote)
	game._load_level(game.current_level_index, false, schedule)
	game._apply_home_composite_round_entry(quote)
	game._on_composite_intro_cancelled()
	game._cancel_opening_king_intro()
	game._cancel_hidden_diamond_event()
	game.composite_phase = "crown"
	game.composite_final_layout = {
		"regions": game.current_level["regions"].duplicate(true),
		"solution": game.current_level["solution"].duplicate(true),
		"signature": "life_coin_policy_test"
	}
	game.run_accuracy.record_mark(Vector2i(0, 0), true, true)
	var before: int = game.coin_count
	game._complete_level()
	check(game.is_completed and game.coin_count == before + 1, "Actual paid Good completion grants its one-coin refund exactly once")
	var receipt: Dictionary = game.active_schedule.get("coinSettlement", {}).duplicate(true)
	check(receipt.get("reward") == 1 and receipt.get("excellent") == false, "Receipt stores the actual reward and immutable rating")
	check(receipt.get("balanceBefore") == before and receipt.get("balanceAfter") == before + 1, "Receipt stores exact transaction endpoints")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	# JSON represents numeric values as floats; compare like serialization forms.
	var saved_receipt: Dictionary = JSON.parse_string(JSON.stringify(receipt))
	check(saved["activeSchedule"]["coinSettlement"] == saved_receipt and saved["homeCompositeHistory"]["activeSchedule"]["coinSettlement"] == saved_receipt, "Completion receipt is saved before celebration finishes in both current and block history")
	game._prepare_success_result_page()
	game._prepare_success_result_page()
	check(game.coin_count == before + 1 and game.active_schedule["coinSettlement"] == receipt, "Reopening a result page cannot re-award or reroll coins")
	# The coin toss follows the board celebration and one of three lion entries.
	var animation_deadline := Time.get_ticks_msec() + 7000
	while game.result_page.result_coin_tween == null and Time.get_ticks_msec() < animation_deadline:
		await process_frame
	check(game.result_page.result_coin_roll_row.visible, "Coin balance remains visible when the toss begins")
	check(game.result_page.result_coin_tween != null, "Existing toss/flight animation still runs for the one-coin refund")
	game.queue_free()
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.coin_count == before + 1 and game.home_composite_history.get("activeSchedule", {}).get("coinSettlement", {}) == saved_receipt, "Restart returns home and preserves the paid completion history without granting it again")
	# Restore the saved completed block board to exercise retry separately from
	# the normal startup route, which intentionally returns to the formal home.
	game.home_composite_entry_active = true
	game.home_composite_round = int(saved["homeCompositeRound"])
	game.home_composite_progress_snapshot = saved["homeCompositeProgressSnapshot"].duplicate(true)
	game.resume_level_id = int(saved["currentLevelId"])
	game.resume_states = saved["cellStates"].duplicate(true)
	game.resume_completed = true
	game.resume_failed = false
	game.resume_composite_state = saved["compositeState"].duplicate(true)
	game.heart_count = int(saved["heartCount"])
	game.run_accuracy.restore(saved["runAccuracy"])
	game._load_level(int(saved["currentLevelIndex"]), true, saved["activeSchedule"], true)
	check(game.active_schedule.get("coinSettlement", {}) == saved_receipt and game.coin_count == before + 1, "Restoring a completed block board preserves its settlement without rerolling")
	game._replay_level()
	check(not game.active_schedule.has("coinSettlement") and game.run_accuracy.save_state()["lostLife"], "Retry clears only the previous settlement, not the sticky life-loss rule")
	check(game.current_heart_limit == 1 and game.heart_count == 1, "Retry restores the round-six one-heart allowance")
	game.queue_free()
	await process_frame
