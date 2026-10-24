class_name SessionStateValidator
extends RefCounted

static func state_error(candidate: Variant) -> String:
    var state_result := _dictionary(candidate, "state")
    if not bool(state_result["ok"]):
        return String(state_result["error"])
    var state: Dictionary = state_result["value"]

    var day_field := _field(state, "day", "day")
    if not bool(day_field["ok"]):
        return String(day_field["error"])
    var day_result := _whole_int(day_field["value"], "day")
    if not bool(day_result["ok"]):
        return String(day_result["error"])
    var day := int(day_result["value"])
    if day < 1 or day > GameRules.MAX_DAY:
        return "day is out of range"

    var time_field := _field(state, "time_minutes", "time_minutes")
    if not bool(time_field["ok"]):
        return String(time_field["error"])
    var time_result := _whole_int(time_field["value"], "time_minutes")
    if not bool(time_result["ok"]):
        return String(time_result["error"])
    var time_minutes := int(time_result["value"])
    if time_minutes < GameRules.DAY_START_MINUTES or time_minutes > GameRules.ACTION_CUTOFF_MINUTES:
        return "time_minutes is out of range"

    var stamina_field := _field(state, "stamina", "stamina")
    if not bool(stamina_field["ok"]):
        return String(stamina_field["error"])
    var stamina_result := _whole_int(stamina_field["value"], "stamina")
    if not bool(stamina_result["ok"]):
        return String(stamina_result["error"])
    var stamina := int(stamina_result["value"])
    if stamina < 0 or stamina > GameRules.MAX_STAMINA:
        return "stamina is out of range"

    var weather_field := _field(state, "weather", "weather")
    if not bool(weather_field["ok"]):
        return String(weather_field["error"])
    var weather_result := _named(weather_field["value"], GameRules.WEATHER_KEYS, "weather")
    if not bool(weather_result["ok"]):
        return String(weather_result["error"])

    var weather_history_field := _field(state, "weather_history", "weather_history")
    if not bool(weather_history_field["ok"]):
        return String(weather_history_field["error"])
    var weather_history_result := _array(
        weather_history_field["value"],
        "weather_history",
    )
    if not bool(weather_history_result["ok"]):
        return String(weather_history_result["error"])
    var weather_history: Array = weather_history_result["value"]
    if weather_history.size() != day:
        return "weather_history must contain one entry per day"
    for index in weather_history.size():
        var history_weather := _named(
            weather_history[index],
            GameRules.WEATHER_KEYS,
            "weather_history[%d]" % index,
        )
        if not bool(history_weather["ok"]):
            return String(history_weather["error"])
        if (
            index == weather_history.size() - 1
            and history_weather["value"] != weather_result["value"]
        ):
            return "weather_history final entry must match weather"

    var action_field := _field(state, "selected_action", "selected_action")
    if not bool(action_field["ok"]):
        return String(action_field["error"])
    var action_result := _named(action_field["value"], GameRules.ACTION_KEYS, "selected_action")
    if not bool(action_result["ok"]):
        return String(action_result["error"])

    var seed_field := _field(state, "selected_seed", "selected_seed")
    if not bool(seed_field["ok"]):
        return String(seed_field["error"])
    var seed_result := _named(seed_field["value"], GameRules.CROP_KEYS, "selected_seed")
    if not bool(seed_result["ok"]):
        return String(seed_result["error"])

    var money_field := _field(state, "money", "money")
    if not bool(money_field["ok"]):
        return String(money_field["error"])
    var money_result := _whole_int(money_field["value"], "money")
    if not bool(money_result["ok"]):
        return String(money_result["error"])
    if int(money_result["value"]) < 0:
        return "money must be non-negative"

    var seeds_field := _field(state, "seeds", "seeds")
    if not bool(seeds_field["ok"]):
        return String(seeds_field["error"])
    var seeds_result := _dictionary(seeds_field["value"], "seeds")
    if not bool(seeds_result["ok"]):
        return String(seeds_result["error"])
    var seeds_error := _counts_state_error(seeds_result["value"])
    if seeds_error != "":
        return seeds_error

    var harvested_field := _field(state, "harvested", "harvested")
    if not bool(harvested_field["ok"]):
        return String(harvested_field["error"])
    var harvested_result := _dictionary(harvested_field["value"], "harvested")
    if not bool(harvested_result["ok"]):
        return String(harvested_result["error"])
    var harvested_error := _counts_state_error(harvested_result["value"])
    if harvested_error != "":
        return harvested_error

    var pending_shipment_field := _field(state, "pending_shipment", "pending_shipment")
    if not bool(pending_shipment_field["ok"]):
        return String(pending_shipment_field["error"])
    var pending_shipment_result := _dictionary(
        pending_shipment_field["value"],
        "pending_shipment",
    )
    if not bool(pending_shipment_result["ok"]):
        return String(pending_shipment_result["error"])
    var pending_shipment_error := _counts_state_error(pending_shipment_result["value"])
    if pending_shipment_error != "":
        return pending_shipment_error

    var intro_field := _field(state, "intro_acknowledged", "intro_acknowledged")
    if not bool(intro_field["ok"]):
        return String(intro_field["error"])
    if not (intro_field["value"] is bool):
        return "intro_acknowledged must be a boolean"

    var tutorial_field := _field(state, "tutorial", "tutorial")
    if not bool(tutorial_field["ok"]):
        return String(tutorial_field["error"])
    var tutorial_result := _dictionary(tutorial_field["value"], "tutorial")
    if not bool(tutorial_result["ok"]):
        return String(tutorial_result["error"])
    var tutorial_error := _tutorial_state_error(tutorial_result["value"])
    if tutorial_error != "":
        return tutorial_error

    var shipped_field := _field(state, "shipped", "shipped")
    if not bool(shipped_field["ok"]):
        return String(shipped_field["error"])
    var shipped_result := _dictionary(shipped_field["value"], "shipped")
    if not bool(shipped_result["ok"]):
        return String(shipped_result["error"])
    var shipped_error := _counts_state_error(shipped_result["value"])
    if shipped_error != "":
        return shipped_error

    var farm_field := _field(state, "farm", "farm")
    if not bool(farm_field["ok"]):
        return String(farm_field["error"])
    var farm_result := _array(farm_field["value"], "farm")
    if not bool(farm_result["ok"]):
        return String(farm_result["error"])
    var farm_error := _farm_state_error(farm_result["value"])
    if farm_error != "":
        return farm_error

    var relationships_field := _field(state, "relationships", "relationships")
    if not bool(relationships_field["ok"]):
        return String(relationships_field["error"])
    var relationships_result := _dictionary(
        relationships_field["value"],
        "relationships",
    )
    if not bool(relationships_result["ok"]):
        return String(relationships_result["error"])
    var relationships_error := _relationship_state_error(relationships_result["value"])
    if relationships_error != "":
        return relationships_error

    var summary_field := _field(
        state,
        "pending_morning_summary",
        "pending_morning_summary",
    )
    if not bool(summary_field["ok"]):
        return String(summary_field["error"])
    var summary_error := _morning_summary_state_error(summary_field["value"], state)
    if summary_error != "":
        return summary_error
    var watering_field := _field(state, "watering_can_upgraded", "watering_can_upgraded")
    if not bool(watering_field["ok"]):
        return String(watering_field["error"])
    if not (watering_field["value"] is bool):
        return "watering_can_upgraded must be a boolean"
    return _finale_state_error(state)

static func _field(map: Dictionary, key: String, label: String) -> Dictionary:
    if not map.has(key):
        return {"ok": false, "error": "%s is missing" % label}
    return {"ok": true, "value": map[key]}

static func _dictionary(value: Variant, label: String) -> Dictionary:
    if not (value is Dictionary):
        return {"ok": false, "error": "%s must be a Dictionary" % label}
    return {"ok": true, "value": value}

static func _array(value: Variant, label: String) -> Dictionary:
    if not (value is Array):
        return {"ok": false, "error": "%s must be an Array" % label}
    return {"ok": true, "value": value}

static func _whole_int(value: Variant, label: String) -> Dictionary:
    if not (value is int or value is float):
        return {"ok": false, "error": "%s must be an integer" % label}
    var number := float(value)
    if not is_finite(number) or number != floor(number):
        return {"ok": false, "error": "%s must be an integer" % label}
    return {"ok": true, "value": int(number)}

static func _named(value: Variant, allowed: Array[StringName], label: String) -> Dictionary:
    if not (value is String or value is StringName):
        return {"ok": false, "error": "%s must be a name" % label}
    var key := StringName(value)
    if allowed.find(key) < 0:
        return {"ok": false, "error": "%s is unknown" % label}
    return {"ok": true, "value": key}

static func named_dictionary_value(map: Dictionary, key: StringName, label: String) -> Dictionary:
    if map.has(key):
        return {"ok": true, "value": map[key]}
    var string_key := String(key)
    if map.has(string_key):
        return {"ok": true, "value": map[string_key]}
    return {"ok": false, "error": "%s is missing" % label}

static func _counts_state_error(value: Dictionary) -> String:
    if value.size() != GameRules.CROP_KEYS.size():
        return "crop counts must contain exactly the crop keys"
    for kind in range(GameRules.CropKind.size()):
        var key := GameRules.crop_key(kind)
        var count_field := named_dictionary_value(value, key, "crop count %s" % key)
        if not bool(count_field["ok"]):
            return String(count_field["error"])
        var count_result := _whole_int(count_field["value"], "crop count %s" % key)
        if not bool(count_result["ok"]):
            return String(count_result["error"])
        if int(count_result["value"]) < 0:
            return "crop count %s must be non-negative" % key
    return ""

static func _tutorial_state_error(value: Dictionary) -> String:
    if value.size() != ContentRules.tutorial_keys().size():
        return "tutorial must contain exactly the tutorial keys"
    for id in ContentRules.tutorial_keys():
        var field := named_dictionary_value(value, id, "tutorial %s" % id)
        if not bool(field["ok"]):
            return String(field["error"])
        if not (field["value"] is bool):
            return "tutorial %s must be a boolean" % id
    return ""

static func _finale_state_error(state: Dictionary) -> String:
    var finale_field := _field(state, "finale_triggered", "finale_triggered")
    if not bool(finale_field["ok"]):
        return String(finale_field["error"])
    if not (finale_field["value"] is bool):
        return "finale_triggered must be a boolean"
    if not bool(finale_field["value"]):
        return ""
    if int(state["day"]) < GameRules.MAX_DAY:
        return "finale_triggered requires the final day"
    if state["pending_morning_summary"] != null:
        return "finale_triggered cannot leave a pending morning summary"
    for kind in range(GameRules.CropKind.size()):
        var key := GameRules.crop_key(kind)
        var count_field := named_dictionary_value(
            state["pending_shipment"],
            key,
            "crop count %s" % key,
        )
        if int(count_field["value"]) > 0:
            return "finale_triggered cannot leave a pending shipment"
    return ""

static func _farm_state_error(value: Array) -> String:
    var expected_cells := WorldContract.farm_cells()
    if value.size() != expected_cells.size():
        return "farm must contain exactly the authored farm cells"
    for index in value.size():
        var tile_result := _dictionary(value[index], "farm[%d]" % index)
        if not bool(tile_result["ok"]):
            return String(tile_result["error"])
        var tile: Dictionary = tile_result["value"]
        if tile.size() != 3:
            return "farm[%d] has an invalid shape" % index

        var cell_field := _field(tile, "cell", "farm[%d].cell" % index)
        if not bool(cell_field["ok"]):
            return String(cell_field["error"])
        if not (cell_field["value"] is Vector2i):
            return "farm[%d].cell must be a Vector2i" % index
        if cell_field["value"] != expected_cells[index]:
            return "farm[%d].cell does not match the authored farm order" % index

        var tilled_field := _field(tile, "tilled", "farm[%d].tilled" % index)
        if not bool(tilled_field["ok"]):
            return String(tilled_field["error"])
        if not (tilled_field["value"] is bool):
            return "farm[%d].tilled must be a boolean" % index

        var crop_field := _field(tile, "crop", "farm[%d].crop" % index)
        if not bool(crop_field["ok"]):
            return String(crop_field["error"])
        if crop_field["value"] == null:
            continue
        var crop_result := _dictionary(crop_field["value"], "farm[%d].crop" % index)
        if not bool(crop_result["ok"]):
            return String(crop_result["error"])
        var crop: Dictionary = crop_result["value"]
        if crop.size() != 3:
            return "farm[%d].crop has an invalid shape" % index

        var kind_field := _field(crop, "kind", "farm[%d].crop.kind" % index)
        if not bool(kind_field["ok"]):
            return String(kind_field["error"])
        var kind_result := _named(
            kind_field["value"],
            GameRules.CROP_KEYS,
            "farm[%d].crop.kind" % index,
        )
        if not bool(kind_result["ok"]):
            return String(kind_result["error"])
        var kind := GameRules.CROP_KEYS.find(StringName(kind_result["value"]))

        var growth_field := _field(crop, "growth", "farm[%d].crop.growth" % index)
        if not bool(growth_field["ok"]):
            return String(growth_field["error"])
        var growth_result := _whole_int(
            growth_field["value"],
            "farm[%d].crop.growth" % index,
        )
        if not bool(growth_result["ok"]):
            return String(growth_result["error"])
        var growth := int(growth_result["value"])
        if growth < 0 or growth > GameRules.growth_nights(kind):
            return "farm[%d].crop.growth is out of range" % index

        var watered_field := _field(
            crop,
            "watered_today",
            "farm[%d].crop.watered_today" % index,
        )
        if not bool(watered_field["ok"]):
            return String(watered_field["error"])
        if not (watered_field["value"] is bool):
            return "farm[%d].crop.watered_today must be a boolean" % index
        if not bool(tilled_field["value"]):
            return "farm[%d] cannot contain a crop on untilled soil" % index
    return ""

static func _relationship_state_error(value: Dictionary) -> String:
    if value.size() != VillagerRules.VILLAGER_KEYS.size():
        return "relationships must contain exactly the villager keys"
    for id in range(VillagerRules.VillagerId.size()):
        var key := VillagerRules.villager_key(id)
        var relationship_field := named_dictionary_value(
            value,
            key,
            "relationship %s" % key,
        )
        if not bool(relationship_field["ok"]):
            return String(relationship_field["error"])
        var relationship_result := _dictionary(
            relationship_field["value"],
            "relationship %s" % key,
        )
        if not bool(relationship_result["ok"]):
            return String(relationship_result["error"])
        var relationship: Dictionary = relationship_result["value"]
        if relationship.size() != 4:
            return "relationship %s has an invalid shape" % key

        var points_field := _field(relationship, "points", "relationship %s.points" % key)
        if not bool(points_field["ok"]):
            return String(points_field["error"])
        var points_result := _whole_int(
            points_field["value"],
            "relationship %s.points" % key,
        )
        if not bool(points_result["ok"]):
            return String(points_result["error"])
        if int(points_result["value"]) < 0:
            return "relationship %s.points must be non-negative" % key

        for field_name in ["talked_today", "gifted_today", "close_friend_dialogue_seen"]:
            var flag_field := _field(
                relationship,
                field_name,
                "relationship %s.%s" % [key, field_name],
            )
            if not bool(flag_field["ok"]):
                return String(flag_field["error"])
            if not (flag_field["value"] is bool):
                return "relationship %s.%s must be a boolean" % [key, field_name]
    return ""

static func _morning_summary_state_error(value: Variant, state: Dictionary) -> String:
    if value == null:
        return ""
    var summary_result := _dictionary(value, "pending_morning_summary")
    if not bool(summary_result["ok"]):
        return String(summary_result["error"])
    var summary: Dictionary = summary_result["value"]
    if summary.size() != 8:
        return "pending_morning_summary has an invalid shape"

    var completed_day_field := _field(summary, "completed_day", "completed_day")
    if not bool(completed_day_field["ok"]):
        return String(completed_day_field["error"])
    var completed_day_result := _whole_int(
        completed_day_field["value"],
        "completed_day",
    )
    if not bool(completed_day_result["ok"]):
        return String(completed_day_result["error"])
    var completed_day := int(completed_day_result["value"])
    if completed_day < 1 or completed_day >= GameRules.MAX_DAY:
        return "completed_day is out of range"

    var next_day_field := _field(summary, "next_day", "next_day")
    if not bool(next_day_field["ok"]):
        return String(next_day_field["error"])
    var next_day_result := _whole_int(next_day_field["value"], "next_day")
    if not bool(next_day_result["ok"]):
        return String(next_day_result["error"])
    var next_day := int(next_day_result["value"])
    if next_day < 1 or next_day > GameRules.MAX_DAY:
        return "next_day is out of range"

    var state_day_field := _field(state, "day", "day")
    if not bool(state_day_field["ok"]):
        return String(state_day_field["error"])
    var state_day_result := _whole_int(state_day_field["value"], "day")
    if not bool(state_day_result["ok"]):
        return String(state_day_result["error"])
    if next_day != int(state_day_result["value"]):
        return "pending_morning_summary.next_day does not match day"
    if completed_day != next_day - 1:
        return "pending_morning_summary.completed_day does not precede next_day"

    var crops_advanced_field := _field(summary, "crops_advanced", "crops_advanced")
    if not bool(crops_advanced_field["ok"]):
        return String(crops_advanced_field["error"])
    var crops_advanced_result := _whole_int(
        crops_advanced_field["value"],
        "crops_advanced",
    )
    if not bool(crops_advanced_result["ok"]):
        return String(crops_advanced_result["error"])
    if int(crops_advanced_result["value"]) < 0 or int(crops_advanced_result["value"]) > WorldContract.farm_cells().size():
        return "crops_advanced is out of range"

    var next_weather_field := _field(summary, "next_weather", "next_weather")
    if not bool(next_weather_field["ok"]):
        return String(next_weather_field["error"])
    var next_weather_result := _named(
        next_weather_field["value"],
        GameRules.WEATHER_KEYS,
        "next_weather",
    )
    if not bool(next_weather_result["ok"]):
        return String(next_weather_result["error"])
    var state_weather_field := _field(state, "weather", "weather")
    if not bool(state_weather_field["ok"]):
        return String(state_weather_field["error"])
    var state_weather_result := _named(
        state_weather_field["value"],
        GameRules.WEATHER_KEYS,
        "weather",
    )
    if not bool(state_weather_result["ok"]):
        return String(state_weather_result["error"])
    if StringName(next_weather_result["value"]) != StringName(state_weather_result["value"]):
        return "pending_morning_summary.next_weather does not match weather"

    var stamina_restored_field := _field(summary, "stamina_restored", "stamina_restored")
    if not bool(stamina_restored_field["ok"]):
        return String(stamina_restored_field["error"])
    var stamina_restored_result := _whole_int(
        stamina_restored_field["value"],
        "stamina_restored",
    )
    if not bool(stamina_restored_result["ok"]):
        return String(stamina_restored_result["error"])
    if int(stamina_restored_result["value"]) < 0 or int(stamina_restored_result["value"]) > GameRules.MAX_STAMINA:
        return "stamina_restored is out of range"

    var shipments_field := _field(summary, "shipments", "shipments")
    if not bool(shipments_field["ok"]):
        return String(shipments_field["error"])
    var shipments_result := _array(shipments_field["value"], "shipments")
    if not bool(shipments_result["ok"]):
        return String(shipments_result["error"])
    var shipments: Array = shipments_result["value"]
    for index in shipments.size():
        var line_result := _dictionary(shipments[index], "shipments[%d]" % index)
        if not bool(line_result["ok"]):
            return String(line_result["error"])
        var line: Dictionary = line_result["value"]
        if line.size() != 3:
            return "shipments[%d] has an invalid shape" % index

        var crop_field := _field(line, "crop", "shipments[%d].crop" % index)
        if not bool(crop_field["ok"]):
            return String(crop_field["error"])
        var crop_result := _named(
            crop_field["value"],
            GameRules.CROP_KEYS,
            "shipments[%d].crop" % index,
        )
        if not bool(crop_result["ok"]):
            return String(crop_result["error"])

        var quantity_field := _field(line, "quantity", "shipments[%d].quantity" % index)
        if not bool(quantity_field["ok"]):
            return String(quantity_field["error"])
        var quantity_result := _whole_int(
            quantity_field["value"],
            "shipments[%d].quantity" % index,
        )
        if not bool(quantity_result["ok"]):
            return String(quantity_result["error"])
        if int(quantity_result["value"]) < 0:
            return "shipments[%d].quantity must be non-negative" % index

        var amount_field := _field(line, "amount", "shipments[%d].amount" % index)
        if not bool(amount_field["ok"]):
            return String(amount_field["error"])
        var amount_result := _whole_int(
            amount_field["value"],
            "shipments[%d].amount" % index,
        )
        if not bool(amount_result["ok"]):
            return String(amount_result["error"])
        if int(amount_result["value"]) < 0:
            return "shipments[%d].amount must be non-negative" % index

    var shipping_income_field := _field(summary, "shipping_income", "shipping_income")
    if not bool(shipping_income_field["ok"]):
        return String(shipping_income_field["error"])
    var shipping_income_result := _whole_int(
        shipping_income_field["value"],
        "shipping_income",
    )
    if not bool(shipping_income_result["ok"]):
        return String(shipping_income_result["error"])
    if int(shipping_income_result["value"]) < 0:
        return "shipping_income must be non-negative"

    var money_after_shipping_field := _field(
        summary,
        "money_after_shipping",
        "money_after_shipping",
    )
    if not bool(money_after_shipping_field["ok"]):
        return String(money_after_shipping_field["error"])
    var money_after_shipping_result := _whole_int(
        money_after_shipping_field["value"],
        "money_after_shipping",
    )
    if not bool(money_after_shipping_result["ok"]):
        return String(money_after_shipping_result["error"])
    var state_money_field := _field(state, "money", "money")
    if not bool(state_money_field["ok"]):
        return String(state_money_field["error"])
    var state_money_result := _whole_int(state_money_field["value"], "money")
    if not bool(state_money_result["ok"]):
        return String(state_money_result["error"])
    if int(money_after_shipping_result["value"]) != int(state_money_result["value"]):
        return "pending_morning_summary.money_after_shipping does not match money"
    return ""
