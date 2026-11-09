class_name ShopPanel
extends Control

signal buy_requested(kind: int, quantity: int)
signal upgrade_requested
signal close_requested

const UPGRADE_ROW := 3
const DIMMED := Color(1.0, 1.0, 1.0, 0.45)

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
var _sub: Label
var _money: Label
var _action: Label
var _action_button: Button
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
	if index == UPGRADE_ROW:
		return "%d" % GameRules.WATERING_CAN_UPGRADE_PRICE
	return "%d" % GameRules.seed_price(index)

func money_text() -> String:
	return _money.text.trim_suffix("G")

func stepper_button(row_index: int, part: StringName) -> Button:
	return _rows[row_index][part] as Button

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
		var owner := get_viewport().gui_get_focus_owner()
		if owner != null and is_ancestor_of(owner):
			return
		_buy()
	else:
		return
	get_viewport().set_input_as_handled()

func _select_row(delta: int) -> void:
	_choose_row(posmod(_selected_row + delta, UPGRADE_ROW + 1))

func _choose_row(index: int) -> void:
	_selected_row = index
	if _selected_row != UPGRADE_ROW:
		_selected_kind = _selected_row
	_quantity = _clamped_quantity(_quantity)
	_update_rows()

func _row_gui_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_choose_row(index)

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
	if _quantity <= 0:
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
	card.custom_minimum_size = Vector2(1040, 0)
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 30, [0, 0, 0, 0])
	)
	center.add_child(card)
	var column := UiStyle.vbox(0)
	column.name = "Column"
	card.add_child(column)
	column.add_child(_header())
	var body := MarginContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 32], ["top", 20], ["right", 32], ["bottom", 24]]:
		body.add_theme_constant_override("margin_" + side[0], side[1])
	column.add_child(body)
	var rows := UiStyle.vbox(10)
	rows.name = "Rows"
	body.add_child(rows)
	for index in range(UPGRADE_ROW + 1):
		rows.add_child(_row(index))
	column.add_child(_footer())

func _header() -> PanelContainer:
	var band := UiStyle.gradient_band(UiStyle.HEADER_GRADIENT, 30, [32, 24, 32, 22])
	band.name = "HeaderBand"
	var row := UiStyle.hbox(16)
	row.name = "Row"
	band.add_child(row)
	var icon_chip := PanelContainer.new()
	icon_chip.name = "IconChip"
	icon_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_chip.custom_minimum_size = Vector2(64, 64)
	icon_chip.add_theme_stylebox_override(
		"panel", UiStyle.card(Color(1.0, 1.0, 1.0, 0.22), 18, [0, 0, 0, 0], false)
	)
	icon_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_chip)
	icon_chip.add_child(UiStyle.icon(SEEDS_ICON, 48))
	var titles := UiStyle.vbox(2)
	titles.name = "Titles"
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(titles)
	var title := UiStyle.label("SEED SHOP", 34, UiStyle.CARD, 900)
	title.name = "Title"
	titles.add_child(title)
	_sub = UiStyle.label("Seeds and tools", 16, Color(1.0, 1.0, 1.0, 0.85), 700)
	_sub.name = "Sub"
	titles.add_child(_sub)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var money_chip := PanelContainer.new()
	money_chip.name = "Money"
	money_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_chip.add_theme_stylebox_override(
		"panel",
		UiStyle.card(
			Color(1.0, 1.0, 1.0, 0.2), UiStyle.PILL_RADIUS, [8, 7, 18, 7], false
		)
	)
	money_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(money_chip)
	var money_row := UiStyle.hbox(8)
	money_chip.add_child(money_row)
	var coin := UiStyle.icon(COIN_ICON, 32)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_row.add_child(coin)
	_money = UiStyle.label("0G", 28, UiStyle.CARD, 900)
	_money.name = "Value"
	money_row.add_child(_money)
	return band

func _row(index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Row_%d" % index
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(_row_gui_input.bind(index))
	var box := UiStyle.card(UiStyle.SOFT, 20, [12, 12, 22, 12], false)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	_row_boxes.append(box)
	row.add_theme_stylebox_override("panel", box)
	var line := UiStyle.hbox(20)
	line.name = "Line"
	row.add_child(line)

	var tile := PanelContainer.new()
	tile.name = "Tile"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(76, 76)
	tile.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 14, [0, 0, 0, 0], false)
	)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(tile)
	var icon := UiStyle.icon(null, 64)
	icon.name = "Icon"
	tile.add_child(icon)

	var info := UiStyle.vbox(4)
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(info)
	var row_name := UiStyle.label("", 26, UiStyle.INK, 900)
	row_name.name = "Name"
	info.add_child(row_name)
	var sub := UiStyle.label("", 17, UiStyle.INK_MUTED, 700)
	sub.name = "Sub"
	info.add_child(sub)

	var stepper := UiStyle.hbox(8)
	stepper.name = "Stepper"
	stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(stepper)
	var minus := UiStyle.stepper_button("−")
	minus.name = "Minus"
	stepper.add_child(minus)
	var quantity_pill := PanelContainer.new()
	quantity_pill.name = "Quantity"
	quantity_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quantity_pill.custom_minimum_size = Vector2(90, 0)
	var quantity_box := UiStyle.card(UiStyle.CARD, 12, [10, 4, 10, 4], false)
	quantity_box.border_color = UiStyle.ACCENT
	quantity_box.set_border_width_all(2)
	quantity_pill.add_theme_stylebox_override("panel", quantity_box)
	quantity_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stepper.add_child(quantity_pill)
	var quantity := UiStyle.label("×0", 26, UiStyle.ACCENT_DEEP, 900)
	quantity.name = "Value"
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_pill.add_child(quantity)
	var plus := UiStyle.stepper_button("+")
	plus.name = "Plus"
	stepper.add_child(plus)
	var max_chip := UiStyle.max_button("max")
	stepper.add_child(max_chip)
	minus.pressed.connect(_adjust_quantity.bind(-1))
	plus.pressed.connect(_adjust_quantity.bind(1))
	max_chip.pressed.connect(_select_max)

	var need := PanelContainer.new()
	need.name = "NeedChip"
	need.mouse_filter = Control.MOUSE_FILTER_IGNORE
	need.visible = false
	need.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	need.add_theme_stylebox_override(
		"panel",
		UiStyle.card(UiStyle.BAD_SOFT, UiStyle.PILL_RADIUS, [12, 5, 12, 5], false)
	)
	line.add_child(need)
	var need_text := UiStyle.label("", 15, UiStyle.BAD, 800)
	need_text.name = "Text"
	need.add_child(need_text)

	var meta := UiStyle.vbox(2)
	meta.name = "Meta"
	meta.custom_minimum_size = Vector2(150, 0)
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(meta)
	var meta_caption := UiStyle.label("", 13, UiStyle.INK_MUTED, 900)
	meta_caption.name = "Caption"
	meta_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(meta_caption)
	var meta_value := UiStyle.label("", 30, UiStyle.INK, 900)
	meta_value.name = "Value"
	meta_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_child(meta_value)

	_rows.append({
		"panel": row,
		"icon": icon,
		"name": row_name,
		"sub": sub,
		"stepper": stepper,
		"quantity": quantity,
		"minus": minus,
		"plus": plus,
		"max": max_chip,
		"need": need,
		"need_text": need_text,
		"meta_caption": meta_caption,
		"meta_value": meta_value,
	})
	return row

func _footer() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = "FooterBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_box := UiStyle.card(
		Color(1.0, 1.0, 1.0, 0.0), 0, [32, 16, 32, 16], false
	)
	bar_box.border_color = UiStyle.LINE
	bar_box.border_width_top = 2
	bar.add_theme_stylebox_override("panel", bar_box)
	var footer := UiStyle.commerce_footer()
	bar.add_child(footer)
	(footer.get_node("CloseButton") as Button).pressed.connect(
		func() -> void: close_requested.emit()
	)
	_action_button = footer.get_node("Action") as Button
	_action_button.pressed.connect(_buy)
	_action = footer.get_node("Action/Pill/Row/Text") as Label
	return bar

func _update_rows() -> void:
	var money := int(_snapshot.get("money", 0))
	_sub.text = tr("Seeds and tools")
	_money.text = "%dG" % money
	if _selected_row != UPGRADE_ROW:
		_action.text = tr("Buy %d · %dG") % [
			_quantity, GameRules.seed_price(_selected_kind) * _quantity,
		]
	var seeds: Dictionary = _snapshot.get("seeds", {})
	for kind in range(GameRules.CropKind.size()):
		var row := _rows[kind]
		var selected := kind == _selected_row
		var held := int(seeds.get(GameRules.crop_key(kind), 0))
		var price := GameRules.seed_price(kind)
		(row["name"] as Label).text = GameRules.crop_display_name(kind)
		(row["sub"] as Label).text = tr("%dG each · %d nights · %d held") % [
			price, GameRules.growth_nights(kind), held,
		]
		(row["quantity"] as Label).text = "×%d" % _quantity
		(row["meta_caption"] as Label).text = "TOTAL" if selected else "EACH"
		(row["meta_value"] as Label).text = (
			"%dG" % (price * _quantity) if selected else "%dG" % price
		)
		(row["icon"] as TextureRect).texture = SEED_PACKETS[kind]
		(row["stepper"] as Control).visible = selected
		(row["need"] as Control).visible = false
		var max_qty := _max_quantity(kind)
		(row["minus"] as Button).disabled = _quantity <= 0
		(row["plus"] as Button).disabled = _quantity >= max_qty
		(row["max"] as Button).disabled = _quantity >= max_qty
		(row["panel"] as Control).modulate = (
			Color.WHITE if max_qty > 0 else DIMMED
		)
		_style_row(kind, selected)
	_update_upgrade_row()
	var owned := bool(_snapshot.get("watering_can_upgraded", false))
	_action_button.disabled = (
		(_selected_row != UPGRADE_ROW and _quantity <= 0)
		or (_selected_row == UPGRADE_ROW and owned)
	)
	_action_button.modulate = DIMMED if _action_button.disabled else Color.WHITE

func _style_row(index: int, selected: bool) -> void:
	var row_box := _row_boxes[index]
	row_box.bg_color = UiStyle.ACCENT_SOFT if selected else UiStyle.SOFT
	row_box.border_color = UiStyle.ACCENT if selected else UiStyle.LINE
	row_box.set_border_width_all(3 if selected else 1)
	row_box.shadow_color = (
		Color(UiStyle.ACCENT, 0.38) if selected else Color(0, 0, 0, 0)
	)
	row_box.shadow_size = 10 if selected else 0
	row_box.shadow_offset = Vector2(0, 6) if selected else Vector2.ZERO
	var row := _rows[index]
	(row["name"] as Label).add_theme_color_override(
		"font_color", UiStyle.ACCENT_DEEP if selected else UiStyle.INK
	)

func _update_upgrade_row() -> void:
	var row := _rows[UPGRADE_ROW]
	var selected := _selected_row == UPGRADE_ROW
	var owned := bool(_snapshot.get("watering_can_upgraded", false))
	var price := GameRules.WATERING_CAN_UPGRADE_PRICE
	var unaffordable := not owned and int(_snapshot.get("money", 0)) < price
	(row["name"] as Label).text = "Efficient Can"
	(row["sub"] as Label).text = (
		tr("Watering costs %d stamina instead of %d. One-time.") % [
			int(GameRules.effective_action_cost(
				GameRules.FarmingAction.WATERING_CAN, true
			)["stamina"]),
			int(GameRules.effective_action_cost(
				GameRules.FarmingAction.WATERING_CAN, false
			)["stamina"]),
		]
	)
	(row["icon"] as TextureRect).texture = CAN_ICON
	(row["stepper"] as Control).visible = false
	(row["need"] as Control).visible = unaffordable
	(row["need_text"] as Label).text = tr("Need %dG") % price
	(row["meta_caption"] as Label).text = "" if owned else "PRICE"
	(row["meta_value"] as Label).text = tr("OWNED") if owned else "%dG" % price
	(row["panel"] as Control).modulate = DIMMED if unaffordable else Color.WHITE
	_style_row(UPGRADE_ROW, selected)
	if selected:
		_action.text = "OWNED" if owned else tr("Buy %d · %dG") % [1, price]
