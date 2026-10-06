extends CenterContainer
## Button's centered icon overlaps centered text. Lay them out as one unit,
## while inheriting its normal/hover/pressed/focus/disabled text colors.

var caption: Label
var _button: Button


func configure(button: Button, texture: Texture2D, icon_size: int = 28) -> void:
	_button = button
	button.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	caption = Label.new()
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", button.get_theme_font_size("font_size"))
	row.add_child(caption)
	button.draw.connect(_sync_color)


func _sync_color() -> void:
	# The button may acquire its page theme only after it enters the tree.
	var font_size := _button.get_theme_font_size("font_size")
	if caption.get_theme_font_size("font_size") != font_size:
		caption.add_theme_font_size_override("font_size", font_size)
	var key := "font_color"
	match _button.get_draw_mode():
		BaseButton.DRAW_HOVER: key = "font_hover_color"
		BaseButton.DRAW_PRESSED: key = "font_pressed_color"
		BaseButton.DRAW_HOVER_PRESSED: key = "font_hover_pressed_color"
		BaseButton.DRAW_DISABLED: key = "font_disabled_color"
	if _button.has_focus() and _button.get_draw_mode() == BaseButton.DRAW_NORMAL:
		key = "font_focus_color"
	var color := _button.get_theme_color(key)
	if caption.get_theme_color("font_color") != color:
		caption.add_theme_color_override("font_color", color)
