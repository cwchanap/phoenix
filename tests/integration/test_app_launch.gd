extends GutTest

const TEST_PATH := "user://phoenix-hpa-598-app-launch-test.json"
const SETTINGS_PATH := "user://phoenix-ui-settings-app-launch-test.cfg"

func _clean() -> void:
    for path in [TEST_PATH, SETTINGS_PATH]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func before_each() -> void:
    OS.unset_environment("PHOENIX_SETTINGS_PATH")
    _clean()

func after_each() -> void:
    OS.unset_environment("PHOENIX_SETTINGS_PATH")
    _clean()

func _spawn_app(
    repository: SaveRepository,
    settings: UiSettings = null,
    use_environment_settings := false,
) -> AppRoot:
    var packed := load("res://scenes/app/app.tscn") as PackedScene
    assert_not_null(packed)
    if packed == null:
        return null
    var app := packed.instantiate() as AppRoot
    assert_not_null(app)
    if app == null:
        return null
    app.configure(
        repository,
        settings if settings != null or use_environment_settings else UiSettings.new(),
    )
    add_child_autoqfree(app)
    return app

func test_new_game_propagates_settings_and_tutorial_toggle_to_world_hud() -> void:
    var settings := UiSettings.load(SETTINGS_PATH)
    assert_eq(settings.set_music(0), OK)
    assert_eq(settings.set_sound(10), OK)
    assert_eq(settings.set_window_scale(3), OK)
    assert_eq(settings.set_tutorial_cards(false), OK)

    var app := _spawn_app(SaveRepository.new(TEST_PATH), settings)
    if app == null:
        return
    (app.get_node("TitleScreen") as TitleScreen).new_game_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    var hud := world.hud
    assert_eq(world._settings, settings)
    assert_eq(hud._settings, settings)
    assert_eq((hud.get_node("MusicPlayer") as AudioStreamPlayer).volume_db, -80.0)
    assert_eq((hud.get_node("SfxPlayer") as AudioStreamPlayer).volume_db, 0.0)

    var opening := hud.get_node("HudRoot/OnboardingOverlay/OpeningPanel") as Control
    var card := hud.get_node("HudRoot/OnboardingOverlay/TutorialCard") as Control
    assert_true(opening.visible)
    assert_false(card.visible)
    var tutorial_before: Dictionary = world._session.snapshot()["tutorial"].duplicate(true)

    (opening.get_node("Start") as Button).pressed.emit()
    assert_false(opening.visible)
    assert_false(card.visible)
    assert_eq(world._session.snapshot()["tutorial"], tutorial_before)

    assert_eq(settings.set_tutorial_cards(true), OK)
    hud.apply_settings()
    assert_true(card.visible)
    assert_eq(world._session.snapshot()["tutorial"], tutorial_before)

func test_settings_environment_path_is_loaded_without_using_save_override() -> void:
    var settings := UiSettings.load(SETTINGS_PATH)
    assert_eq(settings.set_music(0), OK)
    assert_eq(settings.set_tutorial_cards(false), OK)
    OS.set_environment("PHOENIX_SETTINGS_PATH", SETTINGS_PATH)

    var app := _spawn_app(SaveRepository.new(TEST_PATH), null, true)
    if app == null:
        return
    (app.get_node("TitleScreen") as TitleScreen).new_game_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    var hud := world.hud
    assert_eq(hud._settings._path, SETTINGS_PATH)
    assert_eq((hud.get_node("MusicPlayer") as AudioStreamPlayer).volume_db, -80.0)
    assert_false((hud.get_node("HudRoot/OnboardingOverlay/TutorialCard") as Control).visible)

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

func test_continue_with_completed_finale_shows_result_screen() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var session := GameSession.new(func() -> float: return 0.9)
    var seeded := session.state()
    seeded["day"] = GameRules.MAX_DAY
    seeded["weather_history"] = []
    for _day in GameRules.MAX_DAY:
        seeded["weather_history"].append(&"sunny")
    seeded["shipped"] = {&"turnip": 4, &"potato": 0, &"pumpkin": 0}
    seeded["relationships"][&"shopkeeper"]["points"] = VillagerRules.CLOSE_FRIEND_POINTS
    seeded["relationships"][&"farmer"]["points"] = VillagerRules.FRIEND_POINTS
    assert_true(session.restore_state(seeded))
    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_TRIGGERED,
    )
    var completed := session.state()
    assert_eq(GameSession.state_error(completed), "")
    assert_eq(repository.save(completed), OK)

    var app := _spawn_app(repository)
    if app == null:
        return
    var title := app.get_node("TitleScreen") as TitleScreen
    assert_false((title.get_node("Panel/Continue") as Button).disabled)
    title.continue_requested.emit()

    assert_null(app.get_node_or_null("World"))
    var result := app.get_node("ResultScreen") as ResultScreen
    assert_true(result.visible)
    var expected := ContentRules.build_harvest_result(completed)
    assert_eq((result.get_node("Panel/Title") as Label).text, expected["title"])
    assert_eq(
        (result.get_node("Panel/Shipped") as Label).text,
        "Shipped: %d crops · %dG" % [
            int(expected["shipped_count"]),
            int(expected["shipped_value"]),
        ],
    )
    assert_eq(
        (result.get_node("Panel/Money") as Label).text,
        "Final money: %dG" % int(expected["final_money"]),
    )
    assert_eq(
        (result.get_node("Panel/Relationship") as Label).text,
        "Closest villager: %s" % String(expected["villager"]),
    )
    var villagers: Dictionary = expected["villagers"]
    for id in range(VillagerRules.VillagerId.size()):
        var villager: Dictionary = villagers[VillagerRules.villager_key(id)]
        var level_name: String = VillagerRules.RELATIONSHIP_DISPLAY_NAMES[
            VillagerRules.RELATIONSHIP_KEYS.find(villager["level"])
        ]
        assert_eq(
            (result.get_node("Panel/%sLine" % VillagerRules.display_name(id)) as Label).text,
            "%s (%s): %s" % [String(villager["name"]), level_name, String(villager["line"])],
        )
    assert_eq((result.get_node("Panel/SaveStatus") as Label).text, "")

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
