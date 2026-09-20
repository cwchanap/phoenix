extends GutTest

const FARM_CELL := WorldContract.FARM_PATCH.position
const SECOND_FARM_CELL := WorldContract.FARM_PATCH.position + Vector2i.RIGHT
# Deep inside the expanded patch: well outside the old 3x3 footprint.
const DEEP_FARM_CELL := WorldContract.FARM_PATCH.position + Vector2i(4, 3)

func _assert_unchanged(session: GameSession, before: Dictionary) -> void:
    assert_eq(session.snapshot(), before)

func _assert_preview(
    session: GameSession,
    target: Variant,
    expected_code: GameRules.CommandCode,
    expected_action: GameRules.FarmingAction,
    expected_crop: Variant,
) -> Dictionary:
    var before := session.snapshot()
    var preview: Dictionary = session.preview_selected_action(target)
    assert_eq(preview.size(), 4)
    assert_eq(preview["code"], expected_code)
    assert_eq(preview["action"], expected_action)
    if expected_crop == null:
        assert_null(preview["crop"])
    else:
        assert_eq(preview["crop"], expected_crop)
    assert_eq(preview["cost"], session._cost_for(expected_action))
    _assert_unchanged(session, before)
    return preview

func _plant_turnip(session: GameSession, cell: Vector2i = FARM_CELL) -> void:
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)

func _grow_and_harvest_turnip(session: GameSession, cell := FARM_CELL) -> void:
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    for _night in 3:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            session.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )
    assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)

func _mature_turnip(session: GameSession, cell: Vector2i = FARM_CELL) -> void:
    _plant_turnip(session, cell)
    for _night in GameRules.growth_nights(GameRules.CropKind.TURNIP):
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            session.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )

func _sleep_and_ack(session: GameSession) -> void:
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(
        session.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )

func _seed_harvested(session: GameSession, counts: Array[int]) -> void:
    session.set("_harvested_counts", counts)
    var harvested: Dictionary = session.snapshot()["harvested"]
    assert_eq(harvested[&"turnip"], counts[GameRules.CropKind.TURNIP])
    assert_eq(harvested[&"potato"], counts[GameRules.CropKind.POTATO])
    assert_eq(harvested[&"pumpkin"], counts[GameRules.CropKind.PUMPKIN])

func _session_with_money(money: int) -> GameSession:
    var session := GameSession.new(func() -> float: return 0.9)
    var seeded := session.state()
    seeded["money"] = money
    assert_eq(GameSession.state_error(seeded), "")
    assert_true(session.restore_state(seeded))
    return session

func _purchase_upgrade(session: GameSession) -> void:
    assert_eq(
        session.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.WATERING_CAN_UPGRADED,
    )

func _water_target_session(stamina: int, upgraded: bool, weather: StringName = &"sunny") -> GameSession:
    var session := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(session)
    if upgraded:
        var funded := session.state()
        funded["money"] = GameRules.WATERING_CAN_UPGRADE_PRICE
        assert_eq(GameSession.state_error(funded), "")
        assert_true(session.restore_state(funded))
        _purchase_upgrade(session)
    var prepared := session.state()
    prepared["stamina"] = stamina
    prepared["weather"] = weather
    prepared["weather_history"] = [weather]
    assert_eq(GameSession.state_error(prepared), "")
    assert_true(session.restore_state(prepared))
    return session

func test_new_session_has_exact_starter_state() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var snapshot := session.snapshot()
    assert_eq(snapshot.size(), 20)
    assert_eq(snapshot.keys(), [
        "day",
        "time_minutes",
        "stamina",
        "max_stamina",
        "weather",
        "weather_history",
        "selected_action",
        "selected_seed",
        "money",
        "seeds",
        "harvested",
        "pending_shipment",
        "farm",
        "pending_morning_summary",
        "relationships",
        "intro_acknowledged",
        "tutorial",
        "shipped",
        "finale_triggered",
        "watering_can_upgraded",
    ])
    assert_eq(snapshot["max_stamina"], GameRules.MAX_STAMINA)
    assert_eq(snapshot["day"], 1)
    assert_eq(snapshot["time_minutes"], GameRules.DAY_START_MINUTES)
    assert_eq(snapshot["stamina"], GameRules.MAX_STAMINA)
    assert_eq(snapshot["weather"], &"sunny")
    assert_eq(snapshot["weather_history"], [&"sunny"])
    assert_eq(snapshot["money"], GameRules.STARTING_MONEY)
    assert_eq(snapshot["seeds"], {&"turnip": 3, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["harvested"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["pending_shipment"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(snapshot["selected_action"], &"hoe")
    assert_eq(snapshot["selected_seed"], &"turnip")
    assert_eq(snapshot["farm"].size(), WorldContract.farm_cells().size())
    assert_null(snapshot["pending_morning_summary"])
    assert_eq(snapshot["relationships"], {
        &"shopkeeper": {
            "points": 0,
            "level": &"stranger",
            "talked_today": false,
            "gifted_today": false,
            "close_friend_dialogue_seen": false,
        },
        &"farmer": {
            "points": 0,
            "level": &"stranger",
            "talked_today": false,
            "gifted_today": false,
            "close_friend_dialogue_seen": false,
        },
        &"resident": {
            "points": 0,
            "level": &"stranger",
            "talked_today": false,
            "gifted_today": false,
            "close_friend_dialogue_seen": false,
        },
    })
    assert_false(snapshot["intro_acknowledged"])
    assert_eq(snapshot["tutorial"], ContentRules.initial_tutorial_progress())
    assert_eq(snapshot["shipped"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_false(snapshot["finale_triggered"])
    assert_false(snapshot["watering_can_upgraded"])

    var starter_state := session.state()
    for field in [
        "intro_acknowledged",
        "tutorial",
        "shipped",
        "finale_triggered",
        "watering_can_upgraded",
    ]:
        assert_true(starter_state.has(field))

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
    snapshot["relationships"][&"resident"]["points"] = 99
    snapshot["tutorial"][&"farm_basics"] = true
    snapshot["shipped"][&"turnip"] = 99
    snapshot["weather_history"][0] = &"rainy"
    var fresh := session.snapshot()
    assert_false(fresh["farm"][0]["tilled"])
    assert_eq(fresh["seeds"][&"turnip"], 3)
    assert_eq(fresh["relationships"][&"resident"]["points"], 0)
    assert_false(fresh["tutorial"][&"farm_basics"])
    assert_eq(fresh["shipped"][&"turnip"], 0)
    assert_eq(fresh["weather_history"], [&"sunny"])

    _plant_turnip(session)
    var planted := session.snapshot()
    planted["farm"][0]["crop"]["growth"] = 99
    planted["harvested"][&"turnip"] = 99
    planted["relationships"][&"resident"]["talked_today"] = true
    var fresh_planted := session.snapshot()
    assert_eq(fresh_planted["farm"][0]["crop"]["growth"], 0)
    assert_eq(fresh_planted["harvested"][&"turnip"], 0)
    assert_false(fresh_planted["relationships"][&"resident"]["talked_today"])

func test_state_is_deeply_isolated_and_excludes_derived_fields() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var harvested: Array[int] = [1, 0, 0]
    _seed_harvested(session, harvested)
    var june := VillagerRules.VillagerId.RESIDENT
    assert_eq(
        session.talk_to(june, WorldContract.villager_cell(june))["code"],
        GameRules.CommandCode.VILLAGER_TALKED,
    )

    var mutable_state := session.state()
    assert_false(mutable_state.has("max_stamina"))
    assert_false(mutable_state["relationships"][&"resident"].has("level"))
    mutable_state["harvested"][&"turnip"] = 99
    mutable_state["relationships"][&"resident"]["points"] = 99
    mutable_state["farm"][0]["tilled"] = true
    mutable_state["tutorial"][&"gift"] = true
    mutable_state["shipped"][&"pumpkin"] = 99
    mutable_state["weather_history"][0] = &"rainy"

    var fresh := session.state()
    assert_eq(fresh["harvested"][&"turnip"], 1)
    assert_eq(fresh["relationships"][&"resident"]["points"], 1)
    assert_false(fresh["farm"][0]["tilled"])
    assert_false(fresh["tutorial"][&"gift"])
    assert_eq(fresh["shipped"][&"pumpkin"], 0)
    assert_eq(fresh["weather_history"], [&"sunny"])
    assert_eq(session.snapshot()["max_stamina"], GameRules.MAX_STAMINA)
    assert_eq(session.snapshot()["relationships"][&"resident"]["level"], &"stranger")

func test_state_error_returns_messages_for_missing_and_wrong_typed_fields() -> void:
    assert_ne(GameSession.state_error({}), "")

    var bad_day := GameSession.new().state()
    bad_day["day"] = "two"
    assert_ne(GameSession.state_error(bad_day), "")

    var bad_counts := GameSession.new().state()
    bad_counts["seeds"] = []
    assert_ne(GameSession.state_error(bad_counts), "")

    var bad_farm := GameSession.new().state()
    bad_farm["farm"] = "farm"
    assert_ne(GameSession.state_error(bad_farm), "")

func test_weather_history_starts_day_one_and_appends_on_sleep() -> void:
    var session := GameSession.new(func() -> float: return 0.0)
    assert_eq(session.snapshot()["weather_history"], [&"sunny"])
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(session.snapshot()["weather_history"], [&"sunny", &"rainy"])

func test_weather_history_requires_one_entry_per_day() -> void:
    var state := GameSession.new().state()
    state["weather_history"] = []
    assert_eq(GameSession.state_error(state), "weather_history must contain one entry per day")

func test_weather_history_rejects_invalid_entry() -> void:
    var state := GameSession.new().state()
    state["day"] = 2
    state["weather_history"] = [&"sunny", &"stormy"]
    assert_eq(GameSession.state_error(state), "weather_history[1] is unknown")

func test_weather_history_requires_final_entry_to_match_current_weather() -> void:
    var state := GameSession.new().state()
    state["weather_history"] = [&"rainy"]
    assert_eq(
        GameSession.state_error(state),
        "weather_history final entry must match weather",
    )

func test_command_driven_state_restores_farm_and_does_not_alias_candidate() -> void:
    var original := GameSession.new(func() -> float: return 0.9)
    var cell := FARM_CELL
    assert_eq(original.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(original.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(original.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_eq(original.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var saved := original.state()
    var saved_before_command := saved.duplicate(true)
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_eq(GameSession.state_error(saved), "")
    assert_true(restored.restore_state(saved))
    assert_eq(restored.state(), saved)

    assert_eq(
        restored.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )
    assert_eq(restored.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_true(restored.state()["farm"][0]["crop"]["watered_today"])
    assert_eq(saved, saved_before_command)
    assert_false(saved["farm"][0]["crop"]["watered_today"])

func test_state_error_rejects_invalid_current_rule_shapes() -> void:
    var valid := GameSession.new().state()
    assert_eq(GameSession.state_error(valid), "")
    var candidates: Array[Dictionary] = []
    var invalid: Dictionary = valid.duplicate(true)

    invalid["day"] = GameRules.MAX_DAY + 1
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["time_minutes"] = GameRules.ACTION_CUTOFF_MINUTES + 1
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["stamina"] = GameRules.MAX_STAMINA + 1
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["money"] = -1
    candidates.append(invalid)

    for field in ["seeds", "harvested", "pending_shipment"]:
        invalid = valid.duplicate(true)
        invalid[field][&"turnip"] = -1
        candidates.append(invalid)

    for field in ["selected_seed", "selected_action", "weather"]:
        invalid = valid.duplicate(true)
        invalid[field] = &"unknown"
        candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["seeds"].erase(&"turnip")
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["seeds"][&"extra"] = 0
    candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["farm"].pop_back()
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    var first_farm_entry: Dictionary = invalid["farm"][0]
    invalid["farm"][0] = invalid["farm"][1]
    invalid["farm"][1] = first_farm_entry
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["farm"][0]["cell"] = Vector2i(0, 0)
    candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["farm"][0]["crop"] = {
        "kind": &"turnip",
        "growth": 0,
        "watered_today": false,
    }
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["farm"][0]["tilled"] = true
    invalid["farm"][0]["crop"] = {
        "kind": &"turnip",
        "growth": GameRules.growth_nights(GameRules.CropKind.TURNIP) + 1,
        "watered_today": false,
    }
    candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["relationships"].erase(&"resident")
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["relationships"][&"extra"] = {
        "points": 0,
        "talked_today": false,
        "gifted_today": false,
        "close_friend_dialogue_seen": false,
    }
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["relationships"][&"resident"]["talked_today"] = "yes"
    candidates.append(invalid)

    var summary_session := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(summary_session)
    assert_eq(summary_session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    assert_eq(summary_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var with_summary := summary_session.state()

    invalid = with_summary.duplicate(true)
    invalid["pending_morning_summary"]["next_day"] += 1
    candidates.append(invalid)
    invalid = with_summary.duplicate(true)
    invalid["pending_morning_summary"]["next_weather"] = &"rainy"
    candidates.append(invalid)
    invalid = with_summary.duplicate(true)
    invalid["pending_morning_summary"]["money_after_shipping"] += 1
    candidates.append(invalid)
    invalid = with_summary.duplicate(true)
    invalid["pending_morning_summary"]["shipments"].append({
        "crop": &"unknown",
        "quantity": 1,
        "amount": 1,
    })
    candidates.append(invalid)
    invalid = with_summary.duplicate(true)
    invalid["pending_morning_summary"]["shipments"].append({
        "crop": &"turnip",
        "quantity": -1,
        "amount": 1,
    })
    candidates.append(invalid)

    for candidate in candidates:
        assert_ne(GameSession.state_error(candidate), "")

func test_state_error_rejects_invalid_onboarding_and_finale_shapes() -> void:
    var valid := GameSession.new().state()
    assert_eq(GameSession.state_error(valid), "")
    var candidates: Array[Dictionary] = []
    var invalid: Dictionary = valid.duplicate(true)

    for field in [
        "intro_acknowledged",
        "tutorial",
        "shipped",
        "finale_triggered",
        "watering_can_upgraded",
    ]:
        invalid = valid.duplicate(true)
        invalid.erase(field)
        candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid.erase("intro_acknowledged")
    invalid.erase("tutorial")
    invalid.erase("shipped")
    invalid.erase("finale_triggered")
    candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["intro_acknowledged"] = "yes"
    candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["tutorial"].erase(&"farm_basics")
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["tutorial"][&"extra"] = true
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["tutorial"][&"farm_basics"] = 1
    candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["shipped"][&"turnip"] = -1
    candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["finale_triggered"] = "yes"
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["finale_triggered"] = true
    candidates.append(invalid)

    invalid = valid.duplicate(true)
    invalid["watering_can_upgraded"] = "yes"
    candidates.append(invalid)
    invalid = valid.duplicate(true)
    invalid["watering_can_upgraded"] = 1
    candidates.append(invalid)

    var finale_session := GameSession.new(func() -> float: return 0.9)
    while int(finale_session.snapshot()["day"]) < GameRules.MAX_DAY:
        assert_eq(finale_session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        if int(finale_session.snapshot()["day"]) < GameRules.MAX_DAY:
            assert_eq(
                finale_session.acknowledge_morning_summary(),
                GameRules.CommandCode.DAY_STARTED,
            )
    var final_day := finale_session.state()

    invalid = final_day.duplicate(true)
    invalid["pending_morning_summary"] = null
    invalid["finale_triggered"] = true
    assert_eq(GameSession.state_error(invalid), "")

    invalid = final_day.duplicate(true)
    invalid["finale_triggered"] = true
    candidates.append(invalid)

    invalid = final_day.duplicate(true)
    invalid["pending_morning_summary"] = null
    invalid["finale_triggered"] = true
    invalid["pending_shipment"][&"turnip"] = 1
    candidates.append(invalid)

    for candidate in candidates:
        assert_ne(GameSession.state_error(candidate), "")

func test_schema_2_transport_stays_field_blind_and_session_rejects_sabotaged_ownership() -> void:
    assert_eq(SaveFileCodec.SCHEMA_VERSION, 2)

    # Missing ownership decodes fine (the codec is field-blind) but the
    # session validation rejects it; it must never default to false.
    var missing := GameSession.new(func() -> float: return 0.9).state()
    missing.erase("watering_can_upgraded")
    var decoded_missing := SaveFileCodec.decode(SaveFileCodec.encode(missing))
    assert_true(bool(decoded_missing["ok"]))
    assert_false(decoded_missing["state"].has("watering_can_upgraded"))
    assert_ne(GameSession.state_error(decoded_missing["state"]), "")

    # Non-boolean ownership rides the same decode-then-reject path.
    var non_boolean := GameSession.new(func() -> float: return 0.9).state()
    non_boolean["watering_can_upgraded"] = "yes"
    var decoded_non_boolean := SaveFileCodec.decode(SaveFileCodec.encode(non_boolean))
    assert_true(bool(decoded_non_boolean["ok"]))
    assert_ne(GameSession.state_error(decoded_non_boolean["state"]), "")

func test_acknowledge_intro_mutates_once_and_duplicate_is_noop() -> void:
    var session := GameSession.new()
    assert_false(session.snapshot()["intro_acknowledged"])
    assert_eq(session.acknowledge_intro(), GameRules.CommandCode.INTRO_ACKNOWLEDGED)
    assert_true(session.snapshot()["intro_acknowledged"])
    var after_first := session.state()
    assert_eq(
        session.acknowledge_intro(),
        GameRules.CommandCode.INTRO_ALREADY_ACKNOWLEDGED,
    )
    assert_eq(session.state(), after_first)

func test_farm_cell_outside_the_old_footprint_commits_and_restores() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    assert_true(WorldContract.FARM_PATCH.has_point(DEEP_FARM_CELL))
    assert_eq(session.hoe(DEEP_FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(DEEP_FARM_CELL), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(DEEP_FARM_CELL), GameRules.CommandCode.CROP_WATERED)

    # Mutate+restore round-trip: the deep cell's watered crop survives state
    # export and restore, and keeps growing on the restored session.
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(session.state()))
    assert_eq(restored.water(DEEP_FARM_CELL), GameRules.CommandCode.ALREADY_WATERED)
    assert_eq(restored.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(
        restored.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )
    for _night in GameRules.growth_nights(GameRules.CropKind.TURNIP) - 1:
        assert_eq(restored.water(DEEP_FARM_CELL), GameRules.CommandCode.CROP_WATERED)
        assert_eq(restored.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            restored.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )
    assert_eq(restored.harvest(DEEP_FARM_CELL), GameRules.CommandCode.CROP_HARVESTED)

func test_tutorials_complete_only_on_authoritative_successes() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var cell := WorldContract.farm_cells()[0]
    var second := WorldContract.farm_cells()[1]

    assert_eq(session.hoe(Vector2i(0, 0)), GameRules.CommandCode.NOT_FARM_CELL)
    assert_false(session.state()["tutorial"][&"farm_basics"])
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_true(session.state()["tutorial"][&"farm_basics"])

    assert_eq(session.plant(second), GameRules.CommandCode.SOIL_UNTILLED)
    assert_false(session.state()["tutorial"][&"plant"])
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_true(session.state()["tutorial"][&"plant"])

    assert_eq(session.hoe(second), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.water(second), GameRules.CommandCode.NO_CROP)
    assert_false(session.state()["tutorial"][&"water"])
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_true(session.state()["tutorial"][&"water"])

    assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_IMMATURE)
    assert_false(session.state()["tutorial"][&"harvest"])
    assert_eq(session.plant(second), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(second), GameRules.CommandCode.CROP_WATERED)

    assert_eq(session.sleep(Vector2i(0, 0)), GameRules.CommandCode.NOT_AT_BED)
    assert_false(session.state()["tutorial"][&"sleep"])
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_true(session.state()["tutorial"][&"sleep"])
    assert_eq(
        session.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )

    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 1, Vector2i(0, 0)),
        GameRules.CommandCode.NOT_AT_SHOP,
    )
    assert_false(session.state()["tutorial"][&"buy_seeds"])
    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 1, WorldContract.SHOP_CELL),
        GameRules.CommandCode.SEEDS_PURCHASED,
    )
    assert_true(session.state()["tutorial"][&"buy_seeds"])

    var mira := VillagerRules.VillagerId.SHOPKEEPER
    assert_eq(
        session.talk_to(mira, Vector2i(0, 0))["code"],
        GameRules.CommandCode.NOT_AT_VILLAGER,
    )
    assert_false(session.state()["tutorial"][&"talk"])
    assert_eq(
        session.talk_to(mira, WorldContract.villager_cell(mira))["code"],
        GameRules.CommandCode.VILLAGER_TALKED,
    )
    assert_true(session.state()["tutorial"][&"talk"])

    var tutorial_before_selection: Dictionary = session.state()["tutorial"]
    assert_eq(
        session.select_action(GameRules.FarmingAction.SEEDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.SEED_SELECTED,
    )
    assert_eq(session.state()["tutorial"], tutorial_before_selection)

    for _night in 2:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.water(second), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            session.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )

    assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)
    assert_true(session.state()["tutorial"][&"harvest"])
    assert_eq(session.harvest(second), GameRules.CommandCode.CROP_HARVESTED)

    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, Vector2i(0, 0)),
        GameRules.CommandCode.NOT_AT_SHIPPING_BIN,
    )
    assert_false(session.state()["tutorial"][&"shipping"])
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    assert_true(session.state()["tutorial"][&"shipping"])

    assert_eq(
        session.gift_crop(
            mira,
            GameRules.CropKind.PUMPKIN,
            WorldContract.villager_cell(mira),
        )["code"],
        GameRules.CommandCode.INSUFFICIENT_CROPS,
    )
    assert_false(session.state()["tutorial"][&"gift"])
    assert_eq(
        session.gift_crop(
            mira,
            GameRules.CropKind.TURNIP,
            WorldContract.villager_cell(mira),
        )["code"],
        GameRules.CommandCode.CROP_GIFTED,
    )
    assert_true(session.state()["tutorial"][&"gift"])

func test_normal_sleep_accumulates_lifetime_shipped_counts() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    _grow_and_harvest_turnip(session)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var first := session.snapshot()
    assert_eq(first["money"], GameRules.STARTING_MONEY + 35)
    assert_eq(first["pending_shipment"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(first["shipped"], {&"turnip": 1, &"potato": 0, &"pumpkin": 0})
    assert_eq(first["pending_morning_summary"]["shipping_income"], 35)
    assert_eq(
        first["pending_morning_summary"]["shipments"],
        [{"crop": &"turnip", "quantity": 1, "amount": 35}],
    )
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)

    _grow_and_harvest_turnip(session, SECOND_FARM_CELL)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var second := session.snapshot()
    assert_eq(second["shipped"], {&"turnip": 2, &"potato": 0, &"pumpkin": 0})
    assert_eq(second["money"], GameRules.STARTING_MONEY + 70)
    assert_eq(second["pending_morning_summary"]["shipping_income"], 35)
    assert_eq(second["pending_morning_summary"]["money_after_shipping"], GameRules.STARTING_MONEY + 70)
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)

    _grow_and_harvest_turnip(session, WorldContract.farm_cells()[2])
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var third := session.snapshot()
    assert_eq(third["harvested"][&"turnip"], 1)
    assert_eq(third["pending_shipment"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(third["shipped"], {&"turnip": 2, &"potato": 0, &"pumpkin": 0})
    assert_eq(third["money"], GameRules.STARTING_MONEY + 70)
    assert_eq(third["pending_morning_summary"]["shipping_income"], 0)
    assert_eq(third["pending_morning_summary"]["shipments"], [])

func test_talk_to_awards_first_point_and_repeat_is_zero() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var mira := VillagerRules.VillagerId.SHOPKEEPER
    var first: Dictionary = session.talk_to(mira, WorldContract.villager_cell(mira))
    assert_eq(first["code"], GameRules.CommandCode.VILLAGER_TALKED)
    assert_eq(first["lines"], ["The seed counter is open whenever you need it."])
    assert_eq(first["points_gained"], 1)
    assert_eq(first["gift_reaction"], &"")
    assert_false(first["close_friend_sequence"])
    assert_eq(session.snapshot()["relationships"][&"shopkeeper"]["points"], 1)
    assert_true(session.snapshot()["relationships"][&"shopkeeper"]["talked_today"])

    var repeat: Dictionary = session.talk_to(mira, WorldContract.villager_cell(mira))
    assert_eq(repeat["code"], GameRules.CommandCode.VILLAGER_TALKED)
    assert_eq(repeat["lines"], first["lines"])
    assert_eq(repeat["points_gained"], 0)
    assert_false(repeat["close_friend_sequence"])
    assert_eq(session.snapshot()["relationships"][&"shopkeeper"]["points"], 1)

func test_normal_gift_consumes_one_crop_and_awards_three_points() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var seeded: Array[int] = [1, 0, 0]
    _seed_harvested(session, seeded)
    var mira := VillagerRules.VillagerId.SHOPKEEPER
    var result: Dictionary = session.gift_crop(
        mira,
        GameRules.CropKind.TURNIP,
        WorldContract.villager_cell(mira),
    )
    assert_eq(result["code"], GameRules.CommandCode.CROP_GIFTED)
    assert_eq(result["points_gained"], 3)
    assert_eq(result["lines"], [VillagerRules.gift_line(mira, GameRules.CropKind.TURNIP)])
    assert_eq(result["gift_reaction"], &"normal")
    assert_false(result["close_friend_sequence"])
    assert_eq(session.snapshot()["harvested"][&"turnip"], 0)
    assert_eq(session.snapshot()["relationships"][&"shopkeeper"]["points"], 3)
    assert_true(session.snapshot()["relationships"][&"shopkeeper"]["gifted_today"])

func test_favourite_gift_consumes_one_real_harvested_crop() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    _grow_and_harvest_turnip(session)
    var june := VillagerRules.VillagerId.RESIDENT
    var result: Dictionary = session.gift_crop(
        june,
        GameRules.CropKind.TURNIP,
        WorldContract.villager_cell(june),
    )
    assert_eq(result["code"], GameRules.CommandCode.CROP_GIFTED)
    assert_eq(result["points_gained"], 5)
    assert_eq(result["lines"], [VillagerRules.gift_line(june, GameRules.CropKind.TURNIP)])
    assert_eq(session.snapshot()["harvested"][&"turnip"], 0)

func _talk_session(day: int, rainy: bool, shipped: Array[int]) -> GameSession:
    var session := GameSession.new(func() -> float: return 0.9)
    var state := session.state()
    state["day"] = day
    var weather := GameRules.Weather.RAINY if rainy else GameRules.Weather.SUNNY
    state["weather"] = GameRules.weather_key(weather)
    state["weather_history"] = []
    for index in day:
        state["weather_history"].append(
            GameRules.weather_key(weather) if index == day - 1 else GameRules.weather_key(GameRules.Weather.SUNNY)
        )
    state["shipped"] = {
        &"turnip": shipped[GameRules.CropKind.TURNIP],
        &"potato": shipped[GameRules.CropKind.POTATO],
        &"pumpkin": shipped[GameRules.CropKind.PUMPKIN],
    }
    assert_eq(GameSession.state_error(state), "")
    assert_true(session.restore_state(state))
    return session

func test_day_one_sunny_stranger_talk_is_literal_for_every_villager() -> void:
    var expected := [
        "The seed counter is open whenever you need it.",
        "A straight row is nice, but a watered row is useful.",
        "You will learn which corners feel familiar before long.",
    ]
    for id in range(VillagerRules.VillagerId.size()):
        var session := _talk_session(1, false, [0, 0, 0])
        var result: Dictionary = session.talk_to(id, WorldContract.villager_cell(id))
        assert_eq(result["code"], GameRules.CommandCode.VILLAGER_TALKED)
        assert_eq(result["points_gained"], 1)
        assert_eq(result["lines"], [expected[id]])

func test_day_twelve_rainy_settled_stranger_talk_is_literal_for_every_villager() -> void:
    var expected := [
        "The market is close. Keep some coin ready for what comes next.",
        "Watered soil tells you what tomorrow will bring.",
        "The village notices steady footsteps more than grand entrances.",
    ]
    for id in range(VillagerRules.VillagerId.size()):
        var session := _talk_session(12, true, [1, 0, 0])
        var result: Dictionary = session.talk_to(id, WorldContract.villager_cell(id))
        assert_eq(result["code"], GameRules.CommandCode.VILLAGER_TALKED)
        assert_eq(result["lines"], [expected[id]])

func test_only_settled_shipments_enable_shipping_flavor() -> void:
    var mira := VillagerRules.VillagerId.SHOPKEEPER
    var no_shipment_literal := "Turnips are quick. Potatoes ask for a little more patience."

    var harvested_state := _talk_session(12, true, [0, 0, 0]).state()
    harvested_state["harvested"] = {&"turnip": 2, &"potato": 0, &"pumpkin": 0}
    var harvested_only := GameSession.new(func() -> float: return 0.9)
    assert_true(harvested_only.restore_state(harvested_state))
    assert_eq(
        harvested_only.talk_to(mira, WorldContract.villager_cell(mira))["lines"],
        [no_shipment_literal],
    )

    var pending_state := _talk_session(12, true, [0, 0, 0]).state()
    pending_state["pending_shipment"] = {&"turnip": 1, &"potato": 0, &"pumpkin": 0}
    var pending_only := GameSession.new(func() -> float: return 0.9)
    assert_true(pending_only.restore_state(pending_state))
    assert_eq(
        pending_only.talk_to(mira, WorldContract.villager_cell(mira))["lines"],
        [no_shipment_literal],
    )

    var settled := _talk_session(12, true, [1, 0, 0])
    assert_eq(
        settled.talk_to(mira, WorldContract.villager_cell(mira))["lines"],
        ["The market is close. Keep some coin ready for what comes next."],
    )

func test_post_talk_points_select_the_friend_tier_literal() -> void:
    var state := _talk_session(1, false, [0, 0, 0]).state()
    state["relationships"][&"shopkeeper"]["points"] = 11
    assert_eq(GameSession.state_error(state), "")
    var session := GameSession.new(func() -> float: return 0.9)
    assert_true(session.restore_state(state))
    var mira := VillagerRules.VillagerId.SHOPKEEPER
    var result: Dictionary = session.talk_to(mira, WorldContract.villager_cell(mira))
    assert_eq(result["points_gained"], 1)
    assert_eq(result["lines"], ["Your fields are starting to look dependable."])
    assert_eq(session.snapshot()["relationships"][&"shopkeeper"]["level"], &"friend")

func test_talking_does_not_consume_weather_rng() -> void:
    var calls := [0]
    var session := GameSession.new(func() -> float:
        calls[0] += 1
        return 0.9
    )
    var june := VillagerRules.VillagerId.RESIDENT
    var result: Dictionary = session.talk_to(june, WorldContract.villager_cell(june))
    assert_eq(result["code"], GameRules.CommandCode.VILLAGER_TALKED)
    assert_eq(calls[0], 0)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(calls[0], 1)

func test_equivalent_restored_state_repeats_the_same_literal() -> void:
    var mira := VillagerRules.VillagerId.SHOPKEEPER
    var session := _talk_session(12, true, [1, 0, 0])
    var saved := session.state()
    var first: Dictionary = session.talk_to(mira, WorldContract.villager_cell(mira))
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(saved))
    var second: Dictionary = restored.talk_to(mira, WorldContract.villager_cell(mira))
    assert_eq(second["lines"], first["lines"])
    assert_eq(second["lines"], ["The market is close. Keep some coin ready for what comes next."])

func test_social_guards_preserve_complete_snapshot_in_order() -> void:
    var pending := GameSession.new(func() -> float: return 0.9)
    var pending_id := VillagerRules.VillagerId.RESIDENT
    assert_eq(pending.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var pending_before := pending.snapshot()
    assert_eq(
        pending.talk_to(pending_id, Vector2i(0, 0))["code"],
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(pending, pending_before)
    assert_eq(
        pending.gift_crop(
            pending_id,
            GameRules.CropKind.TURNIP,
            Vector2i(0, 0),
        )["code"],
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(pending, pending_before)

    var wrong_target := GameSession.new(func() -> float: return 0.9)
    var wrong_id := VillagerRules.VillagerId.SHOPKEEPER
    var wrong_before := wrong_target.snapshot()
    assert_eq(
        wrong_target.talk_to(wrong_id, Vector2i(0, 0))["code"],
        GameRules.CommandCode.NOT_AT_VILLAGER,
    )
    _assert_unchanged(wrong_target, wrong_before)
    assert_eq(
        wrong_target.gift_crop(
            wrong_id,
            GameRules.CropKind.TURNIP,
            Vector2i(0, 0),
        )["code"],
        GameRules.CommandCode.NOT_AT_VILLAGER,
    )
    _assert_unchanged(wrong_target, wrong_before)

    var duplicate := GameSession.new(func() -> float: return 0.9)
    var duplicate_id := VillagerRules.VillagerId.SHOPKEEPER
    var duplicate_seeded: Array[int] = [1, 0, 0]
    _seed_harvested(duplicate, duplicate_seeded)
    assert_eq(
        duplicate.gift_crop(
            duplicate_id,
            GameRules.CropKind.TURNIP,
            WorldContract.villager_cell(duplicate_id),
        )["code"],
        GameRules.CommandCode.CROP_GIFTED,
    )
    var duplicate_before := duplicate.snapshot()
    assert_eq(
        duplicate.gift_crop(
            duplicate_id,
            GameRules.CropKind.TURNIP,
            WorldContract.villager_cell(duplicate_id),
        )["code"],
        GameRules.CommandCode.GIFT_ALREADY_GIVEN,
    )
    _assert_unchanged(duplicate, duplicate_before)

    var insufficient := GameSession.new(func() -> float: return 0.9)
    var insufficient_id := VillagerRules.VillagerId.FARMER
    var insufficient_before := insufficient.snapshot()
    assert_eq(
        insufficient.gift_crop(
            insufficient_id,
            GameRules.CropKind.PUMPKIN,
            WorldContract.villager_cell(insufficient_id),
        )["code"],
        GameRules.CommandCode.INSUFFICIENT_CROPS,
    )
    _assert_unchanged(insufficient, insufficient_before)

func test_june_reaches_close_friend_and_special_sequence_once() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var seeded: Array[int] = [3, 0, 0]
    _seed_harvested(session, seeded)
    var june := VillagerRules.VillagerId.RESIDENT

    for expected_points in [6, 12]:
        assert_eq(session.talk_to(june, WorldContract.villager_cell(june))["points_gained"], 1)
        assert_eq(session.gift_crop(june, GameRules.CropKind.TURNIP, WorldContract.villager_cell(june))["points_gained"], 5)
        assert_eq(session.snapshot()["relationships"][&"resident"]["points"], expected_points)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_false(session.snapshot()["relationships"][&"resident"]["talked_today"])
        assert_false(session.snapshot()["relationships"][&"resident"]["gifted_today"])
        assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)

    assert_eq(session.talk_to(june, WorldContract.villager_cell(june))["points_gained"], 1)
    assert_eq(session.gift_crop(june, GameRules.CropKind.TURNIP, WorldContract.villager_cell(june))["points_gained"], 5)
    assert_eq(session.snapshot()["relationships"][&"resident"]["points"], 18)
    assert_false(session.snapshot()["relationships"][&"resident"]["close_friend_dialogue_seen"])

    var special: Dictionary = session.talk_to(june, WorldContract.villager_cell(june))
    assert_eq(special["points_gained"], 0)
    assert_true(special["close_friend_sequence"])
    assert_eq(special["lines"], VillagerRules.close_friend_dialogue_lines(june))

    var normal: Dictionary = session.talk_to(june, WorldContract.villager_cell(june))
    assert_false(normal["close_friend_sequence"])
    assert_eq(
        normal["lines"],
        ["You do not look like a newcomer when you walk through town anymore."],
    )
    assert_true(session.snapshot()["relationships"][&"resident"]["close_friend_dialogue_seen"])

func test_turnip_actions_commit_atomically() -> void:
    var session := GameSession.new()
    var cell := FARM_CELL
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
    var session := GameSession.new(func() -> float: return 0.9)
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
    for _night in 3:
        if _night > 0:
            assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            session.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )
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

    var mature := GameSession.new(func() -> float: return 0.9)
    _mature_turnip(mature)
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
    _plant_turnip(rainy)
    assert_eq(rainy.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(rainy.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)
    var before_rain := rainy.snapshot()
    assert_eq(rainy.water(FARM_CELL), GameRules.CommandCode.RAIN_WATERS_CROPS)
    _assert_unchanged(rainy, before_rain)
    var before_rain_again := rainy.snapshot()
    assert_eq(rainy.water(FARM_CELL), GameRules.CommandCode.RAIN_WATERS_CROPS)
    _assert_unchanged(rainy, before_rain_again)

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

    var mature := GameSession.new(func() -> float: return 0.9)
    _mature_turnip(mature)
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

func test_preview_selected_action_matches_hoe_and_plant_guards_without_mutation() -> void:
    var session := GameSession.new()

    _assert_preview(
        session,
        FARM_CELL,
        GameRules.CommandCode.SOIL_TILLED,
        GameRules.FarmingAction.HOE,
        null,
    )

    assert_eq(session.hoe(FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
    _assert_preview(
        session,
        FARM_CELL,
        GameRules.CommandCode.ALREADY_TILLED,
        GameRules.FarmingAction.HOE,
        null,
    )

    assert_eq(
        session.select_action(GameRules.FarmingAction.SEEDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    _assert_preview(
        session,
        FARM_CELL,
        GameRules.CommandCode.CROP_PLANTED,
        GameRules.FarmingAction.SEEDS,
        GameRules.CropKind.TURNIP,
    )

    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.SEED_SELECTED,
    )
    _assert_preview(
        session,
        FARM_CELL,
        GameRules.CommandCode.NO_SELECTED_SEEDS,
        GameRules.FarmingAction.SEEDS,
        GameRules.CropKind.POTATO,
    )

func test_preview_selected_action_matches_water_guards_without_mutation() -> void:
    var session := GameSession.new()
    _plant_turnip(session)
    assert_eq(
        session.select_action(GameRules.FarmingAction.WATERING_CAN),
        GameRules.CommandCode.ACTION_SELECTED,
    )

    _assert_preview(
        session,
        SECOND_FARM_CELL,
        GameRules.CommandCode.NO_CROP,
        GameRules.FarmingAction.WATERING_CAN,
        null,
    )
    _assert_preview(
        session,
        FARM_CELL,
        GameRules.CommandCode.CROP_WATERED,
        GameRules.FarmingAction.WATERING_CAN,
        GameRules.CropKind.TURNIP,
    )

    assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    _assert_preview(
        session,
        FARM_CELL,
        GameRules.CommandCode.ALREADY_WATERED,
        GameRules.FarmingAction.WATERING_CAN,
        GameRules.CropKind.TURNIP,
    )

func test_preview_selected_action_matches_harvest_guards_without_mutation() -> void:
    var immature := GameSession.new()
    _plant_turnip(immature)
    assert_eq(
        immature.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    _assert_preview(
        immature,
        FARM_CELL,
        GameRules.CommandCode.CROP_IMMATURE,
        GameRules.FarmingAction.HANDS,
        GameRules.CropKind.TURNIP,
    )

    var mature := GameSession.new(func() -> float: return 0.9)
    _mature_turnip(mature)
    assert_eq(
        mature.select_action(GameRules.FarmingAction.HANDS),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    _assert_preview(
        mature,
        FARM_CELL,
        GameRules.CommandCode.CROP_HARVESTED,
        GameRules.FarmingAction.HANDS,
        GameRules.CropKind.TURNIP,
    )

func test_preview_selected_action_matches_budget_failure_without_mutation() -> void:
    var session := GameSession.new()
    var cells := WorldContract.farm_cells()
    for index in 6:
        assert_eq(session.hoe(cells[index]), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.snapshot()["stamina"], 2)
    assert_eq(
        session.select_action(GameRules.FarmingAction.HOE),
        GameRules.CommandCode.ACTION_SELECTED,
    )

    _assert_preview(
        session,
        cells[6],
        GameRules.CommandCode.INSUFFICIENT_STAMINA,
        GameRules.FarmingAction.HOE,
        null,
    )

func test_buy_seeds_validates_target_quantity_and_funds_atomically() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var before_wrong_target := session.snapshot()
    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 1, Vector2i(0, 0)),
        GameRules.CommandCode.NOT_AT_SHOP,
    )
    _assert_unchanged(session, before_wrong_target)

    var before_invalid_quantity := session.snapshot()
    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 0, WorldContract.SHOP_CELL),
        GameRules.CommandCode.INVALID_QUANTITY,
    )
    _assert_unchanged(session, before_invalid_quantity)

    var before_insufficient_funds := session.snapshot()
    assert_eq(
        session.buy_seeds(GameRules.CropKind.PUMPKIN, 3, WorldContract.SHOP_CELL),
        GameRules.CommandCode.INSUFFICIENT_FUNDS,
    )
    _assert_unchanged(session, before_insufficient_funds)

    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 2, WorldContract.SHOP_CELL),
        GameRules.CommandCode.SEEDS_PURCHASED,
    )
    var purchased := session.snapshot()
    assert_eq(purchased["money"], 70)
    assert_eq(purchased["seeds"][&"potato"], 2)
    assert_eq(purchased["time_minutes"], GameRules.DAY_START_MINUTES)
    assert_eq(purchased["stamina"], GameRules.MAX_STAMINA)

func test_buy_watering_can_upgrade_guards_in_order_and_purchases_atomically() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var starter := session.snapshot()
    assert_eq(int(starter["money"]), 150)

    # Wrong location outranks insufficient funds and changes nothing.
    assert_eq(
        session.buy_watering_can_upgrade(Vector2i(0, 0)),
        GameRules.CommandCode.NOT_AT_SHOP,
    )
    assert_eq(
        session.buy_watering_can_upgrade(null),
        GameRules.CommandCode.NOT_AT_SHOP,
    )
    _assert_unchanged(session, starter)

    # Starter 150G is short of the 200G price at the exact shop cell.
    assert_eq(
        session.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.INSUFFICIENT_FUNDS,
    )
    _assert_unchanged(session, starter)

    # Exact 200G succeeds: only money and ownership move.
    var funded := _session_with_money(200)
    var funded_before := funded.snapshot()
    _purchase_upgrade(funded)
    var expected := funded_before.duplicate(true)
    expected["money"] = 0
    expected["watering_can_upgraded"] = true
    assert_eq(funded.snapshot(), expected)

    # Duplicate purchase is a no-op returning the dedicated code.
    assert_eq(
        funded.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.WATERING_CAN_ALREADY_UPGRADED,
    )
    _assert_unchanged(funded, expected)

func test_buy_watering_can_upgrade_scales_with_funds_and_restores_ownership() -> void:
    # The reference route's 255G moment: purchase lands at exactly 55G.
    var session := _session_with_money(255)
    _purchase_upgrade(session)
    var purchased := session.snapshot()
    assert_eq(int(purchased["money"]), 55)
    assert_true(purchased["watering_can_upgraded"])

    var saved := session.state()
    assert_eq(GameSession.state_error(saved), "")
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(saved))
    assert_eq(restored.snapshot(), purchased)
    assert_eq(
        restored._cost_for(GameRules.FarmingAction.WATERING_CAN),
        {"minutes": 20, "stamina": 1},
    )
    assert_eq(
        restored.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.WATERING_CAN_ALREADY_UPGRADED,
    )

func test_preview_and_watering_agree_at_base_and_upgraded_boundaries() -> void:
    var base := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(base)
    assert_eq(
        base.select_action(GameRules.FarmingAction.WATERING_CAN),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    var base_preview := _assert_preview(
        base,
        FARM_CELL,
        GameRules.CommandCode.CROP_WATERED,
        GameRules.FarmingAction.WATERING_CAN,
        GameRules.CropKind.TURNIP,
    )
    assert_eq(base_preview["cost"], {"minutes": 20, "stamina": 2})
    assert_eq(base.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    assert_eq(int(base.snapshot()["stamina"]), GameRules.MAX_STAMINA - 4 - 2)

    var upgraded := _water_target_session(GameRules.MAX_STAMINA - 4, true)
    assert_eq(
        upgraded.select_action(GameRules.FarmingAction.WATERING_CAN),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    var upgraded_preview := _assert_preview(
        upgraded,
        FARM_CELL,
        GameRules.CommandCode.CROP_WATERED,
        GameRules.FarmingAction.WATERING_CAN,
        GameRules.CropKind.TURNIP,
    )
    assert_eq(upgraded_preview["cost"], {"minutes": 20, "stamina": 1})
    assert_eq(upgraded.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    assert_eq(int(upgraded.snapshot()["stamina"]), GameRules.MAX_STAMINA - 4 - 1)

func test_upgraded_watering_succeeds_where_base_watering_cannot() -> void:
    var base := _water_target_session(1, false)
    var base_before := base.snapshot()
    assert_eq(
        base.water(FARM_CELL),
        GameRules.CommandCode.INSUFFICIENT_STAMINA,
    )
    _assert_unchanged(base, base_before)

    var upgraded := _water_target_session(1, true)
    assert_eq(upgraded.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    assert_eq(int(upgraded.snapshot()["stamina"]), 0)

func test_rain_still_rejects_watering_in_both_ownership_states() -> void:
    for upgraded in [false, true]:
        var session := _water_target_session(GameRules.MAX_STAMINA, upgraded, &"rainy")
        var before := session.snapshot()
        assert_eq(session.water(FARM_CELL), GameRules.CommandCode.RAIN_WATERS_CROPS)
        _assert_unchanged(session, before)

func test_deposit_crop_validates_target_quantity_and_carried_inventory() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    _grow_and_harvest_turnip(session)

    var before_wrong_target := session.snapshot()
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, Vector2i(0, 0)),
        GameRules.CommandCode.NOT_AT_SHIPPING_BIN,
    )
    _assert_unchanged(session, before_wrong_target)

    var before_invalid_quantity := session.snapshot()
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 0, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.INVALID_QUANTITY,
    )
    _assert_unchanged(session, before_invalid_quantity)

    var before_insufficient_crops := session.snapshot()
    assert_eq(
        session.deposit_crop(GameRules.CropKind.POTATO, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.INSUFFICIENT_CROPS,
    )
    _assert_unchanged(session, before_insufficient_crops)

    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    var deposited := session.snapshot()
    assert_eq(deposited["harvested"][&"turnip"], 0)
    assert_eq(deposited["pending_shipment"][&"turnip"], 1)

func test_watered_sunny_crop_advances_once_and_resets_watered_flag() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(session)
    assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var snapshot := session.snapshot()
    assert_eq(snapshot["day"], 2)
    assert_eq(snapshot["farm"][0]["crop"]["growth"], 1)
    assert_false(snapshot["farm"][0]["crop"]["watered_today"])
    assert_eq(snapshot["pending_morning_summary"]["crops_advanced"], 1)
    assert_eq(snapshot["pending_morning_summary"]["stamina_restored"], 6)
    assert_eq(snapshot["pending_morning_summary"]["next_weather"], &"sunny")

func test_unwatered_sunny_crop_does_not_advance() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(session)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var snapshot := session.snapshot()
    assert_eq(snapshot["farm"][0]["crop"]["growth"], 0)
    assert_false(snapshot["farm"][0]["crop"]["watered_today"])
    assert_eq(snapshot["pending_morning_summary"]["crops_advanced"], 0)

func test_rainy_completed_day_advances_each_planted_crop() -> void:
    var rolls := [0.1, 0.9]
    var roll_index := [0]
    var session := GameSession.new(func() -> float:
        var roll: float = rolls[roll_index[0]]
        roll_index[0] += 1
        return roll
    )
    _plant_turnip(session, FARM_CELL)
    _plant_turnip(session, SECOND_FARM_CELL)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)
    assert_eq(session.snapshot()["weather"], &"rainy")

    var before_rain_water := session.snapshot()
    assert_eq(session.water(FARM_CELL), GameRules.CommandCode.RAIN_WATERS_CROPS)
    _assert_unchanged(session, before_rain_water)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var snapshot := session.snapshot()
    assert_eq(snapshot["farm"][0]["crop"]["growth"], 1)
    assert_eq(snapshot["farm"][1]["crop"]["growth"], 1)
    assert_false(snapshot["farm"][0]["crop"]["watered_today"])
    assert_false(snapshot["farm"][1]["crop"]["watered_today"])
    assert_eq(snapshot["pending_morning_summary"]["crops_advanced"], 2)
    assert_eq(snapshot["pending_morning_summary"]["next_weather"], &"sunny")

func test_sleep_wrong_target_preserves_snapshot_and_does_not_consume_weather() -> void:
    var weather_calls := [0]
    var session := GameSession.new(func() -> float:
        weather_calls[0] += 1
        return 0.9
    )
    var before := session.snapshot()
    assert_eq(session.sleep(Vector2i(0, 0)), GameRules.CommandCode.NOT_AT_BED)
    _assert_unchanged(session, before)
    assert_eq(weather_calls[0], 0)

func test_invalid_sleep_weather_roll_is_an_invariant_error() -> void:
    var session := GameSession.new(func() -> float: return 1.0)
    session.sleep(WorldContract.BED_CELL)
    assert_engine_error_count(1)

func test_next_weather_uses_rain_thresholds_and_consumes_one_roll_per_sleep() -> void:
    var rolls := [0.249999, 0.25]
    var roll_index := [0]
    var session := GameSession.new(func() -> float:
        var roll: float = rolls[roll_index[0]]
        roll_index[0] += 1
        return roll
    )
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(session.snapshot()["weather"], &"rainy")
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(session.snapshot()["weather"], &"sunny")
    assert_eq(roll_index[0], 2)

func test_sleep_settles_shipping_once_and_stores_itemized_summary() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    _grow_and_harvest_turnip(session)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var snapshot := session.snapshot()
    assert_eq(snapshot["money"], GameRules.STARTING_MONEY + 35)
    assert_eq(snapshot["pending_shipment"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(
        snapshot["pending_morning_summary"]["shipments"],
        [{"crop": &"turnip", "quantity": 1, "amount": 35}],
    )
    assert_eq(snapshot["pending_morning_summary"]["shipping_income"], 35)
    assert_eq(snapshot["pending_morning_summary"]["money_after_shipping"], 185)

    var before_duplicate_sleep := snapshot
    assert_eq(
        session.sleep(WorldContract.BED_CELL),
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before_duplicate_sleep)
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)
    assert_eq(session.snapshot()["money"], 185)

func test_pending_morning_summary_blocks_active_commands_without_mutation() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(session)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    var before := session.snapshot()

    assert_eq(
        session.select_action(GameRules.FarmingAction.SEEDS),
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before)
    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before)
    for command in [session.hoe, session.plant, session.water, session.harvest]:
        assert_eq(command.call(FARM_CELL), GameRules.CommandCode.DAY_SUMMARY_PENDING)
        _assert_unchanged(session, before)
    assert_eq(
        session.apply_selected_action(FARM_CELL),
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before)
    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 1, WorldContract.SHOP_CELL),
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before)
    assert_eq(
        session.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before)
    var resident := VillagerRules.VillagerId.RESIDENT
    assert_eq(
        session.talk_to(resident, WorldContract.villager_cell(resident))["code"],
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before)
    assert_eq(
        session.gift_crop(
            resident,
            GameRules.CropKind.TURNIP,
            WorldContract.villager_cell(resident),
        )["code"],
        GameRules.CommandCode.DAY_SUMMARY_PENDING,
    )
    _assert_unchanged(session, before)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_SUMMARY_PENDING)
    _assert_unchanged(session, before)

    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)
    var before_duplicate_ack := session.snapshot()
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.NO_DAY_SUMMARY)
    _assert_unchanged(session, before_duplicate_ack)

func _day14_session_from(state: Dictionary, session: GameSession = null) -> GameSession:
    if session == null:
        session = GameSession.new(func() -> float: return 0.9)
    var seeded := session.state()
    seeded["day"] = GameRules.MAX_DAY
    seeded["weather_history"] = []
    for _day in GameRules.MAX_DAY:
        seeded["weather_history"].append(&"sunny")
    for field in state:
        seeded[field] = state[field]
    seeded["weather_history"][GameRules.MAX_DAY - 1] = seeded["weather"]
    assert_eq(GameSession.state_error(seeded), "")
    assert_true(session.restore_state(seeded))
    var snapshot := session.snapshot()
    assert_eq(snapshot["day"], GameRules.MAX_DAY)
    assert_null(snapshot["pending_morning_summary"])
    assert_false(snapshot["finale_triggered"])
    for field in ["harvested", "pending_shipment", "shipped", "seeds", "money"]:
        if state.has(field):
            assert_eq(snapshot[field], state[field])
    return session

func _day14_pre_final_state() -> Dictionary:
    return {
        "harvested": {&"turnip": 2, &"potato": 0, &"pumpkin": 0},
        "pending_shipment": {&"turnip": 1, &"potato": 0, &"pumpkin": 0},
        "shipped": {&"turnip": 1, &"potato": 0, &"pumpkin": 0},
    }

func test_market_finale_before_day_fourteen_is_not_ready() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var before := session.snapshot()
    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.MARKET_NOT_READY,
    )
    _assert_unchanged(session, before)

func test_day_fourteen_market_requires_the_exact_market_cell() -> void:
    var session := _day14_session_from({})
    var before := session.snapshot()
    assert_eq(
        session.trigger_harvest_finale(WorldContract.SHOP_CELL),
        GameRules.CommandCode.NOT_AT_MARKET,
    )
    _assert_unchanged(session, before)
    assert_eq(
        session.trigger_harvest_finale(null),
        GameRules.CommandCode.NOT_AT_MARKET,
    )
    _assert_unchanged(session, before)

func test_day_fourteen_market_completes_the_canonical_terminal_state() -> void:
    var session := _day14_session_from(_day14_pre_final_state())
    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_TRIGGERED,
    )
    var state := session.state()
    assert_true(state["finale_triggered"])
    assert_eq(state["day"], GameRules.MAX_DAY)
    assert_null(state["pending_morning_summary"])
    assert_eq(state["harvested"], {&"turnip": 2, &"potato": 0, &"pumpkin": 0})
    assert_eq(state["shipped"], {&"turnip": 2, &"potato": 0, &"pumpkin": 0})
    assert_eq(state["pending_shipment"], {&"turnip": 0, &"potato": 0, &"pumpkin": 0})
    assert_eq(state["money"], GameRules.STARTING_MONEY + 35)
    assert_eq(GameSession.state_error(state), "")
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(state))
    assert_eq(restored.state(), state)

func test_market_and_bed_routes_produce_identical_canonical_terminal_states() -> void:
    var market := _day14_session_from(_day14_pre_final_state())
    assert_eq(
        market.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_TRIGGERED,
    )
    var bed := _day14_session_from(_day14_pre_final_state())
    assert_eq(bed.sleep(WorldContract.BED_CELL), GameRules.CommandCode.FINALE_TRIGGERED)
    assert_eq(market.state(), bed.state())
    assert_eq(
        ContentRules.build_harvest_result(market.state()),
        ContentRules.build_harvest_result(bed.state()),
    )

func test_day_fourteen_bed_completes_without_overnight_progression() -> void:
    var weather_calls := [0]
    var session := GameSession.new(func() -> float:
        weather_calls[0] += 1
        return 0.9
    )
    var state := _day14_pre_final_state()
    state["weather"] = &"rainy"
    state["time_minutes"] = 1200
    state["stamina"] = 5
    _day14_session_from(state, session)
    var seeded := session.state()
    seeded["farm"][0]["tilled"] = true
    seeded["farm"][0]["crop"] = {"kind": &"turnip", "growth": 1, "watered_today": true}
    seeded["relationships"][&"resident"]["talked_today"] = true
    seeded["relationships"][&"resident"]["gifted_today"] = true
    assert_true(session.restore_state(seeded))
    var before := session.snapshot()

    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.FINALE_TRIGGERED)

    var after := session.snapshot()
    assert_eq(after["day"], GameRules.MAX_DAY)
    assert_null(after["pending_morning_summary"])
    assert_eq(after["weather"], &"rainy")
    assert_eq(after["time_minutes"], 1200)
    assert_eq(after["stamina"], 5)
    assert_eq(after["farm"], before["farm"])
    assert_eq(after["relationships"], before["relationships"])
    assert_eq(weather_calls[0], 0)

func test_duplicate_terminal_commands_return_finale_already_triggered_without_mutation() -> void:
    var session := _day14_session_from(_day14_pre_final_state())
    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_TRIGGERED,
    )
    var completed := session.snapshot()
    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    _assert_unchanged(session, completed)
    assert_eq(
        session.sleep(WorldContract.BED_CELL),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    _assert_unchanged(session, completed)

func test_finale_blocks_every_ordinary_gameplay_command() -> void:
    var session := _day14_session_from(_day14_pre_final_state())
    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_TRIGGERED,
    )
    var completed := session.snapshot()
    assert_eq(
        session.select_action(GameRules.FarmingAction.SEEDS),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    for command in [session.hoe, session.plant, session.water, session.harvest]:
        assert_eq(command.call(FARM_CELL), GameRules.CommandCode.FINALE_ALREADY_TRIGGERED)
    assert_eq(
        session.apply_selected_action(FARM_CELL),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 1, WorldContract.SHOP_CELL),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    assert_eq(
        session.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    var june := VillagerRules.VillagerId.RESIDENT
    assert_eq(
        session.talk_to(june, WorldContract.villager_cell(june))["code"],
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    assert_eq(
        session.gift_crop(
            june,
            GameRules.CropKind.TURNIP,
            WorldContract.villager_cell(june),
        )["code"],
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    assert_eq(
        session.sleep(WorldContract.BED_CELL),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    _assert_unchanged(session, completed)

func test_public_all_crop_lifecycles_are_successful() -> void:
    var cases: Array = [
        [GameRules.CropKind.TURNIP, 3],
        [GameRules.CropKind.POTATO, 5],
        [GameRules.CropKind.PUMPKIN, 7],
    ]
    for case_data in cases:
        var kind: GameRules.CropKind = case_data[0]
        var nights: int = case_data[1]
        var session := GameSession.new(func() -> float: return 0.9)
        assert_eq(
            session.buy_seeds(kind, 1, WorldContract.SHOP_CELL),
            GameRules.CommandCode.SEEDS_PURCHASED,
        )
        assert_eq(session.select_seed(kind), GameRules.CommandCode.SEED_SELECTED)
        assert_eq(session.hoe(FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
        assert_eq(session.plant(FARM_CELL), GameRules.CommandCode.CROP_PLANTED)
        for _night in nights:
            assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
            assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
            assert_eq(
                session.acknowledge_morning_summary(),
                GameRules.CommandCode.DAY_STARTED,
            )
        assert_eq(session.harvest(FARM_CELL), GameRules.CommandCode.CROP_HARVESTED)

        var snapshot := session.snapshot()
        var crop_key := GameRules.crop_key(kind)
        assert_eq(snapshot["harvested"][crop_key], 1)
        assert_true(snapshot["farm"][0]["tilled"])
        assert_null(snapshot["farm"][0]["crop"])

func test_public_potato_loop_reinvests_shipping_income() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 1, WorldContract.SHOP_CELL),
        GameRules.CommandCode.SEEDS_PURCHASED,
    )
    assert_eq(
        session.select_seed(GameRules.CropKind.POTATO),
        GameRules.CommandCode.SEED_SELECTED,
    )
    assert_eq(session.hoe(FARM_CELL), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(FARM_CELL), GameRules.CommandCode.CROP_PLANTED)
    for _night in 5:
        assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
        assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
        assert_eq(
            session.acknowledge_morning_summary(),
            GameRules.CommandCode.DAY_STARTED,
        )
    assert_eq(session.harvest(FARM_CELL), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.POTATO, 1, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)

    var after_shipping := session.snapshot()
    assert_eq(after_shipping["money"], 185)
    assert_eq(
        session.buy_seeds(GameRules.CropKind.POTATO, 1, WorldContract.SHOP_CELL),
        GameRules.CommandCode.SEEDS_PURCHASED,
    )
    var reinvested := session.snapshot()
    assert_eq(reinvested["money"], 145)
    assert_eq(reinvested["seeds"][&"potato"], 1)

func test_representative_reinvestment_route_reaches_promising() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var cells := [
        WorldContract.farm_cells()[0],
        WorldContract.farm_cells()[1],
        WorldContract.farm_cells()[2],
    ]

    # Starter crop: three Turnips, watered through three sunny growth nights.
    for cell in cells:
        assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
        assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 2
    for cell in cells:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 3
    for cell in cells:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 4, mature

    for cell in cells:
        assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 3, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    _sleep_and_ack(session)  # Day 5, first 105G shipment settled

    # Reinvest into two more Turnips on already-tilled cells.
    assert_eq(
        session.buy_seeds(GameRules.CropKind.TURNIP, 2, WorldContract.SHOP_CELL),
        GameRules.CommandCode.SEEDS_PURCHASED,
    )
    for cell in cells.slice(0, 2):
        assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 6
    for cell in cells.slice(0, 2):
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 7
    for cell in cells.slice(0, 2):
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 8, mature

    for cell in cells.slice(0, 2):
        assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 2, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    _sleep_and_ack(session)  # Day 9, second 70G shipment settled

    while int(session.snapshot()["day"]) < GameRules.MAX_DAY:
        _sleep_and_ack(session)

    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_TRIGGERED,
    )
    var result := ContentRules.build_harvest_result(session.state())
    assert_eq(result["shipped_count"], 5)
    assert_eq(result["shipped_value"], 175)
    assert_true(int(result["shipped_value"]) >= ContentRules.PROMISING_SHIPPED_VALUE)
    assert_eq(result["tier"], &"promising_farmer")

func test_upgrade_purchase_keeps_reinvestment_route_intact() -> void:
    # Economy-safety clone of the representative route: the same five Turnips
    # reach the same 175G / promising_farmer finale when the 200G upgrade is
    # bought at the first-settlement seam. This proves purchase accounting
    # does not corrupt the route; the 200G value proof itself stays with the
    # larger-farm throughput benchmark in test_balance_gate_*.
    var session := GameSession.new(func() -> float: return 0.9)
    var cells := [
        WorldContract.farm_cells()[0],
        WorldContract.farm_cells()[1],
        WorldContract.farm_cells()[2],
    ]

    # Starter crop: three Turnips, watered through three sunny growth nights.
    for cell in cells:
        assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
        assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 2
    for cell in cells:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 3
    for cell in cells:
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 4, mature

    for cell in cells:
        assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 3, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    _sleep_and_ack(session)  # Day 5, first 105G shipment settled

    # The purchase seam: 255G settled -> upgrade -> 55G -> two seeds -> 15G.
    assert_eq(int(session.snapshot()["money"]), 255)
    assert_eq(
        session.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.WATERING_CAN_UPGRADED,
    )
    assert_eq(int(session.snapshot()["money"]), 55)
    assert_true(session.snapshot()["watering_can_upgraded"])
    assert_eq(
        session.buy_seeds(GameRules.CropKind.TURNIP, 2, WorldContract.SHOP_CELL),
        GameRules.CommandCode.SEEDS_PURCHASED,
    )
    assert_eq(int(session.snapshot()["money"]), 15)

    # Same reinvestment into two more Turnips on already-tilled cells.
    for cell in cells.slice(0, 2):
        assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 6
    for cell in cells.slice(0, 2):
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 7
    for cell in cells.slice(0, 2):
        assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Day 8, mature

    for cell in cells.slice(0, 2):
        assert_eq(session.harvest(cell), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(
        session.deposit_crop(GameRules.CropKind.TURNIP, 2, WorldContract.SHIPPING_CELL),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    _sleep_and_ack(session)  # Day 9, second 70G shipment settles into 85G

    while int(session.snapshot()["day"]) < GameRules.MAX_DAY:
        _sleep_and_ack(session)

    assert_eq(
        session.trigger_harvest_finale(WorldContract.MARKET_CELL),
        GameRules.CommandCode.FINALE_TRIGGERED,
    )
    var final := session.snapshot()
    var result := ContentRules.build_harvest_result(session.state())
    assert_eq(result["shipped_count"], 5)
    assert_eq(result["shipped_value"], 175)
    assert_eq(result["tier"], &"promising_farmer")
    assert_true(bool(final["watering_can_upgraded"]))
    assert_eq(int(final["money"]), 85)
    assert_eq(int(final["day"]), GameRules.MAX_DAY)
    # The terminal state leaves no Day 15: sleep is refused without mutation.
    assert_eq(
        session.sleep(WorldContract.BED_CELL),
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED,
    )
    assert_eq(int(session.snapshot()["day"]), GameRules.MAX_DAY)

func _benchmark_session(upgraded: bool) -> GameSession:
    # Prepared balance fixture: Day 1, 200G, ten authored farm cells already
    # tilled and empty, ten Pumpkin seeds, always-sunny weather, and no
    # relationship shortcut. It isolates stamina throughput, not seed buying.
    var session := GameSession.new(func() -> float: return 0.9)
    var seeded := session.state()
    seeded["money"] = GameRules.WATERING_CAN_UPGRADE_PRICE
    seeded["seeds"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 10}
    seeded["selected_seed"] = &"pumpkin"
    for index in 10:
        seeded["farm"][index]["tilled"] = true
    assert_eq(GameSession.state_error(seeded), "")
    assert_true(session.restore_state(seeded))
    if upgraded:
        _purchase_upgrade(session)
        assert_eq(int(session.snapshot()["money"]), 0)
    return session

func _run_benchmark_route(session: GameSession, crop_count: int) -> void:
    var cells := WorldContract.farm_cells()
    # Day 1: complete Plant + Water pairs cost 3 stamina base vs 2 upgraded.
    for index in crop_count:
        assert_eq(session.plant(cells[index]), GameRules.CommandCode.CROP_PLANTED)
        assert_eq(session.water(cells[index]), GameRules.CommandCode.CROP_WATERED)
    _sleep_and_ack(session)  # Night 1
    # Days 2..7: maintain the crops through their remaining sunny nights.
    for _night in 6:
        for index in crop_count:
            assert_eq(session.water(cells[index]), GameRules.CommandCode.CROP_WATERED)
        _sleep_and_ack(session)
    # Day 8: mature; harvest, deposit, and settle overnight into Day 9.
    for index in crop_count:
        assert_eq(session.harvest(cells[index]), GameRules.CommandCode.CROP_HARVESTED)
    assert_eq(
        session.deposit_crop(
            GameRules.CropKind.PUMPKIN,
            crop_count,
            WorldContract.SHIPPING_CELL,
        ),
        GameRules.CommandCode.CROP_DEPOSITED,
    )
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(int(session.snapshot()["day"]), 9)

func test_balance_gate_two_hundred_gold_buys_real_throughput_by_day_nine() -> void:
    var baseline := _benchmark_session(false)
    var upgraded := _benchmark_session(true)
    assert_eq(int(baseline.snapshot()["money"]), 200)
    assert_eq(int(upgraded.snapshot()["money"]), 0)

    _run_benchmark_route(baseline, 6)
    _run_benchmark_route(upgraded, 10)

    var baseline_result := baseline.snapshot()
    var upgraded_result := upgraded.snapshot()
    assert_eq(int(baseline_result["day"]), 9)
    assert_eq(int(upgraded_result["day"]), 9)
    assert_eq(baseline_result["weather"], &"sunny")
    assert_eq(upgraded_result["weather"], &"sunny")
    assert_false(baseline_result["watering_can_upgraded"])
    assert_true(upgraded_result["watering_can_upgraded"])

    var baseline_crops := int(baseline_result["shipped"][&"pumpkin"])
    var upgraded_crops := int(upgraded_result["shipped"][&"pumpkin"])
    var pumpkin_value := GameRules.sale_value(GameRules.CropKind.PUMPKIN)
    var baseline_shipped := baseline_crops * pumpkin_value
    var upgraded_shipped := upgraded_crops * pumpkin_value
    assert_eq(baseline_crops, 6)
    assert_eq(upgraded_crops, 10)
    assert_eq(baseline_shipped, 840)
    assert_eq(upgraded_shipped, 1400)
    assert_eq(int(baseline_result["money"]), 1040)
    assert_eq(int(upgraded_result["money"]), 1400)

    # The pinned advantage: +4 crops / +560G shipped / +360G final money
    # after paying the 200G upgrade price.
    assert_eq(upgraded_crops - baseline_crops, 4)
    assert_eq(upgraded_shipped - baseline_shipped, 560)
    assert_eq(int(upgraded_result["money"]) - int(baseline_result["money"]), 360)
