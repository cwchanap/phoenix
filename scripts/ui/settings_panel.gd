class_name SettingsPanel
extends Control

signal settings_changed(error: int)

# Window row options, in display order: 1080p windowed, then fullscreen.
const WINDOW_VALUES := [false, true]
const LANGUAGE_LABELS: Array[String] = ["English", "繁體中文", "日本語"]
const ROW_NAMES: Array[String] = ["Music", "Sound", "Window", "Tips", "Language"]
const ROW_ICONS: Array[Texture2D] = [
	preload("res://assets/ui/icons/music.png"),
	preload("res://assets/ui/icons/sound.png"),
	preload("res://assets/ui/icons/window-scale.png"),
	preload("res://assets/ui/icons/tutorial.png"),
	preload("res://assets/ui/icons/dialogue.png"),
]
const SETTINGS_ICON := preload("res://assets/ui/icons/settings.png")
const HEADER_GRADIENT: Array[Color] = [UiStyle.ORANGE, UiStyle.SUN]

var _settings: UiSettings
var _selected_index := 0
var _frame: PhoneFrame
var _rows: Array[PanelContainer] = []
var _row_boxes: Array[StyleBoxFlat] = []
var _row_names: Array[Label] = []
var _row_adjusts: Array[Control] = []
var _music_pips: Array[Panel] = []
var _sound_pips: Array[Panel] = []
var _window_chips: Array[Dictionary] = []
var _tutorial_chips: Array[Dictionary] = []
var _language_chips: Array[Dictionary] = []
var _save_path: Label
var _status: Label
var _pip_off := UiStyle.card(UiStyle.LINE, 4, [0, 0, 0, 0], false)
var _pip_music := UiStyle.card(UiStyle.SUN, 4, [0, 0, 0, 0], false)
var _pip_sound := UiStyle.card(UiStyle.ACCENT_2, 4, [0, 0, 0, 0], false)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
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
	return [&"music", &"sound", &"fullscreen", &"tutorial_cards", &"language"][_selected_index]

func set_status_time(time_text: String) -> void:
	_frame.set_status_time(time_text)

func status_time_text() -> String:
	return _frame.status_time_text()

func save_path_text() -> String:
	return _save_path.text

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
			var current := WINDOW_VALUES.find(_settings.fullscreen)
			var next := posmod(current + delta, WINDOW_VALUES.size())
			error = _settings.set_fullscreen(WINDOW_VALUES[next])
		3:
			error = _settings.set_tutorial_cards(delta > 0)
		4:
			var languages := UiSettings.LANGUAGES
			var next_language := posmod(languages.find(_settings.language) + delta, languages.size())
			error = _settings.set_language(languages[next_language])
			_settings.apply_language()
	if error == OK:
		_status.text = ""
	else:
		_status.text = tr("Could not save settings.")
	_refresh()
	settings_changed.emit(error)

func _refresh() -> void:
	if _settings == null or _rows.is_empty():
		return
	for index in _rows.size():
		var selected := index == _selected_index
		_row_boxes[index].border_color = UiStyle.ACCENT if selected else UiStyle.LINE
		_row_boxes[index].set_border_width_all(2 if selected else 1)
		_row_names[index].add_theme_color_override(
			"font_color", UiStyle.ACCENT_DEEP if selected else UiStyle.INK
		)
		_row_adjusts[index].visible = selected
	_save_path.text = tr("Save file: %s") % SaveRepository.DEFAULT_PATH
	for pip_index in 10:
		_music_pips[pip_index].add_theme_stylebox_override(
			"panel", _pip_music if pip_index < _settings.music else _pip_off
		)
		_sound_pips[pip_index].add_theme_stylebox_override(
			"panel", _pip_sound if pip_index < _settings.sound else _pip_off
		)
	_update_chips(_window_chips, WINDOW_VALUES.find(_settings.fullscreen))
	_update_chips(_tutorial_chips, 0 if _settings.tutorial_cards else 1)
	_update_chips(_language_chips, UiSettings.LANGUAGES.find(_settings.language))

func _update_chips(chips: Array[Dictionary], selected: int) -> void:
	for index in chips.size():
		var is_selected := index == selected
		var box := UiStyle.card(
			UiStyle.ACCENT_SOFT if is_selected else UiStyle.CARD, 10, [9, 4, 9, 4], false
		)
		box.border_color = UiStyle.ACCENT if is_selected else UiStyle.LINE
		box.set_border_width_all(2 if is_selected else 1)
		(chips[index]["chip"] as PanelContainer).add_theme_stylebox_override("panel", box)
		(chips[index]["label"] as Label).add_theme_color_override(
			"font_color", UiStyle.ACCENT_DEEP if is_selected else UiStyle.INK_MUTED
		)

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
	var column := UiStyle.vbox(10)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_app_header())
	for index in ROW_NAMES.size():
		column.add_child(_setting_row(index))
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_footer())

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
	icon_chip.add_child(UiStyle.icon(SETTINGS_ICON, 28))
	var title := UiStyle.label("Settings", 26, UiStyle.CARD, 900)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	return header

func _setting_row(index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "%sRow" % ROW_NAMES[index]
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.HUD_CARD, 16, [12, 10, 12, 10], false)
	box.border_color = UiStyle.LINE
	box.set_border_width_all(1)
	_row_boxes.append(box)
	row.add_theme_stylebox_override("panel", box)
	var hbox := UiStyle.hbox(8)
	row.add_child(hbox)

	var icon_chip := PanelContainer.new()
	icon_chip.name = "IconChip"
	icon_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_chip.custom_minimum_size = Vector2(30, 30)
	icon_chip.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.SOFT, 10, [4, 4, 4, 4], false)
	)
	icon_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_chip)
	icon_chip.add_child(UiStyle.icon(ROW_ICONS[index], 20))

	var name_label := UiStyle.label(ROW_NAMES[index], 15, UiStyle.INK, 800)
	name_label.name = "Name"
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row_names.append(name_label)
	hbox.add_child(name_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var value := _row_value(index)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(value)

	var adjust := UiStyle.hbox(4)
	adjust.name = "Adjust"
	adjust.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	adjust.add_child(UiStyle.keycap("A", true))
	adjust.add_child(UiStyle.keycap("D", true))
	_row_adjusts.append(adjust)
	hbox.add_child(adjust)

	_rows.append(row)
	return row

func _row_value(index: int) -> Control:
	match index:
		0:
			return _pips(_music_pips)
		1:
			return _pips(_sound_pips)
		2:
			return _options(["1080p", "FULL"], _window_chips)
		3:
			return _options(["ON", "OFF"], _tutorial_chips)
		_:
			return _options(LANGUAGE_LABELS, _language_chips, false)

func _pips(target: Array[Panel]) -> HBoxContainer:
	var pips := UiStyle.hbox(4)
	pips.name = "Pips"
	for index in 10:
		var pip := Panel.new()
		pip.name = "Pip_%d" % index
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(14, 11)
		pip.add_theme_stylebox_override("panel", _pip_off)
		pips.add_child(pip)
		target.append(pip)
	return pips

func _options(
	texts: Array,
	target: Array[Dictionary],
	translate := true,
) -> HBoxContainer:
	var options := UiStyle.hbox(6)
	options.name = "Options"
	for index in texts.size():
		var chip := PanelContainer.new()
		chip.name = "Option_%d" % index
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := UiStyle.label(texts[index], 13, UiStyle.INK_MUTED, 800)
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not translate:
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chip.add_child(label)
		options.add_child(chip)
		target.append({"chip": chip, "label": label})
	return options

func _footer() -> HBoxContainer:
	var footer := UiStyle.hbox(10)
	footer.name = "Footer"
	var info := UiStyle.vbox(2)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(info)
	_save_path = UiStyle.label("", 12, UiStyle.INK_MUTED, 600)
	_save_path.name = "SavePath"
	info.add_child(_save_path)
	_status = UiStyle.label("", 12, UiStyle.BAD, 600)
	_status.name = "Status"
	info.add_child(_status)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var done := UiStyle.hbox(8)
	done.name = "Done"
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done.add_child(UiStyle.keycap("Esc", true))
	var done_text := UiStyle.label("DONE", 14, UiStyle.INK_MUTED, 800)
	done_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done.add_child(done_text)
	footer.add_child(done)
	return footer
