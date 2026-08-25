extends GutTest

func _state_with_pending_summary() -> Dictionary:
    var session := GameSession.new(func() -> float: return 0.9)
    var cell := Vector2i(2, 7)
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    return session.state()

func test_codec_round_trip_restores_canonical_state() -> void:
    var original := _state_with_pending_summary()
    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(original))
    assert_true(decoded["ok"])
    assert_eq(GameSession.state_error(decoded["state"]), "")
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
    assert_true(restored.state()["seeds"].keys()[0] is StringName)

func test_decode_rejects_malformed_json_wrong_schema_and_bad_vector_marker() -> void:
    assert_false(SaveFileCodec.decode("{broken")["ok"])
    assert_false(SaveFileCodec.decode('{"state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":"1","state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":true,"state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":1.5,"state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":2,"state":{}}')["ok"])
    assert_false(SaveFileCodec.decode('{"schema_version":1,"state":5}')["ok"])
    assert_false(SaveFileCodec.decode(
        '{"schema_version":1,"state":{"__phoenix_type":"Vector2i","x":1}}'
    )["ok"])
    assert_false(SaveFileCodec.decode(
        '{"schema_version":1,"state":{"__phoenix_type":"Unknown","x":1,"y":2}}'
    )["ok"])
    assert_false(SaveFileCodec.decode(
        '{"schema_version":1,"state":{"nested":{"__phoenix_type":"Unknown"}}}'
    )["ok"])

func test_decoded_state_is_deeply_isolated_from_original() -> void:
    var original := _state_with_pending_summary()
    var decoded := SaveFileCodec.decode(SaveFileCodec.encode(original))
    assert_true(decoded["ok"])

    decoded["state"]["seeds"]["turnip"] = 99
    decoded["state"]["farm"][0]["tilled"] = false
    decoded["state"]["farm"][0]["crop"]["growth"] = 99
    decoded["state"]["relationships"]["resident"]["points"] = 99

    assert_eq(original["seeds"][&"turnip"], 2)
    assert_true(original["farm"][0]["tilled"])
    assert_eq(original["farm"][0]["crop"]["growth"], 1)
    assert_eq(original["relationships"][&"resident"]["points"], 0)
