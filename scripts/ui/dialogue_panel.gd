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

func _ready() -> void:
    var panel := ColorRect.new()
    panel.name = "Panel"
    panel.position = Vector2(300, 38)
    panel.size = Vector2(332, 300)
    panel.color = Color(0.08, 0.1, 0.14, 0.96)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel)

    _add_label(panel, "Name", "", Vector2(12, 10), Vector2(308, 22))
    _add_label(panel, "Role", "", Vector2(12, 34), Vector2(308, 20))
    _add_label(panel, "Relationship", "", Vector2(12, 56), Vector2(308, 22))
    var line := _add_label(panel, "Line", "", Vector2(12, 82), Vector2(308, 42))
    line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _add_label(panel, "Feedback", "", Vector2(12, 128), Vector2(308, 38))
    _add_label(panel, "GiftStatus", "", Vector2(12, 168), Vector2(308, 20))

    var gift_buttons := VBoxContainer.new()
    gift_buttons.name = "GiftButtons"
    gift_buttons.position = Vector2(12, 190)
    gift_buttons.size = Vector2(180, 66)
    gift_buttons.add_theme_constant_override("separation", 3)
    panel.add_child(gift_buttons)

    var continue_button := Button.new()
    continue_button.name = "Continue"
    continue_button.text = "Continue"
    continue_button.position = Vector2(142, 264)
    continue_button.size = Vector2(86, 28)
    continue_button.focus_mode = Control.FOCUS_ALL
    continue_button.pressed.connect(_on_continue_pressed)
    panel.add_child(continue_button)

    var close_button := Button.new()
    close_button.name = "Close"
    close_button.text = "Close"
    close_button.position = Vector2(236, 264)
    close_button.size = Vector2(78, 28)
    close_button.focus_mode = Control.FOCUS_ALL
    close_button.pressed.connect(func() -> void: close_requested.emit())
    panel.add_child(close_button)

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
    visible = true
    _render()
    _focus_primary()

func _render() -> void:
    ($Panel/Name as Label).text = VillagerRules.display_name(_villager_id)
    ($Panel/Role as Label).text = VillagerRules.role_label(_villager_id)

    var relationship := _relationship_snapshot()
    ($Panel/Relationship as Label).text = "Relationship: %s · %d points" % [
        _relationship_display(relationship.get("level", &"stranger")),
        int(relationship.get("points", 0)),
    ]
    ($Panel/Line as Label).text = _lines[_line_index] if _line_index < _lines.size() else ""

    var feedback_lines: Array[String] = []
    var points_suffix := "" if _points_gained == 1 else "s"
    feedback_lines.append("+%d relationship point%s" % [_points_gained, points_suffix])
    if _gift_reaction == &"favourite":
        feedback_lines.append("Favourite gift!")
    elif _gift_reaction == &"normal":
        feedback_lines.append("Gift accepted.")
    ($Panel/Feedback as Label).text = "\n".join(feedback_lines)

    var continue_button := $Panel/Continue as Button
    var more_lines := _line_index < _lines.size() - 1
    continue_button.visible = more_lines
    var locked := _close_friend_sequence and more_lines
    ($Panel/Close as Button).visible = not locked
    _render_gift_buttons(locked)

func _render_gift_buttons(suppressed: bool) -> void:
    var gift_status := $Panel/GiftStatus as Label
    var gifts := $Panel/GiftButtons as VBoxContainer
    for child in gifts.get_children():
        gifts.remove_child(child)
        child.queue_free()
    if suppressed:
        gift_status.text = ""
        return

    var relationship := _relationship_snapshot()
    if bool(relationship.get("gifted_today", false)):
        gift_status.text = "Gift already given today"
        return

    var harvested: Dictionary = _snapshot.get("harvested", {})
    var button_count := 0
    for kind in range(GameRules.CropKind.size()):
        var quantity := int(harvested.get(GameRules.crop_key(kind), 0))
        if quantity < 1:
            continue
        var button := Button.new()
        button.name = "Give_%d" % kind
        button.text = "Give %s" % GameRules.crop_display_name(kind)
        button.custom_minimum_size = Vector2(180, 22)
        button.focus_mode = Control.FOCUS_ALL
        button.pressed.connect(_on_gift_button_pressed.bind(kind))
        gifts.add_child(button)
        button_count += 1

    gift_status.text = "No harvested crops to give" if button_count == 0 else ""

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
    gift_requested.emit(_villager_id, crop_kind)

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
    var gifts := $Panel/GiftButtons as VBoxContainer
    if gifts.get_child_count() > 0:
        (gifts.get_child(0) as Button).grab_focus()
        return
    ($Panel/Close as Button).grab_focus()

func close_panel() -> void:
    var focus_owner := get_viewport().gui_get_focus_owner()
    if focus_owner != null and is_ancestor_of(focus_owner):
        focus_owner.release_focus()
    visible = false

func _unhandled_input(event: InputEvent) -> void:
    if not visible or not event.is_action_pressed("ui_cancel"):
        return
    get_viewport().set_input_as_handled()
    if _close_friend_sequence and _line_index < _lines.size() - 1:
        return
    close_requested.emit()

func _add_label(parent: Node, node_name: String, text: String, position: Vector2, size: Vector2) -> Label:
    var label := Label.new()
    label.name = node_name
    label.text = text
    label.position = position
    label.size = size
    parent.add_child(label)
    return label
