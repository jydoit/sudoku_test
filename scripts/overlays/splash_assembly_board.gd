class_name SplashAssemblyBoard
extends Control

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const SPLASH_TILE_TEXTURES := [
	preload("res://assets/ui/splash/splash_tile_blue.png"),
	preload("res://assets/ui/splash/splash_tile_red.png"),
	preload("res://assets/ui/splash/splash_tile_green.png"),
	preload("res://assets/ui/splash/splash_tile_yellow.png"),
	preload("res://assets/ui/splash/splash_tile_purple.png"),
	preload("res://assets/ui/splash/splash_tile_orange.png"),
]
const SPLASH_EMPTY_TILE: Texture2D = preload("res://assets/ui/splash/splash_tile_empty.png")
const SPLASH_CRYSTAL_TILE: Texture2D = preload("res://assets/ui/splash/splash_crystal_tile_neutral.png")
const LION_TEXTURE: Texture2D = preload("res://assets/ui/lion_king.svg")
const HAPPY_LION_TEXTURE: Texture2D = preload("res://assets/ui/lion_king_happy.svg")

# Geometry and piece selection are baked from the real offline composite entry
# `103:hard`; only the warm illustrated rendering style comes from the original
# Splash. Keeping this small snapshot avoids synchronously loading the full 6x6
# bundle during startup. The smoke test compares it with the runtime catalog and
# verifies that the five pieces exactly cover every well.
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
const ANIMATED_PLACEMENT_ORDER := [1, 0]
const INSTANT_FILL_ORDER := [3, 4, 2]
const KING_SOLUTION := [[0, 3], [1, 0], [2, 2], [3, 4], [4, 1], [5, 5]]

const BOARD_CELL_SIZE := 50.0
const PIECE_START_CELL_SIZE := 41.0
const BOARD_TOP := 48.0
const PIECE_ARC_HEIGHT := 38.0
const SPLASH_BOARD_SURFACE := Color("#FFF8EE")
const CRYSTAL_SURFACE := Color(0.70, 0.90, 0.97, 0.46)
const CRYSTAL_EDGE := Color(0.43, 0.78, 0.91, 0.82)
const CRYSTAL_HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.92)
const CRYSTAL_SHADOW := Color(0.12, 0.43, 0.64, 0.20)
const CRYSTAL_REFRACTION := Color(0.82, 0.96, 1.0, 0.34)
const CRYSTAL_TILE_ALPHA := 1.0
const CRYSTAL_TILE_SHADOW := Color(0.05, 0.26, 0.40, 0.30)
const CRYSTAL_HAZE := Color(0.91, 0.98, 1.0, 0.13)
const ANIME_ACTION_INK := Color("#365A8A")
const ANIME_ACTION_LIGHT := Color("#FFF7C9")
const ANIME_STREAK_COUNT := 3
const ANIME_IMPACT_RAY_COUNT := 10
# The two demonstrated real pieces sit below the board like the original
# illustrated Splash. There is no game-like tray or list of the other pieces.
const PIECE_START_CENTERS := [
	Vector2(112.0, 390.0),
	Vector2(328.0, 390.0),
]
const VICTORY_SPARK_POINTS := [
	Vector2(0.05, 0.12), Vector2(0.28, 0.04), Vector2(0.58, 0.06),
	Vector2(0.91, 0.14), Vector2(0.96, 0.52), Vector2(0.84, 0.92),
	Vector2(0.48, 0.96), Vector2(0.12, 0.86),
]

var assembly_progress := 0.0:
	set(value):
		assembly_progress = clampf(value, 0.0, float(ANIMATED_PLACEMENT_ORDER.size()))
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
		"animatedPlacementOrder": ANIMATED_PLACEMENT_ORDER.duplicate(),
		"instantFillOrder": INSTANT_FILL_ORDER.duplicate(),
		"solution": KING_SOLUTION.duplicate(true),
	}


func reset_visuals() -> void:
	assembly_progress = 0.0
	flatten_amount = 0.0
	king_reveal_progress = 0.0
	victory_progress = 0.0
	scale = Vector2.ONE


func show_stable_final() -> void:
	assembly_progress = float(ANIMATED_PLACEMENT_ORDER.size())
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
				_draw_block(rect, int(BASE_REGIONS[row][col]), false)

	var placed_count := mini(int(floor(assembly_progress + 0.0001)), ANIMATED_PLACEMENT_ORDER.size())
	for stage_index in range(placed_count):
		var piece := _piece_by_id(int(ANIMATED_PLACEMENT_ORDER[stage_index]))
		_draw_piece_at_origin(piece, board_origin)
	if placed_count == ANIMATED_PLACEMENT_ORDER.size():
		for piece_id in INSTANT_FILL_ORDER:
			_draw_piece_at_origin(_piece_by_id(int(piece_id)), board_origin)

	if placed_count < ANIMATED_PLACEMENT_ORDER.size():
		# Keep both selected examples visible before their turn, matching the
		# composition of the first Splash instead of a gameplay inventory.
		_draw_moving_piece(placed_count, board_origin)
		for waiting_index in range(placed_count + 1, ANIMATED_PLACEMENT_ORDER.size()):
			var waiting_piece := _piece_by_id(int(ANIMATED_PLACEMENT_ORDER[waiting_index]))
			_draw_piece_centered(waiting_piece, PIECE_START_CENTERS[waiting_index], PIECE_START_CELL_SIZE, 1.0)
	_draw_landing_effects(board_origin)
	_draw_upper_crystal_haze(board_rect)
	_draw_material_transition(board_rect)

	_draw_kings(board_origin)
	_draw_victory(board_rect)


func _draw_board_base(board_rect: Rect2) -> void:
	var crystal_outer := StyleBoxFlat.new()
	crystal_outer.bg_color = CRYSTAL_SURFACE
	crystal_outer.border_color = CRYSTAL_HIGHLIGHT
	crystal_outer.set_border_width_all(3)
	crystal_outer.set_corner_radius_all(21)
	crystal_outer.shadow_color = CRYSTAL_SHADOW
	crystal_outer.shadow_size = 10
	crystal_outer.shadow_offset = Vector2(0, 5)
	draw_style_box(crystal_outer, board_rect.grow(16.0))

	var crystal_band := StyleBoxFlat.new()
	crystal_band.bg_color = Color.TRANSPARENT
	crystal_band.border_color = CRYSTAL_EDGE
	crystal_band.set_border_width_all(8)
	crystal_band.set_corner_radius_all(18)
	draw_style_box(crystal_band, board_rect.grow(12.0))

	var board_base := StyleBoxFlat.new()
	board_base.bg_color = SPLASH_BOARD_SURFACE
	board_base.border_color = CRYSTAL_REFRACTION
	board_base.set_border_width_all(2)
	board_base.set_corner_radius_all(13)
	draw_style_box(board_base, board_rect.grow(4.0))
	_draw_crystal_facets(board_rect.grow(14.0))


func _draw_crystal_facets(frame_rect: Rect2) -> void:
	# Short, uneven refraction fragments read as crystal. Uniform full-length
	# lines looked like UI guides and made the frame too busy.
	var top_y := frame_rect.position.y + 3.0
	var bottom_y := frame_rect.end.y - 3.0
	var left_x := frame_rect.position.x + 3.0
	var right_x := frame_rect.end.x - 3.0
	_draw_refraction_segment(Vector2(frame_rect.position.x + 22.0, top_y), Vector2(frame_rect.position.x + 82.0, top_y), Color(1, 1, 1, 0.54), 2.4)
	_draw_refraction_segment(Vector2(frame_rect.position.x + 108.0, top_y), Vector2(frame_rect.position.x + 151.0, top_y), Color(1, 1, 1, 0.36), 2.1)
	_draw_refraction_segment(Vector2(frame_rect.end.x - 58.0, top_y), Vector2(frame_rect.end.x - 24.0, top_y), Color(1, 1, 1, 0.48), 2.3)
	_draw_refraction_segment(Vector2(left_x, frame_rect.position.y + 24.0), Vector2(left_x, frame_rect.position.y + 83.0), Color(1, 1, 1, 0.40), 2.1)
	_draw_refraction_segment(Vector2(left_x, frame_rect.position.y + 112.0), Vector2(left_x, frame_rect.position.y + 153.0), Color(1, 1, 1, 0.27), 1.8)
	_draw_refraction_segment(Vector2(frame_rect.position.x + 70.0, bottom_y), Vector2(frame_rect.position.x + 131.0, bottom_y), Color(0.31, 0.70, 0.86, 0.30), 2.2)
	_draw_refraction_segment(Vector2(frame_rect.end.x - 91.0, bottom_y), Vector2(frame_rect.end.x - 20.0, bottom_y), Color(0.31, 0.70, 0.86, 0.34), 2.2)
	_draw_refraction_segment(Vector2(right_x, frame_rect.position.y + 65.0), Vector2(right_x, frame_rect.position.y + 111.0), Color(0.31, 0.70, 0.86, 0.30), 2.0)
	_draw_refraction_segment(Vector2(right_x, frame_rect.end.y - 69.0), Vector2(right_x, frame_rect.end.y - 24.0), Color(0.31, 0.70, 0.86, 0.24), 1.8)
	var upper_facet := PackedVector2Array([
		Vector2(frame_rect.end.x - 50.0, frame_rect.position.y + 1.0),
		Vector2(frame_rect.end.x - 24.0, frame_rect.position.y + 1.0),
		Vector2(frame_rect.end.x - 37.0, frame_rect.position.y + 8.0),
	])
	draw_colored_polygon(upper_facet, Color(1.0, 1.0, 1.0, 0.38))
	var lower_facet := PackedVector2Array([
		Vector2(frame_rect.position.x + 31.0, frame_rect.end.y - 1.0),
		Vector2(frame_rect.position.x + 63.0, frame_rect.end.y - 1.0),
		Vector2(frame_rect.position.x + 47.0, frame_rect.end.y - 9.0),
	])
	draw_colored_polygon(lower_facet, Color(0.52, 0.85, 0.95, 0.42))


func _draw_refraction_segment(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, color, width, true)


func _draw_well(rect: Rect2) -> void:
	draw_texture_rect(SPLASH_EMPTY_TILE, rect.grow(-0.25), false, Color.WHITE)


func _draw_block(
	rect: Rect2,
	region_id: int,
	movable: bool,
	alpha: float = 1.0,
	cell_size: float = BOARD_CELL_SIZE
) -> void:
	var gap := maxf(0.2, cell_size * 0.006)
	var tile_rect := rect.grow(-gap)
	var palette_color: Color = UITokensScript.REGION_COLORS[
		posmod(region_id - 1, UITokensScript.REGION_COLORS.size())
	]
	var crystal_alpha := (1.0 - smoothstep(0.08, 0.86, flatten_amount)) * alpha
	var normal_alpha := smoothstep(0.18, 1.0, flatten_amount) * alpha
	if crystal_alpha > 0.001:
		var crystal_tint := palette_color.lightened(0.04)
		crystal_tint.a = crystal_alpha * CRYSTAL_TILE_ALPHA
		var crystal_shadow := CRYSTAL_TILE_SHADOW
		crystal_shadow.a *= crystal_alpha * (1.12 if movable else 0.82)
		draw_texture_rect(
			SPLASH_CRYSTAL_TILE,
			Rect2(tile_rect.position + Vector2(0, cell_size * 0.045), tile_rect.size),
			false,
			crystal_shadow
		)
		draw_texture_rect(SPLASH_CRYSTAL_TILE, tile_rect.grow(cell_size * 0.012), false, crystal_tint)
	if normal_alpha > 0.001:
		var normal_texture: Texture2D = SPLASH_TILE_TEXTURES[posmod(region_id - 1, SPLASH_TILE_TEXTURES.size())]
		var normal_shadow := Color(0.12, 0.065, 0.035, 0.16 * normal_alpha)
		draw_texture_rect(
			normal_texture,
			Rect2(tile_rect.position + Vector2(0, cell_size * 0.035), tile_rect.size),
			false,
			normal_shadow
		)
		draw_texture_rect(normal_texture, tile_rect, false, Color(1, 1, 1, normal_alpha))


func _draw_upper_crystal_haze(board_rect: Rect2) -> void:
	var crystal_amount := 1.0 - smoothstep(0.12, 0.88, flatten_amount)
	if crystal_amount <= 0.001:
		return
	# Four feathered strips soften only the far/top fifth of the board. Lion
	# markers are rendered afterwards so gameplay information remains readable.
	var strip_height := board_rect.size.y * 0.055
	for strip_index in range(4):
		var haze := CRYSTAL_HAZE
		haze.a *= crystal_amount * (1.0 - float(strip_index) * 0.22)
		var strip_rect := Rect2(
			board_rect.position + Vector2(0, float(strip_index) * strip_height),
			Vector2(board_rect.size.x, strip_height + 1.0)
		)
		draw_rect(strip_rect, haze)


func _draw_material_transition(board_rect: Rect2) -> void:
	if flatten_amount <= 0.001 or flatten_amount >= 0.999:
		return
	# A compact diagonal light sweep masks the crystal-to-normal crossfade while
	# keeping the board silhouette fixed and readable.
	var sweep := smoothstep(0.0, 1.0, flatten_amount)
	var center_x := lerpf(board_rect.position.x - board_rect.size.x * 0.18, board_rect.end.x + board_rect.size.x * 0.18, sweep)
	var top_center := Vector2(center_x - board_rect.size.y * 0.24, board_rect.position.y)
	var bottom_center := Vector2(center_x + board_rect.size.y * 0.24, board_rect.end.y)
	for band_index in range(3, -1, -1):
		var half_width := 4.0 + float(band_index) * 6.0
		var normal := Vector2(bottom_center.y - top_center.y, top_center.x - bottom_center.x).normalized()
		var polygon := PackedVector2Array([
			top_center - normal * half_width,
			top_center + normal * half_width,
			bottom_center + normal * half_width,
			bottom_center - normal * half_width,
		])
		var band_color := Color(1.0, 0.97, 0.80, 0.10 + (3.0 - float(band_index)) * 0.08)
		draw_colored_polygon(polygon, band_color)


func _draw_moving_piece(stage_index: int, board_origin: Vector2) -> void:
	var piece := _piece_by_id(int(ANIMATED_PLACEMENT_ORDER[stage_index]))
	var local_progress := clampf(assembly_progress - float(stage_index), 0.0, 1.0)
	var state := _piece_motion_state(piece, stage_index, local_progress, board_origin)
	_draw_anime_motion_streaks(piece, stage_index, local_progress, board_origin, state)
	_draw_piece(
		piece,
		state["top_left"],
		float(state["cell_size"]),
		1.0,
		state["scale"],
		float(state["rotation"])
	)


func _piece_motion_state(
	piece: Dictionary,
	stage_index: int,
	progress: float,
	board_origin: Vector2
) -> Dictionary:
	var eased := smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	var start_top_left := _piece_top_left_for_center(piece, PIECE_START_CENTERS[stage_index], PIECE_START_CELL_SIZE)
	var origin: Array = piece["origin"]
	var destination := board_origin + Vector2(float(origin[1]), float(origin[0])) * BOARD_CELL_SIZE
	var draw_position := start_top_left.lerp(destination, eased)
	var lift_wave := sin(eased * PI)
	draw_position.y -= lift_wave * PIECE_ARC_HEIGHT
	var cell_size := lerpf(PIECE_START_CELL_SIZE, BOARD_CELL_SIZE, eased)
	var landing_squash := 0.0
	if eased > 0.72:
		landing_squash = sin(inverse_lerp(0.72, 1.0, eased) * PI)
	var motion_scale := Vector2(
		1.0 - lift_wave * 0.018 + landing_squash * 0.055,
		1.0 + lift_wave * 0.045 - landing_squash * 0.045
	)
	var rotation_direction := -1.0 if stage_index % 2 == 0 else 1.0
	var rotation := deg_to_rad(5.0) * lift_wave * rotation_direction
	return {
		"top_left": draw_position,
		"cell_size": cell_size,
		"scale": motion_scale,
		"rotation": rotation,
	}


func _draw_anime_motion_streaks(
	piece: Dictionary,
	stage_index: int,
	progress: float,
	board_origin: Vector2,
	state: Dictionary
) -> void:
	var emphasis := sin(clampf(inverse_lerp(0.06, 0.94, progress), 0.0, 1.0) * PI)
	if emphasis <= 0.02:
		return
	var previous_state := _piece_motion_state(piece, stage_index, maxf(0.0, progress - 0.065), board_origin)
	var center := _piece_center_from_state(piece, state)
	var previous_center := _piece_center_from_state(piece, previous_state)
	var direction := center - previous_center
	if direction.length_squared() < 0.01:
		return
	direction = direction.normalized()
	var normal := Vector2(-direction.y, direction.x)
	var bounds := _piece_bounds(piece)
	var trailing_radius := maxf(float(bounds.x), float(bounds.y)) * float(state["cell_size"]) * 0.38
	for line_index in range(ANIME_STREAK_COUNT):
		var lateral := (float(line_index) - 1.0) * 12.0
		var line_end := center - direction * (trailing_radius + 7.0 + float(line_index) * 4.0) + normal * lateral
		var line_start := line_end - direction * (22.0 + float(line_index) * 7.0)
		var ink := ANIME_ACTION_INK
		ink.a = emphasis * (0.20 - float(line_index) * 0.035)
		draw_line(line_start + normal * 1.5, line_end + normal * 1.5, ink, 3.4, true)
		var light := Color.WHITE
		light.a = emphasis * (0.76 - float(line_index) * 0.10)
		draw_line(line_start, line_end, light, 2.0, true)


func _draw_landing_effects(board_origin: Vector2) -> void:
	for stage_index in range(ANIMATED_PLACEMENT_ORDER.size()):
		var strength := _landing_effect_strength(stage_index)
		if strength <= 0.01:
			continue
		var piece := _piece_by_id(int(ANIMATED_PLACEMENT_ORDER[stage_index]))
		var origin: Array = piece["origin"]
		var top_left := board_origin + Vector2(float(origin[1]), float(origin[0])) * BOARD_CELL_SIZE
		var bounds := _piece_bounds(piece)
		var center := top_left + Vector2(bounds.x, bounds.y) * BOARD_CELL_SIZE * 0.5
		_draw_anime_impact_burst(center, maxf(float(bounds.x), float(bounds.y)) * BOARD_CELL_SIZE * 0.50, strength)


func _landing_effect_strength(stage_index: int) -> float:
	if stage_index == 0:
		var elapsed := assembly_progress - 1.0
		if elapsed < 0.0 or elapsed > 0.24:
			return 0.0
		return 1.0 - smoothstep(0.0, 0.24, elapsed)
	if assembly_progress < float(ANIMATED_PLACEMENT_ORDER.size()):
		return 0.0
	return 1.0 - smoothstep(0.0, 0.72, flatten_amount)


func _draw_anime_impact_burst(center: Vector2, piece_radius: float, strength: float) -> void:
	var phase := 1.0 - strength
	var ray_origin_radius := piece_radius + lerpf(5.0, 17.0, phase)
	var ray_length := lerpf(20.0, 7.0, phase)
	for ray_index in range(ANIME_IMPACT_RAY_COUNT):
		var angle := TAU * float(ray_index) / float(ANIME_IMPACT_RAY_COUNT) + PI * 0.10
		var direction := Vector2.from_angle(angle)
		var ray_start := center + direction * ray_origin_radius
		var ray_end := ray_start + direction * ray_length
		var ink := ANIME_ACTION_INK
		ink.a = 0.22 * strength
		draw_line(ray_start, ray_end, ink, 4.2, true)
		var light := ANIME_ACTION_LIGHT if ray_index % 2 == 0 else Color.WHITE
		light.a = 0.92 * strength
		draw_line(ray_start, ray_end, light, 2.2, true)


func _piece_center_from_state(piece: Dictionary, state: Dictionary) -> Vector2:
	var bounds := _piece_bounds(piece)
	return state["top_left"] + Vector2(bounds.x, bounds.y) * float(state["cell_size"]) * 0.5


func _draw_piece_at_origin(piece: Dictionary, board_origin: Vector2) -> void:
	var origin: Array = piece["origin"]
	var top_left := board_origin + Vector2(float(origin[1]), float(origin[0])) * BOARD_CELL_SIZE
	_draw_piece(piece, top_left, BOARD_CELL_SIZE, 1.0, Vector2.ONE)


func _draw_piece_centered(piece: Dictionary, center: Vector2, cell_size: float, alpha: float) -> void:
	_draw_piece(piece, _piece_top_left_for_center(piece, center, cell_size), cell_size, alpha, Vector2.ONE)


func _draw_piece(
	piece: Dictionary,
	top_left: Vector2,
	cell_size: float,
	alpha: float,
	scale_value: Vector2,
	rotation: float = 0.0
) -> void:
	var bounds := _piece_bounds(piece)
	var piece_center := top_left + Vector2(bounds.x, bounds.y) * cell_size * 0.5
	draw_set_transform(piece_center, rotation, scale_value)
	for raw_cell in piece.get("cells", []):
		var local_cell := Vector2(float(raw_cell[1]), float(raw_cell[0]))
		var rect := Rect2(top_left - piece_center + local_cell * cell_size, Vector2.ONE * cell_size)
		_draw_block(rect, int(piece["regionId"]), true, alpha, cell_size)
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


func completed_piece_count() -> int:
	var animated_count := mini(int(floor(assembly_progress + 0.0001)), ANIMATED_PLACEMENT_ORDER.size())
	return PIECES.size() if animated_count == ANIMATED_PLACEMENT_ORDER.size() else animated_count
