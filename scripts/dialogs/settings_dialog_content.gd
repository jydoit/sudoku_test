extends MarginContainer

var language_picker: OptionButton
var music_toggle: CheckButton
var sfx_toggle: CheckButton
var haptics_toggle: CheckButton
var _localizer: Callable


func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	name = "SettingsContent"
	custom_minimum_size = Vector2(368, 298)
	add_theme_constant_override("margin_left", 12)
	add_theme_constant_override("margin_right", 12)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var description := Label.new()
	_set_localized_text(description, "设置语言、音乐、音效和震动反馈。")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color("#718096"))
	description.add_theme_font_size_override("font_size", 14)
	column.add_child(description)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 52
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var label := Label.new()
	_set_localized_text(label, "游戏语言")
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

	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 6)
	column.add_child(divider)
	music_toggle = _setting_toggle("音乐")
	sfx_toggle = _setting_toggle("音效")
	haptics_toggle = _setting_toggle("震动反馈")
	column.add_child(music_toggle)
	column.add_child(sfx_toggle)
	column.add_child(haptics_toggle)


func present(options: Array, locale_index: int, preferences: Dictionary = {}) -> void:
	language_picker.clear()
	for option in options:
		var option_index := language_picker.item_count
		language_picker.add_item(str(option["name"]))
		language_picker.set_item_metadata(option_index, str(option["code"]))
	if language_picker.item_count > 0:
		language_picker.select(clampi(locale_index, 0, language_picker.item_count - 1))
	music_toggle.button_pressed = bool(preferences.get("musicEnabled", true))
	sfx_toggle.button_pressed = bool(preferences.get("sfxEnabled", true))
	haptics_toggle.button_pressed = bool(preferences.get("hapticsEnabled", true))


func selected_locale() -> String:
	if language_picker.selected < 0:
		return ""
	return str(language_picker.get_item_metadata(language_picker.selected))


func selected_audio_preferences() -> Dictionary:
	return {
		"musicEnabled": music_toggle.button_pressed,
		"sfxEnabled": sfx_toggle.button_pressed,
		"hapticsEnabled": haptics_toggle.button_pressed,
	}


func _setting_toggle(label_text: String) -> CheckButton:
	var toggle := CheckButton.new()
	_set_localized_text(toggle, label_text)
	toggle.custom_minimum_size.y = 46
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.add_theme_font_size_override("font_size", 16)
	toggle.add_theme_color_override("font_color", Color("#26334A"))
	return toggle


func _set_localized_text(control: Control, source: String) -> void:
	control.set_meta(&"localization_text_source", source)
	control.set_meta(&"localization_text_values", [])
	control.set("text", _t(source))


func _t(source: String) -> String:
	if _localizer.is_valid():
		return str(_localizer.call(source))
	return source


func _button_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
