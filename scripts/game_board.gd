class_name GameBoard
extends Control

signal cell_pressed(row: int, col: int)
signal cell_double_pressed(row: int, col: int)
signal cell_drag_started(row: int, col: int)
signal cell_dragged(row: int, col: int)
signal cell_drag_ended()

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const PIECE_TEXTURE = preload("res://assets/ui/lion_king.png")
const WRONG_PIECE_TEXTURE = preload("res://assets/ui/lion_king_wrong.png")
const BOARD_INK := UITokensScript.INK
const EMPTY_MARK := "empty"
const PIECE_MARK := "piece"
const BLOCKED_MARK := "blocked"
const HINT_MARK := "hint"
const KING_MARK := "king"
const WRONG_MARK := "wrong"
const REGION_BORDER_COLOR := UITokensScript.BOARD_BORDER
const BOARD_LAYOUT_INSET := 10.0
const DOUBLE_TAP_MIN_MS := 80
const DOUBLE_TAP_MAX_MS := 320
const DOUBLE_TAP_MAX_DISTANCE := 18.0
const TAP_MAX_DRIFT := 14.0
const TOUCH_MOUSE_SUPPRESS_MS := 700

var rows := 6
var cols := 6
var regions: Array = []
var cell_states: Array = []
var error_cells: Dictionary = {}
var guide_cells: Dictionary = {}
var guide_mask_enabled := true
var region_colors: Array = []
var pulse_cell := Vector2i(-1, -1)
var pulse_strength := 0.0
var shake_cell := Vector2i(-1, -1)
var shake_strength := 0.0
var guide_pulse_cell := Vector2i(-1, -1)
var guide_pulse_cells: Dictionary = {}
var guide_pulse_strength := 0.0
var guide_pulse_tween: Tween
var king_reveal_cells: Dictionary = {}
var hidden_king_cells: Dictionary = {}
var king_reveal_strength := 0.0
var victory_strength := 0.0
var waiting_wiggle_strength := 0.0
var tutorial_mask_enabled := false
var tutorial_focus_cell := Vector2i(-1, -1)
var press_cell := Vector2i(-1, -1)
var last_drag_cell := Vector2i(-1, -1)
var tracking_press := false
var dragging := false
var press_started_at_msec := 0
var press_start_position := Vector2.ZERO
var recent_tap_cell := Vector2i(-1, -1)
var recent_tap_position := Vector2.ZERO
var recent_tap_released_at_msec := 0
var last_screen_touch_msec := -1000000



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(300, 300)
	resized.connect(queue_redraw)


func set_level(level: Dictionary, states: Array, colors: Array) -> void:
	rows = int(level["rows"])
	cols = int(level["cols"])
	regions = level["regions"]
	cell_states = states
	region_colors = colors
	error_cells.clear()
	guide_cells.clear()
	guide_mask_enabled = true
	king_reveal_cells.clear()
	hidden_king_cells.clear()
	king_reveal_strength = 0.0
	tutorial_mask_enabled = false
	tutorial_focus_cell = Vector2i(-1, -1)
	victory_strength = 0.0
	queue_redraw()


func set_states(states: Array) -> void:
	cell_states = states
	queue_redraw()


func set_errors(errors: Dictionary) -> void:
	error_cells = errors
	queue_redraw()


func set_guides(guides: Dictionary, show_mask: bool = true) -> void:
	guide_cells = guides
	guide_mask_enabled = show_mask
	_reset_guide_feedback()
	queue_redraw()


func set_tutorial_focus(cell: Vector2i, enabled: bool) -> void:
	tutorial_focus_cell = cell if enabled else Vector2i(-1, -1)
	tutorial_mask_enabled = enabled and cell.x >= 0 and cell.y >= 0
	queue_redraw()


func play_cell_feedback(row: int, col: int) -> void:
	pulse_cell = Vector2i(col, row)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_pulse, 0.0, 1.0, 0.09)
	tween.tween_method(_set_pulse, 1.0, 0.0, 0.18)


func play_wrong_feedback(row: int, col: int) -> void:
	shake_cell = Vector2i(col, row)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_shake, 0.0, 1.0, 0.08)
	tween.tween_method(_set_shake, 1.0, -1.0, 0.08)
	tween.tween_method(_set_shake, -1.0, 0.65, 0.07)
	tween.tween_method(_set_shake, 0.65, 0.0, 0.10)
	tween.finished.connect(func() -> void:
		shake_cell = Vector2i(-1, -1)
		shake_strength = 0.0
		queue_redraw()
	)


func play_guide_feedback(row: int, col: int) -> void:
	_reset_guide_feedback()
	guide_pulse_cell = Vector2i(col, row)
	guide_pulse_cells[guide_pulse_cell] = true
	_play_guide_feedback_tween()


func play_guide_feedback_for_cells(cells: Array) -> void:
	_reset_guide_feedback()
	for raw_cell in cells:
		if raw_cell is Vector2i:
			guide_pulse_cells[raw_cell] = true
	_play_guide_feedback_tween()


func play_king_reveal(cells: Array) -> void:
	king_reveal_cells.clear()
	king_reveal_strength = 0.0
	if cells.is_empty():
		return
	for cell in cells:
		if cell is Vector2i:
			king_reveal_cells[cell] = true
	var tween := create_tween()
	tween.tween_interval(0.16)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_king_reveal, 0.0, 1.0, 0.18)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_king_reveal, 1.0, 0.18, 0.16)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_king_reveal, 0.18, 1.0, 0.16)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_king_reveal, 1.0, 0.0, 0.28)
	tween.finished.connect(func() -> void:
		king_reveal_cells.clear()
		king_reveal_strength = 0.0
		queue_redraw()
	)


func play_waiting_lion_wiggle() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_waiting_wiggle, 0.0, 1.0, 0.62)
	tween.tween_method(_set_waiting_wiggle, 1.0, 0.0, 0.12)


func prepare_king_reveal(cells: Array) -> void:
	hidden_king_cells.clear()
	for cell in cells:
		if cell is Vector2i:
			hidden_king_cells[cell] = true
	queue_redraw()


func reveal_king_cell(cell: Vector2i) -> void:
	hidden_king_cells.erase(cell)
	queue_redraw()
	play_king_reveal([cell])


func reveal_all_prepared_kings() -> void:
	hidden_king_cells.clear()
	queue_redraw()


func cell_global_center(row: int, col: int) -> Vector2:
	if row < 0 or row >= rows or col < 0 or col >= cols:
		return global_position
	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cell_size"]
	return get_global_rect().position + board_rect.position + Vector2(float(col) + 0.5, float(row) + 0.5) * cell_size


func _play_guide_feedback_tween() -> void:
	if guide_pulse_cells.is_empty():
		queue_redraw()
		return
	guide_pulse_tween = create_tween()
	guide_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	guide_pulse_tween.tween_method(_set_guide_pulse, 0.0, 1.0, 0.18)
	guide_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	guide_pulse_tween.tween_method(_set_guide_pulse, 1.0, 0.0, 0.48)
	guide_pulse_tween.finished.connect(func() -> void:
		guide_pulse_tween = null
		guide_pulse_cells.clear()
		guide_pulse_cell = Vector2i(-1, -1)
		guide_pulse_strength = 0.0
		queue_redraw()
	)


func _reset_guide_feedback() -> void:
	if guide_pulse_tween and guide_pulse_tween.is_valid():
		guide_pulse_tween.kill()
	guide_pulse_tween = null
	guide_pulse_cell = Vector2i(-1, -1)
	guide_pulse_cells.clear()
	guide_pulse_strength = 0.0


func play_victory() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_victory, 0.0, 1.0, 0.24)
	tween.tween_method(_set_victory, 1.0, 0.0, 0.34)


func _set_pulse(value: float) -> void:
	pulse_strength = value
	queue_redraw()


func _set_shake(value: float) -> void:
	shake_strength = value
	queue_redraw()


func _set_guide_pulse(value: float) -> void:
	guide_pulse_strength = value
	queue_redraw()


func _set_king_reveal(value: float) -> void:
	king_reveal_strength = value
	queue_redraw()


func _set_waiting_wiggle(value: float) -> void:
	waiting_wiggle_strength = value
	queue_redraw()


func _set_victory(value: float) -> void:
	victory_strength = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _should_ignore_mouse_event_after_touch():
			accept_event()
			return
		if event.pressed:
			_start_pointer(event.position)
		else:
			_finish_pointer(event.position)
		accept_event()
		return
	if event is InputEventScreenTouch:
		last_screen_touch_msec = Time.get_ticks_msec()
		if event.pressed:
			_start_pointer(event.position)
		else:
			_finish_pointer(event.position)
		accept_event()
		return
	if event is InputEventMouseMotion and tracking_press and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _should_ignore_mouse_event_after_touch():
			accept_event()
			return
		_update_drag(event.position)
		accept_event()
		return
	if event is InputEventScreenDrag and tracking_press:
		last_screen_touch_msec = Time.get_ticks_msec()
		_update_drag(event.position)
		accept_event()


func _start_pointer(position: Vector2) -> void:
	var cell := _cell_at_position(position)
	if cell.x < 0 or not _interaction_allowed_for_cell(cell):
		_reset_pointer()
		return
	tracking_press = true
	dragging = false
	press_cell = cell
	last_drag_cell = cell
	press_start_position = position
	press_started_at_msec = Time.get_ticks_msec()


func _finish_pointer(position: Vector2) -> void:
	if not tracking_press:
		_reset_pointer()
		return
	if dragging:
		cell_drag_ended.emit()
	else:
		var cell := _cell_at_position(position)
		if (
			cell == press_cell
			and _interaction_allowed_for_cell(cell)
			and position.distance_to(press_start_position) <= TAP_MAX_DRIFT
		):
			_handle_tap_release(cell, position)
	_reset_pointer()


func _update_drag(position: Vector2) -> void:
	var cell := _cell_at_position(position)
	if cell.x < 0 or cell == last_drag_cell or not _interaction_allowed_for_cell(cell):
		return
	if not dragging:
		dragging = true
		_clear_recent_tap()
		cell_drag_started.emit(press_cell.y, press_cell.x)
	last_drag_cell = cell
	cell_dragged.emit(cell.y, cell.x)


func _reset_pointer() -> void:
	tracking_press = false
	dragging = false
	press_cell = Vector2i(-1, -1)
	last_drag_cell = Vector2i(-1, -1)
	press_start_position = Vector2.ZERO
	press_started_at_msec = 0


func _handle_tap_release(cell: Vector2i, position: Vector2) -> void:
	var now_msec := Time.get_ticks_msec()
	if recent_tap_cell.x >= 0:
		var interval := now_msec - recent_tap_released_at_msec
		var same_cell := cell == recent_tap_cell
		var near_previous := position.distance_to(recent_tap_position) <= DOUBLE_TAP_MAX_DISTANCE
		if same_cell and near_previous and interval >= DOUBLE_TAP_MIN_MS and interval <= DOUBLE_TAP_MAX_MS:
			_clear_recent_tap()
			cell_double_pressed.emit(cell.y, cell.x)
			return
		if same_cell and near_previous and interval < DOUBLE_TAP_MIN_MS:
			return
	if _interaction_allowed_for_cell(cell):
		cell_pressed.emit(cell.y, cell.x)
		_record_recent_tap(cell, position, now_msec)


func _record_recent_tap(cell: Vector2i, position: Vector2, released_at_msec: int) -> void:
	recent_tap_cell = cell
	recent_tap_position = position
	recent_tap_released_at_msec = released_at_msec


func _clear_recent_tap() -> void:
	recent_tap_cell = Vector2i(-1, -1)
	recent_tap_position = Vector2.ZERO
	recent_tap_released_at_msec = 0


func _should_ignore_mouse_event_after_touch() -> bool:
	return Time.get_ticks_msec() - last_screen_touch_msec <= TOUCH_MOUSE_SUPPRESS_MS


func _cell_at_position(position: Vector2) -> Vector2i:
	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	if not board_rect.has_point(position):
		return Vector2i(-1, -1)
	var cell_size: float = geometry["cell_size"]
	var col := int((position.x - board_rect.position.x) / cell_size)
	var row := int((position.y - board_rect.position.y) / cell_size)
	if row >= 0 and row < rows and col >= 0 and col < cols:
		return Vector2i(col, row)
	return Vector2i(-1, -1)


func _interaction_allowed_for_cell(cell: Vector2i) -> bool:
	if _cell_is_locked_for_input(cell):
		return false
	if guide_cells.size() > 0:
		return _guide_cell_is_actionable(cell)
	if tutorial_mask_enabled:
		return cell == tutorial_focus_cell
	return true


func _cell_is_locked_for_input(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= cell_states.size() or cell.x < 0 or cell.x >= cell_states[cell.y].size():
		return true
	var state: String = cell_states[cell.y][cell.x]
	return state == PIECE_MARK or state == HINT_MARK or state == KING_MARK or state == WRONG_MARK

func _draw() -> void:
	if regions.is_empty() or cell_states.is_empty():
		return

	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cell_size"]

	_draw_cell_gap_backgrounds(board_rect.position, cell_size)
	for row in range(rows):
		for col in range(cols):
			_draw_cell(row, col, board_rect.position, cell_size)
	_draw_board_outer_border(board_rect, cell_size)
	_draw_attention_mask(board_rect.position, cell_size)


func _draw_cell(row: int, col: int, origin: Vector2, cell_size: float) -> void:
	var rect := _cell_rect(row, col, origin, cell_size)
	var cell_key := Vector2i(col, row)
	var state: String = cell_states[row][col]
	var cell_pulse_strength := pulse_strength if cell_key == pulse_cell else 0.0
	if cell_pulse_strength > 0.0:
		rect = rect.grow(cell_size * 0.045 * cell_pulse_strength)
	if cell_key == shake_cell and shake_strength != 0.0:
		rect.position.x += round(shake_strength * cell_size * 0.055)
	var is_lion_state := state == PIECE_MARK or state == HINT_MARK or state == KING_MARK
	var king_reveal_scale := king_reveal_strength if is_lion_state and king_reveal_cells.has(cell_key) else 0.0

	var color := _cell_base_color(row, col)
	if error_cells.has(cell_key):
		color = color.lerp(Color("#FF5E67"), 0.58)
	elif victory_strength > 0.0:
		color = color.lerp(Color.WHITE, victory_strength * 0.32)

	var box := StyleBoxFlat.new()
	box.bg_color = color
	var corner_radius := _cell_corner_radius(cell_size)
	box.corner_radius_top_left = corner_radius
	box.corner_radius_top_right = corner_radius
	box.corner_radius_bottom_left = corner_radius
	box.corner_radius_bottom_right = corner_radius
	if error_cells.has(cell_key):
		box.border_color = Color("#D92F42")
		box.set_border_width_all(maxi(2, int(cell_size * 0.04)))
	elif not guide_mask_enabled and guide_cells.has(cell_key):
		box.border_color = UITokensScript.CROWN_GOLD
		box.set_border_width_all(maxi(2, int(cell_size * 0.035)))
	draw_style_box(box, rect)
	_draw_cell_pattern(rect, cell_size, _region_color_index_for_cell(row, col), color)

	if state == KING_MARK and hidden_king_cells.has(cell_key):
		pass
	elif state == PIECE_MARK or state == HINT_MARK or state == KING_MARK:
		_draw_piece(rect, cell_size, state == HINT_MARK, state == KING_MARK, king_reveal_scale, cell_pulse_strength)
	elif state == BLOCKED_MARK:
		_draw_blocked(rect, cell_size)
	elif state == WRONG_MARK:
		_draw_wrong(rect, cell_size)


func _draw_cell_gap_backgrounds(origin: Vector2, cell_size: float) -> void:
	var board_size := Vector2(float(cols) * cell_size, float(rows) * cell_size)
	draw_rect(Rect2(origin, board_size), UITokensScript.BOARD_GAP, true)


func _draw_board_outer_border(board_rect: Rect2, cell_size: float) -> void:
	var border_width := _region_border_width(cell_size)
	if border_width <= 0.0:
		return
	var outer_rect := _outer_border_rect(board_rect, cell_size)
	var corner_radius := _outer_border_corner_radius(cell_size, border_width)

	# Match the perimeter spacing to the existing gap between adjacent cells.
	var outer_gap := StyleBoxFlat.new()
	outer_gap.bg_color = Color.TRANSPARENT
	outer_gap.border_color = UITokensScript.BOARD_GAP
	outer_gap.set_border_width_all(int(border_width))
	outer_gap.corner_radius_top_left = corner_radius
	outer_gap.corner_radius_top_right = corner_radius
	outer_gap.corner_radius_bottom_left = corner_radius
	outer_gap.corner_radius_bottom_right = corner_radius
	draw_style_box(outer_gap, outer_rect.grow(border_width))

	# Build both glow bands outward so they never cover the board cells.
	var edge_width := maxi(1, int(round(border_width * 0.20)))
	var edge_radius := _cell_corner_radius(cell_size) + int(round(border_width * 0.5)) + edge_width
	var edge_expansion := border_width * 0.5
	var inner_glow_width := maxf(2.0, round(border_width * 0.38))
	var outer_glow_width := maxf(3.0, round(border_width * 0.72))

	var outer_glow := StyleBoxFlat.new()
	outer_glow.bg_color = Color.TRANSPARENT
	outer_glow.border_color = Color(0.93, 0.94, 0.95, 0.35)
	outer_glow.set_border_width_all(int(outer_glow_width))
	var outer_glow_radius := edge_radius + int(inner_glow_width + outer_glow_width)
	outer_glow.corner_radius_top_left = outer_glow_radius
	outer_glow.corner_radius_top_right = outer_glow_radius
	outer_glow.corner_radius_bottom_left = outer_glow_radius
	outer_glow.corner_radius_bottom_right = outer_glow_radius
	draw_style_box(
		outer_glow,
		outer_rect.grow(edge_expansion + inner_glow_width + outer_glow_width)
	)

	var inner_glow := StyleBoxFlat.new()
	inner_glow.bg_color = Color.TRANSPARENT
	inner_glow.border_color = Color(0.85, 0.87, 0.89, 0.70)
	inner_glow.set_border_width_all(int(inner_glow_width))
	var inner_glow_radius := edge_radius + int(inner_glow_width)
	inner_glow.corner_radius_top_left = inner_glow_radius
	inner_glow.corner_radius_top_right = inner_glow_radius
	inner_glow.corner_radius_bottom_left = inner_glow_radius
	inner_glow.corner_radius_bottom_right = inner_glow_radius
	draw_style_box(inner_glow, outer_rect.grow(edge_expansion + inner_glow_width))

	var edge_line := StyleBoxFlat.new()
	edge_line.bg_color = Color.TRANSPARENT
	edge_line.border_color = REGION_BORDER_COLOR
	edge_line.set_border_width_all(edge_width)
	edge_line.corner_radius_top_left = edge_radius
	edge_line.corner_radius_top_right = edge_radius
	edge_line.corner_radius_bottom_left = edge_radius
	edge_line.corner_radius_bottom_right = edge_radius
	draw_style_box(edge_line, outer_rect.grow(edge_expansion))


func _draw_attention_mask(origin: Vector2, cell_size: float) -> void:
	var should_mask_guides := not guide_cells.is_empty() and guide_mask_enabled
	if not should_mask_guides and not tutorial_mask_enabled:
		return
	var board_rect := Rect2(origin, Vector2(float(cols) * cell_size, float(rows) * cell_size))
	draw_rect(board_rect, UITokensScript.ATTENTION_MASK_COLOR, true)
	for row in range(rows):
		for col in range(cols):
			var cell_key := Vector2i(col, row)
			if _cell_is_attention_target(cell_key):
				_draw_cell(row, col, origin, cell_size)


func _draw_guide_halos(origin: Vector2, cell_size: float) -> void:
	if guide_pulse_strength <= 0.0 or guide_pulse_cells.is_empty():
		return
	for raw_cell in guide_pulse_cells.keys():
		if not raw_cell is Vector2i:
			continue
		var cell: Vector2i = raw_cell
		if cell.y < 0 or cell.y >= rows or cell.x < 0 or cell.x >= cols:
			continue
		var rect := _cell_rect(cell.y, cell.x, origin, cell_size)
		var corner_radius := _cell_corner_radius(cell_size)
		var outer_halo := StyleBoxFlat.new()
		outer_halo.bg_color = Color(1.0, 0.82, 0.34, 0.025 * guide_pulse_strength)
		outer_halo.shadow_color = Color(
			UITokensScript.ATTENTION_HALO_COLOR.r,
			UITokensScript.ATTENTION_HALO_COLOR.g,
			UITokensScript.ATTENTION_HALO_COLOR.b,
			UITokensScript.ATTENTION_HALO_COLOR.a * guide_pulse_strength
		)
		outer_halo.shadow_size = maxi(2, int(round(cell_size * (0.045 + 0.035 * guide_pulse_strength))))
		outer_halo.shadow_offset = Vector2.ZERO
		outer_halo.corner_radius_top_left = corner_radius
		outer_halo.corner_radius_top_right = corner_radius
		outer_halo.corner_radius_bottom_left = corner_radius
		outer_halo.corner_radius_bottom_right = corner_radius
		draw_style_box(outer_halo, rect)

		var inner_halo := StyleBoxFlat.new()
		inner_halo.bg_color = Color(1.0, 1.0, 1.0, 0.018 * guide_pulse_strength)
		inner_halo.shadow_color = Color(
			UITokensScript.ATTENTION_HALO_INNER_COLOR.r,
			UITokensScript.ATTENTION_HALO_INNER_COLOR.g,
			UITokensScript.ATTENTION_HALO_INNER_COLOR.b,
			UITokensScript.ATTENTION_HALO_INNER_COLOR.a * guide_pulse_strength
		)
		inner_halo.shadow_size = maxi(1, int(round(cell_size * 0.035)))
		inner_halo.shadow_offset = Vector2.ZERO
		inner_halo.corner_radius_top_left = corner_radius
		inner_halo.corner_radius_top_right = corner_radius
		inner_halo.corner_radius_bottom_left = corner_radius
		inner_halo.corner_radius_bottom_right = corner_radius
		draw_style_box(inner_halo, rect)


func _cell_is_attention_target(cell: Vector2i) -> bool:
	if guide_cells.size() > 0:
		return guide_cells.has(cell) or _cell_has_visible_mark(cell)
	if tutorial_mask_enabled:
		return cell == tutorial_focus_cell or _cell_has_visible_mark(cell)
	return true


func _cell_has_visible_mark(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= cell_states.size() or cell.x < 0 or cell.x >= cell_states[cell.y].size():
		return false
	var state: String = cell_states[cell.y][cell.x]
	return state == PIECE_MARK or state == HINT_MARK or state == KING_MARK or state == BLOCKED_MARK or state == WRONG_MARK


func _guide_cell_is_actionable(cell: Vector2i) -> bool:
	# Every cell included in a hint is part of the actionable focus area.
	# `unit` and `candidate` are also intentionally clickable; only cells
	# covered by the dimmed mask are blocked from input.
	return guide_cells.has(cell)


func _guide_kind(cell_key: Vector2i) -> String:
	var value = guide_cells.get(cell_key, "place")
	return str(value)


func _guide_kind_is_primary(kind: String) -> bool:
	return kind == "place" or kind == "exclude" or kind == "exclude_empty"


func _draw_piece(rect: Rect2, cell_size: float, is_hint: bool, _is_king: bool = false, king_reveal_scale: float = 0.0, cell_pulse_strength: float = 0.0) -> void:
	var texture_ratio := minf(
		UITokensScript.CROWN_MAX_FONT_RATIO,
		UITokensScript.CROWN_BASE_FONT_RATIO
		+ cell_pulse_strength * UITokensScript.CROWN_FEEDBACK_FONT_DELTA
		+ king_reveal_scale * UITokensScript.OPENING_CROWN_FONT_DELTA
	)
	var texture_size := cell_size * texture_ratio
	var texture_rect := Rect2(rect.get_center() - Vector2.ONE * texture_size * 0.5, Vector2.ONE * texture_size)
	if waiting_wiggle_strength > 0.0:
		var angle := sin(waiting_wiggle_strength * TAU * 2.0) * 0.08 * sin(waiting_wiggle_strength * PI)
		draw_set_transform(rect.get_center(), angle, Vector2.ONE)
		draw_texture_rect(PIECE_TEXTURE, Rect2(-Vector2.ONE * texture_size * 0.5, Vector2.ONE * texture_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(PIECE_TEXTURE, texture_rect, false)


func _draw_blocked(rect: Rect2, cell_size: float) -> void:
	var center := rect.get_center()
	var radius := cell_size * UITokensScript.BLOCKED_X_RADIUS_RATIO
	var width := maxf(3.0, cell_size * UITokensScript.BLOCKED_X_WIDTH_RATIO)
	var halo_width := width + maxf(1.5, cell_size * 0.020)
	var first_start := center - Vector2(radius, radius)
	var first_end := center + Vector2(radius, radius)
	var second_start := center + Vector2(radius, -radius)
	var second_end := center + Vector2(-radius, radius)
	draw_line(first_start, first_end, UITokensScript.BLOCKED_X_HALO_COLOR, halo_width, true)
	draw_line(second_start, second_end, UITokensScript.BLOCKED_X_HALO_COLOR, halo_width, true)
	draw_line(first_start, first_end, UITokensScript.BLOCKED_X_COLOR, width, true)
	draw_line(second_start, second_end, UITokensScript.BLOCKED_X_COLOR, width, true)


func _draw_wrong(rect: Rect2, cell_size: float) -> void:
	var center := rect.get_center()
	var radius := cell_size * 0.35
	var width := maxf(4.0, cell_size * UITokensScript.WRONG_X_WIDTH_RATIO)
	draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), UITokensScript.WRONG_X_HALO_COLOR, width + 2.5, true)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), UITokensScript.WRONG_X_HALO_COLOR, width + 2.5, true)
	draw_line(center - Vector2(radius, radius), center + Vector2(radius, radius), UITokensScript.WRONG_X_COLOR, width, true)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), UITokensScript.WRONG_X_COLOR, width, true)


func _draw_cell_pattern(rect: Rect2, cell_size: float, color_index: int, base_color: Color) -> void:
	var pattern_color := base_color.darkened(UITokensScript.REGION_PATTERN_DARKEN)
	pattern_color.a = UITokensScript.REGION_PATTERN_ALPHA
	var center := rect.get_center()
	var unit := cell_size / 100.0
	match color_index % 10:
		0:
			for offset in [Vector2(-18, -20), Vector2(18, -18), Vector2(-6, 18)]:
				draw_circle(center + offset * unit, 5.0 * unit, pattern_color, true, -1.0, true)
		1:
			for x_offset in [-20.0, 0.0, 20.0]:
				draw_line(center + Vector2(x_offset, -18) * unit, center + Vector2(x_offset, 18) * unit, pattern_color, maxf(2.0, cell_size * 0.040), true)
		2:
			for offset in [Vector2(-12, -18), Vector2(14, -16), Vector2(0, 10)]:
				draw_circle(center + offset * unit, 6.0 * unit, pattern_color, true, -1.0, true)
			draw_circle(center + Vector2(0, 20) * unit, 11.0 * unit, pattern_color, true, -1.0, true)
		3:
			for x_offset in [-18.0, 18.0]:
				draw_arc(center + Vector2(x_offset, 0) * unit, 17.0 * unit, -0.95, 1.05, 18, pattern_color, maxf(2.0, cell_size * 0.04), true)
		4:
			for offset in [Vector2(0, -22), Vector2(22, 0), Vector2(0, 22), Vector2(-22, 0)]:
				draw_circle(center + offset * unit, 5.5 * unit, pattern_color, true, -1.0, true)
			draw_circle(center, 4.0 * unit, pattern_color, true, -1.0, true)
		5:
			for offset in [-22.0, 5.0, 32.0]:
				draw_line(rect.position + Vector2(offset * unit, 0), rect.position + Vector2((offset + 36.0) * unit, rect.size.y), pattern_color, maxf(2.0, cell_size * 0.032), true)
		6:
			draw_arc(center, 20.0 * unit, 0.0, TAU, 28, pattern_color, maxf(2.0, cell_size * 0.035), true)
			draw_circle(center, 4.5 * unit, pattern_color, true, -1.0, true)
		7:
			for y_offset in [-18.0, 12.0]:
				draw_line(center + Vector2(-22, y_offset) * unit, center + Vector2(22, y_offset) * unit, pattern_color, maxf(2.0, cell_size * 0.035), true)
		8:
			for offset in [Vector2(-14, -12), Vector2(12, 10)]:
				draw_arc(center + offset * unit, 16.0 * unit, -0.30, 2.85, 20, pattern_color, maxf(2.0, cell_size * 0.038), true)
		9:
			var radius := cell_size * 0.22
			draw_line(center + Vector2(0, -radius), center + Vector2(radius, 0), pattern_color, maxf(2.0, cell_size * 0.04), true)
			draw_line(center + Vector2(radius, 0), center + Vector2(0, radius), pattern_color, maxf(2.0, cell_size * 0.04), true)
			draw_line(center + Vector2(0, radius), center + Vector2(-radius, 0), pattern_color, maxf(2.0, cell_size * 0.04), true)
			draw_line(center + Vector2(-radius, 0), center + Vector2(0, -radius), pattern_color, maxf(2.0, cell_size * 0.04), true)


func _board_geometry() -> Dictionary:
	var max_dimension: int = maxi(1, maxi(rows, cols))
	var usable_size := Vector2(
		maxf(1.0, floor(size.x - BOARD_LAYOUT_INSET)),
		maxf(1.0, floor(size.y - BOARD_LAYOUT_INSET))
	)
	var board_size: float = floor(minf(usable_size.x, usable_size.y))
	var cell_size: float = maxf(1.0, floor(board_size / float(max_dimension)))
	var actual_size := Vector2(cols * cell_size, rows * cell_size)
	var board_position: Vector2 = ((size - actual_size) * 0.5).floor()
	return {"rect": Rect2(board_position, actual_size), "cell_size": cell_size}


func _cell_rect(row: int, col: int, origin: Vector2, cell_size: float) -> Rect2:
	var gap := _cell_gap(cell_size)
	return Rect2(origin + Vector2(col, row) * cell_size + Vector2.ONE * gap, Vector2.ONE * (cell_size - gap * 2.0))


func _cell_base_color(row: int, col: int) -> Color:
	if region_colors.is_empty():
		return Color.WHITE
	var index := _region_color_index_for_cell(row, col)
	var color: Color = region_colors[index]
	return color


func _region_color_index_for_cell(row: int, col: int) -> int:
	if region_colors.is_empty():
		return 0
	return posmod(int(regions[row][col]) - 1, region_colors.size())


func _gap_color_between(first_row: int, first_col: int, _second_row: int, _second_col: int) -> Color:
	return _same_region_gap_color(first_row, first_col)


func _gap_corner_color(row: int, col: int) -> Color:
	return _same_region_gap_color(row, col)


func _region_id_for_cell(row: int, col: int) -> int:
	return int(regions[row][col])


func _same_region_gap_color(row: int, col: int) -> Color:
	return UITokensScript.same_region_gap_color(_cell_base_color(row, col))


func _cell_gap(cell_size: float) -> float:
	return UITokensScript.cell_gap(cell_size)


func _cell_corner_radius(cell_size: float) -> int:
	return UITokensScript.cell_corner_radius(cell_size)


func _outer_border_rect(board_rect: Rect2, cell_size: float) -> Rect2:
	var first_cell := _cell_rect(0, 0, board_rect.position, cell_size)
	var last_cell := _cell_rect(rows - 1, cols - 1, board_rect.position, cell_size)
	return Rect2(first_cell.position, last_cell.end - first_cell.position)


func _outer_border_corner_radius(cell_size: float, border_width: float) -> int:
	return _cell_corner_radius(cell_size) + int(border_width)


func _region_border_width(cell_size: float) -> float:
	# Match the outer frame to the actual gap between adjacent cells.
	return _cell_gap(cell_size) * 2.0
