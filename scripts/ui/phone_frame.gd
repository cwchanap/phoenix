class_name PhoneFrame
extends PanelContainer
## The shared City Pop phone chrome (HPA-682): a dark rounded bezel around
## a light screen carrying a status-bar time, one content mount, and a home
## indicator. Code-built like HudChrome; it owns no app navigation, modal
## state, session data, or input — panels own their content.

const PHONE_SIZE := Vector2(470, 930)

var _status_time: Label
var _content: VBoxContainer

func _init() -> void:
	name = "PhoneFrame"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = PHONE_SIZE
	add_theme_stylebox_override("panel", UiStyle.card(UiStyle.INK, 46, [12, 12, 12, 12]))
	var screen := PanelContainer.new()
	screen.name = "Screen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.SOFT, 34, [0, 0, 0, 0], false))
	add_child(screen)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	screen.add_child(column)

	var status := MarginContainer.new()
	status.name = "StatusBar"
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.custom_minimum_size = Vector2(0, 46)
	for side in [["left", 26], ["top", 12], ["right", 26], ["bottom", 0]]:
		status.add_theme_constant_override("margin_" + side[0], side[1])
	column.add_child(status)
	_status_time = UiStyle.label("06:00", 20, UiStyle.INK, 900)
	_status_time.name = "Time"
	status.add_child(_status_time)

	_content = UiStyle.vbox(0)
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)

	var home := CenterContainer.new()
	home.name = "HomeIndicator"
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.custom_minimum_size = Vector2(0, 30)
	column.add_child(home)
	var bar := Panel.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(150, 6)
	bar.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.INK, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
	)
	home.add_child(bar)

## The mount panels fill with their app content.
func content_mount() -> VBoxContainer:
	return _content

func set_status_time(time_text: String) -> void:
	_status_time.text = time_text

func status_time_text() -> String:
	return _status_time.text
