class_name SleepPanel
extends Control

signal sleep_requested

const HEADER_GRADIENT: Array[Color] = [UiStyle.NIGHT, UiStyle.VIOLET]
const BED_ICON := preload("res://assets/ui/icons/bed.png")
const WARNING_ICON := preload("res://assets/ui/icons/warning.png")

var _frame: PhoneFrame
var _alarm_time: Label
var _warning: PanelContainer
var _warning_text: Label
var _confirm: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_confirm.pressed.connect(_on_confirm_pressed)
	visible = false

func present(snapshot: Dictionary) -> void:
	var terminal := int(snapshot.get("day", 1)) == GameRules.MAX_DAY
	_warning.visible = terminal
	_warning_text.text = (
		"Day 14 — this ends the season and settles the bin."
		if terminal
		else ""
	)

func set_status_time(time_text: String) -> void:
	_frame.set_status_time(time_text)

func status_time_text() -> String:
	return _frame.status_time_text()

func alarm_time_text() -> String:
	return _alarm_time.text

func day14_warning_visible() -> bool:
	return _warning.visible

func day14_warning_text() -> String:
	return _warning_text.text

func _on_confirm_pressed() -> void:
	sleep_requested.emit()

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		sleep_requested.emit()

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
	for side in [["left", 20], ["top", 16], ["right", 20], ["bottom", 14]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(14)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_app_header())
	column.add_child(_alarm_card())
	_warning = _warning_card()
	column.add_child(_warning)
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_footer())

	_confirm = UiStyle.action_button("SLEEP")
	_confirm.name = "Confirm"
	_confirm.anchor_left = 0.5
	_confirm.anchor_right = 0.5
	_confirm.anchor_top = 1.0
	_confirm.anchor_bottom = 1.0
	_confirm.offset_left = -110.0
	_confirm.offset_right = 110.0
	_confirm.offset_top = -68.0
	_confirm.offset_bottom = -14.0
	_confirm.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_confirm)

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
	icon_chip.add_child(UiStyle.icon(BED_ICON, 28))
	var title := UiStyle.label("Sleep", 26, UiStyle.CARD, 900)
	title.name = "Title"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	return header

func _alarm_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "AlarmCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.HUD_CARD, 20, [18, 16, 18, 16])
	)
	var column := UiStyle.vbox(8)
	card.add_child(column)

	var tag := PanelContainer.new()
	tag.name = "AlarmTag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.NIGHT, UiStyle.PILL_RADIUS, [12, 3, 12, 3], false)
	)
	column.add_child(tag)
	var tag_label := UiStyle.label("ALARM", 12, UiStyle.CARD, 800)
	tag_label.name = "Label"
	tag.add_child(tag_label)

	_alarm_time = UiStyle.label(
		GameRules.format_time(GameRules.DAY_START_MINUTES), 56, UiStyle.NIGHT, 900
	)
	_alarm_time.name = "AlarmTime"
	_alarm_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_alarm_time)

	var question := UiStyle.label("Sleep until morning?", 15, UiStyle.INK_MUTED, 600)
	question.name = "Question"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(question)
	return card

func _warning_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Warning"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	var box := UiStyle.card(UiStyle.WARN, 14, [12, 10, 12, 10], false)
	box.border_color = UiStyle.SUN
	box.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", box)
	var row := UiStyle.hbox(8)
	card.add_child(row)
	var icon := UiStyle.icon(WARNING_ICON, 20)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_warning_text = UiStyle.label("", 13, UiStyle.WARN_INK, 700)
	_warning_text.name = "Text"
	_warning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_warning_text)
	return card

func _footer() -> HBoxContainer:
	var footer := UiStyle.hbox(8)
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(UiStyle.keycap("Esc", true))
	var cancel := UiStyle.label("not yet", 14, UiStyle.INK_MUTED, 700)
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(cancel)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(18, 0)
	footer.add_child(gap)
	footer.add_child(UiStyle.keycap("Enter", true))
	var action := UiStyle.label("SLEEP", 14, UiStyle.INK_MUTED, 700)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(action)
	return footer
