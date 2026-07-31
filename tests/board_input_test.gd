extends SceneTree

const GameBoardScript = preload("res://scripts/game_board.gd")

var pressed_cells: Array[Vector2i] = []
var double_pressed_cells: Array[Vector2i] = []
var drag_started_cells: Array[Vector2i] = []
var dragged_cells: Array[Vector2i] = []
var drag_end_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("CASES BOARD-010..015")
	var board: GameBoard = GameBoardScript.new()
	root.add_child(board)
	board.size = Vector2(420, 420)
	board.set_level(
		{
			"rows": 2,
			"cols": 2,
			"regions": [[0, 0], [1, 1]]
		},
		[
			["empty", "empty"],
			["empty", "empty"]
		],
		[Color("#3AA8F2"), Color("#FFD94A")]
	)
	board.cell_pressed.connect(func(row: int, col: int) -> void:
		pressed_cells.append(Vector2i(col, row))
	)
	board.cell_double_pressed.connect(func(row: int, col: int) -> void:
		double_pressed_cells.append(Vector2i(col, row))
	)
	board.cell_drag_started.connect(func(row: int, col: int) -> void:
		drag_started_cells.append(Vector2i(col, row))
	)
	board.cell_dragged.connect(func(row: int, col: int) -> void:
		dragged_cells.append(Vector2i(col, row))
	)
	board.cell_drag_ended.connect(func() -> void:
		drag_end_count += 1
	)
	await process_frame

	var first := _cell_center(board, 0, 0)
	var second := _cell_center(board, 0, 1)

	_touch_tap(board, first)
	assert(pressed_cells == [Vector2i(0, 0)], "BOARD-010 single screen tap should emit one normal tap immediately")
	assert(double_pressed_cells.is_empty(), "BOARD-010 single screen tap must not emit a double tap")
	_clear_events(board)

	_touch_tap(board, first)
	_mouse_tap(board, first)
	assert(pressed_cells == [Vector2i(0, 0)], "BOARD-013 touch plus Android-compatible mouse duplicate should still emit one tap")
	assert(double_pressed_cells.is_empty(), "BOARD-013 touch plus mouse duplicate must not become a double tap")
	_clear_events(board)

	_touch_tap(board, first)
	_touch_tap(board, first)
	assert(pressed_cells == [Vector2i(0, 0)], "BOARD-012 two same-cell taps below the minimum interval should collapse to one single tap")
	assert(double_pressed_cells.is_empty(), "BOARD-012 taps below the minimum interval must not emit double tap")
	_clear_events(board)

	_touch_tap(board, first)
	board.recent_tap_released_at_msec = Time.get_ticks_msec() - 160
	_touch_tap(board, first)
	assert(pressed_cells == [Vector2i(0, 0)], "BOARD-011 valid double tap starts with an immediate single tap for responsive feedback")
	assert(double_pressed_cells == [Vector2i(0, 0)], "BOARD-011 valid double tap should emit one double tap on the same cell")
	_clear_events(board)

	_touch_tap(board, first)
	board.recent_tap_released_at_msec = Time.get_ticks_msec() - 400
	_touch_tap(board, first)
	assert(pressed_cells == [Vector2i(0, 0), Vector2i(0, 0)], "BOARD-012 taps outside the double window should remain two single taps")
	assert(double_pressed_cells.is_empty(), "BOARD-012 taps outside the double window must not emit double tap")
	_clear_events(board)

	_touch_tap(board, first)
	board.recent_tap_released_at_msec = Time.get_ticks_msec() - 160
	_touch_tap(board, second)
	assert(pressed_cells == [Vector2i(0, 0), Vector2i(1, 0)], "BOARD-012 cross-cell taps should remain separate single taps")
	assert(double_pressed_cells.is_empty(), "BOARD-012 cross-cell taps must not emit double tap")
	_clear_events(board)

	_touch_drag(board, first, second)
	assert(pressed_cells.is_empty() and double_pressed_cells.is_empty(), "BOARD-014 drag should not emit tap or double tap")
	assert(drag_started_cells == [Vector2i(0, 0)] and dragged_cells == [Vector2i(1, 0)] and drag_end_count == 1, "BOARD-014 drag should emit only drag signals")
	_clear_events(board)

	board.set_states([
		["piece", "hint"],
		["king", "wrong"]
	])
	for row in range(2):
		for col in range(2):
			_touch_tap(board, _cell_center(board, row, col))
			await create_timer(0.16).timeout
			_touch_tap(board, _cell_center(board, row, col))
	assert(pressed_cells.is_empty() and double_pressed_cells.is_empty(), "BOARD-015 locked lion and red-X states should ignore single and double taps")

	print("BOARD INPUT TEST PASSED")
	board.queue_free()
	quit()


func _cell_center(board: GameBoard, row: int, col: int) -> Vector2:
	var geometry := board._board_geometry()
	var board_rect: Rect2 = geometry["rect"]
	var cell_size: float = geometry["cell_size"]
	return board_rect.position + Vector2(float(col) + 0.5, float(row) + 0.5) * cell_size


func _touch_tap(board: GameBoard, position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.position = position
	press.pressed = true
	board._gui_input(press)
	var release := InputEventScreenTouch.new()
	release.position = position
	release.pressed = false
	board._gui_input(release)


func _mouse_tap(board: GameBoard, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.pressed = true
	board._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.pressed = false
	board._gui_input(release)


func _touch_drag(board: GameBoard, start_position: Vector2, end_position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.position = start_position
	press.pressed = true
	board._gui_input(press)
	var drag := InputEventScreenDrag.new()
	drag.position = end_position
	board._gui_input(drag)
	var release := InputEventScreenTouch.new()
	release.position = end_position
	release.pressed = false
	board._gui_input(release)


func _clear_events(board: GameBoard) -> void:
	pressed_cells.clear()
	double_pressed_cells.clear()
	drag_started_cells.clear()
	dragged_cells.clear()
	drag_end_count = 0
	board._clear_recent_tap()
