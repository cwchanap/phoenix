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
const SHIPPING_ICON := preload("res://assets/ui/icons/shipping.png")
const HEART_ICON := preload("res://assets/ui/icons/heart-filled.png")
const SLOT_SIZE := Vector2(96, 96)
const GLOW := Color(1.0, 0.24, 0.5, 0.38)
const DIMMED := Color(1.0, 1.0, 1.0, 0.35)

var _snapshot: Dictionary = {}
var _shelf := 0
var _selected_kind := GameRules.CropKind.TURNIP
var _frame: PhoneFrame
var _totals: Label
var _shelf_titles: Array[Label] = []
var _shelf_boxes: Array[StyleBoxFlat] = []
var _shelf_slots: Array[Array] = []
var _bin_payout: Control
var _bin_count: Label
var _bin_payout_note: Label
var _bin_payout_value: Label
var _detail_title: Label
var _detail_description: Label
var _detail_growth_text: Label
var _detail_economy: Label
var _detail_favourite: Label
var _detail_pips: Array[Dictionary] = []

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
	_frame.set_app_header("Bag", "かばん")
	var chip := PanelContainer.new()
	chip.name = "Totals"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override(
		"panel",
		UiStyle.card(Color(1.0, 1.0, 1.0, 0.22), UiStyle.PILL_RADIUS, [12, 5, 12, 5], false),
	)
	_frame.app_header_accessory().add_child(chip)
	_totals = UiStyle.label("", 15, UiStyle.CARD, 800)
	_totals.name = "TotalsChip"
	chip.add_child(_totals)

	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 22], ["top", -12], ["right", 22], ["bottom", 2]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(10)
	column.name = "Column"
	layout.add_child(column)

	for shelf in SHELF_NAMES.size():
		column.add_child(_shelf_card(shelf))
	column.add_child(_detail_card())
	_build_footer()

func _shelf_card(shelf: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Shelf_%d" % shelf
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.CARD, 20, [16, 12, 16, 12], false)
	box.shadow_color = Color(0.16, 0.04, 0.16, 0.06)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	_shelf_boxes.append(box)
	card.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(6)
	column.name = "Rows"
	card.add_child(column)
	var title := UiStyle.label(SHELF_NAMES[shelf], 14, UiStyle.INK_MUTED, 900)
	title.name = "Title"
	_shelf_titles.append(title)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	var slot_row: Array = []
	for kind in range(GameRules.CropKind.size()):
		var slot := _slot(kind)
		grid.add_child(slot["slot"])
		slot_row.append(slot)
	_shelf_slots.append(slot_row)
	if shelf != 2:
		var filler := Control.new()
		filler.name = "Filler"
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filler.custom_minimum_size = SLOT_SIZE
		grid.add_child(filler)
	if shelf == 2:
		_bin_payout = UiStyle.hbox(14)
		_bin_payout.name = "BinPayout"
		_bin_payout.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(_bin_payout)
		var icon := UiStyle.icon(SHIPPING_ICON, 28)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bin_payout.add_child(icon)
		var info := UiStyle.vbox(2)
		info.name = "Info"
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bin_payout.add_child(info)
		_bin_count = UiStyle.label("", 16, UiStyle.INK, 800)
		_bin_count.name = "BinCount"
		info.add_child(_bin_count)
		_bin_payout_note = UiStyle.label("", 13, UiStyle.INK_MUTED, 700)
		_bin_payout_note.name = "Note"
		info.add_child(_bin_payout_note)
		_bin_payout_value = UiStyle.label("+0G", 22, UiStyle.LEAF_DEEP, 900)
		_bin_payout_value.name = "Value"
		_bin_payout_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bin_payout.add_child(_bin_payout_value)
	return card

func _slot(kind: int) -> Dictionary:
	var slot := Panel.new()
	slot.name = "Slot_%d" % kind
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = SLOT_SIZE
	var icon := UiStyle.icon(null, 60)
	icon.name = "Icon"
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -30.0
	icon.offset_right = 30.0
	icon.offset_top = -30.0
	icon.offset_bottom = 30.0
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	slot.add_child(icon)
	var count := UiStyle.label("", 16, UiStyle.INK, 900)
	count.name = "Count"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.anchor_left = 1.0
	count.anchor_right = 1.0
	count.anchor_top = 1.0
	count.anchor_bottom = 1.0
	count.offset_left = -34.0
	count.offset_right = -6.0
	count.offset_top = -24.0
	count.offset_bottom = -2.0
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot.add_child(count)
	return {"slot": slot, "icon": icon, "count": count}

func _detail_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Detail"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UiStyle.card(UiStyle.CARD, 20, [16, 12, 16, 12], false)
	box.shadow_color = Color(0.16, 0.04, 0.16, 0.06)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(6)
	card.add_child(column)

	var top := UiStyle.hbox(10)
	top.name = "Top"
	column.add_child(top)
	_detail_title = UiStyle.label("", 22, UiStyle.INK, 900)
	_detail_title.name = "Title"
	_detail_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_detail_title)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var favourite_chip := PanelContainer.new()
	favourite_chip.name = "FavouriteChip"
	favourite_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	favourite_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	favourite_chip.add_theme_stylebox_override(
		"panel",
		UiStyle.card(UiStyle.ACCENT_SOFT, UiStyle.PILL_RADIUS, [10, 3, 12, 3], false),
	)
	top.add_child(favourite_chip)
	var favourite_row := UiStyle.hbox(6)
	favourite_row.alignment = BoxContainer.ALIGNMENT_CENTER
	favourite_chip.add_child(favourite_row)
	favourite_row.add_child(UiStyle.icon(HEART_ICON, 16))
	_detail_favourite = UiStyle.label("", 15, UiStyle.ACCENT_DEEP, 800)
	_detail_favourite.name = "Label"
	favourite_row.add_child(_detail_favourite)

	_detail_description = UiStyle.label("", 16, UiStyle.INK_MUTED, 600)
	_detail_description.name = "Description"
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.custom_minimum_size = Vector2(0, 40)
	column.add_child(_detail_description)

	var bottom := UiStyle.hbox(12)
	bottom.name = "Bottom"
	column.add_child(bottom)
	var pips := UiStyle.hbox(4)
	pips.name = "Pips"
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(pips)
	for index in 7:
		var pip := UiStyle.state_pip(Vector2(22, 8))
		pip.name = "Pip_%d" % index
		pips.add_child(pip)
		_detail_pips.append({"pip": pip, "on": pip.get_node("On"), "off": pip.get_node("Off")})
	_detail_growth_text = UiStyle.label("", 16, UiStyle.INK, 800)
	_detail_growth_text.name = "Text"
	_detail_growth_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_detail_growth_text)
	var economy_spacer := Control.new()
	economy_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	economy_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(economy_spacer)
	_detail_economy = UiStyle.label("", 16, UiStyle.INK, 800)
	_detail_economy.name = "Label"
	_detail_economy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_detail_economy)
	return card

func _build_footer() -> void:
	var footer := _frame.footer_mount()
	var caps := UiStyle.hbox(4)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["W", "A", "S", "D"]:
		caps.add_child(UiStyle.keycap(key, true))
	footer.add_child(caps)
	var move := UiStyle.label("move", 15, UiStyle.INK_MUTED, 800)
	move.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(move)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var close_caps := UiStyle.hbox(4)
	close_caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_caps.add_child(UiStyle.keycap("I", true))
	footer.add_child(close_caps)
	var close := UiStyle.label("close", 15, UiStyle.INK_MUTED, 800)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(close)

func _update_view() -> void:
	if _frame == null:
		return
	if _shelf == 2 and _count_for(2, _selected_kind) == 0:
		var first_pending_kind := _first_available_kind(2)
		if first_pending_kind >= 0:
			_selected_kind = first_pending_kind
	_totals.text = tr("%d seeds · %d crops") % [_total_for(0), _total_for(1)]
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
			var slot_panel := slot["slot"] as Panel
			var amount := _count_for(shelf, kind)
			slot_panel.visible = shelf != 2 or amount > 0
			(slot["icon"] as TextureRect).texture = load(
				SHELF_TEXTURES[shelf] % GameRules.crop_key(kind)
			) as Texture2D
			(slot["icon"] as TextureRect).modulate = (
				Color.WHITE if amount > 0 else DIMMED
			)
			var slot_selected := selected and kind == _selected_kind
			var slot_box := UiStyle.card(
				UiStyle.ACCENT_SOFT if slot_selected else UiStyle.SOFT,
				16,
				[0, 0, 0, 0],
				false,
			)
			slot_box.border_color = (
				UiStyle.ACCENT if slot_selected else Color(1.0, 1.0, 1.0, 0.0)
			)
			slot_box.set_border_width_all(3)
			if slot_selected:
				slot_box.shadow_color = GLOW
				slot_box.shadow_size = 12
				slot_box.shadow_offset = Vector2(0, 6)
			slot_panel.add_theme_stylebox_override("panel", slot_box)
			var count := slot["count"] as Label
			count.visible = amount > 0
			count.text = "%d" % amount
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
	_bin_count.text = tr("%d crops in the bin") % pending
	_bin_payout_note.text = (
		"Paid at season end"
		if int(_snapshot.get("day", 1)) >= GameRules.MAX_DAY
		else "Pays out tomorrow morning"
	)
	_bin_payout_value.text = "+%dG" % payout_total

func _update_detail() -> void:
	var kind := _selected_kind
	var crop_name := tr(GameRules.crop_display_name(kind))
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
		var pip: Dictionary = _detail_pips[index]
		(pip["on"] as Control).visible = index < growth
		(pip["off"] as Control).visible = index >= growth
	_detail_economy.text = tr("%dG buy · %dG sell") % [
		GameRules.seed_price(kind),
		GameRules.sale_value(kind),
	]
	var favourite := VillagerRules.favourite_villager_for_crop(kind)
	_detail_favourite.text = tr("%s's favourite") % tr(VillagerRules.display_name(favourite))
