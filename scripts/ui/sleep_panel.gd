class_name SleepPanel
extends Control

signal sleep_requested

const BED_ICON := preload("res://assets/ui/icons/bed.png")
const WARNING_ICON := preload("res://assets/ui/icons/warning.png")
const ALARM_BG := Color("141a2b")
const ALARM_CARD := Color("1f2740")
const MUTED_DARK := Color("9aa6c4")
const SUB_DARK := Color("b6c0da")
const HOME_SLATE := Color("5a6584")

var _frame: PhoneFrame
var _alarm_time: Label
var _wake_day: Label
var _warning: PanelContainer
var _warning_text: Label
var _confirm: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_confirm.pressed.connect(_on_confirm_pressed)
	visible = false

func present(snapshot: Dictionary) -> void:
	var day := int(snapshot.get("day", 1))
	var terminal := day == GameRules.MAX_DAY
	_warning.visible = terminal
	_warning_text.text = (
		"Day 14 — this ends the season and settles the bin."
		if terminal
		else ""
	)
	_wake_day.text = tr("Day %d · wake up") % mini(day + 1, GameRules.MAX_DAY)
	_wake_day.visible = not terminal

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
	_frame.set_screen_backplate(null, ALARM_BG, UiStyle.CARD, HOME_SLATE)
	_frame.set_app_header("Alarm", "アラーム", [ALARM_BG, ALARM_BG])

	var layout := MarginContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["left", 22], ["top", 0], ["right", 22], ["bottom", 0]]:
		layout.add_theme_constant_override("margin_" + side[0], side[1])
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.content_mount().add_child(layout)
	var column := UiStyle.vbox(16)
	column.name = "Column"
	layout.add_child(column)

	column.add_child(_alarm_card())
	column.add_child(_prompt())
	_warning = _warning_card()
	column.add_child(_warning)
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
	var actions := UiStyle.vbox(10)
	actions.name = "Actions"
	footer.add_child(actions)
	var trail := Control.new()
	trail.name = "Trail"
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(trail)
	_confirm = UiStyle.primary_action("Enter", "Sleep")
	_confirm.name = "Confirm"
	_confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.add_child(_confirm)
	var ghost := UiStyle.hbox(8)
	ghost.name = "CancelRow"
	ghost.alignment = BoxContainer.ALIGNMENT_CENTER
	ghost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var escape := UiStyle.keycap("Esc", true)
	escape.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ghost.add_child(escape)
	var cancel := UiStyle.label("not yet", 19, SUB_DARK, 800)
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ghost.add_child(cancel)
	actions.add_child(ghost)

func _alarm_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "AlarmCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(ALARM_CARD, 24, [24, 22, 24, 22], false)
	)
	var row := UiStyle.hbox(10)
	card.add_child(row)
	var column := UiStyle.vbox(6)
	row.add_child(column)
	_alarm_time = UiStyle.label(
		GameRules.format_time(GameRules.DAY_START_MINUTES), 72, UiStyle.CARD, 900
	)
	_alarm_time.name = "AlarmTime"
	column.add_child(_alarm_time)
	_wake_day = UiStyle.label("", 17, MUTED_DARK, 700)
	_wake_day.name = "WakeDay"
	column.add_child(_wake_day)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var toggle := _alarm_switch()
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(toggle)
	return card

func _alarm_switch() -> Control:
	var toggle := Control.new()
	toggle.name = "AlarmSwitch"
	toggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toggle.custom_minimum_size = Vector2(56, 32)
	var track := TextureRect.new()
	track.name = "Track"
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.texture = UiStyle.rounded_gradient_texture(
		UiStyle.ACCENT_GRADIENT, Vector2i(56, 32), 16
	)
	track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	track.stretch_mode = TextureRect.STRETCH_SCALE
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	toggle.add_child(track)
	var knob := Panel.new()
	knob.name = "Knob"
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.position = Vector2(27, 3)
	knob.size = Vector2(26, 26)
	knob.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.CARD, 13, [0, 0, 0, 0], false)
	)
	toggle.add_child(knob)
	return toggle

func _prompt() -> VBoxContainer:
	var prompt := UiStyle.vbox(8)
	prompt.name = "Prompt"
	prompt.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var icon_row := UiStyle.hbox(0)
	icon_row.name = "IconRow"
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt.add_child(icon_row)
	icon_row.add_child(UiStyle.icon(BED_ICON, 96))
	var question := UiStyle.label("Sleep until morning?", 32, UiStyle.CARD, 900)
	question.name = "Question"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(question)
	var hint := UiStyle.label("Crops you watered today grow overnight.", 18, SUB_DARK, 600)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_child(hint)
	return prompt

func _warning_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Warning"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	card.add_theme_stylebox_override(
		"panel", UiStyle.card(UiStyle.WARN, 16, [16, 12, 16, 12], false)
	)
	var row := UiStyle.hbox(12)
	card.add_child(row)
	var icon := UiStyle.icon(WARNING_ICON, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_warning_text = UiStyle.label("", 18, UiStyle.WARN_INK, 700)
	_warning_text.name = "Text"
	_warning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warning_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_warning_text)
	return card
