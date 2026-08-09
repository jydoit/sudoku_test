extends MarginContainer

var language_picker: OptionButton
var _localizer: Callable


func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	name = "SettingsContent"
	custom_minimum_size = Vector2(368, 126)
	add_theme_constant_override("margin_left", 12)
	add_theme_constant_override("margin_right", 12)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var description := Label.new()
	description.text = "选择界面和游戏提示使用的语言。"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#718096"))
	description.add_theme_font_size_override("font_size", 14)
	column.add_child(description)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 52
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var label := Label.new()
	label.text = "游戏语言"
	label.custom_minimum_size.x = 104
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#26334A"))
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	language_picker = OptionButton.new()
	language_picker.name = "LanguagePicker"
	language_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_picker.custom_minimum_size.y = 48
	language_picker.focus_mode = Control.FOCUS_ALL
	language_picker.add_theme_font_size_override("font_size", 16)
	language_picker.add_theme_color_override("font_color", Color("#26334A"))
	language_picker.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 12))
	row.add_child(language_picker)


func present(options: Array, locale_index: int) -> void:
	language_picker.clear()
	for option in options:
		var option_index := language_picker.item_count
		language_picker.add_item(str(option["name"]))
		language_picker.set_item_metadata(option_index, str(option["code"]))
	if language_picker.item_count > 0:
		language_picker.select(clampi(locale_index, 0, language_picker.item_count - 1))


func selected_locale() -> String:
	if language_picker.selected < 0:
		return ""
	return str(language_picker.get_item_metadata(language_picker.selected))


func _button_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
