extends GutTest

const TEST_PATH := "user://phoenix-hpa-598-app-launch-test.json"
const SETTINGS_PATH := "user://phoenix-ui-settings-app-launch-test.cfg"
const SAVE_OVERRIDE_PATH := "user://phoenix-task9-save-override.json"

func _clean() -> void:
    for path in [TEST_PATH, SETTINGS_PATH]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func before_each() -> void:
    OS.unset_environment("PHOENIX_SETTINGS_PATH")
    OS.unset_environment("PHOENIX_SAVE_PATH")
    _clean()

func after_each() -> void:
    OS.unset_environment("PHOENIX_SETTINGS_PATH")
    OS.unset_environment("PHOENIX_SAVE_PATH")
    _clean()

func _push_action(node: Node, action: StringName) -> void:
    var pressed := InputEventAction.new()
    pressed.action = action
    pressed.pressed = true
    node.get_viewport().push_input(pressed)
    var released := InputEventAction.new()
    released.action = action
    released.pressed = false
    node.get_viewport().push_input(released)

func test_settings_panel_shows_canonical_save_path_under_save_override() -> void:
    OS.set_environment("PHOENIX_SAVE_PATH", SAVE_OVERRIDE_PATH)
    OS.set_environment("PHOENIX_SETTINGS_PATH", SETTINGS_PATH)
    var packed := load("res://scenes/app/app.tscn") as PackedScene
    assert_not_null(packed)
    if packed == null:
        return
    var app := packed.instantiate() as AppRoot
    assert_not_null(app)
    if app == null:
        return
    add_child_autoqfree(app)
    await get_tree().process_frame
    (app.get_node("TitleScreen") as TitleScreen).new_game_requested.emit()
    await get_tree().process_frame

    var world := app.get_node("World") as WorldShell
    world.hud.open_pause()
    world.hud.open_settings()
    assert_eq(
        (world.hud.get_node("HudRoot/SettingsPanel/Frame/Footer/SavePath") as Label).text,
        "Save file: %s" % SaveRepository.DEFAULT_PATH,
    )

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

    var accepted := InputEventAction.new()
    accepted.action = &"ui_accept"
    accepted.pressed = true
    hud.get_viewport().push_input(accepted)
    var released := InputEventAction.new()
    released.action = &"ui_accept"
    released.pressed = false
    hud.get_viewport().push_input(released)
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
    seeded["shipped"] = {&"turnip": 4, &"potato": 3, &"pumpkin": 2}
    seeded["pending_shipment"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    seeded["pending_morning_summary"] = null
    seeded["money"] = 505
    seeded["relationships"][&"shopkeeper"]["points"] = VillagerRules.FRIEND_POINTS
    seeded["relationships"][&"resident"]["points"] = VillagerRules.CLOSE_FRIEND_POINTS
    seeded["finale_triggered"] = true
    assert_true(session.restore_state(seeded))
    var completed := session.state()
    assert_eq(GameSession.state_error(completed), "")
    var expected := ContentRules.build_harvest_result(completed)
    assert_eq(expected["shipped_count"], 9)
    assert_eq(expected["shipped_value"], 645)
    assert_eq(expected["tier"], &"heart_of_harvest")
    assert_eq(expected["villager"], "June")
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
    assert_eq(result.featured_villager_name(), expected["villager"])
    assert_true((result.get_node("Panel/Card_Mira/Heart_0") as TextureRect).visible)
    assert_true((result.get_node("Panel/Card_Mira/Heart_1") as TextureRect).visible)
    assert_false((result.get_node("Panel/Card_Mira/Heart_2") as TextureRect).visible)
    assert_false((result.get_node("Panel/Card_Rowan/Heart_0") as TextureRect).visible)
    assert_true((result.get_node("Panel/Card_June/Heart_2") as TextureRect).visible)
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

func _seed_completed_save(repository: SaveRepository) -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var seeded := session.state()
    seeded["day"] = GameRules.MAX_DAY
    seeded["weather_history"] = []
    for _day in GameRules.MAX_DAY:
        seeded["weather_history"].append(&"sunny")
    seeded["shipped"] = {&"turnip": 4, &"potato": 3, &"pumpkin": 2}
    seeded["pending_shipment"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    seeded["pending_morning_summary"] = null
    seeded["money"] = 505
    seeded["finale_triggered"] = true
    assert_true(session.restore_state(seeded))
    assert_eq(repository.save(session.state()), OK)

func test_result_screen_keyboard_enter_and_esc_drive_app_flow() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    _seed_completed_save(repository)
    var app := _spawn_app(repository)
    if app == null:
        return
    var title := app.get_node("TitleScreen") as TitleScreen
    title.continue_requested.emit()
    await get_tree().process_frame
    var result := app.get_node("ResultScreen") as ResultScreen
    assert_true(result.visible)

    # Esc returns to the title without launching a world.
    _push_action(result, &"ui_cancel")
    await get_tree().process_frame
    assert_false(result.visible)
    assert_true((app.get_node("TitleScreen") as TitleScreen).visible)
    assert_null(app.get_node_or_null("World"))

    # Continue back to the result, then Enter starts a new game world.
    title.continue_requested.emit()
    await get_tree().process_frame
    assert_true((app.get_node("ResultScreen") as ResultScreen).visible)
    _push_action(result, &"ui_accept")
    await get_tree().process_frame
    assert_false((app.get_node("ResultScreen") as ResultScreen).visible)
    var world := app.get_node("World") as WorldShell
    assert_not_null(world)
    assert_eq(world._session.state()["day"], 1)

func test_title_keyboard_skips_disabled_continue_and_enter_starts_new_game() -> void:
    var repository := SaveRepository.new(TEST_PATH)
    var incompatible := GameSession.new(func() -> float: return 0.9).state()
    incompatible["day"] = GameRules.MAX_DAY + 1
    assert_eq(repository.save(incompatible), OK)

    var app := _spawn_app(repository)
    if app == null:
        return
    var title := app.get_node("TitleScreen") as TitleScreen
    assert_eq(title.selected_action(), &"new_game")
    assert_eq(
        (title.get_node("Panel/Status/Label") as Label).text,
        "Save is incompatible; start a New Game.",
    )
    _push_action(title, &"move_down")
    assert_eq(title.selected_action(), &"new_game")
    _push_action(title, &"ui_accept")
    await get_tree().process_frame
    assert_eq((app.get_node("World") as WorldShell)._session.state()["day"], 1)

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
    var status := title.get_node("Panel/Status/Label") as Label
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
    var status := title.get_node("Panel/Status/Label") as Label
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
