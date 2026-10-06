extends SceneTree

## Isolated presentation fixtures: no main scene, controller, save, or clock policy.
const Page = preload("res://scripts/pages/level_page_base.gd")
const Announcement = preload("res://scripts/overlays/hidden_diamond_overlay.gd")
const Localization = preload("res://scripts/localization_controller.gd")
const Tokens = preload("res://scripts/ui_tokens.gd")
const UI_FONT = preload("res://assets/fonts/NotoSansSC-Regular.ttf")
const ARABIC_FONT = preload("res://assets/fonts/NotoSansArabic-Regular.ttf")
const OUTPUT := "res://artifacts/release_validation/challenge_depth"
var _failures := 0
var _cases := 0
var _localization = Localization.new()


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
	if not UI_FONT.fallbacks.has(ARABIC_FONT):
		UI_FONT.fallbacks.append(ARABIC_FONT)
	_localization.initialize("zh")
	for dimensions in [Vector2i(540, 960), Vector2i(540, 1170)]:
		root.size = dimensions
		await process_frame
		for locale in ["zh", "en", "ar"]:
			await _check_page(dimensions, locale)
	print("CHALLENGE DEPTH VISUAL TEST: %d cases, %d failures" % [_cases, _failures])
	quit(1 if _failures else 0)


func _check_page(dimensions: Vector2i, locale: String) -> void:
	_localization.set_locale(locale, false)
	var page = Page.new()
	page.layout_direction = Control.LAYOUT_DIRECTION_RTL if locale == "ar" else Control.LAYOUT_DIRECTION_LTR
	root.add_child(page)
	page.setup(12345, false, _localization.text, false)
	page.set_diamond_balance(12345)
	page.set_level_copy(_localization.text("关卡 %d", [27]), "", Tokens.INK)
	page.coach_panel.hide()
	page.set_hearts(2, 3)
	page.set_progress(2, 5)
	page.progress_row.hide()
	for kind in ["clear", "crown", "hint"]:
		page.present_tool(kind, {"label": {"clear": "清除", "crown": "直找", "hint": "提示"}[kind], "status": "free_forever" if kind == "clear" else "paid", "value": 0 if kind == "clear" else (6 if kind == "hint" else 12)})
	_set_board(page, 5)
	var hud = page.hidden_diamond_hud
	await _settle_layout()
	var context := "%s/%s" % [dimensions, locale]
	for kind in ["time", "moves"]:
		for remaining in ([30, 10, 3, 0] if kind == "time" else [8, 3, 0]):
			var lions := 3
			hud.present({"kind": kind, "remaining": remaining, "lions": lions, "reward": 1})
			await _settle_layout()
			_check_geometry(page, context + "/%s/%d" % [kind, remaining])
			_expect(hud._limit_panel._variant == ("urgent" if remaining <= (10 if kind == "time" else 3) else "blue"), "Urgent state color boundary: " + context)
			if kind == "time":
				_expect(hud._limit.text == "00:%02d" % remaining and hud._limit.text_direction == Control.TEXT_DIRECTION_LTR, "Timer must retain LTR MM:SS in all locales: " + context)
			else:
				_expect(hud._limit.text == _localization.text("%d 步", [remaining]), "Moves must use localized short label: " + context)
			_expect(hud._lions.text == "× %d" % lions, "Lion remaining counter: " + context)
			_expect(hud._lions.text_direction == Control.TEXT_DIRECTION_LTR and hud._reward.text_direction == Control.TEXT_DIRECTION_LTR, "Icon quantities must retain × amount order in RTL: " + context)
			if DisplayServer.get_name() != "headless":
				if locale == "zh" and remaining in [30, 10, 8]:
					var prefix := "normal_time" if kind == "time" and remaining == 30 else ("urgent_time" if kind == "time" else "moves")
					await _capture("%s-%dx%d.png" % [prefix, dimensions.x, dimensions.y])
				elif locale in ["en", "ar"] and remaining == (30 if kind == "time" else 8):
					await _capture("%s-%s-%dx%d.png" % [locale, kind, dimensions.x, dimensions.y])
			_cases += 1
	# A larger board and maximum supported target retain square cells.
	_set_board(page, 9)
	hud.present({"kind": "time", "remaining": 30, "lions": 9, "reward": 1})
	await _settle_layout()
	_check_geometry(page, context + "/nine-lion-board")
	if DisplayServer.get_name() != "headless" and locale == "zh":
		await _capture("nine_lions-%dx%d.png" % [dimensions.x, dimensions.y])
	await _check_hud_cleanup(page, context)
	_set_board(page, 5, false)
	hud.present({})
	page.set_progress(0, 5)
	page.progress_row.show()
	await _check_announcement(page, dimensions, locale)
	page.queue_free()
	await process_frame


func _check_geometry(page: Control, context: String) -> void:
	var viewport := root.get_visible_rect().grow(0.5)
	var hud = page.hidden_diamond_hud
	_expect(viewport.encloses(hud.get_global_rect()), "HUD must fit viewport: " + context)
	_expect(hud.size.y <= 74.0, "Challenge HUD must remain compact, got %s: %s" % [hud.size, context])
	for label in [hud._limit, hud._lions, hud._reward, page.diamond_balance_label]:
		_expect(label.size.x + 0.5 >= label.get_minimum_size().x, "Counter text clipped: %s/%s width=%s minimum=%s" % [context, label.name, label.size, label.get_minimum_size()])
		_expect(viewport.encloses(label.get_global_rect()), "Counter outside viewport: " + context)
	var panels: Array = hud.get_child(0).get_children()
	if context == "(540, 960)/zh/time/30":
		print("DEPTH MINIMA digits=%s center=%s target=%s reward=%s hud=%s" % [hud._limit.get_combined_minimum_size(), hud._limit_panel.get_combined_minimum_size(), panels[0].get_combined_minimum_size(), panels[2].get_combined_minimum_size(), hud.size])
	for index in panels.size():
		var plate: Control = panels[index]
		_expect(hud.get_global_rect().grow(0.5).encloses(plate.get_global_rect()), "Plate outside HUD: " + context)
		for other in range(index + 1, panels.size()):
			_expect(not plate.get_global_rect().intersects(panels[other].get_global_rect()), "Challenge plates overlap: " + context)
		for label in [hud._limit, hud._lions, hud._reward]:
			if plate.is_ancestor_of(label):
				_expect(plate.get_global_rect().grow(0.5).encloses(label.get_global_rect()), "Counter text outside plate: " + context)
	var top: Control = page.find_child("LevelTopBar", true, false)
	_expect(viewport.encloses(top.get_global_rect()), "Five-digit balances must not expand topbar outside viewport: " + context)
	_expect(viewport.encloses(page.action_bar.get_global_rect()), "Action buttons must fit viewport: " + context)
	var geometry: Dictionary = page.board._board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	_expect(is_equal_approx(board_rect.size.x, board_rect.size.y), "Rendered board must remain square: " + context)
	_expect(board_rect.size.x >= 495.0, "HUD must preserve full-size board, got %s: %s" % [board_rect.size, context])
	_expect(hud.get_global_rect().end.y <= page.board.get_global_rect().position.y + 0.5, "Challenge HUD must not overlap board: " + context)
	_expect(page.board.get_global_rect().end.y <= page.action_bar.get_global_rect().position.y + 0.5, "Board must not overlap tools: " + context)
	var drawn_board := Rect2(page.board.global_position + board_rect.position, board_rect.size)
	_expect(viewport.encloses(drawn_board), "Complete board must fit viewport: " + context)
	print("DEPTH LAYOUT %s hud=%s board=%s" % [context, hud.size, board_rect.size])


func _check_hud_cleanup(page: Control, context: String) -> void:
	var hud = page.hidden_diamond_hud
	hud.present({"kind": "time", "remaining": 11, "lions": 9, "reward": 1})
	hud.present({"kind": "time", "remaining": 10, "lions": 9, "reward": 1})
	_expect(hud._pulse != null, "Urgent transition must create one pulse: " + context)
	hud.present({})
	_expect(hud._pulse == null and hud._limit.scale == Vector2.ONE and not hud.visible, "Clear must stop pulse and reset digit scale: " + context)
	_expect(hud._limit.text.is_empty() and hud._lions.text.is_empty() and hud._reward.text.is_empty(), "Clear must remove previous challenge values: " + context)
	hud.present({"kind": "moves", "remaining": 8, "lions": 5, "reward": 1})
	_expect(hud._pulse == null and not hud._urgent and hud._limit.scale == Vector2.ONE, "Next challenge cannot retain urgency or scale: " + context)
	hud.present({"kind": "moves", "remaining": 7, "lions": 5, "reward": 1})
	page.hide()
	_expect(hud._pulse == null and hud._limit.scale == Vector2.ONE, "Parent hide must cancel pulse: " + context)
	page.show()
	await _settle_layout()
	_cases += 1


func _check_announcement(page: Control, dimensions: Vector2i, locale: String) -> void:
	var overlay = Announcement.new()
	page.add_child(overlay)
	overlay.configure(_localization.text)
	var dismissed: Array = []
	overlay.dismissed.connect(func() -> void: dismissed.append(true))
	var event := {"kind": "time", "target": 5, "limit": 30, "reward": 1}
	overlay.present(event)
	await create_timer(0.25).timeout
	_check_card(overlay, locale)
	if DisplayServer.get_name() != "headless":
		await _capture("announcement-%s-%dx%d.png" % [locale, dimensions.x, dimensions.y])
	overlay.dismiss()
	_expect(not overlay.visible and overlay._tween == null and dismissed.is_empty(), "Manual dismiss must kill animation without activating challenge")
	event["kind"] = "moves"
	event["limit"] = 18
	overlay.present(event)
	await create_timer(0.25).timeout
	_check_card(overlay, locale)
	_expect(is_zero_approx(overlay._animation_root.position.y) and is_equal_approx(overlay._animation_root.modulate.a, 1.0), "Reopened intro must reset to the fully visible resting position")
	await create_timer(1.10).timeout
	_expect(not overlay.visible and overlay._tween == null and dismissed == [true], "Reopened intro must finish exactly once without stale callback")
	overlay.queue_free()
	_cases += 1


func _check_card(overlay: Control, context: String) -> void:
	var card: Control = overlay._card
	_expect(root.get_visible_rect().grow(0.5).encloses(card.get_global_rect()), "Announcement card must fit mobile viewport: " + context)
	for label in [overlay._title, overlay._target, overlay._constraint, overlay._reward]:
		_expect(card.get_global_rect().encloses(label.get_global_rect()), "Announcement text outside card: " + context)
		_expect(label.size.x + 0.5 >= label.get_minimum_size().x, "Announcement text must not truncate: " + context)
	_expect(overlay._reward.text == "× 1", "Announcement must use one reward quantity")
	_expect(overlay._target.text_direction == Control.TEXT_DIRECTION_LTR and overlay._reward.text_direction == Control.TEXT_DIRECTION_LTR, "Announcement icon quantities must retain × amount order in RTL")


func _set_board(page: Control, side: int, found_lions: bool = true) -> void:
	var regions: Array = []
	var states: Array = []
	for row in side:
		var region_row: Array = []
		var state_row: Array = []
		for col in side:
			region_row.append((row + col / 3) % side + 1)
			state_row.append("empty")
		regions.append(region_row)
		states.append(state_row)
	if side == 5:
		# Match the first shipped 5x5 board, including its valid lion positions.
		regions = [[1, 1, 1, 1, 5], [3, 1, 2, 2, 5], [3, 1, 4, 4, 5], [3, 4, 4, 4, 5], [3, 3, 5, 5, 5]]
		if found_lions:
			states[2][0] = "piece"
			states[4][4] = "piece"
			states[0][0] = "blocked"
			states[0][2] = "blocked"
	page.board.set_level({"rows": side, "cols": side, "regions": regions}, states, Tokens.REGION_COLORS)


func _settle_layout() -> void:
	await process_frame
	await process_frame
	await process_frame


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(image.save_png(OUTPUT.path_join(filename)) == OK, "Preview must be written: " + filename)
