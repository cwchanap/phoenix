class_name CalendarPanel
extends Control
## The calendar phone app (HPA-682): a code-built PhoneFrame holding the
## fixed 7x2 season grid and a Coming Up card. Cells show today, the Day 14
## market, the LAST NIGHT marker, weather only for days inside
## `weather_history` (never a forecast) and earliest-readiness crop icons
## computed from the farm snapshot. GameHud owns the modal; the panel owns
## no gameplay state.

signal close_requested

const WEATHER_TEXTURES := {
	&"sunny": "res://assets/ui/icons/sun.png",
	&"rainy": "res://assets/ui/icons/rain.png",
}
const CROP_TEXTURES: Array[String] = [
	"res://assets/ui/crops/turnip.png",
	"res://assets/ui/crops/potato.png",
	"res://assets/ui/crops/pumpkin.png",
]
const MARKET_ICON := preload("res://assets/ui/icons/market.png")
const MOON_ICON := preload("res://assets/ui/icons/moon.png")
const COMING_UP_CROP_LIMIT := 3

var _snapshot: Dictionary = {}
var _frame: PhoneFrame
var _cells: Array[Dictionary] = []
var _market_tag: Label
var _coming_rows: VBoxContainer
var _caption: Label
var _legend: Label
var _today_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false
	_update_calendar()

func open_panel(snapshot: Dictionary) -> void:
	present(snapshot)
	visible = true

func present(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_update_calendar()

## GameHud.render() supplies the session clock already formatted.
func set_status_time(time_text: String) -> void:
	_frame.set_status_time(time_text)

func status_time_text() -> String:
	return _frame.status_time_text()

## Read-only seam for tests: the rendered state of one day cell.
func day_state(day: int) -> Dictionary:
	if day < 1 or day > _cells.size():
		return {}
	var cell: Dictionary = _cells[day - 1]
	var flags := (cell["flags"] as Control).visible
	var today := (cell["today_fill"] as TextureRect).visible
	var market := (
		(cell["market"] as TextureRect).visible
		and flags
		and (cell["box"] as StyleBoxFlat).bg_color == UiStyle.SUN
	)
	var readiness_row := (cell["readiness_row"] as Control).visible
	var readiness_icon := cell["readiness_icon"] as TextureRect
	var readiness_kinds: Array = []
	if readiness_row and readiness_icon.visible:
		readiness_kinds.append(_kind_for_icon(readiness_icon))
	var multi_icons := cell["multi_icons"] as Array
	for multi_index in range(multi_icons.size()):
		var multi_icon := multi_icons[multi_index] as TextureRect
		if readiness_row and multi_icon.visible:
			readiness_kinds.append(_kind_for_icon(multi_icon))
	return {
		"today": today,
		"market": market,
		"combined": today and market,
		"last_night": (cell["moon"] as TextureRect).visible and flags,
		"weather_known": (cell["weather"] as TextureRect).visible,
		"readiness_kinds": readiness_kinds,
		"readiness_icon_path": (
			readiness_icon.texture.resource_path
			if readiness_row and readiness_icon.visible and readiness_icon.texture != null
			else ""
		),
		"readiness_text": "EARLIEST" if not readiness_kinds.is_empty() else "",
	}

func _kind_for_icon(icon: TextureRect) -> int:
	if icon.texture == null:
		return -1
	return CROP_TEXTURES.find(icon.texture.resource_path)

func coming_up_row_texts() -> Array[String]:
	var texts: Array[String] = []
	for child in _coming_rows.get_children():
		var label := (child as Control).find_child("Text", true, false) as Label
		if label != null:
			texts.append(label.text)
	return texts

func coming_up_day_texts() -> Array[String]:
	var texts: Array[String] = []
	for child in _coming_rows.get_children():
		var label := (child as Control).find_child("Day", true, false) as Label
		if label != null:
			texts.append(label.text)
	return texts

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
	_frame.set_app_header("Season", "カレンダー")
	var tag := SlantTag.new("", [UiStyle.SUN], UiStyle.SUN_INK, 15)
	tag.name = "MarketTag"
	_frame.app_header_accessory().add_child(tag)
	_market_tag = tag.get_node("Text") as Label
	_today_texture = UiStyle.rounded_gradient_texture(
		UiStyle.ACCENT_GRADIENT, Vector2i(64, 96), 14
	)

	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 22], ["top", -10], ["right", 22], ["bottom", 8]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(12)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_grid_card())
	column.add_child(_coming_up_card())
	_caption = UiStyle.label("", 16, UiStyle.INK_MUTED, 700)
	_caption.name = "Caption"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_caption)
	_legend = UiStyle.label("", 15, UiStyle.INK_MUTED, 700)
	_legend.name = "Legend"
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_legend)
	_build_footer()

func _grid_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Grid"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.CARD, 20, [14, 14, 14, 14], false)
	box.shadow_color = Color(0.16, 0.04, 0.16, 0.06)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", box)
	var grid := GridContainer.new()
	grid.name = "Days"
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	card.add_child(grid)
	for day in range(1, GameRules.MAX_DAY + 1):
		var cell := _day_cell(day)
		grid.add_child(cell["cell"])
		_cells.append(cell)
	return card

func _day_cell(day: int) -> Dictionary:
	var cell := PanelContainer.new()
	cell.name = "Day_%02d" % day
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.custom_minimum_size = Vector2(0, 96)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiStyle.card(UiStyle.SOFT, 14, [4, 5, 4, 5], false)
	cell.add_theme_stylebox_override("panel", box)
	var today_fill := TextureRect.new()
	today_fill.name = "TodayFill"
	today_fill.texture = _today_texture
	today_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	today_fill.stretch_mode = TextureRect.STRETCH_SCALE
	today_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	today_fill.visible = false
	cell.add_child(today_fill)
	var column := UiStyle.vbox(2)
	column.name = "Rows"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(column)
	var top := UiStyle.hbox(4)
	top.name = "Top"
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(top)
	var day_label := UiStyle.label("%d" % day, 20, UiStyle.INK, 900)
	day_label.name = "Day"
	top.add_child(day_label)
	var weather := UiStyle.icon(null, 24)
	weather.name = "Weather"
	weather.visible = false
	weather.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(weather)

	var flags := UiStyle.hbox(4)
	flags.name = "Flags"
	flags.alignment = BoxContainer.ALIGNMENT_CENTER
	flags.custom_minimum_size = Vector2(0, 24)
	column.add_child(flags)
	var market := UiStyle.icon(MARKET_ICON, 24)
	market.name = "Market"
	market.visible = false
	market.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flags.add_child(market)
	var moon := UiStyle.icon(MOON_ICON, 20)
	moon.name = "Moon"
	moon.visible = false
	moon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flags.add_child(moon)

	var readiness_icons := UiStyle.hbox(3)
	readiness_icons.name = "ReadinessIcons"
	readiness_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	readiness_icons.custom_minimum_size = Vector2(0, 18)
	column.add_child(readiness_icons)
	var readiness_icon := UiStyle.icon(null, 18)
	readiness_icon.name = "ReadinessIcon"
	readiness_icon.visible = false
	readiness_icons.add_child(readiness_icon)
	var multi_icons: Array[TextureRect] = []
	for multi_index in range(3):
		var multi_icon := UiStyle.icon(null, 15)
		multi_icon.name = "ReadinessMultiIcon_%d" % (multi_index + 1)
		multi_icon.visible = false
		readiness_icons.add_child(multi_icon)
		multi_icons.append(multi_icon)
	return {
		"cell": cell,
		"box": box,
		"today_fill": today_fill,
		"day": day_label,
		"weather": weather,
		"today": today_fill,
		"market": market,
		"flags": flags,
		"moon": moon,
		"last_night": moon,
		"readiness_icon": readiness_icon,
		"readiness_row": readiness_icons,
		"multi_icons": multi_icons,
	}

func _coming_up_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ComingUp"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.CARD, 20, [14, 12, 14, 10], false)
	box.shadow_color = Color(0.16, 0.04, 0.16, 0.06)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(4)
	card.add_child(column)
	var title := UiStyle.label("Coming Up", 15, UiStyle.INK_MUTED, 900)
	title.name = "Title"
	title.uppercase = true
	column.add_child(title)
	_coming_rows = UiStyle.vbox(0)
	_coming_rows.name = "Rows"
	column.add_child(_coming_rows)
	return card

func _coming_up_row() -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 0, [4, 7, 4, 7], false)
	box.border_color = UiStyle.LINE
	box.border_width_bottom = 1
	row.add_theme_stylebox_override("panel", box)
	var line := UiStyle.hbox(10)
	line.name = "Line"
	row.add_child(line)
	var day := UiStyle.label("", 16, UiStyle.ACCENT_DEEP, 900)
	day.name = "Day"
	day.custom_minimum_size = Vector2(64, 0)
	day.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(day)
	var icons := UiStyle.hbox(4)
	icons.name = "Icons"
	icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icons)
	var text := UiStyle.label("", 18, UiStyle.INK, 800)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	return row

func _build_footer() -> void:
	var footer := _frame.footer_mount()
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var cap := UiStyle.keycap("C", true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(cap)
	var close := UiStyle.label("close", 15, UiStyle.INK_MUTED, 800)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(close)

func _update_calendar() -> void:
	if _frame == null:
		return
	var current_day := int(_snapshot.get("day", 1))
	_market_tag.text = (
		tr("MARKET TODAY")
		if current_day >= GameRules.MAX_DAY
		else tr("MARKET IN %d") % (GameRules.MAX_DAY - current_day)
	)
	var history: Array = _snapshot.get("weather_history", [])
	var readiness := _readiness_markers(current_day)
	for index in range(_cells.size()):
		var day := index + 1
		var cell: Dictionary = _cells[index]
		var is_today := day == current_day
		var is_market := day == GameRules.MAX_DAY
		var box := cell["box"] as StyleBoxFlat
		box.bg_color = UiStyle.SUN if is_market else UiStyle.SOFT
		(cell["cell"] as Control).modulate = (
			Color(1.0, 1.0, 1.0, 0.7) if day < current_day else Color.WHITE
		)
		(cell["today_fill"] as TextureRect).visible = is_today
		var ink := (
			UiStyle.SUN_INK
			if is_market
			else UiStyle.CARD if is_today else UiStyle.INK
		)
		var day_label := cell["day"] as Label
		day_label.text = "%d" % day
		day_label.add_theme_color_override("font_color", ink)
		(cell["market"] as TextureRect).visible = is_market
		var is_last_night := day == GameRules.MAX_DAY - 1
		(cell["moon"] as TextureRect).visible = is_last_night
		var weather := cell["weather"] as TextureRect
		var weather_known := index < history.size()
		weather.visible = weather_known
		if weather_known:
			weather.texture = load(
				WEATHER_TEXTURES.get(StringName(history[index]), WEATHER_TEXTURES[&"sunny"])
			) as Texture2D
		var crop_kinds: Array = readiness.get(day, [])
		var single := crop_kinds.size() == 1
		var readiness_icon := cell["readiness_icon"] as TextureRect
		readiness_icon.visible = single
		if single:
			readiness_icon.texture = load(CROP_TEXTURES[int(crop_kinds[0])]) as Texture2D
		var multi := crop_kinds.size() > 1
		var multi_icons := cell["multi_icons"] as Array
		for multi_index in range(multi_icons.size()):
			var multi_icon := multi_icons[multi_index] as TextureRect
			multi_icon.visible = multi and multi_index < crop_kinds.size()
			if multi_icon.visible:
				multi_icon.texture = load(
					CROP_TEXTURES[int(crop_kinds[multi_index])]
				) as Texture2D
	_update_coming_up(current_day, readiness)

func _coming_up_entries(current_day: int, readiness: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var days := readiness.keys()
	days.sort()
	var shown := mini(days.size(), COMING_UP_CROP_LIMIT)
	for index in shown:
		var day: int = days[index]
		entries.append({"day": day, "rank": 0, "kinds": readiness[day]})
	if days.size() > shown:
		entries.append(
			{"day": int(days[shown]), "rank": 0, "overflow": days.size() - shown}
		)
	if current_day <= GameRules.MAX_DAY - 1:
		entries.append({"day": GameRules.MAX_DAY - 1, "rank": 1, "kind": &"last_night"})
	entries.append({"day": GameRules.MAX_DAY, "rank": 2, "kind": &"market"})
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["day"]) != int(b["day"]):
				return int(a["day"]) < int(b["day"])
			return int(a["rank"]) < int(b["rank"])
	)
	return entries

func _update_coming_up(current_day: int, readiness: Dictionary) -> void:
	for child in _coming_rows.get_children():
		_coming_rows.remove_child(child)
		child.queue_free()
	var entries := _coming_up_entries(current_day, readiness)
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var row := _coming_up_row()
		var day := row.find_child("Day", true, false) as Label
		var icons := row.find_child("Icons", true, false) as Control
		var text := row.find_child("Text", true, false) as Label
		if entry.has("kinds"):
			day.text = tr("Day %d") % int(entry["day"])
			var names: Array[String] = []
			for kind in entry["kinds"]:
				icons.add_child(
					UiStyle.icon(load(CROP_TEXTURES[int(kind)]) as Texture2D, 24)
				)
				names.append(tr(GameRules.crop_display_name(int(kind))))
			text.text = (
				tr("%s ready today")
				if int(entry["day"]) == current_day
				else tr("%s earliest harvest")
			) % " · ".join(names)
		elif entry.has("overflow"):
			day.text = ""
			text.text = tr("+%d more earliest days") % int(entry["overflow"])
		elif entry["kind"] == &"last_night":
			day.text = tr("Day %d") % int(entry["day"])
			icons.add_child(UiStyle.icon(MOON_ICON, 24))
			text.text = tr("Last night to grow")
		else:
			day.text = tr("Day %d") % int(entry["day"])
			icons.add_child(UiStyle.icon(MARKET_ICON, 24))
			text.text = tr("Town harvest market")
		if index == entries.size() - 1:
			var box := row.get_theme_stylebox("panel") as StyleBoxFlat
			box.border_width_bottom = 0
		_coming_rows.add_child(row)
	var history: Array = _snapshot.get("weather_history", [])
	if history.size() >= current_day:
		_caption.text = tr("Weather is known through today.")
	elif history.is_empty():
		_caption.text = tr("Weather is not recorded yet.")
	else:
		_caption.text = tr("Weather is known through Day %d.") % history.size()
	_legend.text = (
		tr("Pink: today · Gold: market · Moon: last night · Crops: earliest days")
		+ (" " + tr("Earliest days need nightly watering.") if not readiness.is_empty() else "")
	)

func _readiness_markers(current_day: int) -> Dictionary:
	var result: Dictionary = {}
	var farm: Array = _snapshot.get("farm", [])
	for entry_variant in farm:
		var entry: Dictionary = entry_variant
		var crop_variant: Variant = entry.get("crop", null)
		if crop_variant == null:
			continue
		var crop: Dictionary = crop_variant
		var kind := GameRules.CROP_KEYS.find(StringName(crop["kind"]))
		var ready_day := GameRules.earliest_ready_day(kind, int(crop["growth"]), current_day)
		if ready_day >= 1:
			var kinds: Array = result.get(ready_day, [])
			if not kinds.has(kind):
				kinds.append(kind)
				kinds.sort()
			result[ready_day] = kinds
	return result
