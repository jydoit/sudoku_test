class_name RuleIllustration
extends Control

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const LION_KING_ICON = preload("res://assets/ui/lion_king.png")

const ADJACENT := "adjacent"
const ROW_COLUMN := "row_column"
const REGION := "region"

var rule_kind := ADJACENT


func configure(kind: String) -> void:
	rule_kind = kind
	custom_minimum_size = Vector2(122, 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var grid_side := minf(size.x - 8.0, size.y - 8.0)
	var cell_size := floorf(grid_side / 3.0)
	var board_size := Vector2.ONE * cell_size * 3.0
	var origin := (size - board_size) * 0.5

	for row in range(3):
		for col in range(3):
			var cell_rect := Rect2(
				origin + Vector2(col, row) * cell_size + Vector2.ONE,
				Vector2.ONE * (cell_size - 2.0)
			)
			_draw_cell(cell_rect, _cell_color(row, col))

	for row in range(3):
		for col in range(3):
			if _cell_has_x(row, col):
				var x_rect := Rect2(
					origin + Vector2(col, row) * cell_size,
					Vector2.ONE * cell_size
				)
				_draw_x(x_rect, cell_size)

	var crown_cell := _crown_cell()
	var crown_center := origin + (Vector2(crown_cell.x, crown_cell.y) + Vector2.ONE * 0.5) * cell_size
	var crown_size := cell_size * 0.76
	draw_texture_rect(
		LION_KING_ICON,
		Rect2(crown_center - Vector2.ONE * crown_size * 0.5, Vector2.ONE * crown_size),
		false
	)


func _draw_cell(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = UITokensScript.BOARD_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	draw_style_box(style, rect)


func _draw_x(rect: Rect2, cell_size: float) -> void:
	var center := rect.get_center()
	var radius := cell_size * 0.16
	var width := maxf(2.0, cell_size * 0.055)
	var first_start := center - Vector2(radius, radius)
	var first_end := center + Vector2(radius, radius)
	var second_start := center + Vector2(radius, -radius)
	var second_end := center + Vector2(-radius, radius)
	draw_line(first_start, first_end, Color(1.0, 1.0, 1.0, 0.72), width + 1.6, true)
	draw_line(second_start, second_end, Color(1.0, 1.0, 1.0, 0.72), width + 1.6, true)
	draw_line(first_start, first_end, UITokensScript.BLOCKED_X_COLOR, width, true)
	draw_line(second_start, second_end, UITokensScript.BLOCKED_X_COLOR, width, true)


func _cell_color(row: int, col: int) -> Color:
	if rule_kind == ADJACENT:
		return UITokensScript.SOFT_BLUE
	if rule_kind == ROW_COLUMN:
		if row == 1 or col == 1:
			return UITokensScript.WARNING_YELLOW
		return Color("#F1F4F7")
	if _is_target_region(row, col):
		return UITokensScript.REGION_COLORS[2].lightened(0.16)
	var other_colors := [
		UITokensScript.REGION_COLORS[0],
		UITokensScript.REGION_COLORS[1],
		UITokensScript.REGION_COLORS[3]
	]
	return other_colors[(row + col) % other_colors.size()].lightened(0.18)


func _cell_has_x(row: int, col: int) -> bool:
	var crown := _crown_cell()
	if row == crown.y and col == crown.x:
		return false
	if rule_kind == ADJACENT:
		return true
	if rule_kind == ROW_COLUMN:
		return row == crown.y or col == crown.x
	return _is_target_region(row, col)


func _crown_cell() -> Vector2i:
	if rule_kind == REGION:
		return Vector2i(0, 1)
	return Vector2i(1, 1)


func _is_target_region(row: int, col: int) -> bool:
	return col == 0 or (row == 2 and col == 1)
