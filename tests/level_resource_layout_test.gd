extends SceneTree

## Isolated page geometry only: never opens main or touches a player save.
const Page = preload("res://scripts/pages/level_page_base.gd")
const Tokens = preload("res://scripts/ui_tokens.gd")
const OUTPUT := "res://artifacts/release_validation/diamond_topbar"
var _failures := 0
var _cases := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_size = Vector2i(540, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	RenderingServer.set_default_clear_color(Tokens.SURFACE_CREAM)
	for dimensions in [Vector2i(540, 960), Vector2i(540, 1170), Vector2i(393, 852), Vector2i(1290, 2796)]:
		root.size = dimensions
		await process_frame
		for composite in [false, true]:
			for debug_select in [false, true]:
				for tutorial in [false, true]:
					for balance in [0, 12345]:
						await _case(dimensions, composite, debug_select, tutorial, balance)
	var insets := Tokens.scaled_safe_insets(Rect2i(0, 177, 1290, 2517), Vector2i(1290, 2796), Vector2(540, 1170.4186))
	_expect(is_equal_approx(insets.y, 177.0 * 540.0 / 1290.0), "Physical phone safe-area top inset must convert to logical UI coordinates")
	_expect(is_equal_approx(insets.w, 102.0 * 540.0 / 1290.0), "Physical phone safe-area bottom inset must convert to logical UI coordinates")
	print("LEVEL RESOURCE LAYOUT: %d cases, %d failures" % [_cases, _failures])
	quit(1 if _failures else 0)


func _case(dimensions: Vector2i, composite: bool, debug_select: bool, tutorial: bool, balance: int) -> void:
	var page = Page.new()
	root.add_child(page)
	page.setup(19, composite, Callable(), debug_select)
	page.set_diamond_balance(balance)
	page.set_level_copy("新手教程" if tutorial else ("拼块 27" if composite else "关卡 27"), "", Tokens.INK)
	page.tutorial_skip_button.text = "跳过"
	page.tutorial_skip_button.visible = tutorial
	# Mirror main::_update_tutorial_button: tutorials and independent composite
	# rounds intentionally suppress manual level selection.
	if page.level_select_button:
		page.level_select_button.visible = debug_select and not tutorial and not composite
	page.set_hearts(2, 3)
	page.set_progress(2, 5)
	if composite:
		page.assembly_view.hide()
	var level := {"rows": 5, "cols": 5, "regions": [[2, 2, 1, 1, 1], [2, 2, 1, 3, 3], [6, 2, 3, 3, 5], [6, 4, 3, 5, 5], [6, 4, 4, 4, 5]]}
	var states: Array = []
	for row in 5:
		var cells: Array = []
		cells.resize(5)
		cells.fill("empty")
		states.append(cells)
	states[2][3] = "piece"
	states[4][4] = "piece"
	states[0][0] = "blocked"
	states[0][1] = "blocked"
	page.board.set_level(level, states, Tokens.REGION_COLORS)
	await process_frame
	await process_frame
	await process_frame
	_cases += 1
	var context := "%s composite=%s debug=%s tutorial=%s diamonds=%d" % [dimensions, composite, debug_select, tutorial, balance]
	var viewport_rect: Rect2 = root.get_visible_rect()
	var top: Control = page.find_child("LevelTopBar", true, false)
	var badge: Control = page.find_child("LevelDiamondBalance", true, false)
	var header: Control = page.find_child("LevelHeader", true, false)
	_expect(not (page.tutorial_skip_button.visible and page.level_select_button and page.level_select_button.visible), "Tutorial skip and manual selection must remain exclusive: " + context)
	_expect(viewport_rect.grow(0.5).encloses(top.get_global_rect()), "Top bar outside viewport: %s viewport=%s top=%s" % [context, viewport_rect, top.get_global_rect()])
	_expect(badge.get_parent() == page.settings_button.get_parent(), "Diamond must be in the same top row as settings: " + context)
	_expect(page.level_heart_label.get_global_rect().end.x <= badge.get_global_rect().position.x + 0.5, "Diamond must follow hearts: " + context)
	_expect(badge.get_global_rect().end.x <= page.settings_button.get_global_rect().position.x + 0.5, "Diamond must precede settings without overlap: " + context)
	_expect(header.get_global_rect().position.y >= top.get_global_rect().end.y, "Level header must remain below top resources: " + context)
	_expect(badge.get_global_rect().grow(0.5).encloses(page.diamond_balance_label.get_global_rect()), "Diamond digits must fit badge: " + context)
	_expect(page.diamond_balance_label.size.x + 0.5 >= page.diamond_balance_label.get_minimum_size().x, "Diamond digits must not truncate: " + context)
	_expect(badge.get_global_rect().grow(0.5).encloses((badge.get_child(0) as Control).get_global_rect()), "Diamond icon must fit badge: " + context)
	var row: Control = badge.get_parent()
	var previous: Control
	for child in row.get_children():
		if child is Control and child.visible:
			var rect: Rect2 = child.get_global_rect()
			_expect(top.get_global_rect().grow(0.5).encloses(rect), "Visible top child outside bar: %s child=%s rect=%s" % [context, child.name, rect])
			if previous:
				_expect(previous.get_global_rect().end.x <= rect.position.x + 0.5, "Overlapping top controls: %s %s/%s" % [context, previous.name, child.name])
			previous = child
	if DisplayServer.get_name() != "headless" and dimensions.x == 540 and not composite and not debug_select and not tutorial and balance == 0:
		await _capture("normal-%dx%d.png" % [dimensions.x, dimensions.y])
	if DisplayServer.get_name() != "headless" and dimensions == Vector2i(540, 960) and not composite and debug_select and not tutorial and balance == 12345:
		await _capture("debug-large-balance.png")
	if DisplayServer.get_name() != "headless" and dimensions == Vector2i(540, 960) and not composite and debug_select and tutorial and balance == 12345:
		await _capture("tutorial-large-balance.png")
	page.queue_free()
	await process_frame


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(OUTPUT.path_join(filename)) == OK, "Could not save " + filename)
