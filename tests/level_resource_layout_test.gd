extends SceneTree

## Isolated page geometry only: never opens main or touches a player save.
const Page = preload("res://scripts/pages/level_page_base.gd")
const Tokens = preload("res://scripts/ui_tokens.gd")
const OUTPUT := "res://artifacts/release_validation/diamond_topbar"
var _failures := 0
var _cases := 0
var _hud_preview := false


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
	_hud_preview = OS.get_cmdline_user_args().has("--hud-preview")
	if _hud_preview:
		root.size = Vector2i(540, 960)
		await process_frame
		await _case(root.size, false, true, false, 0, false)
		await _case(root.size, false, true, true, 0, false)
		await _case(root.size, true, false, false, 0, false)
		root.size = Vector2i(393, 852)
		await process_frame
		await _case(root.size, false, true, false, 12345, true)
		print("HUD RENDER CHECK: %d cases, %d failures" % [_cases, _failures])
		quit(1 if _failures else 0)
		return
	for dimensions in [Vector2i(540, 960), Vector2i(540, 1170), Vector2i(393, 852), Vector2i(1290, 2796)]:
		root.size = dimensions
		await process_frame
		for composite in [false, true]:
			for debug_select in [false, true]:
				for tutorial in [false, true]:
					for balance in [0, 12345, 99999]:
						for rtl in [false, true]:
							await _case(dimensions, composite, debug_select, tutorial, balance, rtl)
	var insets := Tokens.scaled_safe_insets(Rect2i(0, 177, 1290, 2517), Vector2i(1290, 2796), Vector2(540, 1170.4186))
	_expect(is_equal_approx(insets.y, 177.0 * 540.0 / 1290.0), "Physical phone safe-area top inset must convert to logical UI coordinates")
	_expect(is_equal_approx(insets.w, 102.0 * 540.0 / 1290.0), "Physical phone safe-area bottom inset must convert to logical UI coordinates")
	print("LEVEL RESOURCE LAYOUT: %d cases, %d failures" % [_cases, _failures])
	quit(1 if _failures else 0)


func _case(dimensions: Vector2i, composite: bool, debug_select: bool, tutorial: bool, balance: int, rtl: bool) -> void:
	var page = Page.new()
	var ui_theme := Theme.new()
	ui_theme.default_font = load("res://assets/fonts/NotoSansSC-Regular.ttf")
	page.theme = ui_theme
	page.layout_direction = Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR
	root.add_child(page)
	page.setup(19, composite, Callable(), debug_select)
	page.set_coin_balance(balance if balance > 0 else 5)
	page.set_diamond_balance(balance)
	page.set_level_copy("新手教程" if tutorial else ("拼块 27" if composite else "关卡 27"), "", Tokens.INK)
	page.tutorial_skip_button.text = "跳过"
	page.tutorial_skip_button.visible = tutorial
	# Mirror main::_update_tutorial_button: tutorials and independent composite
	# rounds intentionally suppress manual level selection.
	if page.level_select_button:
		page.level_select_button.visible = debug_select and not tutorial and not composite
	page.set_hearts(1, 1) if balance == 0 else page.set_hearts(2, 3)
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
	var context := "%s composite=%s debug=%s tutorial=%s diamonds=%d rtl=%s" % [dimensions, composite, debug_select, tutorial, balance, rtl]
	var viewport_rect: Rect2 = root.get_visible_rect()
	var top: Control = page.find_child("LevelTopBar", true, false)
	var badge: Control = page.find_child("LevelDiamondBalance", true, false)
	var coin: Control = page.find_child("LevelCoinBadge", true, false)
	var diamond_capsule: PanelContainer = badge.get_node("DiamondCapsule")
	var coin_capsule: PanelContainer = coin.get_node("CoinCapsule")
	var diamond_icon: TextureRect = badge.get_node("DiamondIcon")
	var header: Control = page.find_child("LevelHeader", true, false)
	_expect(not (page.tutorial_skip_button.visible and page.level_select_button and page.level_select_button.visible), "Tutorial skip and manual selection must remain exclusive: " + context)
	var action_slot: Control = page.find_child("LevelTopBarActionSlot", true, false)
	var expects_action: bool = page.tutorial_skip_button.visible or (page.level_select_button != null and page.level_select_button.visible)
	_expect(action_slot.visible == expects_action, "The shared trailing action slot must appear only for its active action: " + context)
	_expect(viewport_rect.grow(0.5).encloses(top.get_global_rect()), "Top bar outside viewport: %s viewport=%s top=%s" % [context, viewport_rect, top.get_global_rect()])
	_expect(badge.get_parent() == page.find_child("LevelTopBarItems", true, false), "Diamond must be in the shared top-level component row: " + context)
	_expect(page.settings_button.get_parent() == page.find_child("LevelTopBarItems", true, false), "Settings must be an independent top-level component: " + context)
	_expect(diamond_capsule.has_theme_stylebox_override("panel"), "Diamond needs a framed resource capsule: " + context)
	_expect(badge.get_index() == coin.get_index() + 2, "Diamond must follow the distributed gap after coins: " + context)
	_expect(_ordered_without_overlap(coin, badge, rtl), "Diamond must follow coins: " + context)
	_expect(_ordered_without_overlap(badge, page.level_heart_label, rtl), "Diamond must precede hearts without overlap: " + context)
	_expect(is_equal_approx(coin_capsule.size.y, diamond_capsule.size.y), "Resource capsules must share the same height: " + context)
	var diamond_style: StyleBoxTexture = diamond_capsule.get_theme_stylebox("panel")
	var coin_style: StyleBoxTexture = coin_capsule.get_theme_stylebox("panel")
	_expect(diamond_style.texture != null and coin_style.texture != null, "Resource capsules must load the approved SVG artwork: " + context)
	_expect(header.get_global_rect().position.y >= top.get_global_rect().end.y, "Level header must remain below top resources: " + context)
	_expect(badge.get_global_rect().grow(0.5).encloses(page.diamond_balance_label.get_global_rect()), "Diamond digits must fit badge: " + context)
	_expect(page.diamond_balance_label.size.x + 0.5 >= page.diamond_balance_label.get_minimum_size().x, "Diamond digits must not truncate: " + context)
	# Check the REAL rect, not custom_minimum_size: native SVG sizes previously
	# escaped their wrappers (coin=256px, diamond=96px) despite a 42px minimum.
	for resource in [coin, badge, page.level_heart_label]:
		for child in resource.get_children():
			if child is TextureRect:
				_expect(child.size.is_equal_approx(Vector2(42, 42)), "Actual resource icon size escaped its slot: %s %s %s" % [context, child.name, child.size])
				_expect(resource.get_global_rect().grow(0.5).encloses(child.get_global_rect()), "Resource icon must stay inside its HUD component: " + context)
	if balance == 0:
		_expect(page.coin_roll_display.active_font_size() == 20, "Single-digit coin balance must not use the overflow font size: " + context)
	_expect(diamond_icon.get_global_rect().position.x < diamond_capsule.get_global_rect().position.x and diamond_icon.get_global_rect().end.x > diamond_capsule.get_global_rect().position.x, "Diamond icon must overlap the capsule's leading edge: " + context)
	_expect(page.diamond_balance_label.get_global_rect().position.x > diamond_icon.get_global_rect().position.x, "Diamond count must follow its icon: " + context)
	_expect(badge.get_node("DiamondCapsule/DiamondContent").layout_direction == Control.LAYOUT_DIRECTION_LTR, "Diamond count keeps stable internal LTR order: " + context)
	var row: Control = badge.get_parent()
	var previous: Control
	for child in row.get_children():
		if child is Control and child.visible:
			var rect: Rect2 = child.get_global_rect()
			_expect(top.get_global_rect().grow(0.5).encloses(rect), "Visible top child outside bar: %s child=%s rect=%s" % [context, child.name, rect])
			if previous:
				_expect(_ordered_without_overlap(previous, child, rtl), "Overlapping top controls: %s %s/%s" % [context, previous.name, child.name])
			previous = child
	if _hud_preview and DisplayServer.get_name() != "headless":
		var variant := "tutorial" if tutorial else ("puzzle" if composite else ("rtl" if rtl else "normal"))
		await _capture("hud-%s.png" % variant)
	elif not rtl and DisplayServer.get_name() != "headless" and dimensions.x == 540 and not composite and not debug_select and not tutorial and balance == 0:
		await _capture("normal-%dx%d.png" % [dimensions.x, dimensions.y])
	if not rtl and DisplayServer.get_name() != "headless" and dimensions == Vector2i(540, 960) and not composite and debug_select and not tutorial and balance == 12345:
		await _capture("debug-large-balance.png")
	if not rtl and DisplayServer.get_name() != "headless" and dimensions == Vector2i(540, 960) and not composite and debug_select and tutorial and balance == 12345:
		await _capture("tutorial-large-balance.png")
	page.queue_free()
	await process_frame


func _ordered_without_overlap(before: Control, after: Control, rtl: bool) -> bool:
	return after.get_global_rect().end.x <= before.get_global_rect().position.x + 0.5 if rtl else before.get_global_rect().end.x <= after.get_global_rect().position.x + 0.5


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(OUTPUT.path_join(filename)) == OK, "Could not save " + filename)
