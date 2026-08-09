extends TabContainer

signal replay_composite_intro_requested

const RuleIllustrationScript = preload("res://scripts/rule_illustration.gd")
const UITokensScript = preload("res://scripts/ui_tokens.gd")

var _localizer: Callable


func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	name = "HelpContent"
	custom_minimum_size = Vector2(408, 470)
	_build_formal_rules()
	_build_composite_rules()
	refresh_localized_text()


func show_composite_tab(composite_active: bool) -> void:
	current_tab = 1 if composite_active else 0


func refresh_localized_text() -> void:
	if get_tab_count() >= 2:
		set_tab_title(0, _t("消除规则"))
		set_tab_title(1, _t("拼块玩法"))


func _build_formal_rules() -> void:
	var margin := MarginContainer.new()
	margin.name = "消除规则"
	margin.custom_minimum_size = Vector2(408, 438)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var intro := Label.new()
	intro.text = "记住三个规则，把不可能的位置标记为 X。"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", UITokensScript.INK)
	intro.add_theme_font_size_override("font_size", 16)
	column.add_child(intro)

	column.add_child(_build_rule(RuleIllustrationScript.ADJACENT, "AdjacentRuleIllustration", "皇冠周围都是 X", "皇冠的八个邻近方格不能再出现皇冠。"))
	column.add_child(_build_rule(RuleIllustrationScript.ROW_COLUMN, "RowColumnRuleIllustration", "每行、每列一个皇冠", "找到皇冠后，同一行和同一列的其它格都标记 X。"))
	column.add_child(_build_rule(RuleIllustrationScript.REGION, "RegionRuleIllustration", "每种颜色一个皇冠", "一个颜色区域只能有一个皇冠，其余同色格标记 X。"))


func _build_composite_rules() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "拼块玩法"
	scroll.custom_minimum_size = Vector2(408, 438)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var intro := Label.new()
	intro.text = "先补完整个颜色区域，再开始找皇冠。"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color", UITokensScript.INK)
	intro.add_theme_font_size_override("font_size", 16)
	column.add_child(intro)
	column.add_child(_build_step("1", "向下拖出彩色方块", "顶部待放置区可以左右滑动，查看尚未放置的方块。"))
	column.add_child(_build_step("2", "完整对齐空白凹槽", "只要方块不越界、不重叠，就可以吸附到施工区。"))
	column.add_child(_build_step("3", "死局可以复活", "同色区域被隔离时，可用金币自动放回最后一个方块，或重新开始本局。"))
	column.add_child(_build_step("4", "可以随时拿回重放", "把棋盘上的立体方块向上拖回待放置区，再尝试其它位置。"))
	column.add_child(_build_step("5", "拼完自动进入找皇冠", "立体方块会压平为正常颜色棋盘，并恢复清除、直找和提示。"))
	var replay_button := Button.new()
	replay_button.name = "ReplayAssemblyIntro"
	replay_button.text = "重播演示"
	replay_button.custom_minimum_size.y = 48
	replay_button.add_theme_font_size_override("font_size", 16)
	replay_button.add_theme_stylebox_override("normal", _button_style(UITokensScript.SOFT_BLUE, 14))
	replay_button.pressed.connect(func() -> void: replay_composite_intro_requested.emit())
	column.add_child(replay_button)


func _build_step(number: String, title_text: String, body_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 78
	panel.add_theme_stylebox_override("panel", _content_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var badge := Label.new()
	badge.text = number
	badge.custom_minimum_size = Vector2(34, 34)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_font_size_override("font_size", 17)
	badge.add_theme_stylebox_override("normal", _button_style(UITokensScript.PRIMARY_BLUE, 17))
	row.add_child(badge)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", UITokensScript.INK)
	title.add_theme_font_size_override("font_size", 16)
	copy.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", UITokensScript.MUTED)
	body.add_theme_font_size_override("font_size", 13)
	copy.add_child(body)
	return panel


func _build_rule(kind: String, illustration_name: String, title_text: String, body_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 120
	panel.add_theme_stylebox_override("panel", _content_style())
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var illustration = RuleIllustrationScript.new()
	illustration.name = illustration_name
	illustration.configure(kind)
	row.add_child(illustration)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 5)
	row.add_child(copy)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", UITokensScript.INK)
	title.add_theme_font_size_override("font_size", 17)
	copy.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", UITokensScript.MUTED)
	body.add_theme_font_size_override("font_size", 14)
	copy.add_child(body)
	return panel


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


func _content_style() -> StyleBoxFlat:
	var style := _button_style(UITokensScript.DIALOG_CONTENT_SURFACE, 14)
	style.border_color = UITokensScript.DIALOG_CONTENT_BORDER
	style.set_border_width_all(1)
	return style
