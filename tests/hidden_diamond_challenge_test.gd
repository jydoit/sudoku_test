extends SceneTree

const Policy = preload("res://scripts/services/hidden_diamond_policy.gd")
const Controller = preload("res://scripts/controllers/hidden_diamond_controller.gd")
const SaveService = preload("res://scripts/storage/game_save_service.gd")
const OUTPUT := "res://artifacts/release_validation/hidden_diamond_v2"
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error(message)


func _run() -> void:
	_test_policy()
	_test_controller()
	_test_time_baselines()
	await _test_commerce_pause()
	await _test_game_integration()
	print("HIDDEN DIAMOND CHALLENGE TARGETED TEST: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_policy() -> void:
	var progress := Policy.normalize({"seed": 42})
	_expect(is_equal_approx(Policy.dynamic_ratio(progress, "time"), 0.9), "Initial ratio must be 0.9")
	Policy.record_best(progress, "normal", 6, 100.0, 40)
	Policy.record_best(progress, "normal", 5, 5.0, 5)
	var state: Dictionary = progress["modes"]["normal"]
	state["next"] = 20
	state["lastKind"] = "moves"
	var context := {"mode": "normal", "ordinal": 20, "size": 6, "found": 0, "untouched": true}
	var event := Policy.consider(progress, context, [])
	_expect(event["kind"] == "time" and int(event["limit"]) == 63 and event["target"] == 6, "Same-size minimum × 0.7 × 0.9 must give 63 seconds and six lions")
	_expect(Policy.consider(progress, context, []).is_empty(), "Repeated entry cannot reroll a decision")
	Policy.record_outcome(progress, event, true)
	_expect(Policy.dynamic_ratio(progress, "time") < 0.9, "High achievement must tighten the next challenge")
	progress["outcomes"]["time"] = [false, false, false, false]
	_expect(Policy.dynamic_ratio(progress, "time") > 0.9, "Low achievement must loosen the next challenge")
	state["next"] = 21
	context["ordinal"] = 21
	event = Policy.consider(progress, context, [])
	_expect(event["kind"] == "moves" and int(event["limit"]) == 26, "Moves must use the same formula without a simultaneous timer")
	var cadence := Policy.normalize({"seed": 17})
	var offered: Array = []
	var first_thirty := 0
	var non_milestone := false
	for ordinal in range(1, 101):
		context["ordinal"] = ordinal
		event = Policy.consider(cadence, context, offered)
		if not event.is_empty():
			offered.append(event["id"])
			first_thirty += int(ordinal <= 30)
			non_milestone = non_milestone or ordinal % 10 != 0
			Policy.record_outcome(cadence, event, ordinal % 2 == 0)
	_expect(first_thirty in [1, 2] and non_milestone, "Cadence must vary and preserve only one or two early events")
	var legacy := Policy.normalize({})
	Policy.import_legacy_times(legacy, [{"completed": true, "size": 6, "elapsedSeconds": 80, "moves": 1}])
	_expect(legacy["bests"]["normal:6"]["seconds"] == 80 and legacy["bests"]["normal:6"]["moves"] == 0, "Broken legacy move metrics must not become a one-move challenge")
	_expect(progress["bests"]["normal:5"]["seconds"] == 0.0, "Implausibly short solves must not contaminate time records")
	progress["outcomes"]["time"] = [false, false, false, false, false, false, false, false, false, false, false, false]
	_expect(is_equal_approx(Policy.dynamic_ratio(progress, "time"), 2.0), "Repeated failures must be able to relax a timed target beyond the previous best")
	_expect(Policy.dynamic_ratio(progress, "moves") <= 1.35, "The time fix must not silently change move difficulty")
	_expect(Policy.minimum_time_limit(5) == 30 and Policy.minimum_time_limit(6) == 36 and Policy.minimum_time_limit(9) == 54, "Time protection must grow with board size")
	state["next"] = 42
	state["lastKind"] = "moves"
	context["ordinal"] = 42
	event = Policy.consider(progress, context, [])
	_expect(event["limit"] == 140, "Continuous failures must loosen a 100-second baseline to 140 seconds")


func _controller(kind: String) -> Node:
	var controller := Controller.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.progress["modes"]["normal"]["next"] = 20
	controller.progress["modes"]["normal"]["lastKind"] = "moves" if kind == "time" else "time"
	controller.prepare_board({"mode": "normal", "ordinal": 20, "size": 5, "found": 0}, true)
	controller.present_board()
	return controller


func _test_time_baselines() -> void:
	var controller := Controller.new()
	var old := {"seed": 17, "bests": {"normal:5": {"seconds": 2.0, "moves": 15}}, "modes": {"normal": {"checked": 27, "next": 45}}, "outcomes": {"time": [false]}}
	controller.restore(old, ["normal_level_20"], [
		{"completed": true, "size": 5, "elapsedSeconds": 2.0, "moves": 0},
		{"completed": true, "size": 5, "elapsedSeconds": 12.0, "hints": 1},
		{"completed": true, "size": 5, "elapsedSeconds": 13.0, "directFinds": 1},
		{"completed": true, "size": 5, "elapsedSeconds": 14.0, "mode": "manual"},
		{"completed": true, "size": 5, "elapsedSeconds": 18.0, "mode": "fixed"},
	])
	_expect(controller.progress["bests"]["normal:5"] == {"seconds": 18.0, "moves": 15}, "Existing contaminated records must rebuild time only, excluding anomalous, assisted and debug runs")
	_expect(controller.offered_ids == ["normal_level_20"] and controller.progress["modes"]["normal"]["next"] == 45 and controller.progress["outcomes"]["time"] == [false], "Time migration must preserve the reward ledger, cadence and outcomes")
	var migrated: Dictionary = controller.progress.duplicate(true)
	controller.restore(migrated, controller.offered_ids, [{"completed": true, "size": 5, "elapsedSeconds": 10.0}])
	_expect(controller.progress["bests"]["normal:5"]["seconds"] == 18.0, "Versioned baselines must not reimport legacy samples on every startup")
	controller.progress["modes"]["normal"]["next"] = 28
	controller.progress["modes"]["normal"]["lastKind"] = "moves"
	controller.prepare_board({"mode": "normal", "ordinal": 28, "size": 5, "found": 0}, true)
	controller.present_board()
	_expect(controller.event["limit"] == 30, "The player's 18-second record must get the new 30-second playable minimum, not 10 seconds")
	controller.free()

	controller = _controller("time")
	controller.begin_challenge()
	controller._measure_started_msec = Time.get_ticks_msec() - 60000
	controller._process(0.001)
	_expect(controller._elapsed >= 60.0 and controller._elapsed < 61.0, "Historical time must use elapsed wall seconds even if frame delta is tiny")
	var start: int = controller._measure_started_msec
	controller.present_board()
	_expect(controller._measure_started_msec == start, "Refreshing an already presented board cannot reset its time measurement")
	controller.record_action(5, "assist")
	controller.complete_board()
	_expect(controller.progress["bests"]["normal:5"]["seconds"] == 0.0, "Assisted solves may still win the challenge but cannot tighten future time baselines")
	controller.free()


func _test_controller() -> void:
	var controller = _controller("moves")
	var outcomes: Array = []
	controller.settled.connect(func(won: bool, reward: int) -> void: outcomes.append([won, reward]))
	controller._process(10.0)
	_expect(controller.phase == "intro" and controller._elapsed == 0.0 and controller._deadline_msec == 0, "Intro cannot spend gameplay time or steps")
	controller.event["limit"] = 5
	controller.begin_challenge()
	for found in range(1, 6):
		controller.record_action(found - 1, "tap", Vector2i(found, 0))
		controller.record_action(found, "double", Vector2i(found, 0))
	_expect(controller._moves == 5 and outcomes == [[true, 1]], "Five double taps must cost five moves and award immediately on the last move")
	controller.suspend()
	controller.suspend()
	_expect(outcomes == [[true, 1]], "Background after success cannot duplicate or revoke the award")
	controller.free()
	controller = _controller("moves")
	controller.event["limit"] = 1
	controller.begin_challenge()
	controller.record_action(0, "tap", Vector2i(0, 0))
	controller.record_action(5, "double", Vector2i(1, 0))
	_expect(controller.phase == "resolved" and controller.progress["outcomes"]["moves"] == [false], "A different-cell action cannot borrow the prior tap's final step")
	controller.free()
	controller = _controller("time")
	controller.begin_challenge()
	controller._deadline_msec = Time.get_ticks_msec() - 1
	controller.record_action(5)
	_expect(controller.progress["outcomes"]["time"] == [false], "An action after the deadline cannot award even before the next process tick")
	controller.free()
	controller = _controller("time")
	var saved: Dictionary = controller.progress.duplicate(true)
	var ids: Array = controller.offered_ids.duplicate()
	controller.suspend()
	_expect(controller.phase == "resolved" and controller._deadline_msec == 0, "Background during intro must end the offer")
	controller.free()
	controller = Controller.new()
	controller.restore(saved, ids, [])
	_expect(controller.progress["pending"].is_empty() and controller.progress["outcomes"]["time"] == [false], "Process death must retire the persisted unfinished event")
	controller.prepare_board({"mode": "normal", "ordinal": 20, "size": 5, "found": 0}, false)
	controller.present_board()
	_expect(controller.phase == "idle", "Reload cannot reoffer the same challenge")
	controller.free()


func _test_game_integration() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	# A unique disposable save keeps this check isolated from player data.
	ProjectSettings.set_setting("color_king/testing/save_path", "%s/test-%d.json" % [OUTPUT, Time.get_ticks_usec()])
	ProjectSettings.set_setting("color_king/splash/disabled", true)
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	game.debug_level_selection_enabled = false
	root.add_child(game)
	await process_frame
	game.tutorial_completed = true
	game.tutorial_started = false
	game.hidden_diamond_controller.progress["modes"]["normal"]["next"] = 20
	game.hidden_diamond_controller.progress["modes"]["normal"]["lastKind"] = "time"
	var schedule: Dictionary = game._schedule_for_manual_level(0)
	schedule["displayLevel"] = 20
	schedule["kingPositions"] = []
	game._load_level(0, false, schedule)
	game._show_game()
	await process_frame
	await process_frame
	_expect(game.hidden_diamond_overlay.visible and game.hidden_diamond_controller.phase == "intro", "The fresh board must announce the challenge")
	var states: Array = game.cell_states.duplicate(true)
	var solutions: Array = game.current_level["solution"].duplicate(true)
	game._on_cell_double_pressed(int(solutions[0][0]), int(solutions[0][1]))
	_expect(game.cell_states == states, "The intro must block underlying input")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.25).timeout
		await _capture("intro.png")
	await create_timer(1.4).timeout
	_expect(not game.hidden_diamond_overlay.visible and game.hidden_diamond_controller.phase == "active", "Prompt must automatically disappear and only then activate the challenge")
	_expect(game.game_screen.hidden_diamond_hud.visible and not game.progress_row.visible, "The compact challenge HUD must replace, not duplicate, the progress row")
	_expect(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(game.game_screen.hidden_diamond_hud.get_global_rect()), "Challenge HUD must fit the mobile viewport")
	_expect(game.hidden_diamond_controller._deadline_msec == 0, "Move challenges must not have a timer")
	if DisplayServer.get_name() != "headless":
		await _capture("moves-540x960.png")
		root.size = Vector2i(540, 1170)
		await process_frame
		await process_frame
		await _capture("moves-540x1170.png")
	var balance: int = game.player_wallet.diamond_balance
	game.heart_count = 1
	game.hidden_diamond_controller.event["limit"] = solutions.size()
	for cell in solutions:
		game._on_cell_pressed(int(cell[0]), int(cell[1]))
		game._on_cell_double_pressed(int(cell[0]), int(cell[1]))
	_expect(game.player_wallet.diamond_balance == balance + 1 and game.is_completed, "Actual board completion must immediately settle one diamond")
	_expect(game.hidden_diamond_controller._moves == solutions.size(), "The real double-tap signal path must count one move per lion")
	_expect(not game.game_screen.hidden_diamond_hud.visible, "Settled challenge UI must be removed")
	var saved: Dictionary = game.save_repository.load_data()
	var normalized := SaveService.normalize_loaded(saved, {}, "2026-10-05")
	_expect(int(normalized["diamondCount"]) == balance + 1 and normalized["hiddenDiamondEventIds"].has("normal_level_20"), "The diamond and event identity must survive serialization together")
	_expect(normalized["hiddenDiamondProgress"]["pending"].is_empty() and normalized["hiddenDiamondProgress"]["outcomes"]["moves"] == [true], "Settled event history must survive save normalization without a resumable timer")
	await create_timer(game.board.victory_result_delay() + 0.2).timeout
	game.hidden_diamond_controller.progress["modes"]["normal"]["next"] = 21
	# Reproduce the player's valid baseline after the old 2-second record is
	# filtered out; this must display the new 30-second protection.
	game.hidden_diamond_controller.progress["bests"]["normal:5"]["seconds"] = 18.0
	schedule["displayLevel"] = 21
	game._load_level(0, false, schedule)
	game._show_game()
	await process_frame
	await create_timer(1.4).timeout
	_expect(game.hidden_diamond_controller.event["kind"] == "time" and game.hidden_diamond_controller._deadline_msec > 0, "A time challenge must start only its own countdown")
	_expect(game.hidden_diamond_controller.event["limit"] == 30, "The migrated 5x5 history must have a 30-second challenge")
	var before_shop: Array = game.cell_states.duplicate(true)
	var seconds_before_shop: int = game.hidden_diamond_controller._seconds_left()
	game._show_coin_shortage_dialog("hint", 10)
	await create_timer(0.1).timeout
	game.dialog_controller._activate_action("purchase")
	await process_frame
	_expect(game.shop_page.visible and game._shop_return_to_game and game.hidden_diamond_controller.is_paused(), "Shortage-to-shop transition must retain a pause and return destination")
	_expect(game.hidden_diamond_controller.phase == "active", "Shop cannot fail an active challenge")
	_expect(game.shop_page._home_button.tooltip_text == game._t("返回关卡"), "In-level shop uses a return-to-level control")
	_expect(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(game.shop_page._home_button.get_global_rect()), "Return button must fit the existing mobile safe layout")
	await create_timer(0.1).timeout
	game._close_shop()
	_expect(not game.hidden_diamond_controller.is_paused() and game.hidden_diamond_controller.phase == "active", "Closing shop must resume the same challenge")
	_expect(game.cell_states == before_shop and game.hidden_diamond_controller._seconds_left() == seconds_before_shop, "Shop preserves board and remaining seconds")
	game._show_coin_shortage_dialog("hint", 10)
	game.dialog_controller._activate_action("later")
	await process_frame
	_expect(not game.hidden_diamond_controller.is_paused(), "Cancelling shortage releases its pause")
	game._show_coin_shortage_dialog("hint", 10)
	game.dialog_controller._activate_action("rewarded")
	await process_frame
	_expect(not game.hidden_diamond_controller.is_paused() and game.player_wallet.diamond_balance == balance + 1, "Unavailable ad adapter resumes without awarding mock currency")
	var callbacks: Array = []
	game.rewarded_ad_requested.connect(func(finished: Callable) -> void: callbacks.append(finished))
	game._show_coin_shortage_dialog("hint", 10)
	game.dialog_controller._activate_action("rewarded")
	await process_frame
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_expect(game.hidden_diamond_controller.phase == "active" and game.hidden_diamond_controller.is_paused(), "A known external ad's focus loss must pause, not cancel")
	callbacks[0].call()
	callbacks[0].call()
	_expect(game.hidden_diamond_controller.is_paused(), "Ad close callback cannot resume before application focus returns")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_expect(not game.hidden_diamond_controller.is_paused() and game.hidden_diamond_controller.phase == "active", "External flow fully closes before challenge resumes")
	game._request_rewarded_ad()
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(game.hidden_diamond_controller.is_paused(), "Returning focus before ad closure must not resume the board")
	callbacks[1].call()
	_expect(not game.hidden_diamond_controller.is_paused(), "Ad closure after focus also releases its pause")
	if DisplayServer.get_name() != "headless":
		await _capture("time-540x1170.png")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await process_frame
	_expect(not game.hidden_diamond_overlay.visible and not game.game_screen.hidden_diamond_hud.visible and game.progress_row.visible, "Resume must restore ordinary gameplay without any challenge counters")
	_expect(game.player_wallet.diamond_balance == balance + 1, "Interrupted challenge must not add another diamond")
	var normal_mode: Dictionary = game.hidden_diamond_controller.progress["modes"]["normal"].duplicate(true)
	game.home_composite_entry_active = true
	game.home_composite_round = 10
	game.composite_mode = true
	for stage in ["assembly", "transition"]:
		game.composite_phase = stage
		game._maybe_start_hidden_diamond_event()
		_expect(int(game.hidden_diamond_controller.progress["modes"]["composite"]["checked"]) == 0, "Assembly and transition must not evaluate or consume independent challenge eligibility")
	_expect(game.hidden_diamond_controller.progress["modes"]["normal"] == normal_mode, "Block-stage gating must not mutate the normal cadence")
	game.queue_free()
	await process_frame


func _test_commerce_pause() -> void:
	var controller = _controller("time")
	controller.begin_challenge()
	var before: int = controller._seconds_left()
	controller.pause_for("coin_shortage")
	controller.pause_for("shop")
	controller.pause_for("shop")
	controller.resume_after("coin_shortage")
	var elapsed: float = controller._measured_seconds()
	await create_timer(0.08).timeout
	controller._process(100.0)
	controller.record_action(5)
	_expect(controller._seconds_left() == before and controller._measured_seconds() == elapsed and controller._moves == 0, "Commerce pause freezes timer, baseline clock and board moves")
	controller.resume_after("shop")
	controller.resume_after("shop")
	_expect(not controller.is_paused() and controller._seconds_left() == before, "Repeated callbacks cannot add time or leave a stuck pause")
	controller.pause_for("purchase")
	controller.suspend()
	controller.resume_after("purchase")
	_expect(controller.phase == "resolved" and not controller.is_paused(), "Cancellation discards pause receipts; late callbacks cannot revive a challenge")
	controller.free()
	controller = _controller("moves")
	controller.begin_challenge()
	controller.pause_for("shop")
	controller.record_action(1)
	_expect(controller._moves == 0 and controller._deadline_msec == 0, "A moves challenge stays frozen without acquiring a time deadline")
	controller.resume_after("shop")
	controller.record_action(1)
	_expect(controller._moves == 1, "Moves resume once the commerce screen is closed")
	controller.free()
	controller = _controller("time")
	controller.pause_for("shop")
	controller.begin_challenge()
	_expect(controller.phase == "intro", "An intro dismissed under a commerce screen cannot start the timer")
	controller.resume_after("shop")
	_expect(controller.phase == "active", "Deferred intro starts only when the commerce screen closes")
	controller._deadline_msec = Time.get_ticks_msec() - 1
	controller.pause_for("shop")
	_expect(controller.phase == "resolved", "An already expired challenge cannot be rescued by opening shop")
	controller.free()


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.save_png(OUTPUT.path_join(filename)) == OK, "Preview screenshot must be saved")
