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

static func state_for(name: String) -> Dictionary:
    match name:
        "01-hud":
            return hud_state()
        "02-seed-shop":
            return shop_state()
        "03-shipping-day14":
            return shipping_state()
        _:
            assert(false, "unsupported fixture state: %s" % name)
            return {}
