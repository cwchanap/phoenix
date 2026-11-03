class_name BagPanel
extends Control
## The bag phone app (HPA-682): a code-built PhoneFrame holding the seeds,
## harvested and shipping-bin shelves plus the selected item's detail card.
## Selection and counts come from the session snapshot; the panel owns no
## gameplay state and closes through GameHud's I/Esc paths.

signal close_requested

const SHELF_NAMES: Array[String] = ["SEEDS", "HARVESTED", "IN THE SHIPPING BIN"]
const SHELF_KEYS: Array[StringName] = [&"seeds", &"harvested", &"pending_shipment"]
const SHELF_TEXTURES: Array[String] = [
	"res://assets/ui/crops/seed-packet-%s.png",
	"res://assets/ui/crops/%s.png",
	"res://assets/ui/crops/%s.png",
]
const BAG_ICON := preload("res://assets/ui/icons/bag.png")
const SEEDS_ICON := preload("res://assets/ui/icons/seeds.png")
const HARVEST_ICON := preload("res://assets/ui/crops/turnip.png")
const MOON_ICON := preload("res://assets/ui/icons/moon.png")
const COIN_ICON := preload("res://assets/ui/icons/coin.png")
const HEART_ICON := preload("res://assets/ui/icons/heart-filled.png")
const HEADER_GRADIENT: Array[Color] = [UiStyle.ACCENT, UiStyle.ORANGE]
const DIMMED := Color(0.54, 0.58, 0.66, 1.0)

var _snapshot: Dictionary = {}
var _shelf := 0
var _selected_kind := GameRules.CropKind.TURNIP
var _frame: PhoneFrame
var _seed_total: Label
var _harvest_total: Label
var _shelf_titles: Array[Label] = []
var _shelf_boxes: Array[StyleBoxFlat] = []
var _shelf_slots: Array[Array] = []
var _bin_payout: Control
var _bin_payout_note: Label
var _bin_payout_value: Label
var _detail_icon: TextureRect
var _detail_title: Label
var _detail_description: Label
var _detail_growth_text: Label
var _detail_economy: Label
var _detail_favourite: Label
var _pip_on := UiStyle.card(UiStyle.SUN, 4, [0, 0, 0, 0], false)
var _pip_off := UiStyle.card(UiStyle.LINE, 4, [0, 0, 0, 0], false)
var _detail_pips: Array[Panel] = []
var _badge_selected := UiStyle.card(UiStyle.ACCENT, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
var _badge_bin := UiStyle.card(UiStyle.LEAF, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
var _badge_normal := UiStyle.card(UiStyle.INK_MUTED, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false
	_update_view()

func open_panel(snapshot: Dictionary) -> void:
	_shelf = 0
	_selected_kind = GameRules.CropKind.TURNIP
	present(snapshot)
	visible = true

func present(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_update_view()

func selected_shelf() -> int:
	return _shelf

func selected_kind() -> int:
	return _selected_kind

## GameHud.render() supplies the session clock already formatted.
func set_status_time(time_text: String) -> void:
	_frame.set_status_time(time_text)

func status_time_text() -> String:
	return _frame.status_time_text()

## Read-only seams for tests: the selected item's detail and the bin payout.
func detail_title_text() -> String:
	return _detail_title.text

func detail_description_text() -> String:
	return _detail_description.text

func detail_description_line_count() -> int:
	return _detail_description.get_line_count()

func detail_economy_text() -> String:
	return _detail_economy.text

func detail_favourite_text() -> String:
	return _detail_favourite.text

func bin_slot_visible(kind: int) -> bool:
	return (_shelf_slots[2][kind]["slot"] as Control).visible

func bin_payout_visible() -> bool:
	return _bin_payout.visible

func bin_payout_value_text() -> String:
	return _bin_payout_value.text

func bin_payout_note_text() -> String:
	return _bin_payout_note.text

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_up"):
		_select_shelf(-1)
	elif event.is_action_pressed("move_down"):
		_select_shelf(1)
	elif event.is_action_pressed("move_left"):
		_select_kind(-1)
	elif event.is_action_pressed("move_right"):
		_select_kind(1)
	else:
		return
	get_viewport().set_input_as_handled()

func _select_shelf(delta: int) -> void:
	_shelf = posmod(_shelf + delta, SHELF_NAMES.size())
	if _shelf == 2:
		var first_pending_kind := _first_available_kind(2)
		if first_pending_kind >= 0:
			_selected_kind = first_pending_kind
	_update_view()

func _select_kind(delta: int) -> void:
	if _shelf != 2:
		_selected_kind = posmod(_selected_kind + delta, GameRules.CropKind.size())
	else:
		for _step in GameRules.CropKind.size():
			_selected_kind = posmod(_selected_kind + delta, GameRules.CropKind.size())
			if _count_for(2, _selected_kind) > 0:
				break
	_update_view()

func _first_available_kind(shelf: int) -> int:
	for kind in range(GameRules.CropKind.size()):
		if _count_for(shelf, kind) > 0:
			return kind
	return -1

func _counts_for(shelf: int) -> Dictionary:
	return _snapshot.get(SHELF_KEYS[shelf], {})

func _count_for(shelf: int, kind: int) -> int:
	var counts := _counts_for(shelf)
	return int(counts.get(GameRules.crop_key(kind), 0))

func _total_for(shelf: int) -> int:
	var total := 0
	for kind in range(GameRules.CropKind.size()):
		total += _count_for(shelf, kind)
	return total

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
	for side in [["left", 16], ["top", 14], ["right", 16], ["bottom", 12]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(12)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_app_header())
	for shelf in SHELF_NAMES.size():
		column.add_child(_shelf_card(shelf))
	column.add_child(_detail_card())
	column.add_child(_footer_hint())

func _app_header() -> PanelContainer:
	var header := UiStyle.gradient_surface(HEADER_GRADIENT, 20, [16, 10, 16, 10])
	header.name = "AppHeader"
	var row := UiStyle.hbox(10)
	header.add_child(row)
	var icon_chip := PanelContainer.new()
	icon_chip.name = "IconChip"
	icon_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_chip.custom_minimum_size = Vector2(38, 38)
	icon_chip.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 12, [5, 5, 5, 5], false)
	)
	icon_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_chip)
	icon_chip.add_child(UiStyle.icon(BAG_ICON, 28))
	var title := UiStyle.label("Bag", 26, UiStyle.CARD, 900)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var seeds_chip := _count_chip(SEEDS_ICON, "SeedsChip")
	_seed_total = seeds_chip.get_node("Row/Value") as Label
	row.add_child(seeds_chip)
	var harvest_chip := _count_chip(HARVEST_ICON, "HarvestChip")
	_harvest_total = harvest_chip.get_node("Row/Value") as Label
	row.add_child(harvest_chip)
	return header

func _count_chip(icon_texture: Texture2D, chip_name: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override(
		"panel", UiStyle.card(Color(1.0, 1.0, 1.0, 0.22), UiStyle.PILL_RADIUS, [10, 4, 12, 4], false)
	)
	var row := UiStyle.hbox(6)
	row.name = "Row"
	chip.add_child(row)
	row.add_child(UiStyle.icon(icon_texture, 18))
	var value := UiStyle.label("0", 16, UiStyle.CARD, 900)
	value.name = "Value"
	row.add_child(value)
	return chip

func _shelf_card(shelf: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Shelf_%d" % shelf
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.HUD_CARD, 18, [14, 10, 14, 12], false)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	_shelf_boxes.append(box)
	card.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(8)
	card.add_child(column)
	var title := UiStyle.label(SHELF_NAMES[shelf], 15, UiStyle.INK_MUTED, 800)
	title.name = "Title"
	_shelf_titles.append(title)
	column.add_child(title)
	var slots := UiStyle.hbox(10)
	slots.name = "Slots"
	column.add_child(slots)
	var slot_row: Array = []
	for kind in range(GameRules.CropKind.size()):
		var slot := _slot(kind)
		slots.add_child(slot["slot"])
		slot_row.append(slot)
	_shelf_slots.append(slot_row)
	if shelf == 2:
		_bin_payout = UiStyle.hbox(10)
		_bin_payout.name = "Payout"
		_bin_payout.alignment = BoxContainer.ALIGNMENT_END
		column.add_child(_bin_payout)
		_bin_payout_note = UiStyle.label("", 14, UiStyle.INK_MUTED, 700)
		_bin_payout_note.name = "Note"
		_bin_payout_note.size_flags_vertical = Control.SIZE_SHRINK_END
		_bin_payout.add_child(_bin_payout_note)
		_bin_payout_value = UiStyle.label("0G", 22, UiStyle.LEAF_DEEP, 900)
		_bin_payout_value.name = "Value"
		_bin_payout.add_child(_bin_payout_value)
	return card

func _slot(kind: int) -> Dictionary:
	var slot := PanelContainer.new()
	slot.name = "Slot_%d" % kind
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(76, 76)
	var box := Control.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(box)
	var icon := UiStyle.icon(null, 48)
	icon.name = "Icon"
	icon.position = Vector2(10, 12)
	icon.size = Vector2(48, 48)
	box.add_child(icon)
	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -26.0
	badge.offset_right = -2.0
	badge.offset_top = 2.0
	badge.offset_bottom = 22.0
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.custom_minimum_size = Vector2(22, 20)
	box.add_child(badge)
	var value := UiStyle.label("0", 13, UiStyle.CARD, 800)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(value)
	return {"slot": slot, "icon": icon, "badge": badge, "value": value}

func _detail_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 20, [16, 14, 16, 14])
	)
	var column := UiStyle.vbox(10)
	card.add_child(column)

	var top := UiStyle.hbox(14)
	top.name = "Top"
	column.add_child(top)
	var icon_frame := PanelContainer.new()
	icon_frame.name = "IconFrame"
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.custom_minimum_size = Vector2(96, 96)
	icon_frame.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.SOFT, 16, [8, 8, 8, 8], false)
	)
	top.add_child(icon_frame)
	_detail_icon = UiStyle.icon(null, 80)
	_detail_icon.name = "Icon"
	icon_frame.add_child(_detail_icon)
	var header := UiStyle.vbox(6)
	header.name = "Header"
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	_detail_title = UiStyle.label("", 24, UiStyle.INK, 900)
	_detail_title.name = "Title"
	header.add_child(_detail_title)
	var favourite_row := UiStyle.hbox(6)
	favourite_row.name = "Favourite"
	header.add_child(favourite_row)
	favourite_row.add_child(UiStyle.icon(HEART_ICON, 16))
	_detail_favourite = UiStyle.label("", 15, UiStyle.ACCENT, 800)
	_detail_favourite.name = "Label"
	favourite_row.add_child(_detail_favourite)

	_detail_description = UiStyle.label("", 15, UiStyle.INK_MUTED, 500)
	_detail_description.name = "Description"
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.custom_minimum_size = Vector2(0, 44)
	column.add_child(_detail_description)

	var growth_row := UiStyle.hbox(8)
	growth_row.name = "Growth"
	column.add_child(growth_row)
	var moon := UiStyle.icon(MOON_ICON, 20)
	moon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	growth_row.add_child(moon)
	var pips := UiStyle.hbox(4)
	pips.name = "Pips"
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	growth_row.add_child(pips)
	for index in 7:
		var pip := Panel.new()
		pip.name = "Pip_%d" % index
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(18, 10)
		pip.add_theme_stylebox_override("panel", _pip_off)
		pips.add_child(pip)
		_detail_pips.append(pip)
	_detail_growth_text = UiStyle.label("", 15, UiStyle.INK, 700)
	_detail_growth_text.name = "Text"
	_detail_growth_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	growth_row.add_child(_detail_growth_text)

	var economy_row := UiStyle.hbox(8)
	economy_row.name = "Economy"
	column.add_child(economy_row)
	var coin := UiStyle.icon(COIN_ICON, 20)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	economy_row.add_child(coin)
	_detail_economy = UiStyle.label("", 15, UiStyle.INK, 700)
	_detail_economy.name = "Label"
	_detail_economy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	economy_row.add_child(_detail_economy)
	return card

func _footer_hint() -> HBoxContainer:
	var footer := UiStyle.hbox(8)
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	var caps := UiStyle.hbox(4)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["W", "A", "S", "D"]:
		caps.add_child(UiStyle.keycap(key, true))
	footer.add_child(caps)
	var move := UiStyle.label("move", 14, UiStyle.INK_MUTED, 700)
	move.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(move)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(18, 0)
	footer.add_child(gap)
	footer.add_child(UiStyle.keycap("I", true))
	var close := UiStyle.label("close", 14, UiStyle.INK_MUTED, 700)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(close)
	return footer

func _update_view() -> void:
	if _frame == null:
		return
	if _shelf == 2 and _count_for(2, _selected_kind) == 0:
		var first_pending_kind := _first_available_kind(2)
		if first_pending_kind >= 0:
			_selected_kind = first_pending_kind
	_seed_total.text = "%d" % _total_for(0)
	_harvest_total.text = "%d" % _total_for(1)
	for shelf in SHELF_NAMES.size():
		var selected := shelf == _shelf
		_shelf_titles[shelf].add_theme_color_override(
			"font_color", UiStyle.ACCENT if selected else UiStyle.INK_MUTED
		)
		var shelf_box := _shelf_boxes[shelf]
		shelf_box.border_color = UiStyle.ACCENT if selected else UiStyle.LINE
		shelf_box.set_border_width_all(2 if selected else 1)
		for kind in range(GameRules.CropKind.size()):
			var slot: Dictionary = _shelf_slots[shelf][kind]
			var slot_panel := slot["slot"] as PanelContainer
			var amount := _count_for(shelf, kind)
			slot_panel.visible = shelf != 2 or amount > 0
			(slot["icon"] as TextureRect).texture = load(
				SHELF_TEXTURES[shelf] % GameRules.crop_key(kind)
			) as Texture2D
			slot_panel.modulate = Color.WHITE if amount > 0 else DIMMED
			var slot_selected := selected and kind == _selected_kind
			var slot_box := UiStyle.card(UiStyle.CARD, 14, [4, 4, 4, 4], false)
			slot_box.border_color = UiStyle.ACCENT if slot_selected else UiStyle.LINE
			slot_box.set_border_width_all(2 if slot_selected else 1)
			slot_panel.add_theme_stylebox_override("panel", slot_box)
			var badge := slot["badge"] as PanelContainer
			badge.visible = amount > 0
			badge.add_theme_stylebox_override(
				"panel",
				_badge_bin if shelf == 2 else _badge_selected if slot_selected else _badge_normal,
			)
			(slot["value"] as Label).text = "%d" % amount
	_update_bin_payout()
	_update_detail()

func _update_bin_payout() -> void:
	var payout_total := 0
	var pending := 0
	for kind in range(GameRules.CropKind.size()):
		var amount := _count_for(2, kind)
		payout_total += amount * GameRules.sale_value(kind)
		pending += amount
	_bin_payout.visible = pending > 0
	_bin_payout_note.text = (
		"Paid at season end"
		if int(_snapshot.get("day", 1)) >= GameRules.MAX_DAY
		else "Pays out tomorrow morning"
	)
	_bin_payout_value.text = "%dG" % payout_total

func _update_detail() -> void:
	var kind := _selected_kind
	var crop_name := tr(GameRules.crop_display_name(kind))
	_detail_icon.texture = load(
		SHELF_TEXTURES[_shelf] % GameRules.crop_key(kind)
	) as Texture2D
	_detail_title.text = tr("%s seeds") % crop_name if _shelf == 0 else crop_name
	var shelf_count := _count_for(_shelf, kind)
	var description := "Cheapest and fastest; the latest safe planting."
	if kind == GameRules.CropKind.POTATO:
		description = "Best return per seed coin per night."
	elif kind == GameRules.CropKind.PUMPKIN:
		description = "Best profit per stamina of tending in a sunny season."
	if _shelf == 1:
		description = tr("%d harvested and ready for the shipping bin.") % shelf_count
	elif _shelf == 2:
		description = (
			"Payout is collected at season end."
			if int(_snapshot.get("day", 1)) >= GameRules.MAX_DAY
			else "Payout is collected tomorrow morning."
		)
	_detail_description.text = description
	var growth := GameRules.growth_nights(kind)
	_detail_growth_text.text = tr("%d nights") % growth
	for index in _detail_pips.size():
		_detail_pips[index].add_theme_stylebox_override(
			"panel", _pip_on if index < growth else _pip_off
		)
	_detail_economy.text = tr("%dG buy · %dG sell") % [
		GameRules.seed_price(kind),
		GameRules.sale_value(kind),
	]
	var favourite := VillagerRules.favourite_villager_for_crop(kind)
	_detail_favourite.text = tr("%s's favourite") % tr(VillagerRules.display_name(favourite))
