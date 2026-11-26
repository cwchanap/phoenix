class_name OnboardingOverlay
extends Control

signal intro_acknowledged
signal blocking_state_changed

const TUTORIAL_ICON := preload("res://assets/ui/icons/tutorial.png")
const PORTRAIT_POSITION := Vector2(220, 96)
const PORTRAIT_SIZE := Vector2(600, 840)
const NOTE_POSITION := Vector2(540, 260)
const NOTE_SIZE := Vector2(840, 520)
const NOTE_TILT_DEGREES := -1.8
const SCENE_TAG_POSITION := Vector2(120, 128)
const NARRATION_TOP := 760.0
const BAR_HEIGHT := 90.0
# Darkens the lower part of narration pages so the white text reads over any painting.
const SCRIM_INK := Color("0b0714")
const SCRIM_HEIGHT := 560.0
const BAR_INSET := 120
const PAPER := Color("fffaf0")
const PAPER_INK := Color("3b2a1e")
const INNER_VOICE_INK := Color("6b4a9e")
const INNER_VOICE_BODY := Color("5e4470")
const DOT_IDLE := Color(1.0, 1.0, 1.0, 0.45)
const DOT_SIZE := 10.0
const DOT_ACTIVE_WIDTH := 34.0
# HPA-1250 UI motion timings, in seconds unless noted.
const FADE_OUT_SECONDS := 0.45
const FADE_IN_SECONDS := 0.7
## Typing waits for the fade-in to be mostly done before it starts.
const TYPING_DELAY_SECONDS := 0.45
const TYPING_CHARACTERS_PER_SECOND := 30.0
const NOTE_DROP_SECONDS := 0.7
const NOTE_DROP_HEIGHT := 60.0
const NOTE_DROP_TILT_DEGREES := -8.0
const PORTRAIT_SLIDE := 60.0
const PORTRAIT_ENTER_DELAY := 0.3
const PORTRAIT_ENTER_SECONDS := 0.5
const PORTRAIT_DIM_SECONDS := 0.2
const PORTRAIT_BREATH := 3.0
const NAME_POP_SECONDS := 0.22
const TAG_SLIDE := 40.0
const TAG_DELAY := 0.2
const TAG_SECONDS := 0.45
const HINT_BOB := 3.0

## Plays the HPA-1250 motion. Fixtures set it false for instant, still pages;
## turning it off mid-prologue settles the current page at once.
var animate := true:
    set(value):
        animate = value
        if not value and _opening_panel != null and _opening_panel.visible:
            _stop_motion()
            _show_page()
var _dismissed: Array[StringName] = []
var _stage: PrologueStage
var _opening_panel: Control
var _scrim: TextureRect
var _header: Control
var _scene_tag: SlantTag
var _progress_dots: HBoxContainer
var _portrait: TextureRect
var _narration: Label
var _note_drop: Control
var _note_card: PanelContainer
var _note_text: Label
var _dock: Control
var _name_row: Control
var _name_tag: SlantTag
var _role: Label
var _body: Label
var _skip: Button
var _continue: Button
var _accept: Button
var _accept_glow: StyleBoxFlat
var _fade: ColorRect
var _tutorial_card: Control
var _tutorial_title: Label
var _tutorial_body: Label
var _last_snapshot: Dictionary = {}
var _current_prompt_id: StringName = &""
var _tutorial_cards_enabled := true
var _suppressed := false
var _scene_index := 0
var _line_index := 0
# The page whose motion last played, so a re-render never restarts it.
var _shown_scene := -1
var _shown_line := -1
var _portrait_scene := -1
var _portrait_slide := 0.0
var _motion_time := 0.0
var _tweens: Dictionary = {}

func _ready() -> void:
    _build_opening()
    _build_tutorial_card()
    _stage.visible = false
    _opening_panel.visible = false
    _tutorial_card.visible = false
    set_process(false)

func _notification(what: int) -> void:
    if what == NOTIFICATION_TRANSLATION_CHANGED and _opening_panel != null and _opening_panel.visible:
        _show_page()

func _build_opening() -> void:
    _stage = PrologueStage.new()
    add_child(_stage)

    _opening_panel = Control.new()
    _opening_panel.name = "OpeningPanel"
    _opening_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _opening_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    _opening_panel.gui_input.connect(_on_opening_gui_input)
    add_child(_opening_panel)

    _scrim = _build_scrim()
    _opening_panel.add_child(_scrim)

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

    _header = UiStyle.vbox(14)
    _header.name = "Header"
    _opening_panel.add_child(_header)
    UiStyle.pin(_header, CORNER_TOP_LEFT, SCENE_TAG_POSITION)
    _scene_tag = SlantTag.new("", [UiStyle.ACCENT_2], UiStyle.CARD, 22)
    _scene_tag.name = "SceneTag"
    _pad_tag(_scene_tag, 24, 7)
    _header.add_child(_scene_tag)
    _progress_dots = UiStyle.hbox(8)
    _progress_dots.name = "ProgressDots"
    _header.add_child(_progress_dots)
    for _index in ContentRules.PROLOGUE_SCENES.size():
        var dot := PanelContainer.new()
        dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        dot.add_theme_stylebox_override(
            "panel", UiStyle.card(DOT_IDLE, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
        )
        _progress_dots.add_child(dot)

    _portrait = _picture("Portrait", PORTRAIT_POSITION, PORTRAIT_SIZE)
    # The tag and dots draw above the portrait art they sit beside.
    _opening_panel.move_child(_header, _portrait.get_index() + 1)

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

    # The note drops by moving this plain holder, never the card itself: moving
    # the PanelContainer while its wrapped text is still unsized balloons it.
    _note_drop = Control.new()
    _note_drop.name = "NoteDrop"
    _note_drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    UiStyle.pin(_note_drop, CORNER_TOP_LEFT, NOTE_POSITION)
    _opening_panel.add_child(_note_drop)
    _note_card = PanelContainer.new()
    _note_card.name = "NoteCard"
    _note_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var paper := UiStyle.card(PAPER, 6, [96, 84, 96, 64], false)
    paper.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
    paper.shadow_size = 70
    paper.shadow_offset = Vector2(0, 30)
    _note_card.add_theme_stylebox_override("panel", paper)
    _note_card.custom_minimum_size = NOTE_SIZE
    _note_card.pivot_offset = NOTE_SIZE / 2.0
    _note_card.rotation = deg_to_rad(NOTE_TILT_DEGREES)
    _note_card.visible = false
    _note_drop.add_child(_note_card)
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
    _accept.pressed.connect(_accept_page)
    footer.add_child(_accept)
    # A glow drawn under the pill; its shadow pulses while Begin Day 1 waits.
    var glow := Panel.new()
    glow.name = "Glow"
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    _accept_glow = UiStyle.card(UiStyle.ACCENT_DEEP, UiStyle.PILL_RADIUS, [0, 0, 0, 0], false)
    _accept_glow.shadow_color = Color(UiStyle.ACCENT_DEEP, 0.0)
    _accept_glow.shadow_offset = Vector2(0, 8)
    glow.add_theme_stylebox_override("panel", _accept_glow)
    _accept.add_child(glow)
    _accept.move_child(glow, 0)

    _name_row = UiStyle.hbox(14)
    _name_row.name = "NameRow"
    overlay.add_child(_name_row)
    UiStyle.pin(_name_row, CORNER_TOP_LEFT, Vector2(40, -28))
    _name_tag = SlantTag.new("", UiStyle.ACCENT_GRADIENT, UiStyle.CARD, 34)
    _name_tag.name = "NameTag"
    _pad_tag(_name_tag, 30, 6)
    _name_row.add_child(_name_tag)
    var role_pill := PanelContainer.new()
    role_pill.name = "RolePill"
    role_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    role_pill.add_theme_stylebox_override(
        "panel", UiStyle.card(UiStyle.CARD, UiStyle.PILL_RADIUS, [18, 6, 18, 6])
    )
    role_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _name_row.add_child(role_pill)
    _role = UiStyle.label("", 17, UiStyle.INK_MUTED, 800)
    _role.name = "Role"
    role_pill.add_child(_role)

    # Scenes fade through black over everything, bars included; it never takes clicks.
    _fade = ColorRect.new()
    _fade.name = "Fade"
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _fade.set_anchors_preset(Control.PRESET_FULL_RECT)
    _fade.color = Color.BLACK
    _fade.modulate.a = 0.0
    _opening_panel.add_child(_fade)

    for label in [_narration, _body]:
        (label as Label).visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING

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
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint.add_child(UiStyle.keycap("Tab", true))
    var hint_label := UiStyle.label("dismiss", 14, UiStyle.INK_MUTED, 800)
    hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hint.add_child(hint_label)
    dismiss.add_child(hint)
    hint.reset_size()
    hint.position = Vector2(0, 8)
    dismiss.custom_minimum_size = hint.size + Vector2(0, 8)
    dismiss.pressed.connect(_dismiss_current_prompt)
    _tutorial_card = card
    _tutorial_card.visible = false

func render(snapshot: Dictionary) -> void:
    _last_snapshot = snapshot.duplicate(true)
    var was_blocking := _opening_panel.visible
    _opening_panel.visible = not bool(snapshot["intro_acknowledged"])
    _stage.visible = _opening_panel.visible
    if _opening_panel.visible:
        _show_page()
    else:
        _stop_motion()
        _stage.clear()
        _portrait.texture = null
    _refresh_tutorial_card()
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

## Runs before GUI focus traversal so a visible tip takes Tab for itself.
func _input(event: InputEvent) -> void:
    if (
        not _tutorial_card.is_visible_in_tree()
        or not _tutorial_cards_enabled
        or _opening_panel.visible
        or _current_prompt_id == &""
    ):
        return
    if not event.is_action_pressed(&"dismiss_tutorial", false, true):
        return
    get_viewport().set_input_as_handled()
    _dismiss_current_prompt()

func _unhandled_input(event: InputEvent) -> void:
    if not _opening_panel.visible:
        return
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        _acknowledge()
    elif event.is_action_pressed("ui_accept"):
        get_viewport().set_input_as_handled()
        _accept_page()

func _on_opening_gui_input(event: InputEvent) -> void:
    var click := event as InputEventMouseButton
    if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
        return
    _opening_panel.accept_event()
    _advance_page()

## Enter and Begin Day 1 share one rule: the last line finishes typing before
## Day 1 begins. Skip and Esc acknowledge at once.
func _accept_page() -> void:
    if _is_last_page() and is_line_revealed():
        _acknowledge()
    else:
        _advance_page()

func _acknowledge() -> void:
    intro_acknowledged.emit()

## One step forward: a line still typing finishes first; the scene's last
## line fades through black into the next scene. Input waits out the fade.
func _advance_page() -> void:
    if is_changing_scene():
        return
    if not is_line_revealed():
        _reveal_line_now()
        return
    if _is_last_page():
        return
    if _line_index + 1 < _lines().size():
        _line_index += 1
        _show_page()
    elif not animate:
        _enter_next_scene()
    else:
        var fade := _restart_tween(&"scene")
        fade.tween_property(_fade, "modulate:a", 1.0, FADE_OUT_SECONDS)
        fade.tween_callback(_enter_next_scene)

func _enter_next_scene() -> void:
    _scene_index += 1
    _line_index = 0
    _show_page()

## True while the screen fades out to the next scene.
func is_changing_scene() -> bool:
    return _is_running(&"scene")

## True once the current line is fully on screen (typed out, or its note dropped).
func is_line_revealed() -> bool:
    return not _is_running(&"reveal")

func _is_last_page() -> bool:
    return _scene_index == ContentRules.PROLOGUE_SCENES.size() - 1 and _line_index == _lines().size() - 1

func _show_page() -> void:
    var scene := _scene()
    var line := _line()
    var kind := int(line["kind"])
    var speaker := int(line.get("villager", -1))
    var scene_changed := _shown_scene != _scene_index
    var line_changed := scene_changed or _shown_line != _line_index
    _shown_scene = _scene_index
    _shown_line = _line_index
    if scene_changed:
        _stage.animate = animate
        _stage.show_scene(scene)
        # A scene rebuilt in place (motion turned off mid-scene) keeps the
        # beats of the lines already passed, so lit windows stay lit.
        _stage.animate = false
        for earlier in _line_index:
            _stage.show_line(_lines()[earlier])
        _stage.animate = animate
    _scene_tag.set_tag(String(scene["tag"]), [UiStyle.ACCENT_2])
    _render_dots()
    _render_portrait(int(scene["portrait"]), kind, speaker)
    _narration.visible = kind == ContentRules.LineKind.NARRATION
    _scrim.visible = _narration.visible
    _narration.text = String(line["text"])
    _render_note()
    _render_dock(line, kind, speaker)
    var last := _is_last_page()
    _continue.visible = not last
    _accept.visible = last
    if scene_changed:
        _play_scene_entrance()
    if line_changed:
        _stage.show_line(line)
        _play_line_entrance(kind, scene_changed)
    set_process(animate)

## Fades up from black and slides the scene tag in.
func _play_scene_entrance() -> void:
    _header.position.x = SCENE_TAG_POSITION.x
    _header.modulate.a = 1.0
    if not animate:
        _kill_tween(&"scene")
        _fade.modulate.a = 0.0
        return
    var fade := _restart_tween(&"scene_in")
    _fade.modulate.a = 1.0
    fade.tween_property(_fade, "modulate:a", 0.0, FADE_IN_SECONDS).set_trans(Tween.TRANS_SINE)
    _header.position.x = SCENE_TAG_POSITION.x - TAG_SLIDE
    _header.modulate.a = 0.0
    var tag := _restart_tween(&"tag").set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tag.tween_property(_header, "position:x", SCENE_TAG_POSITION.x, TAG_SECONDS).set_delay(TAG_DELAY)
    tag.tween_property(_header, "modulate:a", 1.0, TAG_SECONDS).set_delay(TAG_DELAY)

## Types the line out (or drops the note) and pops the speaker's name tag in.
func _play_line_entrance(kind: int, first_in_scene: bool) -> void:
    _kill_tween(&"reveal")
    _settle_line()
    if not animate:
        return
    var delay := TYPING_DELAY_SECONDS if first_in_scene else 0.0
    if kind == ContentRules.LineKind.NOTE:
        _note_drop.position.y = NOTE_POSITION.y - NOTE_DROP_HEIGHT
        _note_card.rotation = deg_to_rad(NOTE_DROP_TILT_DEGREES)
        _note_card.modulate.a = 0.0
        var drop := _restart_tween(&"reveal").set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        drop.tween_property(_note_drop, "position:y", NOTE_POSITION.y, NOTE_DROP_SECONDS).set_delay(delay)
        drop.tween_property(_note_card, "rotation", deg_to_rad(NOTE_TILT_DEGREES), NOTE_DROP_SECONDS).set_delay(delay).set_trans(Tween.TRANS_BACK)
        drop.tween_property(_note_card, "modulate:a", 1.0, NOTE_DROP_SECONDS * 0.6).set_delay(delay)
        return
    var label := _narration if kind == ContentRules.LineKind.NARRATION else _body
    var characters := label.get_total_character_count()
    if characters > 0:
        label.visible_ratio = 0.0
        var typing := _restart_tween(&"reveal")
        typing.tween_interval(delay)
        typing.tween_property(label, "visible_ratio", 1.0, characters / TYPING_CHARACTERS_PER_SECOND)
    if _dock.visible:
        _name_row.pivot_offset = Vector2(0, _name_row.size.y / 2.0)
        _name_row.scale = Vector2.ONE * 0.92
        _name_row.modulate.a = 0.0
        var pop := _restart_tween(&"name").set_parallel().set_trans(Tween.TRANS_SINE)
        pop.tween_property(_name_row, "scale", Vector2.ONE, NAME_POP_SECONDS)
        pop.tween_property(_name_row, "modulate:a", 1.0, NAME_POP_SECONDS)

## Enter or a click while a line is still appearing shows the whole line at once.
func _reveal_line_now() -> void:
    _kill_tween(&"reveal")
    _settle_line()

## Puts the current line's text and note card in their resting, fully shown state.
func _settle_line() -> void:
    _narration.visible_ratio = 1.0
    _body.visible_ratio = 1.0
    _note_drop.position.y = NOTE_POSITION.y
    _note_card.rotation = deg_to_rad(NOTE_TILT_DEGREES)
    _note_card.modulate.a = 1.0

## Per-frame motion that never ends: the portrait breathes, the Continue hint
## bobs once the line is shown, and Begin Day 1 pulses.
func _process(delta: float) -> void:
    _motion_time += delta
    var t := _motion_time
    _portrait.position = PORTRAIT_POSITION + Vector2(_portrait_slide, sin(t * 1.7) * PORTRAIT_BREATH)
    var shown := 1.0 if is_line_revealed() and not is_changing_scene() else 0.0
    _continue.modulate.a = move_toward(_continue.modulate.a, shown, delta * 6.0)
    var hint := _continue.get_child(0) as Control
    hint.position.y = sin(t * 4.0) * HINT_BOB * shown
    _accept.modulate.a = move_toward(_accept.modulate.a, shown, delta * 6.0)
    var pulse := 0.5 + 0.5 * sin(t * 3.2)
    _accept_glow.shadow_size = int(8.0 + 16.0 * pulse)
    _accept_glow.shadow_color = Color(UiStyle.ACCENT_DEEP, 0.3 + 0.3 * pulse)

## Stops every tween and puts the animated UI back at rest; the prologue is closing.
func _stop_motion() -> void:
    for key in _tweens.keys():
        _kill_tween(key)
    set_process(false)
    _fade.modulate.a = 0.0
    _header.position.x = SCENE_TAG_POSITION.x
    _header.modulate.a = 1.0
    _name_row.scale = Vector2.ONE
    _name_row.modulate.a = 1.0
    _portrait_slide = 0.0
    _portrait.position = PORTRAIT_POSITION
    _portrait.self_modulate.a = 1.0
    _continue.modulate.a = 1.0
    _accept.modulate.a = 1.0
    _settle_line()
    _shown_scene = -1
    _shown_line = -1
    _portrait_scene = -1

## A fresh tween under `key`, replacing (and killing) the previous one.
func _restart_tween(key: StringName) -> Tween:
    _kill_tween(key)
    var tween := create_tween()
    _tweens[key] = tween
    return tween

func _kill_tween(key: StringName) -> void:
    var tween: Tween = _tweens.get(key)
    if tween != null and tween.is_valid():
        tween.kill()
    _tweens.erase(key)

func _is_running(key: StringName) -> bool:
    var tween: Tween = _tweens.get(key)
    return tween != null and tween.is_valid() and tween.is_running()

## A bottom-up gradient (92% ink at the edge, clear at the top) drawn only behind narration.
func _build_scrim() -> TextureRect:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    gradient.colors = PackedColorArray([Color(SCRIM_INK, 0.0), Color(SCRIM_INK, 0.65), Color(SCRIM_INK, 0.92)])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill_from = Vector2.ZERO
    texture.fill_to = Vector2(0.0, 1.0)
    texture.width = 4
    texture.height = 256
    var scrim := TextureRect.new()
    scrim.name = "Scrim"
    scrim.texture = texture
    scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    scrim.stretch_mode = TextureRect.STRETCH_SCALE
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scrim.anchor_top = 1.0
    scrim.anchor_right = 1.0
    scrim.anchor_bottom = 1.0
    scrim.offset_top = -SCRIM_HEIGHT
    scrim.grow_vertical = Control.GROW_DIRECTION_BEGIN
    scrim.visible = false
    return scrim

func _render_dots() -> void:
    for index in _progress_dots.get_child_count():
        var dot := _progress_dots.get_child(index) as PanelContainer
        var active := index == _scene_index
        dot.custom_minimum_size = Vector2(DOT_ACTIVE_WIDTH if active else DOT_SIZE, DOT_SIZE)
        var fill := UiStyle.ACCENT if active else (Color.WHITE if index < _scene_index else DOT_IDLE)
        (dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = fill

## The speaking villager stands at full strength; otherwise the scene's own portrait listens, dimmed.
## With motion the portrait slides in on its first line in a scene, fades back after
## narration, and dims or brightens smoothly.
func _render_portrait(scene_portrait: int, kind: int, speaker: int) -> void:
    var villager := speaker if speaker >= 0 else scene_portrait
    var shown := villager >= 0 and kind != ContentRules.LineKind.NARRATION and kind != ContentRules.LineKind.NOTE
    var was_shown := _portrait.visible
    _portrait.visible = shown
    if not shown:
        return
    var portrait_path := "res://assets/ui/portraits/%s.png" % VillagerRules.PORTRAIT_NAMES[villager]
    if _portrait.texture == null or _portrait.texture.resource_path != portrait_path:
        _portrait.texture = load(portrait_path)
    var strength := Color.WHITE if speaker >= 0 else DialoguePanel.DIMMED
    if not animate:
        _portrait.modulate = strength
        return
    if was_shown and _portrait_scene == _scene_index:
        if _portrait.modulate != strength or _is_running(&"dim"):
            _restart_tween(&"dim").tween_property(_portrait, "modulate", strength, PORTRAIT_DIM_SECONDS)
        return
    _kill_tween(&"dim")
    _portrait.modulate = strength
    _portrait.self_modulate.a = 0.0
    var enter := _restart_tween(&"portrait").set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    if _portrait_scene != _scene_index:
        _portrait_scene = _scene_index
        _portrait_slide = -PORTRAIT_SLIDE
        enter.tween_property(self, "_portrait_slide", 0.0, PORTRAIT_ENTER_SECONDS).set_delay(PORTRAIT_ENTER_DELAY)
        enter.tween_property(_portrait, "self_modulate:a", 1.0, PORTRAIT_ENTER_SECONDS).set_delay(PORTRAIT_ENTER_DELAY)
    else:
        enter.tween_property(_portrait, "self_modulate:a", 1.0, PORTRAIT_DIM_SECONDS)

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
    var text_value := String(line["text"])
    _body.text = (tr("“%s”") % tr(text_value)) if kind == ContentRules.LineKind.DIALOGUE else text_value
    if kind == ContentRules.LineKind.INNER_VOICE:
        UiStyle.text(_body, 34, INNER_VOICE_BODY, 500)
    else:
        UiStyle.text(_body, 36, UiStyle.INK, 700)

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
    _refresh_tutorial_card()

## The modal owner suppresses tips behind full-screen/transactional surfaces;
## clearing it recomputes the eligible prompt from the last rendered snapshot.
func set_suppressed(suppressed: bool) -> void:
    if _suppressed == suppressed:
        return
    _suppressed = suppressed
    _refresh_tutorial_card()

func _refresh_tutorial_card() -> void:
    if (
        _suppressed
        or not _tutorial_cards_enabled
        or _opening_panel.visible
        or _last_snapshot.is_empty()
    ):
        _current_prompt_id = &""
        _tutorial_card.visible = false
        return
    _render_tutorial(ContentRules.next_tutorial_prompt(_last_snapshot, _dismissed))

func _render_tutorial(prompt: Dictionary) -> void:
    _current_prompt_id = prompt.get("id", &"")
    if prompt.is_empty():
        _tutorial_card.visible = false
        return
    _tutorial_title.text = String(prompt["title"])
    _tutorial_body.text = String(prompt["body"])
    _tutorial_card.visible = true

## One dismissal path for the row and the action, keyed by the shown prompt.
func _dismiss_current_prompt() -> void:
    if _current_prompt_id != &"":
        _dismissed.append(_current_prompt_id)
    _refresh_tutorial_card()
