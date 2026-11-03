class_name MorningSummaryPanel
extends Control

signal acknowledged

const SUN_ICON := preload("res://assets/ui/icons/sun.png")
const RAIN_ICON := preload("res://assets/ui/icons/rain.png")
const STAMINA_ICON := preload("res://assets/ui/icons/stamina.png")
const MONEY_ICON := preload("res://assets/ui/icons/money-bag.png")
const SAVE_ICON := preload("res://assets/ui/icons/save.png")
const GROWTH_ICON := preload("res://assets/ui/icons/growth.png")
const COIN_STACK_ICON := preload("res://assets/ui/icons/coin-stack.png")
const FACT_ICONS: Array[Texture2D] = [GROWTH_ICON, SUN_ICON, STAMINA_ICON, COIN_STACK_ICON]
const FACT_COLORS: Array[Color] = [
	UiStyle.LEAF_DEEP, UiStyle.ACCENT_2, UiStyle.LEAF, UiStyle.ORANGE,
]

var _frame: PhoneFrame
var _day_line: Label
var _save_badge: PanelContainer
var _save_caption: Label
var _weather_icon: TextureRect
var _card_values: Array[Label] = []
var _card_captions: Array[Label] = []
var _withered: Label
var _shipment_single: PanelContainer
var _single_row: Dictionary
var _shipment_compact: VBoxContainer
var _compact_rows: Array[Dictionary] = []
var _shipment_empty: Label
var _money: Label
var _action_text: Label
var _save_status: Label
var _acknowledge: Button
var _badge_ok := UiStyle.card(UiStyle.MINT, UiStyle.PILL_RADIUS, [10, 4, 12, 4], false)
var _badge_error := UiStyle.card(UiStyle.BAD_SOFT, UiStyle.PILL_RADIUS, [10, 4, 12, 4], false)

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

	var crops_advanced := int(summary.get("crops_advanced", 0))
	_card_values[0].text = "+%d" % crops_advanced
	_card_captions[0].text = "CROPS GREW"

	var weather := StringName(summary.get("next_weather", &"sunny"))
	var rainy := weather == GameRules.weather_key(GameRules.Weather.RAINY)
	_card_values[1].text = "RAINY" if rainy else "SUNNY"
	_card_captions[1].text = (
		"TODAY — NO\nWATERING NEEDED" if rainy else "TODAY —\nWATER AS USUAL"
	)
	_weather_icon.texture = RAIN_ICON if rainy else SUN_ICON

	var stamina := int(summary.get("stamina_restored", 0))
	_card_values[2].text = "%d" % stamina
	_card_captions[2].text = "STAMINA FULL" if stamina > 0 else "STAMINA"

	var income := int(summary.get("shipping_income", 0))
	_card_values[3].text = "+%d" % income
	_card_captions[3].text = "SHIPPED"

	var crops_withered := int(summary.get("crops_withered", 0))
	_withered.visible = crops_withered > 0
	if _withered.visible:
		_withered.text = (
			tr("%d CROP WITHERED") if crops_withered == 1 else tr("%d CROPS WITHERED")
		) % crops_withered

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
	var action := tr("START DAY %d") % next_day
	_action_text.text = action
	_acknowledge.text = action
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
			_save_badge.visible = false
		&"saved":
			_save_status.text = "Saved."
			_save_status.add_theme_color_override("font_color", UiStyle.LEAF_DEEP)
			_save_caption.text = "SAVED"
			_save_caption.add_theme_color_override("font_color", UiStyle.LEAF_DEEP)
			_save_badge.add_theme_stylebox_override("panel", _badge_ok)
			_save_badge.visible = true
		&"error":
			_save_status.text = message
			_save_status.add_theme_color_override("font_color", UiStyle.BAD)
			_save_caption.text = "SAVE ERROR"
			_save_caption.add_theme_color_override("font_color", UiStyle.BAD)
			_save_badge.add_theme_stylebox_override("panel", _badge_error)
			_save_badge.visible = true
		_:
			assert(false, "unknown save status")

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
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(UiStyle.INK, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_frame = PhoneFrame.new()
	center.add_child(_frame)

	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 18], ["top", 14], ["right", 18], ["bottom", 12]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(10)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_lock_header())
	column.add_child(_facts_grid())
	column.add_child(_bin_card())
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_footer())

	_save_status = UiStyle.label("", 15, UiStyle.LEAF_DEEP, 800)
	_save_status.name = "SaveStatus"
	_save_status.anchor_left = 0.5
	_save_status.anchor_right = 0.5
	_save_status.offset_top = 34.0
	_save_status.offset_bottom = 60.0
	_save_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_save_status)

	_acknowledge = UiStyle.action_button("")
	_acknowledge.name = "Acknowledge"
	_acknowledge.anchor_left = 0.5
	_acknowledge.anchor_right = 0.5
	_acknowledge.anchor_top = 1.0
	_acknowledge.anchor_bottom = 1.0
	_acknowledge.offset_left = -130.0
	_acknowledge.offset_right = 130.0
	_acknowledge.offset_top = -68.0
	_acknowledge.offset_bottom = -14.0
	_acknowledge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_acknowledge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_acknowledge)

func _lock_header() -> VBoxContainer:
	var header := UiStyle.vbox(4)
	header.name = "LockHeader"
	var clock := UiStyle.label(
		GameRules.format_time(GameRules.DAY_START_MINUTES), 64, UiStyle.NIGHT, 900
	)
	clock.name = "Clock"
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(clock)
	_day_line = UiStyle.label("", 16, UiStyle.INK_MUTED, 700)
	_day_line.name = "DayLine"
	_day_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_day_line)
	_save_badge = PanelContainer.new()
	_save_badge.name = "SaveBadge"
	_save_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save_badge.visible = false
	_save_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_badge_ok.border_color = UiStyle.LEAF
	_badge_ok.set_border_width_all(2)
	_badge_error.border_color = UiStyle.BAD
	_badge_error.set_border_width_all(2)
	_save_badge.add_theme_stylebox_override("panel", _badge_ok)
	header.add_child(_save_badge)
	var badge_row := UiStyle.hbox(6)
	badge_row.name = "Row"
	_save_badge.add_child(badge_row)
	badge_row.add_child(UiStyle.icon(SAVE_ICON, 16))
	_save_caption = UiStyle.label("SAVED", 13, UiStyle.LEAF_DEEP, 800)
	_save_caption.name = "Caption"
	badge_row.add_child(_save_caption)
	return header

func _facts_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "FactsGrid"
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for index in FACT_ICONS.size():
		grid.add_child(_fact_card(index))
	return grid

func _fact_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Fact_%d" % index
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiStyle.card(UiStyle.HUD_CARD, 16, [12, 10, 12, 10], false)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", box)
	var row := UiStyle.hbox(10)
	card.add_child(row)
	var icon := UiStyle.icon(FACT_ICONS[index], 30)
	icon.name = "Icon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	if index == 1:
		_weather_icon = icon
	var pair := UiStyle.vbox(2)
	pair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pair)
	var value := UiStyle.label("", 20, FACT_COLORS[index], 900)
	value.name = "Value"
	_card_values.append(value)
	pair.add_child(value)
	var caption := UiStyle.label("", 11, UiStyle.INK_MUTED, 700)
	caption.name = "Caption"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_captions.append(caption)
	pair.add_child(caption)
	return card

func _bin_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "BinCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.HUD_CARD, 18, [14, 10, 14, 12], false)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(8)
	card.add_child(column)

	var title_row := UiStyle.hbox(8)
	title_row.name = "TitleRow"
	column.add_child(title_row)
	var title := UiStyle.label("THE BIN PAID OUT", 13, UiStyle.INK_MUTED, 800)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_withered = UiStyle.label("", 13, UiStyle.BAD, 800)
	_withered.name = "WitheredWarning"
	_withered.visible = false
	_withered.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(_withered)

	var shipments := UiStyle.vbox(6)
	shipments.name = "Shipments"
	column.add_child(shipments)
	_shipment_single = _shipment_row("ShipmentRow", 28, 15, 15)
	_shipment_single.visible = false
	shipments.add_child(_shipment_single)
	_single_row = _row_children(_shipment_single)
	_shipment_compact = UiStyle.vbox(4)
	_shipment_compact.name = "CompactShipmentRows"
	_shipment_compact.visible = false
	shipments.add_child(_shipment_compact)
	for index in 3:
		var row := _shipment_row("Row_%d" % index, 20, 13, 13)
		row.visible = false
		_shipment_compact.add_child(row)
		_compact_rows.append(_row_children(row))
	_shipment_empty = UiStyle.label("No crops shipped.", 14, UiStyle.INK_MUTED, 500)
	_shipment_empty.name = "EmptyShipment"
	_shipment_empty.visible = false
	shipments.add_child(_shipment_empty)

	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = UiStyle.LINE
	divider.custom_minimum_size = Vector2(0, 1)
	column.add_child(divider)

	var money_row := UiStyle.hbox(10)
	money_row.name = "MoneyRow"
	column.add_child(money_row)
	var coin := UiStyle.icon(MONEY_ICON, 24)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_row.add_child(coin)
	var caption := UiStyle.label("Money after shipping", 15, UiStyle.INK, 700)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_row.add_child(caption)
	_money = UiStyle.label("", 22, UiStyle.ORANGE, 900)
	_money.name = "Amount"
	money_row.add_child(_money)
	return card

func _shipment_row(row_name: String, icon_size: int, name_size: int, amount_size: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.SOFT, 12, [10, 5, 10, 5], false)
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

func _footer() -> HBoxContainer:
	var footer := UiStyle.hbox(8)
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(UiStyle.keycap("Enter", true))
	_action_text = UiStyle.label("", 14, UiStyle.INK_MUTED, 700)
	_action_text.name = "ActionText"
	_action_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_action_text)
	return footer
