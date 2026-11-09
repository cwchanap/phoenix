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

const TITLE_WALLPAPER := preload("res://assets/ui/backgrounds/title.png")
const BAG_ICON := preload("res://assets/ui/icons/bag.png")
const ALMANAC_ICON := preload("res://assets/ui/icons/almanac.png")
const CALENDAR_ICON := preload("res://assets/ui/icons/calendar.png")
const SETTINGS_ICON := preload("res://assets/ui/icons/settings.png")
const SUN_ICON := preload("res://assets/ui/icons/sun.png")
const RAIN_ICON := preload("res://assets/ui/icons/rain.png")
const BAG_HUE := Color("ff9f43")
const SETTINGS_HUE := Color("8a94a8")

var _frame: PhoneFrame
var _day: Label
var _weather_icon: TextureRect
var _weather: Label
var _paused_tail: Label
var _lock_time: Label

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
	_lock_time.text = time_text

func status_time_text() -> String:
	return _frame.status_time_text()

func set_day_weather(day: int, weather_key: StringName) -> void:
	_day.text = tr("Day %d") % day
	var rainy := weather_key == GameRules.weather_key(GameRules.Weather.RAINY)
	_weather_icon.texture = RAIN_ICON if rainy else SUN_ICON
	_weather.text = "Rainy" if rainy else "Sunny"
	_paused_tail.text = "· %s" % tr("Paused")

## The chip's "Day 1 · Sunny" line, for tests.
func day_weather_text() -> String:
	return "%s · %s" % [_day.text, _weather.text]

func _build() -> void:
	_frame = UiStyle.phone_mount(self)
	_frame.set_screen_backplate(
		UiStyle.wallpaper_texture(
			TITLE_WALLPAPER,
			Vector2i(
				int(PhoneFrame.PHONE_SIZE.x) - 28,
				int(PhoneFrame.PHONE_SIZE.y) - 28,
			),
			PhoneFrame.SCREEN_RADIUS,
			Color(10.0 / 255.0, 10.0 / 255.0, 30.0 / 255.0, 0.25),
			Color(10.0 / 255.0, 10.0 / 255.0, 30.0 / 255.0, 0.7),
		)
	)

	var home := PanelContainer.new()
	home.name = "Home"
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_frame.content_mount().add_child(home)
	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 22], ["top", 12], ["right", 22], ["bottom", 10]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	home.add_child(layout)
	var column := UiStyle.vbox(22)
	column.name = "Column"
	layout.add_child(column)

	var lock := UiStyle.vbox(2)
	lock.name = "LockBlock"
	column.add_child(lock)
	var day_row := UiStyle.hbox(8)
	day_row.name = "DayLine"
	lock.add_child(day_row)
	_day = UiStyle.shadowed_label("Day 1", 22, 800)
	_day.name = "Day"
	day_row.add_child(_day)
	_weather_icon = UiStyle.icon(SUN_ICON, 22)
	_weather_icon.name = "WeatherIcon"
	_weather_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	day_row.add_child(_weather_icon)
	_weather = UiStyle.shadowed_label("Sunny", 22, 800)
	_weather.name = "Weather"
	day_row.add_child(_weather)
	_paused_tail = UiStyle.shadowed_label("· Paused", 22, 800)
	_paused_tail.name = "PausedTail"
	day_row.add_child(_paused_tail)
	_lock_time = UiStyle.shadowed_label("09:20", 76, 900)
	_lock_time.name = "LockTime"
	lock.add_child(_lock_time)

	var tiles := UiStyle.hbox(18)
	tiles.name = "HomeGrid"
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(tiles)
	tiles.add_child(_app_tile("Bag", BAG_ICON, "I", BAG_HUE, bag_requested))
	tiles.add_child(_app_tile("Almanac", ALMANAC_ICON, "B", UiStyle.LEAF, almanac_requested))
	tiles.add_child(_app_tile("Calendar", CALENDAR_ICON, "C", UiStyle.CARD, calendar_requested))
	tiles.add_child(_app_tile("Settings", SETTINGS_ICON, "O", SETTINGS_HUE, settings_requested))

	column.add_child(_controls_card())
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var footer := _frame.footer_mount()
	var lead := Control.new()
	lead.name = "Lead"
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(lead)
	var actions := UiStyle.vbox(8)
	actions.name = "Actions"
	footer.add_child(actions)
	var trail := Control.new()
	trail.name = "Trail"
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(trail)
	var resume := UiStyle.primary_action("Esc", "Back to the farm")
	resume.name = "Resume"
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.add_child(resume)
	resume.pressed.connect(func() -> void: resume_requested.emit())

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
	var column := UiStyle.vbox(6)
	tile.add_child(column)
	var icon_slot := Control.new()
	icon_slot.name = "IconSlot"
	icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.custom_minimum_size = Vector2(88, 88)
	icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon_slot)
	var icon_tile := Panel.new()
	icon_tile.name = "Icon"
	icon_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_tile.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_tile.add_theme_stylebox_override("panel", UiStyle.card(hue, 24))
	icon_slot.add_child(icon_tile)
	var app_icon := UiStyle.icon(icon, 64)
	app_icon.name = "AppIcon"
	app_icon.position = Vector2(12, 12)
	icon_tile.add_child(app_icon)
	var badge := UiStyle.keycap(key, true)
	badge.name = "KeyBadge"
	badge.position = Vector2(66, -8)
	icon_slot.add_child(badge)
	var caption := UiStyle.shadowed_label(app_name, 15, 800)
	caption.name = "Name"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var click := _click_area()
	tile.add_child(click)
	click.pressed.connect(func() -> void: request.emit())
	return tile

func _click_area() -> Button:
	var button := Button.new()
	button.name = "ClickArea"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	return button

func _controls_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Controls"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.HUD_CARD, 24, [20, 16, 20, 16]))
	var column := UiStyle.vbox(10)
	card.add_child(column)
	var title := UiStyle.label("CONTROLS", 14, UiStyle.INK_MUTED, 900)
	title.name = "Title"
	column.add_child(title)
	column.add_child(_control_row(["W", "A", "S", "D"], "Walk; you face the tile you'll work"))
	column.add_child(_control_row(["Space"], "Till, plant, water or harvest. Hold to keep going.", true))
	column.add_child(_control_row(["2"], "Switch seed"))
	column.add_child(_control_row(["E"], "Talk, shop, bin, bed, truck"))
	return card

func _control_row(keys: Array, copy: String, accent := false) -> HBoxContainer:
	var row := UiStyle.hbox(10)
	var caps := UiStyle.hbox(4)
	caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in keys:
		caps.add_child(UiStyle.keycap(key, true, accent))
	row.add_child(caps)
	var text := UiStyle.label(copy, 15, UiStyle.INK, 700)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text)
	return row
