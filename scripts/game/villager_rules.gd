class_name VillagerRules
extends RefCounted

enum VillagerId { SHOPKEEPER, FARMER, RESIDENT }
enum RelationshipLevel { STRANGER, FRIEND, CLOSE_FRIEND }

const TALK_POINTS := 1
const GIFT_POINTS := 3
const FAVOURITE_GIFT_BONUS := 2
const FRIEND_POINTS := 12
const CLOSE_FRIEND_POINTS := 18
const MARKET_DIALOGUE_START_DAY := 12

const VILLAGER_KEYS: Array[StringName] = [&"shopkeeper", &"farmer", &"resident"]
const DISPLAY_NAMES: Array[String] = ["Mira", "Rowan", "June"]
const ROLE_LABELS: Array[String] = ["Seed-shop keeper", "Neighbouring farmer", "Village resident"]
const FAVOURITE_CROPS: Array[int] = [
    GameRules.CropKind.POTATO,
    GameRules.CropKind.PUMPKIN,
    GameRules.CropKind.TURNIP,
]
const RELATIONSHIP_KEYS: Array[StringName] = [&"stranger", &"friend", &"close_friend"]
const RELATIONSHIP_DISPLAY_NAMES: Array[String] = ["Stranger", "Friend", "Close Friend"]

const NORMAL_DIALOGUE: Array = [
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
const RAINY_DIALOGUE: Array[String] = [
    "Rain saves you a watering round. Good day to plan the next planting.",
    "Let the rain do its share. Save your strength for the rest.",
    "Rain pulls the village closer. Everyone listens to the same roofs.",
]
const SHIPPED_DIALOGUE: Array[String] = [
    "Produce has left your farm now. Growing and selling are different skills.",
    "You have sent real harvest out now. That means the farm is working.",
    "Your produce is going out now. The farm touches more than your own day.",
]
const MARKET_DIALOGUE: Array[String] = [
    "The market is close. Keep some coin ready for what comes next.",
    "The market is close. Finish what will be ready before you plant more.",
    "The market is almost here. You will see who noticed your season.",
]
const CLOSE_FRIEND_DIALOGUE: Array = [
    [
        "You kept showing up, even on the slow days.",
        "The harvest market will feel different with you there.",
    ],
    [
        "I noticed when the farm stopped looking neglected.",
        "You earned that change one ordinary day at a time.",
    ],
    [
        "You came here as the new farmer, but that is not how I think of you now.",
        "You are one of us.",
    ],
]
const NORMAL_GIFT_LINES: Array[String] = [
    "A useful harvest. Thank you.",
    "Good produce. I can use this.",
    "That is kind of you.",
]
const FAVOURITE_GIFT_LINES: Array[String] = [
    "Potatoes? You remembered.",
    "A pumpkin this good is hard to ignore.",
    "Turnips are my favourite. Perfect choice.",
]
const FINALE_LINES: Array = [
    [
        "A quiet first season, but the fields are yours now.",
        "You kept the seed counter busy. That was good for both of us.",
        "You came for seeds and stayed for the village. The market will miss you.",
    ],
    [
        "Every farmer starts with one tilled diamond. Come spring, plant twice as many.",
        "Your rows grew as steady as any I have ever kept.",
        "I would trust you with my own fields. A farmer has no higher words.",
    ],
    [
        "The village noticed someone new working the old farm.",
        "You made this quiet road feel lived-in again.",
        "You are one of us now, whatever the season brings.",
    ],
]

static func villager_key(id: VillagerId) -> StringName:
    return VILLAGER_KEYS[id]

static func display_name(id: VillagerId) -> String:
    return DISPLAY_NAMES[id]

static func role_label(id: VillagerId) -> String:
    return ROLE_LABELS[id]

static func favourite_crop(id: VillagerId) -> GameRules.CropKind:
    return FAVOURITE_CROPS[id]

static func favourite_villager_for_crop(kind: GameRules.CropKind) -> VillagerId:
    var index := FAVOURITE_CROPS.find(kind)
    assert(index >= 0)
    return index as VillagerId

static func relationship_key(level: RelationshipLevel) -> StringName:
    return RELATIONSHIP_KEYS[level]

static func relationship_display_name(level: RelationshipLevel) -> String:
    return RELATIONSHIP_DISPLAY_NAMES[level]

static func relationship_level(points: int) -> RelationshipLevel:
    if points >= CLOSE_FRIEND_POINTS:
        return RelationshipLevel.CLOSE_FRIEND
    if points >= FRIEND_POINTS:
        return RelationshipLevel.FRIEND
    return RelationshipLevel.STRANGER

static func ordinary_dialogue_candidates(
    id: VillagerId,
    level: RelationshipLevel,
    day: int,
    is_rainy: bool,
    has_settled_shipment: bool,
) -> Array[String]:
    var candidates: Array[String] = []
    for line in NORMAL_DIALOGUE[id][level]:
        candidates.append(String(line))
    if is_rainy:
        candidates.append(RAINY_DIALOGUE[id])
    if has_settled_shipment:
        candidates.append(SHIPPED_DIALOGUE[id])
    if day >= MARKET_DIALOGUE_START_DAY:
        candidates.append(MARKET_DIALOGUE[id])
    return candidates

static func ordinary_dialogue_line(
    id: VillagerId,
    level: RelationshipLevel,
    day: int,
    is_rainy: bool,
    has_settled_shipment: bool,
) -> String:
    var candidates := ordinary_dialogue_candidates(id, level, day, is_rainy, has_settled_shipment)
    return candidates[posmod((day - 1) + int(id), candidates.size())]

static func finale_line(id: VillagerId, level: RelationshipLevel) -> String:
    return FINALE_LINES[id][level]

static func close_friend_dialogue_lines(id: VillagerId) -> Array[String]:
    var lines: Array[String] = []
    for line in CLOSE_FRIEND_DIALOGUE[id]:
        lines.append(String(line))
    return lines

static func is_favourite_crop(id: VillagerId, crop: GameRules.CropKind) -> bool:
    return favourite_crop(id) == crop

static func gift_points(id: VillagerId, crop: GameRules.CropKind) -> int:
    return GIFT_POINTS + FAVOURITE_GIFT_BONUS if is_favourite_crop(id, crop) else GIFT_POINTS

static func gift_line(id: VillagerId, crop: GameRules.CropKind) -> String:
    return FAVOURITE_GIFT_LINES[id] if is_favourite_crop(id, crop) else NORMAL_GIFT_LINES[id]
