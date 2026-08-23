class_name GameSession
extends RefCounted

var _day: int = 1
var _time_minutes: int = GameRules.DAY_START_MINUTES
var _stamina: int = GameRules.MAX_STAMINA
var _weather: GameRules.Weather = GameRules.Weather.SUNNY
var _selected_action: GameRules.FarmingAction = GameRules.FarmingAction.HOE
var _selected_seed: GameRules.CropKind = GameRules.CropKind.TURNIP
var _money: int = GameRules.STARTING_MONEY
var _seed_counts: Array[int] = GameRules.starting_seed_counts()
var _harvested_counts: Array[int] = [0, 0, 0]
var _pending_shipment_counts: Array[int] = [0, 0, 0]
var _farm: Array[Dictionary] = []
var _pending_morning_summary: Variant = null
var _weather_roll: Callable

func _init(weather_roll: Callable = Callable()) -> void:
    _weather_roll = weather_roll if weather_roll.is_valid() else Callable(self, "_default_weather_roll")
    for cell in WorldContract.farm_cells():
        _farm.append({"cell": cell, "tilled": false, "crop": null})

func _default_weather_roll() -> float:
    return randf()

func snapshot() -> Dictionary:
    return {
        "day": _day,
        "time_minutes": _time_minutes,
        "stamina": _stamina,
        "weather": &"rainy" if _weather == GameRules.Weather.RAINY else &"sunny",
        "selected_action": _action_key(_selected_action),
        "selected_seed": GameRules.crop_key(_selected_seed),
        "money": _money,
        "seeds": _counts_snapshot(_seed_counts),
        "harvested": _counts_snapshot(_harvested_counts),
        "pending_shipment": _counts_snapshot(_pending_shipment_counts),
        "farm": _farm_snapshot(),
        "pending_morning_summary": _pending_morning_summary,
    }.duplicate(true)

func select_action(action: GameRules.FarmingAction) -> GameRules.CommandCode:
    _selected_action = action
    return GameRules.CommandCode.ACTION_SELECTED

func select_seed(kind: GameRules.CropKind) -> GameRules.CommandCode:
    _selected_seed = kind
    return GameRules.CommandCode.SEED_SELECTED

func apply_selected_action(target_cell: Variant) -> GameRules.CommandCode:
    match _selected_action:
        GameRules.FarmingAction.HOE:
            return hoe(target_cell)
        GameRules.FarmingAction.SEEDS:
            return plant(target_cell)
        GameRules.FarmingAction.WATERING_CAN:
            return water(target_cell)
        GameRules.FarmingAction.HANDS:
            return harvest(target_cell)
    assert(false, "unsupported farming action")
    return GameRules.CommandCode.NO_TARGET

func hoe(target_cell: Variant) -> GameRules.CommandCode:
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var index := _farm_index(target_cell)
    var tile: Dictionary = _farm[index]
    if tile["crop"] != null:
        return GameRules.CommandCode.CROP_PRESENT
    if bool(tile["tilled"]):
        return GameRules.CommandCode.ALREADY_TILLED

    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        GameRules.FarmingAction.HOE,
    )
    if not bool(budget["ok"]):
        return budget["code"]

    tile["tilled"] = true
    _farm[index] = tile
    _commit_budget(budget)
    return GameRules.CommandCode.SOIL_TILLED

func plant(target_cell: Variant) -> GameRules.CommandCode:
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var index := _farm_index(target_cell)
    var tile: Dictionary = _farm[index]
    if not bool(tile["tilled"]):
        return GameRules.CommandCode.SOIL_UNTILLED
    if tile["crop"] != null:
        return GameRules.CommandCode.CROP_PRESENT
    if _seed_counts[_selected_seed] == 0:
        return GameRules.CommandCode.NO_SELECTED_SEEDS

    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        GameRules.FarmingAction.SEEDS,
    )
    if not bool(budget["ok"]):
        return budget["code"]

    tile["crop"] = {
        "kind": _selected_seed,
        "growth": 0,
        "watered_today": false,
    }
    _farm[index] = tile
    _seed_counts[_selected_seed] -= 1
    _commit_budget(budget)
    return GameRules.CommandCode.CROP_PLANTED

func water(target_cell: Variant) -> GameRules.CommandCode:
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var index := _farm_index(target_cell)
    var tile: Dictionary = _farm[index]
    if tile["crop"] == null:
        return GameRules.CommandCode.NO_CROP

    var crop: Dictionary = tile["crop"]
    var kind: GameRules.CropKind = crop["kind"]
    if GameRules.is_mature(kind, int(crop["growth"])):
        return GameRules.CommandCode.CROP_MATURE
    if _weather == GameRules.Weather.RAINY:
        return GameRules.CommandCode.RAIN_WATERS_CROPS
    if bool(crop["watered_today"]):
        return GameRules.CommandCode.ALREADY_WATERED

    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        GameRules.FarmingAction.WATERING_CAN,
    )
    if not bool(budget["ok"]):
        return budget["code"]

    crop["watered_today"] = true
    tile["crop"] = crop
    _farm[index] = tile
    _commit_budget(budget)
    return GameRules.CommandCode.CROP_WATERED

func harvest(target_cell: Variant) -> GameRules.CommandCode:
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var index := _farm_index(target_cell)
    var tile: Dictionary = _farm[index]
    if tile["crop"] == null:
        return GameRules.CommandCode.NO_CROP

    var crop: Dictionary = tile["crop"]
    var kind: GameRules.CropKind = crop["kind"]
    if not GameRules.is_mature(kind, int(crop["growth"])):
        return GameRules.CommandCode.CROP_IMMATURE

    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        GameRules.FarmingAction.HANDS,
    )
    if not bool(budget["ok"]):
        return budget["code"]

    tile["crop"] = null
    _farm[index] = tile
    _harvested_counts[kind] += 1
    _commit_budget(budget)
    return GameRules.CommandCode.CROP_HARVESTED

func _target_failure(target_cell: Variant) -> int:
    if not (target_cell is Vector2i):
        return GameRules.CommandCode.NO_TARGET
    if _farm_index(target_cell) == -1:
        return GameRules.CommandCode.NOT_FARM_CELL
    return -1

func _farm_index(target_cell: Variant) -> int:
    if not (target_cell is Vector2i):
        return -1
    for index in _farm.size():
        if _farm[index]["cell"] == target_cell:
            return index
    return -1

func _commit_budget(budget: Dictionary) -> void:
    _time_minutes = int(budget["time_minutes"])
    _stamina = int(budget["stamina"])

func _counts_snapshot(counts: Array[int]) -> Dictionary:
    var result: Dictionary = {}
    for kind in range(GameRules.CropKind.size()):
        result[GameRules.crop_key(kind)] = counts[kind]
    return result

func _farm_snapshot() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for tile in _farm:
        var entry: Dictionary = {
            "cell": tile["cell"],
            "tilled": tile["tilled"],
            "crop": null,
        }
        if tile["crop"] != null:
            var crop: Dictionary = tile["crop"]
            entry["crop"] = {
                "kind": GameRules.crop_key(crop["kind"]),
                "growth": crop["growth"],
                "watered_today": crop["watered_today"],
            }
        result.append(entry)
    return result

func _action_key(action: GameRules.FarmingAction) -> StringName:
    match action:
        GameRules.FarmingAction.HOE:
            return &"hoe"
        GameRules.FarmingAction.SEEDS:
            return &"seeds"
        GameRules.FarmingAction.WATERING_CAN:
            return &"watering_can"
        GameRules.FarmingAction.HANDS:
            return &"hands"
    assert(false, "unsupported farming action")
    return &"hoe"
