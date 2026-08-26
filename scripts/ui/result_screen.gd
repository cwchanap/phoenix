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
    ($Panel/VillagerLine as Label).text = String(result["line"])
    ($Panel/SaveStatus as Label).text = (
        ""
        if save_error == OK
        else "Final result was not saved."
    )
    visible = true
