class_name TitleScreen
extends Control

signal new_game_requested
signal continue_requested

@onready var _new_game_button: Button = $Panel/NewGame as Button
@onready var _continue_button: Button = $Panel/Continue as Button
@onready var _status_label: Label = $Panel/Status/Label as Label

var _continue_available := false
var _selected_index := 0

func _ready() -> void:
    _new_game_button.pressed.connect(func() -> void: new_game_requested.emit())
    _continue_button.pressed.connect(func() -> void: continue_requested.emit())
    _style_tree(self)
    _apply_style()
    set_continue_state(false)
    _refresh_selection()

func set_continue_state(available: bool, status: String = "") -> void:
    _continue_available = available
    _continue_button.disabled = not available
    _status_label.text = status
    ($Panel/Status as Panel).visible = not status.is_empty()
    if not available:
        _selected_index = 0
    _refresh_selection()

func selected_action() -> StringName:
    return &"continue" if _selected_index == 1 else &"new_game"

func _input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down"):
        var delta := -1 if event.is_action_pressed(&"move_up") else 1
        _move_selection(delta)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"ui_accept"):
        if selected_action() == &"new_game":
            new_game_requested.emit()
        elif _continue_available:
            continue_requested.emit()
        get_viewport().set_input_as_handled()

func _move_selection(delta: int) -> void:
    if not _continue_available:
        _selected_index = 0
    else:
        _selected_index = posmod(_selected_index + delta, 2)
    _refresh_selection()

func _refresh_selection() -> void:
    if not is_node_ready():
        return
    _new_game_button.add_theme_stylebox_override(
        "normal",
        UiStyle.panel(
            UiStyle.WARNING_FILL if _selected_index == 0 else UiStyle.INSET,
            UiStyle.GOLD if _selected_index == 0 else UiStyle.BORDER,
            2 if _selected_index == 0 else 1,
        ),
    )
    _continue_button.add_theme_stylebox_override(
        "normal",
        UiStyle.panel(
            Color(0.055, 0.067, 0.09, 0.48) if not _continue_available else UiStyle.INSET,
            UiStyle.GOLD if _selected_index == 1 else UiStyle.BORDER,
            2 if _selected_index == 1 else 1,
        ),
    )
    _continue_button.add_theme_stylebox_override(
        "disabled",
        UiStyle.panel(Color(0.055, 0.067, 0.09, 0.48), Color(0.25, 0.29, 0.35, 0.48), 1),
    )
    UiStyle.text($Panel/NewGame/Label as Label, 14, UiStyle.GOLD if _selected_index == 0 else UiStyle.TEXT, 800)
    UiStyle.text($Panel/Continue/Label as Label, 14, UiStyle.TEXT if _continue_available else UiStyle.MUTED, 800)

func _style_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_tree(child)

func _apply_style() -> void:
    UiStyle.text($Panel/Footer/Choose as Label, 8, UiStyle.MUTED, 700)
    UiStyle.text($Panel/Footer/Version as Label, 8, UiStyle.MUTED, 600, true)
    UiStyle.text(_status_label, 8, UiStyle.RED, 600)
    ($Panel/Status as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(Color(0.20, 0.06, 0.08, 0.70), UiStyle.RED, 1)
    )
    for keycap in [$Panel/Footer/W as Panel, $Panel/Footer/S as Panel]:
        keycap.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.INSET, UiStyle.BORDER_LIGHT, 1))
        UiStyle.text(keycap.get_node("Label") as Label, 8, UiStyle.TEXT, 800, true)
    ($Panel/NewGame/Enter as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1)
    )
    UiStyle.text($Panel/NewGame/Enter/Label as Label, 8, UiStyle.GOLD, 800, true)
    UiStyle.text($Panel/Status/Label as Label, 8, Color("ffb3b3"), 600)
