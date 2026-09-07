class_name UiFixtureFactory
extends RefCounted

static func hud_state() -> Dictionary:
    var state := GameSession.new().state()
    state["day"] = 3
    state["time_minutes"] = 560
    state["stamina"] = 14
    state["weather"] = GameRules.weather_key(GameRules.Weather.SUNNY)
    state["weather_history"] = [
        GameRules.weather_key(GameRules.Weather.SUNNY),
        GameRules.weather_key(GameRules.Weather.SUNNY),
        GameRules.weather_key(GameRules.Weather.SUNNY),
    ]
    state["selected_action"] = GameRules.action_key(GameRules.FarmingAction.HOE)
    state["selected_seed"] = GameRules.crop_key(GameRules.CropKind.TURNIP)
    state["money"] = 150
    state["seeds"] = {&"turnip": 3, &"potato": 0, &"pumpkin": 0}
    state["harvested"] = {&"turnip": 2, &"potato": 0, &"pumpkin": 0}
    state["pending_shipment"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    state["intro_acknowledged"] = true
    state["tutorial"] = ContentRules.initial_tutorial_progress()
    state["shipped"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    state["finale_triggered"] = false
    var error := GameSession.state_error(state)
    assert(error == "", "invalid HUD fixture state: %s" % error)
    return state

static func shop_state() -> Dictionary:
    var state := hud_state()
    state["money"] = 150
    state["seeds"] = {&"turnip": 3, &"potato": 0, &"pumpkin": 0}
    var error := GameSession.state_error(state)
    assert(error == "", "invalid shop fixture state: %s" % error)
    return state

static func shipping_state() -> Dictionary:
    var state := hud_state()
    state["day"] = GameRules.MAX_DAY
    state["weather_history"] = []
    for _day in GameRules.MAX_DAY:
        state["weather_history"].append(GameRules.weather_key(GameRules.Weather.SUNNY))
    state["harvested"] = {&"turnip": 7, &"potato": 0, &"pumpkin": 0}
    state["pending_shipment"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    var error := GameSession.state_error(state)
    assert(error == "", "invalid shipping fixture state: %s" % error)
    return state

static func bag_state() -> Dictionary:
    var state := hud_state()
    state["seeds"] = {&"turnip": 3, &"potato": 0, &"pumpkin": 0}
    state["harvested"] = {&"turnip": 7, &"potato": 2, &"pumpkin": 0}
    state["pending_shipment"] = {&"turnip": 4, &"potato": 0, &"pumpkin": 0}
    var error := GameSession.state_error(state)
    assert(error == "", "invalid bag fixture state: %s" % error)
    return state

static func almanac_state() -> Dictionary:
    var state := hud_state()
    var error := GameSession.state_error(state)
    assert(error == "", "invalid almanac fixture state: %s" % error)
    return state

static func calendar_state() -> Dictionary:
    var state := hud_state()
    state["weather_history"] = [&"sunny", &"rainy", &"sunny"]
    var farm: Array = state["farm"]
    farm[0]["tilled"] = true
    farm[0]["crop"] = {
        "kind": GameRules.crop_key(GameRules.CropKind.TURNIP),
        "growth": 0,
        "watered_today": false,
    }
    farm[1]["tilled"] = true
    farm[1]["crop"] = {
        "kind": GameRules.crop_key(GameRules.CropKind.PUMPKIN),
        "growth": 1,
        "watered_today": false,
    }
    state["farm"] = farm
    var error := GameSession.state_error(state)
    assert(error == "", "invalid calendar fixture state: %s" % error)
    return state

static func dialogue_state() -> Dictionary:
    var state := hud_state()
    state["harvested"] = {&"turnip": 7, &"potato": 2, &"pumpkin": 0}
    var relationships: Dictionary = state["relationships"]
    relationships[&"shopkeeper"]["points"] = 13
    relationships[&"shopkeeper"]["talked_today"] = true
    state["relationships"] = relationships
    var error := GameSession.state_error(state)
    assert(error == "", "invalid dialogue fixture state: %s" % error)
    return state

static func dialogue_result() -> Dictionary:
    return {
        "code": GameRules.CommandCode.VILLAGER_TALKED,
        "lines": [VillagerRules.dialogue_line(
            VillagerRules.VillagerId.SHOPKEEPER,
            VillagerRules.RelationshipLevel.FRIEND,
        )],
        "points_gained": 1,
        "gift_reaction": &"",
        "close_friend_sequence": false,
        "selected_crop_kind": GameRules.CropKind.POTATO,
    }

static func morning_summary_state() -> Dictionary:
    var state := hud_state()
    state["day"] = 4
    state["weather"] = GameRules.weather_key(GameRules.Weather.RAINY)
    state["weather_history"] = [
        GameRules.weather_key(GameRules.Weather.SUNNY),
        GameRules.weather_key(GameRules.Weather.SUNNY),
        GameRules.weather_key(GameRules.Weather.SUNNY),
        GameRules.weather_key(GameRules.Weather.RAINY),
    ]
    state["stamina"] = GameRules.MAX_STAMINA
    state["money"] = 220
    state["pending_morning_summary"] = {
        "completed_day": 3,
        "next_day": 4,
        "crops_advanced": 2,
        "next_weather": GameRules.weather_key(GameRules.Weather.RAINY),
        "stamina_restored": GameRules.MAX_STAMINA,
        "shipments": [{"crop": &"turnip", "quantity": 2, "amount": 70}],
        "shipping_income": 70,
        "money_after_shipping": 220,
    }
    var error := GameSession.state_error(state)
    assert(error == "", "invalid morning summary fixture state: %s" % error)
    return state

static func sleep_state() -> Dictionary:
    var state := hud_state()
    state["day"] = GameRules.MAX_DAY
    state["weather_history"] = []
    for _day in GameRules.MAX_DAY:
        state["weather_history"].append(GameRules.weather_key(GameRules.Weather.SUNNY))
    var error := GameSession.state_error(state)
    assert(error == "", "invalid sleep fixture state: %s" % error)
    return state

static func intro_state() -> Dictionary:
    var state := hud_state()
    state["intro_acknowledged"] = false
    var error := GameSession.state_error(state)
    assert(error == "", "invalid intro fixture state: %s" % error)
    return state

static func result_state() -> Dictionary:
    var state := hud_state()
    state["day"] = GameRules.MAX_DAY
    state["weather_history"] = []
    for _day in GameRules.MAX_DAY:
        state["weather_history"].append(GameRules.weather_key(GameRules.Weather.SUNNY))
    state["shipped"] = {&"turnip": 4, &"potato": 3, &"pumpkin": 2}
    state["pending_shipment"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    state["pending_morning_summary"] = null
    state["money"] = 505
    var relationships: Dictionary = state["relationships"]
    relationships[&"shopkeeper"]["points"] = VillagerRules.FRIEND_POINTS
    relationships[&"resident"]["points"] = VillagerRules.CLOSE_FRIEND_POINTS
    state["relationships"] = relationships
    state["finale_triggered"] = true
    var error := GameSession.state_error(state)
    assert(error == "", "invalid result fixture state: %s" % error)
    var result := ContentRules.build_harvest_result(state)
    assert(result["shipped_count"] == 9, "result fixture must ship nine crops")
    assert(result["shipped_value"] == 645, "result fixture must ship 645G")
    assert(result["tier"] == &"heart_of_harvest", "result fixture must reach heart tier")
    assert(result["villager"] == "June", "result fixture must feature June")
    return state

static func state_for(name: String) -> Dictionary:
    match name:
        "01-hud":
            return hud_state()
        "02-seed-shop":
            return shop_state()
        "03-shipping-day14":
            return shipping_state()
        "04-bag":
            return bag_state()
        "05-almanac":
            return almanac_state()
        "06-calendar":
            return calendar_state()
        "07-dialogue":
            return dialogue_state()
        "08-morning-summary":
            return morning_summary_state()
        "09-sleep":
            return sleep_state()
        "10-pause", "11-settings":
            return hud_state()
        "12-intro":
            return intro_state()
        "13-title":
            return hud_state()
        "14-result-heart-of-harvest":
            return result_state()
        _:
            assert(false, "unsupported fixture state: %s" % name)
            return {}
