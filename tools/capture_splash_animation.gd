extends SceneTree

const SplashOverlayScript = preload("res://scripts/overlays/splash_overlay.gd")
const CAPTURE_TIMES := [0.35, 0.85, 1.42, 2.04, 2.50, 3.00, 3.65]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var splash = SplashOverlayScript.new()
	root.add_child(splash)
	splash.configure()
	splash.begin(false)
	var process_samples: Array[float] = []
	var peak_draw_calls := 0
	for capture_index in range(CAPTURE_TIMES.size()):
		var target_time: float = CAPTURE_TIMES[capture_index]
		while splash.animation_player.current_animation_position < target_time:
			await process_frame
			process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			peak_draw_calls = maxi(
				peak_draw_calls,
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			)
		var image := root.get_texture().get_image()
		image.save_png("/private/tmp/color_king_splash_%02d.png" % capture_index)

	# Let the stable final frame own any loading hold, then release exactly once.
	splash.mark_ready_to_enter()
	await splash.splash_finished
	var average_ms := 0.0
	var peak_ms := 0.0
	for sample in process_samples:
		average_ms += sample
		peak_ms = maxf(peak_ms, sample)
	if not process_samples.is_empty():
		average_ms /= float(process_samples.size())
	print(JSON.stringify({
		"splash_profile": {
			"average_process_ms": average_ms,
			"peak_process_ms": peak_ms,
			"samples": process_samples.size(),
			"frame_count": splash.SPLASH_FRAMES.size(),
			"peak_draw_calls": peak_draw_calls,
		}
	}))
	quit()
