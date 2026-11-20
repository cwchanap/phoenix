class_name WorldShell
extends Node2D

signal finale_completed(final_state: Dictionary, save_error: int)

const FARM_MAP_SCENE := preload("res://scenes/world/farm_map.tscn")
const TOWN_MAP_SCENE := preload("res://scenes/world/town_map.tscn")
const FARM_ACTION_SUCCESS_CODES := [
    GameRules.CommandCode.SOIL_TILLED,
    GameRules.CommandCode.CROP_PLANTED,
    GameRules.CommandCode.CROP_WATERED,
    GameRules.CommandCode.CROP_HARVESTED,
]

const ACTION_HOLD_DWELL_SECONDS := 0.15
# A hitched or breakpoint-stalled frame must not bank game minutes.
const CLOCK_DELTA_CLAMP := 0.1
# HPA-743 foreground occluders sink to this alpha while the player stands
# behind them; each prop's own Sprite2D tracks it, nothing is shared.
const FADE_ALPHA := 0.45

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
var _map: GameMap
var _interact_regions: Array = []
var _interact_target: Variant = null

@onready var player: PlayerController = $Player as PlayerController
@onready var rain_layer: RainLayer = $RainLayer as RainLayer
@onready var hud: GameHud = $GameHud as GameHud

var farm_view: FarmView:
    get:
        var farm := _map as FarmMap
        return farm.entities if farm != null else null

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
    hud.market_confirmed.connect(_on_market_confirmed)
    hud.gift_requested.connect(_on_gift_requested)
    hud.morning_summary_acknowledged.connect(_on_morning_summary_acknowledged)
    hud.intro_acknowledged.connect(_on_intro_acknowledged)
    hud.modal_state_changed.connect(_refresh_world_input_gate)

    load_map()

func load_map(arrived_by_truck: bool = false) -> void:
    var snapshot := _session.snapshot()
    var location: int = snapshot["location"]
    var scene := TOWN_MAP_SCENE if location == GameRules.MapId.TOWN else FARM_MAP_SCENE

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

    var map := scene.instantiate() as GameMap
    _map = map
    _interact_regions = (
        WorldContract.interact_regions()
        if _map is FarmMap
        else TownContract.interact_regions()
    )
    _interact_target = null
    add_child(_map)
    move_child(_map, 0)

    var entities := _map.get_node("Entities") as Node2D
    player.reparent(entities)
    entities.move_child(player, 0)
    player.owner = self
    player.enter_map(map.spawn_position(arrived_by_truck), map.camera_bounds(), map.map_size())
    var farm := _map as FarmMap
    if farm != null:
        farm.bind_player(player)
    _refresh_from_session(snapshot)

func _process(delta: float) -> void:
    # The fade runs before every early return so occluders track the player
    # while a modal is open or a farming preview ends the frame early.
    _update_occluder_fade(delta)
    # Every frame starts from the true raw diamond: refresh_target() repaints
    # the highlight from the live pose even without a physics tick (fixtures
    # drive _process directly), so no stale E-hint diamond survives into
    # farming, blocked, idle or early-return frames.
    player.refresh_target()
    if clock_running and _clock_window_focused:
        _advance_passive_clock(minf(delta, CLOCK_DELTA_CLAMP))
    var target: Variant = player.current_target_cell()

    var view := farm_view
    if not _world_input_enabled:
        player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
        if view != null:
            view.set_target_cell(null)
        hud.hide_prompt()
        return

    var preview: Dictionary = _session.preview_target_action(target)
    if _advance_action_hold(delta, target, preview):
        return
    # An in-reach, faced E interactable takes prompt and highlight priority
    # over a raw farm preview (except mid-hold on a farm tile or when an
    # active-day gate like morning summary blocks all actions), so the visible
    # hint and E always agree and only one cell is highlighted.
    var active_day_blocked: bool = (
        preview["action"] == null
        and preview["code"] != GameRules.CommandCode.NO_TARGET
        and preview["code"] != GameRules.CommandCode.NOT_FARM_CELL
    )
    if not active_day_blocked and (not _action_hold_active or preview["action"] == null):
        var resolved := _resolve_interactable()
        if not resolved.is_empty():
            if view != null:
                view.set_target_cell(null)
            player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
            var cell: Vector2i = resolved["cell"]
            hud.show_interact_prompt(_prompt_anchor(cell), resolved["label"])
            player.target_highlight.points = WorldMath.cell_diamond(cell)
            player.target_highlight.visible = true
            return
    if view != null:
        view.set_target_cell(target)
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
    hud.hide_prompt()

## HPA-743 shared foreground fade: props the player can walk behind sink
## toward FADE_ALPHA while their drawn bounds overlap the player's and their
## root sorts in front (Player is Entities child 0 for exact Y ties). The
## group is queried per frame — no stored references survive map swaps — and
## only each prop's own Sprite2D moves; the sibling Shadow stays untouched.
func _update_occluder_fade(delta: float) -> void:
    if _map == null:
        return
    var player_bounds := _sprite_global_bounds(player.player_sprite)
    var player_y := player.global_position.y
    for node in get_tree().get_nodes_in_group("player_occluder"):
        var prop := node as Node2D
        if prop == null or not _map.is_ancestor_of(prop):
            continue
        var sprite := prop.get_node_or_null("Sprite2D") as Sprite2D
        if sprite == null:
            continue
        var fades := (
            prop.global_position.y >= player_y
            and _sprite_global_bounds(sprite).intersects(player_bounds)
        )
        sprite.self_modulate.a = move_toward(
            sprite.self_modulate.a,
            FADE_ALPHA if fades else 1.0,
            delta,
        )

## The AABB of a sprite's drawn rectangle in global canvas space.
static func _sprite_global_bounds(sprite: Sprite2D) -> Rect2:
    var rect := sprite.get_rect()
    var transform := sprite.get_global_transform()
    var bounds := Rect2(transform * rect.position, Vector2.ZERO)
    bounds = bounds.expand(transform * (rect.position + Vector2(rect.size.x, 0.0)))
    bounds = bounds.expand(transform * (rect.position + rect.size))
    bounds = bounds.expand(transform * (rect.position + Vector2(0.0, rect.size.y)))
    return bounds

func _interactable(target: Variant) -> Dictionary:
    if target == null:
        return {}
    if _map is FarmMap:
        match target:
            WorldContract.BED_CELL:
                return {"label": "Go to bed", "action": hud.open_sleep_confirmation}
            WorldContract.SHIPPING_CELL:
                return {"label": "Shipping", "action": hud.open_shipping}
            WorldContract.TRUCK_CELL:
                return {
                    "label": "Drive to town",
                    "action": func() -> void: _attempt_travel(target),
                }
    else:
        var villager_id := TownContract.villager_at(target)
        if villager_id >= 0:
            return {
                "label": VillagerRules.display_name(villager_id),
                "action": func() -> void:
                    _finish_social_command(villager_id, _session.talk_to(villager_id)),
            }
        match target:
            TownContract.SHOP_CELL:
                return {"label": "Seed Shop", "action": hud.open_shop}
            TownContract.MARKET_CELL:
                return {
                    "label": "Harvest Market",
                    "action": func() -> void: _attempt_market(target),
                }
            TownContract.TRUCK_CELL:
                return {
                    "label": "Drive home",
                    "action": func() -> void: _attempt_travel(target),
                }
    return {}

## HPA-743 one E resolver: physical contact regions first — the nearest
## canonical cell whose projected footprint contact sits within the inclusive
## reach and is positively faced (contract order breaks ties). When a region
## is within reach but none is faced, refuse instead of raw-falling back; the
## exact raw target cell remains the fixture/legacy input path only when no
## region is nearby.
func _resolve_interactable() -> Dictionary:
    var player_position := player.global_position
    # The facing's screen direction, sign-equivalent without normalization:
    # the facing's grid diagonal projected through the isometric transform.
    var facing_direction := WorldMath.grid_delta_to_world(
        WorldMath.TARGET_OFFSETS[player.facing]
    )
    var best_cell: Variant = null
    var best_distance := INF
    var any_within_reach := false
    for region in _interact_regions:
        var contact := WorldMath.closest_contact(player_position, region["footprint"])
        var distance := player_position.distance_to(contact)
        if distance > WorldContract.INTERACT_REACH_PIXELS:
            continue
        any_within_reach = true
        if facing_direction.dot(contact - player_position) > 0.0 and distance < best_distance:
            best_cell = region["cell"]
            best_distance = distance
    if best_cell != null:
        return _resolved_interactable(best_cell)
    if any_within_reach:
        return {}
    return _resolved_interactable(player.current_target_cell())

## `_interactable(cell)` plus the canonical cell it resolved, so hints,
## prompts and submit handlers share one dictionary ({cell, label, action}).
func _resolved_interactable(cell: Variant) -> Dictionary:
    var info := _interactable(cell)
    if info.is_empty():
        return {}
    info["cell"] = cell
    return info

## Reuse the canonical cell captured when E opened the modal; fall back to
## live resolution when a test opens a modal directly through GameHud.
func _submit_target_cell() -> Variant:
    if _interact_target != null:
        return _interact_target
    var resolved := _resolve_interactable()
    return null if resolved.is_empty() else resolved["cell"]

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

func _refresh_from_session(snapshot: Dictionary = {}) -> void:
    if snapshot.is_empty():
        snapshot = _session.snapshot()
    rain_layer.render(snapshot)
    var farm := _map as FarmMap
    if farm != null:
        farm.entities.refresh(snapshot)
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
    if not hud.has_blocking_modal():
        _interact_target = null
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
    var farm := _map as FarmMap
    if FARM_ACTION_SUCCESS_CODES.has(code) and farm != null:
        farm.effects.play_success(code, preview, target_cell, facing, player_position)

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
    var info := _resolve_interactable()
    if info.is_empty():
        hud.show_feedback(GameRules.CommandCode.NOTHING_TO_INTERACT)
        return
    _interact_target = info["cell"]
    var action: Callable = info["action"]
    action.call()
    if not hud.has_blocking_modal():
        _interact_target = null

func _attempt_travel(target: Variant) -> void:
    var preview := _session.preview_travel(target)
    var code: GameRules.CommandCode = preview["code"]
    hud.show_feedback(code)
    if code != GameRules.CommandCode.TRAVELLED:
        return
    hud.play_travel(
        preview["destination"],
        preview["departure_minutes"],
        preview["arrival_minutes"],
        func() -> void:
            if _session.travel(target) == GameRules.CommandCode.TRAVELLED:
                load_map(true),
    )

func _attempt_market(target: Variant) -> void:
    if _session.day() == GameRules.MAX_DAY:
        hud.open_market_confirmation()
        return
    _finish_finale(_session.trigger_harvest_finale(target))

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
    _finish_command(_session.buy_seeds(kind, quantity, _submit_target_cell()))

func _on_upgrade_requested() -> void:
    _finish_command(_session.buy_watering_can_upgrade(_submit_target_cell()))

func _on_deposit_requested(kind: int, quantity: int) -> void:
    _finish_command(_session.deposit_crop(kind, quantity, _submit_target_cell()))

func _on_sleep_requested() -> void:
    # The finale transition is terminal. _finish_finale closes the sleep
    # modal before starting the cue, but sleep_requested is a HUD signal
    # that bypasses _world_input_enabled, so a duplicate emit here would
    # still resolve to FINALE_ALREADY_TRIGGERED and show_feedback() would
    # restart FINALE_SFX, cutting the original cue. Guard it explicitly.
    if _finale_in_progress:
        return
    var code := _session.sleep(_submit_target_cell())
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

func _on_market_confirmed() -> void:
    if _finale_in_progress:
        return
    _finish_finale(_session.trigger_harvest_finale(_submit_target_cell()))

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
    hud.close_modals()
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
