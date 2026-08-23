extends GutTest

const FARM_CELL := Vector2i(2, 7)
const SECOND_FARM_CELL := Vector2i(3, 7)

func _assert_unchanged(session: GameSession, before: Dictionary) -> void:
    assert_eq(session.snapshot(), before)

func _plant_turnip(session: GameSession, cell: Vector2i = FARM_CELL) -> void:
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)

func _set_crop_growth(session: GameSession, cell: Vector2i, growth: int) -> void:
    var farm: Array[Dictionary] = session.get("_farm")
    var index := WorldContract.farm_cells().find(cell)
    var crop: Dictionary = farm[index]["crop"]
    crop["growth"] = growth
    farm[index]["crop"] = crop
    session.set("_farm", farm)

func _set_crop_watered(session: GameSession, cell: Vector2i, watered: bool) -> void:
    var farm: Array[Dictionary] = session.get("_farm")
    var index := WorldContract.farm_cells().find(cell)
    var crop: Dictionary = farm[index]["crop"]
    crop["watered_today"] = watered
    farm[index]["crop"] = crop
    session.set("_farm", farm)

func test_new_session_has_exact_starter_state() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var snapshot := session.snapshot()
    assert_eq(snapshot["day"], 1)
    assert_eq(snapshot["time_minutes"], GameRules.DAY_START_MINUTES)
    assert_eq(snapshot["stamina"], GameRules.MAX_STAMINA)
    assert_eq(snapshot["weather"], &"sunny")
    assert_eq(snapshot["money"], GameRules.STARTING_MONEY)
    assert_eq(snapshot["seeds"], {&"turnip": 3, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["harvested"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["pending_shipment"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["selected_action"], &"hoe")
    assert_eq(snapshot["selected_seed"], &"turnip")
    assert_eq(snapshot["farm"].size(), 9)
    assert_null(snapshot["pending_morning_summary"])

    var expected_cells := WorldContract.farm_cells()
    for index in expected_cells.size():
        var entry: Dictionary = snapshot["farm"][index]
        assert_eq(entry["cell"], expected_cells[index])
        assert_false(entry["tilled"])
        assert_null(entry["crop"])

func test_snapshot_is_deeply_isolated() -> void:
    var session := GameSession.new()
    var snapshot := session.snapshot()
    snapshot["farm"][0]["tilled"] = true
    snapshot["seeds"][&"turnip"] = 99
    var fresh := session.snapshot()
    assert_false(fresh["farm"][0]["tilled"])
    assert_eq(fresh["seeds"][&"turnip"], 3)

    _plant_turnip(session)
    var planted := session.snapshot()
    planted["farm"][0]["crop"]["growth"] = 99
    planted["harvested"][&"turnip"] = 99
    var fresh_planted := session.snapshot()
    assert_eq(fresh_planted["farm"][0]["crop"]["growth"], 0)
    assert_eq(fresh_planted["harvested"][&"turnip"], 0)

func test_snapshot_excludes_presentation_and_world_state() -> void:
    var snapshot := GameSession.new().snapshot()
    for key in [
        "interaction_cells",
        "player_position",
        "world_position",
        "node",
        "focus",
        "panel",
        "weather_roll",
    ]:
        assert_false(snapshot.has(key), "snapshot must not contain %s" % key)

func test_turnip_actions_commit_atomically() -> void:
    var session := GameSession.new()
    var cell := Vector2i(2, 7)
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    var snapshot := session.snapshot()
    assert_eq(snapshot["time_minutes"], 430)
    assert_eq(snapshot["stamina"], 14)
    assert_eq(snapshot["seeds"][&"turnip"], 2)
    assert_eq(snapshot["farm"][0]["crop"], {
        "kind": &"turnip",
        "growth": 0,
        "watered_today": true,
    })

func test_selection_and_apply_route_all_four_closed_actions() -> void:
    var session := GameSession.new()
    assert_eq(session.apply_selected_action(FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(
        session.select_action(GameRules.FarmingAction.SEEDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    assert_eq(session.apply_selected_action(FARM_CELL), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(
        session.select_action(GameRules.FarmingAction.WATERING_CAN),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    assert_eq(session.apply_selected_action(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    _set_crop_growth(session, FARM_CELL, GameRules.growth_nights(GameRules.CropKind.TURNIP))
    assert_eq(
        session.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    assert_eq(session.apply_selected_action(FARM_CELL), GameRules.CommandCode.CROP_HARVESTED)

func test_select_seed_returns_direct_enum_and_changes_selected_seed() -> void:
    var session := GameSession.new()
    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.SEED_SELECTED,
    )
    assert_eq(session.snapshot()["selected_seed"], &"potato")

func test_target_validation_precedes_farm_state_and_is_atomic() -> void:
    var session := GameSession.new()
    for command in [session.hoe, session.plant, session.water, session.harvest]:
        var before := session.snapshot()
        assert_eq(command.call(null), GameRules.CommandCode.NO_TARGET)
        _assert_unchanged(session, before)

    var before_invalid_type := session.snapshot()
    assert_eq(session.hoe("2,7"), GameRules.CommandCode.NO_TARGET)
    _assert_unchanged(session, before_invalid_type)

    var before_non_farm := session.snapshot()
    assert_eq(session.hoe(Vector2i(0, 0)), GameRules.CommandCode.NOT_FARM_CELL)
    _assert_unchanged(session, before_non_farm)

func test_hoe_guards_crop_before_tilled_and_commits_budget() -> void:
    var session := GameSession.new()
    assert_eq(session.hoe(FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
    var before_already_tilled := session.snapshot()
    assert_eq(session.hoe(FARM_CELL), GameRules.CommandCode.ALREADY_TILLED)
    _assert_unchanged(session, before_already_tilled)

    _plant_turnip(session, SECOND_FARM_CELL)
    var before_crop_present := session.snapshot()
    assert_eq(session.hoe(SECOND_FARM_CELL), GameRules.CommandCode.CROP_PRESENT)
    _assert_unchanged(session, before_crop_present)

func test_plant_guards_soil_crop_and_selected_seed_in_order() -> void:
    var session := GameSession.new()
    var before_untilled := session.snapshot()
    assert_eq(session.plant(FARM_CELL), GameRules.CommandCode.SOIL_UNTILLED)
    _assert_unchanged(session, before_untilled)

    assert_eq(session.hoe(FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(FARM_CELL), GameRules.CommandCode.CROP_PLANTED)
    var before_crop_present := session.snapshot()
    assert_eq(session.plant(FARM_CELL), GameRules.CommandCode.CROP_PRESENT)
    _assert_unchanged(session, before_crop_present)

    var empty_tilled_cell := SECOND_FARM_CELL
    assert_eq(session.hoe(empty_tilled_cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.SEED_SELECTED,
    )
    var before_no_seeds := session.snapshot()
    assert_eq(session.plant(empty_tilled_cell), GameRules.CommandCode.NO_SELECTED_SEEDS)
    _assert_unchanged(session, before_no_seeds)

func test_water_guards_and_rain_are_atomic() -> void:
    var empty := GameSession.new()
    var before_no_crop := empty.snapshot()
    assert_eq(empty.water(FARM_CELL), GameRules.CommandCode.NO_CROP)
    _assert_unchanged(empty, before_no_crop)

    var mature := GameSession.new()
    _plant_turnip(mature)
    _set_crop_growth(mature, FARM_CELL, GameRules.growth_nights(GameRules.CropKind.TURNIP))
    var before_mature := mature.snapshot()
    assert_eq(mature.water(FARM_CELL), GameRules.CommandCode.CROP_MATURE)
    _assert_unchanged(mature, before_mature)

    var already_watered := GameSession.new()
    _plant_turnip(already_watered)
    assert_eq(already_watered.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    var before_already_watered := already_watered.snapshot()
    assert_eq(already_watered.water(FARM_CELL), GameRules.CommandCode.ALREADY_WATERED)
    _assert_unchanged(already_watered, before_already_watered)

    var rainy := GameSession.new(func() -> float: return 0.1)
    rainy.set("_weather", GameRules.Weather.RAINY)
    _plant_turnip(rainy)
    var before_rain := rainy.snapshot()
    assert_eq(rainy.water(FARM_CELL), GameRules.CommandCode.RAIN_WATERS_CROPS)
    _assert_unchanged(rainy, before_rain)
    _set_crop_watered(rainy, FARM_CELL, true)
    var before_rain_already_watered := rainy.snapshot()
    assert_eq(rainy.water(FARM_CELL), GameRules.CommandCode.RAIN_WATERS_CROPS)
    _assert_unchanged(rainy, before_rain_already_watered)

func test_harvest_guards_and_preserves_tilled_soil() -> void:
    var empty := GameSession.new()
    var before_no_crop := empty.snapshot()
    assert_eq(empty.harvest(FARM_CELL), GameRules.CommandCode.NO_CROP)
    _assert_unchanged(empty, before_no_crop)

    var immature := GameSession.new()
    _plant_turnip(immature)
    var before_immature := immature.snapshot()
    assert_eq(immature.harvest(FARM_CELL), GameRules.CommandCode.CROP_IMMATURE)
    _assert_unchanged(immature, before_immature)

    var mature := GameSession.new()
    _plant_turnip(mature)
    _set_crop_growth(mature, FARM_CELL, GameRules.growth_nights(GameRules.CropKind.TURNIP))
    assert_eq(mature.harvest(FARM_CELL), GameRules.CommandCode.CROP_HARVESTED)
    var snapshot := mature.snapshot()
    assert_true(snapshot["farm"][0]["tilled"])
    assert_null(snapshot["farm"][0]["crop"])
    assert_eq(snapshot["harvested"][&"turnip"], 1)

func test_budget_failures_happen_after_state_guards_and_are_atomic() -> void:
    var too_late := GameSession.new()
    too_late.set("_time_minutes", GameRules.ACTION_CUTOFF_MINUTES - 10)
    too_late.set("_stamina", 0)
    var before_too_late := too_late.snapshot()
    assert_eq(too_late.hoe(FARM_CELL), GameRules.CommandCode.ACTION_TOO_LATE)
    _assert_unchanged(too_late, before_too_late)

    var insufficient := GameSession.new()
    insufficient.set("_stamina", 2)
    var before_insufficient := insufficient.snapshot()
    assert_eq(insufficient.hoe(FARM_CELL), GameRules.CommandCode.INSUFFICIENT_STAMINA)
    _assert_unchanged(insufficient, before_insufficient)

    var state_before_budget := GameSession.new()
    state_before_budget.set("_stamina", 0)
    var before_state_guard := state_before_budget.snapshot()
    assert_eq(state_before_budget.plant(FARM_CELL), GameRules.CommandCode.SOIL_UNTILLED)
    _assert_unchanged(state_before_budget, before_state_guard)

func test_failed_commands_preserve_complete_snapshot() -> void:
    var session := GameSession.new()
    _plant_turnip(session)
    var before := session.snapshot()
    assert_eq(session.harvest(FARM_CELL), GameRules.CommandCode.CROP_IMMATURE)
    _assert_unchanged(session, before)
    assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    var after_water := session.snapshot()
    assert_eq(session.water(FARM_CELL), GameRules.CommandCode.ALREADY_WATERED)
    _assert_unchanged(session, after_water)
