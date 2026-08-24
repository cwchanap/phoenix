class_name AppRoot
extends Node

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
var _save_repository: SaveRepository
var _continue_state: Variant = null
@onready var _title_screen: TitleScreen = $TitleScreen as TitleScreen

func configure(repository: SaveRepository) -> void:
    assert(not is_inside_tree())
    _save_repository = repository

func _ready() -> void:
    if _save_repository == null:
        _save_repository = SaveRepository.new()
    _title_screen.new_game_requested.connect(_on_new_game_requested)
    _title_screen.continue_requested.connect(_on_continue_requested)
    _load_title_state()

func _load_title_state() -> void:
    var result := _save_repository.load()
    match result["status"]:
        &"missing":
            _continue_state = null
            _title_screen.set_continue_state(false)
        &"loaded":
            var error := GameSession.state_error(result["state"])
            if error == "":
                _continue_state = result["state"].duplicate(true)
                _title_screen.set_continue_state(true)
            else:
                _continue_state = null
                _title_screen.set_continue_state(false, "Save is incompatible; start a New Game.")
        &"invalid", &"io_error":
            _continue_state = null
            _title_screen.set_continue_state(false, "Save unavailable; start a New Game.")

func _on_new_game_requested() -> void:
    _launch(null)

func _on_continue_requested() -> void:
    if _continue_state != null:
        _launch(_continue_state)

func _launch(initial_state: Variant) -> void:
    if get_node_or_null("World") != null:
        return
    var world := WORLD_SCENE.instantiate() as WorldShell
    world.name = "World"
    world.configure(initial_state, _save_repository)
    add_child(world)
    _title_screen.visible = false
