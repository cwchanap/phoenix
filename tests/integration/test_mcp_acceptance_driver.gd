extends GutTest

# Focused regression for the HPA-863 MCP evidence driver: a failed walk must
# stop at the first failed seek, release movement input and leave an Error
# marker, and a successful interact goto must establish facing through the
# live Input sampler rather than a direct `player.facing` write.

const DriverScene := preload("res://tests/native_tour/mcp_acceptance_driver.tscn")
const MOVE_ACTIONS: Array[StringName] = [
    &"move_left", &"move_right", &"move_up", &"move_down",
]

var driver: Node


func after_each() -> void:
    for action in MOVE_ACTIONS:
        Input.action_release(action)
    OS.unset_environment("PHOENIX_MCP_LOG")
    driver = null


func _wait_frames(count: int) -> void:
    for _index in count:
        await get_tree().process_frame


func _start_driver() -> Node:
    # Keep GUT's driver instance from overwriting the retained native-run log.
    OS.set_environment("PHOENIX_MCP_LOG", "user://mcp-driver-gut.jsonl")
    driver = DriverScene.instantiate()
    add_child_autoqfree(driver)
    await _wait_frames(3)
    assert_not_null(driver.app, "driver app must instantiate")
    if driver.app == null:
        return null
    var title := driver.app.get_node_or_null("TitleScreen") as TitleScreen
    assert_not_null(title, "title screen must exist")
    if title == null:
        return null
    title.new_game_requested.emit()
    await _wait_frames(3)
    var skip := driver.app.find_child("Skip", true, false) as BaseButton
    assert_not_null(skip, "new game must open the skippable prologue")
    if skip == null:
        return null
    skip.pressed.emit()
    await _wait_frames(3)
    assert_not_null(driver._world(), "new game must reach the live world")
    if driver._world() == null:
        return null
    driver._world().clock_running = false
    return driver


func test_failed_seek_propagates_and_releases_movement_input() -> void:
    var started := await _start_driver()
    if started == null:
        return
    var reached: bool = await driver._walk_to(
        WorldMath.grid_to_world(Vector2(3.5, 34.5)), "timeout_probe", 1
    )
    assert_false(reached, "a timed-out seek must make the walk fail")
    assert_not_null(
        driver.state.get_node_or_null("Error"),
        "the driver must retain an Error marker after the failed walk",
    )
    assert_null(
        driver.state.get_node_or_null("At_timeout_probe"),
        "a failed walk must not publish an At_ goal marker",
    )
    assert_true(
        driver.player().global_position.distance_to(
            WorldMath.grid_to_world(Vector2(3.5, 34.5))
        ) > 100.0,
        "a 1 ms seek timeout must not reach the far target",
    )
    for action in MOVE_ACTIONS:
        assert_false(Input.is_action_pressed(action), "%s must be released" % action)


func test_unreachable_goto_keeps_error_marker() -> void:
    var started := await _start_driver()
    if started == null:
        return
    await driver._goto_cell(Vector2i(999, 999), "unreachable")
    assert_not_null(driver.state.get_node_or_null("Error"))
    assert_null(driver.state.get_node_or_null("At_unreachable"))
    for action in MOVE_ACTIONS:
        assert_false(Input.is_action_pressed(action), "%s must be released" % action)


func test_interact_goto_establishes_facing_through_input() -> void:
    var started := await _start_driver()
    if started == null:
        return
    var goal: Dictionary = driver._farm_pose(
        WorldContract.BED_CELL,
        WorldContract.bed_contact_footprint(),
        2,
        "bed",
    )
    await driver._goto_interact(goal)
    assert_not_null(
        driver.state.get_node_or_null("At_bed"),
        "a successful interact goto publishes its goal marker",
    )
    assert_null(driver.state.get_node_or_null("Error"))
    assert_eq(driver.player().facing, WorldMath.Facing.UP)
    for action in MOVE_ACTIONS:
        assert_false(Input.is_action_pressed(action), "%s must be released" % action)
