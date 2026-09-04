extends SceneTree

const SplashOverlayScript = preload("res://scripts/overlays/splash_overlay.gd")
const SPLASH_SOURCE_FRAME_INDICES := [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var splash = SplashOverlayScript.new()
	root.add_child(splash)
	splash.configure()
	assert(splash.SPLASH_FRAMES.size() == 13, "Splash should retain the thirteen consistent assembly keyframes")
	assert(SPLASH_SOURCE_FRAME_INDICES.size() == splash.SPLASH_FRAMES.size(), "Runtime splash frames should map to their retained source indices")
	assert(splash.SPLASH_FRAME_TIMES.size() == splash.SPLASH_FRAMES.size(), "Every splash frame should own one timeline key")
	var normal_total: float = splash.SPLASH_REVEAL_DURATION + splash.SPLASH_FINISH_DURATION
	var reduced_total: float = splash.SPLASH_REDUCED_DURATION + splash.SPLASH_FINISH_DURATION
	assert(is_equal_approx(normal_total, 6.0), "Normal splash should keep the approved six-second pacing")
	assert(splash.SPLASH_REVEAL_DURATION - splash.SPLASH_FRAME_TIMES[-1] >= 0.5, "Final brand composition should hold before fading")
	assert(is_equal_approx(reduced_total, 2.1), "Reduced-motion splash should remain readable without inheriting the long motion timeline")
	for frame_index in range(splash.SPLASH_FRAMES.size()):
		var image: Image = splash.SPLASH_FRAMES[frame_index].get_image()
		assert(not image.is_empty() and image.get_size() == Vector2i(320, 320), "Every splash keyframe should keep the registered 320px canvas")
		var source_frame_index: int = SPLASH_SOURCE_FRAME_INDICES[frame_index]
		var svg_path := "res://assets/ui/splash/splash_assembly_%02d.svg" % source_frame_index
		var svg_source := FileAccess.get_file_as_string(svg_path)
		assert("<path" in svg_source and "<image" not in svg_source, "Every runtime splash keyframe must be a pure-path SVG")
		assert(not FileAccess.file_exists("res://assets/ui/splash/splash_assembly_%02d.png" % source_frame_index), "Runtime splash assets must not retain raster keyframes")
		if frame_index > 0:
			assert(splash.SPLASH_FRAME_TIMES[frame_index] > splash.SPLASH_FRAME_TIMES[frame_index - 1], "Splash frame times must advance monotonically")
	assert(splash.SPLASH_FRAMES[-1] == splash.SPLASH_FRAME_12, "The placed blocks must remain unchanged in the final board")
	assert(not FileAccess.file_exists("res://assets/ui/splash/splash_assembly_13.svg"), "The inconsistent redrawn transition frame must stay retired")
	assert(not FileAccess.file_exists("res://assets/ui/splash/splash_assembly_14.svg"), "Duplicate splash frame 14 must stay removed")
	assert(not FileAccess.file_exists("res://assets/ui/splash/splash_assembly_15.svg"), "The inconsistent redrawn terminal frame must stay retired")
	for terminal_frame_index in [11, 12]:
		var terminal_svg_source := FileAccess.get_file_as_string(
			"res://assets/ui/splash/splash_assembly_%02d.svg" % terminal_frame_index
		)
		assert("id=\"terminal-pink-l-footprint\"" in terminal_svg_source, "Both completed-board frames must preserve the incoming pink L footprint")
		assert("data-terminal-cells=\"4,5 5,4 5,5\"" in terminal_svg_source, "The terminal pink region must contain all three cells of the incoming L piece")
	var splash_processor_source := FileAccess.get_file_as_string("res://tools/process_splash_sprite_sheet.py")
	assert("RUNTIME_FRAME_COUNT = 13" in splash_processor_source, "Offline splash regeneration must not restore inconsistent frames 13-15")
	assert("INCOMING_PIECE_FOOTPRINTS" in splash_processor_source and "TERMINAL_REGION_CELLS" in splash_processor_source, "Offline splash regeneration must validate every incoming piece against its same-color terminal region")
	assert("_validate_terminal_piece_geometry()" in splash_processor_source, "Offline splash generation must enforce piece-to-region geometry before writing frames")
	var lion_svg_source := FileAccess.get_file_as_string("res://assets/ui/lion_king_center_body.svg")
	assert("<path" in lion_svg_source and "<image" not in lion_svg_source, "Final mascot must remain a pure-path SVG")
	var title_svg_source := FileAccess.get_file_as_string("res://assets/ui/splash/color_king_title.svg")
	assert("<path" in title_svg_source and "<text" not in title_svg_source and "<image" not in title_svg_source, "Splash title must be device-independent pure vector paths")
	var ios_launch_svg_source := FileAccess.get_file_as_string("res://assets/ui/ios_launch_blank.svg")
	assert("#2D7DBB" in ios_launch_svg_source and "fill-opacity=\"0\"" not in ios_launch_svg_source, "iOS launch placeholder must remain opaque and match the native blue background")
	var export_presets_source := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert(export_presets_source.count("storyboard/custom_image@2x=\"res://assets/ui/ios_launch_blank.svg\"") == 2, "Both iOS presets must override the template 2x Godot splash")
	assert(export_presets_source.count("storyboard/custom_image@3x=\"res://assets/ui/ios_launch_blank.svg\"") == 2, "Both iOS presets must override the template 3x Godot splash")
	var ios_prepare_source := FileAccess.get_file_as_string("res://tools/prepare_ios_export.sh")
	assert("CURRENT_PROJECT_VERSION" in ios_prepare_source and "ColorKingLaunchScreenV$build_version" in ios_prepare_source, "iOS export preparation must derive a versioned launch-screen cache key from the build number")
	assert("for stale_version in 0 1 2" in ios_prepare_source, "iOS export preparation must clean obsolete ColorKingLaunchScreen V0-V2 artifacts")
	assert("CFBundleSignature NSCameraUsageDescription NSMicrophoneUsageDescription NSPhotoLibraryUsageDescription" in ios_prepare_source, "iOS export preparation must remove unused empty metadata and privacy declarations")
	assert(splash.title_art is TextureRect, "Splash title should render as a responsive vector texture")
	assert(splash.animation_player.has_animation(&"splash_brand_reveal"), "Splash should own one AnimationPlayer brand timeline")
	assert(splash.animation_player.has_animation(&"splash_reduced"), "Splash should provide a reduced-motion timeline")
	assert(splash.animation_player.has_animation(&"splash_finish"), "Splash should own its input-releasing fade")

	splash.preview_frame(splash.SPLASH_FRAMES.size() - 1)
	assert(splash.current_frame_index() == 12, "Splash preview should end on the same board assembled by the incoming pieces")
	assert(splash.brand_coin_rect.texture.resource_path == "res://assets/ui/coin.svg" and splash.brand_coin_rect.modulate.a > 0.99, "Final splash preview should overlay the canonical crown coin without redrawing the board")
	assert(splash.lion_rect.modulate.a > 0.99, "Final splash preview should include the canonical vector mascot")
	assert(splash.title_art.modulate.a > 0.99, "Final splash preview should include the vector wordmark")
	var finish_count := [0]
	var skip_count := [0]
	splash.splash_finished.connect(func() -> void: finish_count[0] += 1)
	splash.splash_skipped.connect(func() -> void: skip_count[0] += 1)
	splash.begin(true)
	splash._skip_unlocked = true
	var skip_event := InputEventMouseButton.new()
	skip_event.button_index = MOUSE_BUTTON_LEFT
	skip_event.pressed = true
	splash._on_gui_input(skip_event)
	await process_frame
	assert(finish_count[0] == 0 and splash.root.visible, "Skip should hold the stable final frame until boot is ready")
	splash._on_gui_input(skip_event)
	assert(skip_count[0] == 1, "Repeated skip input must be ignored")
	splash.mark_ready_to_enter()
	await splash.splash_finished
	assert(finish_count[0] == 1, "Splash must release startup routing exactly once")
	assert(not splash.root.visible, "Finished splash should stop blocking the target page")
	splash.queue_free()
	print("SPLASH SMOKE TEST PASSED: preserved piece footprints, consistent terminal frames, reduced motion and one-shot routing")
	quit()
