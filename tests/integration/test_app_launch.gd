extends GutTest

const TEST_PATH := "user://phoenix-hpa-598-app-launch-test.json"

func _clean() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func before_each() -> void:
    _clean()

func after_each() -> void:
    _clean()

func _spawn_app(repository: SaveRepository) -> AppRoot:
    var packed := load("res://scenes/app/app.tscn") as PackedScene
    assert_not_null(packed)
    if packed == null:
        return null
    var app := packed.instantiate() as AppRoot
    assert_not_null(app)
    if app == null:
        return null
    app.configure(repository)
    add_child_autoqfree(app)
    return app

func test_continue_restores_state_and_uses_authored_spawn() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var saved_session := GameSession.new(func() -> float: return 0.9)
    assert_eq(saved_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var saved_state := saved_session.state()
    assert_eq(repository.save(saved_state), OK)

    var app := _spawn_app(repository)
    if app == null:
        return
    var title := app.get_node("TitleScreen") as TitleScreen
    var continue_button := title.get_node("Panel/Continue") as Button
    assert_false(continue_button.disabled)
    title.continue_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    assert_eq(world._session.state(), saved_state)
    assert_true(
        WorldMath.world_to_grid(world.player.global_position).distance_to(
            WorldContract.PLAYER_SPAWN
        ) <= 0.0001
    )

func test_incompatible_slot_refuses_continue_but_new_game_still_launches() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var incompatible := GameSession.new(func() -> float: return 0.9).state()
    incompatible["day"] = GameRules.MAX_DAY + 1
    assert_eq(repository.save(incompatible), OK)

    var app := _spawn_app(repository)
    if app == null:
        return
    var title := app.get_node("TitleScreen") as TitleScreen
    var continue_button := title.get_node("Panel/Continue") as Button
    var status := title.get_node("Panel/Status") as Label
    assert_true(continue_button.disabled)
    assert_ne(status.text, "")

    # Bypass the disabled Button and prove AppRoot itself refuses the launch.
    title.continue_requested.emit()
    await get_tree().process_frame
    assert_null(app.get_node_or_null("World"))

    title.new_game_requested.emit()
    await get_tree().process_frame
    var world := app.get_node("World") as WorldShell
    assert_eq(world._session.state()["day"], 1)

    var still_incompatible := repository.load()
    assert_eq(still_incompatible["status"], &"loaded")
    assert_ne(GameSession.state_error(still_incompatible["state"]), "")

func test_missing_save_disables_continue_and_refuses_launch() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var app := _spawn_app(repository)
    if app == null:
        return
    var title := app.get_node("TitleScreen") as TitleScreen
    var continue_button := title.get_node("Panel/Continue") as Button
    assert_true(continue_button.disabled)

    title.continue_requested.emit()
    await get_tree().process_frame
    assert_null(app.get_node_or_null("World"))

func test_malformed_file_disables_continue_and_refuses_launch() -> void:
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    assert_not_null(file)
    if file == null:
        return
    file.store_string("{broken")
    file.close()

    var repository := SaveRepository.new(TEST_PATH)
    var app := _spawn_app(repository)
    if app == null:
        return
    var title := app.get_node("TitleScreen") as TitleScreen
    var continue_button := title.get_node("Panel/Continue") as Button
    var status := title.get_node("Panel/Status") as Label
    assert_true(continue_button.disabled)
    assert_ne(status.text, "")

    title.continue_requested.emit()
    await get_tree().process_frame
    assert_null(app.get_node_or_null("World"))

func test_new_game_keeps_valid_existing_slot_unchanged() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var saved_session := GameSession.new(func() -> float: return 0.9)
    assert_eq(saved_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var saved_state := saved_session.state()
    assert_eq(repository.save(saved_state), OK)
    var existing_before: Dictionary = repository.load()["state"]

    var app := _spawn_app(repository)
    if app == null:
        return
    var title := app.get_node("TitleScreen") as TitleScreen
    title.new_game_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    assert_eq(world._session.state()["day"], 1)
    var existing := repository.load()
    assert_eq(existing["status"], &"loaded")
    assert_eq(existing["state"], existing_before)
