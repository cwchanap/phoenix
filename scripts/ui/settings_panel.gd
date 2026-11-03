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
const ROW_TINTS: Array[Color] = [
	Color("ff6b9a"),
	Color("ff9f43"),
	Color("3d8bff"),
	UiStyle.LEAF,
	UiStyle.VIOLET,
]

var _settings: UiSettings
var _selected_index := 0
var _frame: PhoneFrame
var _rows: Array[PanelContainer] = []
var _row_boxes: Array[StyleBoxFlat] = []
var _row_names: Array[Label] = []
var _music_slider: Dictionary = {}
var _sound_slider: Dictionary = {}
var _window_chips: Array[Dictionary] = []
var _language_chips: Array[Dictionary] = []
var _tips_on: TextureRect
var _tips_knob: Panel
var _save_path: Label
var _status: Label

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
		_row_boxes[index].border_color = (
			UiStyle.ACCENT if selected else Color(1.0, 1.0, 1.0, 0.0)
		)
		_row_names[index].add_theme_color_override(
			"font_color", UiStyle.ACCENT_DEEP if selected else UiStyle.INK
		)
	_save_path.text = tr("Save file: %s") % SaveRepository.DEFAULT_PATH
	_update_slider(_music_slider, _settings.music)
	_update_slider(_sound_slider, _settings.sound)
	_update_chips(_window_chips, WINDOW_VALUES.find(_settings.fullscreen))
	_update_chips(_language_chips, UiSettings.LANGUAGES.find(_settings.language))
	_tips_on.visible = _settings.tutorial_cards
	_tips_knob.position = Vector2(27 if _settings.tutorial_cards else 3, 3)

func _update_slider(slider: Dictionary, level: int) -> void:
	var fraction := clampf(level / 10.0, 0.0, 1.0)
	(slider["fill"] as Control).anchor_right = fraction
	(slider["knob"] as Control).anchor_left = fraction
	(slider["knob"] as Control).anchor_right = fraction
	(slider["level"] as Label).text = "%d" % level

func _update_chips(chips: Array[Dictionary], selected: int) -> void:
	for index in chips.size():
		var is_selected := index == selected
		(chips[index]["on"] as Control).visible = is_selected
		(chips[index]["label"] as Label).add_theme_color_override(
			"font_color", UiStyle.CARD if is_selected else UiStyle.INK_MUTED
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
	_frame.set_app_header("Settings", "設定")

	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 22], ["top", 10], ["right", 22], ["bottom", 8]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(10)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_section_label("Sound"))
	column.add_child(_group_card("SoundGroup", [0, 1]))
	column.add_child(_section_label("Display"))
	column.add_child(_group_card("DisplayGroup", [2, 3, 4]))
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_note())
	_build_footer()

func _section_label(text_value: String) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = "%sSection" % text_value
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	var label := UiStyle.label(text_value, 14, UiStyle.INK_MUTED, 900)
	label.name = "Label"
	label.uppercase = true
	margin.add_child(label)
	return margin

func _group_card(group_name: String, indices: Array) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = group_name
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(UiStyle.CARD, 20, [16, 8, 16, 8], false)
	box.shadow_color = Color(0.16, 0.04, 0.16, 0.06)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", box)
	var rows := UiStyle.vbox(0)
	rows.name = "Rows"
	card.add_child(rows)
	for index in indices:
		rows.add_child(_setting_row(int(index)))
	return card

func _setting_row(index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "%sRow" % ROW_NAMES[index]
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 14, [4, 4, 4, 4], false)
	box.border_color = Color(1.0, 1.0, 1.0, 0.0)
	box.set_border_width_all(3)
	_row_boxes.append(box)
	row.add_theme_stylebox_override("panel", box)
	var hbox := UiStyle.hbox(14)
	hbox.name = "Line"
	row.add_child(hbox)

	var icon_chip := PanelContainer.new()
	icon_chip.name = "IconChip"
	icon_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_chip.custom_minimum_size = Vector2(40, 40)
	icon_chip.add_theme_stylebox_override(
		"panel", UiStyle.card(ROW_TINTS[index], 11, [7, 7, 7, 7], false)
	)
	icon_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_chip)
	icon_chip.add_child(UiStyle.icon(ROW_ICONS[index], 26))

	var name_label := UiStyle.label(ROW_NAMES[index], 19, UiStyle.INK, 800)
	name_label.name = "Name"
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row_names.append(name_label)
	hbox.add_child(name_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var control := _row_control(index)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(control)

	_rows.append(row)
	return row

func _row_control(index: int) -> Control:
	match index:
		0:
			return _slider_row("Music", _music_slider)
		1:
			return _slider_row("Sound", _sound_slider)
		2:
			return _seg("WindowSeg", ["1080p", "FULL"], _window_chips)
		3:
			return _tips_switch()
		_:
			return _seg("LanguageSeg", LANGUAGE_LABELS, _language_chips, false)

func _slider_row(slider_name: String, target: Dictionary) -> HBoxContainer:
	var wrap := UiStyle.hbox(10)
	wrap.name = "%sControl" % slider_name
	var slider := Control.new()
	slider.name = "%sSlider" % slider_name
	slider.custom_minimum_size = Vector2(190, 28)
	slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(slider)
	var track := Panel.new()
	track.name = "Track"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.anchor_right = 1.0
	track.anchor_top = 0.5
	track.anchor_bottom = 0.5
	track.offset_top = -4.0
	track.offset_bottom = 4.0
	track.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.LINE, 4, [0, 0, 0, 0], false)
	)
	slider.add_child(track)
	var fill := TextureRect.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.texture = UiStyle.rounded_gradient_texture(
		UiStyle.ACCENT_GRADIENT, Vector2i(190, 8), 4
	)
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.anchor_top = 0.5
	fill.anchor_bottom = 0.5
	fill.offset_top = -4.0
	fill.offset_bottom = 4.0
	slider.add_child(fill)
	var knob := Panel.new()
	knob.name = "Knob"
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.anchor_top = 0.5
	knob.anchor_bottom = 0.5
	knob.offset_left = -13.0
	knob.offset_right = 13.0
	knob.offset_top = -13.0
	knob.offset_bottom = 13.0
	knob.grow_horizontal = Control.GROW_DIRECTION_BOTH
	knob.grow_vertical = Control.GROW_DIRECTION_BOTH
	knob.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 13, [0, 0, 0, 0])
	)
	slider.add_child(knob)
	var level := UiStyle.label("0", 17, UiStyle.INK, 900)
	level.name = "%sLevel" % slider_name
	level.custom_minimum_size = Vector2(26, 0)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.add_child(level)
	target["fill"] = fill
	target["knob"] = knob
	target["level"] = level
	return wrap

func _seg(
	seg_name: String,
	texts: Array,
	target: Array[Dictionary],
	translate := true,
) -> PanelContainer:
	var seg := PanelContainer.new()
	seg.name = seg_name
	seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seg.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.SOFT, 12, [3, 3, 3, 3], false)
	)
	var row := UiStyle.hbox(3)
	row.name = "Options"
	seg.add_child(row)
	for index in texts.size():
		var chip := PanelContainer.new()
		chip.name = "Option_%d" % index
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override(
			"panel", UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 9, [11, 5, 11, 5], false)
		)
		var on := TextureRect.new()
		on.name = "On"
		on.mouse_filter = Control.MOUSE_FILTER_IGNORE
		on.texture = UiStyle.rounded_gradient_texture(
			UiStyle.ACCENT_GRADIENT, Vector2i(80, 28), 9
		)
		on.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		on.stretch_mode = TextureRect.STRETCH_SCALE
		on.visible = false
		chip.add_child(on)
		var label := UiStyle.label(texts[index], 13, UiStyle.INK_MUTED, 800)
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not translate:
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chip.add_child(label)
		row.add_child(chip)
		target.append({"chip": chip, "label": label, "on": on})
	return seg

func _tips_switch() -> Control:
	var sw := Control.new()
	sw.name = "TipsSwitch"
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.custom_minimum_size = Vector2(56, 32)
	var track := Panel.new()
	track.name = "Track"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.LINE, 16, [0, 0, 0, 0], false)
	)
	sw.add_child(track)
	_tips_on = TextureRect.new()
	_tips_on.name = "On"
	_tips_on.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tips_on.texture = UiStyle.rounded_gradient_texture(
		UiStyle.ACCENT_GRADIENT, Vector2i(56, 32), 16
	)
	_tips_on.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tips_on.stretch_mode = TextureRect.STRETCH_SCALE
	_tips_on.set_anchors_preset(Control.PRESET_FULL_RECT)
	sw.add_child(_tips_on)
	_tips_knob = Panel.new()
	_tips_knob.name = "Knob"
	_tips_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tips_knob.position = Vector2(27, 3)
	_tips_knob.size = Vector2(26, 26)
	_tips_knob.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 13, [0, 0, 0, 0])
	)
	sw.add_child(_tips_knob)
	return sw

func _note() -> VBoxContainer:
	var info := UiStyle.vbox(2)
	info.name = "NoteRow"
	_save_path = UiStyle.label("", 13, UiStyle.INK_MUTED, 700)
	_save_path.name = "SavePath"
	info.add_child(_save_path)
	_status = UiStyle.label("", 13, UiStyle.BAD, 700)
	_status.name = "Status"
	info.add_child(_status)
	return info

func _build_footer() -> void:
	var footer := _frame.footer_mount()
	var row_caps := UiStyle.hbox(4)
	row_caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["W", "S"]:
		row_caps.add_child(UiStyle.keycap(key, true))
	footer.add_child(row_caps)
	var row_hint := UiStyle.label("row", 15, UiStyle.INK_MUTED, 800)
	row_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(row_hint)
	var change_caps := UiStyle.hbox(4)
	change_caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for key in ["A", "D"]:
		change_caps.add_child(UiStyle.keycap(key, true))
	footer.add_child(change_caps)
	var change_hint := UiStyle.label("change", 15, UiStyle.INK_MUTED, 800)
	change_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(change_hint)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var done_cap := UiStyle.keycap("Esc", true)
	done_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(done_cap)
	var done := UiStyle.label("done", 15, UiStyle.INK_MUTED, 800)
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(done)
