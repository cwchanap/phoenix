extends SceneTree

const DEFAULT_TILE := Vector2i(0, 0)
const FARM_TILE := Vector2i(1, 0)
const PATH_TILE := Vector2i(2, 0)
const EXPECTED_ASSETS := {
    "proof-tiles": Vector2i(192, 32),
    "proof-player": Vector2i(128, 48),
    "proof-scenery": Vector2i(384, 96),
    "proof-soil": Vector2i(128, 32),
    "proof-crops": Vector2i(128, 144),
    "proof-villagers": Vector2i(96, 48),
}

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    _fail(message)
    return false

func _expect_vec2(actual: Vector2, expected: Vector2, label: String) -> bool:
    return _expect(actual.distance_to(expected) <= 1e-4, "%s: %s != %s" % [label, actual, expected])

func _expect_vec2i(actual: Vector2i, expected: Vector2i, label: String) -> bool:
    return _expect(actual == expected, "%s: %s != %s" % [label, actual, expected])

func _expect_polygon(
    actual: PackedVector2Array, expected: PackedVector2Array, label: String
) -> bool:
    if not _expect(actual.size() == expected.size(), "%s: polygon size mismatch" % label):
        return false
    for index in actual.size():
        if not _expect_vec2(actual[index], expected[index], "%s[%d]" % [label, index]):
            return false
    return true

func _expect_names(node: Node, expected: Array, label: String) -> bool:
    if not _expect(node.get_child_count() == expected.size(), "%s child count" % label):
        return false
    var actual := {}
    for child in node.get_children():
        actual[child.name] = true
    for name in expected:
        if not _expect(actual.has(name), "%s missing %s" % [label, name]):
            return false
    return true

func _expect_child_order(node: Node, expected: Array, label: String) -> bool:
    if not _expect(node.get_child_count() == expected.size(), "%s child count" % label):
        return false
    for index in expected.size():
        if not _expect(
            node.get_child(index).name == expected[index], "%s[%d]" % [label, index]
        ):
            return false
    return true

func _outside_footprint(position: Vector2, footprint: Rect2) -> bool:
    var half_extent := WorldContract.PLAYER_HALF_EXTENT
    return (
        position.x + half_extent <= footprint.position.x
        or position.x - half_extent >= footprint.end.x
        or position.y + half_extent <= footprint.position.y
        or position.y - half_extent >= footprint.end.y
    )

func _within_player_bounds(position: Vector2) -> bool:
    var minimum := WorldContract.PLAYER_HALF_EXTENT
    var maximum := Vector2(WorldContract.MAP_SIZE) - Vector2.ONE * minimum
    return (
        position.x >= minimum
        and position.y >= minimum
        and position.x <= maximum.x
        and position.y <= maximum.y
    )

func _release_movement_actions() -> void:
    for action in ["move_up", "move_right", "move_down", "move_left"]:
        Input.action_release(action)

func _acknowledge_intro(world: WorldShell) -> void:
    var start := world.get_node(
        "GameHud/HudRoot/OnboardingOverlay/OpeningPanel/Start"
    ) as Button
    start.pressed.emit()

func _hold_actions(actions: Array, frames: int) -> void:
    for action in actions:
        Input.action_press(action)
    for _frame in frames:
        await physics_frame
    for action in actions:
        Input.action_release(action)
    await physics_frame

func _place_player(player: CharacterBody2D, logical_position: Vector2) -> void:
    _release_movement_actions()
    player.global_position = WorldMath.grid_to_world(logical_position)
    player.velocity = Vector2.ZERO

func _cell_center(cell: Vector2i) -> Vector2:
    return WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))

func _expected_tile(cell: Vector2i) -> Vector2i:
    if WorldContract.PATH_ROW.has_point(cell):
        return PATH_TILE
    if WorldContract.FARM_PATCH.has_point(cell):
        return FARM_TILE
    return DEFAULT_TILE

func _run() -> void:
    var packed := load("res://scenes/world/world.tscn") as PackedScene
    if packed == null:
        _fail("world.tscn must load")
        return
    var world := packed.instantiate()
    root.add_child(world)
    await process_frame

    for id in range(VillagerRules.VillagerId.size()):
        var cell := WorldContract.villager_cell(id)
        if not _expect(WorldContract.villager_at(cell) == id, "villager lookup %d" % id):
            return
    if not _expect(WorldContract.villager_at(Vector2i(0, 0)) == -1, "unknown villager cell"):
        return
    if not _expect(WorldContract.villager_at(Vector2i(6, 5)) == 0, "shopkeeper villager cell"):
        return
    if not _expect(WorldContract.MARKET_CELL == Vector2i(8, 6), "market cell contract"):
        return
    if not _expect(
        WorldContract.MARKET_FOOTPRINT == Rect2(8.2, 6.2, 0.6, 0.6), "market footprint contract"
    ):
        return
    if not _expect_vec2(
        WorldContract.MARKET_ANCHOR,
        WorldMath.grid_to_world(Vector2(WorldContract.MARKET_CELL) + Vector2(0.5, 0.5)),
        "market anchor projection",
    ):
        return

    var world_names := ["Ground", "FarmSoil", "StaticCollision", "Entities", "TargetHighlight", "GameHud"]
    if not _expect_names(world, world_names, "World"):
        return
    if not _expect_child_order(world, world_names, "World scene-tree order"):
        return
    var ground := world.get_node("Ground") as TileMapLayer
    if not _expect(ground.position == Vector2(352.0, 0.0), "Ground alignment transform"):
        return
    if not _expect(ground.tile_set != null, "Ground must have a TileSet"):
        return
    var tile_set := ground.tile_set
    if not _expect(tile_set.tile_size == Vector2i(64, 32), "ground tile size"):
        return
    if not _expect(tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC, "ground tile shape"):
        return
    if not _expect(tile_set.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN, "ground tile layout"):
        return
    if not _expect(tile_set.get_source_count() == 1, "Ground must use one atlas source"):
        return
    var source := tile_set.get_source(0) as TileSetAtlasSource
    if not _expect(source != null, "Ground source must be an atlas"):
        return
    if not _expect(
        source.texture.resource_path == "res://assets/sprites/proof-tiles.png", "ground atlas texture"
    ):
        return
    if not _expect(source.texture_region_size == Vector2i(64, 32), "ground atlas tile size"):
        return
    if not _expect(source.get_tiles_count() == 3, "ground atlas tile count"):
        return

    var used_cells := ground.get_used_cells()
    if not _expect(used_cells.size() == 144, "Ground must contain exactly 144 cells"):
        return
    for y in WorldContract.MAP_SIZE.y:
        for x in WorldContract.MAP_SIZE.x:
            var cell := Vector2i(x, y)
            if not _expect(used_cells.has(cell), "Ground missing cell %s" % cell):
                return
            var expected_center := WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
            if not _expect_vec2(
                ground.to_global(ground.map_to_local(cell)),
                expected_center,
                "cell %s center" % cell,
            ):
                return
            if not _expect(
                ground.local_to_map(ground.map_to_local(cell)) == cell,
                "TileMapLayer %s must round-trip" % cell,
            ):
                return
            if not _expect(ground.get_cell_source_id(cell) == 0, "cell %s source" % cell):
                return
            if not _expect_vec2i(
                ground.get_cell_atlas_coords(cell), _expected_tile(cell), "cell %s tile" % cell
            ):
                return

    var farm_soil := world.get_node("FarmSoil") as Node2D
    if not _expect(farm_soil != null, "FarmSoil must exist"):
        return
    if not _expect(not farm_soil.y_sort_enabled, "FarmSoil must not enable y-sort"):
        return
    if not _expect(farm_soil.z_index == 5, "FarmSoil z-index"):
        return
    var farm_cells := WorldContract.farm_cells()
    if not _expect(farm_soil.get_child_count() == farm_cells.size(), "FarmSoil child count"):
        return
    for index in farm_cells.size():
        var soil := farm_soil.get_child(index) as Sprite2D
        if not _expect(soil != null, "soil sprite %s" % farm_cells[index]):
            return
        if not _expect_vec2(
            soil.position, _cell_center(farm_cells[index]), "soil %s center" % farm_cells[index]
        ):
            return
        if not _expect(
            soil.texture.resource_path == "res://assets/sprites/proof-soil.png",
            "soil %s texture" % farm_cells[index],
        ):
            return
        if not _expect(soil.hframes == 2, "soil %s frame columns" % farm_cells[index]):
            return

    var static_collision := world.get_node("StaticCollision") as StaticBody2D
    var collision_names := [
        "TreeCollision",
        "BuildingCollision",
        "ShippingCollision",
        "HarvestMarketCollision",
    ] + WorldContract.VILLAGER_COLLISION_NAMES + [
        "PerimeterTop",
        "PerimeterRight",
        "PerimeterBottom",
        "PerimeterLeft",
    ]
    if not _expect_names(static_collision, collision_names, "StaticCollision"):
        return
    if not _expect_child_order(static_collision, collision_names, "StaticCollision scene-tree order"):
        return
    if not _expect(
        static_collision.position == Vector2.ZERO, "StaticCollision must be at world origin"
    ):
        return
    if not _expect_polygon(
        (static_collision.get_node("TreeCollision") as CollisionPolygon2D).polygon,
        WorldMath.footprint_to_polygon(WorldContract.TREE_FOOTPRINT),
        "tree collision",
    ):
        return
    if not _expect_polygon(
        (static_collision.get_node("BuildingCollision") as CollisionPolygon2D).polygon,
        WorldMath.footprint_to_polygon(WorldContract.BUILDING_FOOTPRINT),
        "building collision",
    ):
        return
    if not _expect_polygon(
        (static_collision.get_node("ShippingCollision") as CollisionPolygon2D).polygon,
        WorldMath.footprint_to_polygon(WorldContract.SHIPPING_FOOTPRINT),
        "shipping collision",
    ):
        return
    if not _expect_polygon(
        (static_collision.get_node("HarvestMarketCollision") as CollisionPolygon2D).polygon,
        WorldMath.footprint_to_polygon(WorldContract.MARKET_FOOTPRINT),
        "market collision",
    ):
        return
    for id in range(VillagerRules.VillagerId.size()):
        var villager_collision := static_collision.get_node(
            WorldContract.VILLAGER_COLLISION_NAMES[id]
        ) as CollisionPolygon2D
        if not _expect_polygon(
            villager_collision.polygon,
            WorldMath.footprint_to_polygon(WorldContract.villager_footprint(id)),
            "%s collision" % villager_collision.name,
        ):
            return
    var map_size := Vector2(WorldContract.MAP_SIZE)
    var perimeter_rects := [
        Rect2(0.0, -1.0, map_size.x, 1.0),
        Rect2(map_size.x, 0.0, 1.0, map_size.y),
        Rect2(0.0, map_size.y, map_size.x, 1.0),
        Rect2(-1.0, 0.0, 1.0, map_size.y),
    ]
    for index in perimeter_rects.size():
        var collision := static_collision.get_node(collision_names[index + 7]) as CollisionPolygon2D
        if not _expect_polygon(
            collision.polygon,
            WorldMath.footprint_to_polygon(perimeter_rects[index]),
            "%s collision" % collision.name,
        ):
            return

    var entities := world.get_node("Entities") as Node2D
    if not _expect(entities.y_sort_enabled, "Entities must enable y-sort"):
        return
    var enabled_y_sort_nodes: Array[CanvasItem] = []
    if world.y_sort_enabled:
        enabled_y_sort_nodes.append(world)
    for node in world.find_children("*", "CanvasItem", true, false):
        var canvas_item := node as CanvasItem
        if canvas_item.y_sort_enabled:
            enabled_y_sort_nodes.append(canvas_item)
    if not _expect(
        enabled_y_sort_nodes.size() == 1,
        "World must have exactly one enabled y-sort CanvasItem",
    ):
        return
    if not _expect(
        enabled_y_sort_nodes[0] == entities,
        "Entities must be the only enabled y-sort CanvasItem",
    ):
        return
    var entity_names := [
        "Player",
        "Tree",
        "Building",
        "Shipping",
        "HarvestMarket",
        "VillagerShopkeeper",
        "VillagerFarmer",
        "VillagerResident",
    ]
    for cell in WorldContract.farm_cells():
        entity_names.append("FarmCrop_%d_%d" % [cell.x, cell.y])
    if not _expect_names(entities, entity_names, "Entities"):
        return
    if not _expect_child_order(entities, entity_names, "Entities scene-tree order"):
        return
    var scenery_texture_path := "res://assets/sprites/proof-scenery.png"
    var tree := entities.get_node("Tree") as Node2D
    var building := entities.get_node("Building") as Node2D
    var shipping := entities.get_node("Shipping") as Node2D
    var market := entities.get_node("HarvestMarket") as Node2D
    var villagers := [
        entities.get_node("VillagerShopkeeper") as Node2D,
        entities.get_node("VillagerFarmer") as Node2D,
        entities.get_node("VillagerResident") as Node2D,
    ]
    if not _expect_vec2(tree.position, WorldContract.TREE_ANCHOR, "tree anchor"):
        return
    if not _expect_vec2(building.position, WorldContract.BUILDING_ANCHOR, "building anchor"):
        return
    if not _expect_vec2(shipping.position, _cell_center(WorldContract.SHIPPING_CELL), "shipping anchor"):
        return
    if not _expect_vec2(market.position, WorldContract.MARKET_ANCHOR, "market anchor"):
        return
    for entry in [
        {"node": tree, "frame": 0, "label": "tree"},
        {"node": building, "frame": 1, "label": "building"},
        {"node": shipping, "frame": 2, "label": "shipping"},
        {"node": market, "frame": 3, "label": "market"},
    ]:
        var entity: Node2D = entry.node
        if not _expect_names(entity, ["Sprite2D"], "%s entity" % entry.label):
            return
        var sprite := entity.get_node("Sprite2D") as Sprite2D
        if not _expect(
            sprite.texture.resource_path == scenery_texture_path, "%s texture" % entry.label
        ):
            return
        if not _expect(sprite.hframes == 4, "%s scenery frame columns" % entry.label):
            return
        if not _expect(sprite.frame == entry.frame, "%s scenery frame" % entry.label):
            return
        if not _expect_vec2(
            sprite.offset, Vector2(0.0, -48.0), "%s bottom-center offset" % entry.label
        ):
            return

    for id in range(VillagerRules.VillagerId.size()):
        var villager: Node2D = villagers[id]
        if not _expect_vec2(
            villager.position,
            WorldMath.grid_to_world(Vector2(WorldContract.villager_cell(id)) + Vector2(0.5, 0.5)),
            "villager %d anchor" % id,
        ):
            return
        if not _expect_names(villager, ["Sprite2D"], "villager %d entity" % id):
            return
        var villager_sprite := villager.get_node("Sprite2D") as Sprite2D
        if not _expect(
            villager_sprite.texture.resource_path == "res://assets/sprites/proof-villagers.png",
            "villager %d texture" % id,
        ):
            return
        if not _expect(villager_sprite.hframes == 3, "villager %d frame columns" % id):
            return
        if not _expect(villager_sprite.frame == id, "villager %d frame" % id):
            return
        if not _expect_vec2(
            villager_sprite.offset, Vector2(0.0, -24.0), "villager %d bottom-center offset" % id
        ):
            return

    var player := entities.get_node_or_null("Player") as CharacterBody2D
    if not _expect(player != null, "Entities must contain Player"):
        return
    if not _expect_vec2(
        player.global_position,
        WorldMath.grid_to_world(WorldContract.PLAYER_SPAWN),
        "player spawn",
    ):
        return

    var player_sprite := player.get_node_or_null("Sprite2D") as Sprite2D
    if not _expect(player_sprite != null, "Player must contain Sprite2D"):
        return
    if not _expect(player_sprite.hframes == 4, "player frame columns"):
        return
    if not _expect_vec2(player_sprite.offset, Vector2(0.0, -24.0), "player bottom-center offset"):
        return

    var player_collision := player.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
    if not _expect(player_collision != null, "Player must contain CollisionPolygon2D"):
        return
    var expected_player_polygon := WorldMath.centered_player_footprint_polygon(Vector2.ZERO)
    var projection_origin := WorldMath.grid_to_world(Vector2.ZERO)
    for index in expected_player_polygon.size():
        expected_player_polygon[index] -= projection_origin
    if not _expect_polygon(player_collision.polygon, expected_player_polygon, "player collision"):
        return

    var shared_entity_z_index := tree.z_index
    if not _expect(building.z_index == shared_entity_z_index, "building shared entity z-index"):
        return
    if not _expect(shipping.z_index == shared_entity_z_index, "shipping shared entity z-index"):
        return
    if not _expect(market.z_index == shared_entity_z_index, "market shared entity z-index"):
        return
    if not _expect(player.z_index == shared_entity_z_index, "player shared entity z-index"):
        return
    for id in range(VillagerRules.VillagerId.size()):
        if not _expect(
            villagers[id].z_index == shared_entity_z_index,
            "villager %d shared entity z-index" % id,
        ):
            return
    for cell in WorldContract.farm_cells():
        var crop_root := entities.get_node("FarmCrop_%d_%d" % [cell.x, cell.y]) as Node2D
        if not _expect_vec2(crop_root.position, _cell_center(cell), "crop %s center" % cell):
            return
        if not _expect(crop_root.z_index == shared_entity_z_index, "crop %s z-index" % cell):
            return
        if not _expect_names(crop_root, ["Sprite2D"], "crop %s" % cell):
            return
        var crop_sprite := crop_root.get_node("Sprite2D") as Sprite2D
        if not _expect(
            crop_sprite.texture.resource_path == "res://assets/sprites/proof-crops.png",
            "crop %s texture" % cell,
        ):
            return
        if not _expect(crop_sprite.hframes == 4, "crop %s frame columns" % cell):
            return
        if not _expect(crop_sprite.vframes == 3, "crop %s frame rows" % cell):
            return
        if not _expect_vec2(crop_sprite.offset, Vector2(0.0, -24.0), "crop %s offset" % cell):
            return
        if not _expect(not crop_sprite.visible, "crop %s initially hidden" % cell):
            return

    _place_player(player, Vector2(7.0, 5.0))
    await physics_frame
    if not _expect(
        is_equal_approx(player.global_position.y, tree.global_position.y),
        "tree exact-Y checkpoint",
    ):
        return
    if not _expect(player.get_index() < tree.get_index(), "tree exact-Y scene-tree order"):
        return

    _place_player(player, Vector2(6.5, 11.5))
    await physics_frame
    if not _expect(
        is_equal_approx(player.global_position.y, building.global_position.y),
        "building exact-Y checkpoint",
    ):
        return
    if not _expect(player.get_index() < building.get_index(), "building exact-Y scene-tree order"):
        return

    _place_player(player, Vector2(7.0, 4.8))
    await physics_frame
    if not _expect(is_equal_approx(player.global_position.y, 188.8), "tree behind ground Y"):
        return
    if not _expect(player.global_position.y < tree.global_position.y, "player ground Y < tree.y"):
        return

    _place_player(player, Vector2(7.0, 5.2))
    await physics_frame
    if not _expect(is_equal_approx(player.global_position.y, 195.2), "tree in-front ground Y"):
        return
    if not _expect(player.global_position.y > tree.global_position.y, "player ground Y > tree.y"):
        return

    _place_player(player, Vector2(6.5, 11.3))
    await physics_frame
    if not _expect(is_equal_approx(player.global_position.y, 284.8), "building behind ground Y"):
        return
    if not _expect(player.global_position.y < building.global_position.y, "player ground Y < building.y"):
        return

    _place_player(player, Vector2(6.5, 11.7))
    await physics_frame
    if not _expect(is_equal_approx(player.global_position.y, 291.2), "building in-front ground Y"):
        return
    if not _expect(player.global_position.y > building.global_position.y, "player ground Y > building.y"):
        return

    var target_highlight := world.get_node_or_null("TargetHighlight") as Line2D
    if not _expect(target_highlight != null, "World must contain TargetHighlight"):
        return
    if not _expect(target_highlight.closed, "TargetHighlight must close its diamond"):
        return
    if not _expect(
        ground.z_index < farm_soil.z_index
        and farm_soil.z_index < target_highlight.z_index
        and target_highlight.z_index < entities.z_index,
        "ground renders below soil below target below entities",
    ):
        return

    var camera := player.get_node_or_null("Camera2D") as Camera2D
    if not _expect(camera != null, "Player must contain Camera2D"):
        return
    if not _expect(camera.enabled, "Camera2D must be enabled"):
        return
    if not _expect(camera.position_smoothing_enabled, "Camera2D must use native smoothing"):
        return
    var camera_bounds := Rect2(
        camera.limit_left,
        camera.limit_top,
        camera.limit_right - camera.limit_left,
        camera.limit_bottom - camera.limit_top,
    )
    if not _expect(camera_bounds == WorldContract.CAMERA_BOUNDS, "camera bounds"):
        return
    if not _expect(root.get_window().min_size == Vector2i(640, 360), "minimum window size"):
        return

    for entry in [
        {"action": "move_up", "physical": 87},
        {"action": "move_left", "physical": 65},
        {"action": "move_down", "physical": 83},
        {"action": "move_right", "physical": 68},
        {"action": "select_hoe", "physical": 49},
        {"action": "select_seeds", "physical": 50},
        {"action": "select_water", "physical": 51},
        {"action": "select_hands", "physical": 52},
        {"action": "use_action", "physical": 32},
        {"action": "interact", "physical": 69},
    ]:
        if not _expect(InputMap.has_action(entry.action), "%s movement action" % entry.action):
            return
        var has_key := false
        for event in InputMap.action_get_events(entry.action):
            if event is InputEventKey and event.physical_keycode == entry.physical:
                has_key = true
        if not _expect(has_key, "%s physical key" % entry.action):
            return

    _acknowledge_intro(world)
    _place_player(player, WorldContract.PLAYER_SPAWN)
    await physics_frame
    Input.action_press("move_right")
    await physics_frame
    var cardinal_velocity := player.velocity
    Input.action_release("move_right")
    await physics_frame
    _place_player(player, WorldContract.PLAYER_SPAWN)
    await physics_frame
    Input.action_press("move_right")
    Input.action_press("move_down")
    await physics_frame
    var diagonal_velocity := player.velocity
    _release_movement_actions()
    await physics_frame
    if not _expect(is_equal_approx(cardinal_velocity.length(), WorldContract.MOVE_SPEED), "cardinal speed"):
        return
    if not _expect(is_equal_approx(diagonal_velocity.length(), cardinal_velocity.length()), "diagonal normalization"):
        return
    if not _expect(is_equal_approx(diagonal_velocity.length(), WorldContract.MOVE_SPEED), "diagonal requested speed"):
        return

    _place_player(player, WorldContract.PLAYER_SPAWN)
    await physics_frame
    Input.action_press("move_up")
    Input.action_press("move_right")
    await physics_frame
    if not _expect(player.get("facing") == WorldMath.Facing.RIGHT, "player horizontal tie facing"):
        return
    _release_movement_actions()
    await physics_frame
    if not _expect(player.get("facing") == WorldMath.Facing.RIGHT, "player idle facing retention"):
        return

    var target_cases := [
        {"action": "move_up", "facing": WorldMath.Facing.UP, "cell": Vector2i(1, 8)},
        {"action": "move_right", "facing": WorldMath.Facing.RIGHT, "cell": Vector2i(3, 8)},
        {"action": "move_down", "facing": WorldMath.Facing.DOWN, "cell": Vector2i(3, 10)},
        {"action": "move_left", "facing": WorldMath.Facing.LEFT, "cell": Vector2i(1, 10)},
    ]
    for entry in target_cases:
        _place_player(player, WorldContract.PLAYER_SPAWN)
        await physics_frame
        Input.action_press(entry.action)
        await physics_frame
        Input.action_release(entry.action)
        await physics_frame
        if not _expect(player.get("facing") == entry.facing, "%s player facing" % entry.action):
            return
        if not _expect(target_highlight.visible, "%s target visible" % entry.action):
            return
        if not _expect_polygon(
            target_highlight.points,
            WorldMath.cell_diamond(entry.cell),
            "%s target" % entry.action,
        ):
            return

    _place_player(player, Vector2(0.25, 0.25))
    await physics_frame
    Input.action_press("move_up")
    await physics_frame
    Input.action_release("move_up")
    await physics_frame
    if not _expect(player.get("facing") == WorldMath.Facing.UP, "off-map player facing"):
        return
    if not _expect(not target_highlight.visible, "off-map target hidden"):
        return
    if not _expect(target_highlight.points.is_empty(), "off-map target points cleared"):
        return

    _place_player(player, Vector2(6.6, 5.0))
    await physics_frame
    await _hold_actions(["move_right"], 30)
    var tree_blocked := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _outside_footprint(tree_blocked, WorldContract.TREE_FOOTPRINT),
        "tree approach remains outside footprint",
    ):
        return
    if not _expect(tree_blocked.x <= 7.021, "tree approach stops"):
        return
    await _hold_actions(["move_right", "move_down"], 180)
    var tree_detour := WorldMath.world_to_grid(player.global_position)
    if not _expect(tree_detour.x >= 7.45, "tree detour passes"):
        return
    if not _expect(_outside_footprint(tree_detour, WorldContract.TREE_FOOTPRINT), "tree detour clear"):
        return

    _place_player(player, Vector2(6.5, 7.5))
    await physics_frame
    await _hold_actions(["move_down"], 60)
    var building_edge := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _outside_footprint(building_edge, WorldContract.BUILDING_FOOTPRINT),
        "building approach remains outside footprint",
    ):
        return
    if not _expect(building_edge.x <= 6.821, "building approach stops"):
        return
    if not _expect(building_edge.y > 7.4, "building approach slides"):
        return
    # The harvest market seals the top corridor beside the building, so the
    # corner detour runs along the building's open bottom side.
    _place_player(player, Vector2(6.5, 9.5))
    await physics_frame
    await _hold_actions(["move_right", "move_down"], 180)
    var building_corner := WorldMath.world_to_grid(player.global_position)
    if not _expect(building_corner.x >= 9.18, "building corner detour passes"):
        return
    if not _expect(
        _outside_footprint(building_corner, WorldContract.BUILDING_FOOTPRINT),
        "building corner detour clear",
    ):
        return

    _place_player(player, Vector2(0.5, 6.0))
    await physics_frame
    await _hold_actions(["move_left"], 120)
    if not _expect(_within_player_bounds(WorldMath.world_to_grid(player.global_position)), "left perimeter"):
        return
    _place_player(player, Vector2(11.5, 6.0))
    await physics_frame
    await _hold_actions(["move_right"], 120)
    if not _expect(_within_player_bounds(WorldMath.world_to_grid(player.global_position)), "right perimeter"):
        return
    _place_player(player, Vector2(6.0, 0.5))
    await physics_frame
    await _hold_actions(["move_up"], 120)
    if not _expect(_within_player_bounds(WorldMath.world_to_grid(player.global_position)), "top perimeter"):
        return
    _place_player(player, Vector2(6.0, 11.5))
    await physics_frame
    await _hold_actions(["move_down"], 120)
    if not _expect(_within_player_bounds(WorldMath.world_to_grid(player.global_position)), "bottom perimeter"):
        return

    _place_player(player, Vector2(2.5, 7.5))
    await physics_frame
    await _hold_actions(["move_down"], 100)
    var farm_exit := WorldMath.world_to_grid(player.global_position)
    if not _expect(farm_exit.x > 4.0 and farm_exit.y > 9.0, "farm traversal"):
        return

    _place_player(player, Vector2(8.5, 3.5))
    await physics_frame
    player.velocity = Vector2(-12000.0, 0.0)
    player.move_and_slide()
    var high_motion_stop := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        high_motion_stop.x >= 7.97
        and high_motion_stop.x <= 8.02
        and player.get_slide_collision_count() > 0
        and _outside_footprint(high_motion_stop, WorldContract.TREE_FOOTPRINT),
        "high-motion tree collision",
    ):
        return
    player.velocity = Vector2.ZERO

    for asset in EXPECTED_ASSETS:
        var texture := load("res://assets/sprites/%s.png" % asset) as Texture2D
        if not _expect(texture != null, "%s must import" % asset):
            return
        if not _expect(
            Vector2i(texture.get_width(), texture.get_height()) == EXPECTED_ASSETS[asset],
            "%s dimensions" % asset,
        ):
            return

    print("world shell smoke passed: 144 cells, alignment, player, camera, collisions, reachability, assets")
    quit(0)

func _init() -> void:
    call_deferred("_run")
