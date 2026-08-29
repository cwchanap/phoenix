class_name GameHud
extends CanvasLayer

signal select_action_requested(action: int)
signal select_seed_requested(kind: int)
signal buy_requested(kind: int, quantity: int)
signal deposit_requested(kind: int, quantity: int)
signal sleep_requested
signal gift_requested(villager_id: int, crop_kind: int)
signal morning_summary_acknowledged
signal intro_acknowledged
signal modal_state_changed

const SUNNY_TINT := Color(1.0, 0.96, 0.86, 0.03)
const RAINY_TINT := Color(0.38, 0.52, 0.72, 0.12)

var _root: Control
var _weather_tint: ColorRect
var _day_label: Label
var _time_label: Label
var _weather_label: Label
var _stamina_label: Label
var _money_label: Label
var _selected_seed_label: Label
var _pending_shipment_label: Label
var _interaction_hint: Label
var _feedback: Label
var _summary_body: Label
var _save_status_label: Label
var _shop_panel: Control
var _shipping_panel: Control
var _sleep_panel: Control
var _dialogue_panel: DialoguePanel
var _onboarding_overlay: OnboardingOverlay
var _morning_summary_panel: Control
var _pause_help_panel: Control
var _day14_shipping_boundary: Label
var _day14_sleep_boundary: Label
var _objective_label: Label
var _action_buttons: Array[Button] = []
var _seed_buttons: Array[Button] = []
var _seed_count_labels: Array[Label] = []
var _harvested_count_labels: Array[Label] = []
var _shop_count_labels: Array[Label] = []
var _shipping_count_labels: Array[Label] = []
var _last_snapshot: Dictionary = {}
var _selected_action: StringName = GameRules.action_key(GameRules.FarmingAction.HOE)
var _selected_seed: StringName = GameRules.crop_key(GameRules.CropKind.TURNIP)

func _ready() -> void:
    _root = $HudRoot as Control
    _build_always_visible_hud()
    _build_modals()
    modal_state_changed.connect(_update_toggle_enabled)

func render(snapshot: Dictionary) -> void:
    _last_snapshot = snapshot.duplicate(true)
    _onboarding_overlay.render(snapshot)
    _weather_tint.color = (
        RAINY_TINT
        if snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)
        else SUNNY_TINT
    )
    _day_label.text = "Day %d" % int(snapshot["day"])
    _time_label.text = GameRules.format_time(int(snapshot["time_minutes"]))
    _weather_label.text = "Weather: %s" % _display_weather(snapshot["weather"])
    _stamina_label.text = "Stamina: %d/%d" % [int(snapshot["stamina"]), int(snapshot["max_stamina"])]
    _money_label.text = "Money: %dG" % int(snapshot["money"])

    _selected_action = snapshot["selected_action"]
    _selected_seed = snapshot["selected_seed"]
    _refresh_action_selection()
    _refresh_seed_selection()

    var seeds: Dictionary = snapshot["seeds"]
    var harvested: Dictionary = snapshot["harvested"]
    var pending: Dictionary = snapshot["pending_shipment"]
    var pending_total := 0
    for kind in range(GameRules.CropKind.size()):
        var key := GameRules.crop_key(kind)
        _seed_count_labels[kind].text = "%d" % int(seeds.get(key, 0))
        _harvested_count_labels[kind].text = "%d" % int(harvested.get(key, 0))
        _shop_count_labels[kind].text = "%dG · %d seeds" % [
            GameRules.seed_price(kind),
            int(seeds.get(key, 0)),
        ]
        _shipping_count_labels[kind].text = "%d harvested" % int(harvested.get(key, 0))
        pending_total += int(pending.get(key, 0))
    _pending_shipment_label.text = "Pending shipment: %d" % pending_total

    var day := int(snapshot["day"])
    if day >= GameRules.MAX_DAY:
        _objective_label.text = "Harvest Market today — ship crops first, then visit the village path stall."
    else:
        _objective_label.text = "Harvest Market: Day 14 · %d days left" % (GameRules.MAX_DAY - day)
    _day14_shipping_boundary.text = (
        "Day 14: only crops deposited here count toward the finale."
        if day == GameRules.MAX_DAY
        else ""
    )
    _day14_sleep_boundary.text = (
        "Day 14: sleeping ends the run and settles the shipping bin."
        if day == GameRules.MAX_DAY
        else ""
    )

    var summary: Variant = snapshot["pending_morning_summary"]
    _set_morning_summary_visible(summary != null)
    if summary != null:
        _render_morning_summary(summary)

func has_blocking_modal() -> bool:
    return (
        _shop_panel.visible
        or _shipping_panel.visible
        or _sleep_panel.visible
        or _dialogue_panel.visible
        or _morning_summary_panel.visible
        or _onboarding_overlay.is_opening_visible()
        or _pause_help_panel.visible
    )

func set_save_status(status: StringName, message: String = "") -> void:
    match status:
        &"idle":
            _save_status_label.text = ""
        &"saved":
            _save_status_label.text = "Saved."
        &"error":
            _save_status_label.text = message
        _:
            assert(false, "unknown save status")

func set_interaction_hint(text: String) -> void:
    _interaction_hint.text = text

func open_shop() -> void:
    _open_modal(_shop_panel)

func close_shop() -> void:
    _close_modal(_shop_panel)

func open_shipping() -> void:
    _open_modal(_shipping_panel)

func close_shipping() -> void:
    _close_modal(_shipping_panel)

func open_sleep_confirmation() -> void:
    _open_modal(_sleep_panel)

func close_sleep_confirmation() -> void:
    _close_modal(_sleep_panel)

func open_dialogue(villager_id: int, result: Dictionary, snapshot: Dictionary) -> void:
    _open_modal(_dialogue_panel)
    _dialogue_panel.present(villager_id, result, snapshot)

func update_dialogue(villager_id: int, result: Dictionary, snapshot: Dictionary) -> void:
    _dialogue_panel.present(villager_id, result, snapshot)

func close_dialogue() -> void:
    if not _dialogue_panel.visible:
        return
    _dialogue_panel.close_panel()
    modal_state_changed.emit()

func feedback_text(code: GameRules.CommandCode) -> String:
    match code:
        GameRules.CommandCode.ACTION_SELECTED:
            return "Action selected."
        GameRules.CommandCode.SEED_SELECTED:
            return "Seed selected."
        GameRules.CommandCode.SOIL_TILLED:
            return "Soil tilled."
        GameRules.CommandCode.CROP_PLANTED:
            return "Crop planted."
        GameRules.CommandCode.CROP_WATERED:
            return "Crop watered."
        GameRules.CommandCode.CROP_HARVESTED:
            return "Crop harvested."
        GameRules.CommandCode.SEEDS_PURCHASED:
            return "Seeds purchased."
        GameRules.CommandCode.CROP_DEPOSITED:
            return "Crop deposited."
        GameRules.CommandCode.DAY_ADVANCED:
            return "Day advanced."
        GameRules.CommandCode.DAY_STARTED:
            return "Morning acknowledged."
        GameRules.CommandCode.NO_TARGET:
            return "No target."
        GameRules.CommandCode.NOT_FARM_CELL:
            return "That is not a farm cell."
        GameRules.CommandCode.ALREADY_TILLED:
            return "Soil is already tilled."
        GameRules.CommandCode.SOIL_UNTILLED:
            return "Till the soil first."
        GameRules.CommandCode.CROP_PRESENT:
            return "A crop is already there."
        GameRules.CommandCode.NO_SELECTED_SEEDS:
            return "No selected seeds."
        GameRules.CommandCode.NO_CROP:
            return "There is no crop there."
        GameRules.CommandCode.ALREADY_WATERED:
            return "Crop is already watered."
        GameRules.CommandCode.CROP_MATURE:
            return "Crop is mature."
        GameRules.CommandCode.CROP_IMMATURE:
            return "Crop is not mature."
        GameRules.CommandCode.NOT_AT_BED:
            return "Stand at the bed."
        GameRules.CommandCode.NOT_AT_SHOP:
            return "Stand at the shop."
        GameRules.CommandCode.NOT_AT_SHIPPING_BIN:
            return "Stand at the shipping bin."
        GameRules.CommandCode.INVALID_QUANTITY:
            return "Choose a positive quantity."
        GameRules.CommandCode.INSUFFICIENT_FUNDS:
            return "Not enough money."
        GameRules.CommandCode.INSUFFICIENT_CROPS:
            return "Not enough harvested crops."
        GameRules.CommandCode.ACTION_TOO_LATE:
            return "It is too late for that action."
        GameRules.CommandCode.INSUFFICIENT_STAMINA:
            return "Not enough stamina."
        GameRules.CommandCode.RAIN_WATERS_CROPS:
            return "Rain is watering the crops."
        GameRules.CommandCode.DAY_SUMMARY_PENDING:
            return "Acknowledge the morning summary first."
        GameRules.CommandCode.NO_DAY_SUMMARY:
            return "No morning summary."
        GameRules.CommandCode.NOTHING_TO_INTERACT:
            return "Nothing to interact with."
        GameRules.CommandCode.VILLAGER_TALKED:
            return "Talked to villager."
        GameRules.CommandCode.CROP_GIFTED:
            return "Gift given."
        GameRules.CommandCode.NOT_AT_VILLAGER:
            return "Stand at the villager."
        GameRules.CommandCode.GIFT_ALREADY_GIVEN:
            return "Gift already given today."
        GameRules.CommandCode.INTRO_ACKNOWLEDGED, \
        GameRules.CommandCode.INTRO_ALREADY_ACKNOWLEDGED:
            return ""
        GameRules.CommandCode.FINALE_TRIGGERED:
            return "Harvest finale complete."
        GameRules.CommandCode.MARKET_NOT_READY:
            return "The Harvest Market opens on Day 14."
        GameRules.CommandCode.NOT_AT_MARKET:
            return "Stand at the Harvest Market."
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED:
            return "The harvest finale is already complete."
        _:
            assert(false, "unmapped command feedback: %s" % code)
            return ""

func show_feedback(code: GameRules.CommandCode) -> void:
    var text := feedback_text(code)
    if text != "":
        _feedback.text = text

func _build_always_visible_hud() -> void:
    _weather_tint = ColorRect.new()
    _weather_tint.name = "WeatherTint"
    _weather_tint.position = Vector2.ZERO
    _weather_tint.size = Vector2(640, 360)
    _weather_tint.color = SUNNY_TINT
    _weather_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(_weather_tint)

    _day_label = _add_label(_root, "Day", "Day", Vector2(8, 8), Vector2(72, 20))
    _time_label = _add_label(_root, "Time", "06:00", Vector2(82, 8), Vector2(58, 20))
    _weather_label = _add_label(_root, "Weather", "Weather: Sunny", Vector2(148, 8), Vector2(124, 20))
    _stamina_label = _add_label(_root, "Stamina", "Stamina: 20/20", Vector2(278, 8), Vector2(108, 20))
    _money_label = _add_label(_root, "Money", "Money: 150G", Vector2(394, 8), Vector2(100, 20))

    _add_label(_root, "ActionTitle", "Actions", Vector2(8, 34), Vector2(64, 20))
    var action_names := ["Hoe", "Seeds", "Water", "Hands"]
    for action in action_names.size():
        var button := _add_button(
            _root,
            "Action_%d" % action,
            "%d %s" % [action + 1, action_names[action]],
            Vector2(8 + action * 72, 52),
            Vector2(68, 24),
        )
        button.toggle_mode = true
        button.pressed.connect(_on_action_button_pressed.bind(action))
        _action_buttons.append(button)

    _add_label(_root, "SeedTitle", "Seeds", Vector2(8, 82), Vector2(52, 20))
    _selected_seed_label = _add_label(_root, "SelectedSeed", "Selected: Turnip", Vector2(64, 82), Vector2(140, 20))
    for kind in range(GameRules.CropKind.size()):
        var button := _add_button(
            _root,
            "Seed_%d" % kind,
            GameRules.crop_display_name(kind),
            Vector2(8 + kind * 72, 102),
            Vector2(68, 22),
        )
        button.toggle_mode = true
        button.pressed.connect(_on_seed_button_pressed.bind(kind))
        _seed_buttons.append(button)
        var count := _add_label(
            _root,
            "SeedCount_%d" % kind,
            "0",
            Vector2(35 + kind * 72, 124),
            Vector2(22, 18),
        )
        _seed_count_labels.append(count)

    _add_label(_root, "HarvestedTitle", "Harvested", Vector2(8, 144), Vector2(72, 20))
    for kind in range(GameRules.CropKind.size()):
        var count := _add_label(
            _root,
            "HarvestedCount_%d" % kind,
            "%s: 0" % GameRules.crop_display_name(kind),
            Vector2(8 + kind * 88, 164),
            Vector2(84, 20),
        )
        _harvested_count_labels.append(count)

    _pending_shipment_label = _add_label(
        _root,
        "PendingShipment",
        "Pending shipment: 0",
        Vector2(8, 188),
        Vector2(160, 20),
    )
    _interaction_hint = _add_label(_root, "InteractionHint", "", Vector2(8, 214), Vector2(180, 20))
    _feedback = _add_label(_root, "Feedback", "", Vector2(8, 238), Vector2(280, 24))
    _objective_label = _add_label(_root, "Objective", "", Vector2(8, 338), Vector2(624, 20))
    _objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_modals() -> void:
    _shop_panel = _build_shop_panel()
    _shipping_panel = _build_shipping_panel()
    _sleep_panel = _build_sleep_panel()
    _morning_summary_panel = _build_summary_panel()
    _dialogue_panel = DialoguePanel.new()
    _dialogue_panel.name = "DialoguePanel"
    _root.add_child(_dialogue_panel)
    _dialogue_panel.gift_requested.connect(func(villager_id: int, crop_kind: int) -> void:
        gift_requested.emit(villager_id, crop_kind)
    )
    _dialogue_panel.close_requested.connect(close_dialogue)
    _onboarding_overlay = OnboardingOverlay.new()
    _onboarding_overlay.name = "OnboardingOverlay"
    _root.add_child(_onboarding_overlay)
    _onboarding_overlay.intro_acknowledged.connect(func() -> void:
        intro_acknowledged.emit()
    )
    _onboarding_overlay.blocking_state_changed.connect(func() -> void:
        modal_state_changed.emit()
    )
    _pause_help_panel = _build_pause_help()
    _shop_panel.visible = false
    _shipping_panel.visible = false
    _sleep_panel.visible = false
    _dialogue_panel.visible = false
    _morning_summary_panel.visible = false
    _pause_help_panel.visible = false

func _build_pause_help() -> Control:
    var panel := _add_panel(
        _root,
        "PauseHelp",
        "Phoenix — Controls",
        Vector2(300, 62),
        Vector2(332, 220),
    )
    var body := _add_label(
        panel,
        "Body",
        "WASD — Move\n1 / 2 / 3 / 4 — Hoe / Seeds / Water / Hands\nSpace — Use selected action\nE — Interact\nEsc — Close / controls",
        Vector2(12, 34),
        Vector2(308, 132),
    )
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var resume := _add_button(panel, "Resume", "Resume", Vector2(236, 178), Vector2(78, 28))
    resume.pressed.connect(func() -> void: _set_pause_help_visible(false))
    return panel


func _set_pause_help_visible(is_visible: bool) -> void:
    if _pause_help_panel.visible == is_visible:
        return
    _pause_help_panel.visible = is_visible
    modal_state_changed.emit()

func _build_shop_panel() -> Control:
    var panel := _add_panel(_root, "ShopPanel", "Seed Shop", Vector2(300, 38), Vector2(332, 260))
    _add_label(panel, "Header", "Buy seeds", Vector2(10, 28), Vector2(300, 20))
    for kind in range(GameRules.CropKind.size()):
        var row := _add_row(panel, kind, "Buy", 62 + kind * 48)
        _shop_count_labels.append(row["count"])
        var spin: SpinBox = row["spin"]
        var max_button: Button = row["max"]
        var buy_button: Button = row["action"]
        max_button.pressed.connect(func() -> void:
            spin.value = maxi(1, _max_shop_quantity(kind))
        )
        buy_button.pressed.connect(func() -> void:
            buy_requested.emit(kind, int(spin.value))
        )
    var close_button := _add_button(panel, "Close", "Close", Vector2(244, 218), Vector2(76, 28))
    close_button.pressed.connect(close_shop)
    return panel

func _build_shipping_panel() -> Control:
    var panel := _add_panel(_root, "ShippingPanel", "Shipping", Vector2(300, 38), Vector2(332, 260))
    _add_label(panel, "Header", "Deposit harvested crops", Vector2(10, 28), Vector2(300, 20))
    _day14_shipping_boundary = _add_label(panel, "Boundary", "", Vector2(10, 48), Vector2(310, 20))
    for kind in range(GameRules.CropKind.size()):
        var row := _add_row(panel, kind, "Deposit", 74 + kind * 42)
        _shipping_count_labels.append(row["count"])
        var spin: SpinBox = row["spin"]
        var max_button: Button = row["max"]
        var deposit_button: Button = row["action"]
        max_button.pressed.connect(func() -> void:
            spin.value = maxi(1, _max_shipping_quantity(kind))
        )
        deposit_button.pressed.connect(func() -> void:
            deposit_requested.emit(kind, int(spin.value))
        )
    var close_button := _add_button(panel, "Close", "Close", Vector2(244, 218), Vector2(76, 28))
    close_button.pressed.connect(close_shipping)
    return panel

func _build_sleep_panel() -> Control:
    var panel := _add_panel(_root, "SleepPanel", "Sleep Confirmation", Vector2(300, 94), Vector2(332, 168))
    _add_label(panel, "Body", "Sleep until the next morning?", Vector2(10, 30), Vector2(310, 24))
    _day14_sleep_boundary = _add_label(panel, "Boundary", "", Vector2(10, 56), Vector2(310, 20))
    var confirm_button := _add_button(panel, "Confirm", "Sleep", Vector2(150, 116), Vector2(76, 28))
    confirm_button.pressed.connect(func() -> void: sleep_requested.emit())
    var cancel_button := _add_button(panel, "Cancel", "Cancel", Vector2(238, 116), Vector2(76, 28))
    cancel_button.pressed.connect(close_sleep_confirmation)
    return panel

func _build_summary_panel() -> Control:
    var panel := _add_panel(_root, "MorningSummaryPanel", "Morning Summary", Vector2(300, 66), Vector2(332, 210))
    _summary_body = _add_label(panel, "Body", "", Vector2(12, 32), Vector2(308, 128))
    _summary_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _save_status_label = _add_label(panel, "SaveStatus", "", Vector2(12, 164), Vector2(190, 44))
    _save_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var acknowledge_button := _add_button(
        panel,
        "Acknowledge",
        "Acknowledge",
        Vector2(208, 170),
        Vector2(104, 28),
    )
    acknowledge_button.pressed.connect(func() -> void: morning_summary_acknowledged.emit())
    return panel

func _add_panel(parent: Control, node_name: String, title: String, position: Vector2, size: Vector2) -> Control:
    var panel := ColorRect.new()
    panel.name = node_name
    panel.position = position
    panel.size = size
    panel.color = Color(0.08, 0.1, 0.14, 0.96)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    parent.add_child(panel)
    _add_label(panel, "Title", title, Vector2(10, 6), Vector2(size.x - 20, 22))
    return panel

func _add_row(parent: Control, kind: int, action_name: String, y: float) -> Dictionary:
    var row := Control.new()
    row.name = "Row_%d" % kind
    row.position = Vector2(8, y)
    row.size = Vector2(316, 38)
    parent.add_child(row)
    var label := _add_label(
        row,
        "Crop",
        GameRules.crop_display_name(kind),
        Vector2(0, 8),
        Vector2(92, 22),
    )
    var spin := SpinBox.new()
    spin.name = "Quantity"
    spin.position = Vector2(94, 4)
    spin.size = Vector2(58, 28)
    spin.min_value = 1
    spin.max_value = 99
    spin.step = 1
    spin.value = 1
    row.add_child(spin)
    var max_button := _add_button(row, "Max", "Max", Vector2(156, 4), Vector2(52, 28))
    var action_button := _add_button(
        row,
        action_name,
        action_name,
        Vector2(212, 4),
        Vector2(96, 28),
    )
    return {"label": label, "count": _add_label(row, "Count", "", Vector2(0, 25), Vector2(92, 16)), "spin": spin, "max": max_button, "action": action_button}

func _add_label(parent: Node, node_name: String, text: String, position: Vector2, size: Vector2) -> Label:
    var label := Label.new()
    label.name = node_name
    label.text = text
    label.position = position
    label.size = size
    parent.add_child(label)
    return label

func _add_button(parent: Node, node_name: String, text: String, position: Vector2, size: Vector2) -> Button:
    var button := Button.new()
    button.name = node_name
    button.text = text
    button.position = position
    button.size = size
    button.focus_mode = Control.FOCUS_NONE
    parent.add_child(button)
    return button

func _on_action_button_pressed(action: int) -> void:
    select_action_requested.emit(action)

func _on_seed_button_pressed(kind: int) -> void:
    select_seed_requested.emit(kind)

func _refresh_action_selection() -> void:
    for action in _action_buttons.size():
        var selected: bool = GameRules.ACTION_KEYS[action] == _selected_action
        _action_buttons[action].button_pressed = selected
        _action_buttons[action].modulate = Color(1.0, 0.9, 0.45) if selected else Color.WHITE

func _refresh_seed_selection() -> void:
    _selected_seed_label.text = "Selected: %s" % _display_crop(_selected_seed)
    for kind in _seed_buttons.size():
        var selected: bool = GameRules.crop_key(kind) == _selected_seed
        _seed_buttons[kind].button_pressed = selected
        _seed_buttons[kind].modulate = Color(1.0, 0.9, 0.45) if selected else Color.WHITE
        _seed_buttons[kind].tooltip_text = GameRules.crop_display_name(kind)

func _update_toggle_enabled() -> void:
    var blocked := has_blocking_modal()
    for button in _action_buttons:
        button.disabled = blocked
    for button in _seed_buttons:
        button.disabled = blocked

func _set_morning_summary_visible(is_visible: bool) -> void:
    var was_visible := _morning_summary_panel.visible
    if is_visible:
        _shop_panel.visible = false
        _shipping_panel.visible = false
        _sleep_panel.visible = false
        if _dialogue_panel.visible:
            _dialogue_panel.close_panel()
    _morning_summary_panel.visible = is_visible
    if not is_visible:
        set_save_status(&"idle")
    if was_visible != is_visible:
        modal_state_changed.emit()

func _open_modal(panel: Control) -> void:
    if _morning_summary_panel.visible:
        return
    _shop_panel.visible = false
    _shipping_panel.visible = false
    _sleep_panel.visible = false
    if panel != _dialogue_panel and _dialogue_panel.visible:
        _dialogue_panel.close_panel()
    panel.visible = true
    modal_state_changed.emit()

func _close_modal(panel: Control) -> void:
    if not panel.visible:
        return
    panel.visible = false
    modal_state_changed.emit()

func _render_morning_summary(summary: Dictionary) -> void:
    var lines: Array[String] = [
        "Day %s complete → Day %s" % [summary.get("completed_day", "?"), summary.get("next_day", "?")],
        "Crops advanced: %s" % summary.get("crops_advanced", 0),
        "Next weather: %s" % _display_weather(summary.get(
            "next_weather",
            GameRules.weather_key(GameRules.Weather.SUNNY),
        )),
        "Stamina restored: %s" % summary.get("stamina_restored", 0),
    ]
    var shipments: Array = summary.get("shipments", [])
    if shipments.is_empty():
        lines.append("Shipping income: 0G")
    else:
        for shipment_variant in shipments:
            var shipment: Dictionary = shipment_variant
            lines.append(
                "%s x%s: %sG" % [
                    _display_crop(shipment.get("crop", GameRules.crop_key(GameRules.CropKind.TURNIP))),
                    shipment.get("quantity", 0),
                    shipment.get("amount", 0),
                ]
            )
    lines.append("Money after shipping: %sG" % summary.get("money_after_shipping", 0))
    _summary_body.text = "\n".join(lines)

func _max_shop_quantity(kind: int) -> int:
    return int(_last_snapshot.get("money", 0)) / GameRules.seed_price(kind)

func _max_shipping_quantity(kind: int) -> int:
    var harvested: Dictionary = _last_snapshot.get("harvested", {})
    return int(harvested.get(GameRules.crop_key(kind), 0))

func _display_crop(key: Variant) -> String:
    for kind in range(GameRules.CropKind.size()):
        if GameRules.crop_key(kind) == key:
            return GameRules.crop_display_name(kind)
    return String(key).capitalize()

func _display_weather(key: Variant) -> String:
    return "Rainy" if key == GameRules.weather_key(GameRules.Weather.RAINY) else "Sunny"

func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("ui_cancel"):
        return
    if _morning_summary_panel.visible or _onboarding_overlay.is_opening_visible():
        get_viewport().set_input_as_handled()
        return
    if _shop_panel.visible:
        close_shop()
    elif _shipping_panel.visible:
        close_shipping()
    elif _sleep_panel.visible:
        close_sleep_confirmation()
    elif _pause_help_panel.visible:
        _set_pause_help_visible(false)
    else:
        _set_pause_help_visible(true)
    get_viewport().set_input_as_handled()
