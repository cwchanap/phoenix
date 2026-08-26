class_name ContentRules
extends RefCounted

const PROMISING_SHIPPED_VALUE := 150
const HEART_SHIPPED_VALUE := 300

const TUTORIALS: Array[Dictionary] = [
    {
        "id": &"farm_basics",
        "title": "Prepare the field",
        "body": "Face a farm diamond until the gold outline appears. Press 1 for Hoe, then Space.",
        "completed_by": GameRules.CommandCode.SOIL_TILLED,
    },
    {
        "id": &"plant",
        "title": "Plant a seed",
        "body": "With tilled soil targeted, press 2 for Seeds, then Space.",
        "completed_by": GameRules.CommandCode.CROP_PLANTED,
    },
    {
        "id": &"water",
        "title": "Water the crop",
        "body": "On sunny days, press 3 for Water, then Space on a planted crop.",
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
        "body": "Face Mira, Rowan, or June and press E to talk.",
        "completed_by": GameRules.CommandCode.VILLAGER_TALKED,
    },
    {
        "id": &"buy_seeds",
        "title": "Reinvest",
        "body": "Face the seed counter, press E, and buy seeds to keep planting.",
        "completed_by": GameRules.CommandCode.SEEDS_PURCHASED,
    },
    {
        "id": &"harvest",
        "title": "Harvest",
        "body": "A fully grown crop is ready. Press 4 for Hands, then Space.",
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
    match id:
        &"farm_basics":
            return bool(snapshot.get("intro_acknowledged", false))
        &"plant":
            return _has_any_count(snapshot["seeds"]) and _has_tilled_empty_soil(snapshot["farm"])
        &"water":
            return (
                StringName(snapshot["weather"]) == &"sunny"
                and _has_immature_unwatered_crop(snapshot["farm"])
            )
        &"sleep":
            if _has_watered_crop(snapshot["farm"]):
                return true
            return StringName(snapshot["weather"]) == &"rainy" and _has_immature_crop(snapshot["farm"])
        &"talk":
            return int(snapshot["day"]) >= 2
        &"buy_seeds":
            return (
                int(snapshot["day"]) >= 2
                and int(snapshot["money"]) >= GameRules.seed_price(GameRules.CropKind.TURNIP)
            )
        &"harvest":
            return _has_mature_crop(snapshot["farm"])
        &"shipping", &"gift":
            return _has_any_count(snapshot["harvested"])
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
    var relationships: Dictionary = state["relationships"]
    for id in range(VillagerRules.VillagerId.size()):
        var villager: Dictionary = relationships[VillagerRules.villager_key(id)]
        var level: VillagerRules.RelationshipLevel = VillagerRules.relationship_level(int(villager["points"]))
        if level == VillagerRules.RelationshipLevel.CLOSE_FRIEND:
            has_close_friend = true
        if level >= VillagerRules.RelationshipLevel.FRIEND:
            has_friend = true
        if level > featured_level:
            featured = id
            featured_level = level

    var tier := &"new_beginning"
    var title := "New Beginning"
    if shipped_value >= HEART_SHIPPED_VALUE and has_close_friend:
        tier = &"heart_of_harvest"
        title = "Heart of the Harvest"
    elif shipped_value >= PROMISING_SHIPPED_VALUE or has_friend:
        tier = &"promising_farmer"
        title = "Promising Farmer"

    return {
        "tier": tier,
        "title": title,
        "shipped_count": shipped_count,
        "shipped_value": shipped_value,
        "final_money": int(state["money"]),
        "villager": VillagerRules.display_name(featured),
        "line": VillagerRules.finale_line(featured, featured_level),
    }
