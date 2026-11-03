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
const ART_GRADIENT: Array[Color] = [Color("bfe8ff"), Color("e9fbe8")]
const ARTBOX_SIZE := Vector2i(488, 300)
const ARTBOX_RADIUS := 24
const HEART_ICON := preload("res://assets/ui/icons/heart-filled.png")

var _snapshot: Dictionary = {}
var _art_cache: Dictionary = {}
var _selected_kind := GameRules.CropKind.TURNIP
var _frame: PhoneFrame
var _page: Label
var _art: TextureRect
var _name: Label
var _favourite_value: Label
var _pips: Array[Dictionary] = []
var _growth_value: Label
var _seed_value: Label
var _sell_value: Label
var _margin_value: Label
var _dots: Array[Dictionary] = []

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

func crop_favourite_text() -> String:
	return _favourite_value.text

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
	_frame.set_app_header("Almanac", "作物図鑑")
	var chip := PanelContainer.new()
	chip.name = "Page"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override(
		"panel",
		UiStyle.card(Color(1.0, 1.0, 1.0, 0.22), UiStyle.PILL_RADIUS, [12, 5, 12, 5], false),
	)
	_frame.app_header_accessory().add_child(chip)
	_page = UiStyle.label("", 15, UiStyle.CARD, 800)
	_page.name = "PageChip"
	chip.add_child(_page)

	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 22], ["top", -10], ["right", 22], ["bottom", 4]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(12)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_art_box())
	column.add_child(_name_row())
	column.add_child(_growth_card())
	column.add_child(_stats_row())
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_dots_row())
	_build_footer()

func _art_box() -> PanelContainer:
	var box := PanelContainer.new()
	box.name = "ArtBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(0, ARTBOX_SIZE.y)
	box.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, ARTBOX_RADIUS, [0, 0, 0, 0], false)
	)
	_art = TextureRect.new()
	_art.name = "Art"
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(_art)
	return box

func _art_texture(kind: int) -> ImageTexture:
	if not _art_cache.has(kind):
		_art_cache[kind] = _compose_art(kind)
	return _art_cache[kind]

func _compose_art(kind: int) -> ImageTexture:
	var stops := Gradient.new()
	stops.offsets = PackedFloat32Array([0.0, 1.0])
	stops.colors = PackedColorArray(ART_GRADIENT)
	var image := Image.create(ARTBOX_SIZE.x, ARTBOX_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in ARTBOX_SIZE.y:
		image.fill_rect(
			Rect2i(0, y, ARTBOX_SIZE.x, 1),
			stops.sample(float(y) / float(ARTBOX_SIZE.y - 1)),
		)
	var art_image := (load(ART_TEXTURES[kind]) as Texture2D).get_image()
	var art_scale := minf(
		ARTBOX_SIZE.x / float(art_image.get_width()),
		ARTBOX_SIZE.y / float(art_image.get_height()),
	)
	var art_size := Vector2i(
		int(art_image.get_width() * art_scale),
		int(art_image.get_height() * art_scale),
	)
	art_image.resize(art_size.x, art_size.y, Image.INTERPOLATE_NEAREST)
	image.blend_rect(
		art_image, Rect2i(Vector2i.ZERO, art_size), (ARTBOX_SIZE - art_size) / 2
	)
	UiStyle.apply_rounded_mask(image, ARTBOX_RADIUS)
	return ImageTexture.create_from_image(image)

func _name_row() -> HBoxContainer:
	var row := UiStyle.hbox(10)
	row.name = "NameRow"
	_name = UiStyle.label("", 34, UiStyle.INK, 900)
	_name.name = "Name"
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_name)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var chip := PanelContainer.new()
	chip.name = "FavouriteChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override(
		"panel",
		UiStyle.card(UiStyle.ACCENT_SOFT, UiStyle.PILL_RADIUS, [10, 3, 12, 3], false),
	)
	row.add_child(chip)
	var chip_row := UiStyle.hbox(6)
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(chip_row)
	chip_row.add_child(UiStyle.icon(HEART_ICON, 16))
	_favourite_value = UiStyle.label("", 15, UiStyle.ACCENT_DEEP, 800)
	_favourite_value.name = "Value"
	chip_row.add_child(_favourite_value)
	return row

func _growth_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Growth"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.CARD, 20, [16, 14, 16, 14], false)
	box.shadow_color = Color(0.16, 0.04, 0.16, 0.06)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(8)
	card.add_child(column)
	var caption := UiStyle.label("GROWTH", 14, UiStyle.INK_MUTED, 900)
	caption.name = "Caption"
	column.add_child(caption)
	var row := UiStyle.hbox(12)
	row.name = "Row"
	column.add_child(row)
	var pips := UiStyle.hbox(6)
	pips.name = "GrowthPips"
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	for index in 7:
		var pip := UiStyle.state_pip(Vector2(22, 8))
		pip.name = "Pip_%d" % index
		pips.add_child(pip)
		_pips.append({"pip": pip, "on": pip.get_node("On"), "off": pip.get_node("Off")})
	_growth_value = UiStyle.label("", 17, UiStyle.INK, 800)
	_growth_value.name = "Value"
	_growth_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_growth_value)
	return card

func _stats_row() -> HBoxContainer:
	var row := UiStyle.hbox(10)
	row.name = "Stats"
	_seed_value = _stat_cell(row, "SeedCell", "SEED", UiStyle.INK)
	_sell_value = _stat_cell(row, "SellCell", "SELL", UiStyle.INK)
	_margin_value = _stat_cell(row, "MarginCell", "MARGIN", UiStyle.LEAF_DEEP)
	return row

func _stat_cell(row: HBoxContainer, cell_name: String, caption: String, value_color: Color) -> Label:
	var cell := PanelContainer.new()
	cell.name = cell_name
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiStyle.card(UiStyle.CARD, 20, [16, 14, 16, 14], false)
	box.shadow_color = Color(0.16, 0.04, 0.16, 0.06)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	cell.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(2)
	cell.add_child(column)
	var caption_label := UiStyle.label(caption, 14, UiStyle.INK_MUTED, 900)
	caption_label.name = "Caption"
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption_label)
	var value := UiStyle.label("", 30, value_color, 900)
	value.name = "Value"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	row.add_child(cell)
	return value

func _dots_row() -> HBoxContainer:
	var row := UiStyle.hbox(8)
	row.name = "PageDots"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for kind in range(GameRules.CropKind.size()):
		var dot := Control.new()
		dot.name = "Dot_%d" % kind
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(10, 10)
		var off := Panel.new()
		off.name = "Off"
		off.mouse_filter = Control.MOUSE_FILTER_IGNORE
		off.set_anchors_preset(Control.PRESET_FULL_RECT)
		off.add_theme_stylebox_override(
			"panel", UiStyle.card(UiStyle.LINE, 5, [0, 0, 0, 0], false)
		)
		dot.add_child(off)
		var on := TextureRect.new()
		on.name = "On"
		on.mouse_filter = Control.MOUSE_FILTER_IGNORE
		on.texture = UiStyle.rounded_gradient_texture(
			UiStyle.ACCENT_GRADIENT, Vector2i(26, 10), 5
		)
		on.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		on.stretch_mode = TextureRect.STRETCH_SCALE
		on.set_anchors_preset(Control.PRESET_FULL_RECT)
		dot.add_child(on)
		row.add_child(dot)
		_dots.append({"dot": dot, "on": on, "off": off})
	return row

func _build_footer() -> void:
	var footer := _frame.footer_mount()
	var caps := UiStyle.hbox(4)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caps.add_child(UiStyle.keycap("A", true))
	caps.add_child(UiStyle.keycap("D", true))
	footer.add_child(caps)
	var browse := UiStyle.label("browse", 15, UiStyle.INK_MUTED, 800)
	browse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(browse)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var close_caps := UiStyle.hbox(4)
	close_caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_caps.add_child(UiStyle.keycap("B", true))
	footer.add_child(close_caps)
	var close := UiStyle.label("close", 15, UiStyle.INK_MUTED, 800)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(close)

func _update_page() -> void:
	if _frame == null:
		return
	var kind := _selected_kind
	_page.text = tr("%d of %d") % [kind + 1, GameRules.CropKind.size()]
	_art.texture = _art_texture(kind)
	_name.text = GameRules.crop_display_name(kind)
	var favourite := VillagerRules.favourite_villager_for_crop(kind)
	_favourite_value.text = tr("%s's favourite") % tr(VillagerRules.display_name(favourite))
	var growth := GameRules.growth_nights(kind)
	_growth_value.text = tr("%d watered nights") % growth
	for index in _pips.size():
		var pip: Dictionary = _pips[index]
		(pip["on"] as Control).visible = index < growth
		(pip["off"] as Control).visible = index >= growth
	_seed_value.text = "%dG" % GameRules.seed_price(kind)
	_sell_value.text = "%dG" % GameRules.sale_value(kind)
	_margin_value.text = "+%d" % (
		GameRules.sale_value(kind) - GameRules.seed_price(kind)
	)
	for index in _dots.size():
		var dot: Dictionary = _dots[index]
		var active := index == kind
		(dot["dot"] as Control).custom_minimum_size = (
			Vector2(26, 10) if active else Vector2(10, 10)
		)
		(dot["on"] as Control).visible = active
		(dot["off"] as Control).visible = not active
