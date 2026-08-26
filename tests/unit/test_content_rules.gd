extends GutTest

func test_tutorial_table_is_exact_and_unique() -> void:
    var expected := [
        {"id": &"farm_basics", "code": GameRules.CommandCode.SOIL_TILLED},
        {"id": &"plant", "code": GameRules.CommandCode.CROP_PLANTED},
        {"id": &"water", "code": GameRules.CommandCode.CROP_WATERED},
        {"id": &"sleep", "code": GameRules.CommandCode.DAY_ADVANCED},
        {"id": &"talk", "code": GameRules.CommandCode.VILLAGER_TALKED},
        {"id": &"buy_seeds", "code": GameRules.CommandCode.SEEDS_PURCHASED},
        {"id": &"harvest", "code": GameRules.CommandCode.CROP_HARVESTED},
        {"id": &"shipping", "code": GameRules.CommandCode.CROP_DEPOSITED},
        {"id": &"gift", "code": GameRules.CommandCode.CROP_GIFTED},
    ]

    assert_eq(ContentRules.TUTORIALS.size(), expected.size())
    var seen_ids: Dictionary = {}
    var seen_codes: Dictionary = {}
    for index in expected.size():
        var definition: Dictionary = ContentRules.TUTORIALS[index]
        var id: StringName = definition["id"]
        var code: int = definition["completed_by"]
        assert_eq(id, expected[index]["id"])
        assert_eq(code, expected[index]["code"])
        assert_ne(String(definition["title"]), "")
        assert_ne(String(definition["body"]), "")
        assert_false(seen_ids.has(id), "duplicate tutorial id %s" % id)
        assert_false(seen_codes.has(code), "duplicate tutorial completion code %s" % code)
        seen_ids[id] = true
        seen_codes[code] = true
    assert_eq(seen_ids.size(), expected.size())
    assert_eq(seen_codes.size(), expected.size())

func test_tutorial_helpers_derive_from_the_table() -> void:
    var expected_ids: Array[StringName] = []
    for definition in ContentRules.TUTORIALS:
        expected_ids.append(definition["id"])
        assert_eq(
            ContentRules.tutorial_for_code(definition["completed_by"]),
            definition["id"],
        )

    assert_eq(ContentRules.tutorial_keys(), expected_ids)
    var progress := ContentRules.initial_tutorial_progress()
    assert_eq(progress.size(), expected_ids.size())
    for id in expected_ids:
        assert_true(progress.has(id))
        assert_false(progress[id])
    assert_eq(ContentRules.tutorial_for_code(GameRules.CommandCode.ACTION_SELECTED), &"")

func _fresh_snapshot() -> Dictionary:
    var snapshot := GameSession.new().snapshot()
    snapshot["intro_acknowledged"] = true
    snapshot["tutorial"] = ContentRules.initial_tutorial_progress()
    return snapshot

func _complete(snapshot: Dictionary, ids: Array[StringName]) -> void:
    for id in ids:
        snapshot["tutorial"][id] = true

func _plant_crop(snapshot: Dictionary, growth: int, watered_today: bool) -> void:
    var tile: Dictionary = snapshot["farm"][0]
    tile["tilled"] = true
    tile["crop"] = {
        "kind": &"turnip",
        "growth": growth,
        "watered_today": watered_today,
    }

func test_first_prompt_after_intro_is_farm_basics() -> void:
    var snapshot := _fresh_snapshot()
    var prompt := ContentRules.next_tutorial_prompt(snapshot)
    assert_eq(prompt["id"], &"farm_basics")
    assert_eq(prompt["title"], "Prepare the field")
    assert_ne(String(prompt["body"]), "")

    snapshot["intro_acknowledged"] = false
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

func test_plant_prompt_requires_tilled_empty_soil_and_a_seed() -> void:
    var snapshot := _fresh_snapshot()
    _complete(snapshot, [&"farm_basics"])
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

    var tile: Dictionary = snapshot["farm"][0]
    tile["tilled"] = true
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"plant")

    snapshot["seeds"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

    snapshot["seeds"] = {&"turnip": 1, &"potato": 0, &"pumpkin": 0}
    _plant_crop(snapshot, 0, false)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"water")

func test_water_prompt_requires_sunny_immature_unwatered_crop() -> void:
    var snapshot := _fresh_snapshot()
    _complete(snapshot, [&"farm_basics", &"plant"])
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

    _plant_crop(snapshot, 0, false)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"water")

    _plant_crop(snapshot, 0, true)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"sleep")

    snapshot["weather"] = &"rainy"
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"sleep")

    snapshot["weather"] = &"sunny"
    _plant_crop(snapshot, 3, false)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"harvest")

func test_sleep_prompt_follows_watered_or_rainy_immature_crop() -> void:
    var snapshot := _fresh_snapshot()
    _complete(snapshot, [&"farm_basics", &"plant", &"water"])
    _plant_crop(snapshot, 0, false)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

    _plant_crop(snapshot, 0, true)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"sleep")

    snapshot["weather"] = &"rainy"
    _plant_crop(snapshot, 0, false)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"sleep")

func test_talk_and_buy_seeds_prompts_are_day_two_plus() -> void:
    var snapshot := _fresh_snapshot()
    _complete(snapshot, [&"farm_basics", &"plant", &"water", &"sleep"])
    snapshot["day"] = 1
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

    snapshot["day"] = 2
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"talk")

    _complete(snapshot, [&"talk"])
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"buy_seeds")

    snapshot["money"] = GameRules.seed_price(GameRules.CropKind.TURNIP) - 1
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

    snapshot["money"] = GameRules.seed_price(GameRules.CropKind.TURNIP)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"buy_seeds")

func test_harvest_prompt_requires_a_mature_crop() -> void:
    var snapshot := _fresh_snapshot()
    _complete(snapshot, [
        &"farm_basics",
        &"plant",
        &"water",
        &"sleep",
        &"talk",
        &"buy_seeds",
    ])
    _plant_crop(snapshot, 2, false)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

    _plant_crop(snapshot, 3, false)
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"harvest")

func test_shipping_and_gift_prompts_require_harvested_inventory() -> void:
    var snapshot := _fresh_snapshot()
    _complete(snapshot, [
        &"farm_basics",
        &"plant",
        &"water",
        &"sleep",
        &"talk",
        &"buy_seeds",
        &"harvest",
    ])
    snapshot["harvested"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

    snapshot["harvested"] = {&"turnip": 1, &"potato": 0, &"pumpkin": 0}
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"shipping")

    _complete(snapshot, [&"shipping"])
    assert_eq(ContentRules.next_tutorial_prompt(snapshot)["id"], &"gift")

func test_excluded_ids_are_skipped_without_mutating_completion() -> void:
    var snapshot := _fresh_snapshot()
    _complete(snapshot, [&"farm_basics", &"plant", &"water", &"sleep"])
    snapshot["day"] = 2
    var progress_before: Dictionary = snapshot["tutorial"].duplicate(true)

    var prompt := ContentRules.next_tutorial_prompt(snapshot, [&"talk"])
    assert_ne(prompt.get("id", &""), &"talk")
    assert_eq(prompt.get("id", &""), &"buy_seeds")
    assert_eq(snapshot["tutorial"], progress_before)
    assert_false(snapshot["tutorial"][&"talk"])

func test_no_relevant_incomplete_prompt_returns_empty() -> void:
    var snapshot := _fresh_snapshot()
    _complete(snapshot, ContentRules.tutorial_keys())
    assert_eq(ContentRules.next_tutorial_prompt(snapshot), {})

func _counts(values: Array) -> Dictionary:
    return {
        &"turnip": values[0],
        &"potato": values[1],
        &"pumpkin": values[2],
    }

func _result_for(
    shipped: Array,
    points: Array,
    harvested: Array = [0, 0, 0],
) -> Dictionary:
    return ContentRules.build_harvest_result({
        "shipped": _counts(shipped),
        "harvested": _counts(harvested),
        "money": 150,
        "relationships": {
            &"shopkeeper": {"points": points[0]},
            &"farmer": {"points": points[1]},
            &"resident": {"points": points[2]},
        },
    })

func test_harvest_result_tier_boundaries() -> void:
    # 2 potatoes = 150G -> Promising
    assert_eq(_result_for([0, 2, 0], [0, 0, 0])["tier"], &"promising_farmer")

    # 4 potatoes = 300G but no Close Friend -> still Promising
    assert_eq(_result_for([0, 4, 0], [0, 0, 0])["tier"], &"promising_farmer")

    # 300G + Close Friend -> Heart
    assert_eq(
        _result_for([0, 4, 0], [0, 0, VillagerRules.CLOSE_FRIEND_POINTS])["tier"],
        &"heart_of_harvest",
    )

    # Friend alone -> Promising
    assert_eq(
        _result_for([0, 0, 0], [VillagerRules.FRIEND_POINTS, 0, 0])["tier"],
        &"promising_farmer",
    )

    # Below both boundaries -> New Beginning
    assert_eq(_result_for([0, 1, 0], [0, 0, 0])["tier"], &"new_beginning")

func test_harvest_result_totals_derive_from_sale_value_and_ignore_harvested() -> void:
    var result := _result_for([1, 2, 0], [0, 0, 0])
    assert_eq(result["shipped_count"], 3)
    assert_eq(
        result["shipped_value"],
        GameRules.sale_value(GameRules.CropKind.TURNIP)
            + 2 * GameRules.sale_value(GameRules.CropKind.POTATO),
    )
    assert_eq(result["final_money"], 150)

    # Carried harvested inventory is not scoring state.
    assert_eq(
        _result_for([0, 2, 0], [0, 0, 0]),
        _result_for([0, 2, 0], [0, 0, 0], [5, 5, 5]),
    )

func test_harvest_result_titles_and_featured_finale_line() -> void:
    assert_eq(_result_for([0, 0, 0], [0, 0, 0])["title"], "New Beginning")
    assert_eq(_result_for([0, 2, 0], [0, 0, 0])["title"], "Promising Farmer")
    assert_eq(
        _result_for([0, 4, 0], [0, 0, VillagerRules.CLOSE_FRIEND_POINTS])["title"],
        "Heart of the Harvest",
    )

    # The strongest relationship picks the one featured villager and line.
    var result := _result_for([0, 0, 0], [0, 0, VillagerRules.CLOSE_FRIEND_POINTS])
    assert_eq(result["villager"], "June")
    assert_eq(
        result["line"],
        VillagerRules.finale_line(
            VillagerRules.VillagerId.RESIDENT,
            VillagerRules.RelationshipLevel.CLOSE_FRIEND,
        ),
    )
