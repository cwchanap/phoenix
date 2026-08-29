extends GutTest

const TEST_PATH := "user://phoenix-hpa-599-finale-cue-test.json"

func before_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func after_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func _day14_pre_final_state() -> Dictionary:
    var session := GameSession.new(func() -> float: return 0.9)
    var seeded := session.state()
    seeded["day"] = GameRules.MAX_DAY
    seeded["intro_acknowledged"] = true
    seeded["harvested"] = {&"turnip": 3, &"potato": 0, &"pumpkin": 0}
    seeded["pending_shipment"] = {&"turnip": 2, &"potato": 0, &"pumpkin": 0}
    seeded["shipped"] = {&"turnip": 1, &"potato": 0, &"pumpkin": 0}
    assert_eq(GameSession.state_error(seeded), "")
    assert_true(session.restore_state(seeded))
    return session.state()

func _target_market(world: WorldShell) -> void:
    # Facing DOWN offsets the target by (+1, +1): standing at (7.5, 5.5)
    # targets the authored market cell (8, 6).
    world.player.global_position = WorldMath.grid_to_world(Vector2(7.5, 5.5))
    world.player.facing = WorldMath.Facing.DOWN
    assert_eq(world.player.current_target_cell(), WorldContract.MARKET_CELL)

func test_market_interact_keeps_world_audible_until_cue_finishes() -> void:
    assert_eq(SaveRepository.new(TEST_PATH).save(_day14_pre_final_state()), OK)
    var app := (load("res://scenes/app/app.tscn") as PackedScene).instantiate() as AppRoot
    app.configure(SaveRepository.new(TEST_PATH))
    add_child_autoqfree(app)
    (app.get_node("TitleScreen") as TitleScreen).continue_requested.emit()
    await get_tree().process_frame
    var world := app.get_node("World") as WorldShell
    var finale_emits: Array = []
    world.finale_completed.connect(func(_state: Dictionary, save_error: int) -> void:
        finale_emits.append(save_error)
    )
    _target_market(world)

    world.interact()

    # The world must survive the trigger frame with the finale cue still
    # playing, and the result must not have presented yet.
    assert_true(world.is_inside_tree(), "world should stay in tree during the finale cue")
    assert_true(app.get_node_or_null("World") == world, "app should still hold the world")
    assert_true(
        (world.hud.get_node("SfxPlayer") as AudioStreamPlayer).playing,
        "finale cue should still be playing",
    )
    assert_eq(finale_emits, [], "finale_completed must wait for the cue")

    # Then the cue ends, the world is torn down, and the result presents.
    for _frame in 120:
        if app.get_node_or_null("World") == null:
            break
        await get_tree().process_frame
    assert_null(app.get_node_or_null("World"))
    assert_true((app.get_node("ResultScreen") as ResultScreen).visible)
    assert_eq(finale_emits, [OK])
