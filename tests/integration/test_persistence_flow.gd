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

func _target_market(world: WorldShell) -> void:
    # Facing DOWN offsets the target by (+1, +1): standing at (7.5, 5.5)
    # targets the authored market cell (8, 6).
    world.player.global_position = WorldMath.grid_to_world(Vector2(7.5, 5.5))
    world.player.facing = WorldMath.Facing.DOWN
    assert_eq(world.player.current_target_cell(), WorldContract.MARKET_CELL)

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

func _await_world_teardown(app: AppRoot) -> void:
    # The finale cue holds the live world for a beat before finale_completed
    # fires and AppRoot tears it down; wait (bounded) for that handoff.
    for _frame in 120:
        if app.get_node_or_null("World") == null:
            return
        await get_tree().process_frame
    fail_test("World was never torn down after the finale cue")

func _launch_continued(repository: SaveRepository) -> AppRoot:
    var app := APP_SCENE.instantiate() as AppRoot
    app.configure(repository)
    add_child_autoqfree(app)
    (app.get_node("TitleScreen") as TitleScreen).continue_requested.emit()
    await get_tree().process_frame
    return app

func _seed_slot(state: Dictionary) -> void:
    assert_eq(SaveRepository.new(TEST_PATH).save(state), OK)

func test_market_and_bed_finalizations_save_once_and_reach_identical_result() -> void:
    var pre_final := _day14_pre_final_state()

    _seed_slot(pre_final)
    var market_repository := CountingSaveRepository.new(TEST_PATH)
    var market_app := await _launch_continued(market_repository)
    var market_world := market_app.get_node("World") as WorldShell
    var finale_emits: Array = []
    market_world.finale_completed.connect(func(_state: Dictionary, save_error: int) -> void:
        finale_emits.append(save_error)
    )
    _target_market(market_world)
    market_world.interact()
    # The save stays synchronous; only the emit/teardown wait out the cue.
    assert_eq(market_repository.save_calls, 1)
    var market_state := market_world._session.state()

    # A duplicate terminal attempt during the cue cannot add a save.
    market_world.interact()
    assert_eq(market_repository.save_calls, 1)

    await _await_world_teardown(market_app)
    assert_eq(finale_emits, [OK])
    var market_result := market_app.get_node("ResultScreen") as ResultScreen
    assert_true(market_result.visible)

    _seed_slot(pre_final)
    var bed_repository := CountingSaveRepository.new(TEST_PATH)
    var bed_app := await _launch_continued(bed_repository)
    var bed_world := bed_app.get_node("World") as WorldShell
    _target_bed(bed_world)
    bed_world.hud.sleep_requested.emit()
    assert_eq(bed_repository.save_calls, 1)
    var bed_state := bed_world._session.state()
    await _await_world_teardown(bed_app)
    assert_null(bed_app.get_node_or_null("World"))
    assert_true((bed_app.get_node("ResultScreen") as ResultScreen).visible)

    assert_eq(market_state, bed_state)
    assert_eq(
        ContentRules.build_harvest_result(market_state),
        ContentRules.build_harvest_result(bed_state),
    )

    var loaded := market_repository.load()
    assert_eq(loaded["status"], &"loaded")
    assert_eq(GameSession.state_error(loaded["state"]), "")
    var canonical := GameSession.new(func() -> float: return 0.9)
    assert_true(canonical.restore_state(loaded["state"]))
    assert_eq(canonical.state(), market_state)

func test_duplicate_sleep_during_finale_does_not_restart_cue() -> void:
    _seed_slot(_day14_pre_final_state())
    var repository := CountingSaveRepository.new(TEST_PATH)
    var app := await _launch_continued(repository)
    var world := app.get_node("World") as WorldShell
    _target_bed(world)
    # First sleep on Day 14 triggers the finale and starts the cue.
    world.hud.sleep_requested.emit()
    assert_eq(repository.save_calls, 1)
    var feedback := world.hud.get_node("HudRoot/Feedback") as Label
    assert_eq(feedback.text, "Harvest finale complete.")
    # The sleep confirmation modal stays open during the cue, so a duplicate
    # sleep request can still reach _on_sleep_requested. It must be ignored:
    # without the guard it would resolve to FINALE_ALREADY_TRIGGERED, whose
    # show_feedback() restarts FINALE_SFX and cuts the original cue (and the
    # feedback text would flip to "The harvest finale is already complete.").
    world.hud.sleep_requested.emit()
    assert_eq(feedback.text, "Harvest finale complete.")
    assert_eq(repository.save_calls, 1)
    await _await_world_teardown(app)

func test_terminal_settlement_pays_pending_once_and_keeps_carried_crops() -> void:
    _seed_slot(_day14_pre_final_state())
    var repository := CountingSaveRepository.new(TEST_PATH)
    var app := await _launch_continued(repository)
    var world := app.get_node("World") as WorldShell
    _target_market(world)
    world.interact()

    var state := world._session.state()
    assert_eq(int(state["money"]), GameRules.STARTING_MONEY + 2 * 35)
    assert_eq(state["shipped"], {&"turnip": 3, &"potato": 0, &"pumpkin": 0})
    assert_eq(state["pending_shipment"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(state["harvested"], {&"turnip": 3, &"potato": 0, &"pumpkin": 0})
    var expected_result := ContentRules.build_harvest_result(state)
    assert_eq(int(expected_result["shipped_count"]), 3)
    await _await_world_teardown(app)
    var result := app.get_node("ResultScreen") as ResultScreen
    assert_eq(
        (result.get_node("Panel/Shipped") as Label).text,
        "Shipped: %d crops · %dG" % [
            int(expected_result["shipped_count"]),
            int(expected_result["shipped_value"]),
        ],
    )

func test_finale_save_failure_still_completes_and_shows_unsaved_result() -> void:
    var failure_dir := ProjectSettings.globalize_path(FAILURE_DIR)
    DirAccess.make_dir_recursive_absolute(failure_dir)
    var repository := SaveRepository.new(FAILURE_PATH)
    assert_eq(repository.save(_day14_pre_final_state()), OK)

    var app := APP_SCENE.instantiate() as AppRoot
    app.configure(repository)
    add_child_autoqfree(app)
    (app.get_node("TitleScreen") as TitleScreen).continue_requested.emit()
    await get_tree().process_frame
    var world := app.get_node("World") as WorldShell
    var finale_errors: Array = []
    world.finale_completed.connect(func(_state: Dictionary, save_error: int) -> void:
        finale_errors.append(save_error)
    )
    _target_market(world)

    assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(FAILURE_PATH)), OK)
    assert_eq(DirAccess.remove_absolute(failure_dir), OK)

    world.interact()
    assert_true(bool(world._session.state()["finale_triggered"]))

    await _await_world_teardown(app)
    assert_eq(finale_errors.size(), 1)
    assert_ne(int(finale_errors[0]), OK)
    assert_null(app.get_node_or_null("World"))
    var result := app.get_node("ResultScreen") as ResultScreen
    assert_true(result.visible)
    assert_eq((result.get_node("Panel/SaveStatus") as Label).text, "Final result was not saved.")

func test_result_return_to_title_reloads_save_and_new_game_keeps_slot() -> void:
    _seed_slot(_day14_pre_final_state())
    var repository := CountingSaveRepository.new(TEST_PATH)
    var app := await _launch_continued(repository)
    var world := app.get_node("World") as WorldShell
    _target_market(world)
    world.interact()
    assert_eq(repository.save_calls, 1)
    await _await_world_teardown(app)
    var result := app.get_node("ResultScreen") as ResultScreen
    assert_true(result.visible)

    (result.get_node("Panel/ReturnToTitle") as Button).pressed.emit()
    var title := app.get_node("TitleScreen") as TitleScreen
    assert_true(title.visible)
    assert_false(result.visible)
    assert_false((title.get_node("Panel/Continue") as Button).disabled)

    title.continue_requested.emit()
    assert_null(app.get_node_or_null("World"))
    assert_true(result.visible)

    # The old World was removed before queue_free(), so the guard already
    # cleared and a same-frame New Game launches a fresh run.
    (result.get_node("Panel/NewGame") as Button).pressed.emit()
    var fresh_world := app.get_node("World") as WorldShell
    assert_eq(fresh_world._session.state()["day"], 1)
    assert_false(fresh_world._session.state()["finale_triggered"])

    var existing := repository.load()
    assert_eq(existing["status"], &"loaded")
    assert_true(bool(existing["state"]["finale_triggered"]))

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

    restored_world.hud.morning_summary_acknowledged.emit()
    assert_null(restored_world._session.state()["pending_morning_summary"])
    var resumed_cell: Vector2i = WorldContract.farm_cells()[2]
    assert_eq(
        restored_world._session.hoe(resumed_cell),
        GameRules.CommandCode.SOIL_TILLED,
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
