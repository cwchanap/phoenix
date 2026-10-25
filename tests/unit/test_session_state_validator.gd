extends GutTest

const FARM_CELL := WorldContract.FARM_PATCH.position

func _plant_turnip(session: GameSession, cell: Vector2i = FARM_CELL) -> void:
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)

func _session_with_morning_summary() -> GameSession:
    var session := GameSession.new(func() -> float: return 0.9)
    _plant_turnip(session)
    assert_eq(session.water(FARM_CELL), GameRules.CommandCode.CROP_WATERED)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    return session

func test_state_error_returns_messages_for_missing_and_wrong_typed_fields() -> void:
    assert_ne(SessionStateValidator.state_error({}), "")

    var bad_day := GameSession.new().state()
    bad_day["day"] = "two"
    assert_ne(SessionStateValidator.state_error(bad_day), "")

    var bad_counts := GameSession.new().state()
    bad_counts["seeds"] = []
    assert_ne(SessionStateValidator.state_error(bad_counts), "")

    var bad_farm := GameSession.new().state()
    bad_farm["farm"] = "farm"
    assert_ne(SessionStateValidator.state_error(bad_farm), "")

func test_weather_history_requires_one_entry_per_day() -> void:
    var state := GameSession.new().state()
    state["weather_history"] = []
    assert_eq(SessionStateValidator.state_error(state), "weather_history must contain one entry per day")

func test_weather_history_rejects_invalid_entry() -> void:
    var state := GameSession.new().state()
    state["day"] = 2
    state["weather_history"] = [&"sunny", &"stormy"]
    assert_eq(SessionStateValidator.state_error(state), "weather_history[1] is unknown")

func test_weather_history_requires_final_entry_to_match_current_weather() -> void:
    var state := GameSession.new().state()
    state["weather_history"] = [&"rainy"]
    assert_eq(
        SessionStateValidator.state_error(state),
        "weather_history final entry must match weather",
    )

func test_state_error_rejects_invalid_current_rule_shapes() -> void:
    var valid := GameSession.new().state()
    assert_eq(SessionStateValidator.state_error(valid), "")
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

    var with_summary := _session_with_morning_summary().state()

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
        assert_ne(SessionStateValidator.state_error(candidate), "")

func test_state_error_rejects_invalid_onboarding_and_finale_shapes() -> void:
    var valid := GameSession.new().state()
    assert_eq(SessionStateValidator.state_error(valid), "")
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
    assert_eq(SessionStateValidator.state_error(invalid), "")

    invalid = final_day.duplicate(true)
    invalid["finale_triggered"] = true
    candidates.append(invalid)

    invalid = final_day.duplicate(true)
    invalid["pending_morning_summary"] = null
    invalid["finale_triggered"] = true
    invalid["pending_shipment"][&"turnip"] = 1
    candidates.append(invalid)

    for candidate in candidates:
        assert_ne(SessionStateValidator.state_error(candidate), "")

func test_state_error_rejects_out_of_int64_range_floats_on_every_platform() -> void:
    var overflowing := GameSession.new().state()
    overflowing["money"] = 1e19
    assert_eq(SessionStateValidator.state_error(overflowing), "money is out of range")

    overflowing = GameSession.new().state()
    overflowing["day"] = 1e19
    assert_eq(SessionStateValidator.state_error(overflowing), "day is out of range")

    overflowing = GameSession.new().state()
    overflowing["seeds"]["turnip"] = 1e19
    assert_eq(
        SessionStateValidator.state_error(overflowing),
        "crop count turnip is out of range",
    )

func test_state_error_caps_unbounded_persisted_values() -> void:
    var over_cap := GameSession.new().state()
    over_cap["money"] = SessionStateValidator.MAX_PERSISTED_VALUE + 1
    assert_eq(SessionStateValidator.state_error(over_cap), "money is out of range")

    over_cap = GameSession.new().state()
    over_cap["shipped"]["turnip"] = SessionStateValidator.MAX_PERSISTED_VALUE + 1
    assert_eq(
        SessionStateValidator.state_error(over_cap),
        "crop count turnip is out of range",
    )

    over_cap = GameSession.new().state()
    over_cap["relationships"]["resident"]["points"] = (
        SessionStateValidator.MAX_PERSISTED_VALUE + 1
    )
    assert_eq(
        SessionStateValidator.state_error(over_cap),
        "relationship resident.points is out of range",
    )

    var at_cap := GameSession.new().state()
    at_cap["money"] = SessionStateValidator.MAX_PERSISTED_VALUE
    assert_eq(SessionStateValidator.state_error(at_cap), "")

func test_state_error_rejects_unknown_top_level_fields() -> void:
    var extra := GameSession.new().state()
    extra["unexpected_field"] = 1
    assert_eq(
        SessionStateValidator.state_error(extra),
        "state must contain exactly the persisted fields",
    )
    assert_false(GameSession.new().restore_state(extra))

func test_state_error_prefers_missing_field_errors_over_unknown_field_errors() -> void:
    var drifted := GameSession.new().state()
    drifted.erase("day")
    drifted["unexpected_field"] = 1
    assert_eq(SessionStateValidator.state_error(drifted), "day is missing")

func test_state_error_cross_checks_shipping_income_against_shipments() -> void:
    var with_summary := _session_with_morning_summary().state()
    assert_eq(SessionStateValidator.state_error(with_summary), "")

    var mismatched := with_summary.duplicate(true)
    mismatched["pending_morning_summary"]["shipping_income"] += 1
    assert_eq(
        SessionStateValidator.state_error(mismatched),
        "pending_morning_summary.shipping_income does not match shipments",
    )

    var padded := with_summary.duplicate(true)
    padded["pending_morning_summary"]["shipments"].append({
        "crop": &"turnip",
        "quantity": 1,
        "amount": 1,
    })
    assert_eq(
        SessionStateValidator.state_error(padded),
        "pending_morning_summary.shipping_income does not match shipments",
    )

func test_named_dictionary_value_reads_stringname_and_string_keys() -> void:
    var by_name := SessionStateValidator.named_dictionary_value(
        {&"turnip": 3},
        &"turnip",
        "crop count turnip",
    )
    assert_true(bool(by_name["ok"]))
    assert_eq(by_name["value"], 3)

    var by_string := SessionStateValidator.named_dictionary_value(
        {"turnip": 3},
        &"turnip",
        "crop count turnip",
    )
    assert_true(bool(by_string["ok"]))
    assert_eq(by_string["value"], 3)

    var missing := SessionStateValidator.named_dictionary_value(
        {},
        &"turnip",
        "crop count turnip",
    )
    assert_false(bool(missing["ok"]))
    assert_eq(missing["error"], "crop count turnip is missing")
