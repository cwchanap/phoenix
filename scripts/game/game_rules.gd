class_name GameRules
extends RefCounted

enum CropKind { TURNIP, POTATO, PUMPKIN }
enum FarmingAction { HOE, SEEDS, WATERING_CAN, HANDS }
enum Weather { SUNNY, RAINY }
enum CommandCode {
    ACTION_SELECTED,
    SEED_SELECTED,
    SOIL_TILLED,
    CROP_PLANTED,
    CROP_WATERED,
    CROP_HARVESTED,
    SEEDS_PURCHASED,
    CROP_DEPOSITED,
    DAY_ADVANCED,
    DAY_STARTED,
    NO_TARGET,
    NOT_FARM_CELL,
    ALREADY_TILLED,
    SOIL_UNTILLED,
    CROP_PRESENT,
    NO_SELECTED_SEEDS,
    NO_CROP,
    ALREADY_WATERED,
    CROP_MATURE,
    CROP_IMMATURE,
    NOT_AT_BED,
    NOT_AT_SHOP,
    NOT_AT_SHIPPING_BIN,
    INVALID_QUANTITY,
    INSUFFICIENT_FUNDS,
    INSUFFICIENT_CROPS,
    ACTION_TOO_LATE,
    INSUFFICIENT_STAMINA,
    RAIN_WATERS_CROPS,
    DAY_SUMMARY_PENDING,
    NO_DAY_SUMMARY,
    DAY_LIMIT_REACHED,
    NOTHING_TO_INTERACT,
    VILLAGER_TALKED,
    CROP_GIFTED,
    NOT_AT_VILLAGER,
    GIFT_ALREADY_GIVEN,
    INTRO_ACKNOWLEDGED,
    INTRO_ALREADY_ACKNOWLEDGED,
}

const DAY_START_MINUTES := 360
const ACTION_CUTOFF_MINUTES := 1320
const MAX_STAMINA := 20
const MAX_DAY := 14
const RAIN_CHANCE := 0.25
const STARTING_MONEY := 150

const CROP_KEYS: Array[StringName] = [&"turnip", &"potato", &"pumpkin"]
const ACTION_KEYS: Array[StringName] = [&"hoe", &"seeds", &"watering_can", &"hands"]
const WEATHER_KEYS: Array[StringName] = [&"sunny", &"rainy"]
const CROP_DISPLAY_NAMES: Array[String] = ["Turnip", "Potato", "Pumpkin"]
const GROWTH_NIGHTS: Array[int] = [3, 5, 7]
const SEED_PRICES: Array[int] = [20, 40, 70]
const SALE_VALUES: Array[int] = [35, 75, 140]
const ACTION_MINUTES: Array[int] = [30, 20, 20, 20]
const ACTION_STAMINA: Array[int] = [3, 1, 2, 1]

static func starting_seed_counts() -> Array[int]:
    return [3, 0, 0]

static func crop_key(kind: CropKind) -> StringName:
    return CROP_KEYS[kind]

static func action_key(action: FarmingAction) -> StringName:
    return ACTION_KEYS[action]

static func weather_key(weather: Weather) -> StringName:
    return WEATHER_KEYS[weather]

static func crop_display_name(kind: CropKind) -> String:
    return CROP_DISPLAY_NAMES[kind]

static func growth_nights(kind: CropKind) -> int:
    return GROWTH_NIGHTS[kind]

static func seed_price(kind: CropKind) -> int:
    return SEED_PRICES[kind]

static func sale_value(kind: CropKind) -> int:
    return SALE_VALUES[kind]

static func action_cost(action: FarmingAction) -> Dictionary:
    return {
        "minutes": ACTION_MINUTES[action],
        "stamina": ACTION_STAMINA[action],
    }

static func visual_stage(kind: CropKind, progress: int) -> int:
    var stage := int(floor(float(progress * 3) / float(growth_nights(kind))))
    return mini(3, stage)

static func is_mature(kind: CropKind, progress: int) -> bool:
    return progress >= growth_nights(kind)

static func evaluate_action_budget(
    time_minutes: int,
    stamina: int,
    action: FarmingAction,
) -> Dictionary:
    var cost := action_cost(action)
    var next_time := time_minutes + int(cost["minutes"])
    if next_time > ACTION_CUTOFF_MINUTES:
        return {"ok": false, "code": CommandCode.ACTION_TOO_LATE}
    if stamina < int(cost["stamina"]):
        return {"ok": false, "code": CommandCode.INSUFFICIENT_STAMINA}
    return {
        "ok": true,
        "time_minutes": next_time,
        "stamina": stamina - int(cost["stamina"]),
    }

static func shipment_payout(counts: Dictionary) -> Dictionary:
    var lines: Array[Dictionary] = []
    var total := 0
    for kind in range(CropKind.size()):
        var key := crop_key(kind)
        var quantity: int = counts.get(key, 0)
        assert(quantity >= 0)
        if quantity == 0:
            continue
        var amount := quantity * sale_value(kind)
        lines.append({"crop": key, "quantity": quantity, "amount": amount})
        total += amount
    return {"lines": lines, "total": total}

static func weather_from_roll(roll: float) -> Weather:
    assert(roll >= 0.0 and roll < 1.0)
    return Weather.RAINY if roll < RAIN_CHANCE else Weather.SUNNY

static func format_time(minutes: int) -> String:
    assert(minutes >= 0 and minutes < 1440)
    return "%02d:%02d" % [minutes / 60, minutes % 60]
