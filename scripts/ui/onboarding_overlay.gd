class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

const TUTORIAL_ICON := preload("res://assets/ui/icons/tutorial.png")
const INTRO_BACKGROUND := preload("res://assets/ui/backgrounds/intro.png")

var _dismissed: Array[StringName] = []
var _intro_background: TextureRect
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

    _opening_panel = Control.new()
    _opening_panel.name = "OpeningPanel"
    _opening_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _opening_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_opening_panel)

    var top_bar := ColorRect.new()
    top_bar.name = "LetterboxTop"
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_bar.anchor_right = 1.0
    top_bar.offset_bottom = 90.0
    top_bar.color = Color.BLACK
    _opening_panel.add_child(top_bar)

    var bottom_bar := ColorRect.new()
    bottom_bar.name = "LetterboxBottom"
    bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_bar.anchor_top = 1.0
    bottom_bar.anchor_right = 1.0
    bottom_bar.anchor_bottom = 1.0
    bottom_bar.offset_top = -90.0
    bottom_bar.color = Color.BLACK
    bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _opening_panel.add_child(bottom_bar)

    var day_tag := SlantTag.new(
        (tr("Day %d") % 1).to_upper(), [UiStyle.ACCENT_2], UiStyle.CARD, 17
    )
    day_tag.name = "DayTag"
    _opening_panel.add_child(day_tag)
    UiStyle.pin(day_tag, CORNER_TOP_LEFT, Vector2(120, 130))

    var dock := UiStyle.vn_dock(130.0)
    _opening_panel.add_child(dock)
    var content := dock.find_child("Content", true, false) as VBoxContainer
    var overlay := dock.find_child("Overlay", true, false) as Control

    var intro := UiStyle.label(
        "This farm has been quiet for a while. It is yours now — bring it back one day at a time.",
        32, UiStyle.INK, 700,
    )
    intro.name = "Intro"
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(intro)
    var guide := UiStyle.label(
        "The village harvest market is on Day 14. Grow what you can, and get to know the village before then.",
        20, UiStyle.INK_MUTED, 500,
    )
    guide.name = "Guide"
    guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(guide)

    var footer := UiStyle.hbox(18)
    footer.name = "Footer"
    content.add_child(footer)
    var spacer := Control.new()
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(spacer)
    _accept = UiStyle.primary_action("Enter", "BEGIN DAY 1")
    _accept.name = "Accept"
    _accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    footer.add_child(_accept)

    var name_row := UiStyle.hbox(14)
    name_row.name = "NameRow"
    overlay.add_child(name_row)
    UiStyle.pin(name_row, CORNER_TOP_LEFT, Vector2(40, -28))
    var name_tag := SlantTag.new("SATO-SAN", UiStyle.ACCENT_GRADIENT, UiStyle.CARD, 30)
    name_tag.name = "NameTag"
    var tag_pad := StyleBoxEmpty.new()
    tag_pad.content_margin_left = 26
    tag_pad.content_margin_right = 26
    tag_pad.content_margin_top = 6
    tag_pad.content_margin_bottom = 6
    name_tag.add_theme_stylebox_override("panel", tag_pad)
    name_row.add_child(name_tag)
    var role_pill := PanelContainer.new()
    role_pill.name = "RolePill"
    role_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    role_pill.add_theme_stylebox_override(
        "panel", UiStyle.card(UiStyle.CARD, UiStyle.PILL_RADIUS, [16, 6, 16, 6])
    )
    role_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_row.add_child(role_pill)
    var role := UiStyle.label("Seed-shop keeper", 16, UiStyle.INK_MUTED, 800)
    role.name = "Role"
    role_pill.add_child(role)

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
