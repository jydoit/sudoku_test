extends SceneTree

const View = preload("res://scripts/assembly_view.gd")
const Controller = preload("res://scripts/controllers/composite_game_controller.gd")
const Level = preload("res://scripts/composite_level.gd")
const Tokens = preload("res://scripts/ui_tokens.gd")
var view
var controller
var data: Dictionary
var placed_events: Array = []
var rejected := 0
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _setup_state(placements: Dictionary = {}) -> void:
	controller.placements = placements.duplicate(true)
	controller.tray_slots = Level.sanitize_tray_slots(data, placements)
	view.configure(data, placements, Tokens.REGION_COLORS, controller.allowed_origins(), controller.tray_slots)
	placed_events.clear()
	rejected = 0

func _run() -> void:
	root.size = Vector2i(540, 960)
	var board := Control.new()
	board.position = Vector2(6, 290)
	board.size = Vector2(528, 528)
	root.add_child(board)
	var tray := Control.new()
	tray.position = Vector2(6, 160)
	tray.size = Vector2(528, 118)
	root.add_child(tray)
	view = View.new()
	root.add_child(view)
	view.size = Vector2(540, 960)
	view.bind_targets(board, tray)
	data = load("res://data/runtime/composite_size_6.res").entries["2342:hard"]
	controller = Controller.new()
	controller.data = data
	controller.mode = true
	controller.phase = "assembly"
	view.placement_requested.connect(func(id, origin): placed_events.append([id, origin]))
	view.placement_rejected.connect(func(): rejected += 1)
	view.return_requested.connect(func(id, slot):
		var returned: int = controller.return_piece(id, slot)
		view.update_state(controller.placements, controller.allowed_origins(), controller.tray_slots)
		view.focus_tray_slot(returned)
		view.play_return_feedback(returned)
	)

	# No render pass is required for hit testing, including immediately after sorting.
	for pointer_id in [-1, 7]:
		_setup_state()
		var start: Vector2 = view._tray_slot_rect(0).get_center()
		view._pointer_pressed(start, pointer_id)
		_expect(view._press_piece_id == controller.tray_slots[0], "Hit test before first draw")
		view._pointer_moved(start + Vector2(7, 1), pointer_id)
		_expect(view._interaction_mode == "pending", "Small lateral jitter stays undecided")
		view._pointer_moved(start + Vector2(8, 10), pointer_id)
		_expect(view._interaction_mode == "drag", "Diagonal downward pickup wins after jitter")
		view._pointer_moved(start + Vector2(40, 10), pointer_id)
		_expect(view._interaction_mode == "drag", "Active drag cannot become tray scrolling")
		view._reset_pointer()
		view._pointer_pressed(start, pointer_id)
		view._pointer_moved(start + Vector2(-44, -8), pointer_id)
		_expect(view._interaction_mode == "scroll" and view.tray_scroll > 0, "Deliberate horizontal swipe scrolls")
		view._pointer_released(start + Vector2(-44, -8), pointer_id)
		view.focus_tray_slot(4, false)
		var scrolled_start: Vector2 = view._tray_slot_rect(4).get_center()
		view._pointer_pressed(scrolled_start, pointer_id)
		_expect(view._press_piece_id == controller.tray_slots[4], "Hit regions follow scroll without waiting for draw")
		view._reset_pointer()

	var piece: Dictionary = data.pieces[0]
	var piece_id: int = piece.pieceId
	var origin: Array = piece.initialOrigin
	_setup_state({str(piece_id): origin})
	var cell_size: float = view._board_geometry().cellSize
	var corner: Vector2 = view._board_draw_rect().position + Vector2(origin[1], origin[0]) * cell_size
	var first_cell: Array = piece.cells[0]
	var press := corner + Vector2(float(first_cell[1]) + 0.5, float(first_cell[0]) + 0.5) * cell_size
	view._pointer_pressed(press, 7)
	view._pointer_moved(press + Vector2(0, 14), 7)
	var visual_corner: Vector2 = view._last_pointer - view._pointer_offset_for_piece(piece, cell_size)
	_expect(visual_corner.is_equal_approx(corner + Vector2(0, 14)), "Board pickup preserves exact grab offset")
	_expect(view._origin_for_pointer(press) == Vector2i(origin[1], origin[0]), "Snap uses the same board grab anchor")
	view._pointer_released(press, 7)
	_expect(placed_events.size() == 1 and placed_events[0][1] == origin, "Board move releases using the preserved anchor")

	_setup_state()
	var slot: int = controller.tray_slots.find(piece_id)
	view.focus_tray_slot(slot, false)
	var start: Vector2 = view._tray_slot_rect(slot).get_center()
	view._pointer_pressed(start, 7)
	view._pointer_moved(start + Vector2(0, 14), 7)
	view._preview_origin = Vector2i(-99, -99)
	var release_at: Vector2 = view._snap_pointer_for_origin(piece_id, Vector2i(origin[1], origin[0]))
	view._pointer_released(release_at, 7)
	_expect(placed_events.size() == 1 and placed_events[0][1] == origin and rejected == 0, "Valid release replaces stale invalid preview")
	view._pointer_pressed(start, 7)
	view._pointer_moved(start + Vector2(0, 14), 7)
	view._preview_origin = Vector2i(origin[1], origin[0])
	view._pointer_released(Vector2(-1000, -1000), 7)
	_expect(placed_events.size() == 1 and rejected == 1, "Invalid release cannot commit stale valid preview")

	_setup_state({str(piece_id): origin})
	view._pointer_pressed(press, 7)
	view._pointer_moved(press + Vector2(0, 14), 7)
	var return_point: Vector2 = view._tray_rect().get_center()
	view._pointer_moved(return_point, 7)
	var expected_slots := Level.sanitize_tray_slots(data, {})
	_expect(view._return_preview_slots == expected_slots, "Return preview uses final sorted order")
	_expect(view._return_slot_index == expected_slots.find(piece_id), "Return preview uses final insertion slot")
	view._tray_focus_tween.custom_step(0.07)
	var scroll_at_release: float = view.tray_scroll
	var focus_tween: Tween = view._tray_focus_tween
	view._pointer_released(return_point, 7)
	_expect(not controller.placements.has(str(piece_id)), "Return commits on release")
	_expect(controller.tray_slots == expected_slots, "Committed order exactly matches preview")
	_expect(is_equal_approx(view.tray_scroll, scroll_at_release), "Release cannot snap tray to another scroll position")
	_expect(view._tray_focus_tween == focus_tween, "Return commit does not restart focus tween")
	focus_tween.custom_step(0.3)

	_setup_state({str(piece_id): origin})
	view._pointer_pressed(press, 7)
	view._pointer_moved(press + Vector2(0, 14), 7)
	view._pointer_moved(return_point, 7)
	view._pointer_moved(press, 7)
	_expect(view._return_preview_slots.is_empty() and view._return_slot_index == -1, "Leaving return zone cancels preview only")
	_expect(controller.placements.has(str(piece_id)), "Hovering does not mutate live placements")
	view._pointer_released(return_point, 7)
	_expect(not controller.placements.has(str(piece_id)), "Return release works without final drag event")

	_setup_state()
	view._pointer_pressed(view._tray_slot_rect(0).get_center(), 7)
	var cancelled := InputEventScreenTouch.new()
	cancelled.index = 7
	cancelled.canceled = true
	view._input(cancelled)
	_expect(not view._pointer_down and placed_events.is_empty(), "Cancelled touch never commits a piece")
	view.free()
	board.free()
	tray.free()
	print("ASSEMBLY DRAG: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
