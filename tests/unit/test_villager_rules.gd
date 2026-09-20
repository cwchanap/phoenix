extends GutTest

const EXPECTED_NORMAL_DIALOGUE: Array = [
    [
        [
            "The seed counter is open whenever you need it.",
            "Turnips are quick. Potatoes ask for a little more patience.",
            "Buy only the seeds you have time to water.",
        ],
        [
            "Your fields are starting to look dependable.",
            "You are planning your seed money better now.",
            "A mixed crop shelf keeps the counter interesting.",
        ],
        [
            "You have made this little farm part of the village.",
            "You know what your fields can afford now.",
            "I save the better seed lots when I know you will stop by.",
        ],
    ],
    [
        [
            "Watered soil tells you what tomorrow will bring.",
            "A straight row is nice, but a watered row is useful.",
            "Do the work you can finish before dusk.",
        ],
        [
            "Your rows are getting cleaner every day.",
            "You move through the field with less wasted effort now.",
            "A few well-kept plots beat a field you cannot tend.",
        ],
        [
            "I would trust you with a field of my own.",
            "You have learned when to push and when to leave the soil alone.",
            "Your farm has your rhythm in it now.",
        ],
    ],
    [
        [
            "It is quieter here than the road makes it look.",
            "The village notices steady footsteps more than grand entrances.",
            "You will learn which corners feel familiar before long.",
        ],
        [
            "I keep seeing you around. I like that.",
            "It is nice seeing your farm light up another part of the road.",
            "People say your farm now, not the old farm.",
        ],
        [
            "The village feels more like home with you here.",
            "You do not look like a newcomer when you walk through town anymore.",
            "Some places become home one ordinary day at a time.",
        ],
    ],
]
const EXPECTED_HPA_595_SLOT_ZERO: Array = [
    [
        "The seed counter is open whenever you need it.",
        "Your fields are starting to look dependable.",
        "You have made this little farm part of the village.",
    ],
    [
        "Watered soil tells you what tomorrow will bring.",
        "Your rows are getting cleaner every day.",
        "I would trust you with a field of my own.",
    ],
    [
        "It is quieter here than the road makes it look.",
        "I keep seeing you around. I like that.",
        "The village feels more like home with you here.",
    ],
]
const EXPECTED_RAINY_DIALOGUE: Array = [
    "Rain saves you a watering round. Good day to plan the next planting.",
    "Let the rain do its share. Save your strength for the rest.",
    "Rain pulls the village closer. Everyone listens to the same roofs.",
]
const EXPECTED_SHIPPED_DIALOGUE: Array = [
    "Produce has left your farm now. Growing and selling are different skills.",
    "You have sent real harvest out now. That means the farm is working.",
    "Your produce is going out now. The farm touches more than your own day.",
]
const EXPECTED_MARKET_DIALOGUE: Array = [
    "The market is close. Keep some coin ready for what comes next.",
    "The market is close. Finish what will be ready before you plant more.",
    "The market is almost here. You will see who noticed your season.",
]

func test_identity_favourites_and_policy_are_exact() -> void:
    assert_eq(VillagerRules.VillagerId.size(), 3)
    for table in [
        VillagerRules.VILLAGER_KEYS,
        VillagerRules.DISPLAY_NAMES,
        VillagerRules.ROLE_LABELS,
        VillagerRules.FAVOURITE_CROPS,
        VillagerRules.NORMAL_DIALOGUE,
        VillagerRules.CLOSE_FRIEND_DIALOGUE,
        VillagerRules.NORMAL_GIFT_LINES,
        VillagerRules.FAVOURITE_GIFT_LINES,
    ]:
        assert_eq(table.size(), VillagerRules.VillagerId.size())

    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.SHOPKEEPER), "Mira")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.SHOPKEEPER), GameRules.CropKind.POTATO)
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.FARMER), "Rowan")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.FARMER), GameRules.CropKind.PUMPKIN)
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.RESIDENT), "June")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.RESIDENT), GameRules.CropKind.TURNIP)

    assert_eq(VillagerRules.TALK_POINTS, 1)
    assert_eq(VillagerRules.GIFT_POINTS, 3)
    assert_eq(VillagerRules.FAVOURITE_GIFT_BONUS, 2)
    assert_eq(VillagerRules.relationship_level(11), VillagerRules.RelationshipLevel.STRANGER)
    assert_eq(VillagerRules.relationship_level(12), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(17), VillagerRules.RelationshipLevel.FRIEND)
    assert_eq(VillagerRules.relationship_level(18), VillagerRules.RelationshipLevel.CLOSE_FRIEND)

func test_normal_dialogue_table_shape_and_content_are_exact() -> void:
    assert_eq(VillagerRules.NORMAL_DIALOGUE, EXPECTED_NORMAL_DIALOGUE)
    for id in range(VillagerRules.VillagerId.size()):
        assert_eq(VillagerRules.NORMAL_DIALOGUE[id].size(), VillagerRules.RelationshipLevel.size())
        for level in range(VillagerRules.RelationshipLevel.size()):
            assert_eq(VillagerRules.NORMAL_DIALOGUE[id][level].size(), 3)

func test_existing_hpa_595_lines_stay_in_slot_zero() -> void:
    for id in range(VillagerRules.VillagerId.size()):
        for level in range(VillagerRules.RelationshipLevel.size()):
            assert_eq(
                VillagerRules.NORMAL_DIALOGUE[id][level][0],
                EXPECTED_HPA_595_SLOT_ZERO[id][level],
            )

func test_contextual_tables_and_market_start_are_exact() -> void:
    assert_eq(VillagerRules.MARKET_DIALOGUE_START_DAY, 12)
    assert_eq(VillagerRules.RAINY_DIALOGUE, EXPECTED_RAINY_DIALOGUE)
    assert_eq(VillagerRules.SHIPPED_DIALOGUE, EXPECTED_SHIPPED_DIALOGUE)
    assert_eq(VillagerRules.MARKET_DIALOGUE, EXPECTED_MARKET_DIALOGUE)

func test_gift_close_friend_and_finale_content_is_unchanged() -> void:
    var expected := [
        {
            "id": VillagerRules.VillagerId.SHOPKEEPER,
            "special": [
                "You kept showing up, even on the slow days.",
                "The harvest market will feel different with you there.",
            ],
            "normal_gift": "A useful harvest. Thank you.",
            "favourite_gift": "Potatoes? You remembered.",
        },
        {
            "id": VillagerRules.VillagerId.FARMER,
            "special": [
                "I noticed when the farm stopped looking neglected.",
                "You earned that change one ordinary day at a time.",
            ],
            "normal_gift": "Good produce. I can use this.",
            "favourite_gift": "A pumpkin this good is hard to ignore.",
        },
        {
            "id": VillagerRules.VillagerId.RESIDENT,
            "special": [
                "You came here as the new farmer, but that is not how I think of you now.",
                "You are one of us.",
            ],
            "normal_gift": "That is kind of you.",
            "favourite_gift": "Turnips are my favourite. Perfect choice.",
        },
    ]

    for entry in expected:
        var villager: int = entry["id"]
        var special: Array[String] = VillagerRules.close_friend_dialogue_lines(villager)
        assert_eq(special, entry["special"])
        special[0] = "Mutated line"
        assert_eq(VillagerRules.close_friend_dialogue_lines(villager), entry["special"])

        var favourite := VillagerRules.favourite_crop(villager)
        var normal := (favourite + 1) % GameRules.CropKind.size()
        assert_eq(VillagerRules.gift_line(villager, normal), entry["normal_gift"])
        assert_eq(VillagerRules.gift_line(villager, favourite), entry["favourite_gift"])

func test_finale_lines_cover_every_villager_and_relationship() -> void:
    var seen_lines: Dictionary = {}
    for id in range(VillagerRules.VillagerId.size()):
        assert_eq(VillagerRules.FINALE_LINES[id].size(), VillagerRules.RelationshipLevel.size())
        for level in range(VillagerRules.RelationshipLevel.size()):
            var line: String = VillagerRules.finale_line(id, level)
            assert_ne(line, "")
            assert_eq(line, VillagerRules.FINALE_LINES[id][level])
            assert_false(seen_lines.has(line), "duplicate finale line %s" % line)
            seen_lines[line] = true
    assert_eq(seen_lines.size(), VillagerRules.VillagerId.size() * VillagerRules.RelationshipLevel.size())

func test_favourite_villager_lookup_is_inverse() -> void:
    assert_eq(
        VillagerRules.favourite_villager_for_crop(GameRules.CropKind.TURNIP),
        VillagerRules.VillagerId.RESIDENT,
    )
    assert_eq(
        VillagerRules.favourite_villager_for_crop(GameRules.CropKind.POTATO),
        VillagerRules.VillagerId.SHOPKEEPER,
    )
    assert_eq(
        VillagerRules.favourite_villager_for_crop(GameRules.CropKind.PUMPKIN),
        VillagerRules.VillagerId.FARMER,
    )

func test_candidates_order_is_normals_then_rainy_shipped_market() -> void:
    var stranger := VillagerRules.RelationshipLevel.STRANGER
    var id := VillagerRules.VillagerId.SHOPKEEPER
    var normals: Array = EXPECTED_NORMAL_DIALOGUE[id][stranger]

    assert_eq(
        VillagerRules.ordinary_dialogue_candidates(id, stranger, 1, false, false),
        normals,
    )
    assert_eq(
        VillagerRules.ordinary_dialogue_candidates(id, stranger, 1, true, false),
        normals + [EXPECTED_RAINY_DIALOGUE[id]],
    )
    assert_eq(
        VillagerRules.ordinary_dialogue_candidates(id, stranger, 1, false, true),
        normals + [EXPECTED_SHIPPED_DIALOGUE[id]],
    )
    assert_eq(
        VillagerRules.ordinary_dialogue_candidates(id, stranger, 12, true, true),
        normals + [
            EXPECTED_RAINY_DIALOGUE[id],
            EXPECTED_SHIPPED_DIALOGUE[id],
            EXPECTED_MARKET_DIALOGUE[id],
        ],
    )

func test_market_gate_is_day_twelve_through_fourteen() -> void:
    var stranger := VillagerRules.RelationshipLevel.STRANGER
    var id := VillagerRules.VillagerId.SHOPKEEPER
    assert_eq(
        VillagerRules.ordinary_dialogue_candidates(id, stranger, 11, true, true).size(),
        5,
    )
    for day in [12, 14]:
        var candidates := VillagerRules.ordinary_dialogue_candidates(id, stranger, day, true, true)
        assert_eq(candidates.size(), 6)
        assert_eq(candidates[5], EXPECTED_MARKET_DIALOGUE[id])

func test_identical_inputs_select_a_stable_line() -> void:
    for id in range(VillagerRules.VillagerId.size()):
        for level in range(VillagerRules.RelationshipLevel.size()):
            for day in [1, 7, 12, 14]:
                for context in [[false, false], [true, false], [false, true], [true, true]]:
                    var first := VillagerRules.ordinary_dialogue_line(
                        id, level, day, context[0], context[1]
                    )
                    var second := VillagerRules.ordinary_dialogue_line(
                        id, level, day, context[0], context[1]
                    )
                    assert_eq(first, second)

func test_line_matches_documented_posmod_index() -> void:
    for id in range(VillagerRules.VillagerId.size()):
        for day in [1, 2, 11, 12, 13, 14]:
            var candidates := VillagerRules.ordinary_dialogue_candidates(
                id, VillagerRules.RelationshipLevel.STRANGER, day, true, true
            )
            assert_eq(
                VillagerRules.ordinary_dialogue_line(
                    id, VillagerRules.RelationshipLevel.STRANGER, day, true, true
                ),
                candidates[posmod((day - 1) + id, candidates.size())],
            )

func test_day_and_villager_identity_rotate_the_pool() -> void:
    var stranger := VillagerRules.RelationshipLevel.STRANGER
    assert_eq(
        VillagerRules.ordinary_dialogue_line(VillagerRules.VillagerId.SHOPKEEPER, stranger, 1, false, false),
        EXPECTED_NORMAL_DIALOGUE[0][stranger][0],
    )
    assert_eq(
        VillagerRules.ordinary_dialogue_line(VillagerRules.VillagerId.FARMER, stranger, 1, false, false),
        EXPECTED_NORMAL_DIALOGUE[1][stranger][1],
    )
    assert_eq(
        VillagerRules.ordinary_dialogue_line(VillagerRules.VillagerId.RESIDENT, stranger, 1, false, false),
        EXPECTED_NORMAL_DIALOGUE[2][stranger][2],
    )
    assert_eq(
        VillagerRules.ordinary_dialogue_line(VillagerRules.VillagerId.SHOPKEEPER, stranger, 2, false, false),
        EXPECTED_NORMAL_DIALOGUE[0][stranger][1],
    )
