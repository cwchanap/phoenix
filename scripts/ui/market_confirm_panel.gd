class_name MarketConfirmPanel
extends Control

signal market_confirmed
signal close_requested

const MARKET_ICON := preload("res://assets/ui/icons/market.png")
const WARNING_ICON := preload("res://assets/ui/icons/warning.png")

var _day: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false

func present(snapshot: Dictionary) -> void:
	var day := int(snapshot.get("day", GameRules.MAX_DAY))
	_day.text = tr("HARVEST MARKET · DAY %d") % day

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if (
		key == null
		or key.ctrl_pressed
		or key.alt_pressed
		or key.shift_pressed
		or key.meta_pressed
	):
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		market_confirmed.emit()

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
	card.custom_minimum_size = Vector2(780, 0)
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 30, [0, 0, 0, 0])
	)
	center.add_child(card)
	var column := UiStyle.vbox(0)
	column.name = "Column"
	card.add_child(column)
	column.add_child(_header())
	var body := MarginContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 40], ["top", 24], ["right", 40], ["bottom", 32]]:
		body.add_theme_constant_override("margin_" + side[0], side[1])
	column.add_child(body)
	var content := UiStyle.vbox(20)
	content.name = "Content"
	body.add_child(content)
	var finality := UiStyle.label(
		"The market settles your shipments and friendships and shows your result. You can't keep playing after this.",
		20, UiStyle.INK, 600
	)
	finality.name = "Finality"
	finality.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(finality)
	content.add_child(_warning_card())
	var actions := UiStyle.vbox(12)
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)
	var confirm := UiStyle.primary_action("Enter", "Open the market")
	confirm.name = "Confirm"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(func() -> void: market_confirmed.emit())
	actions.add_child(confirm)
	var cancel := UiStyle.ghost_action("Esc", "Not yet")
	cancel.name = "Cancel"
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.pressed.connect(func() -> void: close_requested.emit())
	actions.add_child(cancel)

func _header() -> PanelContainer:
	var band := UiStyle.gradient_band(UiStyle.HEADER_GRADIENT, 30, [28, 20, 28, 20])
	band.name = "HeaderBand"
	var row := UiStyle.hbox(16)
	row.name = "Row"
	band.add_child(row)
	var icon_chip := PanelContainer.new()
	icon_chip.name = "IconChip"
	icon_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_chip.custom_minimum_size = Vector2(72, 72)
	icon_chip.add_theme_stylebox_override(
		"panel", UiStyle.card(Color(1.0, 1.0, 1.0, 0.22), 18, [0, 0, 0, 0], false)
	)
	icon_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_chip)
	icon_chip.add_child(UiStyle.icon(MARKET_ICON, 48))
	var titles := UiStyle.vbox(4)
	titles.name = "Titles"
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(titles)
	_day = UiStyle.label(
		"HARVEST MARKET · DAY %d" % GameRules.MAX_DAY,
		16, Color(1.0, 1.0, 1.0, 0.9), 800
	)
	_day.name = "Day"
	titles.add_child(_day)
	var title := UiStyle.label("End the season?", 34, UiStyle.CARD, 900)
	title.name = "Title"
	titles.add_child(title)
	return band

func _warning_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Warning"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.WARN, 16, [16, 12, 16, 12], false)
	)
	var row := UiStyle.hbox(12)
	row.name = "Row"
	card.add_child(row)
	var icon := UiStyle.icon(WARNING_ICON, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := UiStyle.label(
		"Crops in your bag are not sold. Ship them first.",
		18, UiStyle.WARN_INK, 700
	)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	return card
