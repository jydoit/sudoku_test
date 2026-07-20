class_name ToolIcon
extends Control

const HINT := "hint"
const CLEAR := "clear"

var icon_kind := HINT
var icon_color := Color("#2D9E63")


func configure(kind: String, color: Color) -> void:
	icon_kind = kind
	icon_color = color
	custom_minimum_size = Vector2(48, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var unit := minf(size.x, size.y) / 48.0
	var center := size * 0.5
	if icon_kind == CLEAR:
		_draw_clear_icon(center, unit)
	else:
		_draw_hint_icon(center, unit)


func _draw_hint_icon(center: Vector2, unit: float) -> void:
	var outline := icon_color.darkened(0.18)
	var bulb_center := center + Vector2(0, -5.0 * unit)
	draw_circle(bulb_center, 11.0 * unit, icon_color, true, -1.0, true)
	draw_arc(bulb_center, 11.0 * unit, 0.0, TAU, 32, outline, 2.4 * unit, true)
	draw_rect(Rect2(center.x - 6.5 * unit, center.y + 5.0 * unit, 13.0 * unit, 7.0 * unit), icon_color, true)
	draw_line(Vector2(center.x - 6.0 * unit, center.y + 8.0 * unit), Vector2(center.x + 6.0 * unit, center.y + 8.0 * unit), outline, 2.2 * unit, true)
	draw_line(Vector2(center.x - 4.0 * unit, center.y + 14.0 * unit), Vector2(center.x + 4.0 * unit, center.y + 14.0 * unit), outline, 2.6 * unit, true)
	for direction in [Vector2(-0.72, -0.72), Vector2(0, -1), Vector2(0.72, -0.72), Vector2(-1, 0), Vector2(1, 0)]:
		var start: Vector2 = bulb_center + direction * 15.0 * unit
		var finish: Vector2 = bulb_center + direction * 20.0 * unit
		draw_line(start, finish, icon_color, 2.8 * unit, true)


func _draw_clear_icon(center: Vector2, unit: float) -> void:
	var outline := icon_color.darkened(0.18)
	var body := Rect2(center.x - 10.0 * unit, center.y - 7.0 * unit, 20.0 * unit, 23.0 * unit)
	draw_rect(body, icon_color, true)
	draw_rect(body, outline, false, 2.4 * unit, true)
	draw_line(Vector2(center.x - 14.0 * unit, center.y - 11.0 * unit), Vector2(center.x + 14.0 * unit, center.y - 11.0 * unit), outline, 4.0 * unit, true)
	draw_line(Vector2(center.x - 5.0 * unit, center.y - 16.0 * unit), Vector2(center.x + 5.0 * unit, center.y - 16.0 * unit), outline, 3.5 * unit, true)
	for x_offset in [-5.0, 0.0, 5.0]:
		draw_line(
			Vector2(center.x + x_offset * unit, center.y - 3.0 * unit),
			Vector2(center.x + x_offset * unit, center.y + 11.0 * unit),
			Color(1.0, 1.0, 1.0, 0.72),
			1.8 * unit,
			true
		)
