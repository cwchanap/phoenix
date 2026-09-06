class_name DialoguePanel
extends Control

signal gift_requested(villager_id: int, crop_kind: int)
signal close_requested

var _villager_id := -1
var _lines: Array[String] = []
var _line_index := 0
var _points_gained := 0
var _gift_reaction: StringName = &""
var _close_friend_sequence := false
var _snapshot: Dictionary = {}
var _selected_gift_kind := -1
var _gift_buttons: Array[Button] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _gift_buttons = [
        $Panel/GiftButtons/Gift_0 as Button,
        $Panel/GiftButtons/Gift_1 as Button,
        $Panel/GiftButtons/Gift_2 as Button,
    ]
    for kind in _gift_buttons.size():
        _gift_buttons[kind].pressed.connect(_on_gift_button_pressed.bind(kind))
        _gift_buttons[kind].focus_entered.connect(_on_gift_focus_entered.bind(kind))
    ($Panel/Continue as Button).pressed.connect(_on_continue_pressed)
    ($Panel/Close as Button).pressed.connect(func() -> void: close_requested.emit())
    _style_authored_tree(self)
    _apply_authored_style()
    ($Panel/Continue as Button).modulate = Color(1, 1, 1, 0)
    ($Panel/Close as Button).modulate = Color(1, 1, 1, 0)
    visible = false

func present(villager_id: int, result: Dictionary, snapshot: Dictionary) -> void:
    _villager_id = villager_id
    _snapshot = snapshot.duplicate(true)

    var incoming_lines: Array = result.get("lines", [])
    if not incoming_lines.is_empty() or _lines.is_empty():
        _lines.clear()
        for line in incoming_lines:
            _lines.append(String(line))
        _line_index = 0
    _points_gained = int(result.get("points_gained", 0))
    _gift_reaction = StringName(result.get("gift_reaction", &""))
    _close_friend_sequence = bool(result.get("close_friend_sequence", false))
    _selected_gift_kind = int(result.get("selected_crop_kind", -1))
    _select_first_available_gift()
    visible = true
    _render()
    _focus_primary()

func _render() -> void:
    var name_label := $Panel/Name as Label
    var role_label := $Panel/Role as Label
    var relationship_label := $Panel/Relationship as Label
    name_label.text = VillagerRules.display_name(_villager_id)
    role_label.text = VillagerRules.role_label(_villager_id)

    var relationship := _relationship_snapshot()
    relationship_label.text = "%s  ·  %d/%d" % [
        _relationship_display(relationship.get("level", &"stranger")).to_upper(),
        int(relationship.get("points", 0)),
        VillagerRules.CLOSE_FRIEND_POINTS,
    ]
    ($Panel/Line as Label).text = _lines[_line_index] if _line_index < _lines.size() else ""

    var feedback_lines: Array[String] = []
    if _points_gained > 0:
        var points_suffix := "" if _points_gained == 1 else "s"
        feedback_lines.append("+%d relationship point%s" % [_points_gained, points_suffix])
    if _gift_reaction == &"favourite":
        feedback_lines.append("Favourite gift!")
    elif _gift_reaction == &"normal":
        feedback_lines.append("Gift accepted.")
    var feedback_label := $Panel/Feedback as Label
    var feedback_badge := $Panel/FeedbackBadge as Panel
    var points_only := _points_gained > 0 and feedback_lines.size() == 1
    feedback_label.text = "\n".join(feedback_lines)
    feedback_label.visible = not feedback_lines.is_empty() and not points_only
    feedback_badge.visible = points_only
    if points_only:
        ($Panel/FeedbackBadge/Value as Label).text = "+%d" % _points_gained

    var continue_button := $Panel/Continue as Button
    var more_lines := _line_index < _lines.size() - 1
    continue_button.visible = more_lines
    var locked := _close_friend_sequence and more_lines
    ($Panel/Close as Button).visible = not locked
    ($Panel/Footer/EscText as Label).text = "continue" if locked else "leave"
    _render_relationship(relationship)
    _render_gift_buttons(locked)

func _render_relationship(relationship: Dictionary) -> void:
    var points := int(relationship.get("points", 0))
    var filled := mini(points / 6, 3)
    for index in 3:
        var heart := $Panel/Header.get_node("Heart_%d" % index) as TextureRect
        heart.texture = load(
            "res://assets/ui/icons/heart-filled.png"
            if index < filled
            else "res://assets/ui/icons/heart-outline.png"
        ) as Texture2D
    var fill := $Panel/Header/ProgressFill as ColorRect
    fill.size.x = 78.0 * clampf(float(points) / float(VillagerRules.CLOSE_FRIEND_POINTS), 0.0, 1.0)
    ($Panel/Header/ProgressValue as Label).text = "%d/%d" % [
        points,
        VillagerRules.CLOSE_FRIEND_POINTS,
    ]

func _render_gift_buttons(suppressed: bool) -> void:
    var gift_status := $Panel/GiftStatus as Label
    var gift_hint := $Panel/GiftHint as Label
    var action_text := $Panel/Footer/ActionText as Label
    if suppressed:
        gift_status.text = ""
        gift_hint.visible = false
        action_text.text = "CONTINUE"
        for button in _gift_buttons:
            button.visible = false
        return

    var relationship := _relationship_snapshot()
    if bool(relationship.get("gifted_today", false)):
        gift_status.text = "GIFT GIVEN TODAY"
        gift_hint.visible = false
        action_text.text = "CLOSE"
        for button in _gift_buttons:
            button.visible = false
        return

    var harvested: Dictionary = _snapshot.get("harvested", {})
    gift_status.text = "GIVE A GIFT  ·  ONE PER DAY"
    gift_hint.visible = false
    action_text.text = "GIVE"
    for kind in _gift_buttons.size():
        var button := _gift_buttons[kind]
        var quantity := int(harvested.get(GameRules.crop_key(kind), 0))
        var favourite := VillagerRules.is_favourite_crop(_villager_id, kind)
        button.visible = true
        button.disabled = quantity < 1
        button.focus_mode = Control.FOCUS_ALL
        button.modulate = Color.WHITE if quantity > 0 else Color(0.5, 0.54, 0.62, 1.0)
        button.add_theme_stylebox_override(
            "normal",
            UiStyle.panel(
                UiStyle.KEYCAP_FILL if kind == _selected_gift_kind else UiStyle.INSET,
                UiStyle.GOLD if kind == _selected_gift_kind else UiStyle.BORDER,
                2 if kind == _selected_gift_kind else 1,
            ),
        )
        (button.get_node("Keycap") as Panel).visible = quantity > 0
        (button.get_node("Icon") as TextureRect).texture = load(
            "res://assets/ui/crops/%s.png" % GameRules.crop_key(kind)
        ) as Texture2D
        (button.get_node("Count") as Label).text = "%d" % quantity
        (button.get_node("Count") as Label).visible = quantity > 0
        (button.get_node("Value") as Label).text = (
            "+%d ♥" % VillagerRules.gift_points(_villager_id, kind)
            if quantity > 0 and favourite
            else "+%d" % VillagerRules.gift_points(_villager_id, kind)
            if quantity > 0
            else "none"
        )
        UiStyle.text(
            button.get_node("Value") as Label,
            8,
            UiStyle.GOLD if quantity > 0 and favourite else UiStyle.MUTED,
            800,
            true,
        )
    if _selected_gift_kind >= 0 and _selected_gift_kind < _gift_buttons.size():
        var selected := _gift_buttons[_selected_gift_kind]
        var selected_quantity := int(harvested.get(
            GameRules.crop_key(_selected_gift_kind),
            0,
        ))
        if selected.visible and not selected.disabled:
            var selected_name := GameRules.crop_display_name(_selected_gift_kind)
            action_text.text = "GIVE %s" % selected_name.to_upper()
            if VillagerRules.is_favourite_crop(_villager_id, _selected_gift_kind):
                gift_hint.text = "%s is %s's favourite — worth %d instead of %d." % [
                    selected_name,
                    VillagerRules.display_name(_villager_id),
                    VillagerRules.gift_points(_villager_id, _selected_gift_kind),
                    VillagerRules.GIFT_POINTS,
                ]
                gift_hint.visible = selected_quantity > 0

func _select_first_available_gift() -> void:
    var harvested: Dictionary = _snapshot.get("harvested", {})
    if _selected_gift_kind >= 0 and int(harvested.get(GameRules.crop_key(_selected_gift_kind), 0)) > 0:
        return
    for kind in range(GameRules.CropKind.size()):
        if int(harvested.get(GameRules.crop_key(kind), 0)) > 0:
            _selected_gift_kind = kind
            return
    _selected_gift_kind = 0

func _relationship_snapshot() -> Dictionary:
    var relationships: Dictionary = _snapshot.get("relationships", {})
    var relationship: Variant = relationships.get(VillagerRules.villager_key(_villager_id), {})
    return relationship if relationship is Dictionary else {}

func _relationship_display(level_key: Variant) -> String:
    for level in range(VillagerRules.RelationshipLevel.size()):
        if VillagerRules.relationship_key(level) == level_key:
            return VillagerRules.relationship_display_name(level)
    return String(level_key)

func _on_gift_button_pressed(crop_kind: int) -> void:
    if _gift_buttons[crop_kind].disabled:
        return
    _selected_gift_kind = crop_kind
    _render_gift_buttons(false)
    gift_requested.emit(_villager_id, crop_kind)

func _on_gift_focus_entered(crop_kind: int) -> void:
    _selected_gift_kind = crop_kind
    if visible and not _close_friend_sequence:
        _render_gift_buttons(false)

func _on_continue_pressed() -> void:
    if _line_index >= _lines.size() - 1:
        return
    _line_index += 1
    _render()
    _focus_primary()

func _focus_primary() -> void:
    if _line_index < _lines.size() - 1:
        ($Panel/Continue as Button).grab_focus()
        return
    if _selected_gift_kind >= 0 and _selected_gift_kind < _gift_buttons.size():
        var selected_button := _gift_buttons[_selected_gift_kind]
        if selected_button.visible and not selected_button.disabled:
            selected_button.grab_focus()
            return
    for button in _gift_buttons:
        if button.visible and not button.disabled:
            button.grab_focus()
            return
    ($Panel/Close as Button).grab_focus()

func close_panel() -> void:
    var focus_owner := get_viewport().gui_get_focus_owner()
    if focus_owner != null and is_ancestor_of(focus_owner):
        focus_owner.release_focus()
    visible = false

func _input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
        var delta := -1 if event.is_action_pressed("move_left") else 1
        _select_gift(delta)
        get_viewport().set_input_as_handled()

func _select_gift(delta: int) -> void:
    var next := _selected_gift_kind
    for _step in GameRules.CropKind.size():
        next = posmod(next + delta, GameRules.CropKind.size())
        if _gift_buttons[next].visible and not _gift_buttons[next].disabled:
            _selected_gift_kind = next
            _gift_buttons[next].grab_focus()
            _render_gift_buttons(false)
            return

func _unhandled_input(event: InputEvent) -> void:
    if not visible or not event.is_action_pressed("ui_cancel"):
        return
    get_viewport().set_input_as_handled()
    if _close_friend_sequence and _line_index < _lines.size() - 1:
        return
    close_requested.emit()

func _style_authored_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_authored_tree(child)

func _apply_authored_style() -> void:
    ($Panel as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.PRIMARY, UiStyle.FRAME_BORDER, 2),
    )
    ($Panel/Header as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0),
    )
    ($Panel/Footer as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0),
    )
    UiStyle.text($Panel/Name as Label, 14, UiStyle.CREAM, 800)
    UiStyle.text($Panel/Role as Label, 9, UiStyle.MUTED, 700)
    UiStyle.text($Panel/Relationship as Label, 10, UiStyle.GOLD, 800)
    UiStyle.text($Panel/Header/RelationshipTitle as Label, 8, UiStyle.GOLD, 700)
    UiStyle.text($Panel/Header/ProgressValue as Label, 9, UiStyle.MUTED, 700, true)
    UiStyle.text($Panel/Line as Label, 13, UiStyle.CREAM, 400)
    UiStyle.text($Panel/Feedback as Label, 10, UiStyle.GREEN, 700)
    ($Panel/FeedbackBadge as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.INSET, UiStyle.GREEN, 1),
    )
    UiStyle.text($Panel/FeedbackBadge/Value as Label, 10, UiStyle.GREEN, 800)
    UiStyle.text($Panel/GiftStatus as Label, 8, UiStyle.MUTED, 700, true)
    UiStyle.text($Panel/GiftHint as Label, 8, UiStyle.GOLD, 700)
    UiStyle.text($Panel/Footer/EscKey as Label, 8, UiStyle.TEXT, 800, true)
    UiStyle.text($Panel/Footer/EscText as Label, 9, UiStyle.MUTED, 600)
    UiStyle.text($Panel/Footer/EnterKey as Label, 8, UiStyle.GOLD, 800, true)
    UiStyle.text($Panel/Footer/ActionText as Label, 9, UiStyle.GOLD, 800)
    ($Panel/Footer/EscKeycap as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.INSET, UiStyle.BORDER_LIGHT, 1),
    )
    ($Panel/Footer/EnterKeycap as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1),
    )
    for button in _gift_buttons:
        UiStyle.button(button, 8)
        button.focus_mode = Control.FOCUS_ALL
        UiStyle.text(button.get_node("Count") as Label, 8, UiStyle.CREAM, 800, true)
        UiStyle.text(button.get_node("Value") as Label, 8, UiStyle.MUTED, 800, true)
        var keycap := button.get_node("Keycap") as Panel
        keycap.add_theme_stylebox_override(
            "panel",
            UiStyle.panel(UiStyle.INSET, UiStyle.BORDER_LIGHT, 1),
        )
        UiStyle.text(keycap.get_node("Key") as Label, 8, UiStyle.TEXT, 800, true)
    ($Panel/Continue as Button).focus_mode = Control.FOCUS_ALL
    ($Panel/Close as Button).focus_mode = Control.FOCUS_ALL
