class_name PausePanel
extends Control

signal settings_requested
signal resume_requested

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	($Frame/Footer/SettingsButton as Button).pressed.connect(func() -> void:
		settings_requested.emit()
	)
	($Frame/Footer/ResumeButton as Button).pressed.connect(func() -> void:
		resume_requested.emit()
	)
	_style_tree(self)
	_apply_style()
	visible = false

func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"open_settings"):
		settings_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()

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
	UiStyle.text($Frame/MoveText as Label, 10, UiStyle.TEXT, 700)
	UiStyle.text($Frame/ActionText as Label, 10, UiStyle.TEXT, 700)
	UiStyle.text($Frame/InteractText as Label, 10, UiStyle.TEXT, 700)
	UiStyle.text($Frame/ShortcutText as Label, 10, UiStyle.GOLD, 700)
	UiStyle.text($Frame/Footer/SettingsText as Label, 9, UiStyle.MUTED, 600)
	UiStyle.text($Frame/Footer/ResumeText as Label, 10, UiStyle.GOLD, 800)
	for keycap_path in [
		"Frame/MoveKeys/W",
		"Frame/MoveKeys/A",
		"Frame/MoveKeys/S",
		"Frame/MoveKeys/D",
		"Frame/ActionKeys/One",
		"Frame/ActionKeys/Two",
		"Frame/ActionKeys/Three",
		"Frame/ActionKeys/Four",
		"Frame/SpaceKey",
		"Frame/InteractKey",
	]:
		_style_keycap(get_node(keycap_path) as Panel, UiStyle.BORDER_LIGHT, UiStyle.INSET)
	for keycap_path in ["Frame/ShortcutKeys/I", "Frame/ShortcutKeys/B", "Frame/ShortcutKeys/C"]:
		_style_keycap(get_node(keycap_path) as Panel, UiStyle.GOLD, UiStyle.KEYCAP_FILL)
	_style_keycap($Frame/Footer/SettingsKey as Panel, UiStyle.BORDER_LIGHT, UiStyle.INSET)
	_style_keycap($Frame/Footer/ResumeKey as Panel, UiStyle.GOLD, UiStyle.KEYCAP_FILL)
	for button in [$Frame/Footer/SettingsButton as Button, $Frame/Footer/ResumeButton as Button]:
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color.TRANSPARENT
		transparent.set_border_width_all(0)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, transparent)
	for label_path in [
		"Frame/MoveKeys/W/Label",
		"Frame/MoveKeys/A/Label",
		"Frame/MoveKeys/S/Label",
		"Frame/MoveKeys/D/Label",
		"Frame/ActionKeys/One/Label",
		"Frame/ActionKeys/Two/Label",
		"Frame/ActionKeys/Three/Label",
		"Frame/ActionKeys/Four/Label",
		"Frame/SpaceKey/Label",
		"Frame/InteractKey/Label",
	]:
		UiStyle.text(get_node(label_path) as Label, 8, UiStyle.TEXT, 800, true)
	for label_path in [
		"Frame/ShortcutKeys/I/Label",
		"Frame/ShortcutKeys/B/Label",
		"Frame/ShortcutKeys/C/Label",
		"Frame/Footer/SettingsKey/Label",
		"Frame/Footer/ResumeKey/Label",
	]:
		UiStyle.text(get_node(label_path) as Label, 8, UiStyle.GOLD, 800, true)

func _style_keycap(keycap: Panel, border: Color, fill: Color) -> void:
	keycap.add_theme_stylebox_override("panel", UiStyle.panel(fill, border, 1))
