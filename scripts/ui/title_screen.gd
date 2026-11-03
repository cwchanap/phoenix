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
    _new_game_label.add_theme_color_override(
        "font_color", UiStyle.CARD if new_selected else UiStyle.INK
    )
    _continue_label.add_theme_color_override(
        "font_color",
        UiStyle.CARD if continue_selected
        else UiStyle.INK if _continue_available
        else UiStyle.INK_MUTED,
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
    logo.position = Vector2(140, 140)
    logo.size = Vector2(560, 240)
    logo.texture = LOGO
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    add_child(logo)

    var menu := UiStyle.vbox(18)
    menu.name = "Menu"
    menu.position = Vector2(140, 500)
    menu.size = Vector2(640, 500)
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
    var status_box := UiStyle.card(UiStyle.BAD_SOFT, UiStyle.PILL_RADIUS, [18, 12, 18, 12], false)
    status_box.border_color = UiStyle.BAD
    status_box.set_border_width_all(2)
    _status_pill.add_theme_stylebox_override("panel", status_box)
    var status_row := UiStyle.hbox(12)
    status_row.name = "Row"
    _status_pill.add_child(status_row)
    var status_icon := UiStyle.icon(WARNING_ICON, 26)
    status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    status_row.add_child(status_icon)
    _status_label = UiStyle.label("", 17, UiStyle.BAD, 800)
    _status_label.name = "Label"
    _status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_row.add_child(_status_label)
    menu.add_child(_status_pill)

    var footer := UiStyle.hbox(10)
    footer.name = "Footer"
    footer.alignment = BoxContainer.ALIGNMENT_BEGIN
    menu.add_child(footer)
    var w_key := UiStyle.keycap("W", true)
    w_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(w_key)
    var s_key := UiStyle.keycap("S", true)
    s_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(s_key)
    var choose := UiStyle.label("choose", 16, UiStyle.ACCENT_SOFT, 800)
    choose.name = "Choose"
    choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(choose)
    var spacer := Control.new()
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(spacer)
    var version := UiStyle.label("Godot 4.7.1 · 1080p", 14, UiStyle.ACCENT_SOFT, 600)
    version.name = "Version"
    version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(version)

func _action_row(
    row_name: String, icon_texture: Texture2D, text_value: String
) -> Dictionary:
    var button := Button.new()
    button.name = row_name
    button.custom_minimum_size = Vector2(640, 104)
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var normal := UiStyle.card(UiStyle.HUD_CARD, 24)
    normal.border_color = UiStyle.LINE
    normal.set_border_width_all(2)
    var hover := UiStyle.card(UiStyle.CARD, 24)
    hover.border_color = UiStyle.ACCENT
    hover.set_border_width_all(2)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", UiStyle.card(UiStyle.ACCENT_SOFT, 24))
    button.add_theme_stylebox_override("focus", normal)
    button.add_theme_stylebox_override("disabled", UiStyle.card(UiStyle.LINE, 24))

    var gradient := UiStyle.gradient_surface(UiStyle.ACCENT_GRADIENT, 24)
    gradient.name = "Gradient"
    gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
    gradient.visible = false
    button.add_child(gradient)

    var icon := UiStyle.icon(icon_texture, 44)
    icon.name = "Icon"
    icon.position = Vector2(30, 30)
    icon.size = Vector2(44, 44)
    button.add_child(icon)

    var label := UiStyle.label(text_value, 30, UiStyle.INK, 900)
    label.name = "Label"
    label.position = Vector2(96, 0)
    label.size = Vector2(400, 104)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    button.add_child(label)

    var keycap := UiStyle.keycap("Enter")
    keycap.name = "Keycap"
    keycap.visible = false
    button.add_child(keycap)
    keycap.reset_size()
    keycap.position = Vector2(616 - keycap.size.x, (104 - keycap.size.y) / 2.0)

    return {"button": button, "gradient": gradient, "label": label, "keycap": keycap}

func _left_fade() -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
    gradient.colors = PackedColorArray([
        Color(0.015, 0.02, 0.025, 0.78),
        Color(0.015, 0.02, 0.025, 0.28),
        Color(0.015, 0.02, 0.025, 0.08),
    ])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 1920
    texture.height = 1080
    texture.fill_from = Vector2(0, 0.5)
    texture.fill_to = Vector2(1, 0.5)
    return texture
