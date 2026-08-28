class_name AppRoot
extends Node

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
var _save_repository: SaveRepository
var _continue_state: Variant = null
@onready var _title_screen: TitleScreen = $TitleScreen as TitleScreen
@onready var _result_screen: ResultScreen = $ResultScreen as ResultScreen

func configure(repository: SaveRepository) -> void:
    assert(not is_inside_tree())
    _save_repository = repository

func _ready() -> void:
    if _save_repository == null:
        var path := OS.get_environment("PHOENIX_SAVE_PATH")
        _save_repository = SaveRepository.new(
            path if not path.is_empty() else SaveRepository.DEFAULT_PATH
        )
    _title_screen.new_game_requested.connect(_on_new_game_requested)
    _title_screen.continue_requested.connect(_on_continue_requested)
    _result_screen.new_game_requested.connect(_on_result_new_game_requested)
    _result_screen.return_to_title_requested.connect(_on_result_return_to_title)
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
    if initial_state != null and bool(initial_state["finale_triggered"]):
        _show_result(initial_state, OK)
        return
    var world := WORLD_SCENE.instantiate() as WorldShell
    world.name = "World"
    world.configure(initial_state, _save_repository)
    world.finale_completed.connect(_on_finale_completed)
    add_child(world)
    _title_screen.visible = false

func _on_finale_completed(final_state: Dictionary, save_error: int) -> void:
    _show_result(final_state, save_error)

func _show_result(state: Dictionary, save_error: int) -> void:
    var world := get_node_or_null("World")
    if world != null:
        remove_child(world)
        world.queue_free()
    _title_screen.visible = false
    _result_screen.present(ContentRules.build_harvest_result(state), save_error)

func _on_result_new_game_requested() -> void:
    _result_screen.visible = false
    _launch(null)

func _on_result_return_to_title() -> void:
    _result_screen.visible = false
    _title_screen.visible = true
    _load_title_state()
