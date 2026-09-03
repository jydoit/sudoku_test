extends SceneTree

const OUTPUT_PREFIX := "/private/tmp/color_king_lion_entry_"

var game
var runner: TextureRect


func _init() -> void:
	root.size = Vector2i(540, 960)
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	game = packed.instantiate()
	root.add_child(game)
	await _settle()
	if game.dialog_controller:
		game.dialog_controller.hide_dialog(true)
	game.localization.set_locale("zh")
	game.result_page.present_success({
		"excellent": false,
		"reward": 2,
		"coinBalanceBefore": 20,
		"coinBalance": 22,
		"displayLevel": 8,
	})
	game.result_page.show()
	await _settle()
	game.result_page.stop_all_animations()
	# Let the stopped live entrance finish its deferred queue_free before adding
	# the deterministic probe runner used by this capture tool.
	await _settle()
	if game.home_screen:
		game.home_screen.hide()
	_show_result_only()
	game.result_page.result_piece_icon.hide()
	game.result_page.result_lion_entry_layer.show()
	_ensure_probe_runner()

	var target: Vector2 = game.result_page._control_center_in_layer(
		game.result_page.result_piece_icon,
		game.result_page.result_lion_entry_layer
	)
	var profile_spec := {}
	for spec in [
		{
			"name": "left",
			"variant": "peek_left",
			"support": Vector2(0, 480),
			"start": Vector2(210 * (0.5 - game.result_page.RESULT_LION_LEFT_SUPPORT_RATIO), 480),
			"curve": Vector2(210, target.y - 142),
		},
		{
			"name": "right",
			"variant": "peek_right",
			"support": Vector2(540, 480),
			"start": Vector2(540 - 210 * (game.result_page.RESULT_LION_RIGHT_SUPPORT_RATIO - 0.5), 480),
			"curve": Vector2(330, target.y - 142),
		},
		{
			"name": "bottom",
			"variant": "peek_bottom",
			"support": Vector2(270, 960),
			"start": Vector2(270, 960 - 210 * (game.result_page.RESULT_LION_BOTTOM_SUPPORT_RATIO - 0.5)),
			"curve": Vector2(230, target.y - 168),
		},
	]:
		var direction_name := str(spec["name"])
		var variant := str(spec["variant"])
		var support: Vector2 = spec["support"]
		var start: Vector2 = spec["start"]
		var curve: Vector2 = spec["curve"]
		await _capture_peek("%s_01_peek" % direction_name, 0.0, support, variant)
		await _capture_peek("%s_02_revealed" % direction_name, 0.51, support, variant)
		await _capture_peek("%s_03_tease_hold" % direction_name, 0.70, support, variant)
		game.result_page._set_result_lion_entry_brace_progress(1.0, runner, support, variant)
		await _shot("%s_04_brace" % direction_name)
		await _capture_jump("%s_05_air" % direction_name, 0.52, start, curve, target, variant)
		profile_spec = spec
	_ensure_probe_runner()
	await _profile_entry_animation(
		profile_spec["support"],
		profile_spec["start"],
		profile_spec["curve"],
		target,
		str(profile_spec["variant"])
	)
	_ensure_probe_runner()
	await _capture_handoff_and_center_actions(target)
	quit()


func _ensure_probe_runner() -> void:
	if is_instance_valid(runner):
		return
	runner = game.result_page._piece_texture_rect(Vector2(210, 210), game.result_page.LION_LEFT_ENTRY_00)
	runner.size = Vector2(210, 210)
	runner.pivot_offset = runner.size * 0.5
	game.result_page.result_lion_entry_layer.add_child(runner)
	var runner_frame_animation: ResultLionFrameAnimator = game.result_page.ResultLionFrameAnimatorScript.new()
	runner_frame_animation.name = "ResultLionRunnerFrameAnimation"
	runner.add_child(runner_frame_animation)
	runner_frame_animation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	runner_frame_animation.show_behind_parent = false
	runner_frame_animation.hide()
	var peek_blink: TextureRect = game.result_page._piece_texture_rect(Vector2.ZERO, game.result_page.LION_LEFT_PEEK_BLINK)
	peek_blink.name = "ResultLionPeekBlink"
	runner.add_child(peek_blink)
	peek_blink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	peek_blink.hide()


func _capture_peek(name: String, progress: float, support: Vector2, variant: String) -> void:
	game.result_page._set_result_lion_entry_peek_progress(progress, runner, support, variant)
	await _shot(name)


func _capture_jump(name: String, progress: float, start: Vector2, curve: Vector2, target: Vector2, variant: String) -> void:
	game.result_page._set_result_lion_entry_jump_progress(progress, runner, start, curve, target, variant)
	await _shot(name)


func _profile_entry_animation(support: Vector2, start: Vector2, curve: Vector2, target: Vector2, variant: String) -> void:
	var peek_duration: float = game.result_page.RESULT_LION_PEEK_DURATION
	var brace_duration: float = game.result_page.RESULT_LION_SQUAT_DURATION
	var jump_duration: float = game.result_page.RESULT_LION_JUMP_DURATION
	var total_duration := peek_duration + brace_duration + jump_duration
	var baseline_started_at := Time.get_ticks_usec()
	var baseline_process_ms_total := 0.0
	var baseline_process_ms_peak := 0.0
	var baseline_samples := 0
	while float(Time.get_ticks_usec() - baseline_started_at) / 1000000.0 < total_duration:
		await process_frame
		var baseline_process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		baseline_process_ms_total += baseline_process_ms
		baseline_process_ms_peak = maxf(baseline_process_ms_peak, baseline_process_ms)
		baseline_samples += 1
	_ensure_probe_runner()
	var started_at := Time.get_ticks_usec()
	var process_ms_total := 0.0
	var process_ms_peak := 0.0
	var draw_calls_peak := 0
	var samples := 0
	while true:
		_ensure_probe_runner()
		var elapsed := float(Time.get_ticks_usec() - started_at) / 1000000.0
		if elapsed >= total_duration:
			break
		if elapsed < peek_duration:
			game.result_page._set_result_lion_entry_peek_progress(elapsed / peek_duration, runner, support, variant)
		elif elapsed < peek_duration + brace_duration:
			game.result_page._set_result_lion_entry_brace_progress(
				(elapsed - peek_duration) / brace_duration,
				runner,
				support,
				variant
			)
		else:
			game.result_page._set_result_lion_entry_jump_progress(
				(elapsed - peek_duration - brace_duration) / jump_duration,
				runner,
				start,
				curve,
				target,
				variant
			)
		await process_frame
		var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		process_ms_total += process_ms
		process_ms_peak = maxf(process_ms_peak, process_ms)
		draw_calls_peak = maxi(
			draw_calls_peak,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		)
		samples += 1
	print(JSON.stringify({
		"lion_directional_profile": {
			"baseline_average_process_ms": baseline_process_ms_total / maxf(1.0, float(baseline_samples)),
			"baseline_peak_process_ms": baseline_process_ms_peak,
			"samples": samples,
			"average_process_ms": process_ms_total / maxf(1.0, float(samples)),
			"peak_process_ms": process_ms_peak,
			"peak_total_draw_calls": draw_calls_peak,
			"static_memory_mb": float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
			"runner_nodes": game.result_page.result_lion_entry_layer.get_child_count(),
		}
	}))


func _capture_handoff_and_center_actions(_target: Vector2) -> void:
	game.result_page.result_piece_icon.show()
	game.result_page._show_center_result_lion_idle()
	await _settle()
	var handoff_target: Vector2 = game.result_page._control_center_in_layer(
		game.result_page.result_piece_icon,
		game.result_page.result_lion_entry_layer
	)
	game.result_page.result_piece_icon.modulate.a = 0.0
	runner.show()
	runner.modulate = Color.WHITE
	for sample in [0.0, 0.18, 0.50, 1.0]:
		game.result_page._set_result_lion_land_progress(
			sample,
			runner,
			handoff_target,
			"peek_bottom"
		)
		await _shot("handoff_land_%03d" % roundi(sample * 100.0))
	for sample in [0.0, 0.58, 0.78, 1.0]:
		game.result_page._set_result_lion_arrival_progress(sample, runner, handoff_target, 0)
		await _shot("handoff_arrival_%03d" % roundi(sample * 100.0))
	runner.hide()
	game.result_page.result_piece_icon.modulate = Color.WHITE
	for action_name in ["coin_toss"]:
		var action_length: float = game.result_page.result_lion_frame_animation.action_length(action_name)
		for sample in [0.0, 0.25, 0.5, 0.75, 1.0]:
			game.result_page.result_lion_frame_animation.play_action(action_name)
			game.result_page.result_lion_frame_animation.animation_player.seek(
				action_length * sample,
				true
			)
			game.result_page.result_lion_frame_animation.animation_player.pause()
			await _shot("center_%s_%03d" % [action_name, roundi(sample * 100.0)])
	game.result_page.result_lion_frame_animation.set_idle_pose()
	var scatter_source: Vector2 = game.result_page._control_point_in_flight_layer(
		game.result_page.result_piece_icon,
		Vector2(
			game.result_page.result_piece_icon.size.x * 0.50,
			game.result_page.result_piece_icon.size.y * 0.07
		)
	)
	game.result_page._launch_result_coin_scatter(scatter_source)
	await _timed_shot("center_coin_scatter_040", 0.04)
	await _timed_shot("center_coin_scatter_120", 0.08)
	await _timed_shot("center_coin_scatter_240", 0.12)
	game.result_page.stop_coin_animation()


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	await process_frame


func _shot(name: String) -> void:
	_show_result_only()
	await _settle()
	root.get_texture().get_image().save_png("%s%s.png" % [OUTPUT_PREFIX, name])


func _timed_shot(name: String, wait_duration: float) -> void:
	await create_timer(wait_duration).timeout
	_show_result_only()
	await process_frame
	root.get_texture().get_image().save_png("%s%s.png" % [OUTPUT_PREFIX, name])


func _show_result_only() -> void:
	for child in game.get_children():
		if child != game.result_page and child is CanvasItem:
			child.hide()
	game.result_page.show()
	game.result_page.move_to_front()
