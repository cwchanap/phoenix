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
const DIMMED := Color(0.58, 0.61, 0.68, 1.0)

var _snapshot: Dictionary = {}
var _selected_kind := GameRules.CropKind.TURNIP
var _quantity := 1
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
	card.custom_minimum_size = Vector2(960, 0)
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 26, [24, 18, 24, 18])
	)
	center.add_child(card)
	var column := UiStyle.vbox(14)
	column.name = "Column"
	card.add_child(column)
	column.add_child(_header())
	_warning = _warning_card()
	column.add_child(_warning)
	var rows := UiStyle.vbox(10)
	rows.name = "Rows"
	column.add_child(rows)
	for kind in range(GameRules.CropKind.size()):
		rows.add_child(_row(kind))
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
	icon_chip.add_child(UiStyle.icon(SHIPPING_ICON, 30))
	var title := UiStyle.label("SHIPPING BIN", 28, UiStyle.INK, 900)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var pending_chip := PanelContainer.new()
	pending_chip.name = "Pending"
	pending_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pending_chip.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.MINT, UiStyle.PILL_RADIUS, [12, 5, 16, 5], false)
	)
	pending_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(pending_chip)
	var pending_row := UiStyle.hbox(8)
	pending_chip.add_child(pending_row)
	var coin := UiStyle.icon(COIN_ICON, 22)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pending_row.add_child(coin)
	var caption := UiStyle.label("PENDING", 14, UiStyle.LEAF_DEEP, 800)
	caption.name = "Caption"
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pending_row.add_child(caption)
	_pending = UiStyle.label("0G", 24, UiStyle.LEAF_DEEP, 900)
	_pending.name = "Value"
	pending_row.add_child(_pending)
	return header

func _warning_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Warning"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	var box := UiStyle.card(UiStyle.WARN, 14, [12, 10, 12, 10], false)
	box.border_color = UiStyle.SUN
	box.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", box)
	var row := UiStyle.hbox(8)
	card.add_child(row)
	var icon := UiStyle.icon(WARNING_ICON, 20)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_warning_text = UiStyle.label("", 14, UiStyle.WARN_INK, 700)
	_warning_text.name = "Text"
	_warning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_warning_text)
	return card

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
	var details := UiStyle.label("", 15, UiStyle.INK_MUTED, 500)
	details.name = "Details"
	info.add_child(details)

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
	var max_chip := _stepper_chip("M", "all")
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
		"details": details,
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
	_warning.visible = int(_snapshot.get("day", 1)) == GameRules.MAX_DAY
	_warning_text.text = (
		"Day 14 — only crops deposited here count toward the finale. Anything still in the bag scores nothing."
		if _warning.visible
		else ""
	)
	_pending.text = "%dG" % _pending_value()
	_action.text = tr("DEPOSIT ×%d") % _quantity
	var harvested: Dictionary = _snapshot.get("harvested", {})
	for kind in range(GameRules.CropKind.size()):
		var row := _rows[kind]
		var selected := kind == _selected_kind
		var held := int(harvested.get(GameRules.crop_key(kind), 0))
		(row["name"] as Label).text = GameRules.crop_display_name(kind)
		(row["details"] as Label).text = tr("%d in bag · %dG each") % [
			held,
			GameRules.sale_value(kind),
		]
		(row["quantity"] as Label).text = "×%d" % _quantity
		(row["meta_caption"] as Label).text = "VALUE" if selected else ""
		(row["meta_value"] as Label).text = (
			"%d" % (GameRules.sale_value(kind) * _quantity) if selected else "—"
		)
		(row["icon"] as TextureRect).texture = CROP_TEXTURES[kind]
		(row["stepper"] as Control).visible = selected
		(row["panel"] as Control).modulate = Color.WHITE if selected or held > 0 else DIMMED
		_style_row(kind, selected)

func _style_row(index: int, selected: bool) -> void:
	var row_box := _row_boxes[index]
	row_box.bg_color = UiStyle.ACCENT_SOFT if selected else UiStyle.CARD
	row_box.border_color = UiStyle.ACCENT if selected else UiStyle.LINE
	row_box.set_border_width_all(2 if selected else 1)
	var row := _rows[index]
	(row["name"] as Label).add_theme_color_override(
		"font_color", UiStyle.ACCENT_DEEP if selected else UiStyle.INK
	)
	(row["meta_value"] as Label).add_theme_color_override(
		"font_color", UiStyle.LEAF_DEEP if selected else UiStyle.INK_MUTED
	)
