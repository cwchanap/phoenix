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
    state["max_stamina"] = GameRules.MAX_STAMINA
    var error := GameSession.state_error(state)
    assert(error == "", "invalid HUD fixture state: %s" % error)
    return state
