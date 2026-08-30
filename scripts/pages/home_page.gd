extends Control

signal start_requested
signal composite_requested
signal tutorial_requested

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const LION_KING_ICON = preload("res://assets/ui/lion_king.svg")
const COLOR_KING_TITLE = preload("res://assets/ui/splash/color_king_title.svg")

var start_button: Button
var composite_button: Button
var tutorial_button: Button

var _localizer: Callable
var _view_data: Dictionary = {}


func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_page()


func present(view_data: Dictionary) -> void:
	_view_data = view_data.duplicate()
	if not start_button:
		return
	var tutorial_completed := bool(view_data.get("tutorial_completed", false))
	var tutorial_started := bool(view_data.get("tutorial_started", false))
	if tutorial_completed:
		start_button.text = _t("开始第 %d 关", [int(view_data.get("player_level", 1))])
	elif tutorial_started:
		start_button.text = _t("继续新手教程")
	else:
		start_button.text = _t("开始新手教程")

	var composite_unlocked := bool(view_data.get("composite_unlocked", false))
	var saved_round := maxi(1, int(view_data.get("composite_round", 1)))
	if tutorial_completed and not composite_unlocked:
		composite_button.text = _t("拼块玩法 · 第 %d 关解锁", [int(view_data.get("composite_unlock_level", 1))])
	elif bool(view_data.get("composite_paid", false)):
		composite_button.text = _t("拼块玩法 · -%d 金币", [int(view_data.get("composite_entry_cost", 0))])
	elif bool(view_data.get("composite_has_history", false)):
		composite_button.text = _t("拼块玩法 · 第 %d 局", [saved_round])
	else:
		composite_button.text = _t("拼块玩法")
	composite_button.disabled = not tutorial_completed
	tutorial_button.text = _t("新人流程")


func refresh_localized_text() -> void:
	present(_view_data)


func _build_page() -> void:
	var base := ColorRect.new()
	base.color = UITokensScript.ROYAL_FLOOR
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	var background := TextureRect.new()
	background.name = "RoyalScreenBackground"
	background.texture = UITokensScript.royal_screen_gradient_texture()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	add_child(_build_hero())
	add_child(_build_primary_buttons())


func _build_hero() -> Control:
	var hero := VBoxContainer.new()
	hero.set_anchor(SIDE_LEFT, 0.08)
	hero.set_anchor(SIDE_TOP, 0.12)
	hero.set_anchor(SIDE_RIGHT, 0.92)
	hero.set_anchor(SIDE_BOTTOM, 0.56)
	hero.add_theme_constant_override("separation", 10)

	var title := TextureRect.new()
	title.name = "HomeBrandTitle"
	title.texture = COLOR_KING_TITLE
	title.custom_minimum_size = Vector2(0, 112)
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero.add_child(title)

	var lion := TextureRect.new()
	lion.texture = LION_KING_ICON
	lion.custom_minimum_size = Vector2(210, 210)
	lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_child(lion)
	return hero


func _build_primary_buttons() -> Control:
	var column := VBoxContainer.new()
	column.set_anchor(SIDE_LEFT, 0.0)
	column.set_anchor(SIDE_TOP, 0.63)
	column.set_anchor(SIDE_RIGHT, 1.0)
	column.set_anchor(SIDE_BOTTOM, 0.94)
	column.offset_left = 36
	column.offset_right = -36
	column.add_theme_constant_override("separation", 10)

	start_button = _royal_button("开始关卡", Color("#3E8DFF"))
	start_button.custom_minimum_size.y = 70
	start_button.pressed.connect(func() -> void: start_requested.emit())
	column.add_child(start_button)

	composite_button = _royal_button("拼块玩法", Color("#635BDB"))
	composite_button.custom_minimum_size.y = 64
	composite_button.pressed.connect(func() -> void: composite_requested.emit())
	column.add_child(composite_button)

	tutorial_button = _royal_button("新人流程", UITokensScript.SURFACE_CARD)
	tutorial_button.custom_minimum_size.y = 60
	tutorial_button.add_theme_color_override("font_color", Color("#287BFF"))
	tutorial_button.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.0))
	tutorial_button.add_theme_stylebox_override("hover", _card_style(Color("#F6FAFF"), 22, true))
	tutorial_button.add_theme_stylebox_override("pressed", _button_style(Color("#E7F1FF"), 22))
	tutorial_button.pressed.connect(func() -> void: tutorial_requested.emit())
	column.add_child(tutorial_button)
	return column


func _royal_button(text_value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.16))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_stylebox_override("normal", _card_style(color, 22, true))
	button.add_theme_stylebox_override("hover", _card_style(color.lightened(0.08), 22, true))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), 22))
	button.add_theme_stylebox_override("disabled", _button_style(color.darkened(0.18), 22))
	return button


func _t(source: String, values: Array = []) -> String:
	if _localizer.is_valid():
		return str(_localizer.call(source, values))
	return source % values if not values.is_empty() else source


func _button_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _card_style(color: Color, radius: int, shadow: bool = false) -> StyleBoxFlat:
	var style := _button_style(color, radius)
	if shadow:
		style.shadow_color = Color(0.16, 0.23, 0.34, 0.18)
		style.shadow_size = 7
		style.shadow_offset = Vector2(0, 4)
	return style
