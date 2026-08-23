class_name VillagerRules
extends RefCounted

enum VillagerId { SHOPKEEPER, FARMER, RESIDENT }
enum RelationshipLevel { STRANGER, FRIEND, CLOSE_FRIEND }

const TALK_POINTS := 1
const GIFT_POINTS := 3
const FAVOURITE_GIFT_BONUS := 2
const FRIEND_POINTS := 12
const CLOSE_FRIEND_POINTS := 18

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

static func villager_key(id: VillagerId) -> StringName:
    return VILLAGER_KEYS[id]

static func display_name(id: VillagerId) -> String:
    return DISPLAY_NAMES[id]

static func role_label(id: VillagerId) -> String:
    return ROLE_LABELS[id]

static func favourite_crop(id: VillagerId) -> GameRules.CropKind:
    return FAVOURITE_CROPS[id]

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

static func dialogue_line(id: VillagerId, level: RelationshipLevel) -> String:
    return NORMAL_DIALOGUE[id][level]

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
