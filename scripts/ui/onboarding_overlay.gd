class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

const TUTORIAL_ICON := preload("res://assets/ui/icons/tutorial.png")
const INTRO_BACKGROUND := preload("res://assets/ui/backgrounds/intro.png")
const SATO_PORTRAIT := preload("res://assets/ui/portraits/sato.png")

var _dismissed: Array[StringName] = []
var _intro_background: TextureRect
var _intro_shade: ColorRect
var _intro_gradient: TextureRect
var _opening_panel: Control
var _accept: Button
var _tutorial_card: Control
var _tutorial_title: Label
var _tutorial_body: Label
var _last_snapshot: Dictionary = {}
var _current_prompt_id: StringName = &""
var _tutorial_cards_enabled := true

func _ready() -> void:
    _build_opening()
    # HPA-680 stopgap: the opening card is still 640x360-authored (HPA-682).
    _accept.pressed.connect(func() -> void: intro_acknowledged.emit())
    _build_tutorial_card()
    _intro_background.visible = false
    _intro_shade.visible = false
    _intro_gradient.visible = false
    _opening_panel.visible = false
    _tutorial_card.visible = false

func _build_opening() -> void:
    _intro_background = TextureRect.new()
    _intro_background.name = "IntroBackground"
    _intro_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _intro_background.set_anchors_preset(Control.PRESET_FULL_RECT)
    _intro_background.texture = INTRO_BACKGROUND
    _intro_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _intro_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(_intro_background)

    _intro_shade = ColorRect.new()
    _intro_shade.name = "IntroShade"
    _intro_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _intro_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    _intro_shade.color = Color(0.027, 0.035, 0.047, 0.12)
    add_child(_intro_shade)

    _intro_gradient = TextureRect.new()
    _intro_gradient.name = "IntroGradient"
    _intro_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _intro_gradient.set_anchors_preset(Control.PRESET_FULL_RECT)
    _intro_gradient.texture = _bottom_fade()
    _intro_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _intro_gradient.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(_intro_gradient)

    _opening_panel = Control.new()
    _opening_panel.name = "OpeningPanel"
    _opening_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _opening_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_opening_panel)

    var top_bar := ColorRect.new()
    top_bar.name = "LetterboxTop"
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_bar.anchor_right = 1.0
    top_bar.offset_bottom = 96.0
    top_bar.color = Color(UiStyle.INK, 0.94)
    _opening_panel.add_child(top_bar)

    var bottom_bar := ColorRect.new()
    bottom_bar.name = "LetterboxBottom"
    bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_bar.anchor_top = 1.0
    bottom_bar.anchor_right = 1.0
    bottom_bar.anchor_bottom = 1.0
    bottom_bar.offset_top = -330.0
    bottom_bar.color = Color(UiStyle.INK, 0.94)
    bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _opening_panel.add_child(bottom_bar)

    var content := MarginContainer.new()
    content.name = "Content"
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.anchor_top = 1.0
    content.anchor_right = 1.0
    content.anchor_bottom = 1.0
    content.offset_top = -330.0
    content.grow_vertical = Control.GROW_DIRECTION_BEGIN
    for side in [["left", 72], ["top", 30], ["right", 72], ["bottom", 30]]:
        content.add_theme_constant_override("margin_" + side[0], side[1])
    _opening_panel.add_child(content)

    var row := UiStyle.hbox(36)
    row.name = "Row"
    content.add_child(row)
    var portrait := TextureRect.new()
    portrait.name = "Portrait"
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait.custom_minimum_size = Vector2(190, 266)
    portrait.texture = SATO_PORTRAIT
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(portrait)

    var column := UiStyle.vbox(12)
    column.name = "Column"
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(column)
    var header := UiStyle.hbox(14)
    header.name = "Header"
    column.add_child(header)
    var name_tag := SlantTag.new("SATO-SAN", UiStyle.ACCENT_GRADIENT, UiStyle.CARD, 20)
    name_tag.name = "NameTag"
    header.add_child(name_tag)
    var day_tag := SlantTag.new(tr("Day %d") % 1, [UiStyle.VIOLET], UiStyle.CARD, 16)
    day_tag.name = "DayTag"
    day_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    header.add_child(day_tag)

    var intro := UiStyle.label(
        "This farm has been quiet for a while. It is yours now — bring it back one day at a time.",
        21, UiStyle.CARD, 500,
    )
    intro.name = "Intro"
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(intro)
    var guide := UiStyle.label(
        "The village harvest market is on Day 14. Grow what you can, and get to know the village before then.",
        18, UiStyle.ACCENT_SOFT, 500,
    )
    guide.name = "Guide"
    guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(guide)
    var spacer := Control.new()
    spacer.name = "Spacer"
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(spacer)
    var footer := UiStyle.hbox(12)
    footer.name = "FooterRow"
    footer.alignment = BoxContainer.ALIGNMENT_END
    column.add_child(footer)
    var enter := UiStyle.keycap("Enter", true, true)
    enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(enter)
    _accept = UiStyle.action_button("BEGIN DAY 1")
    _accept.name = "Accept"
    _accept.custom_minimum_size = Vector2(300, 64)
    footer.add_child(_accept)

func _bottom_fade() -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    gradient.colors = PackedColorArray([
        Color(0, 0, 0, 0.10),
        Color(0, 0, 0, 0.26),
        Color(0, 0, 0, 0.58),
    ])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 1920
    texture.height = 1080
    texture.fill_from = Vector2(0.5, 0)
    texture.fill_to = Vector2(0.5, 1)
    return texture

## The tutorial card as a phone-style notification at the top right (HPA-681).
func _build_tutorial_card() -> void:
    var card := PanelContainer.new()
    card.name = "TutorialCard"
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var box := UiStyle.card(UiStyle.HUD_CARD, 22, [16, 14, 16, 14])
    box.shadow_size = 17
    box.shadow_offset = Vector2(0, 14)
    box.shadow_color = Color(UiStyle.SHADOW, 0.28)
    card.add_theme_stylebox_override("panel", box)
    card.custom_minimum_size = Vector2(480, 0)
    UiStyle.pin(card, CORNER_TOP_RIGHT, Vector2(HudChrome.MARGIN, 200))
    add_child(card)
    var row := UiStyle.hbox(12)
    card.add_child(row)
    var app := UiStyle.gradient_surface(UiStyle.ACCENT_GRADIENT, 14)
    app.name = "App"
    app.custom_minimum_size = Vector2(52, 52)
    app.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    var app_icon := UiStyle.icon(TUTORIAL_ICON)
    app_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    app_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    app.add_child(app_icon)
    row.add_child(app)
    var text := UiStyle.vbox(2)
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(text)
    var top := UiStyle.hbox(0)
    text.add_child(top)
    var tip := UiStyle.label("TIP", 14, UiStyle.INK_MUTED, 800)
    tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(tip)
    top.add_child(UiStyle.label("now", 14, UiStyle.INK_MUTED, 800))
    _tutorial_title = UiStyle.label("", 20, UiStyle.INK, 700)
    _tutorial_title.name = "Title"
    text.add_child(_tutorial_title)
    _tutorial_body = UiStyle.label("", 17, UiStyle.INK_MUTED, 500)
    _tutorial_body.name = "Body"
    _tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_child(_tutorial_body)
    # The whole "[Tab] dismiss" row is the click target.
    var dismiss := Button.new()
    dismiss.name = "Dismiss"
    dismiss.flat = true
    dismiss.focus_mode = Control.FOCUS_NONE
    dismiss.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    for state in ["normal", "hover", "pressed", "focus"]:
        dismiss.add_theme_stylebox_override(state, StyleBoxEmpty.new())
    text.add_child(dismiss)
    var hint := UiStyle.hbox(8)
    hint.add_child(UiStyle.keycap("Tab", true))
    var hint_label := UiStyle.label("dismiss", 14, UiStyle.INK_MUTED, 800)
    hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hint.add_child(hint_label)
    dismiss.add_child(hint)
    hint.reset_size()
    hint.position = Vector2(0, 8)
    dismiss.custom_minimum_size = hint.size + Vector2(0, 8)
    dismiss.pressed.connect(_on_dismiss_pressed)
    _tutorial_card = card
    _tutorial_card.visible = false

func render(snapshot: Dictionary) -> void:
    _last_snapshot = snapshot.duplicate(true)
    var was_blocking := _opening_panel.visible
    _opening_panel.visible = not bool(snapshot["intro_acknowledged"])
    _intro_background.visible = _opening_panel.visible
    _intro_shade.visible = _opening_panel.visible
    _intro_gradient.visible = _opening_panel.visible
    if _opening_panel.visible:
        _tutorial_card.visible = false
    elif not _tutorial_cards_enabled:
        _tutorial_card.visible = false
    else:
        _render_tutorial(ContentRules.next_tutorial_prompt(snapshot, _dismissed))
    if was_blocking != _opening_panel.visible:
        blocking_state_changed.emit()

func is_opening_visible() -> bool:
    return _opening_panel.visible

func _unhandled_input(event: InputEvent) -> void:
    if not _opening_panel.visible or not event.is_action_pressed("ui_accept"):
        return
    get_viewport().set_input_as_handled()
    intro_acknowledged.emit()

func set_tutorial_cards_enabled(enabled: bool) -> void:
    _tutorial_cards_enabled = enabled
    if not enabled or _opening_panel.visible:
        _tutorial_card.visible = false
    elif not _last_snapshot.is_empty():
        _render_tutorial(ContentRules.next_tutorial_prompt(_last_snapshot, _dismissed))

func _render_tutorial(prompt: Dictionary) -> void:
    _current_prompt_id = prompt.get("id", &"")
    if prompt.is_empty():
        _tutorial_card.visible = false
        return
    _tutorial_title.text = String(prompt["title"])
    _tutorial_body.text = String(prompt["body"])
    _tutorial_card.visible = true

func _on_dismiss_pressed() -> void:
    if _current_prompt_id != &"":
        _dismissed.append(_current_prompt_id)
    render(_last_snapshot)
