class_name WorldShell
extends Node2D

signal finale_completed(final_state: Dictionary, save_error: int)

const PERIMETER_BAND_WIDTH := 1.0
const FARM_ACTION_SUCCESS_CODES := [
    GameRules.CommandCode.SOIL_TILLED,
    GameRules.CommandCode.CROP_PLANTED,
    GameRules.CommandCode.CROP_WATERED,
    GameRules.CommandCode.CROP_HARVESTED,
]

var _session: GameSession
var _initial_state: Variant = null
var _save_repository: SaveRepository = null
var _world_input_enabled := true
var _finale_in_progress := false

@onready var player: PlayerController = $Entities/Player as PlayerController
@onready var farm_view: FarmView = $Entities as FarmView
@onready var hud: GameHud = $GameHud as GameHud

static func perimeter_footprints() -> Array[Rect2]:
    var map_size := Vector2(WorldContract.MAP_SIZE)
    return [
        Rect2(0.0, -PERIMETER_BAND_WIDTH, map_size.x, PERIMETER_BAND_WIDTH),
        Rect2(map_size.x, 0.0, PERIMETER_BAND_WIDTH, map_size.y),
        Rect2(0.0, map_size.y, map_size.x, PERIMETER_BAND_WIDTH),
        Rect2(-PERIMETER_BAND_WIDTH, 0.0, PERIMETER_BAND_WIDTH, map_size.y),
    ]

func configure(initial_state: Variant, repository: SaveRepository) -> void:
    assert(not is_inside_tree())
    _initial_state = initial_state.duplicate(true) if initial_state != null else null
    _save_repository = repository

func _ready() -> void:
    _session = GameSession.new()
    if _initial_state != null and not _session.restore_state(_initial_state):
        push_error("AppRoot supplied invalid restored state")
        _session = GameSession.new()

    get_window().min_size = Vector2i(640, 360)

    var static_collision := get_node("StaticCollision") as StaticBody2D
    var tree_collision := static_collision.get_node("TreeCollision") as CollisionPolygon2D
    var building_collision := static_collision.get_node("BuildingCollision") as CollisionPolygon2D
    var shipping_collision := static_collision.get_node("ShippingCollision") as CollisionPolygon2D
    var market_collision := static_collision.get_node("HarvestMarketCollision") as CollisionPolygon2D
    tree_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.TREE_FOOTPRINT)
    building_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.BUILDING_FOOTPRINT)
    shipping_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT)
    market_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.MARKET_FOOTPRINT)

    for id in range(VillagerRules.VillagerId.size()):
        var collision := static_collision.get_node(
            WorldContract.VILLAGER_COLLISION_NAMES[id]
        ) as CollisionPolygon2D
        collision.polygon = WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id))

    var perimeter_names := ["PerimeterTop", "PerimeterRight", "PerimeterBottom", "PerimeterLeft"]
    var perimeter_rects := perimeter_footprints()
    for index in perimeter_rects.size():
        var perimeter := static_collision.get_node(perimeter_names[index]) as CollisionPolygon2D
        perimeter.polygon = WorldMath.footprint_to_polygon(perimeter_rects[index])

    hud.select_action_requested.connect(_on_select_action_requested)
    hud.select_seed_requested.connect(_on_select_seed_requested)
    hud.buy_requested.connect(_on_buy_requested)
    hud.deposit_requested.connect(_on_deposit_requested)
    hud.sleep_requested.connect(_on_sleep_requested)
    hud.gift_requested.connect(_on_gift_requested)
    hud.morning_summary_acknowledged.connect(_on_morning_summary_acknowledged)
    hud.intro_acknowledged.connect(_on_intro_acknowledged)
    hud.modal_state_changed.connect(_refresh_world_input_gate)
    _refresh_from_session()

func _process(_delta: float) -> void:
    var target: Variant = player.current_target_cell()

    if not _world_input_enabled:
        player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
        hud.set_interaction_hint("")
        return

    var preview := _session.preview_selected_action(target)
    if FARM_ACTION_SUCCESS_CODES.has(preview):
        player.set_target_tint(PlayerController.TargetTint.VALID)
        hud.set_interaction_hint("Space — use selected action")
        return
    if preview != GameRules.CommandCode.NO_TARGET and preview != GameRules.CommandCode.NOT_FARM_CELL:
        player.set_target_tint(PlayerController.TargetTint.INVALID)
        hud.set_interaction_hint(hud.feedback_text(preview))
        return

    player.set_target_tint(PlayerController.TargetTint.NEUTRAL)
    # Continue into the existing villager/shop/bed/shipping/market/empty hint chain.
    var villager_id := WorldContract.villager_at(target)
    if villager_id >= 0:
        hud.set_interaction_hint("%s — E" % VillagerRules.display_name(villager_id))
    elif target == WorldContract.SHOP_CELL:
        hud.set_interaction_hint("Shop — E")
    elif target == WorldContract.BED_CELL:
        hud.set_interaction_hint("Bed — E")
    elif target == WorldContract.SHIPPING_CELL:
        hud.set_interaction_hint("Shipping — E")
    elif target == WorldContract.MARKET_CELL:
        hud.set_interaction_hint("Harvest Market — E")
    else:
        hud.set_interaction_hint("")

func _refresh_from_session() -> void:
    var snapshot := _session.snapshot()
    farm_view.refresh(snapshot)
    hud.render(snapshot)
    _refresh_world_input_gate()

func _refresh_world_input_gate() -> void:
    # The finale transition is terminal: once it begins, no command may reach
    # the session/HUD, so the finale cue stream cannot be replaced mid-play
    # while _finish_finale awaits the cue (the terminal state opens no modal,
    # so the modal gate alone would leave input enabled).
    _world_input_enabled = not _finale_in_progress and not hud.has_blocking_modal()
    player.set_input_enabled(_world_input_enabled)

func select_action_slot(slot: int) -> void:
    if not _world_input_enabled:
        return
    match slot:
        1:
            _finish_command(_session.select_action(GameRules.FarmingAction.HOE))
        2:
            _finish_command(_session.select_action(GameRules.FarmingAction.SEEDS))
        3:
            _finish_command(_session.select_action(GameRules.FarmingAction.WATERING_CAN))
        4:
            _finish_command(_session.select_action(GameRules.FarmingAction.HANDS))

func use_selected_action() -> void:
    if not _world_input_enabled:
        return
    var target: Variant = player.current_target_cell()
    _finish_command(_session.apply_selected_action(target))

func interact() -> void:
    if not _world_input_enabled:
        return
    var target: Variant = player.current_target_cell()
    var villager_id := WorldContract.villager_at(target)
    if villager_id >= 0:
        _finish_social_command(villager_id, _session.talk_to(villager_id, target))
    elif target == WorldContract.SHOP_CELL:
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
    if event.is_action_pressed("select_hoe"):
        select_action_slot(1)
    elif event.is_action_pressed("select_seeds"):
        select_action_slot(2)
    elif event.is_action_pressed("select_water"):
        select_action_slot(3)
    elif event.is_action_pressed("select_hands"):
        select_action_slot(4)
    elif event.is_action_pressed("use_action"):
        use_selected_action()
    elif event.is_action_pressed("interact"):
        interact()

func _on_select_action_requested(action: int) -> void:
    if not _world_input_enabled:
        return
    _finish_command(_session.select_action(action))

func _on_select_seed_requested(kind: int) -> void:
    if not _world_input_enabled:
        return
    _finish_command(_session.select_seed(kind))

func _on_buy_requested(kind: int, quantity: int) -> void:
    var target: Variant = player.current_target_cell()
    _finish_command(_session.buy_seeds(kind, quantity, target))

func _on_deposit_requested(kind: int, quantity: int) -> void:
    var target: Variant = player.current_target_cell()
    _finish_command(_session.deposit_crop(kind, quantity, target))

func _on_sleep_requested() -> void:
    # The finale transition is terminal. The sleep confirmation modal stays
    # open while _finish_finale awaits the cue (closing it would play
    # CONFIRM_SFX and cut the cue itself), so the world-input gate does not
    # cover this signal. A duplicate sleep here would resolve to
    # FINALE_ALREADY_TRIGGERED and show_feedback() would restart FINALE_SFX,
    # cutting the original cue. Guard it explicitly.
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
    var target: Variant = player.current_target_cell()
    _finish_social_command(villager_id, _session.gift_crop(villager_id, crop_kind, target))

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
