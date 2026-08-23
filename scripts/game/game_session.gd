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
var _relationships: Array[Dictionary] = []
var _pending_morning_summary: Variant = null
var _weather_roll: Callable

func _init(weather_roll: Callable = Callable()) -> void:
    _weather_roll = weather_roll if weather_roll.is_valid() else Callable(self, "_default_weather_roll")
    for cell in WorldContract.farm_cells():
        _farm.append({"cell": cell, "tilled": false, "crop": null})
    for _id in VillagerRules.VillagerId.size():
        _relationships.append({
            "points": 0,
            "talked_today": false,
            "gifted_today": false,
            "close_friend_dialogue_seen": false,
        })

func _default_weather_roll() -> float:
    return randf()

func snapshot() -> Dictionary:
    return {
        "day": _day,
        "time_minutes": _time_minutes,
        "stamina": _stamina,
        "max_stamina": GameRules.MAX_STAMINA,
        "weather": GameRules.weather_key(_weather),
        "selected_action": GameRules.action_key(_selected_action),
        "selected_seed": GameRules.crop_key(_selected_seed),
        "money": _money,
        "seeds": _counts_snapshot(_seed_counts),
        "harvested": _counts_snapshot(_harvested_counts),
        "pending_shipment": _counts_snapshot(_pending_shipment_counts),
        "farm": _farm_snapshot(),
        "pending_morning_summary": _pending_morning_summary,
        "relationships": _relationships_snapshot(),
    }.duplicate(true)

func select_action(action: GameRules.FarmingAction) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    _selected_action = action
    return GameRules.CommandCode.ACTION_SELECTED

func select_seed(kind: GameRules.CropKind) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    _selected_seed = kind
    return GameRules.CommandCode.SEED_SELECTED

func apply_selected_action(target_cell: Variant) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
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
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
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
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
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
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
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
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
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

func buy_seeds(
    kind: GameRules.CropKind,
    quantity: int,
    target_cell: Variant,
) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    if not (target_cell is Vector2i) or target_cell != WorldContract.SHOP_CELL:
        return GameRules.CommandCode.NOT_AT_SHOP
    if quantity <= 0:
        return GameRules.CommandCode.INVALID_QUANTITY

    var total := GameRules.seed_price(kind) * quantity
    if _money < total:
        return GameRules.CommandCode.INSUFFICIENT_FUNDS

    _money -= total
    _seed_counts[kind] += quantity
    return GameRules.CommandCode.SEEDS_PURCHASED

func deposit_crop(
    kind: GameRules.CropKind,
    quantity: int,
    target_cell: Variant,
) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    if not (target_cell is Vector2i) or target_cell != WorldContract.SHIPPING_CELL:
        return GameRules.CommandCode.NOT_AT_SHIPPING_BIN
    if quantity <= 0:
        return GameRules.CommandCode.INVALID_QUANTITY
    if _harvested_counts[kind] < quantity:
        return GameRules.CommandCode.INSUFFICIENT_CROPS

    _harvested_counts[kind] -= quantity
    _pending_shipment_counts[kind] += quantity
    return GameRules.CommandCode.CROP_DEPOSITED

func _social_failure(code: GameRules.CommandCode) -> Dictionary:
    return {"code": code, "lines": [], "points_gained": 0, "gift_reaction": &"", "close_friend_sequence": false}

func _social_success(
    code: GameRules.CommandCode,
    lines: Array[String],
    points_gained: int,
    gift_reaction: StringName = &"",
    close_friend_sequence: bool = false,
) -> Dictionary:
    return {
        "code": code,
        "lines": lines.duplicate(),
        "points_gained": points_gained,
        "gift_reaction": gift_reaction,
        "close_friend_sequence": close_friend_sequence,
    }

func talk_to(
    villager_id: VillagerRules.VillagerId,
    target_cell: Variant,
) -> Dictionary:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return _social_failure(active_failure)
    if not (target_cell is Vector2i) or target_cell != WorldContract.villager_cell(villager_id):
        return _social_failure(GameRules.CommandCode.NOT_AT_VILLAGER)

    var relationship: Dictionary = _relationships[villager_id]
    var points_gained := 0
    if not bool(relationship["talked_today"]):
        relationship["talked_today"] = true
        points_gained = VillagerRules.TALK_POINTS
        relationship["points"] = int(relationship["points"]) + points_gained

    var level: VillagerRules.RelationshipLevel = VillagerRules.relationship_level(int(relationship["points"]))
    if level == VillagerRules.RelationshipLevel.CLOSE_FRIEND and not bool(relationship["close_friend_dialogue_seen"]):
        relationship["close_friend_dialogue_seen"] = true
        return _social_success(
            GameRules.CommandCode.VILLAGER_TALKED,
            VillagerRules.close_friend_dialogue_lines(villager_id),
            points_gained,
            &"",
            true,
        )

    var lines: Array[String] = [VillagerRules.dialogue_line(villager_id, level)]
    return _social_success(GameRules.CommandCode.VILLAGER_TALKED, lines, points_gained)

func gift_crop(
    villager_id: VillagerRules.VillagerId,
    crop_kind: GameRules.CropKind,
    target_cell: Variant,
) -> Dictionary:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return _social_failure(active_failure)
    if not (target_cell is Vector2i) or target_cell != WorldContract.villager_cell(villager_id):
        return _social_failure(GameRules.CommandCode.NOT_AT_VILLAGER)

    var relationship: Dictionary = _relationships[villager_id]
    if bool(relationship["gifted_today"]):
        return _social_failure(GameRules.CommandCode.GIFT_ALREADY_GIVEN)
    if _harvested_counts[crop_kind] < 1:
        return _social_failure(GameRules.CommandCode.INSUFFICIENT_CROPS)

    _harvested_counts[crop_kind] -= 1
    relationship["gifted_today"] = true
    var points_gained := VillagerRules.gift_points(villager_id, crop_kind)
    relationship["points"] = int(relationship["points"]) + points_gained
    var gift_reaction: StringName = &"favourite" if VillagerRules.is_favourite_crop(villager_id, crop_kind) else &"normal"
    var lines: Array[String] = [VillagerRules.gift_line(villager_id, crop_kind)]
    return _social_success(
        GameRules.CommandCode.CROP_GIFTED,
        lines,
        points_gained,
        gift_reaction,
    )

func sleep(target_cell: Variant) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    if not (target_cell is Vector2i) or target_cell != WorldContract.BED_CELL:
        return GameRules.CommandCode.NOT_AT_BED
    if _day >= GameRules.MAX_DAY:
        return GameRules.CommandCode.DAY_LIMIT_REACHED

    var completed_day := _day
    var completed_weather := _weather
    var stamina_restored := GameRules.MAX_STAMINA - _stamina
    var next_weather := GameRules.weather_from_roll(float(_weather_roll.call()))
    var payout := GameRules.shipment_payout(_counts_snapshot(_pending_shipment_counts))

    var crops_advanced := 0
    for index in _farm.size():
        var tile: Dictionary = _farm[index]
        if tile["crop"] == null:
            continue
        var crop: Dictionary = tile["crop"]
        var kind: GameRules.CropKind = crop["kind"]
        var watered := bool(crop["watered_today"]) or completed_weather == GameRules.Weather.RAINY
        if watered and not GameRules.is_mature(kind, int(crop["growth"])):
            crop["growth"] = int(crop["growth"]) + 1
            crops_advanced += 1
        crop["watered_today"] = false
        tile["crop"] = crop
        _farm[index] = tile

    _money += int(payout["total"])
    _pending_shipment_counts = [0, 0, 0]
    _day += 1
    _time_minutes = GameRules.DAY_START_MINUTES
    _stamina = GameRules.MAX_STAMINA
    _weather = next_weather
    _pending_morning_summary = {
        "completed_day": completed_day,
        "next_day": _day,
        "crops_advanced": crops_advanced,
        "next_weather": GameRules.weather_key(next_weather),
        "stamina_restored": stamina_restored,
        "shipments": payout["lines"].duplicate(true),
        "shipping_income": int(payout["total"]),
        "money_after_shipping": _money,
    }
    for relationship in _relationships:
        relationship["talked_today"] = false
        relationship["gifted_today"] = false
    return GameRules.CommandCode.DAY_ADVANCED

func acknowledge_morning_summary() -> GameRules.CommandCode:
    if _pending_morning_summary == null:
        return GameRules.CommandCode.NO_DAY_SUMMARY
    _pending_morning_summary = null
    return GameRules.CommandCode.DAY_STARTED

func _active_day_failure() -> int:
    if _pending_morning_summary != null:
        return GameRules.CommandCode.DAY_SUMMARY_PENDING
    return -1

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

func _relationships_snapshot() -> Dictionary:
    var result: Dictionary = {}
    for id in range(VillagerRules.VillagerId.size()):
        var relationship: Dictionary = _relationships[id]
        var level := VillagerRules.relationship_level(int(relationship["points"]))
        result[VillagerRules.villager_key(id)] = {
            "points": relationship["points"],
            "level": VillagerRules.relationship_key(level),
            "talked_today": relationship["talked_today"],
            "gifted_today": relationship["gifted_today"],
            "close_friend_dialogue_seen": relationship["close_friend_dialogue_seen"],
        }
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
