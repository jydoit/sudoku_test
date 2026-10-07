extends PanelContainer

## Resolution-independent enamel face, bevel and solid lower edge.
## Decoration redraws only when resized or restyled; no per-frame shader.
const UI = preload("res://scripts/ui_tokens.gd")

var _variant := "blue"
var _radius := UI.RELIEF_RADIUS
var _depth := UI.RELIEF_DEPTH
var _shadow: StyleBoxFlat


func configure(variant: String = "blue", padding: Vector2 = Vector2(12, 8), radius: float = UI.RELIEF_RADIUS) -> void:
	_variant = variant
	_radius = radius
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var space := StyleBoxEmpty.new()
	space.content_margin_left = padding.x
	space.content_margin_right = padding.x
	space.content_margin_top = padding.y
	space.content_margin_bottom = padding.y + _depth
	add_theme_stylebox_override("panel", space)
	_shadow = StyleBoxFlat.new()
	_shadow.bg_color = Color.TRANSPARENT
	_shadow.set_corner_radius_all(int(_radius))
	_shadow.shadow_color = Color(0.11, 0.22, 0.35, 0.18)
	_shadow.shadow_size = 5
	_shadow.shadow_offset = Vector2(0, 3)
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()


func set_variant(value: String) -> void:
	if _variant != value:
		_variant = value
		queue_redraw()


func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0 or not _shadow:
		return
	var face := Rect2(Vector2(2, 1), size - Vector2(4, _depth + 3))
	_shadow.draw(get_canvas_item(), face)
	_round_gradient(Rect2(face.position + Vector2(0, _depth), face.size), _radius, UI.RELIEF_GOLD_DARK, UI.RELIEF_BLUE_EDGE)
	_round_gradient(face, _radius, UI.RELIEF_GOLD_LIGHT, UI.RELIEF_GOLD)
	var inner := face.grow(-3.0)
	var top := UI.RELIEF_BLUE_LIGHT
	var bottom := UI.RELIEF_BLUE_DARK
	match _variant:
		"cream":
			top = UI.RELIEF_CREAM_LIGHT
			bottom = UI.RELIEF_CREAM_DARK
		"teal":
			top = Color("#77DDEC")
			bottom = Color("#2786AB")
		"urgent":
			top = UI.RELIEF_WARNING_LIGHT
			bottom = UI.RELIEF_WARNING_DARK
	_round_gradient(inner, _radius - 3.0, top, bottom)
	var shine := Rect2(inner.position + Vector2(3, 2), Vector2(inner.size.x - 6, inner.size.y * 0.38))
	_round_gradient(shine, minf(_radius - 5.0, shine.size.y * 0.5), Color(1, 1, 1, 0.27), Color(1, 1, 1, 0.02))
	draw_line(inner.position + Vector2(_radius, 2), Vector2(inner.end.x - _radius, inner.position.y + 2), Color(1, 1, 1, 0.65), 1.0, true)


func _round_gradient(rect: Rect2, radius: float, top: Color, bottom: Color) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var r := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var centers := [
		Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r),
		Vector2(rect.position.x + r, rect.end.y - r),
		rect.position + Vector2(r, r)
	]
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for corner in range(4):
		for step in range(9):
			var angle := -PI * 0.5 + float(corner) * PI * 0.5 + float(step) * PI / 16.0
			var point: Vector2 = centers[corner] + Vector2(cos(angle), sin(angle)) * r
			points.append(point)
			colors.append(top.lerp(bottom, clampf((point.y - rect.position.y) / rect.size.y, 0, 1)))
	draw_polygon(points, colors)
