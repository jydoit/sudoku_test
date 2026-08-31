extends MarginContainer

const CHECK_ICON: Texture2D = preload("res://assets/ui/check.svg")

var picker: OptionButton
var _localizer: Callable


func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	name = "LevelSelectContent"
	custom_minimum_size = Vector2(368, 86)
	add_theme_constant_override("margin_left", 12)
	add_theme_constant_override("margin_right", 12)
	add_theme_constant_override("margin_top", 12)
	add_theme_constant_override("margin_bottom", 8)
	picker = OptionButton.new()
	picker.custom_minimum_size.y = 48
	picker.focus_mode = Control.FOCUS_NONE
	picker.add_theme_font_size_override("font_size", 17)
	picker.add_theme_color_override("font_color", Color("#26334A"))
	picker.add_theme_stylebox_override("normal", _button_style(Color("#F1F4F7"), 12))
	add_child(picker)


func present(levels: Array, completed_levels: Array, selected_index: int) -> void:
	picker.clear()
	for index in range(levels.size()):
		var level: Dictionary = levels[index]
		var label := _t("关卡 %d · %s", [int(level["levelId"]), _t(str(level.get("difficulty", "normal")))])
		picker.add_item(label, index)
		if completed_levels.has(int(level["levelId"])):
			picker.set_item_icon(picker.item_count - 1, CHECK_ICON)
	if not levels.is_empty():
		picker.select(clampi(selected_index, 0, levels.size() - 1))


func selected_index() -> int:
	var selected_id := picker.get_selected_id()
	return selected_id if selected_id >= 0 else picker.selected


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
