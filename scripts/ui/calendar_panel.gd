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
const CALENDAR_ICON := preload("res://assets/ui/icons/calendar.png")
const MARKET_ICON := preload("res://assets/ui/icons/market.png")
const HEADER_GRADIENT: Array[Color] = [UiStyle.VIOLET, UiStyle.ACCENT]

var _snapshot: Dictionary = {}
var _frame: PhoneFrame
var _cells: Array[Dictionary] = []
var _day_states: Array[Dictionary] = []
var _market_value: Label
var _coming_up_market: Label
var _legend: Label

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

## Read-only seam for tests: the presented state of one day cell.
func day_state(day: int) -> Dictionary:
	if day < 1 or day > _day_states.size():
		return {}
	return _day_states[day - 1]

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
	column.add_child(_grid_card())
	column.add_child(_coming_up_card())
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
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
	icon_chip.add_child(UiStyle.icon(CALENDAR_ICON, 28))
	var title := UiStyle.label("Calendar", 26, UiStyle.CARD, 900)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var badge := PanelContainer.new()
	badge.name = "MarketBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override(
		"panel", UiStyle.card(Color(1.0, 1.0, 1.0, 0.22), UiStyle.PILL_RADIUS, [12, 5, 14, 5], false)
	)
	row.add_child(badge)
	var badge_row := UiStyle.hbox(6)
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge.add_child(badge_row)
	badge_row.add_child(UiStyle.icon(MARKET_ICON, 16))
	_market_value = UiStyle.label("", 14, UiStyle.CARD, 900)
	_market_value.name = "MarketValue"
	badge_row.add_child(_market_value)
	return header

func _grid_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Grid"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 20, [12, 12, 12, 12])
	)
	var grid := GridContainer.new()
	grid.name = "Days"
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	card.add_child(grid)
	for day in range(1, GameRules.MAX_DAY + 1):
		var cell := _day_cell(day)
		grid.add_child(cell["cell"])
		_cells.append(cell)
		_day_states.append({})
	return card

func _day_cell(day: int) -> Dictionary:
	var cell := PanelContainer.new()
	cell.name = "Day_%02d" % day
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.custom_minimum_size = Vector2(64, 100)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UiStyle.card(UiStyle.CARD, 12, [6, 5, 6, 5], false)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", box)
	var column := UiStyle.vbox(2)
	column.name = "Rows"
	cell.add_child(column)
	var top := UiStyle.hbox(3)
	top.name = "Top"
	column.add_child(top)
	var day_label := UiStyle.label("%d" % day, 15, UiStyle.INK_MUTED, 800)
	day_label.name = "Day"
	top.add_child(day_label)
	var top_spacer := Control.new()
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	var weather := UiStyle.icon(null, 16)
	weather.name = "Weather"
	weather.visible = false
	weather.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(weather)
	var market := UiStyle.icon(MARKET_ICON, 13)
	market.name = "Market"
	market.visible = false
	market.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(market)

	var status := UiStyle.hbox(3)
	status.name = "Status"
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.custom_minimum_size = Vector2(0, 15)
	column.add_child(status)
	var today := UiStyle.label("TODAY", 10, UiStyle.ACCENT, 900)
	today.name = "Today"
	today.visible = false
	status.add_child(today)

	var markers := UiStyle.hbox(3)
	markers.name = "Markers"
	markers.alignment = BoxContainer.ALIGNMENT_CENTER
	markers.custom_minimum_size = Vector2(0, 13)
	column.add_child(markers)
	var market_label := UiStyle.label("MARKET", 9, UiStyle.WARN_INK, 900)
	market_label.name = "MarketLabel"
	market_label.visible = false
	markers.add_child(market_label)
	var last_night := UiStyle.label("LAST NIGHT", 8, UiStyle.INK_MUTED, 800)
	last_night.name = "LastNight"
	last_night.visible = false
	markers.add_child(last_night)

	var readiness_icons := UiStyle.hbox(3)
	readiness_icons.name = "ReadinessIcons"
	readiness_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	readiness_icons.custom_minimum_size = Vector2(0, 15)
	column.add_child(readiness_icons)
	var readiness_icon := UiStyle.icon(null, 14)
	readiness_icon.name = "ReadinessIcon"
	readiness_icon.visible = false
	readiness_icons.add_child(readiness_icon)
	var multi_icons: Array[TextureRect] = []
	for multi_index in range(3):
		var multi_icon := UiStyle.icon(null, 12)
		multi_icon.name = "ReadinessMultiIcon_%d" % (multi_index + 1)
		multi_icon.visible = false
		readiness_icons.add_child(multi_icon)
		multi_icons.append(multi_icon)

	var readiness_label_row := UiStyle.hbox(0)
	readiness_label_row.name = "ReadinessLabelRow"
	readiness_label_row.alignment = BoxContainer.ALIGNMENT_CENTER
	readiness_label_row.custom_minimum_size = Vector2(0, 11)
	column.add_child(readiness_label_row)
	var readiness_label := UiStyle.label("EARLIEST", 8, UiStyle.LEAF_DEEP, 800)
	readiness_label.name = "ReadinessLabel"
	readiness_label.visible = false
	readiness_label_row.add_child(readiness_label)
	return {
		"cell": cell,
		"box": box,
		"day": day_label,
		"weather": weather,
		"today": today,
		"market": market,
		"market_label": market_label,
		"last_night": last_night,
		"readiness_icon": readiness_icon,
		"readiness_label": readiness_label,
		"multi_icons": multi_icons,
	}

func _coming_up_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "ComingUp"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 18, [14, 10, 14, 12])
	)
	var column := UiStyle.vbox(6)
	card.add_child(column)
	var title := UiStyle.label("Coming Up", 14, UiStyle.INK_MUTED, 800)
	title.name = "Title"
	column.add_child(title)
	var market_row := UiStyle.hbox(8)
	market_row.name = "MarketRow"
	column.add_child(market_row)
	var market_icon := UiStyle.icon(MARKET_ICON, 20)
	market_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	market_row.add_child(market_icon)
	_coming_up_market = UiStyle.label("", 16, UiStyle.WARN_INK, 900)
	_coming_up_market.name = "Value"
	_coming_up_market.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	market_row.add_child(_coming_up_market)
	_legend = UiStyle.label("", 12, UiStyle.INK_MUTED, 600)
	_legend.name = "Legend"
	column.add_child(_legend)
	return card

func _footer_hint() -> HBoxContainer:
	var footer := UiStyle.hbox(8)
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(UiStyle.keycap("C", true))
	var close := UiStyle.label("close", 14, UiStyle.INK_MUTED, 700)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(close)
	return footer

func _update_calendar() -> void:
	if _frame == null:
		return
	var current_day := int(_snapshot.get("day", 1))
	var market_text := (
		"MARKET TODAY"
		if current_day >= GameRules.MAX_DAY
		else tr("%d DAYS TO MARKET") % (GameRules.MAX_DAY - current_day)
	)
	_market_value.text = market_text
	_coming_up_market.text = market_text
	var history: Array = _snapshot.get("weather_history", [])
	var readiness := _readiness_markers(current_day)
	for index in range(_cells.size()):
		var day := index + 1
		var cell: Dictionary = _cells[index]
		var is_today := day == current_day
		var is_market := day == GameRules.MAX_DAY
		var combined := is_today and is_market
		var box := cell["box"] as StyleBoxFlat
		box.bg_color = (
			UiStyle.WARN
			if is_market
			else UiStyle.ACCENT_SOFT if is_today else UiStyle.CARD
		)
		box.border_color = (
			UiStyle.SUN
			if is_market
			else UiStyle.ACCENT if is_today else UiStyle.LINE
		)
		box.set_border_width_all(2 if is_today or is_market else 1)
		var day_label := cell["day"] as Label
		day_label.text = "%d" % day
		day_label.add_theme_color_override(
			"font_color",
			UiStyle.WARN_INK if is_market else UiStyle.ACCENT if is_today else UiStyle.INK_MUTED,
		)
		(cell["today"] as Label).visible = is_today
		(cell["market"] as TextureRect).visible = is_market
		(cell["market_label"] as Label).visible = is_market
		var is_last_night := day == GameRules.MAX_DAY - 1
		(cell["last_night"] as Label).visible = is_last_night
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
		(cell["readiness_label"] as Label).visible = not crop_kinds.is_empty()
		_day_states[index] = {
			"today": is_today,
			"market": is_market,
			"combined": combined,
			"last_night": is_last_night,
			"weather_known": weather_known,
			"readiness_kinds": crop_kinds.duplicate(),
			"readiness_icon_path": CROP_TEXTURES[int(crop_kinds[0])] if single else "",
			"readiness_text": "EARLIEST" if not crop_kinds.is_empty() else "",
		}
	var history_day := mini(history.size(), GameRules.MAX_DAY)
	_legend.text = tr("KNOWN WEATHER THROUGH DAY %d · EARLIEST READINESS") % history_day

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
