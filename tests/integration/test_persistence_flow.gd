extends GutTest

class CountingSaveRepository:
    extends SaveRepository

    var save_calls := 0

    func save(state: Dictionary) -> Error:
        save_calls += 1
        return super.save(state)

const APP_SCENE := preload("res://scenes/app/app.tscn")
const TEST_PATH := "user://phoenix-hpa-598-flow-test.json"
const FAILURE_PATH := "user://missing-hpa-598-flow-dir/save.json"
const FAILURE_DIR := "user://missing-hpa-598-flow-dir"

func _clean() -> void:
    for path in [TEST_PATH, FAILURE_PATH]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var failure_dir := ProjectSettings.globalize_path(FAILURE_DIR)
    if DirAccess.dir_exists_absolute(failure_dir):
        DirAccess.remove_absolute(failure_dir)

func before_each() -> void:
    _clean()

func after_each() -> void:
    _clean()

func _command_driven_pre_save_state() -> Dictionary:
    var session := GameSession.new(func() -> float: return 0.9)
    var first: Vector2i = WorldContract.farm_cells()[0]
    var second: Vector2i = WorldContract.farm_cells()[1]

    for cell in [first, second]:
        assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
        assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)

    for _night in GameRules.growth_nights(GameRules.CropKind.TURNIP):
        assert_eq(session.water(first), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.water(second), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            session.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )

    assert_eq(session.harvest(first), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(session.harvest(second), GameRules.CommandCode.CROP_HARVESTED)
    var june := VillagerRules.VillagerId.RESIDENT
    assert_eq(
        session.talk_to(june, WorldContract.villager_cell(june))["code"],
        GameRules.CommandCode.VILLAGER_TALKED,
    )
    assert_eq(
        session.gift_crop(
            june,
            GameRules.CropKind.TURNIP,
            WorldContract.villager_cell(june),
        )["code"],
        GameRules.CommandCode.CROP_GIFTED,
    )
    assert_eq(
        session.deposit_crop(
            GameRules.CropKind.TURNIP,
            1,
            WorldContract.SHIPPING_CELL,
        ),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    return session.state()

func _target_bed(world: WorldShell) -> void:
    world.player.global_position = WorldMath.grid_to_world(Vector2(5.5, 7.5))
    world.player.facing = WorldMath.Facing.DOWN
    assert_eq(world.player.current_target_cell(), WorldContract.BED_CELL)

func test_sleep_writes_once_and_continue_restores_complete_morning() -> void:
    var prepared := _command_driven_pre_save_state()
    assert_eq(SaveRepository.new(TEST_PATH).save(prepared), OK)

    var repository := CountingSaveRepository.new(TEST_PATH)
    var app := APP_SCENE.instantiate() as AppRoot
    app.configure(repository)
    add_child_autoqfree(app)
    var title := app.get_node("TitleScreen") as TitleScreen
    title.continue_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    assert_eq(world._session.state(), prepared)
    _target_bed(world)

    # Synchronous handler: the second signal sees the pending summary and cannot save again.
    world.hud.sleep_requested.emit()
    world.hud.sleep_requested.emit()

    assert_eq(repository.save_calls, 1)
    var saved_result := repository.load()
    assert_eq(saved_result["status"], &"loaded")
    var saved_state: Dictionary = saved_result["state"]
    assert_eq(GameSession.state_error(saved_state), "")
    assert_eq(int(saved_state["day"]), int(prepared["day"]) + 1)

    var canonical_saved := GameSession.new(func() -> float: return 0.9)
    assert_true(canonical_saved.restore_state(saved_state))
    assert_eq(canonical_saved.state(), world._session.state())
    assert_eq(canonical_saved.state()["pending_shipment"][&"turnip"], 0)
    assert_true(int(canonical_saved.state()["money"]) > int(prepared["money"]))
    assert_false(canonical_saved.state()["relationships"][&"resident"]["talked_today"])
    assert_false(canonical_saved.state()["relationships"][&"resident"]["gifted_today"])
    assert_not_null(canonical_saved.state()["pending_morning_summary"])

    app.queue_free()
    await get_tree().process_frame

    var restored_app := APP_SCENE.instantiate() as AppRoot
    restored_app.configure(repository)
    add_child_autoqfree(restored_app)
    var restored_title := restored_app.get_node("TitleScreen") as TitleScreen
    restored_title.continue_requested.emit()
    await get_tree().process_frame

    var restored_world := restored_app.get_node("World") as WorldShell
    assert_eq(restored_world._session.state(), canonical_saved.state())
    assert_true(
        WorldMath.world_to_grid(restored_world.player.global_position).distance_to(
            WorldContract.PLAYER_SPAWN
        ) <= 0.0001
    )

func test_sleep_keeps_morning_and_reports_save_failure() -> void:
    var repository := SaveRepository.new(FAILURE_PATH)
    var app := APP_SCENE.instantiate() as AppRoot
    app.configure(repository)
    add_child_autoqfree(app)
    var title := app.get_node("TitleScreen") as TitleScreen
    title.new_game_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    _target_bed(world)
    world.hud.sleep_requested.emit()

    var state := world._session.state()
    assert_eq(int(state["day"]), 2)
    assert_not_null(state["pending_morning_summary"])
    var status := world.hud.get_node("HudRoot/MorningSummaryPanel/SaveStatus") as Label
    assert_eq(status.text, "Save failed — this morning is not persisted.")
