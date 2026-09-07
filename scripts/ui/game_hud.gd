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

const ACTION_SFX := preload("res://assets/audio/action.wav")
const COMMERCE_SFX := preload("res://assets/audio/commerce.wav")
const SOCIAL_SFX := preload("res://assets/audio/social.wav")
const CONFIRM_SFX := preload("res://assets/audio/confirm.wav")
const CANCEL_SFX := preload("res://assets/audio/cancel.wav")
const DAY_TRANSITION_SFX := preload("res://assets/audio/day-transition.wav")
const FINALE_SFX := preload("res://assets/audio/finale.wav")
const FARM_DAY_LOOP := preload("res://assets/audio/farm-day-loop.wav")
const ONBOARDING_SCENE := preload("res://scenes/ui/onboarding_overlay.tscn")
const SHOP_SCENE := preload("res://scenes/ui/shop_panel.tscn")
const SHIPPING_SCENE := preload("res://scenes/ui/shipping_panel.tscn")
const BAG_SCENE := preload("res://scenes/ui/bag_panel.tscn")
const ALMANAC_SCENE := preload("res://scenes/ui/almanac_panel.tscn")
const CALENDAR_SCENE := preload("res://scenes/ui/calendar_panel.tscn")
const DIALOGUE_SCENE := preload("res://scenes/ui/dialogue_panel.tscn")
const MORNING_SUMMARY_SCENE := preload("res://scenes/ui/morning_summary_panel.tscn")
const SLEEP_SCENE := preload("res://scenes/ui/sleep_panel.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_panel.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_panel.tscn")

var _root: Control
var _weather_tint: ColorRect
var _interaction_hint: Label
var _feedback: Label
var _day_value_label: Label
var _day_max_label: Label
var _time_value_label: Label
var _weather_value_label: Label
var _market_label: Label
var _money_value_label: Label
var _bag_value_label: Label
var _pending_value_label: Label
var _seed_action_badge: Label
var _feedback_panel: Panel
var _stamina_pips: Array[ColorRect] = []
var _shop_panel: ShopPanel
var _shipping_panel: ShippingPanel
var _bag_panel: BagPanel
var _almanac_panel: AlmanacPanel
var _calendar_panel: CalendarPanel
var _sleep_panel: SleepPanel
var _dialogue_panel: DialoguePanel
var _onboarding_overlay: OnboardingOverlay
var _morning_summary_panel: MorningSummaryPanel
var _pause_panel: PausePanel
var _settings_panel: SettingsPanel
var _day14_sleep_boundary: Label
var _objective_label: Label
var _action_buttons: Array[Button] = []
var _seed_buttons: Array[Button] = []
var _seed_count_labels: Array[Label] = []
var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _settings: UiSettings
var _last_snapshot: Dictionary = {}
var _finale_in_progress := false
var _primary_modals: Array[Control] = []
var _esc_close_order: Array[Dictionary] = []
var _selected_action: StringName = GameRules.action_key(GameRules.FarmingAction.HOE)
var _selected_seed: StringName = GameRules.crop_key(GameRules.CropKind.TURNIP)

func _ready() -> void:
    _root = $HudRoot as Control
    _build_always_visible_hud()
    _build_modals()
    _primary_modals = [
        _shop_panel,
        _shipping_panel,
        _bag_panel,
        _almanac_panel,
        _calendar_panel,
        _sleep_panel,
        _dialogue_panel,
        _morning_summary_panel,
        _settings_panel,
        _pause_panel,
    ]
    _esc_close_order = [
        {"control": _dialogue_panel, "close": close_dialogue},
        {"control": _shop_panel, "close": close_shop},
        {"control": _shipping_panel, "close": close_shipping},
        {"control": _bag_panel, "close": close_bag},
        {"control": _almanac_panel, "close": close_almanac},
        {"control": _calendar_panel, "close": close_calendar},
        {"control": _sleep_panel, "close": close_sleep_confirmation},
        {"control": _settings_panel, "close": close_settings},
        {"control": _pause_panel, "close": close_pause},
    ]
    _build_audio()
    apply_settings()
    modal_state_changed.connect(_update_toggle_enabled)

func configure(settings: UiSettings = null) -> void:
    if settings != null:
        _settings = settings
    apply_settings()

func apply_settings() -> void:
    if _settings == null or _music_player == null or _sfx_player == null:
        return
    _music_player.volume_db = _settings.db_for_level(_settings.music)
    _sfx_player.volume_db = _settings.db_for_level(_settings.sound)
    _onboarding_overlay.set_tutorial_cards_enabled(_settings.tutorial_cards)
    _settings.apply_window(get_window())

func render(snapshot: Dictionary) -> void:
    _last_snapshot = snapshot.duplicate(true)
    _shop_panel.present(snapshot)
    _shipping_panel.present(snapshot)
    _bag_panel.present(snapshot)
    _almanac_panel.present(snapshot)
    _calendar_panel.present(snapshot)
    _onboarding_overlay.render(snapshot)
    _weather_tint.color = (
        RAINY_TINT
        if snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)
        else SUNNY_TINT
    )
    _time_value_label.text = GameRules.format_time(int(snapshot["time_minutes"]))
    _day_value_label.text = "%d" % int(snapshot["day"])
    _day_max_label.text = "/%d" % GameRules.MAX_DAY
    _weather_value_label.text = _display_weather(snapshot["weather"]).to_upper()
    _market_label.text = (
        "HARVEST MARKET TODAY"
        if int(snapshot["day"]) >= GameRules.MAX_DAY
        else "HARVEST MARKET IN %d" % (GameRules.MAX_DAY - int(snapshot["day"]))
    )
    _money_value_label.text = "%d" % int(snapshot["money"])
    for index in _stamina_pips.size():
        _stamina_pips[index].color = UiStyle.GREEN if index < int(snapshot["stamina"]) else Color("22301c")

    _selected_action = snapshot["selected_action"]
    _selected_seed = snapshot["selected_seed"]
    _refresh_action_selection()
    _refresh_seed_selection()

    var seeds: Dictionary = snapshot["seeds"]
    var harvested: Dictionary = snapshot["harvested"]
    var pending: Dictionary = snapshot["pending_shipment"]
    var pending_total := 0
    var harvested_total := 0
    for kind in range(GameRules.CropKind.size()):
        var key := GameRules.crop_key(kind)
        _seed_count_labels[kind].text = "%d" % int(seeds.get(key, 0))
        pending_total += int(pending.get(key, 0))
        harvested_total += int(harvested.get(key, 0))
    _bag_value_label.text = "%d" % harvested_total
    _pending_value_label.text = "%d" % pending_total
    _seed_action_badge.text = "×%d" % int(seeds.get(GameRules.crop_key(GameRules.CropKind.TURNIP), 0))

    var day := int(snapshot["day"])
    if day >= GameRules.MAX_DAY:
        _objective_label.text = "Harvest Market today — ship crops first, then visit the village path stall."
    else:
        _objective_label.text = "Harvest Market: Day 14 · %d days left" % (GameRules.MAX_DAY - day)
    _day14_sleep_boundary.text = (
        "Day 14 — this ends the season and settles the bin."
        if day == GameRules.MAX_DAY
        else ""
    )

    var summary: Variant = snapshot["pending_morning_summary"]
    _set_morning_summary_visible(summary != null)
    if summary != null:
        _morning_summary_panel.present(summary)
    _sleep_panel.present(snapshot)

func has_blocking_modal() -> bool:
    if _onboarding_overlay.is_opening_visible():
        return true
    for panel in _primary_modals:
        if panel.visible:
            return true
    return false

func set_finale_in_progress(value: bool) -> void:
    # While the finale cue plays, no close path may replace FINALE_SFX with
    # CONFIRM_SFX. WorldShell sets this before closing the sleep modal and
    # starting the cue; the three CONFIRM_SFX close paths check it.
    _finale_in_progress = value

func set_save_status(status: StringName, message: String = "") -> void:
    _morning_summary_panel.set_save_status(status, message)

func set_interaction_hint(text: String) -> void:
    _interaction_hint.text = text

func open_shop() -> void:
    if _open_modal(_shop_panel):
        _shop_panel.open_panel(_last_snapshot)

func close_shop() -> void:
    _close_modal(_shop_panel)

func open_shipping() -> void:
    if _open_modal(_shipping_panel):
        _shipping_panel.open_panel(_last_snapshot)

func close_shipping() -> void:
    _close_modal(_shipping_panel)

func open_bag() -> void:
    if _open_modal(_bag_panel):
        _bag_panel.open_panel(_last_snapshot)

func close_bag() -> void:
    _close_modal(_bag_panel)

func open_almanac() -> void:
    if _open_modal(_almanac_panel):
        _almanac_panel.open_panel(_last_snapshot)

func close_almanac() -> void:
    _close_modal(_almanac_panel)

func open_calendar() -> void:
    if _open_modal(_calendar_panel):
        _calendar_panel.open_panel(_last_snapshot)

func close_calendar() -> void:
    _close_modal(_calendar_panel)

func open_sleep_confirmation() -> void:
    if _open_modal(_sleep_panel):
        _sleep_panel.present(_last_snapshot)

func close_sleep_confirmation() -> void:
    _close_modal(_sleep_panel)

func open_dialogue(villager_id: int, result: Dictionary, snapshot: Dictionary) -> void:
    if _open_modal(_dialogue_panel):
        _dialogue_panel.present(villager_id, result, snapshot)

func update_dialogue(villager_id: int, result: Dictionary, snapshot: Dictionary) -> void:
    _dialogue_panel.present(villager_id, result, snapshot)

func close_dialogue() -> void:
    if not _dialogue_panel.visible:
        return
    _dialogue_panel.close_panel()
    if not _finale_in_progress:
        _play_sfx(CONFIRM_SFX)
    _onboarding_overlay.render(_last_snapshot)
    _set_hud_chrome_visible(true)
    modal_state_changed.emit()

func open_pause() -> void:
    if _open_modal(_pause_panel):
        _pause_panel.visible = true

func close_pause() -> void:
    _close_modal(_pause_panel)

func open_settings() -> void:
    if not _pause_panel.visible or _settings == null:
        return
    if _open_modal(_settings_panel):
        _settings_panel.open_panel(_settings)

func close_settings() -> void:
    if not _settings_panel.visible:
        return
    # Reopen Pause in one modal transaction so the world gate never briefly
    # sees an unblocked state between the nested surfaces.
    open_pause()

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
        var tutorial_visible: bool = $HudRoot/OnboardingOverlay/TutorialCard.visible
        _feedback_panel.visible = not tutorial_visible
        _feedback.visible = not tutorial_visible
    var sfx := _sfx_for_code(code)
    if sfx != null:
        _play_sfx(sfx)

func _sfx_for_code(code: GameRules.CommandCode) -> AudioStream:
    match code:
        GameRules.CommandCode.ACTION_SELECTED, \
        GameRules.CommandCode.SEED_SELECTED, \
        GameRules.CommandCode.SOIL_TILLED, \
        GameRules.CommandCode.CROP_PLANTED, \
        GameRules.CommandCode.CROP_WATERED, \
        GameRules.CommandCode.CROP_HARVESTED:
            return ACTION_SFX
        GameRules.CommandCode.SEEDS_PURCHASED, \
        GameRules.CommandCode.CROP_DEPOSITED:
            return COMMERCE_SFX
        GameRules.CommandCode.VILLAGER_TALKED, \
        GameRules.CommandCode.CROP_GIFTED:
            return SOCIAL_SFX
        GameRules.CommandCode.DAY_ADVANCED, \
        GameRules.CommandCode.DAY_STARTED:
            return DAY_TRANSITION_SFX
        GameRules.CommandCode.FINALE_TRIGGERED, \
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED:
            return FINALE_SFX
        GameRules.CommandCode.INTRO_ACKNOWLEDGED, \
        GameRules.CommandCode.INTRO_ALREADY_ACKNOWLEDGED:
            return null
        _:
            return CANCEL_SFX

func _build_audio() -> void:
    _sfx_player = AudioStreamPlayer.new()
    _sfx_player.name = "SfxPlayer"
    _sfx_player.volume_db = -8.0
    add_child(_sfx_player)

    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.volume_db = -20.0
    _music_player.stream = FARM_DAY_LOOP
    add_child(_music_player)
    _music_player.play()

func await_feedback_cue() -> void:
    # Lets a caller hold the world until the just-started feedback stream has
    # been heard. Never waits off-tree: a detached World replays feedback
    # silently (see _play_sfx) and must not hang the awaiting caller.
    if not is_inside_tree():
        return
    var stream := _sfx_player.stream
    if stream == null or not _sfx_player.playing:
        return
    await get_tree().create_timer(maxf(stream.get_length(), 0.05)).timeout

func _play_sfx(stream: AudioStream) -> void:
    # A detached World can still receive commands (e.g. duplicate terminal
    # attempts after the result teardown); playing off-tree only logs errors.
    if not is_inside_tree():
        return
    _sfx_player.stream = stream
    _sfx_player.play()

func _build_always_visible_hud() -> void:
    _weather_tint = $HudRoot/WeatherTint as ColorRect
    _day_value_label = $HudRoot/TopBar/DayValue as Label
    _day_max_label = $HudRoot/TopBar/DayMax as Label
    _time_value_label = $HudRoot/TopBar/TimeValue as Label
    _weather_value_label = $HudRoot/TopBar/WeatherValue as Label
    _market_label = $HudRoot/TopBar/MarketPanel/Market as Label
    _money_value_label = $HudRoot/TopBar/MoneyValue as Label
    _stamina_pips.clear()
    for index in 20:
        _stamina_pips.append($HudRoot/TopBar.get_node("StaminaPip_%02d" % index) as ColorRect)

    _interaction_hint = $HudRoot/InteractionHint as Label
    _feedback = $HudRoot/Feedback as Label
    _feedback_panel = $HudRoot/FeedbackPanel as Panel
    _bag_value_label = $HudRoot/ResourceStrip/BagPanel/BagValue as Label
    _pending_value_label = $HudRoot/ResourceStrip/PendingPanel/PendingValue as Label
    _seed_action_badge = $HudRoot/Action_1/Badge as Label
    _objective_label = $HudRoot/Objective as Label
    _seed_count_labels.clear()
    _action_buttons.clear()
    _seed_buttons.clear()
    for action in 4:
        var action_button := $HudRoot.get_node("Action_%d" % action) as Button
        action_button.toggle_mode = true
        action_button.pressed.connect(_on_action_button_pressed.bind(action))
        _action_buttons.append(action_button)
    for kind in range(GameRules.CropKind.size()):
        var seed_button := $HudRoot.get_node("Seed_%d" % kind) as Button
        seed_button.toggle_mode = true
        seed_button.pressed.connect(_on_seed_button_pressed.bind(kind))
        _seed_buttons.append(seed_button)
        _seed_count_labels.append(seed_button.get_node("Count") as Label)

    _style_authored_tree(_root)
    _apply_authored_hud_style()
    _feedback_panel.visible = false
    _feedback.visible = false

func _style_authored_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_authored_tree(child)

func _apply_authored_hud_style() -> void:
    for panel_path in ["TopBar", "TopBar/MarketPanel", "FeedbackPanel", "Hotbar", "ResourceStrip/BagPanel", "ResourceStrip/PendingPanel"]:
        var panel := $HudRoot.get_node(panel_path) as Panel
        panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PRIMARY, UiStyle.BORDER, 1))
    _feedback_panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 1))
    var topbar := $HudRoot/TopBar as Control
    UiStyle.text(topbar.get_node("DayCaption") as Label, 8, UiStyle.MUTED, 700)
    UiStyle.text(_day_value_label, 14, UiStyle.CREAM, 800)
    UiStyle.text(_day_max_label, 9, UiStyle.MUTED, 600)
    UiStyle.text(_time_value_label, 12, UiStyle.CREAM, 700, true)
    UiStyle.text(_weather_value_label, 10, UiStyle.CREAM, 700)
    UiStyle.text(_market_label, 9, UiStyle.GOLD, 700)
    UiStyle.text($HudRoot/TopBar/StaminaCaption as Label, 7, UiStyle.MUTED, 700)
    UiStyle.text(_money_value_label, 14, UiStyle.GOLD, 800, true)
    UiStyle.text($HudRoot/TopBar/MoneySuffix as Label, 9, UiStyle.MUTED, 700)
    UiStyle.text($HudRoot/ResourceStrip/BagPanel/BagCaption as Label, 8, UiStyle.MUTED, 600)
    UiStyle.text(_bag_value_label, 8, UiStyle.CREAM, 700)
    UiStyle.text($HudRoot/ResourceStrip/PendingPanel/PendingCaption as Label, 8, UiStyle.MUTED, 600)
    UiStyle.text(_pending_value_label, 8, UiStyle.CREAM, 700)
    UiStyle.button($HudRoot/ResourceStrip/BagPanel/BagKey as Button, 8)
    UiStyle.text(_interaction_hint, 9, UiStyle.GOLD, 700)
    _interaction_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    UiStyle.text($HudRoot/SeedCycleHint as Label, 8, UiStyle.MUTED, 700)
    UiStyle.text($HudRoot/Hotbar/TillLabel as Label, 9, UiStyle.CREAM, 700)
    UiStyle.text($HudRoot/Hotbar/ShopLabel as Label, 9, UiStyle.CREAM, 700)
    UiStyle.button($HudRoot/Hotbar/SpaceKey as Button, 9, true)
    UiStyle.button($HudRoot/Hotbar/InteractKey as Button, 9)
    for action in _action_buttons.size():
        UiStyle.button(_action_buttons[action], 8)
        var keycap := _action_buttons[action].get_node("Keycap") as Button
        UiStyle.button(keycap, 8)
        keycap.add_theme_stylebox_override("normal", UiStyle.panel(UiStyle.INSET, UiStyle.BORDER_LIGHT, 1))
        UiStyle.text(_action_buttons[action].get_node("Key") as Label, 8, UiStyle.GOLD, 700)
        UiStyle.text(_action_buttons[action].get_node("Name") as Label, 8, UiStyle.TEXT, 600)
    UiStyle.text(_seed_action_badge, 8, UiStyle.GOLD, 700)
    for seed in _seed_buttons.size():
        UiStyle.button(_seed_buttons[seed], 8)
        UiStyle.text(_seed_buttons[seed].get_node("Key") as Label, 8, UiStyle.GOLD, 700)
        UiStyle.text(_seed_count_labels[seed], 8, UiStyle.TEXT, 700)
    for separator_path in [
        "TopBar/DaySeparator",
        "TopBar/StatsSeparator",
        "TopBar/MoneySeparator",
        "Hotbar/ActionDivider",
        "Hotbar/SeedDivider",
    ]:
        ($HudRoot.get_node(separator_path) as ColorRect).color = UiStyle.BORDER
    ($HudRoot/TopBar/TimeRule as ColorRect).color = UiStyle.BORDER
    ($HudRoot/TopBar/MarketPanel as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.PRIMARY, UiStyle.GOLD, 1),
    )

func _build_modals() -> void:
    _onboarding_overlay = ONBOARDING_SCENE.instantiate() as OnboardingOverlay
    _root.add_child(_onboarding_overlay)
    _onboarding_overlay.intro_acknowledged.connect(func() -> void:
        intro_acknowledged.emit()
    )
    _onboarding_overlay.blocking_state_changed.connect(func() -> void:
        modal_state_changed.emit()
    )
    _shop_panel = SHOP_SCENE.instantiate() as ShopPanel
    _root.add_child(_shop_panel)
    _shop_panel.buy_requested.connect(func(kind: int, quantity: int) -> void:
        buy_requested.emit(kind, quantity)
    )
    _shipping_panel = SHIPPING_SCENE.instantiate() as ShippingPanel
    _root.add_child(_shipping_panel)
    _shipping_panel.deposit_requested.connect(func(kind: int, quantity: int) -> void:
        deposit_requested.emit(kind, quantity)
    )
    _bag_panel = BAG_SCENE.instantiate() as BagPanel
    _root.add_child(_bag_panel)
    _bag_panel.close_requested.connect(close_bag)
    _almanac_panel = ALMANAC_SCENE.instantiate() as AlmanacPanel
    _root.add_child(_almanac_panel)
    _almanac_panel.close_requested.connect(close_almanac)
    _calendar_panel = CALENDAR_SCENE.instantiate() as CalendarPanel
    _root.add_child(_calendar_panel)
    _calendar_panel.close_requested.connect(close_calendar)
    _sleep_panel = SLEEP_SCENE.instantiate() as SleepPanel
    _root.add_child(_sleep_panel)
    _sleep_panel.sleep_requested.connect(func() -> void:
        sleep_requested.emit()
    )
    _day14_sleep_boundary = _sleep_panel.get_node("Boundary") as Label
    _morning_summary_panel = MORNING_SUMMARY_SCENE.instantiate() as MorningSummaryPanel
    _root.add_child(_morning_summary_panel)
    _morning_summary_panel.acknowledged.connect(func() -> void:
        morning_summary_acknowledged.emit()
    )
    _dialogue_panel = DIALOGUE_SCENE.instantiate() as DialoguePanel
    _root.add_child(_dialogue_panel)
    _dialogue_panel.gift_requested.connect(func(villager_id: int, crop_kind: int) -> void:
        gift_requested.emit(villager_id, crop_kind)
    )
    _dialogue_panel.close_requested.connect(close_dialogue)
    _pause_panel = PAUSE_SCENE.instantiate() as PausePanel
    _root.add_child(_pause_panel)
    _pause_panel.settings_requested.connect(open_settings)
    _pause_panel.resume_requested.connect(close_pause)
    _settings_panel = SETTINGS_SCENE.instantiate() as SettingsPanel
    _root.add_child(_settings_panel)
    _settings_panel.settings_changed.connect(_on_settings_changed)
    _shop_panel.visible = false
    _shipping_panel.visible = false
    _bag_panel.visible = false
    _almanac_panel.visible = false
    _calendar_panel.visible = false
    _sleep_panel.visible = false
    _dialogue_panel.visible = false
    _morning_summary_panel.visible = false
    _pause_panel.visible = false
    _settings_panel.visible = false

func _on_settings_changed(_error: int) -> void:
    apply_settings()

func _on_action_button_pressed(action: int) -> void:
    select_action_requested.emit(action)

func _on_seed_button_pressed(kind: int) -> void:
    select_seed_requested.emit(kind)

func _refresh_action_selection() -> void:
    for action in _action_buttons.size():
        var selected: bool = GameRules.ACTION_KEYS[action] == _selected_action
        _action_buttons[action].button_pressed = selected
        _action_buttons[action].modulate = Color(1.0, 0.9, 0.45) if selected else Color.WHITE
        var name_label := _action_buttons[action].get_node("Name") as Label
        UiStyle.text(name_label, 8, UiStyle.GOLD if selected else UiStyle.TEXT, 700 if selected else 600)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _refresh_seed_selection() -> void:
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
        if not _open_modal(_morning_summary_panel):
            return
    else:
        _morning_summary_panel.visible = false
    if not is_visible:
        _morning_summary_panel.set_save_status(&"idle")
    _reconcile_modal_presentation()
    if was_visible != is_visible:
        modal_state_changed.emit()

func _reconcile_modal_presentation() -> void:
    for panel in _primary_modals:
        if not panel.visible:
            continue
        if not _onboarding_overlay.is_opening_visible():
            (_onboarding_overlay.get_node("TutorialCard") as Control).visible = false
        _set_hud_chrome_visible(false)
        return
    _set_hud_chrome_visible(true)

func _open_modal(panel: Control) -> bool:
    if _morning_summary_panel.visible and panel != _morning_summary_panel:
        return false
    if not _onboarding_overlay.is_opening_visible():
        (_onboarding_overlay.get_node("TutorialCard") as Control).visible = false
    _set_hud_chrome_visible(false)
    for registered in _primary_modals:
        if registered == panel:
            registered.visible = true
            continue
        if registered == _dialogue_panel and registered.visible:
            _dialogue_panel.close_panel()
        else:
            registered.visible = false
    modal_state_changed.emit()
    return true

func _close_modal(panel: Control) -> void:
    if not panel.visible:
        return
    panel.visible = false
    if not _finale_in_progress:
        _play_sfx(CONFIRM_SFX)
    _onboarding_overlay.render(_last_snapshot)
    _set_hud_chrome_visible(true)
    modal_state_changed.emit()

func _set_hud_chrome_visible(is_visible: bool) -> void:
    for node_path in [
        "TopBar",
        "ResourceStrip",
        "Hotbar",
        "Action_0",
        "Action_1",
        "Action_2",
        "Action_3",
        "Seed_0",
        "Seed_1",
        "Seed_2",
        "SeedCycleHint",
    ]:
        ($HudRoot.get_node(node_path) as Control).visible = is_visible

func _display_weather(key: Variant) -> String:
    return "Rainy" if key == GameRules.weather_key(GameRules.Weather.RAINY) else "Sunny"

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_bag"):
        if _bag_panel.visible:
            close_bag()
        elif not has_blocking_modal():
            open_bag()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("toggle_almanac"):
        if _almanac_panel.visible:
            close_almanac()
        elif not has_blocking_modal():
            open_almanac()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("toggle_calendar"):
        if _calendar_panel.visible:
            close_calendar()
        elif not has_blocking_modal():
            open_calendar()
        get_viewport().set_input_as_handled()
        return
    if not event.is_action_pressed("ui_cancel"):
        return
    if _morning_summary_panel.visible or _onboarding_overlay.is_opening_visible():
        get_viewport().set_input_as_handled()
        return
    for entry in _esc_close_order:
        var panel := entry["control"] as Control
        if not panel.visible:
            continue
        (entry["close"] as Callable).call()
        get_viewport().set_input_as_handled()
        return
    if not _pause_panel.visible:
        open_pause()
    get_viewport().set_input_as_handled()
