extends GutTest

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

func test_spoken_content_is_verbatim_hpa_595_oracle() -> void:
    var expected := [
        {
            "id": VillagerRules.VillagerId.SHOPKEEPER,
            "dialogue": [
                "The seed counter is open whenever you need it.",
                "Your fields are starting to look dependable.",
                "You have made this little farm part of the village.",
            ],
            "special": [
                "You kept showing up, even on the slow days.",
                "The harvest market will feel different with you there.",
            ],
            "normal_gift": "A useful harvest. Thank you.",
            "favourite_gift": "Potatoes? You remembered.",
        },
        {
            "id": VillagerRules.VillagerId.FARMER,
            "dialogue": [
                "Watered soil tells you what tomorrow will bring.",
                "Your rows are getting cleaner every day.",
                "I would trust you with a field of my own.",
            ],
            "special": [
                "I noticed when the farm stopped looking neglected.",
                "You earned that change one ordinary day at a time.",
            ],
            "normal_gift": "Good produce. I can use this.",
            "favourite_gift": "A pumpkin this good is hard to ignore.",
        },
        {
            "id": VillagerRules.VillagerId.RESIDENT,
            "dialogue": [
                "It is quieter here than the road makes it look.",
                "I keep seeing you around. I like that.",
                "The village feels more like home with you here.",
            ],
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
        var dialogue: Array = entry["dialogue"]
        for relationship in range(VillagerRules.RelationshipLevel.size()):
            assert_eq(VillagerRules.dialogue_line(villager, relationship), dialogue[relationship])

        var special: Array[String] = VillagerRules.close_friend_dialogue_lines(villager)
        assert_eq(special, entry["special"])
        special[0] = "Mutated line"
        assert_eq(VillagerRules.close_friend_dialogue_lines(villager), entry["special"])

        var favourite := VillagerRules.favourite_crop(villager)
        var normal := (favourite + 1) % GameRules.CropKind.size()
        assert_eq(VillagerRules.gift_line(villager, normal), entry["normal_gift"])
        assert_eq(VillagerRules.gift_line(villager, favourite), entry["favourite_gift"])
