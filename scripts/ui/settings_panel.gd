class_name SettingsPanel
extends Control

signal settings_changed(error: int)

const WINDOW_VALUES := [1, 2, 3, 4, UiSettings.FULLSCREEN]

var _settings: UiSettings
var _selected_index := 0
var _rows: Array[Panel] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rows = [
		$Frame/Body/MusicRow as Panel,
		$Frame/Body/SoundRow as Panel,
		$Frame/Body/WindowRow as Panel,
		$Frame/Body/TutorialRow as Panel,
	]
	($Frame/Footer/SavePath as Label).text = "Save file: %s" % SaveRepository.DEFAULT_PATH
	_style_tree(self)
	_apply_style()
	visible = false

func open_panel(settings: UiSettings) -> void:
	_settings = settings
	_selected_index = 0
	_refresh()
	visible = true

func present(settings: UiSettings) -> void:
	_settings = settings
	_refresh()

func selected_setting() -> int:
	return _selected_index

func selected_setting_name() -> StringName:
	return [&"music", &"sound", &"window_scale", &"tutorial_cards"][_selected_index]

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"move_up"):
		_selected_index = posmod(_selected_index - 1, _rows.size())
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_down"):
		_selected_index = posmod(_selected_index + 1, _rows.size())
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_left"):
		_adjust(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_right"):
		_adjust(1)
		get_viewport().set_input_as_handled()

func _adjust(delta: int) -> void:
	if _settings == null:
		return
	var error := OK
	match _selected_index:
		0:
			error = _settings.set_music(clampi(_settings.music + delta, 0, 10))
		1:
			error = _settings.set_sound(clampi(_settings.sound + delta, 0, 10))
		2:
			var current := WINDOW_VALUES.find(_settings.window_scale)
			var next := posmod(current + delta, WINDOW_VALUES.size())
			error = _settings.set_window_scale(WINDOW_VALUES[next])
		3:
			error = _settings.set_tutorial_cards(delta > 0)
	if error == OK:
		($Frame/Footer/Status as Label).text = ""
	else:
		($Frame/Footer/Status as Label).text = "Could not save settings."
	_refresh()
	settings_changed.emit(error)

func _refresh() -> void:
	if _settings == null or _rows.is_empty():
		return
	for index in _rows.size():
		var selected := index == _selected_index
		_rows[index].add_theme_stylebox_override(
			"panel", UiStyle.panel(UiStyle.INSET, UiStyle.GOLD if selected else UiStyle.BORDER, 2 if selected else 1)
		)
	UiStyle.text($Frame/Body/MusicRow/Name as Label, 11, UiStyle.CREAM if _selected_index == 0 else UiStyle.TEXT, 800)
	UiStyle.text($Frame/Body/SoundRow/Name as Label, 11, UiStyle.CREAM if _selected_index == 1 else UiStyle.TEXT, 800)
	UiStyle.text($Frame/Body/WindowRow/Name as Label, 11, UiStyle.CREAM if _selected_index == 2 else UiStyle.TEXT, 800)
	UiStyle.text($Frame/Body/TutorialRow/Name as Label, 11, UiStyle.CREAM if _selected_index == 3 else UiStyle.TEXT, 800)
	var music_level := _settings.music
	var sound_level := _settings.sound
	for pip_index in 10:
		(get_node("Frame/Body/MusicRow/Pips/Pip_%d" % pip_index) as ColorRect).color = UiStyle.GOLD if pip_index < music_level else UiStyle.BORDER
		(get_node("Frame/Body/SoundRow/Pips/Pip_%d" % pip_index) as ColorRect).color = UiStyle.BORDER_LIGHT if pip_index < sound_level else UiStyle.BORDER
	_update_window_buttons()
	_update_tutorial_buttons()
	($Frame/Body/MusicRow/Adjust as Control).visible = _selected_index == 0
	($Frame/Body/SoundRow/Adjust as Control).visible = _selected_index == 1
	($Frame/Body/WindowRow/Adjust as Control).visible = _selected_index == 2
	($Frame/Body/TutorialRow/Adjust as Control).visible = _selected_index == 3

func _update_window_buttons() -> void:
	for index in WINDOW_VALUES.size():
		var button := $Frame/Body/WindowRow/Options.get_node("Option_%d" % index) as Panel
		var selected: bool = WINDOW_VALUES[index] == _settings.window_scale
		button.add_theme_stylebox_override(
			"panel", UiStyle.panel(UiStyle.KEYCAP_FILL if selected else UiStyle.INSET, UiStyle.GOLD if selected else UiStyle.BORDER, 1)
		)
		UiStyle.text(button.get_node("Label") as Label, 9, UiStyle.GOLD if selected else UiStyle.MUTED, 800, true)

func _update_tutorial_buttons() -> void:
	var enabled := _settings.tutorial_cards
	for entry in [
		{"node": $Frame/Body/TutorialRow/Options/On as Panel, "selected": enabled},
		{"node": $Frame/Body/TutorialRow/Options/Off as Panel, "selected": not enabled},
	]:
		var button: Panel = entry["node"]
		var selected: bool = entry["selected"]
		button.add_theme_stylebox_override(
			"panel", UiStyle.panel(UiStyle.KEYCAP_FILL if selected else UiStyle.INSET, UiStyle.GOLD if selected else UiStyle.BORDER, 1)
		)
		UiStyle.text(button.get_node("Label") as Label, 9, UiStyle.GOLD if selected else UiStyle.MUTED, 800, true)

func _style_tree(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			UiStyle.text(child as Label)
		elif child is Button:
			UiStyle.button(child as Button)
		_style_tree(child)

func _apply_style() -> void:
	($Frame as Panel).add_theme_stylebox_override(
		"panel", UiStyle.panel(UiStyle.PRIMARY, UiStyle.FRAME_BORDER, 2)
	)
	var header_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
	header_style.border_width_bottom = 2
	($Frame/Header as Panel).add_theme_stylebox_override("panel", header_style)
	var footer_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
	footer_style.border_width_top = 2
	($Frame/Footer as Panel).add_theme_stylebox_override("panel", footer_style)
	UiStyle.text($Frame/Header/Title as Label, 13, UiStyle.CREAM, 800)
	UiStyle.text($Frame/Footer/SavePath as Label, 9, UiStyle.MUTED, 600)
	UiStyle.text($Frame/Footer/Status as Label, 8, UiStyle.RED, 600)
	UiStyle.text($Frame/Footer/DoneText as Label, 10, UiStyle.GOLD, 800)
	for row in _rows:
		row.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.INSET, UiStyle.BORDER, 1))
	for path in ["MusicRow", "SoundRow", "WindowRow", "TutorialRow"]:
		UiStyle.text($Frame/Body.get_node(path + "/Name") as Label, 11, UiStyle.TEXT, 800)
	for path in [
		"Frame/Body/MusicRow/Adjust/Left",
		"Frame/Body/MusicRow/Adjust/Right",
		"Frame/Body/SoundRow/Adjust/Left",
		"Frame/Body/SoundRow/Adjust/Right",
		"Frame/Body/WindowRow/Adjust/Left",
		"Frame/Body/WindowRow/Adjust/Right",
		"Frame/Body/TutorialRow/Adjust/Left",
		"Frame/Body/TutorialRow/Adjust/Right",
	]:
		_style_keycap(get_node(path) as Panel, UiStyle.BORDER_LIGHT, UiStyle.INSET)
	for row_path in ["MusicRow", "SoundRow"]:
		for pip_index in 10:
			(get_node("Frame/Body/%s/Pips/Pip_%d" % [row_path, pip_index]) as ColorRect).color = UiStyle.BORDER
	for option in [$Frame/Body/WindowRow/Options/Option_0 as Panel, $Frame/Body/WindowRow/Options/Option_1 as Panel, $Frame/Body/WindowRow/Options/Option_2 as Panel, $Frame/Body/WindowRow/Options/Option_3 as Panel, $Frame/Body/WindowRow/Options/Option_4 as Panel, $Frame/Body/TutorialRow/Options/On as Panel, $Frame/Body/TutorialRow/Options/Off as Panel]:
		option.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.INSET, UiStyle.BORDER, 1))
	_style_keycap($Frame/Footer/EscKey as Panel, UiStyle.GOLD, UiStyle.KEYCAP_FILL)

func _style_keycap(keycap: Panel, border: Color, fill: Color) -> void:
	keycap.add_theme_stylebox_override("panel", UiStyle.panel(fill, border, 1))
	UiStyle.text(keycap.get_node("Label") as Label, 8, UiStyle.GOLD if border == UiStyle.GOLD else UiStyle.TEXT, 800, true)
