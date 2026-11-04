class_name TitleScreen
extends Control

signal new_game_requested
signal continue_requested

const BACKGROUND := preload("res://assets/ui/backgrounds/title.png")
const LOGO := preload("res://assets/ui/logo/phoenix.png")
const GROWTH_ICON := preload("res://assets/ui/icons/growth.png")
const SAVE_ICON := preload("res://assets/ui/icons/save.png")
const WARNING_ICON := preload("res://assets/ui/icons/warning.png")

var _continue_available := false
var _selected_index := 0
var _new_game_button: Button
var _continue_button: Button
var _new_game_gradient: PanelContainer
var _continue_gradient: PanelContainer
var _new_game_label: Label
var _continue_label: Label
var _new_game_keycap: PanelContainer
var _continue_keycap: PanelContainer
var _status_pill: PanelContainer
var _status_label: Label

func _ready() -> void:
    _build()
    _new_game_button.pressed.connect(func() -> void: new_game_requested.emit())
    _continue_button.pressed.connect(func() -> void: continue_requested.emit())
    set_continue_state(false)
    _refresh_selection()

func set_continue_state(available: bool, status: String = "") -> void:
    _continue_available = available
    _continue_button.disabled = not available
    _status_label.text = status
    _status_pill.visible = not status.is_empty()
    if not available:
        _selected_index = 0
    _refresh_selection()

func selected_action() -> StringName:
    return &"continue" if _selected_index == 1 else &"new_game"

func status_text() -> String:
    return _status_label.text

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
    var new_selected := _selected_index == 0
    var continue_selected := _selected_index == 1
    _new_game_gradient.visible = new_selected
    _continue_gradient.visible = continue_selected
    _new_game_label.add_theme_color_override("font_color", UiStyle.CARD)
    _continue_label.add_theme_color_override(
        "font_color",
        UiStyle.CARD if _continue_available else Color(1.0, 1.0, 1.0, 0.45),
    )
    _new_game_keycap.visible = new_selected
    _continue_keycap.visible = continue_selected

func _build() -> void:
    var background := TextureRect.new()
    background.name = "Background"
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.texture = BACKGROUND
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(background)

    var shade := TextureRect.new()
    shade.name = "Shade"
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.texture = _left_fade()
    shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    shade.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(shade)

    var logo := TextureRect.new()
    logo.name = "Logo"
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    logo.position = Vector2(130, 130)
    logo.size = Vector2(600, 600.0 * LOGO.get_size().y / LOGO.get_size().x)
    logo.texture = LOGO
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    add_child(logo)

    var menu := UiStyle.vbox(12)
    menu.name = "Menu"
    menu.position = Vector2(140, 470)
    menu.size = Vector2(520, 420)
    add_child(menu)

    var new_row := _action_row("NewGame", GROWTH_ICON, "NEW GAME")
    _new_game_button = new_row["button"]
    _new_game_gradient = new_row["gradient"]
    _new_game_label = new_row["label"]
    _new_game_keycap = new_row["keycap"]
    menu.add_child(_new_game_button)
    var continue_row := _action_row("Continue", SAVE_ICON, "CONTINUE")
    _continue_button = continue_row["button"]
    _continue_gradient = continue_row["gradient"]
    _continue_label = continue_row["label"]
    _continue_keycap = continue_row["keycap"]
    menu.add_child(_continue_button)

    _status_pill = PanelContainer.new()
    _status_pill.name = "Status"
    _status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _status_pill.add_theme_stylebox_override(
        "panel", UiStyle.card(UiStyle.WARN, 14, [16, 10, 16, 10], false)
    )
    var status_row := UiStyle.hbox(10)
    status_row.name = "Row"
    _status_pill.add_child(status_row)
    var status_icon := UiStyle.icon(WARNING_ICON, 32)
    status_icon.name = "Icon"
    status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    status_row.add_child(status_icon)
    _status_label = UiStyle.label("", 20, UiStyle.WARN_INK, 700)
    _status_label.name = "Label"
    _status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_row.add_child(_status_label)
    menu.add_child(_status_pill)

    var footer := UiStyle.hbox(16)
    footer.name = "Footer"
    add_child(footer)
    UiStyle.pin(footer, CORNER_BOTTOM_LEFT, Vector2(160, 40))
    var caps := UiStyle.hbox(4)
    caps.name = "Caps"
    caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(caps)
    caps.add_child(UiStyle.keycap("W", true))
    caps.add_child(UiStyle.keycap("S", true))
    var choose := UiStyle.label("choose", 16, Color(1.0, 1.0, 1.0, 0.7), 700)
    choose.name = "Choose"
    choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(choose)
    var version := UiStyle.label(
        "Godot 4.7.1 · 1080p", 16, Color(1.0, 1.0, 1.0, 0.7), 700
    )
    version.name = "Version"
    version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(version)

func _action_row(
    row_name: String, icon_texture: Texture2D, text_value: String
) -> Dictionary:
    var button := Button.new()
    button.name = row_name
    button.custom_minimum_size = Vector2(520, 80)
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var normal := UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 20, [0, 0, 0, 0], false)
    var hover := UiStyle.card(Color(1.0, 1.0, 1.0, 0.14), 20, [0, 0, 0, 0], false)
    var pressed := UiStyle.card(Color(1.0, 1.0, 1.0, 0.22), 20, [0, 0, 0, 0], false)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", normal)
    button.add_theme_stylebox_override("disabled", normal)

    var gradient := UiStyle.gradient_surface(UiStyle.ACCENT_GRADIENT, 20)
    gradient.name = "Gradient"
    gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
    gradient.visible = false
    var gradient_box := gradient.get_theme_stylebox("panel") as StyleBoxFlat
    gradient_box.shadow_size = 18
    gradient_box.shadow_offset = Vector2(0, 12)
    gradient_box.shadow_color = Color(1.0, 0.24, 0.5, 0.38)
    button.add_child(gradient)

    var icon := UiStyle.icon(icon_texture, 48)
    icon.name = "Icon"
    icon.position = Vector2(24, 16)
    icon.size = Vector2(48, 48)
    button.add_child(icon)

    var label := UiStyle.label(text_value, 30, UiStyle.CARD, 900)
    label.name = "Label"
    label.position = Vector2(88, 0)
    label.size = Vector2(370, 80)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    button.add_child(label)

    var keycap := UiStyle.translucent_keycap("Enter")
    keycap.name = "Keycap"
    keycap.visible = false
    button.add_child(keycap)
    keycap.reset_size()
    keycap.position = Vector2(496 - keycap.size.x, (80 - keycap.size.y) / 2.0)

    return {"button": button, "gradient": gradient, "label": label, "keycap": keycap}

func _left_fade() -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.58])
    gradient.colors = PackedColorArray([
        Color(0.059, 0.039, 0.137, 0.78),
        Color(0.059, 0.039, 0.137, 0.5),
        Color(0.059, 0.039, 0.137, 0.0),
    ])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 1920
    texture.height = 1080
    texture.fill_from = Vector2(0, 0.5)
    texture.fill_to = Vector2(1, 0.5)
    return texture
