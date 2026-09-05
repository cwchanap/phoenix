class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

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
    _tutorial_card = $TutorialCard as Control
    _tutorial_title = $TutorialCard/Title as Label
    _tutorial_body = $TutorialCard/Body as Label
    ($OpeningPanel/Intro as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ($OpeningPanel/MiraCard/Guide as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _style_authored_tree(self)
    _apply_authored_style()
    ($OpeningPanel/Footer/Accept as Button).pressed.connect(func() -> void: intro_acknowledged.emit())
    ($TutorialCard/Dismiss as Button).pressed.connect(_on_dismiss_pressed)
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
    ($TutorialCard as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.PRIMARY, UiStyle.BORDER, 2),
    )
    UiStyle.text($OpeningPanel/Intro as Label, 16, UiStyle.CREAM, 400)
    UiStyle.text($OpeningPanel/MiraCard/Name as Label, 9, UiStyle.GOLD, 700)
    UiStyle.text($OpeningPanel/MiraCard/Guide as Label, 10, UiStyle.TEXT, 400)
    UiStyle.text($OpeningPanel/Footer/Begin as Label, 10, UiStyle.GOLD, 700)
    UiStyle.button($OpeningPanel/Footer/Accept as Button, 9, true)
    UiStyle.text(_tutorial_title, 9, UiStyle.GOLD, 700)
    UiStyle.text(_tutorial_body, 9, UiStyle.TEXT, 400)
    UiStyle.button($TutorialCard/Dismiss as Button, 8)

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
    _tutorial_title.text = String(prompt["title"]).to_upper()
    if _current_prompt_id == &"farm_basics":
        _tutorial_body.text = "Green diamond means the action can run, red means it cannot. Press 1, then Space."
    else:
        _tutorial_body.text = String(prompt["body"])
    _tutorial_card.visible = true

func _on_dismiss_pressed() -> void:
    if _current_prompt_id != &"":
        _dismissed.append(_current_prompt_id)
    render(_last_snapshot)
