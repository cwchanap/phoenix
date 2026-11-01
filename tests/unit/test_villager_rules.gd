extends GutTest

const EXPECTED_NORMAL_DIALOGUE: Array = [
    [
        [
            "Seeds on the left, prices on the tags. I do not haggle.",
            "Turnips are quick. Potatoes want patience. Pumpkins want faith.",
            "Buy only what you can water. The field will not wait for you.",
        ],
        [
            "You stopped asking which seeds are best. Now you ask which are right.",
            "Your tab is in my ledger. Paper never crashes, you know.",
            "A mixed shelf keeps the counter interesting. So do you.",
        ],
        [
            "I set the good seed lots aside for you now. Do not tell Gen-san.",
            "You know what that field can afford. Most people take years.",
            "The shop feels busier on the days your truck is outside.",
        ],
    ],
    [
        [
            "City hands. You will learn, or the field will teach you.",
            "Water first, plan later. Soil does not read spreadsheets.",
            "Do the work you can finish before dark. Then go to bed.",
        ],
        [
            "Your rows are straighter. Not straight. Straighter.",
            "You waste fewer steps now. The field notices that.",
            "A few good plots beat a big field you cannot keep.",
        ],
        [
            "I would trust you with my own field. Do not make me regret it.",
            "You learned when to push and when to leave the soil alone.",
            "That old field has your rhythm in it now.",
        ],
    ],
    [
        [
            "Coffee is strong here and the trains are slow. You get used to both.",
            "Out at the old field? It is so quiet there you can hear the river.",
            "I left Tokyo too. I never ask why people come out here.",
        ],
        [
            "Your usual seat was free. I kept it that way, a little.",
            "You look less like you are waiting for a phone to buzz.",
            "People in town say your farm now, not the old field.",
        ],
        [
            "Town feels more like home with you around.",
            "Whatever you left behind, you do not carry it in here anymore.",
            "Some places become home one ordinary day at a time.",
        ],
    ],
]
const EXPECTED_RAINY_DIALOGUE: Array = [
    "Rain day. Let the sky water and come plan your next planting.",
    "Let the rain do its share. Save your back for tomorrow.",
    "Rainy days fill every seat in here. Everyone listens to the same roof.",
]
const EXPECTED_SHIPPED_DIALOGUE: Array = [
    "Your produce has gone out. Growing and selling are different skills.",
    "You sold real harvest. Now that field is a farm.",
    "I heard your produce made it into town. That is how people learn a name.",
]
const EXPECTED_MARKET_DIALOGUE: Array = [
    "The market is close. Keep some coin ready for what comes next.",
    "Market soon. Finish what will be ready before you plant more.",
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

    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.SHOPKEEPER), "Sato-san")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.SHOPKEEPER), GameRules.CropKind.POTATO)
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.FARMER), "Gen-san")
    assert_eq(VillagerRules.favourite_crop(VillagerRules.VillagerId.FARMER), GameRules.CropKind.PUMPKIN)
    assert_eq(VillagerRules.display_name(VillagerRules.VillagerId.RESIDENT), "Hana")
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

func test_contextual_tables_and_market_start_are_exact() -> void:
    assert_eq(VillagerRules.MARKET_DIALOGUE_START_DAY, 12)
    assert_eq(VillagerRules.RAINY_DIALOGUE, EXPECTED_RAINY_DIALOGUE)
    assert_eq(VillagerRules.SHIPPED_DIALOGUE, EXPECTED_SHIPPED_DIALOGUE)
    assert_eq(VillagerRules.MARKET_DIALOGUE, EXPECTED_MARKET_DIALOGUE)

func test_gift_close_friend_and_finale_content_is_exact() -> void:
    var expected := [
        {
            "id": VillagerRules.VillagerId.SHOPKEEPER,
            "special": [
                "You kept driving in, even on the slow days.",
                "The harvest market will feel different with you behind a stall.",
            ],
            "normal_gift": "Good produce. I will note it in the ledger. Thank you.",
            "favourite_gift": "Potatoes? You remembered.",
        },
        {
            "id": VillagerRules.VillagerId.FARMER,
            "special": [
                "I watched that field sit empty for ten years.",
                "You brought it back one ordinary day at a time.",
            ],
            "normal_gift": "Hm. Decent. I can use this.",
            "favourite_gift": "A pumpkin like this is hard to argue with.",
        },
        {
            "id": VillagerRules.VillagerId.RESIDENT,
            "special": [
                "You came here as the Tokyo guy. That is not how I think of you now.",
                "You are one of us.",
            ],
            "normal_gift": "For me? That is kind of you.",
            "favourite_gift": "Turnips! My favourite. Perfect choice.",
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
