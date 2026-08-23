extends GutTest

func test_starter_and_day_constants_are_exact() -> void:
    assert_eq(GameRules.DAY_START_MINUTES, 360)
    assert_eq(GameRules.ACTION_CUTOFF_MINUTES, 1320)
    assert_eq(GameRules.MAX_STAMINA, 20)
    assert_eq(GameRules.MAX_DAY, 14)
    assert_eq(GameRules.RAIN_CHANCE, 0.25)
    assert_eq(GameRules.STARTING_MONEY, 150)
    assert_eq(GameRules.starting_seed_counts(), [3, 0, 0])

func test_crop_table_is_closed_and_exact() -> void:
    assert_eq(GameRules.CROP_KEYS.size(), GameRules.CropKind.size())
    assert_eq(GameRules.CROP_DISPLAY_NAMES.size(), GameRules.CropKind.size())
    assert_eq(GameRules.GROWTH_NIGHTS.size(), GameRules.CropKind.size())
    assert_eq(GameRules.SEED_PRICES.size(), GameRules.CropKind.size())
    assert_eq(GameRules.SALE_VALUES.size(), GameRules.CropKind.size())

    assert_eq(GameRules.crop_key(GameRules.CropKind.TURNIP), &"turnip")
    assert_eq(GameRules.crop_display_name(GameRules.CropKind.TURNIP), "Turnip")
    assert_eq(GameRules.growth_nights(GameRules.CropKind.TURNIP), 3)
    assert_eq(GameRules.seed_price(GameRules.CropKind.TURNIP), 20)
    assert_eq(GameRules.sale_value(GameRules.CropKind.TURNIP), 35)

    assert_eq(GameRules.crop_key(GameRules.CropKind.POTATO), &"potato")
    assert_eq(GameRules.crop_display_name(GameRules.CropKind.POTATO), "Potato")
    assert_eq(GameRules.growth_nights(GameRules.CropKind.POTATO), 5)
    assert_eq(GameRules.seed_price(GameRules.CropKind.POTATO), 40)
    assert_eq(GameRules.sale_value(GameRules.CropKind.POTATO), 75)

    assert_eq(GameRules.crop_key(GameRules.CropKind.PUMPKIN), &"pumpkin")
    assert_eq(GameRules.crop_display_name(GameRules.CropKind.PUMPKIN), "Pumpkin")
    assert_eq(GameRules.growth_nights(GameRules.CropKind.PUMPKIN), 7)
    assert_eq(GameRules.seed_price(GameRules.CropKind.PUMPKIN), 70)
    assert_eq(GameRules.sale_value(GameRules.CropKind.PUMPKIN), 140)

func test_maturity_boundaries_are_exact() -> void:
    var cases: Array = [
        [GameRules.CropKind.TURNIP, 3],
        [GameRules.CropKind.POTATO, 5],
        [GameRules.CropKind.PUMPKIN, 7],
    ]
    for case_data in cases:
        var kind: int = case_data[0]
        var mature_progress: int = case_data[1]
        assert_false(GameRules.is_mature(kind, mature_progress - 1))
        assert_true(GameRules.is_mature(kind, mature_progress))

func test_visual_stage_boundaries_are_exact() -> void:
    var cases: Array = [
        [GameRules.CropKind.TURNIP, [0, 1, 2, 3]],
        [GameRules.CropKind.POTATO, [0, 0, 1, 1, 2, 3]],
        [GameRules.CropKind.PUMPKIN, [0, 0, 0, 1, 1, 2, 2, 3]],
    ]
    for case_data in cases:
        var kind: int = case_data[0]
        var expected: Array = case_data[1]
        for progress in range(expected.size()):
            assert_eq(GameRules.visual_stage(kind, progress), expected[progress])

func test_action_costs_are_exact() -> void:
    assert_eq(
        GameRules.action_cost(GameRules.FarmingAction.HOE),
        {"minutes": 30, "stamina": 3},
    )
    assert_eq(
        GameRules.action_cost(GameRules.FarmingAction.SEEDS),
        {"minutes": 20, "stamina": 1},
    )
    assert_eq(
        GameRules.action_cost(GameRules.FarmingAction.WATERING_CAN),
        {"minutes": 20, "stamina": 2},
    )
    assert_eq(
        GameRules.action_cost(GameRules.FarmingAction.HANDS),
        {"minutes": 20, "stamina": 1},
    )

func test_action_budget_accepts_exact_2200_boundary() -> void:
    assert_eq(
        GameRules.evaluate_action_budget(1290, 3, GameRules.FarmingAction.HOE),
        {"ok": true, "time_minutes": 1320, "stamina": 0},
    )

func test_action_budget_checks_time_before_stamina() -> void:
    assert_eq(
        GameRules.evaluate_action_budget(1310, 0, GameRules.FarmingAction.HOE),
        {"ok": false, "code": GameRules.CommandCode.ACTION_TOO_LATE},
    )
    assert_eq(
        GameRules.evaluate_action_budget(1290, 2, GameRules.FarmingAction.HOE),
        {"ok": false, "code": GameRules.CommandCode.INSUFFICIENT_STAMINA},
    )

func test_shipment_payout_is_itemized_in_crop_order() -> void:
    assert_eq(
        GameRules.shipment_payout({&"turnip": 2, &"potato": 1, &"pumpkin": 1}),
        {
            "lines": [
                {"crop": &"turnip", "quantity": 2, "amount": 70},
                {"crop": &"potato", "quantity": 1, "amount": 75},
                {"crop": &"pumpkin", "quantity": 1, "amount": 140},
            ],
            "total": 285,
        },
    )

func test_weather_threshold_is_exact() -> void:
    assert_eq(GameRules.weather_from_roll(0.249999), GameRules.Weather.RAINY)
    assert_eq(GameRules.weather_from_roll(0.25), GameRules.Weather.SUNNY)

func test_weather_roll_below_zero_asserts() -> void:
    GameRules.weather_from_roll(-0.001)
    assert_engine_error_count(1)

func test_weather_roll_at_one_asserts() -> void:
    GameRules.weather_from_roll(1.0)
    assert_engine_error_count(1)

func test_format_time_is_zero_padded() -> void:
    assert_eq(GameRules.format_time(0), "00:00")
    assert_eq(GameRules.format_time(360), "06:00")
    assert_eq(GameRules.format_time(1320), "22:00")
