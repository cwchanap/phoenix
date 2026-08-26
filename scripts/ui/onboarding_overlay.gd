class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

var _dismissed: Array[StringName] = []
var _opening_panel: Control
var _tutorial_card: Control
var _tutorial_title: Label
var _tutorial_body: Label
var _last_snapshot: Dictionary = {}
var _current_prompt_id: StringName = &""

func _ready() -> void:
    _opening_panel = _build_opening_panel()
    _tutorial_card = _build_tutorial_card()
    _opening_panel.visible = false
    _tutorial_card.visible = false

func render(snapshot: Dictionary) -> void:
    _last_snapshot = snapshot.duplicate(true)
    var was_blocking := _opening_panel.visible
    _opening_panel.visible = not bool(snapshot["intro_acknowledged"])
    if _opening_panel.visible:
        _tutorial_card.visible = false
    else:
        _render_tutorial(ContentRules.next_tutorial_prompt(snapshot, _dismissed))
    if was_blocking != _opening_panel.visible:
        blocking_state_changed.emit()

func is_opening_visible() -> bool:
    return _opening_panel.visible

func _build_opening_panel() -> Control:
    var panel := ColorRect.new()
    panel.name = "OpeningPanel"
    panel.position = Vector2(160, 96)
    panel.size = Vector2(320, 180)
    panel.color = Color(0.08, 0.1, 0.14, 0.96)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel)
    var intro := _add_label(
        panel,
        "Intro",
        "This farm has been quiet for a while. It is yours now — bring it back one day at a time.",
        Vector2(12, 14),
        Vector2(296, 56),
    )
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var guide := _add_label(
        panel,
        "Guide",
        "Mira: The village harvest market is on Day 14. Grow what you can, and get to know the village before then.",
        Vector2(12, 76),
        Vector2(296, 56),
    )
    guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var start := Button.new()
    start.name = "Start"
    start.text = "Start"
    start.position = Vector2(120, 140)
    start.size = Vector2(80, 28)
    start.focus_mode = Control.FOCUS_ALL
    start.pressed.connect(func() -> void: intro_acknowledged.emit())
    panel.add_child(start)
    return panel

func _build_tutorial_card() -> Control:
    var panel := ColorRect.new()
    panel.name = "TutorialCard"
    panel.position = Vector2(8, 264)
    panel.size = Vector2(288, 70)
    panel.color = Color(0.08, 0.1, 0.14, 0.96)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel)
    _tutorial_title = _add_label(panel, "Title", "", Vector2(8, 6), Vector2(200, 18))
    _tutorial_body = _add_label(panel, "Body", "", Vector2(8, 28), Vector2(272, 36))
    _tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var dismiss := Button.new()
    dismiss.name = "Dismiss"
    dismiss.text = "Dismiss"
    dismiss.position = Vector2(216, 4)
    dismiss.size = Vector2(64, 20)
    dismiss.focus_mode = Control.FOCUS_NONE
    dismiss.pressed.connect(_on_dismiss_pressed)
    panel.add_child(dismiss)
    return panel

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

func _add_label(parent: Node, node_name: String, text: String, position: Vector2, size: Vector2) -> Label:
    var label := Label.new()
    label.name = node_name
    label.text = text
    label.position = position
    label.size = size
    parent.add_child(label)
    return label
