class_name ResultScreen
extends Control

signal new_game_requested
signal return_to_title_requested

func _ready() -> void:
    ($Panel/NewGame as Button).pressed.connect(func() -> void: new_game_requested.emit())
    ($Panel/ReturnToTitle as Button).pressed.connect(func() -> void: return_to_title_requested.emit())

func present(result: Dictionary, save_error: int = OK) -> void:
    ($Panel/Title as Label).text = String(result["title"])
    ($Panel/Shipped as Label).text = "Shipped: %d crops · %dG" % [
        int(result["shipped_count"]),
        int(result["shipped_value"]),
    ]
    ($Panel/Money as Label).text = "Final money: %dG" % int(result["final_money"])
    ($Panel/Relationship as Label).text = "Closest villager: %s" % String(result["villager"])
    var villagers: Dictionary = result["villagers"]
    for id in range(VillagerRules.VillagerId.size()):
        var villager: Dictionary = villagers[VillagerRules.villager_key(id)]
        (get_node("Panel/%sLine" % VillagerRules.display_name(id)) as Label).text = "%s (%s): %s" % [
            String(villager["name"]),
            _level_display_name(villager["level"]),
            String(villager["line"]),
        ]
    ($Panel/SaveStatus as Label).text = (
        ""
        if save_error == OK
        else "Final result was not saved."
    )
    visible = true

func _level_display_name(level_key: Variant) -> String:
    for level in range(VillagerRules.RelationshipLevel.size()):
        if VillagerRules.relationship_key(level) == level_key:
            return VillagerRules.relationship_display_name(level)
    return String(level_key)
