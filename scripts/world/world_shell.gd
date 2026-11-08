class_name WorldShell
extends Node2D

signal finale_completed(final_state: Dictionary, save_error: int)

enum MapId { FARM }

const FARM_MAP_SCENE := preload("res://scenes/world/farm_map.tscn")
const FARM_ACTION_SUCCESS_CODES := [
    GameRules.CommandCode.SOIL_TILLED,
    GameRules.CommandCode.CROP_PLANTED,
    GameRules.CommandCode.CROP_WATERED,
    GameRules.CommandCode.CROP_HARVESTED,
]

const ACTION_HOLD_DWELL_SECONDS := 0.15
# A hitched or breakpoint-stalled frame must not bank game minutes.
const CLOCK_DELTA_CLAMP := 0.1

var _session: GameSession
var _initial_state: Variant = null
var _save_repository: SaveRepository = null
var _settings: UiSettings
var _world_input_enabled := true
var _finale_in_progress := false
var _action_hold_active := false
var _action_hold_target: Variant = null
var _action_hold_dwell := 0.0
var _action_hold_action: Variant = null
var clock_running := true
var _clock_elapsed_seconds := 0.0
var _clock_window_focused := true
var _map: FarmMap

@onready var player: PlayerController = $Player as PlayerController
@onready var hud: GameHud = $GameHud as GameHud

var farm_view: FarmView:
    get:
        return _map.entities

func configure(
    initial_state: Variant,
    repository: SaveRepository,
    settings: UiSettings = null,
) -> void:
    assert(not is_inside_tree())
    _initial_state = initial_state.duplicate(true) if initial_state != null else null
    _save_repository = repository
    _settings = settings

func _ready() -> void:
    if _settings == null:
        _settings = UiSettings.new()
    _session = GameSession.new()
    if _initial_state != null and not _session.restore_state(_initial_state):
        push_error("AppRoot supplied invalid restored state")
        _session = GameSession.new()

    var window := get_window()
    window.min_size = UiSettings.min_window_size(
        DisplayServer.screen_get_usable_rect(window.current_screen).size
    )
    # Focus notifications only fire on transitions; a world that enters the
    # tree already unfocused must not tick until its first focus-in.
    _clock_window_focused = window.has_focus()
    hud.configure(_settings)

    player.target_highlight = $TargetHighlight as Line2D

    hud.select_seed_requested.connect(_on_select_seed_requested)
    hud.buy_requested.connect(_on_buy_requested)
    hud.upgrade_requested.connect(_on_upgrade_requested)
    hud.deposit_requested.connect(_on_deposit_requested)
    hud.sleep_requested.connect(_on_sleep_requested)
    hud.gift_requested.connect(_on_gift_requested)
    hud.morning_summary_acknowledged.connect(_on_morning_summary_acknowledged)
    hud.intro_acknowledged.connect(_on_intro_acknowledged)
    hud.modal_state_changed.connect(_refresh_world_input_gate)

    load_map(MapId.FARM)

func load_map(map_id: MapId) -> void:
    var scene: PackedScene
    match map_id:
        MapId.FARM:
            scene = FARM_MAP_SCENE

    _cancel_action_hold()
    hud.hide_prompt()
    hud.close_modals()
    player.set_target_tint(PlayerController.TargetTint.NEUTRAL)

    if player.get_parent() != self:
        player.get_parent().remove_child(player)
        add_child(player)
    if _map != null:
        remove_child(_map)
        _map.queue_free()

    _map = scene.instantiate() as FarmMap
    add_child(_map)
    move_child(_map, 0)

    player.reparent(_map.entities)
    _map.entities.move_child(player, 0)
    player.owner = self
    player.enter_map(_map.SPAWN, _map.CAMERA_BOUNDS)
    _map.bind_player(player)
    _refresh_from_session()

func _process(delta: float) -> void:
    if clock_running and _clock_window_focused:
        _advance_passive_clock(minf(delta, CLOCK_DELTA_CLAMP))
    var target: Variant = player.current_target_cell()

    if not _world_input_enabled:
        player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
        farm_view.set_target_cell(null)
        hud.hide_prompt()
        return

    var preview: Dictionary = _session.preview_target_action(target)
    if _advance_action_hold(delta, target, preview):
        return
    farm_view.set_target_cell(target)
    # A held gesture is bound to one action: a farm tile resolving a
    # different action shows neutral rather than advertising work the
    # hold will never do.
    if (
        _action_hold_active
        and _action_hold_action != null
        and preview["action"] != null
        and preview["action"] != _action_hold_action
    ):
        player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
        hud.hide_prompt()
        return
    if FARM_ACTION_SUCCESS_CODES.has(preview["code"]):
        player.set_target_tint(PlayerController.TargetTint.VALID)
        hud.show_farming_prompt(_prompt_anchor(target), preview)
        return
    if preview["code"] != GameRules.CommandCode.NO_TARGET and preview["code"] != GameRules.CommandCode.NOT_FARM_CELL:
        player.set_target_tint(PlayerController.TargetTint.INVALID)
        hud.show_blocked_prompt(_prompt_anchor(target), preview)
        return

    player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
    # Continue into the existing shop/bed/shipping/market/empty prompt chain.
    var label := _interact_label(target)
    if label == "":
        hud.hide_prompt()
    else:
        hud.show_interact_prompt(_prompt_anchor(target), label)

func _interact_label(target: Variant) -> String:
    if target == null:
        return ""
    match target:
        WorldContract.SHOP_CELL:
            return "Seed Box"
        WorldContract.BED_CELL:
            return "Bed"
        WorldContract.SHIPPING_CELL:
            return "Shipping"
        WorldContract.MARKET_CELL:
            return "Harvest Market"
    return ""

## The target cell's centre in HUD (screen) coordinates.
func _prompt_anchor(cell: Vector2i) -> Vector2:
    return get_viewport().get_canvas_transform() * WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))

func _advance_passive_clock(delta: float) -> void:
    if not _world_input_enabled or delta <= 0.0:
        return
    _clock_elapsed_seconds += delta
    var whole_minutes := floori(_clock_elapsed_seconds / GameRules.REAL_SECONDS_PER_GAME_MINUTE)
    if whole_minutes <= 0:
        return
    _clock_elapsed_seconds -= whole_minutes * GameRules.REAL_SECONDS_PER_GAME_MINUTE
    if _session.advance_clock(whole_minutes):
        _refresh_from_session()

func _refresh_from_session() -> void:
    var snapshot := _session.snapshot()
    farm_view.refresh(snapshot)
    _map.ambience.render(snapshot)
    hud.render(snapshot)
    _refresh_world_input_gate()

func _refresh_world_input_gate() -> void:
    # The finale transition is terminal: once it begins, no command may reach
    # the session/HUD, so the finale cue stream cannot be replaced mid-play
    # while _finish_finale awaits the cue (the terminal state opens no modal,
    # so the modal gate alone would leave input enabled).
    _world_input_enabled = not _finale_in_progress and not hud.has_blocking_modal()
    if not _world_input_enabled:
        _cancel_action_hold()
    player.set_input_enabled(_world_input_enabled)

func cycle_seed() -> void:
    if not _world_input_enabled:
        return
    _cancel_action_hold()
    _finish_command(_session.select_seed((_session.selected_seed() + 1) % GameRules.CropKind.size()))

func _attempt_target_action(target_cell: Variant, preview: Dictionary) -> void:
    # Capture the presentation facts that mutation could destroy (notably the
    # harvest crop kind) before dispatching the authoritative command.
    var facing := player.facing
    var player_position := player.global_position
    var code := _session.apply_target_action(target_cell)
    _finish_command(code)
    if FARM_ACTION_SUCCESS_CODES.has(code):
        _map.effects.play_success(code, preview, target_cell, facing, player_position)

func _cancel_action_hold() -> void:
    _action_hold_active = false
    _action_hold_target = null
    _action_hold_dwell = 0.0
    _action_hold_action = null

func _advance_action_hold(delta: float, target: Variant, preview: Dictionary) -> bool:
    if not _action_hold_active:
        return false
    if target != _action_hold_target:
        _action_hold_target = target
        _action_hold_dwell = 0.0
        # Off-farm presses bind on the first farm tile reached (even if
        # blocked); farm presses already carry the lock from the press.
        if _action_hold_action == null and preview["action"] != null:
            _action_hold_action = preview["action"]
        return false
    _action_hold_dwell += delta
    if _action_hold_dwell < ACTION_HOLD_DWELL_SECONDS:
        return false
    if not FARM_ACTION_SUCCESS_CODES.has(preview["code"]):
        return false
    if preview["action"] != _action_hold_action:
        return false
    _attempt_target_action(target, preview)
    return true

func use_target_action() -> void:
    if not _world_input_enabled:
        return
    # One-shot wrapper: it never starts or advances hold state.
    var target: Variant = player.current_target_cell()
    _attempt_target_action(target, _session.preview_target_action(target))

func _notification(what: int) -> void:
    # Focus-in is window-level only: application FOCUS_IN can arrive while
    # the window is still hidden (e.g. Cmd+Tab back to a minimized macOS
    # window), which would resume the clock over an invisible game. Any
    # focus-out flavor pauses the clock and drops the held gesture —
    # pausing on ambiguous focus loss is always safe.
    if (
        what == NOTIFICATION_APPLICATION_FOCUS_OUT
        or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT
    ):
        _clock_window_focused = false
        _cancel_action_hold()
    elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
        _clock_window_focused = true

func interact() -> void:
    if not _world_input_enabled:
        return
    var target: Variant = player.current_target_cell()
    if target == WorldContract.SHOP_CELL:
        hud.open_shop()
    elif target == WorldContract.SHIPPING_CELL:
        hud.open_shipping()
    elif target == WorldContract.BED_CELL:
        hud.open_sleep_confirmation()
    elif target == WorldContract.MARKET_CELL:
        _finish_finale(_session.trigger_harvest_finale(target))
    else:
        hud.show_feedback(GameRules.CommandCode.NOTHING_TO_INTERACT)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("select_seeds"):
        cycle_seed()
    elif event.is_action_pressed("use_action"):
        # Hold-to-work start: return before touching hold state while gated;
        # otherwise reset and dispatch exactly once on the fresh press.
        if not _world_input_enabled:
            return
        _cancel_action_hold()
        _action_hold_active = true
        _action_hold_target = player.current_target_cell()
        _action_hold_dwell = 0.0
        var press_preview := _session.preview_target_action(_action_hold_target)
        _action_hold_action = press_preview["action"]
        _attempt_target_action(_action_hold_target, press_preview)
    elif event.is_action_released("use_action"):
        _cancel_action_hold()
    elif event.is_action_pressed("interact"):
        interact()

func _on_select_seed_requested(kind: int) -> void:
    if not _world_input_enabled:
        return
    _cancel_action_hold()
    _finish_command(_session.select_seed(kind))

func _on_buy_requested(kind: int, quantity: int) -> void:
    var target: Variant = player.current_target_cell()
    _finish_command(_session.buy_seeds(kind, quantity, target))

func _on_upgrade_requested() -> void:
    var target: Variant = player.current_target_cell()
    _finish_command(_session.buy_watering_can_upgrade(target))

func _on_deposit_requested(kind: int, quantity: int) -> void:
    var target: Variant = player.current_target_cell()
    _finish_command(_session.deposit_crop(kind, quantity, target))

func _on_sleep_requested() -> void:
    # The finale transition is terminal. _finish_finale closes the sleep
    # modal before starting the cue, but sleep_requested is a HUD signal
    # that bypasses _world_input_enabled, so a duplicate emit here would
    # still resolve to FINALE_ALREADY_TRIGGERED and show_feedback() would
    # restart FINALE_SFX, cutting the original cue. Guard it explicitly.
    if _finale_in_progress:
        return
    var target: Variant = player.current_target_cell()
    var code := _session.sleep(target)
    if code == GameRules.CommandCode.FINALE_TRIGGERED:
        _finish_finale(code)
        return
    if code != GameRules.CommandCode.DAY_ADVANCED or _save_repository == null:
        _finish_command(code)
        return

    hud.show_feedback(code)
    _refresh_from_session()

    var save_error := _save_repository.save(_session.state())
    if save_error == OK:
        hud.set_save_status(&"saved")
    else:
        hud.set_save_status(&"error", "Save failed — this morning is not persisted.")

func _finish_finale(code: GameRules.CommandCode) -> void:
    if code != GameRules.CommandCode.FINALE_TRIGGERED:
        _finish_command(code)
        return
    _finale_in_progress = true
    hud.set_finale_in_progress(true)
    # Close the sleep confirmation modal before starting the finale cue so
    # its Cancel button and Esc (which route to close_sleep_confirmation →
    # _play_sfx(CONFIRM_SFX)) cannot replace FINALE_SFX during the
    # await_feedback_cue() window. The HUD finale lock suppresses
    # CONFIRM_SFX, so the modal closes silently and only FINALE_SFX plays.
    # No-op on the market path, where the sleep modal was never opened.
    hud.close_sleep_confirmation()
    hud.show_feedback(code)
    _refresh_from_session()
    var state := _session.state()
    var save_error := ERR_UNAVAILABLE
    if _save_repository != null:
        save_error = _save_repository.save(state)
    # Hold the live world until the finale cue has played so AppRoot's
    # synchronous result teardown cannot cut the stream off before a frame.
    await hud.await_feedback_cue()
    finale_completed.emit(state, save_error)

func _on_gift_requested(villager_id: int, crop_kind: int) -> void:
    _finish_social_command(villager_id, _session.gift_crop(villager_id, crop_kind))

func _on_morning_summary_acknowledged() -> void:
    _finish_command(_session.acknowledge_morning_summary())

func _on_intro_acknowledged() -> void:
    _finish_command(_session.acknowledge_intro())

func _finish_social_command(villager_id: int, result: Dictionary) -> void:
    hud.show_feedback(result["code"])
    _refresh_from_session()
    if result["code"] == GameRules.CommandCode.VILLAGER_TALKED:
        hud.open_dialogue(villager_id, result, _session.snapshot())
    elif result["code"] == GameRules.CommandCode.CROP_GIFTED:
        hud.update_dialogue(villager_id, result, _session.snapshot())

func _finish_command(code: GameRules.CommandCode) -> void:
    hud.show_feedback(code)
    _refresh_from_session()
