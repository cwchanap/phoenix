class_name SleepPanel
extends Control

signal sleep_requested

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    ($Confirm as Button).pressed.connect(_on_confirm_pressed)
    _style_authored_tree(self)
    _apply_authored_style()
    ($Confirm as Button).modulate = Color(1, 1, 1, 0)
    visible = false

func present(snapshot: Dictionary) -> void:
    var day := int(snapshot.get("day", 1))
    var terminal := day == GameRules.MAX_DAY
    ($Boundary as Label).visible = terminal
    ($Boundary as Label).text = (
        "Day 14 — this ends the season and settles the bin."
        if terminal
        else ""
    )
    ($Frame/Footer/ActionText as Label).text = "SLEEP"

func _on_confirm_pressed() -> void:
    sleep_requested.emit()

func _input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed("ui_accept"):
        get_viewport().set_input_as_handled()
        sleep_requested.emit()

func _style_authored_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_authored_tree(child)

func _apply_authored_style() -> void:
    ($Frame as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.PRIMARY, UiStyle.FRAME_BORDER, 2),
    )
    ($Frame/WarningBox as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.WARNING_FILL, UiStyle.GOLD, 1),
    )
    ($Frame/Footer as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0),
    )
    ($Frame/Footer/EscKeycap as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.INSET, UiStyle.BORDER_LIGHT, 1),
    )
    ($Frame/Footer/EnterKeycap as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1),
    )
    UiStyle.text($Frame/Title as Label, 15, UiStyle.CREAM, 800)
    UiStyle.text($Boundary as Label, 9, UiStyle.GOLD, 600)
    UiStyle.text($Frame/Footer/EscKey as Label, 8, UiStyle.TEXT, 800, true)
    UiStyle.text($Frame/Footer/EscText as Label, 9, UiStyle.MUTED, 600)
    UiStyle.text($Frame/Footer/EnterKey as Label, 8, UiStyle.GOLD, 800, true)
    UiStyle.text($Frame/Footer/ActionText as Label, 9, UiStyle.GOLD, 800)
