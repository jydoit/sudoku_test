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

var rows := 6
var cols := 6
var regions: Array = []
var cell_states: Array = []
var error_cells: Dictionary = {}
var guide_cells: Dictionary = {}
var region_colors: Array = []
var pulse_cell := Vector2i(-1, -1)
var pulse_strength := 0.0
var guide_pulse_cell := Vector2i(-1, -1)
var guide_pulse_cells: Dictionary = {}
var guide_pulse_strength := 0.0
var king_reveal_cells: Dictionary = {}
var hidden_king_cells: Dictionary = {}
var king_reveal_strength := 0.0
var victory_strength := 0.0
var tutorial_mask_enabled := false
var tutorial_focus_cell := Vector2i(-1, -1)
var press_cell := Vector2i(-1, -1)
var last_drag_cell := Vector2i(-1, -1)
var tracking_press := false
var dragging := false



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


func set_guides(guides: Dictionary) -> void:
	guide_cells = guides
	guide_pulse_cell = Vector2i(-1, -1)
	guide_pulse_cells.clear()
	guide_pulse_strength = 0.0
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


func play_guide_feedback(row: int, col: int) -> void:
	guide_pulse_cell = Vector2i(-1, -1)
	guide_pulse_cells.clear()
	guide_pulse_strength = 0.0
	queue_redraw()


func play_guide_feedback_for_cells(cells: Array) -> void:
	guide_pulse_cell = Vector2i(-1, -1)
	guide_pulse_cells.clear()
	guide_pulse_strength = 0.0
	queue_redraw()


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
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_guide_pulse, 0.0, 1.0, 0.22)
	tween.tween_method(_set_guide_pulse, 1.0, 0.18, 0.30)
	tween.tween_method(_set_guide_pulse, 0.18, 1.0, 0.22)
	tween.tween_method(_set_guide_pulse, 1.0, 0.0, 0.36)


func play_victory() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_victory, 0.0, 1.0, 0.24)
	tween.tween_method(_set_victory, 1.0, 0.0, 0.34)


func _set_pulse(value: float) -> void:
	pulse_strength = value
	queue_redraw()


func _set_guide_pulse(value: float) -> void:
	guide_pulse_strength = value
	queue_redraw()


func _set_king_reveal(value: float) -> void:
	king_reveal_strength = value
	queue_redraw()


func _set_victory(value: float) -> void:
	victory_strength = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_pointer(event.position, event.double_click)
		else:
			_finish_pointer(event.position)
		accept_event()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_pointer(event.position, event.double_tap)
		else:
			_finish_pointer(event.position)
		accept_event()
		return
	if event is InputEventMouseMotion and tracking_press and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_update_drag(event.position)
		accept_event()
		return
	if event is InputEventScreenDrag and tracking_press:
		_update_drag(event.position)
		accept_event()


func _start_pointer(position: Vector2, is_double: bool) -> void:
	var cell := _cell_at_position(position)
	if cell.x < 0 or not _interaction_allowed_for_cell(cell):
		_reset_pointer()
		return
	if is_double:
		_reset_pointer()
		cell_double_pressed.emit(cell.y, cell.x)
		return
	tracking_press = true
	dragging = false
	press_cell = cell
	last_drag_cell = cell


func _finish_pointer(position: Vector2) -> void:
	if not tracking_press:
		_reset_pointer()
		return
	if dragging:
		cell_drag_ended.emit()
	else:
		var cell := _cell_at_position(position)
		if cell == press_cell and _interaction_allowed_for_cell(cell):
			cell_pressed.emit(cell.y, cell.x)
	_reset_pointer()


func _update_drag(position: Vector2) -> void:
	var cell := _cell_at_position(position)
	if cell.x < 0 or cell == last_drag_cell or not _interaction_allowed_for_cell(cell):
		return
	if not dragging:
		dragging = true
		cell_drag_started.emit(press_cell.y, press_cell.x)
	last_drag_cell = cell
	cell_dragged.emit(cell.y, cell.x)


func _reset_pointer() -> void:
	tracking_press = false
	dragging = false
	press_cell = Vector2i(-1, -1)
	last_drag_cell = Vector2i(-1, -1)


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
	if guide_cells.size() > 0:
		return _guide_cell_is_actionable(cell)
	if tutorial_mask_enabled:
		return cell == tutorial_focus_cell
	return true

func _draw() -> void:
	if regions.is_empty() or cell_states.is_empty():
		return

	var geometry := _board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cell_size"]
	var outer := StyleBoxFlat.new()
	outer.bg_color = Color("#FFFFFF").lerp(Color("#F7FAFF"), victory_strength * 0.32)
	outer.corner_radius_top_left = 22
	outer.corner_radius_top_right = 22
	outer.corner_radius_bottom_left = 22
	outer.corner_radius_bottom_right = 22
	draw_style_box(outer, board_rect.grow(_region_border_width(cell_size) * 0.5))

	_draw_cell_gap_backgrounds(board_rect.position, cell_size)
	for row in range(rows):
		for col in range(cols):
			_draw_cell(row, col, board_rect.position, cell_size)
	_draw_region_borders(board_rect.position, cell_size)
	_draw_attention_mask(board_rect.position, cell_size)


func _draw_cell(row: int, col: int, origin: Vector2, cell_size: float) -> void:
	var rect := _cell_rect(row, col, origin, cell_size)
	var cell_key := Vector2i(col, row)
	var state: String = cell_states[row][col]
	var cell_pulse_strength := pulse_strength if cell_key == pulse_cell else 0.0
	if cell_pulse_strength > 0.0:
		rect = rect.grow(cell_size * 0.045 * cell_pulse_strength)
	var king_reveal_scale := king_reveal_strength if state == KING_MARK and king_reveal_cells.has(cell_key) else 0.0

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
	draw_style_box(box, rect)

	if state == KING_MARK and hidden_king_cells.has(cell_key):
		pass
	elif state == PIECE_MARK or state == HINT_MARK or state == KING_MARK:
		_draw_piece(rect, cell_size, state == HINT_MARK, state == KING_MARK, king_reveal_scale, cell_pulse_strength)
	elif state == BLOCKED_MARK:
		_draw_blocked(rect, cell_size)
	elif state == WRONG_MARK:
		_draw_wrong(rect, cell_size)


func _draw_cell_gap_backgrounds(origin: Vector2, cell_size: float) -> void:
	var gap := _cell_gap(cell_size)
	var strip_size := gap * 2.0

	for row in range(rows):
		for col in range(cols):
			var slot_rect := Rect2(origin + Vector2(col, row) * cell_size, Vector2.ONE * cell_size)
			draw_rect(slot_rect, _same_region_gap_color(row, col), true)

	for row in range(rows):
		for col in range(cols - 1):
			var rect := Rect2(
				Vector2(origin.x + (col + 1) * cell_size - gap, origin.y + row * cell_size + gap),
				Vector2(strip_size, cell_size - gap * 2.0)
			)
			draw_rect(rect, _gap_color_between(row, col, row, col + 1), true)

	for row in range(rows - 1):
		for col in range(cols):
			var rect := Rect2(
				Vector2(origin.x + col * cell_size + gap, origin.y + (row + 1) * cell_size - gap),
				Vector2(cell_size - gap * 2.0, strip_size)
			)
			draw_rect(rect, _gap_color_between(row, col, row + 1, col), true)

	for row in range(rows - 1):
		for col in range(cols - 1):
			var rect := Rect2(
				Vector2(origin.x + (col + 1) * cell_size - gap, origin.y + (row + 1) * cell_size - gap),
				Vector2(strip_size, strip_size)
			)
			draw_rect(rect, _gap_corner_color(row, col), true)


func _draw_region_borders(origin: Vector2, cell_size: float) -> void:
	var border_width := _region_border_width(cell_size)
	var board_width := float(cols) * cell_size
	var board_height := float(rows) * cell_size
	draw_rect(Rect2(origin, Vector2(board_width, border_width)), REGION_BORDER_COLOR, true)
	draw_rect(Rect2(Vector2(origin.x, origin.y + board_height - border_width), Vector2(board_width, border_width)), REGION_BORDER_COLOR, true)
	draw_rect(Rect2(origin, Vector2(border_width, board_height)), REGION_BORDER_COLOR, true)
	draw_rect(Rect2(Vector2(origin.x + board_width - border_width, origin.y), Vector2(border_width, board_height)), REGION_BORDER_COLOR, true)


func _draw_attention_mask(origin: Vector2, cell_size: float) -> void:
	if guide_cells.is_empty() and not tutorial_mask_enabled:
		return
	for row in range(rows):
		for col in range(cols):
			var cell_key := Vector2i(col, row)
			if _cell_is_attention_target(cell_key):
				continue
			var rect := _cell_rect(row, col, origin, cell_size)
			var mask_box := StyleBoxFlat.new()
			mask_box.bg_color = Color(0.82, 0.84, 0.88, 0.58)
			var corner_radius := _cell_corner_radius(cell_size)
			mask_box.corner_radius_top_left = corner_radius
			mask_box.corner_radius_top_right = corner_radius
			mask_box.corner_radius_bottom_left = corner_radius
			mask_box.corner_radius_bottom_right = corner_radius
			draw_style_box(mask_box, rect)


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


func _draw_piece(rect: Rect2, cell_size: float, is_hint: bool, _is_king: bool = false, king_reveal_scale: float = 0.0, cell_pulse_strength: float = 0.0) -> void:
	if is_hint:
		draw_circle(rect.get_center(), cell_size * 0.35, Color(1.0, 0.84, 0.35, 0.34))
	var texture_ratio := minf(
		UITokensScript.CROWN_MAX_FONT_RATIO,
		UITokensScript.CROWN_BASE_FONT_RATIO
		+ cell_pulse_strength * UITokensScript.CROWN_FEEDBACK_FONT_DELTA
		+ king_reveal_scale * UITokensScript.OPENING_CROWN_FONT_DELTA
	)
	var texture_size := cell_size * texture_ratio
	var texture_rect := Rect2(rect.get_center() - Vector2.ONE * texture_size * 0.5, Vector2.ONE * texture_size)
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
	var texture_size := cell_size * UITokensScript.CROWN_MAX_FONT_RATIO
	var texture_rect := Rect2(rect.get_center() - Vector2.ONE * texture_size * 0.5, Vector2.ONE * texture_size)
	draw_texture_rect(WRONG_PIECE_TEXTURE, texture_rect, false)

	var badge_center := rect.position + rect.size * Vector2(0.78, 0.78)
	var badge_radius := cell_size * 0.135
	var x_radius := badge_radius * 0.48
	var x_width := maxf(2.4, cell_size * 0.038)
	draw_circle(badge_center, badge_radius, UITokensScript.WRONG_X_BACKDROP_COLOR)
	draw_line(badge_center - Vector2(x_radius, x_radius), badge_center + Vector2(x_radius, x_radius), UITokensScript.WRONG_X_HALO_COLOR, x_width + 2.0, true)
	draw_line(badge_center + Vector2(x_radius, -x_radius), badge_center + Vector2(-x_radius, x_radius), UITokensScript.WRONG_X_HALO_COLOR, x_width + 2.0, true)
	draw_line(badge_center - Vector2(x_radius, x_radius), badge_center + Vector2(x_radius, x_radius), UITokensScript.WRONG_X_COLOR, x_width, true)
	draw_line(badge_center + Vector2(x_radius, -x_radius), badge_center + Vector2(-x_radius, x_radius), UITokensScript.WRONG_X_COLOR, x_width, true)


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


func _gap_color_between(first_row: int, first_col: int, second_row: int, second_col: int) -> Color:
	if _region_id_for_cell(first_row, first_col) == _region_id_for_cell(second_row, second_col):
		return _same_region_gap_color(first_row, first_col)
	return REGION_BORDER_COLOR


func _gap_corner_color(row: int, col: int) -> Color:
	var region_id := _region_id_for_cell(row, col)
	if _region_id_for_cell(row, col + 1) != region_id:
		return REGION_BORDER_COLOR
	if _region_id_for_cell(row + 1, col) != region_id:
		return REGION_BORDER_COLOR
	if _region_id_for_cell(row + 1, col + 1) != region_id:
		return REGION_BORDER_COLOR
	return _same_region_gap_color(row, col)


func _region_id_for_cell(row: int, col: int) -> int:
	return int(regions[row][col])


func _same_region_gap_color(row: int, col: int) -> Color:
	return UITokensScript.same_region_gap_color(_cell_base_color(row, col))


func _cell_gap(cell_size: float) -> float:
	return UITokensScript.cell_gap(cell_size)


func _cell_corner_radius(cell_size: float) -> int:
	return UITokensScript.cell_corner_radius(cell_size)


func _region_border_width(_cell_size: float) -> float:
	return UITokensScript.board_border_width(maxi(rows, cols))
