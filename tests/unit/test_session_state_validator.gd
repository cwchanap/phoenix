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

    for field in ["selected_seed", "weather"]:
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
        "dry_nights": 0,
        "watered_today": false,
    }
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "farm[0] cannot contain a crop on untilled soil",
    )
    invalid = valid.duplicate(true)
    invalid["farm"][0]["tilled"] = true
    invalid["farm"][0]["crop"] = {
        "kind": &"turnip",
        "growth": GameRules.growth_nights(GameRules.CropKind.TURNIP) + 1,
        "dry_nights": 0,
        "watered_today": false,
    }
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "farm[0].crop.growth is out of range",
    )

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

func test_state_error_validates_dry_nights_shape_and_range() -> void:
    var valid := GameSession.new().state()
    valid["farm"][0]["tilled"] = true
    valid["farm"][0]["crop"] = {
        "kind": &"turnip",
        "growth": 0,
        "dry_nights": 0,
        "watered_today": false,
    }
    assert_eq(SessionStateValidator.state_error(valid), "")

    var one_dry_night := valid.duplicate(true)
    one_dry_night["farm"][0]["crop"]["dry_nights"] = 1
    assert_eq(SessionStateValidator.state_error(one_dry_night), "")

    var invalid := valid.duplicate(true)
    invalid["farm"][0]["crop"].erase("dry_nights")
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "farm[0].crop.dry_nights is missing",
    )

    invalid = valid.duplicate(true)
    invalid["farm"][0]["crop"]["dry_nights"] = 0.5
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "farm[0].crop.dry_nights must be an integer",
    )

    invalid = valid.duplicate(true)
    invalid["farm"][0]["crop"]["dry_nights"] = -1
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "farm[0].crop.dry_nights must be non-negative",
    )

    invalid = valid.duplicate(true)
    invalid["farm"][0]["crop"]["dry_nights"] = 2
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "farm[0].crop.dry_nights is out of range",
    )

func test_state_error_validates_crops_withered_shape_and_range() -> void:
    var valid := _session_with_morning_summary().state()
    assert_eq(valid["pending_morning_summary"].get("crops_withered", -1), 0)
    assert_eq(SessionStateValidator.state_error(valid), "")

    var max_count := valid.duplicate(true)
    max_count["pending_morning_summary"]["crops_withered"] = WorldContract.farm_cells().size()
    assert_eq(SessionStateValidator.state_error(max_count), "")

    var invalid := valid.duplicate(true)
    invalid["pending_morning_summary"].erase("crops_withered")
    assert_eq(SessionStateValidator.state_error(invalid), "crops_withered is missing")

    invalid = valid.duplicate(true)
    invalid["pending_morning_summary"]["crops_withered"] = "zero"
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "crops_withered must be an integer",
    )

    invalid = valid.duplicate(true)
    invalid["pending_morning_summary"]["crops_withered"] = -1
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "crops_withered is out of range",
    )

    invalid = valid.duplicate(true)
    invalid["pending_morning_summary"]["crops_withered"] = WorldContract.farm_cells().size() + 1
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "crops_withered is out of range",
    )

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

func test_state_error_accepts_large_persisted_values() -> void:
    var large := GameSession.new().state()
    large["money"] = 9223372036854775807
    large["shipped"]["turnip"] = 1000000000
    large["relationships"]["resident"]["points"] = 1000000000
    assert_eq(SessionStateValidator.state_error(large), "")
    assert_true(GameSession.new().restore_state(large))

func test_state_error_tolerates_unknown_top_level_fields() -> void:
    var extra := GameSession.new().state()
    extra["unexpected_field"] = 1
    assert_eq(SessionStateValidator.state_error(extra), "")
    assert_true(GameSession.new().restore_state(extra))

func test_state_error_reports_missing_fields_despite_unknown_fields() -> void:
    var drifted := GameSession.new().state()
    drifted.erase("day")
    drifted["unexpected_field"] = 1
    assert_eq(SessionStateValidator.state_error(drifted), "day is missing")

    drifted = GameSession.new().state()
    drifted.erase("finale_triggered")
    drifted["unexpected_field"] = 1
    assert_eq(SessionStateValidator.state_error(drifted), "finale_triggered is missing")

func test_state_error_requires_non_negative_shipping_income() -> void:
    var invalid := _session_with_morning_summary().state()
    invalid["pending_morning_summary"]["shipping_income"] = -1
    assert_eq(
        SessionStateValidator.state_error(invalid),
        "shipping_income must be non-negative",
    )

func test_restored_state_remains_valid_after_pending_shipment_payout() -> void:
    var restored := GameSession.new().state()
    restored["money"] = 999999999
    restored["pending_shipment"][&"turnip"] = 1
    assert_eq(SessionStateValidator.state_error(restored), "")

    var session := GameSession.new(func() -> float: return 0.9)
    assert_true(session.restore_state(restored))
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var after := session.state()
    assert_eq(int(after["money"]), 1000000034)
    assert_eq(SessionStateValidator.state_error(after), "")

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
