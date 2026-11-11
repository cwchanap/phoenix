class_name MorningSummaryPanel
extends Control

signal acknowledged

const INTRO_WALLPAPER := preload("res://assets/ui/backgrounds/intro.png")
const SUN_ICON := preload("res://assets/ui/icons/sun.png")
const RAIN_ICON := preload("res://assets/ui/icons/rain.png")
const MONEY_ICON := preload("res://assets/ui/icons/money-bag.png")
const SAVE_ICON := preload("res://assets/ui/icons/save.png")
const GROWTH_ICON := preload("res://assets/ui/icons/growth.png")
const COIN_STACK_ICON := preload("res://assets/ui/icons/coin-stack.png")
const RAIN_TILE := Color("4d8dff")
const SAVE_STATUS_MAX_SHOWN := 2
const SAVE_STATUS_WIDTH := 420.0
const SAVE_STATUS_SCROLL_STEP := 30

var _frame: PhoneFrame
var _day_line: Label
var _weather_tail: Label
var _weather_tile_box: StyleBoxFlat
var _weather_icon: TextureRect
var _card_values: Array[Label] = []
var _card_captions: Array[Label] = []
var _weather_sub: Label
var _farm_sub: Label
var _withered: Label
var _shipment_single: PanelContainer
var _single_row: Dictionary
var _shipment_compact: VBoxContainer
var _compact_rows: Array[Dictionary] = []
var _shipment_empty: Label
var _money: Label
var _diary_line: Label
var _action_text: Label
var _save_status: Label
var _save_status_card: PanelContainer
var _save_status_scroll: ScrollContainer
var _save_hint: Label
var _acknowledge: Button
var _save_badge: PanelContainer
var _save_caption: Label
var _badge_ok := UiStyle.card(
	Color(UiStyle.LEAF, 0.15), UiStyle.PILL_RADIUS, [12, 4, 12, 4], false
)
var _badge_error := UiStyle.card(
	Color(UiStyle.BAD, 0.14), UiStyle.PILL_RADIUS, [12, 4, 12, 4], false
)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_acknowledge.pressed.connect(_on_acknowledge_pressed)
	visible = false

func present(summary: Dictionary) -> void:
	var completed_day := int(summary.get("completed_day", 0))
	var next_day := int(summary.get("next_day", 0))
	_day_line.text = "%s → %s" % [
		tr("Day %d") % completed_day,
		tr("Day %d") % next_day,
	]

	var weather := StringName(summary.get("next_weather", &"sunny"))
	var rainy := weather == GameRules.weather_key(GameRules.Weather.RAINY)
	_weather_tail.text = "· %s" % tr("Rainy" if rainy else "Sunny")
	_weather_tile_box.bg_color = RAIN_TILE if rainy else UiStyle.SUN
	_weather_icon.texture = RAIN_ICON if rainy else SUN_ICON
	_card_values[0].text = "Rain all day" if rainy else "Sunny all day"
	_weather_sub.text = (
		"No watering needed today." if rainy else "Water as usual."
	)

	var crops_advanced := int(summary.get("crops_advanced", 0))
	if crops_advanced <= 0:
		_card_values[1].text = "No crops grew overnight"
	elif crops_advanced == 1:
		_card_values[1].text = tr("%d crop grew overnight") % crops_advanced
	else:
		_card_values[1].text = tr("%d crops grew overnight") % crops_advanced
	_farm_sub.text = tr("Stamina is back to %d.") % GameRules.MAX_STAMINA

	var crops_withered := int(summary.get("crops_withered", 0))
	_withered.visible = crops_withered > 0
	if _withered.visible:
		_withered.text = (
			tr("%d CROP WITHERED") if crops_withered == 1 else tr("%d CROPS WITHERED")
		) % crops_withered

	var income := int(summary.get("shipping_income", 0))
	_card_values[2].text = (
		tr("Shipping payout +%dG") % income if income > 0 else "No shipping payout"
	)

	var shipments: Array = summary.get("shipments", [])
	assert(shipments.size() <= _compact_rows.size(), "morning summary has too many shipment lines")
	_shipment_single.visible = shipments.size() == 1
	_shipment_compact.visible = shipments.size() > 1
	_shipment_empty.visible = shipments.is_empty()
	if _shipment_single.visible:
		_render_shipment_row(_single_row, shipments[0])
	for index in _compact_rows.size():
		var row := _compact_rows[index]
		(row["row"] as Control).visible = _shipment_compact.visible and index < shipments.size()
		if (row["row"] as Control).visible:
			_render_shipment_row(row, shipments[index])

	_money.text = "%dG" % int(summary.get("money_after_shipping", 0))
	_diary_line.text = ContentRules.diary_line(next_day)
	_action_text.text = tr("START DAY %d") % next_day
	visible = true

func _render_shipment_row(row: Dictionary, shipment: Dictionary) -> void:
	var crop_key := StringName(shipment.get("crop", &"turnip"))
	var kind := GameRules.CROP_KEYS.find(crop_key)
	(row["name"] as Label).text = "%s ×%d" % [
		tr(GameRules.crop_display_name(kind)),
		int(shipment.get("quantity", 0)),
	]
	(row["amount"] as Label).text = "%dG" % int(shipment.get("amount", 0))
	(row["icon"] as TextureRect).texture = load(
		"res://assets/ui/crops/%s.png" % crop_key
	) as Texture2D

func set_save_status(status: StringName, message: String = "") -> void:
	match status:
		&"idle":
			_save_status.text = ""
			_save_status_card.visible = false
			_save_badge.visible = false
		&"saved":
			_save_status.text = "Saved."
			_save_status.add_theme_color_override("font_color", UiStyle.LEAF_DEEP)
			_save_status_card.visible = true
			_save_caption.text = "SAVED"
			_save_caption.add_theme_color_override("font_color", UiStyle.LEAF)
			_save_badge.add_theme_stylebox_override("panel", _badge_ok)
			_save_badge.visible = true
		&"error":
			_save_status.text = message
			_save_status.add_theme_color_override("font_color", UiStyle.BAD)
			_save_status_card.visible = true
			_save_caption.text = "SAVE ERROR"
			_save_caption.add_theme_color_override("font_color", UiStyle.BAD)
			_save_badge.add_theme_stylebox_override("panel", _badge_error)
			_save_badge.visible = true
		_:
			assert(false, "unknown save status")
	if _save_status_scroll != null:
		_save_status_scroll.scroll_vertical = 0
	if is_inside_tree():
		call_deferred(&"_sync_save_status_height")

func _sync_save_status_height() -> void:
	if _save_status == null or _save_status_scroll == null:
		return
	var lines := _save_status.get_line_count()
	var line_height := _save_status.get_line_height()
	var shown := clampi(lines, 1, SAVE_STATUS_MAX_SHOWN)
	_save_status_scroll.custom_minimum_size = Vector2(
		SAVE_STATUS_WIDTH, ceilf(line_height * float(shown))
	)
	_save_hint.visible = lines > SAVE_STATUS_MAX_SHOWN

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if _save_status_scroll == null or _save_status == null:
		return
	if _save_status.get_line_count() <= SAVE_STATUS_MAX_SHOWN:
		return
	var max_scroll := int(maxf(
		0.0,
		_save_status.get_combined_minimum_size().y - _save_status_scroll.size.y,
	))
	if max_scroll <= 0:
		return
	if event.is_action_pressed("move_up"):
		_save_status_scroll.scroll_vertical = maxi(
			0, _save_status_scroll.scroll_vertical - SAVE_STATUS_SCROLL_STEP
		)
	elif event.is_action_pressed("move_down"):
		_save_status_scroll.scroll_vertical = mini(
			max_scroll,
			_save_status_scroll.scroll_vertical + SAVE_STATUS_SCROLL_STEP,
		)
	else:
		return
	get_viewport().set_input_as_handled()

func set_status_time(time_text: String) -> void:
	_frame.set_status_time(time_text)

func status_time_text() -> String:
	return _frame.status_time_text()

func save_status_text() -> String:
	return _save_status.text

func summary_state() -> Dictionary:
	var shipments: Array = []
	if _shipment_single.visible:
		shipments.append({
			"name": (_single_row["name"] as Label).text,
			"amount": (_single_row["amount"] as Label).text,
		})
	else:
		for row in _compact_rows:
			if (row["row"] as Control).visible:
				shipments.append({
					"name": (row["name"] as Label).text,
					"amount": (row["amount"] as Label).text,
				})
	var card_values: Array[String] = []
	var card_captions: Array[String] = []
	for index in _card_values.size():
		card_values.append(_card_values[index].text)
		card_captions.append(_card_captions[index].text)
	var shipment_mode := "empty"
	if _shipment_single.visible:
		shipment_mode = "single"
	elif _shipment_compact.visible:
		shipment_mode = "compact"
	return {
		"day_text": _day_line.text,
		"card_values": card_values,
		"card_captions": card_captions,
		"withered_visible": _withered.visible,
		"withered_text": _withered.text,
		"shipment_mode": shipment_mode,
		"shipments": shipments,
		"money_text": _money.text,
		"diary_line": _diary_line.text,
		"action_text": _action_text.text,
		"save_badge_visible": _save_badge.visible,
	}

func _on_acknowledge_pressed() -> void:
	acknowledged.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()
	acknowledged.emit()

func _build() -> void:
	_frame = UiStyle.phone_mount(self)
	_frame.set_screen_backplate(
		UiStyle.wallpaper_texture(
			INTRO_WALLPAPER,
			Vector2i(
				int(PhoneFrame.PHONE_SIZE.x) - 28,
				int(PhoneFrame.PHONE_SIZE.y) - 28,
			),
			PhoneFrame.SCREEN_RADIUS,
			Color(10.0 / 255.0, 10.0 / 255.0, 30.0 / 255.0, 0.3),
			Color(10.0 / 255.0, 10.0 / 255.0, 30.0 / 255.0, 0.72),
		)
	)
	_frame.set_status_time_visible(false)

	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 20], ["top", 6], ["right", 20], ["bottom", 0]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(6)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_lock_header())

	var weather := _notification_card("Weather", RAIN_TILE, RAIN_ICON)
	_weather_tile_box = weather["tile_box"]
	_weather_icon = weather["tile_icon"]
	_card_values.append(weather["headline"])
	_card_captions.append(weather["header"])
	_weather_sub = _card_sub("")
	weather["lines"].add_child(_weather_sub)
	column.add_child(weather["card"])

	var farm := _notification_card("Farm", UiStyle.LEAF, GROWTH_ICON)
	_card_values.append(farm["headline"])
	_card_captions.append(farm["header"])
	_farm_sub = _card_sub("")
	farm["lines"].add_child(_farm_sub)
	_withered = UiStyle.label("", 13, UiStyle.BAD, 800)
	_withered.name = "WitheredWarning"
	_withered.visible = false
	farm["lines"].add_child(_withered)
	column.add_child(farm["card"])

	var bank := _notification_card("Bank", UiStyle.SUN, COIN_STACK_ICON)
	_card_values.append(bank["headline"])
	_card_captions.append(bank["header"])
	var shipments := UiStyle.vbox(5)
	shipments.name = "Shipments"
	bank["lines"].add_child(shipments)
	_shipment_single = _shipment_row("ShipmentRow", 24, 14, 14)
	_shipment_single.visible = false
	shipments.add_child(_shipment_single)
	_single_row = _row_children(_shipment_single)
	_shipment_compact = UiStyle.vbox(4)
	_shipment_compact.name = "CompactShipmentRows"
	_shipment_compact.visible = false
	shipments.add_child(_shipment_compact)
	for index in 3:
		var row := _shipment_row("Row_%d" % index, 16, 13, 13)
		row.visible = false
		_shipment_compact.add_child(row)
		_compact_rows.append(_row_children(row))
	_shipment_empty = UiStyle.label("No crops shipped.", 14, UiStyle.INK_MUTED, 500)
	_shipment_empty.name = "EmptyShipment"
	_shipment_empty.visible = false
	shipments.add_child(_shipment_empty)
	var balance := UiStyle.hbox(8)
	balance.name = "BalanceRow"
	bank["lines"].add_child(balance)
	var coin := UiStyle.icon(MONEY_ICON, 20)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance.add_child(coin)
	var balance_caption := UiStyle.label("Balance", 15, UiStyle.INK_MUTED, 700)
	balance_caption.name = "Sub"
	balance_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance.add_child(balance_caption)
	_money = UiStyle.label("", 20, UiStyle.ORANGE, 900)
	_money.name = "Amount"
	_money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance.add_child(_money)
	column.add_child(bank["card"])

	_diary_line = UiStyle.shadowed_label("", 16, 600)
	_diary_line.name = "DiaryLine"
	_diary_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diary_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_diary_line)

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var footer := _frame.footer_mount()
	var lead := Control.new()
	lead.name = "Lead"
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(lead)
	var actions := UiStyle.vbox(8)
	actions.name = "Actions"
	footer.add_child(actions)
	var trail := Control.new()
	trail.name = "Trail"
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(trail)

	_save_status_card = PanelContainer.new()
	_save_status_card.name = "SaveStatusCard"
	_save_status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_status_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_save_status_card.visible = false
	_save_status_card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 16, [14, 6, 14, 6])
	)
	actions.add_child(_save_status_card)
	var save_column := UiStyle.vbox(6)
	save_column.name = "Column"
	_save_status_card.add_child(save_column)

	var head_row := UiStyle.hbox(8)
	head_row.name = "HeadRow"
	save_column.add_child(head_row)

	_save_badge = PanelContainer.new()
	_save_badge.name = "SaveBadge"
	_save_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_badge.visible = false
	_save_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_save_badge.add_theme_stylebox_override("panel", _badge_ok)
	head_row.add_child(_save_badge)
	var badge_row := UiStyle.hbox(6)
	badge_row.name = "Row"
	_save_badge.add_child(badge_row)
	var badge_icon := UiStyle.icon(SAVE_ICON, 16)
	badge_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_row.add_child(badge_icon)
	_save_caption = UiStyle.label("SAVED", 15, UiStyle.LEAF, 800)
	_save_caption.name = "Caption"
	badge_row.add_child(_save_caption)

	var head_spacer := Control.new()
	head_spacer.name = "Spacer"
	head_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head_spacer)
	_save_hint = UiStyle.label("W/S more", 13, UiStyle.INK_MUTED, 700)
	_save_hint.name = "ScrollHint"
	_save_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_save_hint.visible = false
	head_row.add_child(_save_hint)

	_save_status_scroll = ScrollContainer.new()
	_save_status_scroll.name = "SaveStatusScroll"
	_save_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_save_status_scroll.custom_minimum_size = Vector2(SAVE_STATUS_WIDTH, 0)
	save_column.add_child(_save_status_scroll)
	_save_status = UiStyle.label("", 20, UiStyle.BAD, 800)
	_save_status.name = "SaveStatus"
	_save_status.custom_minimum_size = Vector2(SAVE_STATUS_WIDTH - 20.0, 0)
	_save_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_status.resized.connect(_sync_save_status_height)
	_save_status_scroll.add_child(_save_status)

	_acknowledge = UiStyle.primary_action("Enter", "")
	_acknowledge.name = "Acknowledge"
	_acknowledge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.add_child(_acknowledge)
	_action_text = _acknowledge.find_child("Text", true, false) as Label

func _lock_header() -> VBoxContainer:
	var header := UiStyle.vbox(2)
	header.name = "DayHeader"
	var day_row := UiStyle.hbox(8)
	day_row.name = "DayRow"
	day_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(day_row)
	_day_line = UiStyle.shadowed_label("", 22, 800)
	_day_line.name = "DayLine"
	day_row.add_child(_day_line)
	_weather_tail = UiStyle.shadowed_label("", 22, 800)
	_weather_tail.name = "WeatherTail"
	day_row.add_child(_weather_tail)
	var clock := UiStyle.shadowed_label(
		GameRules.format_time(GameRules.DAY_START_MINUTES), 84, 900
	)
	clock.name = "LockTime"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(clock)
	return header

func _notification_card(
	card_name: String, tile_fill: Color, icon: Texture2D
) -> Dictionary:
	var card := PanelContainer.new()
	card.name = "%sCard" % card_name
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 22, [14, 6, 14, 6])
	)
	var row := UiStyle.hbox(12)
	card.add_child(row)
	var tile := PanelContainer.new()
	tile.name = "Tile"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(44, 44)
	var tile_box := UiStyle.card(tile_fill, 12, [0, 0, 0, 0], false)
	tile.add_theme_stylebox_override("panel", tile_box)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tile)
	var tile_icon := UiStyle.icon(icon, 32)
	tile_icon.name = "Icon"
	tile.add_child(tile_icon)
	var lines := UiStyle.vbox(0)
	lines.name = "Lines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lines)
	var head_row := UiStyle.hbox(6)
	head_row.name = "HeadRow"
	lines.add_child(head_row)
	var header := UiStyle.label(card_name.to_upper(), 13, UiStyle.INK_MUTED, 900)
	header.name = "Header"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(header)
	var stamp := UiStyle.label(
		GameRules.format_time(GameRules.DAY_START_MINUTES),
		12,
		UiStyle.INK_MUTED,
		700
	)
	stamp.name = "Stamp"
	head_row.add_child(stamp)
	var headline := UiStyle.label("", 18, UiStyle.INK, 800)
	headline.name = "Headline"
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(headline)
	return {
		"card": card,
		"tile_box": tile_box,
		"tile_icon": tile_icon,
		"lines": lines,
		"header": header,
		"stamp": stamp,
		"headline": headline,
	}

func _card_sub(text_value: String) -> Label:
	var result := UiStyle.label(text_value, 16, UiStyle.INK_MUTED, 600)
	result.name = "Sub"
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func _shipment_row(row_name: String, icon_size: int, name_size: int, amount_size: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.SOFT, 12, [8, 4, 8, 4], false)
	row.add_theme_stylebox_override("panel", box)
	var hbox := UiStyle.hbox(8)
	hbox.name = "Row"
	row.add_child(hbox)
	var icon := UiStyle.icon(null, icon_size)
	icon.name = "Icon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)
	var item_name := UiStyle.label("", name_size, UiStyle.INK, 700)
	item_name.name = "Name"
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(item_name)
	var amount := UiStyle.label("", amount_size, UiStyle.LEAF_DEEP, 800)
	amount.name = "Amount"
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(amount)
	return row

func _row_children(row: PanelContainer) -> Dictionary:
	return {
		"row": row,
		"icon": row.get_node("Row/Icon") as TextureRect,
		"name": row.get_node("Row/Name") as Label,
		"amount": row.get_node("Row/Amount") as Label,
	}
