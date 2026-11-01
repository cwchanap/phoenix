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
const DISPLAY_NAMES: Array[String] = ["Sato-san", "Gen-san", "Hana"]
const ROLE_LABELS: Array[String] = ["Seed-shop keeper", "Retired farmer", "Station cafe owner"]
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
const RAINY_DIALOGUE: Array[String] = [
    "Rain day. Let the sky water and come plan your next planting.",
    "Let the rain do its share. Save your back for tomorrow.",
    "Rainy days fill every seat in here. Everyone listens to the same roof.",
]
const SHIPPED_DIALOGUE: Array[String] = [
    "Your produce has gone out. Growing and selling are different skills.",
    "You sold real harvest. Now that field is a farm.",
    "I heard your produce made it into town. That is how people learn a name.",
]
const MARKET_DIALOGUE: Array[String] = [
    "The market is close. Keep some coin ready for what comes next.",
    "Market soon. Finish what will be ready before you plant more.",
    "The market is almost here. You will see who noticed your season.",
]
const CLOSE_FRIEND_DIALOGUE: Array = [
    [
        "You kept driving in, even on the slow days.",
        "The harvest market will feel different with you behind a stall.",
    ],
    [
        "I watched that field sit empty for ten years.",
        "You brought it back one ordinary day at a time.",
    ],
    [
        "You came here as the Tokyo guy. That is not how I think of you now.",
        "You are one of us.",
    ],
]
const NORMAL_GIFT_LINES: Array[String] = [
    "Good produce. I will note it in the ledger. Thank you.",
    "Hm. Decent. I can use this.",
    "For me? That is kind of you.",
]
const FAVOURITE_GIFT_LINES: Array[String] = [
    "Potatoes? You remembered.",
    "A pumpkin like this is hard to argue with.",
    "Turnips! My favourite. Perfect choice.",
]
const FINALE_LINES: Array = [
    [
        "A quiet first season, but the field is yours now.",
        "You kept my counter busy. That was good for both of us.",
        "You came in for seeds and stayed for the town. Come back in spring.",
    ],
    [
        "Every farmer starts with one tilled square. Plant twice as many in spring.",
        "Your rows grew as steady as any I ever kept.",
        "I would trust you with my own field. A farmer has no higher words.",
    ],
    [
        "Town noticed someone new working the old field.",
        "You made the road out of town feel lived-in again.",
        "You are one of us now, whatever the next season brings.",
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
