class_name ResultScreen
extends Control

signal new_game_requested
signal return_to_title_requested

var _featured_villager := ""

func _ready() -> void:
    ($Panel/NewGame as Button).pressed.connect(func() -> void: new_game_requested.emit())
    ($Panel/ReturnToTitle as Button).pressed.connect(func() -> void: return_to_title_requested.emit())
    _style_tree(self)
    _apply_style()
    visible = false

func _unhandled_input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed(&"ui_accept"):
        new_game_requested.emit()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"ui_cancel"):
        return_to_title_requested.emit()
        get_viewport().set_input_as_handled()

func present(result: Dictionary, save_error: int = OK) -> void:
    _featured_villager = String(result["villager"])
    ($Panel/Title as Label).text = String(result["title"])
    ($Panel/Shipped as Label).text = "Shipped: %d crops · %dG" % [
        int(result["shipped_count"]),
        int(result["shipped_value"]),
    ]
    ($Panel/Money as Label).text = "Final money: %dG" % int(result["final_money"])
    ($Panel/Relationship as Label).text = "Closest villager: %s" % _featured_villager
    ($Panel/Stats/Card_0/Value as Label).text = "%d" % int(result["shipped_count"])
    ($Panel/Stats/Card_1/Value as Label).text = "%dG" % int(result["shipped_value"])
    ($Panel/Stats/Card_2/Value as Label).text = "%dG" % int(result["final_money"])
    var villagers: Dictionary = result["villagers"]
    for id in range(VillagerRules.VillagerId.size()):
        var villager: Dictionary = villagers[VillagerRules.villager_key(id)]
        var name := VillagerRules.display_name(id)
        var card := $Panel.get_node("Card_%s" % name) as Panel
        var line := $Panel.get_node("%sLine" % name) as Label
        var level_key := StringName(villager["level"])
        var level := VillagerRules.RELATIONSHIP_KEYS.find(level_key)
        line.text = "%s (%s): %s" % [
            String(villager["name"]),
            _level_display_name(level_key),
            String(villager["line"]),
        ]
        line.visible = false
        (card.get_node("Quote") as Label).text = "\u201c%s\u201d" % String(villager["line"])
        (card.get_node("Name") as Label).text = String(villager["name"])
        var heart_count := _heart_count(level)
        for heart_index in 3:
            (card.get_node("Heart_%d" % heart_index) as TextureRect).visible = heart_index < heart_count
            (card.get_node("HeartOutline_%d" % heart_index) as TextureRect).visible = heart_index >= heart_count
        var featured := String(villager["name"]) == _featured_villager
        card.add_theme_stylebox_override(
            "panel",
            UiStyle.panel(UiStyle.PRIMARY, UiStyle.GOLD if featured else UiStyle.FRAME_BORDER, 2),
        )
        UiStyle.text(card.get_node("Name") as Label, 11, UiStyle.GOLD if featured else UiStyle.CREAM, 800)
        UiStyle.text(card.get_node("Quote") as Label, 9, UiStyle.TEXT, 400)
    ($Panel/SaveStatus as Label).text = "" if save_error == OK else "Final result was not saved."
    visible = true

func featured_villager_name() -> String:
    return _featured_villager

func _level_display_name(level_key: Variant) -> String:
    for level in range(VillagerRules.RelationshipLevel.size()):
        if VillagerRules.relationship_key(level) == level_key:
            return VillagerRules.relationship_display_name(level)
    return String(level_key)

func _heart_count(level: int) -> int:
    if level == VillagerRules.RelationshipLevel.CLOSE_FRIEND:
        return 3
    if level == VillagerRules.RelationshipLevel.FRIEND:
        return 2
    return 0

func _style_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_tree(child)

func _apply_style() -> void:
    for index in 3:
        var card := $Panel/Stats.get_node("Card_%d" % index) as Panel
        card.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.INSET, UiStyle.FRAME_BORDER, 2))
        UiStyle.text(card.get_node("Value") as Label, 20, UiStyle.CREAM, 800, true)
        UiStyle.text(card.get_node("Caption") as Label, 8, UiStyle.MUTED, 800)
    ($Panel/Stats/Card_1 as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.WARNING_FILL, UiStyle.GOLD, 2)
    )
    UiStyle.text($Panel/Stats/Card_1/Value as Label, 20, UiStyle.GOLD, 800, true)
    UiStyle.text($Panel/Kicker as Label, 8, UiStyle.MUTED, 800)
    UiStyle.text($Panel/Title as Label, 26, UiStyle.GOLD, 800)
    UiStyle.text($Panel/Shipped as Label, 1, Color.TRANSPARENT)
    UiStyle.text($Panel/Money as Label, 1, Color.TRANSPARENT)
    UiStyle.text($Panel/Relationship as Label, 1, Color.TRANSPARENT)
    UiStyle.text($Panel/SaveStatus as Label, 8, UiStyle.RED, 600)
    for name in ["Mira", "Rowan", "June"]:
        var card := $Panel.get_node("Card_%s" % name) as Panel
        UiStyle.text(card.get_node("Name") as Label, 11, UiStyle.CREAM, 800)
        UiStyle.text($Panel.get_node("%sLine" % name) as Label, 8, UiStyle.MUTED, 400)
        UiStyle.text(card.get_node("Quote") as Label, 9, UiStyle.TEXT, 400)
    for button in [$Panel/NewGame as Button, $Panel/ReturnToTitle as Button]:
        UiStyle.button(button, 9, true)
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        ($Panel/NewGame as Button).add_theme_stylebox_override(
            state, UiStyle.panel(UiStyle.WARNING_FILL, UiStyle.GOLD, 1)
        )
        ($Panel/ReturnToTitle as Button).add_theme_stylebox_override(
            state, UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER_LIGHT, 1)
        )
    for keycap in [$Panel/NewGame/Keycap as Panel, $Panel/ReturnToTitle/Keycap as Panel]:
        keycap.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1))
        UiStyle.text(keycap.get_node("Label") as Label, 8, UiStyle.GOLD, 800, true)
    UiStyle.text($Panel/NewGame/Label as Label, 9, UiStyle.GOLD, 800)
    UiStyle.text($Panel/ReturnToTitle/Label as Label, 9, UiStyle.TEXT, 800)
