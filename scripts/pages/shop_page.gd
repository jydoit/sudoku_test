extends Control

signal home_requested
signal exchange_requested(offer_id: String)

const UITokensScript = preload("res://scripts/ui_tokens.gd")
const Catalog = preload("res://scripts/services/shop_catalog.gd")
const ButtonContent = preload("res://scripts/components/centered_button_content.gd")
const CoinIcon = preload("res://assets/ui/coin.svg")
const DiamondIcon = preload("res://assets/ui/diamond.svg")
const HomeIcon = preload("res://assets/ui/home.svg")
const CoinsArt = preload("res://assets/ui/shop/coins_pile.svg")
const DiamondsArt = preload("res://assets/ui/shop/diamonds_pile.svg")
const NAVY := Color("#173B69")
const CREAM := Color("#FFF3CE")
const GOLD := Color("#F5BB38")

var active_tab := "diamonds"
var _localizer: Callable
var _safe: MarginContainer
var _title: Label
var _coins: Label
var _diamonds: Label
var _home_button: Button
var _diamond_tab: Button
var _coin_tab: Button
var _preview_label: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _offer_buttons: Array[Button] = []
var _coin_count := 0
var _diamond_count := 0


func configure(localizer: Callable = Callable()) -> void:
	_localizer = localizer
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _shop_theme()
	_build()
	refresh_localized_text()
	visibility_changed.connect(_focus_active_tab)
	resized.connect(_apply_safe_area)
	if is_inside_tree():
		_apply_safe_area()
	else:
		tree_entered.connect(_apply_safe_area, CONNECT_ONE_SHOT)


func present(coins: int, diamonds: int) -> void:
	_coin_count = maxi(0, coins)
	_diamond_count = maxi(0, diamonds)
	_coins.text = _quantity(_coin_count)
	_diamonds.text = _quantity(_diamond_count)
	for value in [_coins, _diamonds]:
		value.add_theme_font_size_override("font_size", 24 if value.text.length() < 9 else 18)
	for button in _offer_buttons:
		# Mock USD prices are display-only. Never grant diamonds from these cards.
		button.disabled = active_tab == "diamonds" or _diamond_count < int(button.get_meta("diamond_cost", 0))


func select_tab(tab: String) -> void:
	active_tab = "coins" if tab == "coins" else "diamonds"
	_diamond_tab.set_pressed_no_signal(active_tab == "diamonds")
	_coin_tab.set_pressed_no_signal(active_tab == "coins")
	_preview_label.text = _t("价格预览") if active_tab == "diamonds" else ""
	_build_offers()
	_scroll.scroll_vertical = 0
	present(_coin_count, _diamond_count)


func refresh_localized_text() -> void:
	_title.text = _t("商店")
	_home_button.tooltip_text = _t("返回首页")
	_diamond_tab.get_meta("content").caption.text = _t("钻石")
	_coin_tab.get_meta("content").caption.text = _t("金币")
	select_tab(active_tab)


func _build() -> void:
	var background := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#156EB4"), Color("#16477C"), Color("#0E2E55")])
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	background.texture = texture
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_safe = MarginContainer.new()
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_safe.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_home_button = Button.new()
	_home_button.custom_minimum_size = Vector2(52, 52)
	_home_button.icon = HomeIcon
	_home_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home_button.add_theme_constant_override("icon_max_width", 28)
	_home_button.add_theme_stylebox_override("normal", _style(CREAM, GOLD, 24, 3))
	_home_button.add_theme_stylebox_override("hover", _style(Color.WHITE, GOLD, 24, 3))
	_home_button.add_theme_stylebox_override("pressed", _style(Color("#DFEAF5"), GOLD, 24, 3))
	_home_button.pressed.connect(func() -> void: home_requested.emit())
	header.add_child(_home_button)
	_title = _label("", 34, CREAM)
	_title.add_theme_color_override("font_outline_color", NAVY)
	_title.add_theme_constant_override("outline_size", 5)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 52
	header.add_child(spacer)
	var balances := HBoxContainer.new()
	balances.add_theme_constant_override("separation", 14)
	column.add_child(balances)
	_coins = _label("0", 24, NAVY)
	_diamonds = _label("0", 24, NAVY)
	balances.add_child(_balance(CoinIcon, _coins))
	balances.add_child(_balance(DiamondIcon, _diamonds))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	_diamond_tab = _tab(DiamondIcon)
	_coin_tab = _tab(CoinIcon)
	tabs.add_child(_diamond_tab)
	tabs.add_child(_coin_tab)
	_diamond_tab.pressed.connect(func() -> void: select_tab("diamonds"))
	_coin_tab.pressed.connect(func() -> void: select_tab("coins"))
	var group := ButtonGroup.new()
	_diamond_tab.button_group = group
	_coin_tab.button_group = group
	_preview_label = _label("", 14, Color("#D1E2F2"))
	_preview_label.custom_minimum_size.y = 20
	column.add_child(_preview_label)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		grid_margin.add_theme_constant_override("margin_" + edge, 5)
	_scroll.add_child(grid_margin)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	grid_margin.add_child(_grid)


func _build_offers() -> void:
	_offer_buttons.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var is_coins := active_tab == "coins"
	var offers := Catalog.coin_offers() if is_coins else Catalog.diamond_offers()
	for offer in offers:
		_grid.add_child(_offer_card(offer, is_coins))


func _offer_card(offer: Dictionary, is_coins: bool) -> Control:
	var frame := PanelContainer.new()
	frame.name = str(offer["id"])
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Keep prices on the physical bottom-right even in an RTL locale.
	frame.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var frame_style := _style(Color("#E3A42C"), GOLD, 22, 3)
	frame_style.set_content_margin_all(5)
	frame_style.shadow_color = Color(0.02, 0.08, 0.16, 0.45)
	frame_style.shadow_size = 3
	frame_style.shadow_offset = Vector2(0, 4)
	frame.add_theme_stylebox_override("panel", frame_style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	frame.add_child(column)
	var art_panel := PanelContainer.new()
	var art_style := _style(Color("#FFF1CD") if is_coins else Color("#E4F5FF"), Color("#FFFAE5"), 17, 2)
	art_style.corner_radius_bottom_left = 0
	art_style.corner_radius_bottom_right = 0
	art_style.set_content_margin_all(6)
	art_panel.add_theme_stylebox_override("panel", art_style)
	column.add_child(art_panel)
	var art_column := VBoxContainer.new()
	art_column.add_theme_constant_override("separation", 0)
	art_panel.add_child(art_column)
	var art := _icon(CoinsArt if is_coins else DiamondsArt, 92)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_column.add_child(art)
	var quantity := _label(_quantity(int(offer["quantity"])), 30, NAVY)
	quantity.custom_minimum_size.y = 36
	quantity.add_theme_color_override("font_outline_color", Color.WHITE)
	quantity.add_theme_constant_override("outline_size", 3)
	art_column.add_child(quantity)
	var footer := PanelContainer.new()
	var footer_style := _style(Color("#23558A"), Color("#F8C755"), 17, 0)
	footer_style.corner_radius_top_left = 0
	footer_style.corner_radius_top_right = 0
	footer_style.set_content_margin_all(7)
	footer.add_theme_stylebox_override("panel", footer_style)
	column.add_child(footer)
	var row := HBoxContainer.new()
	footer.add_child(row)
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(filler)
	var price := Button.new()
	price.name = "Price"
	price.custom_minimum_size = Vector2(122, 48)
	if is_coins:
		var content := ButtonContent.new()
		content.configure(price, DiamondIcon, 26)
		content.caption.text = str(offer["diamond_cost"])
		price.set_meta("diamond_cost", offer["diamond_cost"])
		price.pressed.connect(func() -> void: exchange_requested.emit(str(offer["id"])))
	else:
		price.text = Catalog.usd_price(int(offer["usd_cents"]))
		price.tooltip_text = _t("价格预览")
		price.disabled = true
	row.add_child(price)
	_offer_buttons.append(price)
	return frame


func _balance(texture: Texture2D, value: Label) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _style(CREAM, GOLD, 18, 2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(_icon(texture, 36))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	row.add_child(value)
	return card


func _tab(texture: Texture2D) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 56
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_constant_override("h_separation", 12)
	button.add_theme_stylebox_override("normal", _style(Color("#163D68"), Color("#547AA3"), 17, 2))
	button.add_theme_stylebox_override("hover", _style(Color("#255788"), GOLD, 17, 2))
	button.add_theme_stylebox_override("pressed", _style(CREAM, GOLD, 17, 3))
	button.add_theme_stylebox_override("hover_pressed", _style(Color("#FFF9E8"), GOLD, 17, 3))
	button.add_theme_color_override("font_color", Color("#E3EFFA"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color("#E3EFFA"))
	button.add_theme_color_override("font_pressed_color", NAVY)
	button.add_theme_color_override("font_hover_pressed_color", NAVY)
	var content := ButtonContent.new()
	content.configure(button, texture, 28)
	button.set_meta("content", content)
	return button


func _shop_theme() -> Theme:
	var result := Theme.new()
	var bold := FontVariation.new()
	bold.base_font = preload("res://assets/fonts/NotoSansSC-Regular.ttf")
	bold.variation_embolden = 0.7
	result.default_font = bold
	result.set_font_size("font_size", "Button", 23)
	result.set_stylebox("normal", "Button", _style(Color("#69AF39"), Color("#D3EF77"), 14, 2))
	result.set_stylebox("hover", "Button", _style(Color("#7BBF48"), Color("#F9F4AB"), 14, 2))
	result.set_stylebox("pressed", "Button", _style(Color("#448C25"), Color("#BADF67"), 14, 2))
	result.set_stylebox("disabled", "Button", _style(Color("#91AF89"), Color("#D2DDA4"), 14, 2))
	var focus := _style(Color.TRANSPARENT, Color.WHITE, 14, 2)
	focus.draw_center = false
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	result.set_stylebox("focus", "Button", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		result.set_color(state, "Button", Color("#FFFFFF"))
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_disabled_color"]:
		result.set_color(state, "Button", Color.WHITE)
	result.set_color("font_outline_color", "Button", Color("#2C5225"))
	result.set_constant("outline_size", "Button", 2)
	return result


func _style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _icon(texture: Texture2D, height: int) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = Vector2(height, height)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_safe_area() -> void:
	if not _safe or not is_inside_tree():
		return
	var insets := UITokensScript.display_safe_insets(get_viewport_rect().size)
	_safe.add_theme_constant_override("margin_left", maxi(24, ceili(insets.x + 12)))
	_safe.add_theme_constant_override("margin_right", maxi(24, ceili(insets.z + 12)))
	_safe.add_theme_constant_override("margin_top", maxi(24, ceili(insets.y + 8)))
	_safe.add_theme_constant_override("margin_bottom", maxi(18, ceili(insets.w + 8)))


func _focus_active_tab() -> void:
	if is_inside_tree() and is_visible_in_tree() and _diamond_tab:
		var active_button: Button = _coin_tab if active_tab == "coins" else _diamond_tab
		if active_button.is_inside_tree():
			active_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		home_requested.emit()
		get_viewport().set_input_as_handled()


func _quantity(value: int) -> String:
	var digits := str(value)
	var formatted := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			formatted += " "
		formatted += digits[i]
	return formatted


func _t(source: String, values: Array = []) -> String:
	if _localizer.is_valid():
		return str(_localizer.call(source, values))
	return source % values if not values.is_empty() else source
