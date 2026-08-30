class_name UITokens
extends RefCounted

## Runtime counterpart of docs/UI_DESIGN_GUIDE.md.
## Update the guide and this file together when a shared UI token changes.

const INK := Color("#26334A")
const MUTED := Color("#718096")
const SURFACE_CREAM := Color("#FFF8ED")
const SURFACE_CARD := Color("#FFFFFF")
const PRIMARY_BLUE := Color("#3E8DFF")
const SOFT_BLUE := Color("#E7F1FF")
const ROYAL_SKY_TOP := Color("#2D7DBB")
const ROYAL_SKY := Color("#52A8E8")
const ROYAL_GLOW := Color("#B5DFF3")
const ROYAL_FLOOR := SURFACE_CREAM
const ROYAL_EDGE_BOTTOM := Color("#8CC8E5")
const SUCCESS_GREEN := Color("#48B985")
const WARNING_YELLOW := Color("#FFF1BD")
const DANGER_RED := Color("#F25D72")
const ASSEMBLY_TRAY := Color("#20283A")
const ASSEMBLY_TRAY_EDGE := Color("#111827")
const ASSEMBLY_BOARD_SURFACE := Color("#EEEAE3")
const ASSEMBLY_BOARD_EDGE := Color("#B9B3AA")
const ASSEMBLY_BOARD_SHADOW := Color(0.12, 0.14, 0.18, 0.22)
const ASSEMBLY_WELL := Color("#D8D3CB")
const ASSEMBLY_WELL_DARK := Color("#A9A39A")
const ASSEMBLY_WELL_LIGHT := Color("#F7F3EC")
const CROWN_GOLD := Color("#E4A236")
const PROGRESS_TRACK := Color("#E8E3DB")
const PROGRESS_FILL := Color("#FFB84E")
const OPENING_OVERLAY_SCRIM := Color(0.10, 0.14, 0.22, 0.38)
const OPENING_OVERLAY_CARD := Color("#FFFDF8")
const DIALOG_SCRIM := Color(0.102, 0.141, 0.220, 0.38)
const DIALOG_SURFACE := Color("#FFFDF8")
const DIALOG_BORDER := Color("#E7DED1")
const DIALOG_CONTENT_SURFACE := Color("#F7FAFF")
const DIALOG_CONTENT_BORDER := Color("#DFEAF6")
const DIALOG_SECONDARY_BUTTON := Color("#F1F4F7")
const DIALOG_RADIUS := 24
const DIALOG_BORDER_WIDTH := 2
const DIALOG_BUTTON_RADIUS := 14
const DIALOG_BUTTON_HEIGHT := 48
const DIALOG_STANDARD_WIDTH := 420
const DIALOG_RICH_WIDTH := 460
const DIALOG_SCREEN_MARGIN := 24
const DIALOG_SHADOW_COLOR := Color(0.20, 0.23, 0.30, 0.16)
const DIALOG_SHADOW_SIZE := 12
const DIALOG_SHADOW_OFFSET := Vector2(0, 5)
const CROWN_BASE_FONT_RATIO := 0.66
const CROWN_FEEDBACK_FONT_DELTA := 0.05
const OPENING_CROWN_FONT_DELTA := 0.16
const CROWN_MAX_FONT_RATIO := 0.72

const REGION_COLOR_NAMES := ["蓝色", "红色", "绿色", "金色", "紫色", "橙色", "青色", "粉色", "青柠色", "靛蓝色"]
const REGION_PATTERN_NAMES := ["散点纹", "三竖线纹", "爪印纹", "双弧纹", "菱形点阵", "斜线纹", "圆环纹", "双横线纹", "弧叶纹", "菱形纹"]
const REGION_COLORS := [
	Color("#38A7F4"),
	Color("#FB5958"),
	Color("#4FC267"),
	Color("#FFDD45"),
	Color("#AA30C4"),
	Color("#FF9A3D"),
	Color("#35D6D0"),
	Color("#FF7BC8"),
	Color("#A7DE38"),
	Color("#5F7CFF")
]

const BOARD_BORDER_INK := Color("#1F2530")
const BOARD_BORDER_ALPHA := 0.92
const BOARD_BORDER := Color("#1F2530")
const BOARD_GAP := Color("#FFFFFF")
const REGION_PATTERN_DARKEN := 0.20
const REGION_PATTERN_ALPHA := 0.30
const CELL_GAP_RATIO := 0.033
const CELL_GAP_MIN := 2.0
const CELL_CORNER_RATIO := 0.085
const ATTENTION_MASK_COLOR := Color(0.92, 0.94, 0.96, 0.70)
const ATTENTION_HALO_COLOR := Color(1.0, 0.82, 0.34, 0.30)
const ATTENTION_HALO_INNER_COLOR := Color(1.0, 1.0, 1.0, 0.24)

const BLOCKED_X_COLOR := Color("#26334A", 0.78)
const BLOCKED_X_HALO_COLOR := Color(1.0, 1.0, 1.0, 0.28)
const BLOCKED_X_RADIUS_RATIO := 0.18
const BLOCKED_X_WIDTH_RATIO := 0.046

const WRONG_X_COLOR := Color("#D92F42")
const WRONG_X_HALO_COLOR := Color("#FFF7F8", 0.94)
const WRONG_X_BACKDROP_COLOR := Color("#F25D72", 0.22)
const WRONG_X_RADIUS_RATIO := 0.22
const WRONG_X_WIDTH_RATIO := 0.060
const WRONG_X_BACKDROP_RADIUS_RATIO := 0.32


static func cell_gap(cell_size: float) -> float:
	return maxf(CELL_GAP_MIN, round(cell_size * CELL_GAP_RATIO))


static func cell_corner_radius(cell_size: float) -> int:
	return int(round(cell_size * CELL_CORNER_RATIO))


static func board_border_width(board_size: int) -> float:
	if board_size <= 6:
		return 4.0
	if board_size <= 8:
		return 3.0
	return 2.0


static func same_region_gap_color(_base_color: Color) -> Color:
	return BOARD_GAP


static func royal_screen_gradient_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.52, 0.76, 0.90, 1.0])
	gradient.colors = PackedColorArray([
		ROYAL_SKY_TOP,
		ROYAL_SKY,
		ROYAL_GLOW,
		ROYAL_FLOOR,
		ROYAL_FLOOR,
		ROYAL_EDGE_BOTTOM,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1
	texture.height = 256
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	return texture


static func light_screen_edge_gradient_texture() -> GradientTexture2D:
	var top_edge := ROYAL_SKY_TOP
	top_edge.a = 0.94
	var top_haze := ROYAL_GLOW
	top_haze.a = 0.30
	var top_clear := ROYAL_GLOW
	top_clear.a = 0.0
	var bottom_clear := ROYAL_EDGE_BOTTOM
	bottom_clear.a = 0.0
	var bottom_haze := ROYAL_EDGE_BOTTOM
	bottom_haze.a = 0.26
	var bottom_edge := ROYAL_EDGE_BOTTOM
	bottom_edge.a = 0.88
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.035, 0.085, 0.88, 0.94, 1.0])
	gradient.colors = PackedColorArray([
		top_edge,
		top_haze,
		top_clear,
		bottom_clear,
		bottom_haze,
		bottom_edge,
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1
	texture.height = 256
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	return texture


static func scaled_safe_insets(safe_rect: Rect2i, window_size: Vector2i, viewport_size: Vector2) -> Vector4:
	if window_size.x <= 0 or window_size.y <= 0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4.ZERO
	var scale_x := viewport_size.x / float(window_size.x)
	var scale_y := viewport_size.y / float(window_size.y)
	return Vector4(
		maxf(0.0, safe_rect.position.x * scale_x),
		maxf(0.0, safe_rect.position.y * scale_y),
		maxf(0.0, (window_size.x - safe_rect.end.x) * scale_x),
		maxf(0.0, (window_size.y - safe_rect.end.y) * scale_y)
	)


static func display_safe_insets(viewport_size: Vector2) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	return scaled_safe_insets(
		DisplayServer.get_display_safe_area(),
		DisplayServer.window_get_size(),
		viewport_size
	)
