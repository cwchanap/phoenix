class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

const TUTORIAL_ICON := preload("res://assets/ui/icons/tutorial.png")

var _dismissed: Array[StringName] = []
var _intro_background: TextureRect
var _intro_shade: ColorRect
var _intro_gradient: TextureRect
var _opening_panel: Control
var _tutorial_card: Control
var _tutorial_title: Label
var _tutorial_body: Label
var _last_snapshot: Dictionary = {}
var _current_prompt_id: StringName = &""
var _tutorial_cards_enabled := true

func _ready() -> void:
    _intro_background = $IntroBackground as TextureRect
    _intro_shade = $IntroShade as ColorRect
    _intro_gradient = $IntroGradient as TextureRect
    _opening_panel = $OpeningPanel as Control
    # HPA-680 stopgap: the opening card is still 640x360-authored (HPA-682).
    UiStyle.fit_legacy_control(_opening_panel)
    ($OpeningPanel/Intro as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ($OpeningPanel/MiraCard/Guide as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _style_authored_tree(self)
    _apply_authored_style()
    ($OpeningPanel/Footer/Accept as Button).pressed.connect(func() -> void: intro_acknowledged.emit())
    _build_tutorial_card()
    _intro_background.visible = false
    _intro_shade.visible = false
    _intro_gradient.visible = false
    _opening_panel.visible = false
    _tutorial_card.visible = false

func _style_authored_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_authored_tree(child)

func _apply_authored_style() -> void:
    ($OpeningPanel as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.PRIMARY, UiStyle.BORDER_LIGHT, 2),
    )
    ($OpeningPanel/MiraCard as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.INSET, UiStyle.BORDER, 1),
    )
    ($OpeningPanel/Footer as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 2),
    )
    UiStyle.text($OpeningPanel/Intro as Label, 16, UiStyle.CREAM, 400)
    UiStyle.text($OpeningPanel/MiraCard/Name as Label, 9, UiStyle.GOLD, 700)
    UiStyle.text($OpeningPanel/MiraCard/Guide as Label, 10, UiStyle.TEXT, 400)
    UiStyle.text($OpeningPanel/Footer/Begin as Label, 10, UiStyle.GOLD, 700)
    UiStyle.button($OpeningPanel/Footer/Accept as Button, 9, true)

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
