class_name HudChrome
extends Control
## The always-visible City Pop HUD (HPA-681), drawn natively at 1920x1080:
## clock card, stamina pill, money and market/bin pills, the floating
## context prompt, the seed card, and the key pills. Code-built like
## DialoguePanel; it renders snapshots and owns no gameplay state.

signal seed_card_pressed

const MARGIN := 32.0
const TOP := 28.0
# The prompt's pointer tip sits this far above the target cell's centre:
# the cell's projected half height (16 px at zoom 3) plus a gap.
const PROMPT_LIFT := 72.0
const POINTER_SIZE := 11.0
const STAMINA_LOW := GameRules.MAX_STAMINA / 5
# From 18:00 the fieldwork bar turns amber: four hours to the cutoff.
const FIELDWORK_LATE_MINUTES := 18 * 60

const SUN_ICON := preload("res://assets/ui/icons/sun.png")
const RAIN_ICON := preload("res://assets/ui/icons/rain.png")
const STAMINA_ICON := preload("res://assets/ui/icons/stamina.png")
const COIN_ICON := preload("res://assets/ui/icons/coin.png")
const SHIPPING_ICON := preload("res://assets/ui/icons/shipping.png")
const SEED_PACKETS: Array[Texture2D] = [
	preload("res://assets/ui/crops/seed-packet-turnip.png"),
	preload("res://assets/ui/crops/seed-packet-potato.png"),
	preload("res://assets/ui/crops/seed-packet-pumpkin.png"),
]
# One hue per crop, indexed by GameRules.CropKind: the seed card's outline,
# tile, and active dot follow the selected seed.
const SEED_COLORS: Array[Color] = [UiStyle.VIOLET, Color("d9922e"), UiStyle.ORANGE]
const KEY_PILLS := [
	["I", "Bag", UiStyle.ACCENT],
	["B", "Almanac", UiStyle.BLUE],
	["C", "Calendar", UiStyle.VIOLET],
	["Esc", "Phone", UiStyle.ORANGE],
]
const SUNNY_CHIP := [UiStyle.WARN, UiStyle.WARN_INK]
const RAINY_CHIP := [Color("dff4ff"), UiStyle.BLUE]
const BIN_AMOUNT := Color("fff36b")

## A rounded track with a fill pill; `ratio` is the filled share.
class Bar extends Panel:
	var ratio := 0.0
	var fill: PanelContainer
	var track: StyleBoxFlat

	func _init(height: int, width: int = 0, track_color: Color = UiStyle.LINE) -> void:
		custom_minimum_size = Vector2(width, height)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		track = UiStyle.card(track_color, height, [0, 0, 0, 0], false)
		add_theme_stylebox_override("panel", track)
		fill = UiStyle.gradient_surface(UiStyle.ACCENT_GRADIENT, height)
		fill.name = "Fill"
		add_child(fill)
		resized.connect(_layout)

	func set_value(value: float, texture: Texture2D) -> void:
		ratio = clampf(value, 0.0, 1.0)
		(fill.get_node("Gradient") as TextureRect).texture = texture
		_layout()

	func _layout() -> void:
		var width := size.x * ratio
		fill.visible = width > 0.0
		fill.position = Vector2.ZERO
		fill.size = Vector2(maxf(width, size.y), size.y)

var _field_fill := UiStyle.gradient_texture(UiStyle.FIELDWORK_GRADIENT)
var _sun_fill := UiStyle.gradient_texture([UiStyle.SUN, UiStyle.SUN])
var _leaf_fill := UiStyle.gradient_texture(UiStyle.STAMINA_GRADIENT)
var _bad_fill := UiStyle.gradient_texture([UiStyle.BAD, UiStyle.BAD])
var _dot_off := UiStyle.card(UiStyle.LINE, 5, [0, 0, 0, 0], false)

var _clock: Label
var _day: Label
var _day_max: Label
var _weather_box: StyleBoxFlat
var _weather_icon: TextureRect
var _weather: Label
var _fieldwork: Bar
var _fieldwork_label: Label
var _stamina_box: StyleBoxFlat
var _stamina: Bar
var _stamina_value: Label
var _money: Label
var _market: Label
var _bin: Control
var _bin_amount: Label
var _bin_when: Label
var _seed_box: StyleBoxFlat
var _seed_tile_box: StyleBoxFlat
var _seed_dot_on: StyleBoxFlat
var _seed_packet: TextureRect
var _seed_badge: PanelContainer
var _seed_count: Label
var _seed_name: Label
var _seed_dots: Array[Panel] = []
var _prompt: Control
var _prompt_bubble: PanelContainer
var _prompt_key: Control
var _prompt_icon: TextureRect
var _prompt_label: Label
var _prompt_detail: Label
var _prompt_blocked := false

func _init() -> void:
	name = "Chrome"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_clock_card()
	_build_stamina()
	_build_top_right()
	_build_seed_card()
	_build_keys()
	_build_prompt()

func render(snapshot: Dictionary) -> void:
	var time := int(snapshot["time_minutes"])
	var day := int(snapshot["day"])
	_clock.text = GameRules.format_time(time)
	_day.text = tr("Day %d") % day
	_day_max.text = "/ %d" % GameRules.MAX_DAY
	var rainy: bool = snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)
	_weather_icon.texture = RAIN_ICON if rainy else SUN_ICON
	_weather.text = "Rainy" if rainy else "Sunny"
	var chip: Array = RAINY_CHIP if rainy else SUNNY_CHIP
	_weather_box.bg_color = chip[0]
	_weather.add_theme_color_override("font_color", chip[1])
	var span := float(GameRules.ACTION_CUTOFF_MINUTES - GameRules.DAY_START_MINUTES)
	_fieldwork.set_value(
		float(time - GameRules.DAY_START_MINUTES) / span,
		_sun_fill if time >= FIELDWORK_LATE_MINUTES else _field_fill,
	)
	_fieldwork_label.text = tr("Fieldwork until %s") % GameRules.format_time(GameRules.ACTION_CUTOFF_MINUTES)

	var stamina := int(snapshot["stamina"])
	var low := stamina <= STAMINA_LOW
	_stamina.set_value(float(stamina) / GameRules.MAX_STAMINA, _bad_fill if low else _leaf_fill)
	_stamina.track.bg_color = UiStyle.BAD_TRACK if low else UiStyle.MINT_TRACK
	_stamina_box.bg_color = UiStyle.BAD_SOFT if low else UiStyle.MINT
	_stamina_box.border_color = UiStyle.BAD if low else UiStyle.LEAF
	_stamina_value.text = "%d" % stamina
	_stamina_value.add_theme_color_override("font_color", UiStyle.BAD if low else UiStyle.LEAF_DEEP)

	_money.text = "%dG" % int(snapshot["money"])
	var days_left := GameRules.MAX_DAY - day
	if days_left <= 0:
		_market.text = "today — ship crops, then visit the stall"
	elif days_left == 1:
		_market.text = "tomorrow"
	else:
		_market.text = tr("in %d days") % days_left
	var payout := int(GameRules.shipment_payout(snapshot["pending_shipment"])["total"])
	_bin.visible = payout > 0
	_bin_amount.text = "+%dG" % payout
	_bin_when.text = "today" if days_left <= 0 else "tomorrow"

	var kind := GameRules.CROP_KEYS.find(snapshot["selected_seed"])
	_seed_packet.texture = SEED_PACKETS[kind]
	_seed_count.text = "×%d" % int(snapshot["seeds"].get(snapshot["selected_seed"], 0))
	_seed_name.text = tr("%s seeds") % tr(GameRules.crop_display_name(kind))
	var hue := SEED_COLORS[kind]
	_seed_box.border_color = hue
	_seed_tile_box.bg_color = hue.lerp(UiStyle.CARD, 0.82)
	_seed_dot_on.bg_color = hue
	for index in _seed_dots.size():
		_seed_dots[index].add_theme_stylebox_override("panel", _seed_dot_on if index == kind else _dot_off)
	_seed_badge.reset_size()
	_seed_badge.position = Vector2(90, 90) - _seed_badge.size

## Shows the prompt bubble with its pointer tip above `anchor`, the target
## cell's centre in screen coordinates. Empty parts are hidden.
func show_prompt(anchor: Vector2, key: String, icon: Texture2D, text: String, detail: String = "", blocked: bool = false) -> void:
	_prompt_key.visible = key != ""
	(_prompt_key.get_node("Key") as Label).text = key
	_prompt_icon.visible = icon != null
	_prompt_icon.texture = icon
	_prompt_label.text = text
	_prompt_detail.visible = detail != ""
	_prompt_detail.text = detail
	if blocked != _prompt_blocked:
		_prompt_blocked = blocked
		_prompt_label.add_theme_color_override("font_color", UiStyle.BAD if blocked else UiStyle.INK)
	_prompt_bubble.reset_size()
	_prompt_bubble.position = Vector2(-_prompt_bubble.size.x / 2.0, -_prompt_bubble.size.y - POINTER_SIZE)
	_prompt.position = anchor - Vector2(0.0, PROMPT_LIFT)
	_prompt.visible = true

func hide_prompt() -> void:
	_prompt.visible = false

## The prompt as one readable line ("[Space] Till soil · 3 stamina"), or ""
## when hidden. A test and e2e seam; the bubble itself is the presentation.
func prompt_text() -> String:
	if not _prompt.visible:
		return ""
	var parts: Array[String] = []
	if _prompt_key.visible:
		parts.append("[%s]" % (_prompt_key.get_node("Key") as Label).text)
	parts.append(_prompt_label.text)
	if _prompt_detail.visible:
		parts.append(_prompt_detail.text)
	return " ".join(parts)

func prompt_icon() -> Texture2D:
	return _prompt_icon.texture if _prompt.visible and _prompt_icon.visible else null

func _build_clock_card() -> void:
	var card := PanelContainer.new()
	card.name = "ClockCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.NIGHT))
	card.position = Vector2(MARGIN, TOP)
	card.custom_minimum_size = Vector2(420, 0)
	add_child(card)
	# A card-shaped mask clips the gradient band to the rounded top edge. It
	# is a sibling of the content: Godot does not nest clip_children, and the
	# day tag and fieldwork bar inside clip their own gradients.
	var band_mask := PanelContainer.new()
	band_mask.name = "BandMask"
	band_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band_mask.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.CARD, 22, [0, 0, 0, 0], false))
	band_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	card.add_child(band_mask)
	var band := UiStyle.gradient_rect(UiStyle.HEADER_GRADIENT)
	band.name = "Band"
	band_mask.add_child(band)
	band_mask.sort_children.connect(func() -> void:
		band.position = Vector2.ZERO
		band.size = Vector2(band_mask.size.x, 6)
	)
	var surface := MarginContainer.new()
	surface.name = "Surface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 24], ["top", 18], ["right", 24], ["bottom", 18]]:
		surface.add_theme_constant_override("margin_" + side[0], side[1])
	card.add_child(surface)
	var body := UiStyle.vbox(12)
	body.name = "Body"
	surface.add_child(body)

	var row := UiStyle.hbox(18)
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	body.add_child(row)
	_clock = UiStyle.label("06:00", 64, UiStyle.CARD, 900)
	_clock.name = "Clock"
	# The mockup sets the clock at line-height 0.9; trim M PLUS 1's tall
	# default line box to match.
	var clock_font := _clock.get_theme_font("font") as FontVariation
	clock_font.spacing_top = -16
	clock_font.spacing_bottom = -16
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_clock)
	var meta := UiStyle.vbox(6)
	meta.name = "Meta"
	meta.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(meta)
	var day_tag := UiStyle.gradient_surface(UiStyle.ACCENT_GRADIENT, UiStyle.PILL_RADIUS, [12, 0, 12, 0])
	day_tag.name = "DayTag"
	day_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meta.add_child(day_tag)
	var day_row := UiStyle.hbox(4)
	day_row.name = "DayRow"
	day_tag.add_child(day_row)
	_day = UiStyle.label("Day 1", 20, UiStyle.CARD, 900)
	_day.name = "Day"
	day_row.add_child(_day)
	_day_max = UiStyle.label("/ 14", 15, Color(1, 1, 1, 0.85), 900)
	_day_max.name = "DayMax"
	_day_max.size_flags_vertical = Control.SIZE_SHRINK_END
	day_row.add_child(_day_max)
	var weather := PanelContainer.new()
	weather.name = "Weather"
	weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_weather_box = UiStyle.card(SUNNY_CHIP[0], UiStyle.PILL_RADIUS, [8, 2, 14, 2], false)
	weather.add_theme_stylebox_override("panel", _weather_box)
	meta.add_child(weather)
	var weather_row := UiStyle.hbox(6)
	weather_row.name = "Row"
	weather.add_child(weather_row)
	_weather_icon = UiStyle.icon(SUN_ICON)
	_weather_icon.name = "Icon"
	weather_row.add_child(_weather_icon)
	_weather = UiStyle.label("Sunny", 18, SUNNY_CHIP[1], 800)
	_weather.name = "Label"
	weather_row.add_child(_weather)

	var fieldwork := UiStyle.vbox(6)
	fieldwork.name = "Fieldwork"
	body.add_child(fieldwork)
	_fieldwork = Bar.new(6, 0, Color(1, 1, 1, 0.16))
	_fieldwork.name = "Bar"
	fieldwork.add_child(_fieldwork)
	_fieldwork_label = UiStyle.label("", 14, Color(1, 1, 1, 0.7), 700)
	_fieldwork_label.name = "Label"
	fieldwork.add_child(_fieldwork_label)

func _build_stamina() -> void:
	var pill := _pill("Stamina", [12, 10, 18, 10], 12)
	_stamina_box = UiStyle.outlined(pill.get_theme_stylebox("panel") as StyleBoxFlat, UiStyle.LEAF)
	_stamina_box.bg_color = UiStyle.MINT
	pill.position = Vector2(MARGIN, 200)
	add_child(pill)
	var row := pill.get_node("Row")
	row.add_child(UiStyle.icon(STAMINA_ICON))
	_stamina = Bar.new(14, 260, UiStyle.MINT_TRACK)
	_stamina.name = "Bar"
	_stamina.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_stamina)
	var numbers := UiStyle.hbox(6)
	numbers.name = "Numbers"
	row.add_child(numbers)
	_stamina_value = UiStyle.label("20", 20, UiStyle.LEAF_DEEP, 900)
	_stamina_value.name = "Value"
	numbers.add_child(_stamina_value)
	var max_label := UiStyle.label("/ %d" % GameRules.MAX_STAMINA, 16, UiStyle.INK_MUTED, 900)
	max_label.size_flags_vertical = Control.SIZE_SHRINK_END
	numbers.add_child(max_label)

func _build_top_right() -> void:
	var column := UiStyle.vbox(8)
	column.name = "TopRight"
	UiStyle.pin(column, CORNER_TOP_RIGHT, Vector2(MARGIN, TOP))
	add_child(column)
	var money := _pill("Money", [12, 10, 22, 10], 10, false, UiStyle.ACCENT)
	money.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(money)
	money.get_node("Row").add_child(UiStyle.icon(COIN_ICON))
	_money = UiStyle.label("0G", 32, UiStyle.CARD, 900)
	_money.name = "Value"
	money.get_node("Row").add_child(_money)

	var sub := UiStyle.vbox(8)
	sub.name = "SubInfo"
	sub.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(sub)
	var market := _pill("Market", [16, 6, 16, 6], 8, true, UiStyle.BLUE)
	market.size_flags_horizontal = Control.SIZE_SHRINK_END
	sub.add_child(market)
	var market_tag := SlantTag.new("MARKET", [UiStyle.SUN], UiStyle.SUN_INK)
	market_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	market.get_node("Row").add_child(market_tag)
	_market = UiStyle.label("", 17, UiStyle.CARD, 800)
	_market.name = "Label"
	market.get_node("Row").add_child(_market)

	_bin = _pill("Bin", [16, 6, 16, 6], 8, true, UiStyle.LEAF)
	_bin.size_flags_horizontal = Control.SIZE_SHRINK_END
	sub.add_child(_bin)
	var bin_row := _bin.get_node("Row")
	bin_row.add_child(UiStyle.icon(SHIPPING_ICON))
	bin_row.add_child(UiStyle.label("Bin", 17, UiStyle.CARD, 800))
	_bin_amount = UiStyle.label("", 17, BIN_AMOUNT, 900)
	_bin_amount.name = "Amount"
	bin_row.add_child(_bin_amount)
	_bin_when = UiStyle.label("", 17, UiStyle.CARD, 800)
	_bin_when.name = "When"
	bin_row.add_child(_bin_when)

func _build_seed_card() -> void:
	var card := PanelContainer.new()
	card.name = "SeedCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_seed_box = UiStyle.outlined(UiStyle.card(UiStyle.HUD_CARD, 22, [12, 12, 22, 12]), SEED_COLORS[0])
	card.add_theme_stylebox_override("panel", _seed_box)
	UiStyle.pin(card, CORNER_BOTTOM_LEFT, Vector2(MARGIN, TOP))
	card.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			seed_card_pressed.emit()
	)
	add_child(card)
	var row := UiStyle.hbox(16)
	row.name = "Row"
	card.add_child(row)

	var tile := Panel.new()
	tile.name = "Tile"
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.custom_minimum_size = Vector2(84, 84)
	_seed_tile_box = UiStyle.card(UiStyle.SOFT, 16, [0, 0, 0, 0], false)
	tile.add_theme_stylebox_override("panel", _seed_tile_box)
	row.add_child(tile)
	_seed_packet = UiStyle.icon(SEED_PACKETS[0], 64)
	_seed_packet.name = "Packet"
	_seed_packet.position = Vector2(10, 10)
	_seed_packet.size = Vector2(64, 64)
	tile.add_child(_seed_packet)
	_seed_badge = UiStyle.gradient_surface(UiStyle.ACCENT_GRADIENT, UiStyle.PILL_RADIUS, [9, 0, 9, 0])
	_seed_badge.name = "Badge"
	tile.add_child(_seed_badge)
	_seed_count = UiStyle.label("×0", 16, UiStyle.CARD, 900)
	_seed_count.name = "Count"
	_seed_badge.add_child(_seed_count)

	var info := UiStyle.vbox(8)
	info.name = "Info"
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	_seed_name = UiStyle.label("", 22, UiStyle.INK, 900)
	_seed_name.name = "Name"
	info.add_child(_seed_name)
	var hint := UiStyle.hbox(10)
	hint.name = "Hint"
	info.add_child(hint)
	var dots := UiStyle.hbox(6)
	dots.name = "Dots"
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.add_child(dots)
	_seed_dot_on = UiStyle.card(SEED_COLORS[0], 5, [0, 0, 0, 0], false)
	_seed_dots.clear()
	for kind in range(GameRules.CropKind.size()):
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dots.add_child(dot)
		_seed_dots.append(dot)
	hint.add_child(UiStyle.keycap("2", true))
	var switch_label := UiStyle.label("switch", 15, UiStyle.INK_MUTED, 800)
	switch_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.add_child(switch_label)

func _build_keys() -> void:
	var keys := UiStyle.hbox(10)
	keys.name = "Keys"
	UiStyle.pin(keys, CORNER_BOTTOM_RIGHT, Vector2(MARGIN, TOP))
	add_child(keys)
	for entry in KEY_PILLS:
		var pill := _pill(entry[1], [6, 6, 14, 6], 8, true)
		keys.add_child(pill)
		pill.get_node("Row").add_child(UiStyle.keycap(entry[0], true, false, entry[2]))
		var caption := UiStyle.label(entry[1], 16, UiStyle.INK, 800)
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.get_node("Row").add_child(caption)

func _build_prompt() -> void:
	_prompt = Control.new()
	_prompt.name = "Prompt"
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	add_child(_prompt)
	var pointer := Control.new()
	pointer.name = "Pointer"
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.draw.connect(func() -> void:
		pointer.draw_colored_polygon(
			PackedVector2Array([
				Vector2(-POINTER_SIZE, -POINTER_SIZE - 1.0),
				Vector2(POINTER_SIZE, -POINTER_SIZE - 1.0),
				Vector2(0.0, 0.0),
			]),
			UiStyle.HUD_CARD,
		)
	)
	_prompt.add_child(pointer)
	_prompt_bubble = PanelContainer.new()
	_prompt_bubble.name = "Bubble"
	_prompt_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_bubble.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.HUD_CARD, UiStyle.PILL_RADIUS, [8, 8, 20, 8]))
	_prompt.add_child(_prompt_bubble)
	var row := UiStyle.hbox(12)
	row.name = "Row"
	_prompt_bubble.add_child(row)
	_prompt_key = UiStyle.keycap("Space", false, true)
	_prompt_key.name = "Key"
	row.add_child(_prompt_key)
	_prompt_icon = UiStyle.icon(null)
	_prompt_icon.name = "Icon"
	row.add_child(_prompt_icon)
	_prompt_label = UiStyle.label("", 23, UiStyle.INK, 900)
	_prompt_label.name = "Label"
	row.add_child(_prompt_label)
	_prompt_detail = UiStyle.label("", 18, UiStyle.INK_MUTED, 700)
	_prompt_detail.name = "Detail"
	row.add_child(_prompt_detail)

## A HUD pill, white or filled with its widget's hue, holding one HBox
## named Row.
func _pill(node_name: String, padding: Array, separation: int, light_shadow: bool = false, fill: Color = UiStyle.HUD_CARD) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = node_name
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(fill, UiStyle.PILL_RADIUS, padding)
	if light_shadow:
		box.shadow_color = Color(UiStyle.SHADOW, 0.2)
		box.shadow_size = 10
	pill.add_theme_stylebox_override("panel", box)
	var row := UiStyle.hbox(separation)
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(row)
	return pill
