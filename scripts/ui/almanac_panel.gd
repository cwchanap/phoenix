class_name AlmanacPanel
extends Control
## The almanac phone app (HPA-682): a code-built PhoneFrame paging one crop
## at a time — big crop art, favourite villager, growth and the seed/sell/
## margin facts straight from GameRules. A/D browse; the panel owns no
## gameplay state and closes through GameHud's B/Esc paths.

signal close_requested

const ART_TEXTURES: Array[String] = [
	"res://assets/ui/crops/turnip-art.png",
	"res://assets/ui/crops/potato-art.png",
	"res://assets/ui/crops/pumpkin-art.png",
]
const GROWTH_COLORS: Array[Color] = [UiStyle.SUN, UiStyle.BLUE, UiStyle.ORANGE]
const ALMANAC_ICON := preload("res://assets/ui/icons/almanac.png")
const HEART_ICON := preload("res://assets/ui/icons/heart-filled.png")
const HEADER_GRADIENT: Array[Color] = [UiStyle.ACCENT_2, UiStyle.VIOLET]

var _snapshot: Dictionary = {}
var _selected_kind := GameRules.CropKind.TURNIP
var _frame: PhoneFrame
var _art: TextureRect
var _name: Label
var _favourite_badge: PanelContainer
var _favourite_box: StyleBoxFlat
var _favourite_value: Label
var _pips: Array[Panel] = []
var _pip_boxes: Array[StyleBoxFlat] = []
var _pip_off := UiStyle.card(UiStyle.LINE, 4, [0, 0, 0, 0], false)
var _growth_value: Label
var _seed_value: Label
var _sell_value: Label
var _margin_value: Label
var _dots: Array[Panel] = []
var _dot_on := UiStyle.card(UiStyle.BLUE, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
var _dot_off := UiStyle.card(UiStyle.LINE, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false
	_update_page()

func open_panel(snapshot: Dictionary) -> void:
	_selected_kind = GameRules.CropKind.TURNIP
	present(snapshot)
	visible = true

func present(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_update_page()

func selected_kind() -> int:
	return _selected_kind

## GameHud.render() supplies the session clock already formatted.
func set_status_time(time_text: String) -> void:
	_frame.set_status_time(time_text)

func status_time_text() -> String:
	return _frame.status_time_text()

## Read-only seams for tests: the paged crop's facts.
func crop_name_text() -> String:
	return _name.text

func crop_seed_text() -> String:
	return _seed_value.text

func crop_sell_text() -> String:
	return _sell_value.text

func crop_margin_text() -> String:
	return _margin_value.text

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("move_left"):
		_selected_kind = posmod(_selected_kind - 1, GameRules.CropKind.size())
	elif event.is_action_pressed("move_right"):
		_selected_kind = posmod(_selected_kind + 1, GameRules.CropKind.size())
	else:
		return
	_update_page()
	get_viewport().set_input_as_handled()

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

	for color in GROWTH_COLORS:
		_pip_boxes.append(UiStyle.card(color, 4, [0, 0, 0, 0], false))
	column.add_child(_app_header())
	column.add_child(_art_card())
	column.add_child(_growth_card())
	column.add_child(_stats_row())
	column.add_child(_dots_row())
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
	icon_chip.add_child(UiStyle.icon(ALMANAC_ICON, 28))
	var title := UiStyle.label("Almanac", 26, UiStyle.CARD, 900)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var subtitle := UiStyle.label("3 crops · 14-day season", 14, UiStyle.CARD, 800)
	subtitle.name = "Subtitle"
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(subtitle)
	return header

func _art_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ArtCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 20, [14, 12, 14, 12])
	)
	var column := UiStyle.vbox(10)
	card.add_child(column)
	var art_frame := PanelContainer.new()
	art_frame.name = "ArtFrame"
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_frame.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.SOFT, 16, [10, 10, 10, 10], false)
	)
	column.add_child(art_frame)
	_art = UiStyle.icon(null, 220)
	_art.name = "Art"
	_art.custom_minimum_size = Vector2(0, 220)
	art_frame.add_child(_art)
	var name_row := UiStyle.hbox(10)
	name_row.name = "NameRow"
	column.add_child(name_row)
	_name = UiStyle.label("", 26, UiStyle.INK, 900)
	_name.name = "Name"
	name_row.add_child(_name)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(spacer)
	_favourite_badge = PanelContainer.new()
	_favourite_badge.name = "FavouriteBadge"
	_favourite_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_favourite_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_favourite_box = UiStyle.card(UiStyle.ACCENT_SOFT, UiStyle.PILL_RADIUS, [12, 4, 12, 4], false)
	_favourite_badge.add_theme_stylebox_override("panel", _favourite_box)
	name_row.add_child(_favourite_badge)
	var badge_row := UiStyle.hbox(4)
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_favourite_badge.add_child(badge_row)
	badge_row.add_child(UiStyle.icon(HEART_ICON, 14))
	_favourite_value = UiStyle.label("", 13, UiStyle.ACCENT_DEEP, 800)
	_favourite_value.name = "Value"
	badge_row.add_child(_favourite_value)
	return card

func _growth_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Growth"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 18, [14, 10, 14, 12], false)
	)
	var column := UiStyle.vbox(8)
	card.add_child(column)
	var caption := UiStyle.label("GROWTH", 13, UiStyle.INK_MUTED, 800)
	caption.name = "Caption"
	column.add_child(caption)
	var row := UiStyle.hbox(8)
	row.name = "Row"
	column.add_child(row)
	var pips := UiStyle.hbox(4)
	pips.name = "Pips"
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	for index in 7:
		var pip := Panel.new()
		pip.name = "Pip_%d" % index
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(20, 12)
		pip.add_theme_stylebox_override("panel", _pip_off)
		pips.add_child(pip)
		_pips.append(pip)
	_growth_value = UiStyle.label("", 15, UiStyle.INK, 700)
	_growth_value.name = "Value"
	_growth_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_growth_value)
	return card

func _stats_row() -> HBoxContainer:
	var row := UiStyle.hbox(10)
	row.name = "Stats"
	_seed_value = _stat_cell(row, "SEED", UiStyle.INK)
	_sell_value = _stat_cell(row, "SELL", UiStyle.LEAF_DEEP)
	_margin_value = _stat_cell(row, "MARGIN", UiStyle.LEAF_DEEP)
	return row

func _stat_cell(row: HBoxContainer, caption: String, value_color: Color) -> Label:
	var cell := PanelContainer.new()
	cell.name = "%sCell" % caption
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiStyle.card(UiStyle.HUD_CARD, 14, [10, 8, 10, 8], false)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(2)
	cell.add_child(column)
	var caption_label := UiStyle.label(caption, 11, UiStyle.INK_MUTED, 800)
	caption_label.name = "Caption"
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption_label)
	var value := UiStyle.label("", 20, value_color, 900)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	row.add_child(cell)
	return value

func _dots_row() -> HBoxContainer:
	var row := UiStyle.hbox(6)
	row.name = "Dots"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for kind in range(GameRules.CropKind.size()):
		var dot := Panel.new()
		dot.name = "Dot_%d" % kind
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(10, 10)
		dot.add_theme_stylebox_override("panel", _dot_off)
		row.add_child(dot)
		_dots.append(dot)
	return row

func _footer_hint() -> HBoxContainer:
	var footer := UiStyle.hbox(8)
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	var caps := UiStyle.hbox(4)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caps.add_child(UiStyle.keycap("A", true))
	caps.add_child(UiStyle.keycap("D", true))
	footer.add_child(caps)
	var browse := UiStyle.label("browse", 14, UiStyle.INK_MUTED, 700)
	browse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(browse)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(18, 0)
	footer.add_child(gap)
	footer.add_child(UiStyle.keycap("B", true))
	var close := UiStyle.label("close", 14, UiStyle.INK_MUTED, 700)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(close)
	return footer

func _update_page() -> void:
	if _frame == null:
		return
	var kind := _selected_kind
	_art.texture = load(ART_TEXTURES[kind]) as Texture2D
	_name.text = GameRules.crop_display_name(kind)
	var favourite := VillagerRules.favourite_villager_for_crop(kind)
	_favourite_value.text = tr(VillagerRules.display_name(favourite)).to_upper()
	_favourite_box.border_color = UiStyle.ACCENT
	_favourite_box.set_border_width_all(2)
	var growth := GameRules.growth_nights(kind)
	_growth_value.text = tr("%d watered nights") % growth
	for index in _pips.size():
		_pips[index].add_theme_stylebox_override(
			"panel", _pip_boxes[kind] if index < growth else _pip_off
		)
	_seed_value.text = "%dG" % GameRules.seed_price(kind)
	_sell_value.text = "%dG" % GameRules.sale_value(kind)
	_margin_value.text = "+%d" % (
		GameRules.sale_value(kind) - GameRules.seed_price(kind)
	)
	for index in _dots.size():
		_dots[index].add_theme_stylebox_override(
			"panel", _dot_on if index == kind else _dot_off
		)
