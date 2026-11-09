class_name GameHud
extends CanvasLayer

signal select_seed_requested(kind: int)
signal buy_requested(kind: int, quantity: int)
signal upgrade_requested
signal deposit_requested(kind: int, quantity: int)
signal sleep_requested
signal gift_requested(villager_id: int, crop_kind: int)
signal morning_summary_acknowledged
signal intro_acknowledged
signal modal_state_changed

const SUNNY_TINT := Color(1.0, 0.96, 0.86, 0.03)
const RAINY_TINT := Color(0.38, 0.52, 0.72, 0.12)

const FARMING_PREVIEW_VERBS := {
    GameRules.FarmingAction.HOE: "Till soil",
    GameRules.FarmingAction.SEEDS: "Plant",
    GameRules.FarmingAction.WATERING_CAN: "Water",
    GameRules.FarmingAction.HANDS: "Harvest",
}
const ACTION_SFX := preload("res://assets/audio/action.wav")
const FARM_HOE_SFX := preload("res://assets/audio/farm-hoe.wav")
const FARM_PLANT_SFX := preload("res://assets/audio/farm-plant.wav")
const FARM_WATER_SFX := preload("res://assets/audio/farm-water.wav")
const FARM_HARVEST_SFX := preload("res://assets/audio/farm-harvest.wav")
const COMMERCE_SFX := preload("res://assets/audio/commerce.wav")
const ACTION_ICONS: Array[Texture2D] = [
    preload("res://assets/ui/icons/hoe.png"),
    preload("res://assets/ui/icons/seeds.png"),
    preload("res://assets/ui/icons/watering-can.png"),
    preload("res://assets/ui/icons/hands.png"),
]
const WATERING_CAN_EFFICIENT_ICON := preload("res://assets/ui/icons/watering-can-efficient.png")
const WARNING_ICON := preload("res://assets/ui/icons/warning.png")
const TOAST_SECONDS := 2.5
const SOCIAL_SFX := preload("res://assets/audio/social.wav")
const CONFIRM_SFX := preload("res://assets/audio/confirm.wav")
const CANCEL_SFX := preload("res://assets/audio/cancel.wav")
const DAY_TRANSITION_SFX := preload("res://assets/audio/day-transition.wav")
const FINALE_SFX := preload("res://assets/audio/finale.wav")
const FARM_DAY_LOOP := preload("res://assets/audio/farm-day-loop.wav")
const RIVER_AMBIENCE := preload("res://assets/audio/river-ambience.wav")
const RAIN_AMBIENCE := preload("res://assets/audio/rain-ambience.wav")
const AMBIENCE_HEADROOM_DB := -12.0
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
var _chrome: HudChrome
var _toast: Control
var _toast_label: Label
var _toast_timer: Timer
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
var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _river_ambience_player: AudioStreamPlayer
var _rain_ambience_player: AudioStreamPlayer
var _settings: UiSettings
var _last_snapshot: Dictionary = {}
var _finale_in_progress := false
var _primary_modals: Array[Control] = []
var _esc_close_order: Array[Dictionary] = []

func _ready() -> void:
    _root = $HudRoot as Control
    _weather_tint = $HudRoot/WeatherTint as ColorRect
    _chrome = HudChrome.new()
    _root.add_child(_chrome)
    _chrome.seed_card_pressed.connect(_on_seed_card_pressed)
    _build_modals()
    _build_toast()
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

func configure(settings: UiSettings = null) -> void:
    if settings != null:
        _settings = settings
    apply_settings()

func apply_settings() -> void:
    if _settings == null or _music_player == null or _sfx_player == null:
        return
    _music_player.volume_db = _settings.db_for_level(_settings.music)
    var sound_db := _settings.db_for_level(_settings.sound)
    _sfx_player.volume_db = sound_db
    var ambience_db := maxf(sound_db + AMBIENCE_HEADROOM_DB, -80.0)
    _river_ambience_player.volume_db = ambience_db
    _rain_ambience_player.volume_db = ambience_db
    # Sound 0 is the project's -80 dB mute; pausing also stops the decode.
    var muted := _sound_muted()
    _river_ambience_player.stream_paused = muted
    _rain_ambience_player.stream_paused = muted
    # A muted rainy render leaves Rain idle, and unpausing an idle player
    # starts nothing; the unmute itself must start it or Rain stays silent
    # until the next command-driven render.
    if (
        not muted
        and is_inside_tree()
        and not _rain_ambience_player.playing
        and _last_snapshot.get("weather") == GameRules.weather_key(GameRules.Weather.RAINY)
    ):
        _rain_ambience_player.play()
    _onboarding_overlay.set_tutorial_cards_enabled(_settings.tutorial_cards)
    _settings.apply_window(get_window())
    _settings.apply_language()

func _sound_muted() -> bool:
    return _settings != null and _settings.sound == 0

func render(snapshot: Dictionary) -> void:
    _last_snapshot = snapshot.duplicate(true)
    # Hidden modals re-present through their open_*() paths, so a render —
    # including each passive-clock tick — only pays for panels on screen.
    if _shop_panel.visible:
        _shop_panel.present(snapshot)
    if _shipping_panel.visible:
        _shipping_panel.present(snapshot)
    if _bag_panel.visible:
        _bag_panel.present(snapshot)
    if _almanac_panel.visible:
        _almanac_panel.present(snapshot)
    if _calendar_panel.visible:
        _calendar_panel.present(snapshot)
    _onboarding_overlay.render(snapshot)
    var rainy: bool = snapshot["weather"] == GameRules.weather_key(GameRules.Weather.RAINY)
    _weather_tint.color = RAINY_TINT if rainy else SUNNY_TINT
    if rainy:
        # A detached World can still render (result teardown); playing
        # off-tree only logs errors, so Rain starts only inside the tree.
        # Sound 0 skips the stream instead of decoding it at -80 dB.
        if is_inside_tree() and not _sound_muted() and not _rain_ambience_player.playing:
            _rain_ambience_player.play()
    elif _rain_ambience_player.playing or _rain_ambience_player.stream_paused:
        _rain_ambience_player.stop()
    _chrome.render(snapshot)
    var day := int(snapshot["day"])
    var status_time := GameRules.format_time(int(snapshot["time_minutes"]))
    _pause_panel.set_status_time(status_time)
    _bag_panel.set_status_time(status_time)
    _almanac_panel.set_status_time(status_time)
    _calendar_panel.set_status_time(status_time)
    _settings_panel.set_status_time(status_time)
    _sleep_panel.set_status_time(status_time)
    _morning_summary_panel.set_status_time(status_time)
    _pause_panel.set_day_weather(day, snapshot["weather"])

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
    # starting the cue; the modal close path checks it.
    _finale_in_progress = value

func set_save_status(status: StringName, message: String = "") -> void:
    _morning_summary_panel.set_save_status(status, message)

## Floating prompts over the target cell; `anchor` is the cell centre in
## screen coordinates. WorldShell picks the prompt; the HUD owns the copy.
func show_farming_prompt(anchor: Vector2, preview: Dictionary) -> void:
    var action: GameRules.FarmingAction = preview["action"]
    var crop_suffix := ""
    if preview["crop"] != null:
        crop_suffix = " %s" % tr(GameRules.crop_display_name(preview["crop"]))
    _chrome.show_prompt(
        anchor,
        "Space",
        action_icon(action),
        tr(FARMING_PREVIEW_VERBS[action]) + crop_suffix,
        tr("· %d stamina") % int(preview["cost"]["stamina"]),
    )

func show_blocked_prompt(anchor: Vector2, preview: Dictionary) -> void:
    var icon: Texture2D = null if preview["action"] == null else action_icon(preview["action"])
    _chrome.show_prompt(anchor, "", icon, tr(feedback_text(preview["code"])), "", true)

func show_interact_prompt(anchor: Vector2, label: String) -> void:
    _chrome.show_prompt(anchor, "E", null, tr(label))

func hide_prompt() -> void:
    _chrome.hide_prompt()

func prompt_text() -> String:
    return _chrome.prompt_text()

func prompt_icon() -> Texture2D:
    return _chrome.prompt_icon()

## The tool icon for a farming action; the Efficient Can once owned.
func action_icon(action: GameRules.FarmingAction) -> Texture2D:
    if action == GameRules.FarmingAction.WATERING_CAN and _last_snapshot.get("watering_can_upgraded", false):
        return WATERING_CAN_EFFICIENT_ICON
    return ACTION_ICONS[action]

## The refusal toast's text, or "" when no toast is showing.
func toast_text() -> String:
    return _toast_label.text if _toast.visible else ""

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
    _close_modal(_dialogue_panel)

func open_pause() -> void:
    if _open_modal(_pause_panel):
        _pause_panel.visible = true

func close_pause() -> void:
    _close_modal(_pause_panel)

## Tears down every open user modal in one transaction on map replacement.
## A swap is not a user close, so no CONFIRM_SFX plays; the session-driven
## morning summary and opening overlay are preserved if currently active.
func close_modals() -> void:
    var any_closed := false
    for panel in _primary_modals:
        if panel == _morning_summary_panel or not panel.visible:
            continue
        _hide_modal_panel(panel)
        any_closed = true
    if not any_closed:
        return
    _finish_modal_transition()

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

## Refusal copy for the toast and blocked prompts. Successes have none: the
## world shows them (farm FX, the panels, the session snapshot).
func feedback_text(code: GameRules.CommandCode) -> String:
    match code:
        GameRules.CommandCode.SEED_SELECTED, \
        GameRules.CommandCode.SOIL_TILLED, \
        GameRules.CommandCode.CROP_PLANTED, \
        GameRules.CommandCode.CROP_WATERED, \
        GameRules.CommandCode.CROP_HARVESTED, \
        GameRules.CommandCode.SEEDS_PURCHASED, \
        GameRules.CommandCode.WATERING_CAN_UPGRADED, \
        GameRules.CommandCode.CROP_DEPOSITED, \
        GameRules.CommandCode.DAY_ADVANCED, \
        GameRules.CommandCode.DAY_STARTED, \
        GameRules.CommandCode.VILLAGER_TALKED, \
        GameRules.CommandCode.CROP_GIFTED, \
        GameRules.CommandCode.INTRO_ACKNOWLEDGED, \
        GameRules.CommandCode.INTRO_ALREADY_ACKNOWLEDGED, \
        GameRules.CommandCode.FINALE_TRIGGERED, \
        GameRules.CommandCode.FINALE_ALREADY_TRIGGERED, \
        GameRules.CommandCode.TRAVELLED:
            return ""
        GameRules.CommandCode.WATERING_CAN_ALREADY_UPGRADED:
            return "Watering can is already upgraded."
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
        GameRules.CommandCode.GIFT_ALREADY_GIVEN:
            return "Gift already given today."
        GameRules.CommandCode.MARKET_NOT_READY:
            return "The Harvest Market opens on Day 14."
        GameRules.CommandCode.NOT_AT_MARKET:
            return "Stand at the Harvest Market."
        _:
            assert(false, "unmapped command feedback: %s" % code)
            return ""

## Refusals raise one red toast; any other result clears a stale one.
func show_feedback(code: GameRules.CommandCode) -> void:
    var text := feedback_text(code)
    if text != "":
        _toast_label.text = text
        _toast.visible = true
        _toast_timer.start(TOAST_SECONDS)
    else:
        _toast.visible = false
    var sfx := _sfx_for_code(code)
    if sfx != null:
        _play_sfx(sfx)

func _sfx_for_code(code: GameRules.CommandCode) -> AudioStream:
    match code:
        GameRules.CommandCode.SEED_SELECTED, \
        GameRules.CommandCode.TRAVELLED:
            return ACTION_SFX
        GameRules.CommandCode.SOIL_TILLED:
            return FARM_HOE_SFX
        GameRules.CommandCode.CROP_PLANTED:
            return FARM_PLANT_SFX
        GameRules.CommandCode.CROP_WATERED:
            return FARM_WATER_SFX
        GameRules.CommandCode.CROP_HARVESTED:
            return FARM_HARVEST_SFX
        GameRules.CommandCode.SEEDS_PURCHASED, \
        GameRules.CommandCode.WATERING_CAN_UPGRADED, \
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
    _sfx_player = _add_audio_player(&"SfxPlayer", null, -8.0)
    _music_player = _add_audio_player(&"MusicPlayer", FARM_DAY_LOOP, -20.0, true)
    _river_ambience_player = _add_audio_player(&"RiverAmbience", RIVER_AMBIENCE, -80.0, true)
    _rain_ambience_player = _add_audio_player(&"RainAmbience", RAIN_AMBIENCE, -80.0)

func _add_audio_player(
    node_name: StringName,
    stream: AudioStream,
    volume_db: float,
    playing := false,
) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    player.name = node_name
    player.volume_db = volume_db
    player.stream = stream
    add_child(player)
    if playing:
        player.play()
    return player

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

func _build_toast() -> void:
    # Last HudRoot child, so a refusal inside a modal (the shop's "Not enough
    # money.") still shows above the panel.
    _toast = UiStyle.hbox(0)
    _toast.name = "Toast"
    _toast.alignment = BoxContainer.ALIGNMENT_CENTER
    _toast.anchor_left = 0.0
    _toast.anchor_right = 1.0
    _toast.anchor_top = 1.0
    _toast.anchor_bottom = 1.0
    _toast.offset_bottom = -150.0
    _toast.offset_top = -150.0
    _toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _toast.visible = false
    _root.add_child(_toast)
    var pill := PanelContainer.new()
    pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pill.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.BAD, UiStyle.PILL_RADIUS, [12, 10, 22, 10]))
    _toast.add_child(pill)
    var row := UiStyle.hbox(10)
    pill.add_child(row)
    row.add_child(UiStyle.icon(WARNING_ICON))
    _toast_label = UiStyle.label("", 20, UiStyle.CARD, 800)
    _toast_label.name = "Label"
    row.add_child(_toast_label)
    _toast_timer = Timer.new()
    _toast_timer.name = "ToastTimer"
    _toast_timer.one_shot = true
    _toast_timer.timeout.connect(func() -> void: _toast.visible = false)
    add_child(_toast_timer)

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
    _shop_panel.upgrade_requested.connect(func() -> void:
        upgrade_requested.emit()
    )
    _shop_panel.close_requested.connect(close_shop)
    _shipping_panel = SHIPPING_SCENE.instantiate() as ShippingPanel
    _root.add_child(_shipping_panel)
    _shipping_panel.deposit_requested.connect(func(kind: int, quantity: int) -> void:
        deposit_requested.emit(kind, quantity)
    )
    _shipping_panel.close_requested.connect(close_shipping)
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
    _sleep_panel.close_requested.connect(close_sleep_confirmation)
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
    _pause_panel.bag_requested.connect(open_bag)
    _pause_panel.almanac_requested.connect(open_almanac)
    _pause_panel.calendar_requested.connect(open_calendar)
    _pause_panel.settings_requested.connect(open_settings)
    _pause_panel.resume_requested.connect(close_pause)
    _settings_panel = SETTINGS_SCENE.instantiate() as SettingsPanel
    _root.add_child(_settings_panel)
    _settings_panel.settings_changed.connect(_on_settings_changed)
    _settings_panel.close_requested.connect(close_settings)
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
    # Auto-translated labels follow a language change on their own; text
    # formatted with tr() is rebuilt from the last snapshot.
    if not _last_snapshot.is_empty():
        render(_last_snapshot)
    # Applying settings can re-show the tutorial card while a blocking modal
    # (e.g. Settings) is open; re-reconcile so the card stays hidden under it.
    _reconcile_modal_presentation()

## Clicking the seed card advances the seed like the `2` key does.
func _on_seed_card_pressed() -> void:
    if _last_snapshot.is_empty():
        return
    var kind := GameRules.CROP_KEYS.find(_last_snapshot["selected_seed"])
    select_seed_requested.emit((kind + 1) % GameRules.CropKind.size())

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
        if registered.visible:
            _hide_modal_panel(registered)
    modal_state_changed.emit()
    return true

func _close_modal(panel: Control) -> void:
    if not panel.visible:
        return
    _hide_modal_panel(panel)
    if not _finale_in_progress:
        _play_sfx(CONFIRM_SFX)
    _finish_modal_transition()

func _hide_modal_panel(panel: Control) -> void:
    if panel == _dialogue_panel:
        _dialogue_panel.close_panel()
    else:
        panel.visible = false

func _finish_modal_transition() -> void:
    _onboarding_overlay.render(_last_snapshot)
    _reconcile_modal_presentation()
    modal_state_changed.emit()

func _set_hud_chrome_visible(is_visible: bool) -> void:
    _chrome.visible = is_visible

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_bag"):
        if _bag_panel.visible:
            close_bag()
        elif not has_blocking_modal() or _pause_panel.visible:
            open_bag()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("toggle_almanac"):
        if _almanac_panel.visible:
            close_almanac()
        elif not has_blocking_modal() or _pause_panel.visible:
            open_almanac()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("toggle_calendar"):
        if _calendar_panel.visible:
            close_calendar()
        elif not has_blocking_modal() or _pause_panel.visible:
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
