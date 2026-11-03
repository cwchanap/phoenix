class_name ShippingPanel
extends Control

signal deposit_requested(kind: int, quantity: int)

const SHIPPING_ICON := preload("res://assets/ui/icons/shipping.png")
const WARNING_ICON := preload("res://assets/ui/icons/warning.png")
const COIN_ICON := preload("res://assets/ui/icons/coin.png")
const CROP_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/crops/turnip.png"),
	preload("res://assets/ui/crops/potato.png"),
	preload("res://assets/ui/crops/pumpkin.png"),
]
const DIMMED := Color(1.0, 1.0, 1.0, 0.45)

var _snapshot: Dictionary = {}
var _selected_kind := GameRules.CropKind.TURNIP
var _quantity := 1
var _sub: Label
var _pending: Label
var _action: Label
var _warning: PanelContainer
var _warning_text: Label
var _rows: Array[Dictionary] = []
var _row_boxes: Array[StyleBoxFlat] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_update_rows()

func open_panel(snapshot: Dictionary) -> void:
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

func selected_quantity() -> int:
	return _quantity

func selected_action_text() -> String:
	return _action.text

func stepper_button(row_index: int, part: StringName) -> Button:
	return _rows[row_index][part] as Button

func day14_warning_visible() -> bool:
	return _warning.visible

func day14_warning_text() -> String:
	return _warning_text.text

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_up"):
		_select_kind(-1)
	elif event.is_action_pressed("move_down"):
		_select_kind(1)
	elif event.is_action_pressed("move_left"):
		_adjust_quantity(-1)
	elif event.is_action_pressed("move_right"):
		_adjust_quantity(1)
	elif event.is_action_pressed("panel_max"):
		_select_max()
	elif event.is_action_pressed("ui_accept"):
		_deposit()
	else:
		return
	get_viewport().set_input_as_handled()

func _select_kind(delta: int) -> void:
	_selected_kind = posmod(_selected_kind + delta, GameRules.CropKind.size())
	_quantity = _clamped_quantity(_quantity)
	_update_rows()

func _adjust_quantity(delta: int) -> void:
	_quantity = clampi(_quantity + delta, 0, _max_quantity(_selected_kind))
	_update_rows()

func _select_max() -> void:
	_quantity = _max_quantity(_selected_kind)
	_update_rows()

func _deposit() -> void:
	deposit_requested.emit(_selected_kind, _quantity)

func _clamped_quantity(quantity: int) -> int:
	return clampi(quantity, 0, _max_quantity(_selected_kind))

func _max_quantity(kind: int) -> int:
	var harvested: Dictionary = _snapshot.get("harvested", {})
	return int(harvested.get(GameRules.crop_key(kind), 0))

func _pending_value() -> int:
	var pending: Dictionary = _snapshot.get("pending_shipment", {})
	var result := 0
	for kind in range(GameRules.CropKind.size()):
		result += int(pending.get(GameRules.crop_key(kind), 0)) * GameRules.sale_value(kind)
	return result

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
	var content := UiStyle.vbox(10)
	content.name = "Content"
	body.add_child(content)
	_warning = _warning_card()
	content.add_child(_warning)
	var rows := UiStyle.vbox(10)
	rows.name = "Rows"
	content.add_child(rows)
	for kind in range(GameRules.CropKind.size()):
		rows.add_child(_row(kind))
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
	icon_chip.add_child(UiStyle.icon(SHIPPING_ICON, 48))
	var titles := UiStyle.vbox(2)
	titles.name = "Titles"
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(titles)
	var title := UiStyle.label("SHIPPING BIN", 34, UiStyle.CARD, 900)
	title.name = "Title"
	titles.add_child(title)
	_sub = UiStyle.label("Pays out tomorrow morning", 16, Color(1.0, 1.0, 1.0, 0.85), 700)
	_sub.name = "Sub"
	titles.add_child(_sub)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var pending_chip := PanelContainer.new()
	pending_chip.name = "Pending"
	pending_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pending_chip.add_theme_stylebox_override(
		"panel",
		UiStyle.card(
			Color(1.0, 1.0, 1.0, 0.2), UiStyle.PILL_RADIUS, [8, 7, 18, 7], false
		)
	)
	pending_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pending_chip)
	var pending_row := UiStyle.hbox(10)
	pending_chip.add_child(pending_row)
	var coin := UiStyle.icon(COIN_ICON, 32)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pending_row.add_child(coin)
	var pending_text := UiStyle.vbox(0)
	pending_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pending_row.add_child(pending_text)
	var caption := UiStyle.label("PENDING", 14, Color(1.0, 1.0, 1.0, 0.85), 800)
	caption.name = "Caption"
	pending_text.add_child(caption)
	_pending = UiStyle.label("0G", 28, UiStyle.CARD, 900)
	_pending.name = "Value"
	pending_text.add_child(_pending)
	return band

func _warning_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Warning"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	var box := UiStyle.card(UiStyle.WARN, 16, [16, 12, 16, 12], false)
	box.border_color = UiStyle.SUN
	box.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", box)
	var row := UiStyle.hbox(10)
	card.add_child(row)
	var icon := UiStyle.icon(WARNING_ICON, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_warning_text = UiStyle.label("", 18, UiStyle.WARN_INK, 700)
	_warning_text.name = "Text"
	_warning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_warning_text)
	return card

func _row(index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Row_%d" % index
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var details := UiStyle.label("", 17, UiStyle.INK_MUTED, 700)
	details.name = "Sub"
	info.add_child(details)

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
	var max_chip := UiStyle.max_button("all")
	stepper.add_child(max_chip)
	minus.pressed.connect(_adjust_quantity.bind(-1))
	plus.pressed.connect(_adjust_quantity.bind(1))
	max_chip.pressed.connect(_select_max)

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
		"sub": details,
		"stepper": stepper,
		"quantity": quantity,
		"minus": minus,
		"plus": plus,
		"max": max_chip,
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
	var footer := UiStyle.commerce_footer("all")
	bar.add_child(footer)
	_action = footer.get_node("Action/Row/Text") as Label
	return bar

func _update_rows() -> void:
	var day := int(_snapshot.get("day", 1))
	_warning.visible = day == GameRules.MAX_DAY
	_warning_text.text = (
		"Day 14 — only crops deposited here count toward the finale. Anything still in the bag scores nothing."
		if _warning.visible
		else ""
	)
	_sub.text = (
		tr("Paid at season end")
		if _warning.visible
		else tr("Pays out tomorrow morning")
	)
	_pending.text = "%dG" % _pending_value()
	_action.text = tr("Ship %d · %dG") % [
		_quantity, GameRules.sale_value(_selected_kind) * _quantity,
	]
	var harvested: Dictionary = _snapshot.get("harvested", {})
	for kind in range(GameRules.CropKind.size()):
		var row := _rows[kind]
		var selected := kind == _selected_kind
		var held := int(harvested.get(GameRules.crop_key(kind), 0))
		(row["name"] as Label).text = GameRules.crop_display_name(kind)
		(row["sub"] as Label).text = tr("%d in bag · %dG each") % [
			held,
			GameRules.sale_value(kind),
		]
		(row["quantity"] as Label).text = "×%d" % _quantity
		(row["meta_caption"] as Label).text = "VALUE" if selected else ""
		(row["meta_value"] as Label).text = (
			"%dG" % (GameRules.sale_value(kind) * _quantity) if selected else "—"
		)
		(row["icon"] as TextureRect).texture = CROP_TEXTURES[kind]
		(row["stepper"] as Control).visible = selected
		(row["minus"] as Button).disabled = _quantity <= 0
		(row["plus"] as Button).disabled = _quantity >= held
		(row["max"] as Button).disabled = _quantity >= held
		(row["panel"] as Control).modulate = Color.WHITE if held > 0 else DIMMED
		_style_row(kind, selected)

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
	(row["meta_value"] as Label).add_theme_color_override(
		"font_color", UiStyle.LEAF_DEEP if selected else UiStyle.INK_MUTED
	)
