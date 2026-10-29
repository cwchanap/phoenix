extends GutTest

func _state_with_pending_summary() -> Dictionary:
    var session := GameSession.new(func() -> float: return 0.9)
    var cell := WorldContract.farm_cells()[0]
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    return session.state()

func test_codec_round_trip_restores_canonical_state() -> void:
    assert_eq(SaveFileCodec.SCHEMA_VERSION, 4)
    var original := _state_with_pending_summary()
    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(original))
    assert_true(decoded["ok"])
    assert_eq(SessionStateValidator.state_error(decoded["state"]), "")
    assert_true(decoded["state"]["farm"][0]["cell"] is Vector2i)

    # Raw decoded JSON keeps ordinary identifiers as String/untyped containers.
    assert_true(decoded["state"]["weather"] is String)
    assert_true(decoded["state"]["seeds"].keys()[0] is String)
    assert_true(decoded["state"]["farm"] is Array)

    # GameSession is the canonicalizer back to runtime state.
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(decoded["state"]))
    assert_eq(restored.state(), original)
    assert_true(restored.state()["weather"] is StringName)
    assert_eq(restored.state()["weather_history"], [&"sunny", &"sunny"])
    assert_true(restored.state()["weather_history"][0] is StringName)
    assert_true(restored.state()["seeds"].keys()[0] is StringName)

func test_codec_round_trip_preserves_dry_streak_and_wither_summary() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    var cells := WorldContract.farm_cells()
    assert_eq(session.hoe(cells[0]), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cells[0]), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(session.acknowledge_morning_summary(), GameRules.CommandCode.DAY_STARTED)

    # Plant a second crop after the first missed night so only the older crop withers.
    assert_eq(session.hoe(cells[1]), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cells[1]), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)

    var original := session.state()
    assert_null(original["farm"][0]["crop"])
    assert_eq(original["farm"][1]["crop"].get("dry_nights", -1), 1)
    assert_eq(original["pending_morning_summary"].get("crops_withered", -1), 1)

    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(original))
    assert_true(decoded["ok"])
    assert_eq(SessionStateValidator.state_error(decoded["state"]), "")
    assert_eq(decoded["state"]["farm"][1]["crop"].get("dry_nights", -1), 1)
    assert_eq(decoded["state"]["pending_morning_summary"].get("crops_withered", -1), 1)

    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(decoded["state"]))
    assert_eq(restored.state(), original)

func test_round_trip_preserves_a_change_outside_the_old_farm_footprint() -> void:
    var session := GameSession.new(func() -> float: return 0.9)
    # Deep inside the expanded patch: well outside the old 3x3 footprint.
    var cell := WorldContract.FARM_PATCH.position + Vector2i(4, 3)
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)

    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(session.state()))
    assert_true(decoded["ok"])
    assert_eq(SessionStateValidator.state_error(decoded["state"]), "")
    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(decoded["state"]))
    # CROP_PRESENT proves the decoded save carried the tilled, planted cell.
    assert_eq(restored.plant(cell), GameRules.CommandCode.CROP_PRESENT)

func test_decode_rejects_malformed_json_wrong_schema_and_bad_vector_marker() -> void:
    assert_false(SaveFileCodec.decode("{broken")["ok"])
    assert_false(SaveFileCodec.decode('{"state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":"1","state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":true,"state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":1.5,"state":{}}')["ok"])
    var schema_three := SaveFileCodec.decode(JSON.stringify({
        "schema_version": 3,
        "state": GameSession.new().state(),
    }))
    assert_false(schema_three["ok"])
    assert_eq(schema_three.get("error", ""), "Unsupported save schema")
    var legacy := SaveFileCodec.decode(JSON.stringify({
        "schema_version": SaveFileCodec.SCHEMA_VERSION - 1,
        "state": {},
    }))
    assert_false(legacy["ok"])
    assert_eq(legacy["error"], "Unsupported save schema")
    var future := SaveFileCodec.decode(JSON.stringify({
        "schema_version": SaveFileCodec.SCHEMA_VERSION + 1,
        "state": {},
    }))
    assert_false(future["ok"])
    assert_eq(future["error"], "Unsupported save schema")

    var non_object_state := SaveFileCodec.decode(JSON.stringify({
        "schema_version": SaveFileCodec.SCHEMA_VERSION,
        "state": 5,
    }))
    assert_false(non_object_state["ok"])
    assert_eq(non_object_state["error"], "Save state must be an object")
    var bad_vector := SaveFileCodec.decode(JSON.stringify({
        "schema_version": SaveFileCodec.SCHEMA_VERSION,
        "state": {"__phoenix_type": "Vector2i", "x": 1},
    }))
    assert_false(bad_vector["ok"])
    assert_eq(bad_vector["error"], "Vector2i marker must contain exactly x and y")
    var unknown_marker := SaveFileCodec.decode(JSON.stringify({
        "schema_version": SaveFileCodec.SCHEMA_VERSION,
        "state": {"__phoenix_type": "Unknown", "x": 1, "y": 2},
    }))
    assert_false(unknown_marker["ok"])
    assert_eq(unknown_marker["error"], "Unknown save type marker")
    var nested_unknown_marker := SaveFileCodec.decode(JSON.stringify({
        "schema_version": SaveFileCodec.SCHEMA_VERSION,
        "state": {"nested": {"__phoenix_type": "Unknown"}},
    }))
    assert_false(nested_unknown_marker["ok"])
    assert_eq(nested_unknown_marker["error"], "Unknown save type marker")

func test_decoded_state_is_deeply_isolated_from_original() -> void:
    var original := _state_with_pending_summary()
    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(original))
    assert_true(decoded["ok"])

    decoded["state"]["seeds"]["turnip"] = 99
    decoded["state"]["farm"][0]["tilled"] = false
    decoded["state"]["farm"][0]["crop"]["growth"] = 99
    decoded["state"]["relationships"]["resident"]["points"] = 99
    decoded["state"]["weather_history"][0] = "rainy"

    assert_eq(original["seeds"][&"turnip"], 2)
    assert_true(original["farm"][0]["tilled"])
    assert_eq(original["farm"][0]["crop"]["growth"], 1)
    assert_eq(original["relationships"][&"resident"]["points"], 0)
    assert_eq(original["weather_history"], [&"sunny", &"sunny"])
