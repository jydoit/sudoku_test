extends MarginContainer

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const CoinIconResourceScript = preload("res://scripts/components/coin_icon_resource.gd")
const UI_FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.ttf")

var round_label: Label
var cost_caption_label: Label
var balance_caption_label: Label
var cost_value_label: Label
var balance_value_label: Label
var cost_icon: TextureRect
var balance_icon: TextureRect
var _localizer: Callable
var _bold_font: FontVariation


func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	name = "CompositePaidEntryContent"
	custom_minimum_size = Vector2(0, 148)
	add_theme_constant_override("margin_top", 2)
	add_theme_constant_override("margin_bottom", 2)
	_bold_font = FontVariation.new()
	_bold_font.base_font = UI_FONT
	_bold_font.variation_embolden = 0.75

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var round_panel := PanelContainer.new()
	round_panel.name = "PaidEntryRoundPanel"
	round_panel.custom_minimum_size.y = 44
	round_panel.add_theme_stylebox_override("panel", _card_style(UITokensScript.SOFT_BLUE, Color("#CFE1FA"), 14))
	column.add_child(round_panel)
	round_label = Label.new()
	round_label.name = "PaidEntryRound"
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_label.add_theme_font_override("font", _bold_font)
	round_label.add_theme_font_size_override("font_size", 20)
	round_label.add_theme_color_override("font_color", UITokensScript.PRIMARY_BLUE)
	round_panel.add_child(round_label)

	var stats_row := HBoxContainer.new()
	stats_row.name = "PaidEntryStats"
	stats_row.custom_minimum_size.y = 88
	stats_row.add_theme_constant_override("separation", 12)
	column.add_child(stats_row)
	var cost_card := _coin_stat_card("消耗", "PaidEntryCost", UITokensScript.WARNING_YELLOW, Color("#E9D38B"))
	cost_caption_label = cost_card["caption"] as Label
	cost_value_label = cost_card["value"] as Label
	cost_icon = cost_card["icon"] as TextureRect
	stats_row.add_child(cost_card["panel"])
	var balance_card := _coin_stat_card("余额", "PaidEntryBalance", Color("#EEF6FF"), Color("#D4E6FA"))
	balance_caption_label = balance_card["caption"] as Label
	balance_value_label = balance_card["value"] as Label
	balance_icon = balance_card["icon"] as TextureRect
	stats_row.add_child(balance_card["panel"])


func present(round_number: int, entry_cost: int, coin_balance: int) -> void:
	round_label.text = _t("第 %d 局", [maxi(1, round_number)])
	cost_caption_label.text = _t("消耗")
	balance_caption_label.text = _t("余额")
	cost_value_label.text = str(maxi(0, entry_cost))
	balance_value_label.text = str(maxi(0, coin_balance))
	cost_value_label.tooltip_text = _t("消耗 %d 金币", [maxi(0, entry_cost)])
	balance_value_label.tooltip_text = _t("当前持有 %d 金币", [maxi(0, coin_balance)])


func _coin_stat_card(caption_source: String, node_prefix: String, background: Color, border: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "%sCard" % node_prefix
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_style(background, border, 16))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var caption := Label.new()
	caption.name = "%sCaption" % node_prefix
	caption.text = _t(caption_source)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", UITokensScript.MUTED)
	column.add_child(caption)
	var amount_row := HBoxContainer.new()
	amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	amount_row.add_theme_constant_override("separation", 7)
	column.add_child(amount_row)
	var icon := TextureRect.new()
	icon.name = "%sCoinIcon" % node_prefix
	icon.texture = CoinIconResourceScript.texture()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_row.add_child(icon)
	var value := Label.new()
	value.name = "%sValue" % node_prefix
	value.add_theme_font_override("font", _bold_font)
	value.add_theme_font_size_override("font_size", 28)
	value.add_theme_color_override("font_color", UITokensScript.INK)
	amount_row.add_child(value)
	return {"panel": panel, "caption": caption, "icon": icon, "value": value}


func _t(source: String, values: Array = []) -> String:
	if _localizer.is_valid():
		return str(_localizer.call(source, values))
	return source % values if not values.is_empty() else source


func _card_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
