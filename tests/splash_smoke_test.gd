extends SceneTree

const SplashOverlayScript = preload("res://scripts/overlays/splash_overlay.gd")
const SplashAssemblyBoardScript = preload("res://scripts/overlays/splash_assembly_board.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var splash = SplashOverlayScript.new()
	root.add_child(splash)
	splash.configure()
	var normal_total: float = splash.SPLASH_REVEAL_DURATION + splash.SPLASH_FINISH_DURATION
	var reduced_total: float = splash.SPLASH_REDUCED_DURATION + splash.SPLASH_FINISH_DURATION
	assert(is_equal_approx(normal_total, 6.0), "Normal splash should keep the approved six-second pacing")
	assert(splash.SPLASH_REVEAL_DURATION - splash.SPLASH_SKIP_UNLOCK_TIME >= 1.0, "The completed board and mascot should hold before fading")
	assert(is_equal_approx(reduced_total, 2.1), "Reduced-motion splash should remain readable without piece flight")
	assert(splash.SPLASH_PIECE_COUNT == 5, "The real Splash fixture should retain all five source pieces")
	assert(splash.SPLASH_ANIMATED_PIECE_COUNT == 2, "Only two representative pieces should visibly fly into place")
	assert(splash.SPLASH_KING_COUNT == 6, "The final 6x6 board should reveal every lion in its crown solution")

	var fixture: Dictionary = SplashAssemblyBoardScript.fixture_data()
	assert(str(fixture["sourceEntryKey"]) == "103:hard", "Splash should identify its baked real composite source entry")
	assert(fixture["pieces"].size() == splash.SPLASH_PIECE_COUNT, "The timeline piece count must match the fixture")
	assert(fixture["placementOrder"].size() == fixture["pieces"].size(), "Every fixture piece should appear exactly once in the placement timeline")
	assert(fixture["animatedPlacementOrder"].size() == splash.SPLASH_ANIMATED_PIECE_COUNT, "Exactly two real source pieces should be selected for visible placement")
	assert(fixture["animatedPlacementOrder"] + fixture["instantFillOrder"] == fixture["placementOrder"], "The two animated pieces and instant fill must preserve the real solution order")
	assert(fixture["solution"].size() == splash.SPLASH_KING_COUNT, "Every final lion reveal must come from the fixture solution")
	_validate_fixture_geometry(fixture)
	_validate_fixture_against_runtime_catalog(fixture)

	for retired_frame_index in range(16):
		assert(not FileAccess.file_exists("res://assets/ui/splash/splash_assembly_%02d.svg" % retired_frame_index), "The inconsistent hand-drawn Splash frame sequence must stay retired")
	assert(not FileAccess.file_exists("res://tools/process_splash_sprite_sheet.py"), "The retired hand-drawn frame processor must not return")
	var assembly_source := FileAccess.get_file_as_string("res://scripts/overlays/splash_assembly_board.gd")
	assert("SOURCE_ENTRY_KEY := \"103:hard\"" in assembly_source, "The data-driven Splash must keep its real catalog provenance visible")
	for tile_name in ["blue", "red", "green", "yellow", "purple", "orange", "empty"]:
		assert(FileAccess.file_exists("res://assets/ui/splash/splash_tile_%s.png" % tile_name), "Every original-style Splash tile should be exported as its own clean-color texture")
	assert("SPLASH_TILE_TEXTURES" in assembly_source and "SPLASH_EMPTY_TILE" in assembly_source, "Splash should render with the original full-color illustration tiles instead of tinting one neutral material")
	assert(not FileAccess.file_exists("res://assets/ui/splash/splash_tile_original_style.png"), "The muddy neutral-tint Splash texture must stay removed")
	assert("HAPPY_LION_TEXTURE" in assembly_source, "The completed board should reveal the canonical happy lion markers")
	assert("func _draw_dock" not in assembly_source and "ASSEMBLY_TRAY" not in assembly_source, "Splash must not show a lower pending-piece tray")
	assert("MOTION_TRAIL_SEGMENTS" not in assembly_source and "SPLASH_BOARD_GLOW" not in assembly_source, "The reverted first-edition art must not keep the later realistic glow and ribbon effects")
	assert("PIECE_START_CENTERS" in assembly_source and "_draw_piece_centered" in assembly_source, "Exactly two selected real pieces should be presented below the board before placement")
	assert("ANIME_STREAK_COUNT := 3" in assembly_source and "ANIME_IMPACT_RAY_COUNT := 10" in assembly_source, "The two demonstrated pieces should use restrained anime motion accents")
	assert("func _draw_anime_motion_streaks" in assembly_source and "func _draw_anime_impact_burst" in assembly_source, "Anime accents should remain deterministic code-driven effects")
	assert("CRYSTAL_SURFACE" in assembly_source and "func _draw_crystal_facets" in assembly_source, "The board should retain its lightweight illustrated crystal frame")
	assert("set_border_width_all(8)" in assembly_source, "The outer crystal refraction band should remain visibly wide")
	assert("WOOD_EDGE_SHADE_ALPHA := 0.38" in assembly_source and "func _draw_wood_bevel" in assembly_source, "Every colored tile should retain strong edge shading and a four-sided wood bevel")
	assert("func _draw_wood_grain" in assembly_source, "Colored Splash tiles should retain deterministic low-contrast wood grain")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/overlays/splash_overlay.gd")
	assert("func _splash_background_texture" in overlay_source and "SPLASH_SKY_TOP" in overlay_source, "Splash should use its own lower-saturation sky without changing shared royal screens")

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
	assert(splash.assembly_board is SplashAssemblyBoard, "Splash should render assembly from one data-driven Control")
	assert(splash.title_art is TextureRect, "Splash title should render as a responsive vector texture")
	assert(splash.animation_player.has_animation(&"splash_brand_reveal"), "Splash should own one AnimationPlayer brand timeline")
	assert(splash.animation_player.has_animation(&"splash_reduced"), "Splash should provide a reduced-motion timeline")
	assert(splash.animation_player.has_animation(&"splash_finish"), "Splash should own its input-releasing fade")

	for animated_stage in range(splash.SPLASH_ANIMATED_PIECE_COUNT + 1):
		splash.preview_stage(animated_stage)
		var expected_count: int = splash.SPLASH_PIECE_COUNT if animated_stage == splash.SPLASH_ANIMATED_PIECE_COUNT else animated_stage
		assert(splash.current_placed_piece_count() == expected_count, "The first placement must persist and the second must atomically complete the real board")
		assert(is_zero_approx(float(splash.assembly_board.king_reveal_progress)), "Lion markers must wait until the same board is fully assembled")
	splash.preview_stage(splash.PREVIEW_STAGE_COUNT - 1)
	assert(splash.current_placed_piece_count() == splash.SPLASH_PIECE_COUNT, "Final preview should retain every piece placed by the same timeline")
	assert(is_equal_approx(float(splash.assembly_board.flatten_amount), 1.0), "Final preview should flatten the same assembled cells without swapping boards")
	assert(is_equal_approx(float(splash.assembly_board.king_reveal_progress), float(splash.SPLASH_KING_COUNT)), "Final preview should show all six happy lion markers")
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
	assert(finish_count[0] == 0 and splash.root.visible, "Skip should hold the stable final state until boot is ready")
	assert(splash.current_placed_piece_count() == splash.SPLASH_PIECE_COUNT, "Skip should resolve to the same fully assembled board")
	assert(is_equal_approx(float(splash.assembly_board.king_reveal_progress), float(splash.SPLASH_KING_COUNT)), "Skip should resolve to the all-lions-found state")
	splash._on_gui_input(skip_event)
	assert(skip_count[0] == 1, "Repeated skip input must be ignored")
	splash.mark_ready_to_enter()
	await splash.splash_finished
	assert(finish_count[0] == 1, "Splash must release startup routing exactly once")
	assert(not splash.root.visible, "Finished splash should stop blocking the target page")
	splash.queue_free()
	print("SPLASH SMOKE TEST PASSED: two illustrated placements, atomic real-layout completion, all-lion reveal and one-shot routing")
	quit()


func _validate_fixture_geometry(fixture: Dictionary) -> void:
	var pieces_by_id := {}
	var piece_region_ids := {}
	for piece in fixture["pieces"]:
		var piece_id := int(piece["pieceId"])
		assert(not pieces_by_id.has(piece_id), "Fixture piece ids must be unique")
		pieces_by_id[piece_id] = piece
		piece_region_ids[int(piece["regionId"])] = true
	assert(piece_region_ids.size() == 3, "The Splash fixture should demonstrate three construction colors")
	var order_seen := {}
	for piece_id in fixture["placementOrder"]:
		assert(pieces_by_id.has(int(piece_id)) and not order_seen.has(int(piece_id)), "Placement order must reference each piece once")
		order_seen[int(piece_id)] = true

	var construction := {}
	for raw_cell in fixture["constructionCells"]:
		construction[Vector2i(int(raw_cell[1]), int(raw_cell[0]))] = true
	var covered := {}
	for piece in fixture["pieces"]:
		var origin: Array = piece["origin"]
		for raw_cell in piece["cells"]:
			var absolute := Vector2i(int(origin[1]) + int(raw_cell[1]), int(origin[0]) + int(raw_cell[0]))
			assert(construction.has(absolute), "Every animated piece cell must land in a real construction well")
			assert(not covered.has(absolute), "Animated pieces must never overlap")
			covered[absolute] = true
			assert(int(fixture["baseRegions"][absolute.y][absolute.x]) == int(piece["regionId"]), "Every piece cell must keep the same color after placement")
	assert(covered.size() == construction.size(), "Placed pieces must exactly fill the initial construction wells")
	for cell in construction.keys():
		assert(covered.has(cell), "No initial Splash shape may disappear from the terminal board")
	var rows_seen := {}
	var columns_seen := {}
	var regions_seen := {}
	var solution_cells: Array = []
	for raw_cell in fixture["solution"]:
		var cell := Vector2i(int(raw_cell[1]), int(raw_cell[0]))
		var region_id := int(fixture["baseRegions"][cell.y][cell.x])
		assert(not rows_seen.has(cell.y) and not columns_seen.has(cell.x) and not regions_seen.has(region_id), "Final lions must be unique by row, column and color region")
		for other_cell in solution_cells:
			assert(maxi(absi(cell.x - other_cell.x), absi(cell.y - other_cell.y)) > 1, "Final lions must not touch in any of eight directions")
		rows_seen[cell.y] = true
		columns_seen[cell.x] = true
		regions_seen[region_id] = true
		solution_cells.append(cell)


func _validate_fixture_against_runtime_catalog(fixture: Dictionary) -> void:
	var bundle = ResourceLoader.load("res://data/runtime/composite_size_6.res", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(bundle != null and bundle.get("entries") is Dictionary, "The 6x6 composite runtime bundle should be available")
	var source: Dictionary = bundle.get("entries").get(str(fixture["sourceEntryKey"]), {})
	assert(not source.is_empty(), "The baked Splash fixture must still exist in the real composite catalog")
	assert(source.get("baseRegions", []) == fixture["baseRegions"], "Splash board colors must match the real composite source entry")
	assert(source.get("constructionCells", []) == fixture["constructionCells"], "Splash wells must match the real composite source entry")
	var source_pieces_by_id := {}
	for source_piece in source.get("pieces", []):
		source_pieces_by_id[int(source_piece["pieceId"])] = source_piece
	var source_layouts: Array = source.get("validLayouts", [])
	assert(not source_layouts.is_empty(), "The source composite entry must retain a valid layout")
	assert(source_layouts[0].get("solution", []) == fixture["solution"], "Splash lion positions must match the real composite solution")
	var source_placements: Dictionary = source_layouts[0].get("placements", {})
	var source_order: Array = []
	for step in source.get("solutionOrder", []):
		source_order.append(int(step["pieceId"]))
	assert(source_order == fixture["placementOrder"], "Splash placement order must follow the real composite solution order")
	for piece in fixture["pieces"]:
		var piece_id := int(piece["pieceId"])
		var source_piece: Dictionary = source_pieces_by_id.get(piece_id, {})
		assert(not source_piece.is_empty(), "Every animated piece must come from the real composite source entry")
		assert(int(source_piece["regionId"]) == int(piece["regionId"]) and source_piece["cells"] == piece["cells"], "Animated piece color and shape must match the real source")
		assert(source_placements.get(str(piece_id), []) == piece["origin"], "Animated piece destination must match a valid real layout")
