extends MarginContainer

var language_picker: OptionButton
var music_toggle: Button
var sfx_toggle: Button
var haptics_toggle: Button
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
	var music_row := _setting_toggle_row("音乐", "MusicToggle")
	music_toggle = music_row["toggle"] as Button
	column.add_child(music_row["row"])
	var sfx_row := _setting_toggle_row("音效", "SoundEffectsToggle")
	sfx_toggle = sfx_row["toggle"] as Button
	column.add_child(sfx_row["row"])
	var haptics_row := _setting_toggle_row("震动反馈", "HapticsToggle")
	haptics_toggle = haptics_row["toggle"] as Button
	column.add_child(haptics_row["row"])


func present(options: Array, locale_index: int, preferences: Dictionary = {}) -> void:
	language_picker.clear()
	for option in options:
		var option_index := language_picker.item_count
		language_picker.add_item(str(option["name"]))
		language_picker.set_item_metadata(option_index, str(option["code"]))
	if language_picker.item_count > 0:
		language_picker.select(clampi(locale_index, 0, language_picker.item_count - 1))
	music_toggle.set_pressed_no_signal(bool(preferences.get("musicEnabled", true)))
	sfx_toggle.set_pressed_no_signal(bool(preferences.get("sfxEnabled", true)))
	haptics_toggle.set_pressed_no_signal(bool(preferences.get("hapticsEnabled", true)))
	refresh_localized_text()


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


func refresh_localized_text() -> void:
	_refresh_toggle_visual(music_toggle)
	_refresh_toggle_visual(sfx_toggle)
	_refresh_toggle_visual(haptics_toggle)


func _setting_toggle_row(label_text: String, toggle_name: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 52
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.name = "%sLabel" % toggle_name
	_set_localized_text(label, label_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("#26334A"))
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var toggle := Button.new()
	toggle.name = toggle_name
	toggle.toggle_mode = true
	toggle.custom_minimum_size = Vector2(88, 44)
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.add_theme_font_size_override("font_size", 15)
	toggle.toggled.connect(func(_pressed: bool) -> void: _refresh_toggle_visual(toggle))
	row.add_child(toggle)
	_refresh_toggle_visual(toggle)
	return {"row": row, "toggle": toggle}


func _refresh_toggle_visual(toggle: Button) -> void:
	if not toggle:
		return
	var enabled := toggle.button_pressed
	_set_localized_text(toggle, "开启" if enabled else "关闭")
	var background := Color("#DDF7EB") if enabled else Color("#EEF1F5")
	var border := Color("#38A976") if enabled else Color("#A8B0BC")
	var font_color := Color("#18724B") if enabled else Color("#526071")
	for state in ["normal", "hover", "pressed", "focus"]:
		var state_background := background
		if state == "hover":
			state_background = background.lightened(0.04)
		elif state == "pressed":
			state_background = background.darkened(0.04)
		toggle.add_theme_stylebox_override(state, _toggle_style(state_background, border))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		toggle.add_theme_color_override(color_name, font_color)


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


func _toggle_style(color: Color, border_color: Color) -> StyleBoxFlat:
	var style := _button_style(color, 22)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style
