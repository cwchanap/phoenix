class_name ContentRules
extends RefCounted

enum LineKind { NARRATION, DIALOGUE, INNER_VOICE, NOTE }

const PROMISING_SHIPPED_VALUE := 150
const HEART_SHIPPED_VALUE := 300

const OPENING_SPEAKER := "KENJI"
const OPENING_ROLE := "Former software engineer"

const INNER_VOICE_LABEL := "Inner voice"

## The six prologue scenes. Each scene's "motion" is presentation data for
## PrologueStage (HPA-1250), tuned by eye in 1920x1080 stage space over the
## 1.5x painting: "camera" zooms about a pivot (and optionally pans) as it
## settles; "lights" are [look, centre, radius, optional phase] glows from
## PrologueStage.LIGHT_LOOKS; the other keys place one effect each. A line's
## "cue" fires a stage cue when that line shows.
const PROLOGUE_SCENES: Array[Dictionary] = [
    {
        "tag": "Station · 19:00",
        "background": "res://assets/ui/backgrounds/prologue-platform.png",
        "portrait": -1,
        "night": false,
        "motion": {
            "camera": {"pivot": Vector2(1080, 420), "zoom": Vector2(1.03, 1.12)},
            "lights": [
                [&"halo", Vector2(1122, 318), 280.0],
                [&"flame", Vector2(1122, 312), 60.0],
                [&"spill", Vector2(1122, 600), 260.0],
                [&"window", Vector2(520, 500), 90.0],
                [&"window", Vector2(630, 500), 90.0],
                [&"window", Vector2(740, 500), 90.0],
                [&"window", Vector2(850, 500), 90.0],
                [&"window", Vector2(960, 500), 90.0],
                [&"window", Vector2(1070, 500), 90.0],
                [&"glow", Vector2(1530, 455), 150.0],
                [&"flame", Vector2(1422, 393), 40.0],
                [&"bulb", Vector2(279, 442), 34.0],
                [&"bulb", Vector2(375, 442), 34.0],
            ],
            "moths": Vector2(1122, 312),
            "fireflies": [Rect2(80, 700, 1760, 200), 14],
        },
        "lines": [
            {
                "kind": LineKind.NARRATION,
                "text": "Seven in the evening. The last train eases into a small station. Only one lamp is lit on the platform.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "Left Tokyo. Three transfers, four hours on trains. Then the doors opened on a wall of insect song.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "Three months ago, I was staring at a crashed server at two in the morning.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "While the system rebooted, I checked a lottery ticket. Then again. Then a third time.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "The next day I resigned. My manager asked where I was going next. I said, 'Farming.'",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "After buying the land, I put the rest of the prize money in the bank and planned not to touch a cent. Only a little living money stays in my pocket. This season, I want to see what my own two hands can do.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "Nobody here knows about the lottery. I plan to keep it that way.",
            },
        ],
    },
    {
        "tag": "Station front · 19:05",
        "background": "res://assets/ui/backgrounds/prologue-station.png",
        "portrait": VillagerRules.VillagerId.RESIDENT,
        "night": false,
        "motion": {
            "camera": {
                "pivot": Vector2(1200, 460),
                "zoom": Vector2(1.07, 1.07),
                "pan": [Vector2(44, 0), Vector2(-44, 0)],
            },
            "lights": [
                [&"glow", Vector2(1560, 460), 300.0],
                [&"halo", Vector2(1617, 435), 110.0],
                [&"flame", Vector2(1617, 435), 24.0],
                [&"halo", Vector2(1735, 428), 110.0],
                [&"flame", Vector2(1735, 428), 24.0],
                [&"halo", Vector2(810, 425), 110.0],
                [&"flame", Vector2(810, 425), 24.0],
                [&"halo", Vector2(1038, 425), 110.0],
                [&"flame", Vector2(1038, 425), 24.0],
                [&"glow", Vector2(1205, 450), 120.0],
                [&"neon", Vector2(1340, 495), 70.0],
                [&"signal", Vector2(655, 337), 22.0, 0.0],
                [&"signal", Vector2(655, 362), 22.0, 1.0],
            ],
            "fireflies": [Rect2(560, 600, 1300, 160), 12],
        },
        "lines": [
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.RESIDENT,
                "text": "Hey! You with the suitcase and the just-off-work face.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.RESIDENT,
                "text": "You're the one who bought the Moriyama field, right?",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": -1,
                "text": "...Is it that obvious?",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.RESIDENT,
                "text": "Anyone who gets off at this hour is either going home or lost. You don't look like you're going home.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.RESIDENT,
                "text": "I'm Hana. I run the cafe by the station.",
            },
            {
                "kind": LineKind.NARRATION,
                "text": "She hands over a can of hot coffee from the vending machine.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.RESIDENT,
                "text": "This one's a welcome gift. Real coffee costs money, though. I open tomorrow morning.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.RESIDENT,
                "text": "Gen-san's been out front since six. Says he isn't waiting, just passing by. For an hour. Ride with him, and hold on to something.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.RESIDENT,
                "text": "Also, past the bridge, the phone signal comes and goes. Everyone here says that's the best part.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "She seems to know that just-off-work look very well.",
            },
        ],
    },
    {
        "tag": "Country road · 19:20",
        "background": "res://assets/ui/backgrounds/prologue-road.png",
        "portrait": VillagerRules.VillagerId.FARMER,
        "night": false,
        "motion": {
            "camera": {"pivot": Vector2(1060, 560), "zoom": Vector2(1.02, 1.09)},
            "lights": [
                [&"village", Vector2(742, 392), 14.0],
                [&"village", Vector2(760, 378), 14.0],
                [&"village", Vector2(790, 372), 14.0],
                [&"village", Vector2(826, 384), 14.0],
                [&"village", Vector2(858, 376), 14.0],
                [&"village", Vector2(880, 392), 14.0],
            ],
            "stars": Rect2(0, 95, 1400, 120),
            "truck": {
                "from": Vector2(932, 702),
                "to": Vector2(1161, 631),
                "scale": Vector2(0.8, 0.56),
                "beam_to": Vector2(1450, 400),
            },
        },
        "lines": [
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "You're late.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": -1,
                "text": "The train was delayed...",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "The trains out here never run late. They just run slow.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Just the one suitcase? City folk usually bring more.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": -1,
                "text": "Most of it stayed in Tokyo. On purpose.",
            },
            {
                "kind": LineKind.NARRATION,
                "text": "The kei truck coughs twice, then takes the dirt road into the hills at a speed the law might not approve of.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "That field belonged to the Moriyamas. After old Moriyama passed, his wife moved to Osaka to live with their daughter.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Then it sat empty for ten years. I open the windows now and then, and start this truck once a month. Somebody has to.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": -1,
                "text": "So this truck came with the land too...?",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Old Moriyama's. It went with the land. Mrs Moriyama says a truck left idle breaks, and a field left idle goes to ruin.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Why would a Tokyo man buy a dead field?",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": -1,
                "text": "Call it good luck.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Luck won't water your turnips.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Ever grown anything?",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": -1,
                "text": "I kept a basil plant on my desk once. It died the week the product launched.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "...Hmph. At least you're honest.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Town is 30 minutes from the field, if the deer behave. Buy seeds from Sato-san. Get your coffee from Hana. She talks a lot, but she doesn't pry.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "The harvest market is on Day 14, two weeks from now. The whole town goes. Bring what you grew, or don't show up and embarrass yourself.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "And no farming after 22:00. Working in the dark just gets you hurt.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "He talks like he's writing a spec. Short, no filler, and every point matters.",
            },
        ],
    },
    {
        "tag": "Moriyama farm · 19:50",
        "background": "res://assets/ui/backgrounds/intro.png",
        "portrait": VillagerRules.VillagerId.FARMER,
        "night": true,
        "motion": {
            "camera": {"pivot": Vector2(960, 520), "zoom": Vector2(1.13, 1.03)},
            "headlights": Vector2(1180, 470),
            "windows": [
                [Vector2(1325, 232), Vector2(1365, 215), Vector2(1367, 262), Vector2(1327, 280)],
                [Vector2(1285, 325), Vector2(1347, 305), Vector2(1347, 380), Vector2(1287, 402)],
            ],
            "fireflies": [Rect2(260, 390, 1300, 300), 26],
        },
        "lines": [
            {
                "kind": LineKind.NARRATION,
                "text": "Full dark now. The headlights find an old house and a field grown over with weeds. Somewhere out past it, a river runs.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "We're here.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Power's on, water's on. I aired out the futons yesterday.",
                "cue": &"windows",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "The field's over there. Nobody's touched it in ten years. The weeds are taller than you.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "That wooden box by the field is the shipping bin. Put what you want to sell in before bed. Someone collects it by morning, and the money goes straight into your account.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Sato-san asked me to drop this off. 3 packs of Turnip seeds. First batch is free, next time it's full price.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Everything's ready. The rest is up to you.",
            },
            {
                "kind": LineKind.NARRATION,
                "text": "Gen-san tosses over a ring of keys.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": -1,
                "text": "Then how are you getting home?",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "On foot. Good for the knees.",
            },
            {
                "kind": LineKind.DIALOGUE,
                "villager": VillagerRules.VillagerId.FARMER,
                "text": "Don't call me unless the place is on fire. ...And if it is, call the fire department first.",
            },
            {
                "kind": LineKind.NARRATION,
                "text": "Gen-san walks off down the dirt road into the night, flashlight in hand, without looking back.",
            },
        ],
    },
    {
        "tag": "Indoors · 21:30",
        "background": "res://assets/ui/backgrounds/interior-night.png",
        "portrait": -1,
        "night": true,
        "motion": {
            "camera": {"pivot": Vector2(1068, 420), "zoom": Vector2(1.03, 1.1)},
            "room_lamp": Vector2(1068, 345),
            "moonlight": [Vector2(300, 210), Vector2(490, 195), Vector2(1160, 900), Vector2(820, 985)],
        },
        "lines": [
            {
                "kind": LineKind.NARRATION,
                "text": "The house smells of tatami and old timber.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "One bar of signal left. The work group chat keeps pinging.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "I deleted it. Easier than I expected.",
            },
            {
                "kind": LineKind.NARRATION,
                "text": "A note lies on the low table, held down by a weight. The handwriting is very neat.",
            },
            {
                "kind": LineKind.NOTE,
                "text": "The soil here is good. It has only been lonely. Please take good care of it for me. — Moriyama",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "...Right. I'll try.",
            },
        ],
    },
    {
        "tag": "Day 1 · 06:00",
        "background": "res://assets/ui/backgrounds/intro.png",
        "portrait": -1,
        "night": false,
        "motion": {
            "camera": {
                "pivot": Vector2(640, 420),
                "zoom": Vector2(1.09, 1.025),
                "pan": [Vector2.ZERO, Vector2(-10, 0)],
            },
            "dawn": true,
            "sun": Vector2(305, 128),
            "mist": [590.0, 645.0, 700.0],
            "birds": [Vector2(0.6, 175), Vector2(1.1, 205), Vector2(1.5, 160), Vector2(5.5, 230)],
        },
        "lines": [
            {
                "kind": LineKind.NARRATION,
                "text": "Six in the morning.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "No alarm clock. Birds woke me up.",
            },
            {
                "kind": LineKind.INNER_VOICE,
                "text": "Gen-san said the harvest market is two weeks away. To be exact, 13 days. Turn the soil, plant, water, and see what this field can grow.",
            },
        ],
    },
]

const RESULT_TIERS: Dictionary = {
    &"new_beginning": {
        "title": "New Beginning",
        "epilogue": "The lottery bought the land. Choosing to stay is a different kind of win.",
    },
    &"promising_farmer": {
        "title": "Promising Farmer",
        "epilogue": "The days are finally finding their rhythm. For once, success needs no deployment.",
    },
    &"heart_of_harvest": {
        "title": "Heart of the Harvest",
        "epilogue": "The field grew crops. The friendships made it feel like home.",
    },
}

const DIARY_LINES: Array[String] = [
    "No stand-up. No sprint. Just an enormous field and me.",
    "The weeds don't use issue trackers. They still find every edge case.",
    "The land was easy to buy. Figuring out how to care for it is another matter.",
    "There's a road to town. I should probably remember how to talk to people.",
    "The town has a seed shop. Predictable prices—imagine that.",
    "I could stop by the café. Conversations don't need ticket numbers.",
    "A week in. The silence is starting to sound less like a warning.",
    "I can usually tell which patch needs care without a dashboard.",
    "There is no perfect farming algorithm. The soil keeps proving it.",
    "The truck can take me to town. It can also bring me home.",
    "The place is still rough around the edges. So am I.",
    "The harvest market is close. The field gets the final review.",
    "I used to count releases. Tomorrow I'll count what grew.",
    "Whatever happens at the market, this is the first thing I chose for myself.",
]

static func diary_line(day: int) -> String:
    assert(DIARY_LINES.size() == GameRules.MAX_DAY)
    if DIARY_LINES.is_empty():
        return ""
    var clamped_day := clampi(day, 1, DIARY_LINES.size())
    return DIARY_LINES[clamped_day - 1]

const TUTORIALS: Array[Dictionary] = [
    {
        "id": &"farm_basics",
        "title": "Prepare the field",
        "body": "Face a farm diamond. Green means ready; red means blocked. Press Space to till.",
        "completed_by": GameRules.CommandCode.SOIL_TILLED,
    },
    {
        "id": &"plant",
        "title": "Plant a seed",
        "body": "Face tilled soil and press Space to plant the selected seed. Press 2 to change seeds.",
        "completed_by": GameRules.CommandCode.CROP_PLANTED,
    },
    {
        "id": &"water",
        "title": "Water the crop",
        "body": "On sunny days, press Space on a growing crop to water it. Two dry nights in a row and it withers.",
        "completed_by": GameRules.CommandCode.CROP_WATERED,
    },
    {
        "id": &"sleep",
        "title": "End the day",
        "body": "When today's work is done, face the bed, press E, and sleep.",
        "completed_by": GameRules.CommandCode.DAY_ADVANCED,
    },
    {
        "id": &"talk",
        "title": "Meet the village",
        "body": "Face Sato-san, Gen-san, or Hana and press E to talk.",
        "completed_by": GameRules.CommandCode.VILLAGER_TALKED,
    },
    {
        "id": &"buy_seeds",
        "title": "Reinvest",
        "body": "Face the Seed Shop, press E, and buy seeds to keep planting.",
        "completed_by": GameRules.CommandCode.SEEDS_PURCHASED,
    },
    {
        "id": &"harvest",
        "title": "Harvest",
        "body": "A fully grown crop is ready. Press Space to harvest it.",
        "completed_by": GameRules.CommandCode.CROP_HARVESTED,
    },
    {
        "id": &"shipping",
        "title": "Ship produce",
        "body": "Carry harvested produce to the shipping bin and deposit it for next-morning income.",
        "completed_by": GameRules.CommandCode.CROP_DEPOSITED,
    },
    {
        "id": &"gift",
        "title": "Give a gift",
        "body": "Open a villager conversation while carrying a crop and choose a gift.",
        "completed_by": GameRules.CommandCode.CROP_GIFTED,
    },
]

static func tutorial_keys() -> Array[StringName]:
    var result: Array[StringName] = []
    for definition in TUTORIALS:
        result.append(definition["id"])
    return result

static func initial_tutorial_progress() -> Dictionary:
    var result: Dictionary = {}
    for definition in TUTORIALS:
        result[definition["id"]] = false
    return result

static func tutorial_for_code(code: GameRules.CommandCode) -> StringName:
    for definition in TUTORIALS:
        if definition["completed_by"] == code:
            return definition["id"]
    return &""

static func next_tutorial_prompt(
    snapshot: Dictionary,
    excluded: Array[StringName] = [],
) -> Dictionary:
    var progress: Dictionary = snapshot.get("tutorial", {})
    for definition in TUTORIALS:
        var id: StringName = definition["id"]
        if bool(progress.get(id, false)) or excluded.has(id):
            continue
        if _tutorial_relevant(id, snapshot):
            return {
                "id": id,
                "title": definition["title"],
                "body": definition["body"],
            }
    return {}

static func _tutorial_relevant(id: StringName, snapshot: Dictionary) -> bool:
    var on_farm: bool = snapshot.get("location") == GameRules.MapId.FARM
    var in_town: bool = snapshot.get("location") == GameRules.MapId.TOWN
    match id:
        &"farm_basics":
            return on_farm and bool(snapshot.get("intro_acknowledged", false))
        &"plant":
            return (
                on_farm
                and _has_any_count(snapshot["seeds"])
                and _has_tilled_empty_soil(snapshot["farm"])
            )
        &"water":
            return (
                on_farm
                and StringName(snapshot["weather"]) == &"sunny"
                and _has_immature_unwatered_crop(snapshot["farm"])
            )
        &"sleep":
            if not on_farm:
                return false
            if _has_watered_crop(snapshot["farm"]):
                return true
            return StringName(snapshot["weather"]) == &"rainy" and _has_immature_crop(snapshot["farm"])
        &"talk":
            return int(snapshot["day"]) >= 2 and in_town
        &"buy_seeds":
            return (
                int(snapshot["day"]) >= 2
                and int(snapshot["money"]) >= int(GameRules.SEED_PRICES.min())
                and in_town
            )
        &"harvest":
            return on_farm and _has_mature_crop(snapshot["farm"])
        &"shipping":
            return on_farm and _has_any_count(snapshot["harvested"])
        &"gift":
            return in_town and _has_any_count(snapshot["harvested"])
        _:
            return false

static func _has_any_count(counts: Dictionary) -> bool:
    for key in counts:
        if int(counts[key]) > 0:
            return true
    return false

static func _has_tilled_empty_soil(farm: Array) -> bool:
    for tile in farm:
        if bool(tile["tilled"]) and tile["crop"] == null:
            return true
    return false

static func _has_immature_unwatered_crop(farm: Array) -> bool:
    for tile in farm:
        if tile["crop"] == null:
            continue
        var crop: Dictionary = tile["crop"]
        if not _tile_crop_is_mature(crop) and not bool(crop["watered_today"]):
            return true
    return false

static func _has_watered_crop(farm: Array) -> bool:
    for tile in farm:
        if tile["crop"] != null and bool(tile["crop"]["watered_today"]):
            return true
    return false

static func _has_immature_crop(farm: Array) -> bool:
    for tile in farm:
        if tile["crop"] != null and not _tile_crop_is_mature(tile["crop"]):
            return true
    return false

static func _has_mature_crop(farm: Array) -> bool:
    for tile in farm:
        if tile["crop"] != null and _tile_crop_is_mature(tile["crop"]):
            return true
    return false

static func _tile_crop_is_mature(crop: Dictionary) -> bool:
    var kind := GameRules.CROP_KEYS.find(StringName(crop["kind"]))
    return GameRules.is_mature(kind, int(crop["growth"]))

static func build_harvest_result(state: Dictionary) -> Dictionary:
    var shipped: Dictionary = state["shipped"]
    var shipped_count := 0
    var shipped_value := 0
    for kind in range(GameRules.CropKind.size()):
        var count := int(shipped.get(GameRules.crop_key(kind), 0))
        shipped_count += count
        shipped_value += count * GameRules.sale_value(kind)

    var has_close_friend := false
    var has_friend := false
    var featured := VillagerRules.VillagerId.SHOPKEEPER
    var featured_level := VillagerRules.RelationshipLevel.STRANGER
    var villagers: Dictionary = {}
    var relationships: Dictionary = state["relationships"]
    for id in range(VillagerRules.VillagerId.size()):
        var key := VillagerRules.villager_key(id)
        var level: VillagerRules.RelationshipLevel = VillagerRules.relationship_level(
            int(relationships[key]["points"])
        )
        if level == VillagerRules.RelationshipLevel.CLOSE_FRIEND:
            has_close_friend = true
        if level >= VillagerRules.RelationshipLevel.FRIEND:
            has_friend = true
        if level > featured_level:
            featured = id
            featured_level = level
        villagers[key] = {
            "name": VillagerRules.display_name(id),
            "level": VillagerRules.relationship_key(level),
            "line": VillagerRules.finale_line(id, level),
        }

    var tier := &"new_beginning"
    if shipped_value >= HEART_SHIPPED_VALUE and has_close_friend:
        tier = &"heart_of_harvest"
    elif shipped_value >= PROMISING_SHIPPED_VALUE or has_friend:
        tier = &"promising_farmer"

    var tier_definition: Dictionary = RESULT_TIERS[tier]
    return {
        "tier": tier,
        "title": tier_definition["title"],
        "epilogue": tier_definition["epilogue"],
        "shipped_count": shipped_count,
        "shipped_value": shipped_value,
        "final_money": int(state["money"]),
        "villager": VillagerRules.display_name(featured),
        "villagers": villagers,
    }
