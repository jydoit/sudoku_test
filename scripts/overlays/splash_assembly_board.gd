class_name SplashAssemblyBoard
extends Control

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const BLOCK_TILE_TEXTURE: Texture2D = preload("res://assets/ui/block_tile_neutral.svg")
const LION_TEXTURE: Texture2D = preload("res://assets/ui/lion_king.svg")
const HAPPY_LION_TEXTURE: Texture2D = preload("res://assets/ui/lion_king_happy.svg")

# Baked from the real offline composite entry `103:hard`. Keeping this small
# snapshot in the Splash avoids synchronously loading the full 6x6 bundle while
# startup data is still being prepared. The smoke test compares it with the
# runtime catalog and verifies that the five pieces exactly cover every well.
const SOURCE_ENTRY_KEY := "103:hard"
const ROWS := 6
const COLS := 6
const BASE_REGIONS := [
	[2, 1, 1, 1, 4, 4],
	[2, 2, 2, 1, 4, 4],
	[2, 2, 3, 3, 4, 4],
	[2, 5, 4, 4, 4, 6],
	[5, 5, 4, 6, 4, 6],
	[5, 5, 5, 6, 6, 6],
]
const CONSTRUCTION_CELLS := [
	[0, 2], [0, 3], [1, 3],
	[4, 0], [4, 1], [4, 3], [4, 5],
	[5, 0], [5, 1], [5, 2], [5, 3], [5, 4], [5, 5],
]
const PIECES := [
	{"pieceId": 0, "regionId": 1, "cells": [[0, 0], [0, 1], [1, 1]], "origin": [0, 2]},
	{"pieceId": 1, "regionId": 5, "cells": [[0, 0], [0, 1], [1, 0]], "origin": [4, 0]},
	{"pieceId": 2, "regionId": 5, "cells": [[0, 0], [0, 1]], "origin": [5, 1]},
	{"pieceId": 3, "regionId": 6, "cells": [[0, 1], [1, 0], [1, 1]], "origin": [4, 4]},
	{"pieceId": 4, "regionId": 6, "cells": [[0, 0], [1, 0]], "origin": [4, 3]},
]
const PLACEMENT_ORDER := [1, 0, 3, 4, 2]
const KING_SOLUTION := [[0, 3], [1, 0], [2, 2], [3, 4], [4, 1], [5, 5]]

const BOARD_CELL_SIZE := 44.0
const DOCK_CELL_SIZE := 18.0
const BOARD_TOP := 48.0
const DOCK_TOP := 342.0
const DOCK_HEIGHT := 76.0
const PIECE_ARC_HEIGHT := 42.0
const VICTORY_SPARK_POINTS := [
	Vector2(0.05, 0.12), Vector2(0.28, 0.04), Vector2(0.58, 0.06),
	Vector2(0.91, 0.14), Vector2(0.96, 0.52), Vector2(0.84, 0.92),
	Vector2(0.48, 0.96), Vector2(0.12, 0.86),
]

var assembly_progress := 0.0:
	set(value):
		assembly_progress = clampf(value, 0.0, float(PIECES.size()))
		queue_redraw()

var flatten_amount := 0.0:
	set(value):
		flatten_amount = clampf(value, 0.0, 1.0)
		queue_redraw()

var king_reveal_progress := 0.0:
	set(value):
		king_reveal_progress = clampf(value, 0.0, float(KING_SOLUTION.size()))
		queue_redraw()

var victory_progress := 0.0:
	set(value):
		victory_progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	queue_redraw()


static func fixture_data() -> Dictionary:
	return {
		"sourceEntryKey": SOURCE_ENTRY_KEY,
		"rows": ROWS,
		"cols": COLS,
		"baseRegions": BASE_REGIONS.duplicate(true),
		"constructionCells": CONSTRUCTION_CELLS.duplicate(true),
		"pieces": PIECES.duplicate(true),
		"placementOrder": PLACEMENT_ORDER.duplicate(),
		"solution": KING_SOLUTION.duplicate(true),
	}


func reset_visuals() -> void:
	assembly_progress = 0.0
	flatten_amount = 0.0
	king_reveal_progress = 0.0
	victory_progress = 0.0
	scale = Vector2.ONE


func show_stable_final() -> void:
	assembly_progress = float(PIECES.size())
	flatten_amount = 1.0
	king_reveal_progress = float(KING_SOLUTION.size())
	victory_progress = 1.0
	scale = Vector2.ONE


func _draw() -> void:
	var board_origin := Vector2((size.x - BOARD_CELL_SIZE * COLS) * 0.5, BOARD_TOP)
	var board_rect := Rect2(board_origin, Vector2(BOARD_CELL_SIZE * COLS, BOARD_CELL_SIZE * ROWS))
	var construction := _construction_cell_set()
	_draw_board_base(board_rect)
	for row in range(ROWS):
		for col in range(COLS):
			var cell := Vector2i(col, row)
			var rect := Rect2(board_origin + Vector2(col, row) * BOARD_CELL_SIZE, Vector2.ONE * BOARD_CELL_SIZE)
			if construction.has(cell):
				_draw_well(rect)
			else:
				_draw_block(rect, _region_color(int(BASE_REGIONS[row][col])), false)

	var placed_count := mini(int(floor(assembly_progress + 0.0001)), PIECES.size())
	for stage_index in range(placed_count):
		var piece := _piece_by_id(int(PLACEMENT_ORDER[stage_index]))
		_draw_piece_at_origin(piece, board_origin)

	_draw_dock(placed_count)
	if placed_count < PIECES.size():
		_draw_moving_piece(placed_count, board_origin)

	_draw_kings(board_origin)
	_draw_victory(board_rect)


func _draw_board_base(board_rect: Rect2) -> void:
	var board_base := StyleBoxFlat.new()
	board_base.bg_color = UITokensScript.ASSEMBLY_BOARD_SURFACE
	board_base.border_color = UITokensScript.ASSEMBLY_BOARD_EDGE
	board_base.set_border_width_all(3)
	board_base.set_corner_radius_all(12)
	board_base.shadow_color = UITokensScript.ASSEMBLY_BOARD_SHADOW
	board_base.shadow_size = 7
	board_base.shadow_offset = Vector2(0, 4)
	draw_style_box(board_base, board_rect.grow(7.0))


func _draw_well(rect: Rect2) -> void:
	var inner := rect.grow(-2.0)
	draw_rect(inner, UITokensScript.ASSEMBLY_WELL_DARK, true)
	var cavity := inner.grow(-2.0)
	draw_rect(cavity, UITokensScript.ASSEMBLY_WELL, true)
	draw_line(cavity.position, Vector2(cavity.end.x, cavity.position.y), UITokensScript.ASSEMBLY_WELL_DARK.darkened(0.10), 2.0)
	draw_line(cavity.position, Vector2(cavity.position.x, cavity.end.y), UITokensScript.ASSEMBLY_WELL_DARK.darkened(0.10), 2.0)
	draw_line(Vector2(inner.position.x, inner.end.y), inner.end, UITokensScript.ASSEMBLY_WELL_LIGHT, 2.0)
	draw_line(Vector2(inner.end.x, inner.position.y), inner.end, UITokensScript.ASSEMBLY_WELL_LIGHT, 2.0)


func _draw_block(rect: Rect2, color: Color, movable: bool, cell_size: float = BOARD_CELL_SIZE) -> void:
	var gap := maxf(1.2, cell_size * 0.035)
	var tile_rect := rect.grow(-gap)
	var material_alpha := color.a
	var textured_alpha := 1.0 - flatten_amount
	if textured_alpha > 0.001:
		var shadow := Color(0.05, 0.07, 0.11, (0.22 if movable else 0.16) * material_alpha * textured_alpha)
		draw_texture_rect(BLOCK_TILE_TEXTURE, Rect2(tile_rect.position + Vector2(0, cell_size * 0.045), tile_rect.size), false, shadow)
		var tint := color
		tint.a = material_alpha * textured_alpha
		draw_texture_rect(BLOCK_TILE_TEXTURE, tile_rect, false, tint)
	if flatten_amount > 0.001:
		var flat_color := color
		flat_color.a = material_alpha * flatten_amount
		draw_rect(tile_rect, flat_color, true)


func _draw_dock(placed_count: int) -> void:
	var dock_alpha := 1.0 - flatten_amount
	if dock_alpha <= 0.001:
		return
	var dock_rect := Rect2(18.0, DOCK_TOP, size.x - 36.0, DOCK_HEIGHT)
	var dock_color := UITokensScript.ASSEMBLY_TRAY
	dock_color.a = 0.92 * dock_alpha
	var edge_color := UITokensScript.ASSEMBLY_TRAY_EDGE
	edge_color.a = dock_alpha
	draw_rect(dock_rect, dock_color, true)
	draw_rect(dock_rect, edge_color, false, 3.0)
	for stage_index in range(PIECES.size()):
		var slot_center := _dock_center(stage_index)
		var slot_rect := Rect2(slot_center - Vector2(33, 27), Vector2(66, 54))
		var slot_color := Color(1, 1, 1, 0.12 * dock_alpha)
		if stage_index == placed_count:
			var pulse := 0.55 + 0.25 * sin(clampf(assembly_progress - float(placed_count), 0.0, 1.0) * PI)
			slot_color = Color(UITokensScript.CROWN_GOLD, pulse * dock_alpha)
		draw_rect(slot_rect, slot_color, false, 2.0)
		if stage_index < placed_count:
			continue
		if stage_index == placed_count:
			continue
		var piece := _piece_by_id(int(PLACEMENT_ORDER[stage_index]))
		_draw_piece_centered(piece, slot_center, DOCK_CELL_SIZE, dock_alpha)


func _draw_moving_piece(stage_index: int, board_origin: Vector2) -> void:
	var piece := _piece_by_id(int(PLACEMENT_ORDER[stage_index]))
	var local_progress := clampf(assembly_progress - float(stage_index), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, local_progress)
	var start_cell_size := DOCK_CELL_SIZE
	var destination_cell_size := BOARD_CELL_SIZE
	var start_top_left := _piece_top_left_for_center(piece, _dock_center(stage_index), start_cell_size)
	var origin: Array = piece["origin"]
	var destination := board_origin + Vector2(float(origin[1]), float(origin[0])) * BOARD_CELL_SIZE
	var draw_position := start_top_left.lerp(destination, eased)
	draw_position.y -= sin(eased * PI) * PIECE_ARC_HEIGHT
	var cell_size := lerpf(start_cell_size, destination_cell_size, eased)
	var lift_scale := 1.0 + sin(eased * PI) * 0.08
	_draw_piece(piece, draw_position, cell_size, 1.0, lift_scale)


func _draw_piece_at_origin(piece: Dictionary, board_origin: Vector2) -> void:
	var origin: Array = piece["origin"]
	var top_left := board_origin + Vector2(float(origin[1]), float(origin[0])) * BOARD_CELL_SIZE
	_draw_piece(piece, top_left, BOARD_CELL_SIZE, 1.0, 1.0)


func _draw_piece_centered(piece: Dictionary, center: Vector2, cell_size: float, alpha: float) -> void:
	_draw_piece(piece, _piece_top_left_for_center(piece, center, cell_size), cell_size, alpha, 1.0)


func _draw_piece(piece: Dictionary, top_left: Vector2, cell_size: float, alpha: float, scale_value: float) -> void:
	var bounds := _piece_bounds(piece)
	var piece_center := top_left + Vector2(bounds.x, bounds.y) * cell_size * 0.5
	draw_set_transform(piece_center, 0.0, Vector2.ONE * scale_value)
	for raw_cell in piece.get("cells", []):
		var local_cell := Vector2(float(raw_cell[1]), float(raw_cell[0]))
		var rect := Rect2(top_left - piece_center + local_cell * cell_size, Vector2.ONE * cell_size)
		var color := _region_color(int(piece["regionId"]))
		color.a = alpha
		_draw_block(rect, color, true, cell_size)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_kings(board_origin: Vector2) -> void:
	for index in range(KING_SOLUTION.size()):
		var local_progress := clampf(king_reveal_progress - float(index), 0.0, 1.0)
		if local_progress <= 0.001:
			continue
		var raw_cell: Array = KING_SOLUTION[index]
		var center := board_origin + Vector2(float(raw_cell[1]) + 0.5, float(raw_cell[0]) + 0.5) * BOARD_CELL_SIZE
		var reveal := smoothstep(0.0, 0.62, local_progress)
		var pop := 1.0 + sin(local_progress * PI) * 0.30
		var victory_wiggle := sin((victory_progress * 2.0 + float(index) * 0.17) * TAU) * 0.045 * (1.0 - victory_progress)
		var texture_size := BOARD_CELL_SIZE * 0.66
		draw_set_transform(center, victory_wiggle, Vector2.ONE * pop)
		var texture := HAPPY_LION_TEXTURE if local_progress >= 0.72 else LION_TEXTURE
		draw_texture_rect(
			texture,
			Rect2(-Vector2.ONE * texture_size * 0.5, Vector2.ONE * texture_size),
			false,
			Color(1, 1, 1, reveal)
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_victory(board_rect: Rect2) -> void:
	if victory_progress <= 0.001:
		return
	var pulse := sin(victory_progress * PI)
	var victory_border := StyleBoxFlat.new()
	victory_border.bg_color = Color.TRANSPARENT
	victory_border.border_color = Color(UITokensScript.CROWN_GOLD, 0.86 * pulse)
	victory_border.set_border_width_all(int(round(3.0 + pulse * 2.0)))
	victory_border.set_corner_radius_all(13)
	draw_style_box(victory_border, board_rect.grow(10.0 + pulse * 3.0))
	for index in range(VICTORY_SPARK_POINTS.size()):
		var local := clampf(victory_progress * 1.45 - float(index % 4) * 0.10, 0.0, 1.0)
		var alpha := sin(local * PI)
		if alpha <= 0.01:
			continue
		var point: Vector2 = board_rect.position + VICTORY_SPARK_POINTS[index] * board_rect.size
		var radius := 3.0 + 4.0 * alpha
		var color := Color(1.0, 0.86, 0.30, 0.94 * alpha)
		draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), color, 2.0, true)
		draw_line(point - Vector2(0, radius), point + Vector2(0, radius), color, 2.0, true)


func _construction_cell_set() -> Dictionary:
	var result := {}
	for raw_cell in CONSTRUCTION_CELLS:
		result[Vector2i(int(raw_cell[1]), int(raw_cell[0]))] = true
	return result


func _piece_by_id(piece_id: int) -> Dictionary:
	for piece in PIECES:
		if int(piece["pieceId"]) == piece_id:
			return piece
	return {}


func _piece_bounds(piece: Dictionary) -> Vector2i:
	var result := Vector2i.ONE
	for raw_cell in piece.get("cells", []):
		result.x = maxi(result.x, int(raw_cell[1]) + 1)
		result.y = maxi(result.y, int(raw_cell[0]) + 1)
	return result


func _piece_top_left_for_center(piece: Dictionary, center: Vector2, cell_size: float) -> Vector2:
	var bounds := _piece_bounds(piece)
	return center - Vector2(bounds.x, bounds.y) * cell_size * 0.5


func _dock_center(stage_index: int) -> Vector2:
	var usable_width := size.x - 64.0
	var spacing := usable_width / float(PIECES.size())
	return Vector2(32.0 + spacing * (float(stage_index) + 0.5), DOCK_TOP + DOCK_HEIGHT * 0.5)


func _region_color(region_id: int) -> Color:
	return UITokensScript.REGION_COLORS[posmod(region_id - 1, UITokensScript.REGION_COLORS.size())]
