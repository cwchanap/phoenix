class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

const TUTORIAL_ICON := preload("res://assets/ui/icons/tutorial.png")
const TRUCK_SHEET := preload("res://assets/sprites/kei-truck.png")
const TRUCK_FRAME := Rect2(0, 0, 96, 96)
const TRUCK_POSITION := Vector2(900, 360)
const TRUCK_SIZE := Vector2(288, 288)
const PORTRAIT_POSITION := Vector2(220, 96)
const PORTRAIT_SIZE := Vector2(600, 840)
const NOTE_POSITION := Vector2(540, 260)
const NOTE_SIZE := Vector2(840, 520)
const NOTE_TILT_DEGREES := -1.8
const SCENE_TAG_POSITION := Vector2(120, 128)
const NARRATION_TOP := 760.0
const BAR_HEIGHT := 90.0
const BAR_INSET := 120
# One grade shared by both night scenes; it darkens the painting only.
const NIGHT_GRADE := Color(0.5, 0.5, 0.66)
const PAPER := Color("fffaf0")
const PAPER_INK := Color("3b2a1e")
const INNER_VOICE_INK := Color("6b4a9e")
const DOT_IDLE := Color(1.0, 1.0, 1.0, 0.45)
const DOT_SIZE := 10.0
const DOT_ACTIVE_WIDTH := 34.0

var _dismissed: Array[StringName] = []
var _intro_background: TextureRect
var _opening_panel: Control
var _scene_tag: SlantTag
var _progress_dots: HBoxContainer
var _truck: TextureRect
var _portrait: TextureRect
var _narration: Label
var _note_card: PanelContainer
var _note_text: Label
var _dock: Control
var _name_tag: SlantTag
var _role: Label
var _body: Label
var _skip: Button
var _continue: Button
var _accept: Button
var _tutorial_card: Control
var _tutorial_title: Label
var _tutorial_body: Label
var _last_snapshot: Dictionary = {}
var _current_prompt_id: StringName = &""
var _tutorial_cards_enabled := true
var _scene_index := 0
var _line_index := 0

func _ready() -> void:
    _build_opening()
    _show_page()
    _build_tutorial_card()
    _intro_background.visible = false
    _opening_panel.visible = false
    _tutorial_card.visible = false

func _build_opening() -> void:
    _intro_background = TextureRect.new()
    _intro_background.name = "IntroBackground"
    _intro_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _intro_background.set_anchors_preset(Control.PRESET_FULL_RECT)
    _intro_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _intro_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(_intro_background)

    _opening_panel = Control.new()
    _opening_panel.name = "OpeningPanel"
    _opening_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _opening_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    _opening_panel.gui_input.connect(_on_opening_gui_input)
    add_child(_opening_panel)

    var top_bar := ColorRect.new()
    top_bar.name = "LetterboxTop"
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_bar.anchor_right = 1.0
    top_bar.offset_bottom = BAR_HEIGHT
    top_bar.color = Color.BLACK
    _opening_panel.add_child(top_bar)
    var top_row := _bar_row(top_bar)
    var prologue := UiStyle.label("Prologue", 16, Color(1.0, 1.0, 1.0, 0.62), 800)
    prologue.name = "Prologue"
    prologue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    top_row.add_child(prologue)
    top_row.add_child(_spacer())
    _skip = UiStyle.hit_button(UiStyle.key_hint("Esc", "Skip intro", 17, UiStyle.CARD))
    _skip.name = "Skip"
    _skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _skip.pressed.connect(_acknowledge)
    top_row.add_child(_skip)

    var bottom_bar := ColorRect.new()
    bottom_bar.name = "LetterboxBottom"
    bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom_bar.anchor_top = 1.0
    bottom_bar.anchor_right = 1.0
    bottom_bar.anchor_bottom = 1.0
    bottom_bar.offset_top = -BAR_HEIGHT
    bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
    bottom_bar.color = Color.BLACK
    _opening_panel.add_child(bottom_bar)
    var bottom_row := _bar_row(bottom_bar)
    bottom_row.add_child(_spacer())
    _continue = UiStyle.hit_button(UiStyle.key_hint("Enter", "Continue", 17, UiStyle.CARD))
    _continue.name = "Continue"
    _continue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _continue.pressed.connect(_advance_page)
    bottom_row.add_child(_continue)

    var header := UiStyle.vbox(14)
    header.name = "Header"
    _opening_panel.add_child(header)
    UiStyle.pin(header, CORNER_TOP_LEFT, SCENE_TAG_POSITION)
    _scene_tag = SlantTag.new("", [UiStyle.ACCENT_2], UiStyle.CARD, 22)
    _scene_tag.name = "SceneTag"
    _pad_tag(_scene_tag, 24, 7)
    header.add_child(_scene_tag)
    _progress_dots = UiStyle.hbox(8)
    _progress_dots.name = "ProgressDots"
    header.add_child(_progress_dots)
    for _index in ContentRules.PROLOGUE_SCENES.size():
        var dot := PanelContainer.new()
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        dot.add_theme_stylebox_override(
            "panel", UiStyle.card(DOT_IDLE, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
        )
        _progress_dots.add_child(dot)

    var frame := AtlasTexture.new()
    frame.atlas = TRUCK_SHEET
    frame.region = TRUCK_FRAME
    _truck = _picture("Truck", TRUCK_POSITION, TRUCK_SIZE)
    _truck.texture = frame
    _portrait = _picture("Portrait", PORTRAIT_POSITION, PORTRAIT_SIZE)

    var narration_column := UiStyle.vbox(0)
    narration_column.name = "NarrationBox"
    narration_column.set_anchors_preset(Control.PRESET_TOP_WIDE)
    narration_column.offset_left = 240.0
    narration_column.offset_top = NARRATION_TOP
    narration_column.offset_right = -240.0
    _opening_panel.add_child(narration_column)
    _narration = UiStyle.shadowed_label("", 38, 500)
    _narration.name = "Narration"
    _narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    narration_column.add_child(_narration)

    _note_card = PanelContainer.new()
    _note_card.name = "NoteCard"
    _note_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var paper := UiStyle.card(PAPER, 6, [96, 84, 96, 64], false)
    paper.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
    paper.shadow_size = 70
    paper.shadow_offset = Vector2(0, 30)
    _note_card.add_theme_stylebox_override("panel", paper)
    _note_card.custom_minimum_size = NOTE_SIZE
    UiStyle.pin(_note_card, CORNER_TOP_LEFT, NOTE_POSITION)
    _note_card.pivot_offset = NOTE_SIZE / 2.0
    _note_card.rotation = deg_to_rad(NOTE_TILT_DEGREES)
    _note_card.visible = false
    _opening_panel.add_child(_note_card)
    _note_text = UiStyle.label("", 40, PAPER_INK, 500)
    _note_text.name = "NoteText"
    _note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _note_card.add_child(_note_text)

    _dock = UiStyle.vn_dock(130.0)
    _opening_panel.add_child(_dock)
    var content := _dock.find_child("Content", true, false) as VBoxContainer
    var overlay := _dock.find_child("Overlay", true, false) as Control

    _body = UiStyle.label("", 36, UiStyle.INK, 700)
    _body.name = "Body"
    _body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(_body)

    var footer := UiStyle.hbox(18)
    footer.name = "Footer"
    content.add_child(footer)
    footer.add_child(_spacer())
    _accept = UiStyle.primary_action("Enter", "BEGIN DAY 1")
    _accept.name = "Accept"
    _accept.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _accept.pressed.connect(_acknowledge)
    footer.add_child(_accept)

    var name_row := UiStyle.hbox(14)
    name_row.name = "NameRow"
    overlay.add_child(name_row)
    UiStyle.pin(name_row, CORNER_TOP_LEFT, Vector2(40, -28))
    _name_tag = SlantTag.new("", UiStyle.ACCENT_GRADIENT, UiStyle.CARD, 34)
    _name_tag.name = "NameTag"
    _pad_tag(_name_tag, 30, 6)
    name_row.add_child(_name_tag)
    var role_pill := PanelContainer.new()
    role_pill.name = "RolePill"
    role_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    role_pill.add_theme_stylebox_override(
        "panel", UiStyle.card(UiStyle.CARD, UiStyle.PILL_RADIUS, [18, 6, 18, 6])
    )
    role_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_row.add_child(role_pill)
    _role = UiStyle.label("", 17, UiStyle.INK_MUTED, 800)
    _role.name = "Role"
    role_pill.add_child(_role)

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

## Total authored prologue pages across all scenes.
func page_count() -> int:
    var total := 0
    for scene in ContentRules.PROLOGUE_SCENES:
        total += (scene["lines"] as Array).size()
    return total

func current_page() -> Dictionary:
    var before := 0
    for index in _scene_index:
        before += (ContentRules.PROLOGUE_SCENES[index]["lines"] as Array).size()
    var line := _line()
    return {
        "scene": _scene_index,
        "line": _line_index,
        "kind": int(line["kind"]),
        "text": String(line["text"]),
        "page_number": before + _line_index + 1,
    }

func _unhandled_input(event: InputEvent) -> void:
    if not _opening_panel.visible:
        return
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        _acknowledge()
    elif event.is_action_pressed("ui_accept"):
        get_viewport().set_input_as_handled()
        if _is_last_page():
            _acknowledge()
        else:
            _advance_page()

func _on_opening_gui_input(event: InputEvent) -> void:
    var click := event as InputEventMouseButton
    if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
        return
    _opening_panel.accept_event()
    _advance_page()

func _acknowledge() -> void:
    intro_acknowledged.emit()

func _advance_page() -> void:
    if _is_last_page():
        return
    if _line_index + 1 < _lines().size():
        _line_index += 1
    else:
        _scene_index += 1
        _line_index = 0
    _show_page()

func _is_last_page() -> bool:
    return _scene_index == ContentRules.PROLOGUE_SCENES.size() - 1 and _line_index == _lines().size() - 1

func _show_page() -> void:
    var scene := _scene()
    var line := _line()
    var kind := int(line["kind"])
    var speaker := int(line.get("villager", -1))
    _intro_background.texture = load(String(scene["background"]))
    _intro_background.modulate = NIGHT_GRADE if bool(scene["night"]) else Color.WHITE
    _scene_tag.set_tag(String(scene["tag"]), [UiStyle.ACCENT_2])
    _truck.visible = bool(scene["truck"])
    _render_dots()
    _render_portrait(int(scene["portrait"]), kind, speaker)
    _narration.visible = kind == ContentRules.LineKind.NARRATION
    _narration.text = String(line["text"])
    _render_note()
    _render_dock(line, kind, speaker)
    var last := _is_last_page()
    _continue.visible = not last
    _accept.visible = last

func _render_dots() -> void:
    for index in _progress_dots.get_child_count():
        var dot := _progress_dots.get_child(index) as PanelContainer
        var active := index == _scene_index
        dot.custom_minimum_size = Vector2(DOT_ACTIVE_WIDTH if active else DOT_SIZE, DOT_SIZE)
        var fill := UiStyle.ACCENT if active else (Color.WHITE if index < _scene_index else DOT_IDLE)
        (dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = fill

## The speaking villager stands at full strength; otherwise the scene's own portrait listens, dimmed.
func _render_portrait(scene_portrait: int, kind: int, speaker: int) -> void:
    var villager := speaker if speaker >= 0 else scene_portrait
    var shown := villager >= 0 and kind != ContentRules.LineKind.NARRATION and kind != ContentRules.LineKind.NOTE
    _portrait.visible = shown
    if not shown:
        return
    _portrait.texture = load("res://assets/ui/portraits/%s.png" % VillagerRules.PORTRAIT_NAMES[villager])
    _portrait.modulate = Color.WHITE if speaker >= 0 else DialoguePanel.DIMMED

## The latest note in this scene, so a note stays up until the scene changes.
func _render_note() -> void:
    var note := _current_note()
    _note_card.visible = not note.is_empty()
    if not note.is_empty():
        _note_text.text = String(note["text"])

func _current_note() -> Dictionary:
    var lines := _lines()
    for index in range(_line_index, -1, -1):
        var line: Dictionary = lines[index]
        if int(line["kind"]) == ContentRules.LineKind.NOTE:
            return line
    return {}

func _render_dock(line: Dictionary, kind: int, speaker: int) -> void:
    var spoken := kind == ContentRules.LineKind.DIALOGUE or kind == ContentRules.LineKind.INNER_VOICE
    _dock.visible = spoken
    if not spoken:
        return
    if kind == ContentRules.LineKind.INNER_VOICE:
        _name_tag.set_tag(ContentRules.OPENING_SPEAKER, [UiStyle.NIGHT])
        _set_role(ContentRules.INNER_VOICE_LABEL, INNER_VOICE_INK)
    elif speaker >= 0:
        _name_tag.set_tag(VillagerRules.display_name(speaker), UiStyle.ACCENT_GRADIENT)
        _set_role(VillagerRules.role_label(speaker), UiStyle.INK_MUTED)
    else:
        _name_tag.set_tag(ContentRules.OPENING_SPEAKER, UiStyle.ACCENT_GRADIENT)
        _set_role(ContentRules.OPENING_ROLE, UiStyle.INK_MUTED)
    _body.text = String(line["text"])
    var body_ink := INNER_VOICE_INK if kind == ContentRules.LineKind.INNER_VOICE else UiStyle.INK
    _body.add_theme_color_override("font_color", body_ink)

func _set_role(text_value: String, color: Color) -> void:
    _role.text = text_value
    _role.add_theme_color_override("font_color", color)

func _scene() -> Dictionary:
    return ContentRules.PROLOGUE_SCENES[_scene_index]

func _lines() -> Array:
    return _scene()["lines"]

func _line() -> Dictionary:
    return _lines()[_line_index]

func _spacer() -> Control:
    var spacer := Control.new()
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return spacer

## A full-height row inset by the mockup's side margins; only its buttons take clicks.
func _bar_row(bar: ColorRect) -> HBoxContainer:
    var inset := MarginContainer.new()
    inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
    inset.set_anchors_preset(Control.PRESET_FULL_RECT)
    inset.add_theme_constant_override("margin_left", BAR_INSET)
    inset.add_theme_constant_override("margin_right", BAR_INSET)
    bar.add_child(inset)
    var row := UiStyle.hbox(0)
    inset.add_child(row)
    return row

func _picture(picture_name: String, picture_position: Vector2, picture_size: Vector2) -> TextureRect:
    var picture := TextureRect.new()
    picture.name = picture_name
    picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
    picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode = TextureRect.STRETCH_SCALE
    picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    picture.custom_minimum_size = picture_size
    UiStyle.pin(picture, CORNER_TOP_LEFT, picture_position)
    _opening_panel.add_child(picture)
    return picture

## Gives a slant tag the mockup's padding, in px, around its caption.
func _pad_tag(tag: SlantTag, horizontal: int, vertical: int) -> void:
    var pad := StyleBoxEmpty.new()
    pad.content_margin_left = horizontal
    pad.content_margin_right = horizontal
    pad.content_margin_top = vertical
    pad.content_margin_bottom = vertical
    tag.add_theme_stylebox_override("panel", pad)

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
