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
const SUCCESS_GREEN := Color("#48B985")
const WARNING_YELLOW := Color("#FFF1BD")
const DANGER_RED := Color("#F25D72")
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
const CROWN_BASE_FONT_RATIO := 0.55
const CROWN_FEEDBACK_FONT_DELTA := 0.05
const OPENING_CROWN_FONT_DELTA := 0.16
const CROWN_MAX_FONT_RATIO := 0.72

const REGION_COLOR_NAMES := ["红色", "蓝色", "绿色", "黄色", "紫色", "青色", "橙色", "靛蓝色", "黄绿色", "粉色"]
const REGION_COLORS := [
	Color("#E53935"),
	Color("#1E88E5"),
	Color("#43A047"),
	Color("#FDD835"),
	Color("#8E24AA"),
	Color("#00ACC1"),
	Color("#FB8C00"),
	Color("#3949AB"),
	Color("#7CB342"),
	Color("#D81B60")
]

const BOARD_BORDER_INK := Color("#1F2530")
const BOARD_BORDER_ALPHA := 0.46
# Precomposed over a light surface so every boundary renders with the same color.
const BOARD_BORDER := Color("#989BA0")
const SAME_REGION_GAP_MIX := 0.22
const CELL_GAP_RATIO := 0.033
const CELL_GAP_MIN := 2.0
const CELL_CORNER_RATIO := 0.065
const ATTENTION_MASK_COLOR := Color(0.68, 0.72, 0.78, 0.70)
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


static func same_region_gap_color(base_color: Color) -> Color:
	return base_color.lerp(BOARD_BORDER, SAME_REGION_GAP_MIX)
