class_name WorldShell
extends Node2D

const PERIMETER_BAND_WIDTH := 1.0

var _session := GameSession.new()
var _world_input_enabled := true

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

func _ready() -> void:
    get_window().min_size = Vector2i(640, 360)

    var static_collision := get_node("StaticCollision") as StaticBody2D
    var tree_collision := static_collision.get_node("TreeCollision") as CollisionPolygon2D
    var building_collision := static_collision.get_node("BuildingCollision") as CollisionPolygon2D
    var shipping_collision := static_collision.get_node("ShippingCollision") as CollisionPolygon2D
    tree_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.TREE_FOOTPRINT)
    building_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.BUILDING_FOOTPRINT)
    shipping_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT)

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
    hud.morning_summary_acknowledged.connect(_on_morning_summary_acknowledged)
    hud.modal_state_changed.connect(_refresh_world_input_gate)
    _refresh_from_session()

func _process(_delta: float) -> void:
    var target: Variant = player.current_target_cell()
    if target == WorldContract.SHOP_CELL:
        hud.set_interaction_hint("Shop — E")
    elif target == WorldContract.BED_CELL:
        hud.set_interaction_hint("Bed — E")
    elif target == WorldContract.SHIPPING_CELL:
        hud.set_interaction_hint("Shipping — E")
    else:
        hud.set_interaction_hint("")

func _refresh_from_session() -> void:
    var snapshot := _session.snapshot()
    farm_view.refresh(snapshot)
    hud.render(snapshot)
    _refresh_world_input_gate()

func _refresh_world_input_gate() -> void:
    _world_input_enabled = not hud.has_blocking_modal()
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
    if target == WorldContract.SHOP_CELL:
        hud.open_shop()
    elif target == WorldContract.SHIPPING_CELL:
        hud.open_shipping()
    elif target == WorldContract.BED_CELL:
        hud.open_sleep_confirmation()
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
    var target: Variant = player.current_target_cell()
    _finish_command(_session.sleep(target))

func _on_morning_summary_acknowledged() -> void:
    _finish_command(_session.acknowledge_morning_summary())

func _finish_command(code: GameRules.CommandCode) -> void:
    hud.show_feedback(code)
    _refresh_from_session()
