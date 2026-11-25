extends GutTest

# Focused regressions for the HPA-863 MCP evidence driver: playtest storage is
# isolated, a failed walk stops at the first failed seek, movement input is
# released, an interact goto holds its busy lock through its final marker, and
# facing is established through the live Input sampler.

const DriverScene := preload("res://tests/native_tour/mcp_acceptance_driver.tscn")
const DriverScript := preload("res://tests/native_tour/mcp_acceptance_driver.gd")
const TEST_STORAGE_DIR := "res://test_output/mcp_acceptance_driver_gut"
const TEST_SAVE_PATH := TEST_STORAGE_DIR + "/playtest-save.json"
const TEST_SETTINGS_PATH := TEST_STORAGE_DIR + "/playtest-settings.cfg"
const TEST_LOG_PATH := "user://mcp-driver-gut.jsonl"
const MOVE_ACTIONS: Array[StringName] = [
    &"move_left", &"move_right", &"move_up", &"move_down",
]

var driver: Node


func after_each() -> void:
    for action in MOVE_ACTIONS:
        Input.action_release(action)
    OS.unset_environment("PHOENIX_MCP_LOG")
    OS.unset_environment("PHOENIX_SAVE_PATH")
    OS.unset_environment("PHOENIX_SETTINGS_PATH")
    if driver != null and driver.log_file != null:
        driver.log_file.close()
        driver.log_file = null
    driver = null
    _clean_test_storage()


func _clean_test_storage() -> void:
    for path in [TEST_SAVE_PATH, TEST_SETTINGS_PATH, TEST_LOG_PATH]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var directory := ProjectSettings.globalize_path(TEST_STORAGE_DIR)
    if DirAccess.dir_exists_absolute(directory):
        DirAccess.remove_absolute(directory)


func _wait_frames(count: int) -> void:
    for _index in count:
        await get_tree().process_frame


func _start_driver() -> Node:
    # Keep GUT's driver instance from overwriting the retained native-run log
    # or playtest save/settings storage.
    _clean_test_storage()
    OS.set_environment("PHOENIX_MCP_LOG", TEST_LOG_PATH)
    driver = DriverScene.instantiate()
    driver.call("configure_storage_dir", TEST_STORAGE_DIR)
    add_child_autoqfree(driver)
    await _wait_frames(3)
    assert_not_null(driver.app, "driver app must instantiate")
    if driver.app == null:
        return null
    var repository := driver.app._save_repository as SaveRepository
    var settings := driver.app._settings as UiSettings
    assert_not_null(repository, "the default driver app must receive a save repository")
    assert_not_null(settings, "the default driver app must receive settings")
    if repository == null or settings == null:
        return null
    assert_eq(
        repository._path,
        TEST_SAVE_PATH,
        "driver tests must isolate save storage in TEST_STORAGE_DIR",
    )
    assert_eq(
        settings._path,
        TEST_SETTINGS_PATH,
        "driver tests must isolate settings storage in TEST_STORAGE_DIR",
    )
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


func test_driver_configures_isolated_playtest_storage() -> void:
    _clean_test_storage()
    OS.set_environment("PHOENIX_SAVE_PATH", SaveRepository.DEFAULT_PATH)
    OS.set_environment("PHOENIX_SETTINGS_PATH", UiSettings.DEFAULT_PATH)
    OS.set_environment("PHOENIX_MCP_LOG", "user://mcp-driver-gut.jsonl")
    assert_eq(
        DriverScript.PLAYTEST_SAVE_PATH,
        "res://test_output/mcp_acceptance/playtest-save.json",
        "the native MCP playtest keeps its checkout-local save file",
    )
    assert_eq(
        DriverScript.PLAYTEST_SETTINGS_PATH,
        "res://test_output/mcp_acceptance/playtest-settings.cfg",
        "the native MCP playtest keeps its checkout-local settings file",
    )
    assert_ne(DriverScript.PLAYTEST_SAVE_PATH, SaveRepository.DEFAULT_PATH)
    assert_ne(DriverScript.PLAYTEST_SETTINGS_PATH, UiSettings.DEFAULT_PATH)
    driver = DriverScene.instantiate()
    assert_true(
        driver.has_method("configure_storage_dir"),
        "the driver must accept temporary storage before entering the tree",
    )
    if not driver.has_method("configure_storage_dir"):
        return
    driver.call("configure_storage_dir", TEST_STORAGE_DIR)
    add_child_autoqfree(driver)
    await _wait_frames(3)
    assert_not_null(driver.app, "driver app must instantiate")
    if driver.app == null:
        return
    var repository := driver.app._save_repository as SaveRepository
    var settings := driver.app._settings as UiSettings
    assert_not_null(repository, "the app must receive a save repository")
    assert_not_null(settings, "the app must receive settings")
    if repository == null or settings == null:
        return
    assert_eq(repository._path, TEST_SAVE_PATH, "the test uses a temporary save file")
    assert_eq(settings._path, TEST_SETTINGS_PATH, "the test uses a temporary settings file")
    assert_ne(repository._path, DriverScript.PLAYTEST_SAVE_PATH)
    assert_ne(settings._path, DriverScript.PLAYTEST_SETTINGS_PATH)
    assert_ne(repository._path, SaveRepository.DEFAULT_PATH)
    assert_ne(settings._path, UiSettings.DEFAULT_PATH)
    assert_eq(repository.save({"probe": true}), OK, "the temporary save directory must be writable")
    assert_eq(settings.set_tutorial_cards(false), OK, "the temporary settings directory must be writable")
    assert_true(FileAccess.file_exists(TEST_SAVE_PATH))
    assert_true(FileAccess.file_exists(TEST_SETTINGS_PATH))


func test_interact_goto_holds_busy_until_marker() -> void:
    var started := await _start_driver()
    if started == null:
        return
    var goal: Dictionary = driver._farm_pose(
        WorldContract.BED_CELL,
        WorldContract.bed_contact_footprint(),
        2,
        "bed",
    )
    driver._goto_interact(goal)
    var unlocked_before_marker := false
    var frames := 0
    while (
        driver.state.get_node_or_null("At_bed") == null
        and driver.state.get_node_or_null("Error") == null
        and frames < 600
    ):
        if not driver._busy:
            unlocked_before_marker = true
            break
        await get_tree().physics_frame
        frames += 1
    assert_false(
        unlocked_before_marker,
        "an interact goto must hold its busy lock through the final marker",
    )
    assert_not_null(driver.state.get_node_or_null("At_bed"))
    assert_false(driver._busy, "a completed interact goto releases the busy lock")


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


func test_yard_west_and_east_gate_routes_cross_their_gate_cells() -> void:
    var started := await _start_driver()
    if started == null:
        return
    var west_path: Array[Vector2i] = driver._path(Vector2i(19, 10), Vector2i(17, 10))
    assert_true(
        west_path.has(Vector2i(18, 10)),
        "the west-yard route must cross the approved (18,10) gate",
    )
    var east_path: Array[Vector2i] = driver._path(Vector2i(29, 11), Vector2i(31, 11))
    assert_true(
        east_path.has(Vector2i(30, 11)),
        "the east-yard route must cross the approved (30,11) gate",
    )
    assert_false(
        WorldContract.fence_cells().has(Vector2i(18, 10)),
        "the west-yard gate cell must not carry a fence",
    )
    assert_false(
        WorldContract.fence_cells().has(Vector2i(30, 11)),
        "the east-yard gate cell must not carry a fence",
    )


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
