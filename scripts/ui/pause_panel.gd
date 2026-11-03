class_name PausePanel
extends Control
## The phone home screen (HPA-682): a code-built PhoneFrame over a dimmed
## world, holding a wallpaper, the four app tiles, and the Controls widget.
## It owns presentation only; GameHud feeds it the status time and the
## day/weather summary, and the tiles emit requests GameHud routes.

signal settings_requested
signal resume_requested
signal bag_requested
signal almanac_requested
signal calendar_requested

const BAG_ICON := preload("res://assets/ui/icons/bag.png")
const ALMANAC_ICON := preload("res://assets/ui/icons/almanac.png")
const CALENDAR_ICON := preload("res://assets/ui/icons/calendar.png")
const SETTINGS_ICON := preload("res://assets/ui/icons/settings.png")
const CONTROLS_ICON := preload("res://assets/ui/icons/controls.png")
const SUN_ICON := preload("res://assets/ui/icons/sun.png")
const RAIN_ICON := preload("res://assets/ui/icons/rain.png")

var _frame: PhoneFrame
var _day: Label
var _weather_icon: TextureRect
var _weather: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	visible = false

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"open_settings"):
		settings_requested.emit()
		get_viewport().set_input_as_handled()

## GameHud.render() supplies the session clock already formatted.
func set_status_time(time_text: String) -> void:
	_frame.set_status_time(time_text)

func status_time_text() -> String:
	return _frame.status_time_text()

func set_day_weather(day: int, weather_key: StringName) -> void:
	_day.text = tr("Day %d") % day
	var rainy := weather_key == GameRules.weather_key(GameRules.Weather.RAINY)
	_weather_icon.texture = RAIN_ICON if rainy else SUN_ICON
	_weather.text = "Rainy" if rainy else "Sunny"

## The chip's "Day 1 · Sunny" line, for tests.
func day_weather_text() -> String:
	return "%s · %s" % [_day.text, _weather.text]

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

	var home := PanelContainer.new()
	home.name = "Home"
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_frame.content_mount().add_child(home)
	var wallpaper := PanelContainer.new()
	wallpaper.name = "Wallpaper"
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallpaper.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 24, [0, 0, 0, 0], false)
	)
	wallpaper.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	home.add_child(wallpaper)
	var sky := UiStyle.gradient_rect(UiStyle.HEADER_GRADIENT)
	sky.name = "Gradient"
	wallpaper.add_child(sky)
	wallpaper.sort_children.connect(func() -> void:
		sky.position = Vector2.ZERO
		sky.size = wallpaper.size
	)
	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 24], ["top", 22], ["right", 24], ["bottom", 20]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	home.add_child(layout)
	var column := UiStyle.vbox(16)
	column.name = "Column"
	layout.add_child(column)

	var summary := UiStyle.vbox(10)
	summary.name = "Summary"
	column.add_child(summary)
	var title := UiStyle.label("Paused", 46, UiStyle.CARD, 900)
	title.name = "Title"
	summary.add_child(title)
	var chip := PanelContainer.new()
	chip.name = "DayChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, UiStyle.PILL_RADIUS, [16, 7, 18, 7], false)
	)
	summary.add_child(chip)
	var chip_row := UiStyle.hbox(8)
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(chip_row)
	_day = UiStyle.label("Day 1", 18, UiStyle.INK, 900)
	_day.name = "Day"
	chip_row.add_child(_day)
	_weather_icon = UiStyle.icon(SUN_ICON, 22)
	_weather_icon.name = "WeatherIcon"
	chip_row.add_child(_weather_icon)
	_weather = UiStyle.label("Sunny", 18, UiStyle.INK, 800)
	_weather.name = "Weather"
	chip_row.add_child(_weather)

	var tiles := UiStyle.hbox(18)
	tiles.name = "Tiles"
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(tiles)
	tiles.add_child(_app_tile("Bag", BAG_ICON, "I", UiStyle.ACCENT, bag_requested))
	tiles.add_child(_app_tile("Almanac", ALMANAC_ICON, "B", UiStyle.BLUE, almanac_requested))
	tiles.add_child(_app_tile("Calendar", CALENDAR_ICON, "C", UiStyle.VIOLET, calendar_requested))
	tiles.add_child(_app_tile("Settings", SETTINGS_ICON, "O", UiStyle.ORANGE, settings_requested))

	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_controls_card())

func _app_tile(
	app_name: String,
	icon: Texture2D,
	key: String,
	hue: Color,
	request: Signal,
) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = "%sTile" % app_name
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var column := UiStyle.vbox(8)
	tile.add_child(column)
	var icon_tile := Panel.new()
	icon_tile.name = "Icon"
	icon_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_tile.custom_minimum_size = Vector2(84, 84)
	var icon_box := UiStyle.card(hue.lerp(UiStyle.CARD, 0.82), 22, [0, 0, 0, 0], false)
	icon_box.border_color = hue
	icon_box.set_border_width_all(3)
	icon_tile.add_theme_stylebox_override("panel", icon_box)
	icon_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon_tile)
	var app_icon := UiStyle.icon(icon, 52)
	app_icon.position = Vector2(16, 16)
	app_icon.size = Vector2(52, 52)
	icon_tile.add_child(app_icon)
	var caption := UiStyle.hbox(6)
	caption.name = "Caption"
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(caption)
	caption.add_child(UiStyle.label(app_name, 17, UiStyle.CARD, 900))
	caption.add_child(UiStyle.keycap(key, true))
	tile.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			request.emit()
	)
	return tile

func _controls_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Controls"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.HUD_CARD, 24, [20, 16, 20, 16]))
	var column := UiStyle.vbox(10)
	card.add_child(column)
	var title_row := UiStyle.hbox(10)
	title_row.name = "TitleRow"
	column.add_child(title_row)
	title_row.add_child(UiStyle.icon(CONTROLS_ICON, 24))
	var title := UiStyle.label("CONTROLS", 18, UiStyle.INK, 900)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title)
	column.add_child(_control_row(["W", "A", "S", "D"], "Move · facing picks the target cell"))
	column.add_child(_control_row(["2"], "Cycle the selected seed"))
	column.add_child(_control_row(["Space"], "Space works target tile"))
	column.add_child(_control_row(["E"], "Shop · bed · bin · villagers"))

	var resume := PanelContainer.new()
	resume.name = "Resume"
	resume.mouse_filter = Control.MOUSE_FILTER_STOP
	resume.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resume.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	column.add_child(resume)
	resume.add_child(_control_row(["Esc"], "RESUME"))
	resume.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			resume_requested.emit()
	)
	return card

func _control_row(keys: Array, copy: String) -> HBoxContainer:
	var row := UiStyle.hbox(10)
	var caps := UiStyle.hbox(4)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in keys:
		caps.add_child(UiStyle.keycap(key, true))
	row.add_child(caps)
	var text := UiStyle.label(copy, 15, UiStyle.INK, 700)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	return row
