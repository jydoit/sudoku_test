class_name AssemblyView
extends Control

signal placement_requested(piece_id: int, origin: Array)
signal return_requested(piece_id: int, slot_index: int)
signal intro_finished()

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const BLOCK_TILE_TEXTURE: Texture2D = preload("res://assets/ui/block_tile_neutral.png")
const BOARD_LAYOUT_INSET := 10.0
const TRAY_CELL_SIZE := 21.0
const TRAY_SLOT_HEIGHT := 94.0
const TRAY_SLOT_GAP := 8.0
const DRAG_THRESHOLD := 6.0
const SCROLL_DIRECTION_BIAS := 0.78
const WHEEL_SCROLL_STEP := 54.0
const PAN_SCROLL_SCALE := 42.0
const RETURN_FOCUS_DURATION := 0.18
const RETURN_HOTZONE_MARGIN := 12.0
const DRAG_LIFT_CELLS := 0.72
const SNAP_RADIUS_CELLS := 0.95

var assembly_data: Dictionary = {}
var placements: Dictionary = {}
var allowed_by_piece: Dictionary = {}
var tray_slot_piece_ids: Array = []
var region_colors: Array = []
var board_target: Control
var tray_target: Control
var active := false
var input_locked := false
var tray_scroll := 0.0
var flatten_amount := 0.0

var _piece_hit_rects: Dictionary = {}
var _pointer_down := false
var _pointer_id := -1
var _press_position := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _press_piece_id := -1
var _drag_piece_id := -1
var _drag_source := ""
var _interaction_mode := ""
var _preview_origin := Vector2i(-99, -99)
var _return_slot_index := -1
var _demo_piece_id := -1
var _demo_origin := Vector2i(-99, -99)
var _intro_dragging_piece := false

var _intro_caption: Label
var _intro_hand: Label
var _hint_popup: PanelContainer
var _hint_title: Label
var _hint_copy: Label
var _hint_swatch: Label
var _hint_piece_id := -1
var _hint_origin := Vector2i(-99, -99)
var _intro_tween: Tween
var _tray_focus_tween: Tween
var _intro_token := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process_input(true)
	resized.connect(queue_redraw)
	resized.connect(_position_hint_popup)
	_build_intro_controls()
	_build_hint_popup()
	hide()


func _process(_delta: float) -> void:
	if _intro_dragging_piece and _intro_hand and _intro_hand.visible:
		_last_pointer = _intro_hand.position + _intro_hand.size * 0.5
		queue_redraw()


func bind_targets(board_control: Control, tray_control: Control) -> void:
	board_target = board_control
	tray_target = tray_control
	if board_target:
		board_target.resized.connect(queue_redraw)
	if tray_target:
		tray_target.resized.connect(queue_redraw)
	queue_redraw()


func configure(
	data: Dictionary,
	current_placements: Dictionary,
	colors: Array,
	allowed: Dictionary,
	tray_slots: Array = []
) -> void:
	assembly_data = data
	placements = current_placements.duplicate(true)
	region_colors = colors.duplicate()
	allowed_by_piece = allowed.duplicate()
	tray_slot_piece_ids = CompositeLevel.sanitize_tray_slots(assembly_data, placements, tray_slots)
	tray_scroll = 0.0
	flatten_amount = 0.0
	active = not assembly_data.is_empty()
	input_locked = false
	visible = active
	hide_piece_hint()
	_reset_pointer()
	queue_redraw()


func update_state(current_placements: Dictionary, allowed: Dictionary, tray_slots: Array = []) -> void:
	placements = current_placements.duplicate(true)
	allowed_by_piece = allowed.duplicate()
	tray_slot_piece_ids = CompositeLevel.sanitize_tray_slots(assembly_data, placements, tray_slots)
	hide_piece_hint()
	queue_redraw()


func deactivate() -> void:
	_intro_token += 1
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	if _tray_focus_tween and _tray_focus_tween.is_valid():
		_tray_focus_tween.kill()
	active = false
	input_locked = false
	hide_piece_hint()
	_reset_pointer()
	_hide_intro_controls()
	hide()


func play_intro() -> void:
	if not active or not board_target or not tray_target:
		intro_finished.emit()
		return
	_intro_token += 1
	var token := _intro_token
	input_locked = true
	_reset_pointer()
	_intro_caption.show()
	_intro_hand.show()
	var board_rect := _board_draw_rect()
	var tray_rect := _tray_rect()
	_intro_caption.text = tr("锁定区域不需要移动")
	_intro_hand.position = board_rect.position + board_rect.size * Vector2(0.24, 0.28) - _intro_hand.size * 0.5
	await get_tree().create_timer(0.95).timeout
	if not _intro_is_current(token):
		return
	_intro_caption.text = tr("把彩色方块拖进空白凹槽")
	await _move_intro_hand(board_rect.get_center() - Vector2(0, 16), 0.72)
	if not _intro_is_current(token):
		return
	await get_tree().create_timer(0.65).timeout
	if not _intro_is_current(token):
		return
	_intro_caption.text = tr("左右滑动待放置区查看更多")
	_intro_hand.position = tray_rect.position + Vector2(tray_rect.size.x * 0.72, tray_rect.size.y * 0.50) - _intro_hand.size * 0.5
	await _move_intro_hand(tray_rect.position + Vector2(tray_rect.size.x * 0.28, tray_rect.size.y * 0.50), 0.72)
	if not _intro_is_current(token):
		return
	await get_tree().create_timer(0.45).timeout
	if not _intro_is_current(token):
		return
	var demo_piece: Dictionary = assembly_data.get("pieces", [])[0] if not assembly_data.get("pieces", []).is_empty() else {}
	if not demo_piece.is_empty():
		_demo_piece_id = int(demo_piece["pieceId"])
		var origins: Array = allowed_by_piece.get(str(_demo_piece_id), [])
		if not origins.is_empty():
			_demo_origin = Vector2i(int(origins[0][1]), int(origins[0][0]))
			_drag_piece_id = _demo_piece_id
			_drag_source = "tray"
			_preview_origin = _demo_origin
			_intro_dragging_piece = true
			_intro_caption.text = tr("把彩色方块拖进空白凹槽")
			await _move_intro_hand(_cell_center(_demo_origin), 0.78)
			if not _intro_is_current(token):
				return
			_intro_dragging_piece = false
			_drag_piece_id = -1
			queue_redraw()
			await get_tree().create_timer(0.55).timeout
			if not _intro_is_current(token):
				return
	_intro_caption.text = tr("已放方块可以拖回托盘")
	if _demo_piece_id >= 0:
		_drag_piece_id = _demo_piece_id
		_drag_source = "board"
		_preview_origin = _demo_origin
		_demo_piece_id = -1
		_intro_dragging_piece = true
	await _move_intro_hand(tray_rect.get_center(), 0.72)
	if not _intro_is_current(token):
		return
	_intro_dragging_piece = false
	_drag_piece_id = -1
	_demo_piece_id = -1
	await get_tree().create_timer(0.65).timeout
	if not _intro_is_current(token):
		return
	_hide_intro_controls()
	input_locked = false
	intro_finished.emit()


func _intro_is_current(token: int) -> bool:
	return active and token == _intro_token


func play_flatten_transition() -> void:
	input_locked = true
	flatten_amount = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_flatten_amount, 0.0, 1.0, 0.88)
	await tween.finished


func _set_flatten_amount(value: float) -> void:
	flatten_amount = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if not active or assembly_data.is_empty() or not board_target or not tray_target:
		return
	_piece_hit_rects.clear()
	_draw_board()
	_draw_tray()
	if _drag_piece_id >= 0:
		_draw_dragging_piece()


func _draw_board() -> void:
	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cellSize"]
	var rows := int(assembly_data.get("rows", 0))
	var cols := int(assembly_data.get("cols", 0))
	var base_regions: Array = assembly_data.get("baseRegions", [])
	var construction := _cell_set(assembly_data.get("constructionCells", []))
	var placed_cells := _placed_cell_map()

	_draw_board_base(board_rect, cell_size)
	for row in range(rows):
		for col in range(cols):
			var cell := Vector2i(col, row)
			var rect := _cell_rect(cell, board_rect.position, cell_size)
			var key := _cell_key(cell)
			if construction.has(key):
				_draw_well(rect, cell_size)
			else:
				var region_id := int(base_regions[row][col])
				_draw_block(rect, _region_color(region_id), cell_size, false)
			if placed_cells.has(key):
				var placed: Dictionary = placed_cells[key]
				if int(placed["pieceId"]) != _drag_piece_id:
					_draw_block(rect, _region_color(int(placed["regionId"])), cell_size, true)
	if _demo_piece_id >= 0 and _demo_origin.x > -90:
		var demo_piece := _piece_by_id(_demo_piece_id)
		for cell in _piece_absolute_cells(demo_piece, _demo_origin):
			if cell.x >= 0 and cell.y >= 0 and cell.y < rows and cell.x < cols:
				_draw_block(_cell_rect(cell, board_rect.position, cell_size), _region_color(int(demo_piece.get("regionId", 1))), cell_size, true)
	if _hint_piece_id >= 0 and _hint_origin.x > -90:
		var hint_piece := _piece_by_id(_hint_piece_id)
		if not hint_piece.is_empty():
			var hint_color := _region_color(int(hint_piece.get("regionId", 1)))
			hint_color.a = 0.32
			for cell in _piece_absolute_cells(hint_piece, _hint_origin):
				if cell.x < 0 or cell.y < 0 or cell.y >= rows or cell.x >= cols:
					continue
				var hint_rect := _cell_rect(cell, board_rect.position, cell_size)
				_draw_block(hint_rect, hint_color, cell_size, true)
				draw_rect(hint_rect.grow(1.0), UITokensScript.ATTENTION_HALO_COLOR, false, maxf(2.0, cell_size * 0.06))

	if _drag_piece_id >= 0 and _preview_origin.x > -90:
		var piece := _piece_by_id(_drag_piece_id)
		var allowed := _origin_allowed(_drag_piece_id, _preview_origin)
		for cell in _piece_absolute_cells(piece, _preview_origin):
			if cell.x < 0 or cell.y < 0 or cell.y >= rows or cell.x >= cols:
				continue
			var preview_rect := _cell_rect(cell, board_rect.position, cell_size)
			var preview_color := _region_color(int(piece.get("regionId", 1)))
			preview_color.a = 0.86
			_draw_block(preview_rect, preview_color, cell_size, true)
			draw_rect(preview_rect.grow(1.0), Color.WHITE if allowed else UITokensScript.DANGER_RED, false, maxf(2.0, cell_size * 0.045))


func _draw_board_base(board_rect: Rect2, cell_size: float) -> void:
	var frame_width := maxi(2, int(round(cell_size * 0.055)))
	var frame_radius := maxi(6, int(round(cell_size * 0.14)))
	var board_base := StyleBoxFlat.new()
	board_base.bg_color = UITokensScript.ASSEMBLY_BOARD_SURFACE
	board_base.border_color = UITokensScript.ASSEMBLY_BOARD_EDGE
	board_base.set_border_width_all(frame_width)
	board_base.corner_radius_top_left = frame_radius
	board_base.corner_radius_top_right = frame_radius
	board_base.corner_radius_bottom_left = frame_radius
	board_base.corner_radius_bottom_right = frame_radius
	board_base.shadow_color = UITokensScript.ASSEMBLY_BOARD_SHADOW
	board_base.shadow_size = maxi(4, int(round(cell_size * 0.09)))
	board_base.shadow_offset = Vector2(0, maxf(2.0, round(cell_size * 0.055)))
	draw_style_box(board_base, board_rect.grow(float(frame_width)))


func _draw_well(rect: Rect2, cell_size: float) -> void:
	var gap := maxf(1.5, cell_size * 0.035)
	var inner := rect.grow(-gap)
	var bevel := maxf(2.0, round(cell_size * 0.045))
	draw_rect(inner, UITokensScript.ASSEMBLY_WELL_DARK, true)
	var cavity := inner.grow(-bevel)
	draw_rect(cavity, UITokensScript.ASSEMBLY_WELL, true)
	draw_line(cavity.position, Vector2(cavity.end.x, cavity.position.y), UITokensScript.ASSEMBLY_WELL_DARK.darkened(0.10), bevel)
	draw_line(cavity.position, Vector2(cavity.position.x, cavity.end.y), UITokensScript.ASSEMBLY_WELL_DARK.darkened(0.10), bevel)
	draw_line(Vector2(inner.position.x, inner.end.y), inner.end, UITokensScript.ASSEMBLY_WELL_LIGHT, bevel)
	draw_line(Vector2(inner.end.x, inner.position.y), inner.end, UITokensScript.ASSEMBLY_WELL_LIGHT, bevel)


func _draw_block(rect: Rect2, color: Color, cell_size: float, movable: bool) -> void:
	var gap := maxf(1.5, cell_size * 0.035)
	var tile_rect := rect.grow(-gap)
	var material_alpha := color.a
	var texture_alpha := 1.0 - flatten_amount
	if texture_alpha > 0.001:
		var shadow_color := Color(0.05, 0.07, 0.11, (0.22 if movable else 0.16) * material_alpha * texture_alpha)
		var shadow_offset := Vector2(0, maxf(1.0, cell_size * (0.045 if movable else 0.03)))
		draw_texture_rect(BLOCK_TILE_TEXTURE, Rect2(tile_rect.position + shadow_offset, tile_rect.size), false, shadow_color)
		var tint := color
		tint.a = material_alpha * texture_alpha
		draw_texture_rect(BLOCK_TILE_TEXTURE, tile_rect, false, tint)
	if flatten_amount > 0.001:
		var flat_color := color
		flat_color.a = material_alpha * flatten_amount
		draw_rect(tile_rect, flat_color, true)


func _draw_tray() -> void:
	var tray_rect := _tray_rect()
	var tray_alpha := 1.0 - flatten_amount
	if tray_alpha <= 0.01:
		return
	var tray_color := UITokensScript.ASSEMBLY_TRAY
	tray_color.a = tray_alpha
	var tray_edge := UITokensScript.ASSEMBLY_TRAY_EDGE
	tray_edge.a = tray_alpha
	draw_rect(tray_rect, tray_color, true)
	draw_rect(tray_rect, tray_edge, false, 3.0)

	var slots := _tray_slot_layout()
	var max_scroll := _tray_max_scroll()
	tray_scroll = clampf(tray_scroll, 0.0, max_scroll)

	for slot in slots:
		var slot_index := int(slot["index"])
		var slot_rect := Rect2(
			tray_rect.position.x + float(slot["x"]) - tray_scroll,
			tray_rect.position.y + float(slot["y"]),
			float(slot["width"]),
			float(slot["height"])
		)
		if slot_rect.end.x < tray_rect.position.x or slot_rect.position.x > tray_rect.end.x:
			continue
		var piece_id := int(tray_slot_piece_ids[slot_index]) if slot_index < tray_slot_piece_ids.size() else -1
		if slot_index == _return_slot_index and _drag_source == "board" and _drag_piece_id >= 0:
			var focus_piece := _piece_by_id(_drag_piece_id)
			_draw_slot_frame(slot_rect, _region_color(int(focus_piece.get("regionId", 1))), 1.0 * tray_alpha, true)
			_draw_piece_preview(_piece_by_id(_drag_piece_id), slot_rect, 0.72 * tray_alpha)
			continue
		if piece_id < 0:
			draw_rect(slot_rect.grow(-6.0), Color(1.0, 1.0, 1.0, 0.12 * tray_alpha), false, 2.0)
			continue
		var piece := _piece_by_id(piece_id)
		if piece.is_empty():
			continue
		var is_placed := placements.has(str(piece_id))
		_draw_slot_frame(slot_rect, _region_color(int(piece.get("regionId", 1))), (0.42 if is_placed else 0.96) * tray_alpha, not is_placed)
		if is_placed:
			_draw_piece_preview(piece, slot_rect, 0.28 * tray_alpha)
			draw_string(ThemeDB.fallback_font, slot_rect.end - Vector2(24, 12), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.72, 0.92, 0.80, 0.75 * tray_alpha))
			continue
		_piece_hit_rects[piece_id] = slot_rect
		if piece_id == _drag_piece_id:
			draw_rect(slot_rect.grow(-8.0), Color(1.0, 1.0, 1.0, 0.16 * tray_alpha), false, 2.0)
		else:
			_draw_piece_preview(piece, slot_rect, tray_alpha)

	if max_scroll > 0.0:
		var hint_color := Color(1.0, 1.0, 1.0, 0.58 * tray_alpha)
		draw_string(ThemeDB.fallback_font, tray_rect.position + Vector2(8, tray_rect.size.y * 0.5 + 7), "‹", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, hint_color)
		draw_string(ThemeDB.fallback_font, tray_rect.end - Vector2(22, tray_rect.size.y * 0.5 - 7), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, hint_color)


func _draw_slot_frame(slot_rect: Rect2, region_color: Color, alpha: float, emphasized: bool) -> void:
	var glow := region_color
	glow.a = 0.22 * alpha
	draw_rect(slot_rect.grow(4.0), glow, false, 7.0 if emphasized else 5.0)
	var border := region_color
	border.a = alpha
	draw_rect(slot_rect.grow(-2.0), border, false, 4.0 if emphasized else 3.0)
	var slot_surface := UITokensScript.ASSEMBLY_TRAY
	slot_surface.a = 0.72 * alpha
	draw_rect(slot_rect.grow(-5.0), slot_surface, true)


func _draw_piece_preview(piece: Dictionary, slot_rect: Rect2, alpha: float) -> void:
	var bounds := _piece_bounds(piece)
	var cell_size := minf(TRAY_CELL_SIZE, minf((slot_rect.size.x - 22.0) / maxf(1.0, bounds.size.x), (slot_rect.size.y - 22.0) / maxf(1.0, bounds.size.y)))
	var shape_size := Vector2(bounds.size.x, bounds.size.y) * cell_size
	var origin := slot_rect.get_center() - shape_size * 0.5
	var color := _region_color(int(piece.get("regionId", 1)))
	color.a = alpha
	for cell in _piece_local_cells(piece):
		var rect := Rect2(origin + Vector2(cell.x, cell.y) * cell_size, Vector2.ONE * cell_size)
		_draw_block(rect, color, cell_size, true)


func _draw_dragging_piece() -> void:
	var piece := _piece_by_id(_drag_piece_id)
	if piece.is_empty():
		return
	if _drag_source == "board" and _return_slot_index >= 0 and _tray_rect().grow(RETURN_HOTZONE_MARGIN).has_point(_last_pointer):
		return
	var geometry := _board_geometry()
	var cell_size: float = geometry["cellSize"]
	var bounds := _piece_bounds(piece)
	var draw_size := Vector2(bounds.size.x, bounds.size.y) * cell_size
	var origin := _last_pointer - Vector2(draw_size.x * 0.5, draw_size.y + cell_size * DRAG_LIFT_CELLS)
	var color := _region_color(int(piece.get("regionId", 1)))
	for cell in _piece_local_cells(piece):
		var rect := Rect2(origin + Vector2(cell.x, cell.y) * cell_size, Vector2.ONE * cell_size)
		_draw_block(rect, color, cell_size, true)


func _input(event: InputEvent) -> void:
	if not active or not visible or input_locked:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		var position := _canvas_to_local(mouse_event.position)
		var pointer_over_tray := _tray_rect().has_point(position)
		if pointer_over_tray and mouse_event.pressed and (
			mouse_event.button_index == MOUSE_BUTTON_WHEEL_LEFT
			or mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP
		):
			_scroll_tray(-WHEEL_SCROLL_STEP)
			get_viewport().set_input_as_handled()
		elif pointer_over_tray and mouse_event.pressed and (
			mouse_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
			or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			_scroll_tray(WHEEL_SCROLL_STEP)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_pointer_pressed(position, -1)
			else:
				_pointer_released(position, -1)
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		var pan_position := _canvas_to_local(pan.position)
		if _tray_rect().has_point(pan_position):
			_scroll_tray(-pan.delta.x * PAN_SCROLL_SCALE)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer_down and _pointer_id == -1:
		_pointer_moved(_canvas_to_local((event as InputEventMouseMotion).position), -1)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var touch_position := _canvas_to_local(touch.position)
		if touch.pressed:
			_pointer_pressed(touch_position, touch.index)
		else:
			_pointer_released(touch_position, touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_pointer_moved(_canvas_to_local(drag.position), drag.index)


func _pointer_pressed(position: Vector2, pointer_id: int) -> void:
	if _pointer_down:
		return
	var tray_rect := _tray_rect()
	var board_rect := _board_draw_rect()
	if not tray_rect.has_point(position) and not board_rect.has_point(position):
		return
	_pointer_down = true
	_pointer_id = pointer_id
	_press_position = position
	_last_pointer = position
	_interaction_mode = "pending"
	_press_piece_id = -1
	_drag_source = ""
	if tray_rect.has_point(position):
		_drag_source = "tray"
		for piece_id in _piece_hit_rects.keys():
			if (_piece_hit_rects[piece_id] as Rect2).has_point(position) and not placements.has(str(piece_id)):
				_press_piece_id = int(piece_id)
				break
	else:
		var cell := _cell_at_position(position)
		var placed_piece := _piece_at_cell(cell)
		if placed_piece >= 0:
			_press_piece_id = placed_piece
			_drag_source = "board"
	get_viewport().set_input_as_handled()


func _pointer_moved(position: Vector2, pointer_id: int) -> void:
	if not _pointer_down or pointer_id != _pointer_id:
		return
	var delta := position - _press_position
	if _interaction_mode == "pending":
		var horizontal_scroll := (
			_drag_source == "tray"
			and absf(delta.x) > DRAG_THRESHOLD
			and absf(delta.x) >= absf(delta.y) * SCROLL_DIRECTION_BIAS
		)
		if horizontal_scroll:
			_interaction_mode = "scroll"
		elif _press_piece_id >= 0 and delta.length() > DRAG_THRESHOLD and (
			_drag_source == "board"
			or (_drag_source == "tray" and delta.y > DRAG_THRESHOLD * 0.55 and absf(delta.y) > absf(delta.x))
		):
			_start_drag(_press_piece_id, position)
		elif _drag_source == "tray" and _press_piece_id < 0 and absf(delta.x) > DRAG_THRESHOLD:
			_interaction_mode = "scroll"
	if _interaction_mode == "scroll":
		_scroll_tray(_last_pointer.x - position.x)
	elif _interaction_mode == "drag":
		_last_pointer = position
		if _drag_source == "board" and _tray_rect().grow(RETURN_HOTZONE_MARGIN).has_point(position):
			_prepare_return_slot_focus()
		else:
			_return_slot_index = -1
			_preview_origin = _origin_for_pointer(position)
		queue_redraw()
	_last_pointer = position
	get_viewport().set_input_as_handled()


func _pointer_released(position: Vector2, pointer_id: int) -> void:
	if not _pointer_down or pointer_id != _pointer_id:
		return
	var return_piece_id := -1
	var return_slot_index := -1
	var placement_piece_id := -1
	var placement_origin := Vector2i(-99, -99)
	if _interaction_mode == "drag" and _drag_piece_id >= 0:
		_last_pointer = position
		var in_return_hotzone := _tray_rect().grow(RETURN_HOTZONE_MARGIN).has_point(position)
		if _drag_source == "board" and in_return_hotzone:
			# Release can arrive without a final motion event on touch screens. Resolve
			# the target from the release position itself so returning is immediate.
			_prepare_return_slot_focus(false)
			if _return_slot_index >= 0:
				return_piece_id = _drag_piece_id
				return_slot_index = _return_slot_index
		elif _origin_allowed(_drag_piece_id, _preview_origin):
			placement_piece_id = _drag_piece_id
			placement_origin = _preview_origin
	_reset_pointer()
	queue_redraw()
	get_viewport().set_input_as_handled()
	# Clear the local drag state before invoking the main controller. This lets
	# the view render the release immediately even when the controller updates
	# the tray and schedules persistence in the same input tick.
	if return_piece_id >= 0:
		return_requested.emit(return_piece_id, return_slot_index)
	elif placement_piece_id >= 0:
		placement_requested.emit(placement_piece_id, [placement_origin.y, placement_origin.x])


func _start_drag(piece_id: int, pointer_position: Vector2) -> void:
	_drag_piece_id = piece_id
	_interaction_mode = "drag"
	_last_pointer = pointer_position
	_preview_origin = _origin_for_pointer(pointer_position)
	queue_redraw()


func _reset_pointer() -> void:
	_pointer_down = false
	_pointer_id = -1
	_press_piece_id = -1
	_drag_piece_id = -1
	_drag_source = ""
	_interaction_mode = ""
	_preview_origin = Vector2i(-99, -99)
	_return_slot_index = -1
	_intro_dragging_piece = false
	_demo_piece_id = -1
	_demo_origin = Vector2i(-99, -99)


func _origin_for_pointer(position: Vector2) -> Vector2i:
	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cellSize"]
	var piece := _piece_by_id(_drag_piece_id)
	var bounds := _piece_bounds(piece)
	var col := int(round((position.x - board_rect.position.x) / cell_size - float(bounds.size.x) * 0.5))
	var row := int(round((position.y - board_rect.position.y) / cell_size - float(bounds.size.y) - DRAG_LIFT_CELLS))
	var raw_origin := Vector2i(col, row)
	return _nearest_snap_origin(position, piece, raw_origin, board_rect.position, cell_size)


func _nearest_snap_origin(position: Vector2, piece: Dictionary, fallback: Vector2i, board_origin: Vector2, cell_size: float) -> Vector2i:
	var bounds := _piece_bounds(piece)
	var best_origin := fallback
	var best_distance := cell_size * SNAP_RADIUS_CELLS
	for raw in allowed_by_piece.get(str(_drag_piece_id), []):
		if not raw is Array or raw.size() < 2:
			continue
		var origin := Vector2i(int(raw[1]), int(raw[0]))
		var snap_pointer := board_origin + Vector2(
			(float(origin.x) + float(bounds.size.x) * 0.5) * cell_size,
			(float(origin.y + bounds.size.y) + DRAG_LIFT_CELLS) * cell_size
		)
		var distance := position.distance_to(snap_pointer)
		if distance <= best_distance:
			best_distance = distance
			best_origin = origin
	return best_origin


func _origin_allowed(piece_id: int, origin: Vector2i) -> bool:
	for raw in allowed_by_piece.get(str(piece_id), []):
		if raw is Array and raw.size() >= 2 and int(raw[0]) == origin.y and int(raw[1]) == origin.x:
			return true
	return false


func _scroll_tray(delta: float) -> void:
	if _tray_focus_tween and _tray_focus_tween.is_valid():
		_tray_focus_tween.kill()
	tray_scroll = clampf(tray_scroll + delta, 0.0, _tray_max_scroll())
	queue_redraw()


func _tray_max_scroll() -> float:
	var slots := _tray_slot_layout()
	if slots.is_empty():
		return 0.0
	var last_slot: Dictionary = slots.back()
	var content_width := float(last_slot["x"]) + float(last_slot["width"]) + 4.0
	return maxf(0.0, content_width - _tray_rect().size.x)


func _tray_slot_layout() -> Array:
	var pieces: Array = assembly_data.get("pieces", [])
	var result: Array = []
	var horizontal_padding := 10.0
	var column_gap := TRAY_SLOT_GAP
	var slot_width := clampf((_tray_rect().size.x - horizontal_padding * 2.0 - column_gap * 3.0) / 4.0, 72.0, 120.0)
	for slot_index in range(pieces.size()):
		result.append({
			"index": slot_index,
			"x": horizontal_padding + slot_index * (slot_width + column_gap),
			"y": (tray_target.size.y - TRAY_SLOT_HEIGHT) * 0.5,
			"width": slot_width,
			"height": TRAY_SLOT_HEIGHT
		})
	return result


func _piece_for_initial_slot(slot_index: int) -> Dictionary:
	var pieces: Array = assembly_data.get("pieces", [])
	for piece in pieces:
		if int(piece.get("trayIndex", piece.get("pieceId", -1))) == slot_index:
			return piece
	return pieces[slot_index] if slot_index >= 0 and slot_index < pieces.size() else {}


func _prepare_return_slot_focus(animated: bool = true) -> void:
	if _return_slot_index >= 0:
		return
	_return_slot_index = tray_slot_piece_ids.find(_drag_piece_id)
	if _return_slot_index >= 0:
		focus_tray_slot(_return_slot_index, animated)


func focus_tray_slot(slot_index: int, animated: bool = true) -> void:
	var slots := _tray_slot_layout()
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot: Dictionary = slots[slot_index]
	var target_scroll := clampf(
		float(slot["x"]) + float(slot["width"]) * 0.5 - _tray_rect().size.x * 0.5,
		0.0,
		_tray_max_scroll()
	)
	if _tray_focus_tween and _tray_focus_tween.is_valid():
		_tray_focus_tween.kill()
	if not animated or is_equal_approx(tray_scroll, target_scroll):
		_set_tray_scroll(target_scroll)
		return
	_tray_focus_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tray_focus_tween.tween_method(_set_tray_scroll, tray_scroll, target_scroll, RETURN_FOCUS_DURATION)


func _set_tray_scroll(value: float) -> void:
	tray_scroll = clampf(value, 0.0, _tray_max_scroll())
	queue_redraw()


func _piece_at_cell(cell: Vector2i) -> int:
	for piece in assembly_data.get("pieces", []):
		var piece_id := int(piece["pieceId"])
		if not placements.has(str(piece_id)):
			continue
		var origin: Array = placements[str(piece_id)]
		for occupied in _piece_absolute_cells(piece, Vector2i(int(origin[1]), int(origin[0]))):
			if occupied == cell:
				return piece_id
	return -1


func _placed_cell_map() -> Dictionary:
	var result := {}
	for piece in assembly_data.get("pieces", []):
		var piece_id := int(piece["pieceId"])
		if not placements.has(str(piece_id)):
			continue
		var origin: Array = placements[str(piece_id)]
		for cell in _piece_absolute_cells(piece, Vector2i(int(origin[1]), int(origin[0]))):
			result[_cell_key(cell)] = {"pieceId": piece_id, "regionId": int(piece["regionId"])}
	return result


func _piece_by_id(piece_id: int) -> Dictionary:
	for piece in assembly_data.get("pieces", []):
		if int(piece.get("pieceId", -1)) == piece_id:
			return piece
	return {}


func _piece_local_cells(piece: Dictionary) -> Array:
	var result: Array = []
	for raw in piece.get("cells", []):
		result.append(Vector2i(int(raw[1]), int(raw[0])))
	return result


func _piece_absolute_cells(piece: Dictionary, origin: Vector2i) -> Array:
	var result: Array = []
	for local_cell in _piece_local_cells(piece):
		result.append(origin + local_cell)
	return result


func _piece_bounds(piece: Dictionary) -> Rect2i:
	var max_col := 0
	var max_row := 0
	for cell in _piece_local_cells(piece):
		max_col = maxi(max_col, cell.x)
		max_row = maxi(max_row, cell.y)
	return Rect2i(0, 0, max_col + 1, max_row + 1)


func _region_color(region_id: int) -> Color:
	if region_colors.is_empty():
		return Color.WHITE
	return region_colors[posmod(region_id - 1, region_colors.size())]


func _board_geometry() -> Dictionary:
	var target_rect := _target_rect(board_target)
	var rows: int = maxi(1, int(assembly_data.get("rows", 1)))
	var cols: int = maxi(1, int(assembly_data.get("cols", 1)))
	var usable := Vector2(maxf(1.0, target_rect.size.x - BOARD_LAYOUT_INSET), maxf(1.0, target_rect.size.y - BOARD_LAYOUT_INSET))
	var board_size: float = floor(minf(usable.x, usable.y))
	var cell_size := maxf(1.0, floor(board_size / float(maxi(rows, cols))))
	var actual := Vector2(cols * cell_size, rows * cell_size)
	var position := (target_rect.position + (target_rect.size - actual) * 0.5).floor()
	return {"rect": Rect2(position, actual), "cellSize": cell_size}


func _board_draw_rect() -> Rect2:
	return _board_geometry()["rect"]


func _tray_rect() -> Rect2:
	return _target_rect(tray_target)


func _target_rect(target: Control) -> Rect2:
	if not target:
		return Rect2()
	var global_rect := target.get_global_rect()
	return Rect2(_canvas_to_local(global_rect.position), global_rect.size)


func _canvas_to_local(canvas_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * canvas_position


func _cell_rect(cell: Vector2i, origin: Vector2, cell_size: float) -> Rect2:
	return Rect2(origin + Vector2(cell.x, cell.y) * cell_size, Vector2.ONE * cell_size)


func _cell_at_position(position: Vector2) -> Vector2i:
	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cellSize"]
	return Vector2i(int(floor((position.x - board_rect.position.x) / cell_size)), int(floor((position.y - board_rect.position.y) / cell_size)))


func _cell_center(cell: Vector2i) -> Vector2:
	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cellSize"]
	return board_rect.position + Vector2(cell.x + 0.5, cell.y + 0.5) * cell_size


func _cell_set(raw_cells: Array) -> Dictionary:
	var result := {}
	for raw in raw_cells:
		result["%d,%d" % [int(raw[0]), int(raw[1])]] = true
	return result


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.y, cell.x]


func show_piece_hint(piece_id: int, origin: Vector2i) -> void:
	var piece := _piece_by_id(piece_id)
	if piece.is_empty():
		return
	_hint_piece_id = piece_id
	_hint_origin = origin
	var region_id := int(piece.get("regionId", 1))
	var color_name := "颜色"
	var color_index := region_id - 1
	if color_index >= 0 and color_index < UITokensScript.REGION_COLOR_NAMES.size():
		color_name = str(UITokensScript.REGION_COLOR_NAMES[color_index])
	_hint_title.text = "提示：%s块放这里" % color_name
	_hint_copy.text = "正确位置：第 %d 行，第 %d 列" % [origin.y + 1, origin.x + 1]
	_hint_swatch.text = "■"
	_hint_swatch.add_theme_color_override("font_color", _region_color(region_id))
	_position_hint_popup()
	_hint_popup.show()
	queue_redraw()


func hide_piece_hint() -> void:
	_hint_piece_id = -1
	_hint_origin = Vector2i(-99, -99)
	if _hint_popup:
		_hint_popup.hide()
	queue_redraw()


func _position_hint_popup() -> void:
	if not _hint_popup:
		return
	var board_rect := _board_draw_rect()
	_hint_popup.position = Vector2(
		maxf(12.0, (size.x - _hint_popup.size.x) * 0.5),
		maxf(120.0, board_rect.position.y - _hint_popup.size.y - 10.0)
	)


func _build_hint_popup() -> void:
	_hint_popup = PanelContainer.new()
	_hint_popup.custom_minimum_size = Vector2(318, 86)
	_hint_popup.size = Vector2(318, 86)
	_hint_popup.z_index = 30
	_hint_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#FFFDF8")
	style.border_color = Color("#D8E5F5")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.05, 0.08, 0.14, 0.20)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	_hint_popup.add_theme_stylebox_override("panel", style)
	add_child(_hint_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_hint_popup.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	_hint_swatch = Label.new()
	_hint_swatch.custom_minimum_size = Vector2(34, 42)
	_hint_swatch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_swatch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_swatch.add_theme_font_size_override("font_size", 28)
	row.add_child(_hint_swatch)
	var copy_column := VBoxContainer.new()
	copy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_column.add_theme_constant_override("separation", 2)
	row.add_child(copy_column)
	_hint_title = Label.new()
	_hint_title.add_theme_color_override("font_color", UITokensScript.INK)
	_hint_title.add_theme_font_size_override("font_size", 16)
	copy_column.add_child(_hint_title)
	_hint_copy = Label.new()
	_hint_copy.add_theme_color_override("font_color", UITokensScript.MUTED)
	_hint_copy.add_theme_font_size_override("font_size", 13)
	copy_column.add_child(_hint_copy)
	var close_button := Button.new()
	close_button.text = "知道了"
	close_button.custom_minimum_size = Vector2(62, 34)
	close_button.pressed.connect(hide_piece_hint)
	row.add_child(close_button)
	_hint_popup.hide()


func _build_intro_controls() -> void:
	_intro_caption = Label.new()
	_intro_caption.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_intro_caption.position = Vector2(-170, 108)
	_intro_caption.size = Vector2(340, 48)
	_intro_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_caption.add_theme_color_override("font_color", Color.WHITE)
	_intro_caption.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.14, 0.75))
	_intro_caption.add_theme_constant_override("shadow_offset_y", 2)
	_intro_caption.add_theme_font_size_override("font_size", 18)
	_intro_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_caption.z_index = 20
	add_child(_intro_caption)

	_intro_hand = Label.new()
	_intro_hand.text = "☝"
	_intro_hand.size = Vector2(72, 72)
	_intro_hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_hand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_hand.add_theme_color_override("font_color", Color.WHITE)
	_intro_hand.add_theme_color_override("font_shadow_color", Color(0.05, 0.08, 0.14, 0.72))
	_intro_hand.add_theme_constant_override("shadow_offset_y", 3)
	_intro_hand.add_theme_font_size_override("font_size", 58)
	_intro_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_hand.z_index = 21
	add_child(_intro_hand)
	_hide_intro_controls()


func _move_intro_hand(target: Vector2, duration: float) -> void:
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(_intro_hand, "position", target - _intro_hand.size * 0.5, duration)
	await _intro_tween.finished


func _hide_intro_controls() -> void:
	if _intro_caption:
		_intro_caption.hide()
	if _intro_hand:
		_intro_hand.hide()
