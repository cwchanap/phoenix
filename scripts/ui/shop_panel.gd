class_name ShopPanel
extends Control

signal buy_requested(kind: int, quantity: int)
signal upgrade_requested

const UPGRADE_ROW := 3

const SEEDS_ICON := preload("res://assets/ui/icons/seeds.png")
const COIN_ICON := preload("res://assets/ui/icons/coin.png")
const CAN_ICON := preload("res://assets/ui/icons/watering-can-efficient.png")
const SEED_PACKETS: Array[Texture2D] = [
	preload("res://assets/ui/crops/seed-packet-turnip.png"),
	preload("res://assets/ui/crops/seed-packet-potato.png"),
	preload("res://assets/ui/crops/seed-packet-pumpkin.png"),
]

var _snapshot: Dictionary = {}
var _selected_row := 0
var _selected_kind := GameRules.CropKind.TURNIP
var _quantity := 1
var _money: Label
var _action: Label
var _rows: Array[Dictionary] = []
var _row_boxes: Array[StyleBoxFlat] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_update_rows()

func open_panel(snapshot: Dictionary) -> void:
	_selected_row = 0
	_selected_kind = GameRules.CropKind.TURNIP
	_quantity = 1
	present(snapshot)
	visible = true

func present(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_quantity = _clamped_quantity(_quantity)
	_update_rows()

func selected_kind() -> int:
	return _selected_kind

func selected_row() -> int:
	return _selected_row

func selected_quantity() -> int:
	return _quantity

func selected_action_text() -> String:
	return _action.text

func display_price_for_row(index: int) -> String:
	return (_rows[index]["price"] as Label).text

func money_text() -> String:
	return _money.text

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_up"):
		_select_row(-1)
	elif event.is_action_pressed("move_down"):
		_select_row(1)
	elif event.is_action_pressed("move_left"):
		_adjust_quantity(-1)
	elif event.is_action_pressed("move_right"):
		_adjust_quantity(1)
	elif event.is_action_pressed("panel_max"):
		_select_max()
	elif event.is_action_pressed("ui_accept"):
		_buy()
	else:
		return
	get_viewport().set_input_as_handled()

func _select_row(delta: int) -> void:
	_selected_row = posmod(_selected_row + delta, UPGRADE_ROW + 1)
	if _selected_row != UPGRADE_ROW:
		_selected_kind = _selected_row
	_quantity = _clamped_quantity(_quantity)
	_update_rows()

func _adjust_quantity(delta: int) -> void:
	if _selected_row == UPGRADE_ROW:
		return
	_quantity = clampi(_quantity + delta, 0, _max_quantity(_selected_kind))
	_update_rows()

func _select_max() -> void:
	if _selected_row == UPGRADE_ROW:
		return
	_quantity = _max_quantity(_selected_kind)
	_update_rows()

func _buy() -> void:
	if _selected_row == UPGRADE_ROW:
		if not bool(_snapshot.get("watering_can_upgraded", false)):
			upgrade_requested.emit()
		return
	buy_requested.emit(_selected_kind, _quantity)

func _clamped_quantity(quantity: int) -> int:
	return clampi(quantity, 0, _max_quantity(_selected_kind))

func _max_quantity(kind: int) -> int:
	return int(_snapshot.get("money", 0)) / GameRules.seed_price(kind)

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
	var card := PanelContainer.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(960, 0)
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 26, [24, 18, 24, 18])
	)
	center.add_child(card)
	var column := UiStyle.vbox(14)
	column.name = "Column"
	card.add_child(column)
	column.add_child(_header())
	var rows := UiStyle.vbox(10)
	rows.name = "Rows"
	column.add_child(rows)
	for index in range(UPGRADE_ROW + 1):
		rows.add_child(_row(index))
	column.add_child(_footer())

func _header() -> HBoxContainer:
	var header := UiStyle.hbox(12)
	header.name = "Header"
	var icon_chip := PanelContainer.new()
	icon_chip.name = "IconChip"
	icon_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_chip.custom_minimum_size = Vector2(44, 44)
	icon_chip.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 13, [7, 7, 7, 7], false)
	)
	icon_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(icon_chip)
	icon_chip.add_child(UiStyle.icon(SEEDS_ICON, 30))
	var title := UiStyle.label("SEED SHOP", 28, UiStyle.INK, 900)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var money_chip := PanelContainer.new()
	money_chip.name = "Money"
	money_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_chip.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.WARN, UiStyle.PILL_RADIUS, [12, 7, 16, 7], false)
	)
	money_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(money_chip)
	var money_row := UiStyle.hbox(8)
	money_chip.add_child(money_row)
	money_row.add_child(UiStyle.icon(COIN_ICON, 24))
	_money = UiStyle.label("0", 24, UiStyle.WARN_INK, 900)
	_money.name = "Value"
	money_row.add_child(_money)
	return header

func _row(index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Row_%d" % index
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.CARD, 16, [12, 10, 12, 10], false)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	_row_boxes.append(box)
	row.add_theme_stylebox_override("panel", box)
	var line := UiStyle.hbox(14)
	row.add_child(line)

	var tile := Panel.new()
	tile.name = "Tile"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(68, 68)
	tile.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.SOFT, 14, [0, 0, 0, 0], false)
	)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(tile)
	var icon := UiStyle.icon(null, 48)
	icon.name = "Icon"
	icon.position = Vector2(10, 10)
	icon.size = Vector2(48, 48)
	tile.add_child(icon)

	var info := UiStyle.vbox(4)
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(info)
	var row_name := UiStyle.label("", 22, UiStyle.INK, 800)
	row_name.name = "Name"
	info.add_child(row_name)
	var price_row := UiStyle.hbox(8)
	price_row.name = "PriceRow"
	info.add_child(price_row)
	var coin := UiStyle.icon(COIN_ICON, 18)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_row.add_child(coin)
	var price := UiStyle.label("0", 18, UiStyle.INK_MUTED, 800)
	price.name = "Price"
	price_row.add_child(price)
	var note := UiStyle.label("", 15, UiStyle.INK_MUTED, 600)
	note.name = "Note"
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_row.add_child(note)

	var stepper := UiStyle.hbox(6)
	stepper.name = "Stepper"
	stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(stepper)
	var minus := _stepper_button("−")
	minus.name = "Minus"
	stepper.add_child(minus)
	var quantity_pill := PanelContainer.new()
	quantity_pill.name = "Quantity"
	quantity_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_pill.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.NIGHT, UiStyle.PILL_RADIUS, [14, 6, 14, 6], false)
	)
	quantity_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stepper.add_child(quantity_pill)
	var quantity := UiStyle.label("×0", 20, UiStyle.CARD, 900)
	quantity.name = "Value"
	quantity_pill.add_child(quantity)
	var plus := _stepper_button("+")
	plus.name = "Plus"
	stepper.add_child(plus)
	var max_chip := _stepper_chip("M", "max")
	max_chip.name = "Max"
	stepper.add_child(max_chip)
	minus.pressed.connect(_adjust_quantity.bind(-1))
	plus.pressed.connect(_adjust_quantity.bind(1))
	max_chip.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_select_max()
	)

	var meta := UiStyle.vbox(2)
	meta.name = "Meta"
	meta.custom_minimum_size = Vector2(130, 0)
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(meta)
	var meta_caption := UiStyle.label("", 12, UiStyle.INK_MUTED, 800)
	meta_caption.name = "Caption"
	meta_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(meta_caption)
	var meta_value := UiStyle.label("", 24, UiStyle.INK, 900)
	meta_value.name = "Value"
	meta_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(meta_value)

	_rows.append({
		"panel": row,
		"icon": icon,
		"name": row_name,
		"price": price,
		"note": note,
		"stepper": stepper,
		"quantity": quantity,
		"meta_caption": meta_caption,
		"meta_value": meta_value,
	})
	return row

func _stepper_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(42, 42)
	button.focus_mode = Control.FOCUS_NONE
	UiStyle.text(button, 22, UiStyle.INK, 800)
	button.add_theme_stylebox_override(
		"normal",
		UiStyle.outlined(UiStyle.card(UiStyle.CARD, 10, [0, 0, 0, 0], false), UiStyle.LINE, 1),
	)
	button.add_theme_stylebox_override(
		"hover",
		UiStyle.outlined(UiStyle.card(UiStyle.ACCENT_SOFT, 10, [0, 0, 0, 0], false), UiStyle.ACCENT, 1),
	)
	button.add_theme_stylebox_override(
		"pressed",
		UiStyle.outlined(UiStyle.card(UiStyle.ACCENT_SOFT, 10, [0, 0, 0, 0], false), UiStyle.ACCENT, 2),
	)
	button.add_theme_stylebox_override(
		"focus",
		UiStyle.outlined(UiStyle.card(UiStyle.CARD, 10, [0, 0, 0, 0], false), UiStyle.ACCENT, 2),
	)
	button.add_theme_stylebox_override(
		"disabled",
		UiStyle.outlined(UiStyle.card(UiStyle.SOFT, 10, [0, 0, 0, 0], false), UiStyle.LINE, 1),
	)
	button.add_theme_color_override("font_disabled_color", UiStyle.INK_MUTED)
	return button

func _stepper_chip(key: String, caption_text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_stylebox_override(
		"panel",
		UiStyle.outlined(UiStyle.card(UiStyle.CARD, 10, [8, 5, 10, 5], false), UiStyle.LINE, 1),
	)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UiStyle.hbox(6)
	chip.add_child(row)
	row.add_child(UiStyle.keycap(key, true))
	var caption := UiStyle.label(caption_text, 14, UiStyle.INK_MUTED, 800)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	return chip

func _footer() -> HBoxContainer:
	var footer := UiStyle.hbox(10)
	footer.name = "Footer"
	var caps := UiStyle.hbox(4)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["W", "S"]:
		caps.add_child(UiStyle.keycap(key, true))
	footer.add_child(caps)
	var choose := UiStyle.label("choose crop", 15, UiStyle.INK_MUTED, 700)
	choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(choose)
	var adjust_caps := UiStyle.hbox(4)
	adjust_caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["A", "D"]:
		adjust_caps.add_child(UiStyle.keycap(key, true))
	footer.add_child(adjust_caps)
	var quantity_hint := UiStyle.label("quantity", 15, UiStyle.INK_MUTED, 700)
	quantity_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(quantity_hint)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var escape := UiStyle.keycap("Esc", true)
	escape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(escape)
	var leave := UiStyle.label("leave", 15, UiStyle.INK_MUTED, 700)
	leave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(leave)
	var enter := UiStyle.keycap("Enter", true)
	enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(enter)
	var pill := UiStyle.gradient_surface(UiStyle.ACCENT_GRADIENT, UiStyle.PILL_RADIUS, [18, 8, 18, 8])
	pill.name = "Action"
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(pill)
	_action = UiStyle.label("", 18, UiStyle.CARD, 900)
	_action.name = "Text"
	pill.add_child(_action)
	return footer

func _update_rows() -> void:
	var money := int(_snapshot.get("money", 0))
	_money.text = "%d" % money
	if _selected_row != UPGRADE_ROW:
		_action.text = tr("BUY · %dG") % (
			GameRules.seed_price(_selected_kind) * _quantity
		)
	var seeds: Dictionary = _snapshot.get("seeds", {})
	for kind in range(GameRules.CropKind.size()):
		var row := _rows[kind]
		var selected := kind == _selected_row
		var held := int(seeds.get(GameRules.crop_key(kind), 0))
		(row["name"] as Label).text = GameRules.crop_display_name(kind)
		(row["price"] as Label).text = "%d" % GameRules.seed_price(kind)
		(row["note"] as Label).text = "each"
		(row["quantity"] as Label).text = "×%d" % _quantity
		(row["meta_caption"] as Label).text = "TOTAL" if selected else "STOCK"
		(row["meta_value"] as Label).text = (
			"%d" % (GameRules.seed_price(kind) * _quantity)
			if selected
			else tr("%d held") % held
		)
		(row["icon"] as TextureRect).texture = SEED_PACKETS[kind]
		(row["stepper"] as Control).visible = selected
		_style_row(kind, selected)
	_update_upgrade_row()

func _style_row(index: int, selected: bool) -> void:
	var row_box := _row_boxes[index]
	row_box.bg_color = UiStyle.ACCENT_SOFT if selected else UiStyle.CARD
	row_box.border_color = UiStyle.ACCENT if selected else UiStyle.LINE
	row_box.set_border_width_all(2 if selected else 1)
	var row := _rows[index]
	(row["name"] as Label).add_theme_color_override(
		"font_color", UiStyle.ACCENT_DEEP if selected else UiStyle.INK
	)
	(row["price"] as Label).add_theme_color_override(
		"font_color", UiStyle.INK if selected else UiStyle.INK_MUTED
	)
	(row["meta_value"] as Label).add_theme_color_override(
		"font_color", UiStyle.LEAF_DEEP if selected else UiStyle.INK
	)

func _update_upgrade_row() -> void:
	var row := _rows[UPGRADE_ROW]
	var selected := _selected_row == UPGRADE_ROW
	var owned := bool(_snapshot.get("watering_can_upgraded", false))
	(row["name"] as Label).text = "Efficient Can"
	(row["price"] as Label).text = "%d" % GameRules.WATERING_CAN_UPGRADE_PRICE
	(row["note"] as Label).text = tr("Water %d→%d STA") % [
		int(GameRules.effective_action_cost(GameRules.FarmingAction.WATERING_CAN, false)["stamina"]),
		int(GameRules.effective_action_cost(GameRules.FarmingAction.WATERING_CAN, true)["stamina"]),
	]
	(row["icon"] as TextureRect).texture = CAN_ICON
	(row["stepper"] as Control).visible = false
	(row["meta_caption"] as Label).text = ""
	(row["meta_value"] as Label).text = tr("OWNED") if owned else ""
	_style_row(UPGRADE_ROW, selected)
	if selected:
		_action.text = (
			"OWNED" if owned
			else tr("BUY · %dG") % GameRules.WATERING_CAN_UPGRADE_PRICE
		)
