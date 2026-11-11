class_name ContentRules
extends RefCounted

const PROMISING_SHIPPED_VALUE := 150
const HEART_SHIPPED_VALUE := 300

const OPENING_INTRO := (
    "I won the lottery, left my software job in Tokyo, and bought a "
    + "field that looks like it hasn't seen a hoe in years."
)
const OPENING_GUIDE := (
    "The harvest market opens on Day 14. I have two weeks to grow "
    + "something—and maybe get to know the people in town."
)
const OPENING_SPEAKER := "KENJI"
const OPENING_ROLE := "Former software engineer"

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
