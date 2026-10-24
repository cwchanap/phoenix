class_name GameSession
extends RefCounted

var _day: int = 1
var _time_minutes: int = GameRules.DAY_START_MINUTES
var _stamina: int = GameRules.MAX_STAMINA
var _weather: GameRules.Weather = GameRules.Weather.SUNNY
var _weather_history: Array[StringName] = [GameRules.weather_key(GameRules.Weather.SUNNY)]
var _selected_action: GameRules.FarmingAction = GameRules.FarmingAction.HOE
var _selected_seed: GameRules.CropKind = GameRules.CropKind.TURNIP
var _money: int = GameRules.STARTING_MONEY
var _seed_counts: Array[int] = GameRules.starting_seed_counts()
var _harvested_counts: Array[int] = [0, 0, 0]
var _pending_shipment_counts: Array[int] = [0, 0, 0]
var _shipped_counts: Array[int] = [0, 0, 0]
var _intro_acknowledged := false
var _tutorial_progress: Dictionary = ContentRules.initial_tutorial_progress()
var _finale_triggered := false
var _watering_can_upgraded := false
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

func state() -> Dictionary:
    return {
        "day": _day,
        "time_minutes": _time_minutes,
        "stamina": _stamina,
        "weather": GameRules.weather_key(_weather),
        "weather_history": _weather_history.duplicate(),
        "selected_action": GameRules.action_key(_selected_action),
        "selected_seed": GameRules.crop_key(_selected_seed),
        "money": _money,
        "seeds": _counts_snapshot(_seed_counts),
        "harvested": _counts_snapshot(_harvested_counts),
        "pending_shipment": _counts_snapshot(_pending_shipment_counts),
        "farm": _farm_snapshot(),
        "pending_morning_summary": _pending_morning_summary,
        "relationships": _relationships_state(),
        "intro_acknowledged": _intro_acknowledged,
        "tutorial": _tutorial_progress.duplicate(true),
        "shipped": _counts_snapshot(_shipped_counts),
        "finale_triggered": _finale_triggered,
        "watering_can_upgraded": _watering_can_upgraded,
    }.duplicate(true)

func snapshot() -> Dictionary:
    var state_result := state()
    var result: Dictionary = {
        "day": state_result["day"],
        "time_minutes": state_result["time_minutes"],
        "stamina": state_result["stamina"],
        "max_stamina": GameRules.MAX_STAMINA,
        "weather": state_result["weather"],
        "weather_history": state_result["weather_history"],
        "selected_action": state_result["selected_action"],
        "selected_seed": state_result["selected_seed"],
        "money": state_result["money"],
        "seeds": state_result["seeds"],
        "harvested": state_result["harvested"],
        "pending_shipment": state_result["pending_shipment"],
        "farm": state_result["farm"],
        "pending_morning_summary": state_result["pending_morning_summary"],
        "relationships": state_result["relationships"],
        "intro_acknowledged": state_result["intro_acknowledged"],
        "tutorial": state_result["tutorial"],
        "shipped": state_result["shipped"],
        "finale_triggered": state_result["finale_triggered"],
        "watering_can_upgraded": state_result["watering_can_upgraded"],
    }
    for id in range(VillagerRules.VillagerId.size()):
        var key := VillagerRules.villager_key(id)
        var relationship: Dictionary = result["relationships"][key]
        relationship["level"] = VillagerRules.relationship_key(
            VillagerRules.relationship_level(int(relationship["points"]))
        )
    return result

func restore_state(candidate: Dictionary) -> bool:
    if SessionStateValidator.state_error(candidate) != "":
        return false

    _day = int(candidate["day"])
    _time_minutes = int(candidate["time_minutes"])
    _stamina = int(candidate["stamina"])
    _weather = GameRules.WEATHER_KEYS.find(StringName(candidate["weather"]))
    _weather_history = []
    for weather_value in candidate["weather_history"]:
        var weather_key := StringName(weather_value)
        var weather_index := GameRules.WEATHER_KEYS.find(weather_key)
        _weather_history.append(GameRules.WEATHER_KEYS[weather_index])
    _selected_action = GameRules.ACTION_KEYS.find(StringName(candidate["selected_action"]))
    _selected_seed = GameRules.CROP_KEYS.find(StringName(candidate["selected_seed"]))
    _money = int(candidate["money"])
    _seed_counts = _counts_array(candidate["seeds"])
    _harvested_counts = _counts_array(candidate["harvested"])
    _pending_shipment_counts = _counts_array(candidate["pending_shipment"])
    _intro_acknowledged = bool(candidate["intro_acknowledged"])
    _tutorial_progress = {}
    for id in ContentRules.tutorial_keys():
        var field := SessionStateValidator.named_dictionary_value(candidate["tutorial"], id, "tutorial %s" % id)
        _tutorial_progress[id] = bool(field["value"])
    _shipped_counts = _counts_array(candidate["shipped"])
    _finale_triggered = bool(candidate["finale_triggered"])
    _watering_can_upgraded = bool(candidate["watering_can_upgraded"])
    _farm = _farm_array(candidate["farm"])
    _relationships = _relationship_array(candidate["relationships"])
    _pending_morning_summary = (
        candidate["pending_morning_summary"].duplicate(true)
        if candidate["pending_morning_summary"] != null
        else null
    )
    if _pending_morning_summary != null:
        var summary: Dictionary = _pending_morning_summary
        var next_weather := StringName(summary["next_weather"])
        summary["next_weather"] = GameRules.WEATHER_KEYS[
            GameRules.WEATHER_KEYS.find(next_weather)
        ]
        var shipments: Array = summary["shipments"]
        for line_value in shipments:
            var line: Dictionary = line_value
            var crop := StringName(line["crop"])
            line["crop"] = GameRules.CROP_KEYS[GameRules.CROP_KEYS.find(crop)]
    return true

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

func preview_selected_action(target_cell: Variant) -> Dictionary:
    var failure := _selected_action_failure(target_cell)
    var code := GameRules.CommandCode.NO_TARGET
    if failure != -1:
        code = failure
    else:
        match _selected_action:
            GameRules.FarmingAction.HOE:
                code = GameRules.CommandCode.SOIL_TILLED
            GameRules.FarmingAction.SEEDS:
                code = GameRules.CommandCode.CROP_PLANTED
            GameRules.FarmingAction.WATERING_CAN:
                code = GameRules.CommandCode.CROP_WATERED
            GameRules.FarmingAction.HANDS:
                code = GameRules.CommandCode.CROP_HARVESTED
    return {
        "code": code,
        "action": _selected_action,
        "crop": _preview_crop(target_cell),
        "cost": _cost_for(_selected_action),
    }

func _preview_crop(target_cell: Variant) -> Variant:
    match _selected_action:
        GameRules.FarmingAction.SEEDS:
            return _selected_seed
        GameRules.FarmingAction.WATERING_CAN, \
        GameRules.FarmingAction.HANDS:
            var index := _farm_index(target_cell)
            if index == -1:
                return null
            var crop: Variant = _farm[index]["crop"]
            return null if crop == null else (crop as Dictionary)["kind"]
        _:
            return null

func _cost_for(action: GameRules.FarmingAction) -> Dictionary:
    return GameRules.effective_action_cost(action, _watering_can_upgraded)

func _hoe_failure(target_cell: Variant) -> int:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var tile: Dictionary = _farm[_farm_index(target_cell)]
    if tile["crop"] != null:
        return GameRules.CommandCode.CROP_PRESENT
    if bool(tile["tilled"]):
        return GameRules.CommandCode.ALREADY_TILLED
    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        _cost_for(GameRules.FarmingAction.HOE),
    )
    return -1 if bool(budget["ok"]) else int(budget["code"])

func _plant_failure(target_cell: Variant) -> int:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var tile: Dictionary = _farm[_farm_index(target_cell)]
    if not bool(tile["tilled"]):
        return GameRules.CommandCode.SOIL_UNTILLED
    if tile["crop"] != null:
        return GameRules.CommandCode.CROP_PRESENT
    if _seed_counts[_selected_seed] == 0:
        return GameRules.CommandCode.NO_SELECTED_SEEDS
    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        _cost_for(GameRules.FarmingAction.SEEDS),
    )
    return -1 if bool(budget["ok"]) else int(budget["code"])

func _water_failure(target_cell: Variant) -> int:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var tile: Dictionary = _farm[_farm_index(target_cell)]
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
        _cost_for(GameRules.FarmingAction.WATERING_CAN),
    )
    return -1 if bool(budget["ok"]) else int(budget["code"])

func _harvest_failure(target_cell: Variant) -> int:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    var target_failure := _target_failure(target_cell)
    if target_failure != -1:
        return target_failure
    var tile: Dictionary = _farm[_farm_index(target_cell)]
    if tile["crop"] == null:
        return GameRules.CommandCode.NO_CROP
    var crop: Dictionary = tile["crop"]
    var kind: GameRules.CropKind = crop["kind"]
    if not GameRules.is_mature(kind, int(crop["growth"])):
        return GameRules.CommandCode.CROP_IMMATURE
    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        _cost_for(GameRules.FarmingAction.HANDS),
    )
    return -1 if bool(budget["ok"]) else int(budget["code"])

func _selected_action_failure(target_cell: Variant) -> int:
    match _selected_action:
        GameRules.FarmingAction.HOE:
            return _hoe_failure(target_cell)
        GameRules.FarmingAction.SEEDS:
            return _plant_failure(target_cell)
        GameRules.FarmingAction.WATERING_CAN:
            return _water_failure(target_cell)
        GameRules.FarmingAction.HANDS:
            return _harvest_failure(target_cell)
    assert(false, "unsupported farming action")
    return GameRules.CommandCode.NO_TARGET

func hoe(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _hoe_failure(target_cell)
    if failure != -1:
        return failure
    var index := _farm_index(target_cell)
    var tile: Dictionary = _farm[index]

    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        _cost_for(GameRules.FarmingAction.HOE),
    )
    if not bool(budget["ok"]):
        return budget["code"]

    tile["tilled"] = true
    _farm[index] = tile
    _commit_budget(budget)
    return _commit(GameRules.CommandCode.SOIL_TILLED)

func plant(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _plant_failure(target_cell)
    if failure != -1:
        return failure
    var index := _farm_index(target_cell)
    var tile: Dictionary = _farm[index]

    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        _cost_for(GameRules.FarmingAction.SEEDS),
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
    return _commit(GameRules.CommandCode.CROP_PLANTED)

func water(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _water_failure(target_cell)
    if failure != -1:
        return failure
    var index := _farm_index(target_cell)
    var tile: Dictionary = _farm[index]

    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        _cost_for(GameRules.FarmingAction.WATERING_CAN),
    )
    if not bool(budget["ok"]):
        return budget["code"]

    var crop: Dictionary = tile["crop"]
    crop["watered_today"] = true
    tile["crop"] = crop
    _farm[index] = tile
    _commit_budget(budget)
    return _commit(GameRules.CommandCode.CROP_WATERED)

func harvest(target_cell: Variant) -> GameRules.CommandCode:
    var failure := _harvest_failure(target_cell)
    if failure != -1:
        return failure
    var index := _farm_index(target_cell)
    var tile: Dictionary = _farm[index]

    var budget := GameRules.evaluate_action_budget(
        _time_minutes,
        _stamina,
        _cost_for(GameRules.FarmingAction.HANDS),
    )
    if not bool(budget["ok"]):
        return budget["code"]

    var crop: Dictionary = tile["crop"]
    var kind: GameRules.CropKind = crop["kind"]
    tile["crop"] = null
    _farm[index] = tile
    _harvested_counts[kind] += 1
    _commit_budget(budget)
    return _commit(GameRules.CommandCode.CROP_HARVESTED)

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
    return _commit(GameRules.CommandCode.SEEDS_PURCHASED)

func buy_watering_can_upgrade(target_cell: Variant) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    if not (target_cell is Vector2i) or target_cell != WorldContract.SHOP_CELL:
        return GameRules.CommandCode.NOT_AT_SHOP
    if _watering_can_upgraded:
        return GameRules.CommandCode.WATERING_CAN_ALREADY_UPGRADED
    if _money < GameRules.WATERING_CAN_UPGRADE_PRICE:
        return GameRules.CommandCode.INSUFFICIENT_FUNDS

    _money -= GameRules.WATERING_CAN_UPGRADE_PRICE
    _watering_can_upgraded = true
    return _commit(GameRules.CommandCode.WATERING_CAN_UPGRADED)

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
    return _commit(GameRules.CommandCode.CROP_DEPOSITED)

func _social_failure(code: GameRules.CommandCode) -> Dictionary:
    return {"code": code, "lines": [], "points_gained": 0, "gift_reaction": &"", "close_friend_sequence": false}

func _social_success(
    code: GameRules.CommandCode,
    lines: Array[String],
    points_gained: int,
    gift_reaction: StringName = &"",
    close_friend_sequence: bool = false,
) -> Dictionary:
    code = _commit(code)
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

    var is_rainy := _weather == GameRules.Weather.RAINY
    var has_settled_shipment := false
    for count in _shipped_counts:
        if count > 0:
            has_settled_shipment = true
            break
    var lines: Array[String] = [
        VillagerRules.ordinary_dialogue_line(villager_id, level, _day, is_rainy, has_settled_shipment)
    ]
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
    if _day == GameRules.MAX_DAY:
        return _complete_finale()

    var completed_day := _day
    var completed_weather := _weather
    var stamina_restored := GameRules.MAX_STAMINA - _stamina
    var next_weather := GameRules.weather_from_roll(float(_weather_roll.call()))

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

    var payout := _settle_pending_shipment()
    _day += 1
    _time_minutes = GameRules.DAY_START_MINUTES
    _stamina = GameRules.MAX_STAMINA
    _weather = next_weather
    _weather_history.append(GameRules.weather_key(next_weather))
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
    return _commit(GameRules.CommandCode.DAY_ADVANCED)

func trigger_harvest_finale(target_cell: Variant) -> GameRules.CommandCode:
    var active_failure := _active_day_failure()
    if active_failure != -1:
        return active_failure
    if _day != GameRules.MAX_DAY:
        return GameRules.CommandCode.MARKET_NOT_READY
    if not (target_cell is Vector2i) or target_cell != WorldContract.MARKET_CELL:
        return GameRules.CommandCode.NOT_AT_MARKET
    return _complete_finale()

func _complete_finale() -> GameRules.CommandCode:
    if _finale_triggered:
        return GameRules.CommandCode.FINALE_ALREADY_TRIGGERED
    _settle_pending_shipment()
    _finale_triggered = true
    return GameRules.CommandCode.FINALE_TRIGGERED

func _settle_pending_shipment() -> Dictionary:
    var payout := GameRules.shipment_payout(_counts_snapshot(_pending_shipment_counts))
    for kind in range(GameRules.CropKind.size()):
        _shipped_counts[kind] += _pending_shipment_counts[kind]
    _money += int(payout["total"])
    _pending_shipment_counts = [0, 0, 0]
    return payout

func acknowledge_morning_summary() -> GameRules.CommandCode:
    if _pending_morning_summary == null:
        return GameRules.CommandCode.NO_DAY_SUMMARY
    _pending_morning_summary = null
    return GameRules.CommandCode.DAY_STARTED

func advance_clock(minutes: int) -> bool:
    assert(minutes > 0)
    if minutes <= 0:
        return false
    if _active_day_failure() != -1:
        return false
    var previous := _time_minutes
    _time_minutes = mini(_time_minutes + minutes, GameRules.ACTION_CUTOFF_MINUTES)
    return _time_minutes > previous

func acknowledge_intro() -> GameRules.CommandCode:
    if _intro_acknowledged:
        return GameRules.CommandCode.INTRO_ALREADY_ACKNOWLEDGED
    _intro_acknowledged = true
    return GameRules.CommandCode.INTRO_ACKNOWLEDGED

func _active_day_failure() -> int:
    if _finale_triggered:
        return GameRules.CommandCode.FINALE_ALREADY_TRIGGERED
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

func _commit(code: GameRules.CommandCode) -> GameRules.CommandCode:
    var tutorial_id := ContentRules.tutorial_for_code(code)
    if tutorial_id != &"":
        _tutorial_progress[tutorial_id] = true
    return code

func _commit_budget(budget: Dictionary) -> void:
    _time_minutes = int(budget["time_minutes"])
    _stamina = int(budget["stamina"])

static func _counts_array(value: Dictionary) -> Array[int]:
    var result: Array[int] = []
    for kind in range(GameRules.CropKind.size()):
        var key := GameRules.crop_key(kind)
        var count_field := SessionStateValidator.named_dictionary_value(value, key, "crop count %s" % key)
        result.append(int(count_field["value"]))
    return result

static func _farm_array(value: Array) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in value.size():
        var source: Dictionary = value[index]
        var tile: Dictionary = {
            "cell": source["cell"],
            "tilled": source["tilled"],
            "crop": null,
        }
        if source["crop"] != null:
            var source_crop: Dictionary = source["crop"]
            tile["crop"] = {
                "kind": GameRules.CROP_KEYS.find(StringName(source_crop["kind"])),
                "growth": int(source_crop["growth"]),
                "watered_today": source_crop["watered_today"],
            }
        result.append(tile)
    return result

static func _relationship_array(value: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for id in range(VillagerRules.VillagerId.size()):
        var key := VillagerRules.villager_key(id)
        var relationship_field := SessionStateValidator.named_dictionary_value(
            value,
            key,
            "relationship %s" % key,
        )
        var source: Dictionary = relationship_field["value"]
        result.append({
            "points": int(source["points"]),
            "talked_today": source["talked_today"],
            "gifted_today": source["gifted_today"],
            "close_friend_dialogue_seen": source["close_friend_dialogue_seen"],
        })
    return result

func _counts_snapshot(counts: Array[int]) -> Dictionary:
    var result: Dictionary = {}
    for kind in range(GameRules.CropKind.size()):
        result[GameRules.crop_key(kind)] = counts[kind]
    return result

func _relationships_state() -> Dictionary:
    var result: Dictionary = {}
    for id in range(VillagerRules.VillagerId.size()):
        var relationship: Dictionary = _relationships[id]
        result[VillagerRules.villager_key(id)] = {
            "points": relationship["points"],
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
