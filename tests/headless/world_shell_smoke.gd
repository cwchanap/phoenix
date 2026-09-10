extends SceneTree

const DEFAULT_TILE := Vector2i(0, 0)
const GRASS_DETAIL_TILE := Vector2i(1, 0)
const FARM_TILE := Vector2i(2, 0)
const PATH_TILE := Vector2i(3, 0)
const WATER_TILE := Vector2i(4, 0)
const BANK_SOUTH_TILE := Vector2i(6, 0)
const TERRAIN_TEXTURE_PATH := "res://assets/sprites/starting-farm-terrain.png"
const PROPS_TEXTURE_PATH := "res://assets/sprites/starting-farm-props.png"
const EXPECTED_ASSETS := [
    {"path": "res://assets/sprites/proof-player.png", "size": Vector2i(128, 48)},
    {"path": "res://assets/sprites/proof-scenery.png", "size": Vector2i(384, 96)},
    {"path": "res://assets/sprites/proof-soil.png", "size": Vector2i(128, 32)},
    {"path": "res://assets/sprites/proof-crops.png", "size": Vector2i(128, 144)},
    {"path": "res://assets/sprites/proof-villagers.png", "size": Vector2i(96, 48)},
    {"path": "res://assets/sprites/proof-shadow.png", "size": Vector2i(16, 8)},
    {"path": "res://assets/sprites/starting-farm-tiles-source.webp", "size": Vector2i(384, 192)},
    {"path": "res://assets/sprites/starting-farm-props-source.webp", "size": Vector2i(384, 192)},
    {"path": "res://assets/sprites/starting-farm-terrain.png", "size": Vector2i(512, 32)},
    {"path": "res://assets/sprites/starting-farm-props.png", "size": Vector2i(384, 192)},
]
const DECORATION_CELLS: Array[Vector2i] = [
    Vector2i(4, 3),
    Vector2i(8, 6),
    Vector2i(12, 2),
    Vector2i(15, 3),
    Vector2i(19, 3),
    Vector2i(21, 12),
    Vector2i(4, 7),
    Vector2i(14, 15),
]

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

func _within_player_bounds(position: Vector2) -> bool:
    var minimum := WorldContract.PLAYER_HALF_EXTENT
    var maximum := Vector2(WorldContract.MAP_SIZE) - Vector2.ONE * minimum
    return (
        position.x >= minimum
        and position.y >= minimum
        and position.x <= maximum.x
        and position.y <= maximum.y
    )

func _outside_footprint(position: Vector2, footprint: Rect2) -> bool:
    var half_extent := WorldContract.PLAYER_HALF_EXTENT
    return (
        position.x + half_extent <= footprint.position.x
        or position.x - half_extent >= footprint.end.x
        or position.y + half_extent <= footprint.position.y
        or position.y - half_extent >= footprint.end.y
    )

func _release_movement_actions() -> void:
    for action in ["move_up", "move_right", "move_down", "move_left"]:
        Input.action_release(action)

func _acknowledge_intro(world: WorldShell) -> void:
    var accepted := InputEventAction.new()
    accepted.action = &"ui_accept"
    accepted.pressed = true
    world.get_viewport().push_input(accepted)
    var released := InputEventAction.new()
    released.action = &"ui_accept"
    released.pressed = false
    world.get_viewport().push_input(released)

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

func _rect_cells(rect: Rect2) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for y in range(int(rect.position.y), int(rect.end.y)):
        for x in range(int(rect.position.x), int(rect.end.x)):
            cells.append(Vector2i(x, y))
    return cells

func _expected_path_cells() -> Array[Vector2i]:
    # Main east-west road to the future village, the farm-side path that starts
    # at x=10 beside the farm, and the workbench spur reaching x=12.
    var cells: Array[Vector2i] = []
    for x in range(10, WorldContract.MAP_SIZE.x):
        cells.append(Vector2i(x, 9))
    for y in range(10, 17):
        cells.append(Vector2i(10, y))
    cells.append(Vector2i(11, 16))
    cells.append(Vector2i(12, 16))
    return cells

func _static_entity_names() -> Array:
    return [
        "Player",
        "House",
        "ShopStall",
        "TreeForest",
        "TreeBank",
        "TreeNorth",
        "RockYard",
        "RockMeadow",
        "TreeNorth2",
        "TreeNorth3",
        "TreeNorth4",
        "RockNorth1",
        "TreeNorth5",
        "TreeNorth6",
        "RockNorth2",
        "TreeNorth7",
        "FarmFence_1",
        "FarmFence_2",
        "FarmFence_3",
        "Workbench",
        "VillageSign",
        "Shipping",
        "HarvestMarket",
        "VillagerShopkeeper",
        "VillagerFarmer",
        "VillagerResident",
    ]

func _expected_water_tile(cell: Vector2i) -> Vector2i:
    # The south river's north shore faces up-right, matching the bank-B sheet
    # cell; the west river's shore faces down-right, which no sheet cell
    # provides, so those cells stay plain water.
    if cell.y == 18 and cell.x >= 2 and cell.x <= 11:
        return BANK_SOUTH_TILE
    return WATER_TILE

func _prop_entities() -> Array:
    return [
        {"node": "House", "frame": 0, "label": "house"},
        {"node": "ShopStall", "frame": 1, "label": "shop stall"},
        {"node": "TreeForest", "frame": 2, "label": "forest tree"},
        {"node": "TreeBank", "frame": 2, "label": "bank tree"},
        {"node": "TreeNorth", "frame": 2, "label": "north tree"},
        {"node": "RockYard", "frame": 3, "label": "yard rock"},
        {"node": "RockMeadow", "frame": 3, "label": "meadow rock"},
        {"node": "TreeNorth2", "frame": 2, "label": "north tree 2"},
        {"node": "TreeNorth3", "frame": 2, "label": "north tree 3"},
        {"node": "TreeNorth4", "frame": 2, "label": "north tree 4"},
        {"node": "RockNorth1", "frame": 3, "label": "north rock 1"},
        {"node": "TreeNorth5", "frame": 2, "label": "north tree 5"},
        {"node": "TreeNorth6", "frame": 2, "label": "north tree 6"},
        {"node": "RockNorth2", "frame": 3, "label": "north rock 2"},
        {"node": "TreeNorth7", "frame": 2, "label": "north tree 7"},
        {"node": "FarmFence_1", "frame": 4, "label": "farm fence 1"},
        {"node": "FarmFence_2", "frame": 4, "label": "farm fence 2"},
        {"node": "FarmFence_3", "frame": 4, "label": "farm fence 3"},
        {"node": "Workbench", "frame": 5, "label": "workbench"},
        {"node": "VillageSign", "frame": 6, "label": "village sign"},
    ]

func _proof_entities() -> Array:
    return [
        {"node": "Shipping", "frame": 2, "label": "shipping"},
        {"node": "HarvestMarket", "frame": 3, "label": "market"},
    ]

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
    if not _expect(WorldContract.MARKET_CELL == Vector2i(19, 10), "market cell contract"):
        return
    if not _expect(
        WorldContract.MARKET_FOOTPRINT == Rect2(19.2, 10.2, 0.6, 0.6), "market footprint contract"
    ):
        return
    if not _expect_vec2(
        WorldContract.MARKET_ANCHOR,
        WorldMath.grid_to_world(Vector2(WorldContract.MARKET_CELL) + Vector2(0.5, 0.5)),
        "market anchor projection",
    ):
        return

    var world_names := [
        "Ground",
        "Water",
        "Paths",
        "GroundDecoration",
        "FarmSoil",
        "StaticCollision",
        "Entities",
        "TargetHighlight",
        "GameHud",
    ]
    if not _expect_names(world, world_names, "World"):
        return
    if not _expect_child_order(world, world_names, "World scene-tree order"):
        return

    var ground := world.get_node("Ground") as TileMapLayer
    if not _expect(ground.position == Vector2(736.0, 0.0), "Ground alignment transform"):
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
    if not _expect(source.texture.resource_path == TERRAIN_TEXTURE_PATH, "ground atlas texture"):
        return
    if not _expect(source.texture_region_size == Vector2i(64, 32), "ground atlas tile size"):
        return
    if not _expect(source.get_tiles_count() == 8, "ground atlas tile count"):
        return

    var used_cells := ground.get_used_cells()
    if not _expect(used_cells.size() == 480, "Ground must contain exactly 480 cells"):
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
            var expected_tile := FARM_TILE if WorldContract.FARM_PATCH.has_point(cell) else DEFAULT_TILE
            if not _expect_vec2i(
                ground.get_cell_atlas_coords(cell), expected_tile, "ground cell %s tile" % cell
            ):
                return

    var water := world.get_node("Water") as TileMapLayer
    if not _expect(water != null, "Water must exist"):
        return
    if not _expect(water.position == Vector2(736.0, 0.0), "Water alignment transform"):
        return
    if not _expect(water.tile_set == ground.tile_set, "Water must share the terrain TileSet"):
        return
    var water_used := water.get_used_cells()
    var expected_water := _rect_cells(WorldContract.RIVER_WEST_FOOTPRINT)
    for river_cell in _rect_cells(WorldContract.RIVER_SOUTH_FOOTPRINT):
        if not expected_water.has(river_cell):
            expected_water.append(river_cell)
    if not _expect(
        water_used.size() == expected_water.size(), "Water must paint exactly the river cells"
    ):
        return
    for river_cell in expected_water:
        if not _expect(water_used.has(river_cell), "Water missing river cell %s" % river_cell):
            return
        if not _expect(water.get_cell_source_id(river_cell) == 0, "water %s source" % river_cell):
            return
        if not _expect_vec2i(
            water.get_cell_atlas_coords(river_cell),
            _expected_water_tile(river_cell),
            "water %s tile" % river_cell,
        ):
            return

    var paths := world.get_node("Paths") as TileMapLayer
    if not _expect(paths != null, "Paths must exist"):
        return
    if not _expect(paths.position == Vector2(736.0, 0.0), "Paths alignment transform"):
        return
    if not _expect(paths.tile_set == ground.tile_set, "Paths must share the ground TileSet"):
        return
    var path_used := paths.get_used_cells()
    var expected_paths := _expected_path_cells()
    if not _expect(
        path_used.size() == expected_paths.size(), "Paths must paint exactly the path cells"
    ):
        return
    for path_cell in expected_paths:
        if not _expect(path_used.has(path_cell), "Paths missing path cell %s" % path_cell):
            return
        if not _expect_vec2i(
            paths.get_cell_atlas_coords(path_cell), PATH_TILE, "path %s tile" % path_cell
        ):
            return

    var decoration := world.get_node("GroundDecoration") as TileMapLayer
    if not _expect(decoration != null, "GroundDecoration must exist"):
        return
    if not _expect(decoration.position == Vector2(736.0, 0.0), "GroundDecoration alignment"):
        return
    if not _expect(
        decoration.tile_set == ground.tile_set, "GroundDecoration must share the ground TileSet"
    ):
        return
    var decoration_used := decoration.get_used_cells()
    if not _expect(
        decoration_used.size() == DECORATION_CELLS.size(), "GroundDecoration cell count"
    ):
        return
    for decoration_cell in DECORATION_CELLS:
        if not _expect(
            decoration_used.has(decoration_cell), "GroundDecoration missing cell %s" % decoration_cell
        ):
            return
        if not _expect_vec2i(
            decoration.get_cell_atlas_coords(decoration_cell),
            GRASS_DETAIL_TILE,
            "GroundDecoration %s tile" % decoration_cell,
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
    if not _expect(farm_cells.size() == 30, "farm cell count"):
        return
    if not _expect(farm_soil.get_child_count() == farm_cells.size(), "FarmSoil soil sprite count"):
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
        "HouseCollision",
        "ShopStallCollision",
        "ForestCollision",
        "RiverWestCollision",
        "RiverSouthCollision",
        "WorkbenchCollision",
        "HouseYardWestCollision",
        "HouseYardEastCollision",
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
    var collider_footprints := {
        "HouseCollision": WorldContract.HOUSE_FOOTPRINT,
        "ShopStallCollision": WorldContract.SHOP_STALL_FOOTPRINT,
        "ForestCollision": WorldContract.FOREST_FOOTPRINT,
        "RiverWestCollision": WorldContract.RIVER_WEST_FOOTPRINT,
        "RiverSouthCollision": WorldContract.RIVER_SOUTH_FOOTPRINT,
        "WorkbenchCollision": WorldContract.WORKBENCH_FOOTPRINT,
        "HouseYardWestCollision": WorldContract.HOUSE_YARD_WEST_FOOTPRINT,
        "HouseYardEastCollision": WorldContract.HOUSE_YARD_EAST_FOOTPRINT,
        "ShippingCollision": WorldContract.SHIPPING_FOOTPRINT,
        "HarvestMarketCollision": WorldContract.MARKET_FOOTPRINT,
    }
    for id in range(VillagerRules.VillagerId.size()):
        collider_footprints[WorldContract.VILLAGER_COLLISION_NAMES[id]] = (
            WorldContract.villager_footprint(id)
        )
    var map_size := Vector2(WorldContract.MAP_SIZE)
    var perimeter_rects := [
        Rect2(0.0, -1.0, map_size.x, 1.0),
        Rect2(map_size.x, 0.0, 1.0, map_size.y),
        Rect2(0.0, map_size.y, map_size.x, 1.0),
        Rect2(-1.0, 0.0, 1.0, map_size.y),
    ]
    var perimeter_names := ["PerimeterTop", "PerimeterRight", "PerimeterBottom", "PerimeterLeft"]
    for index in perimeter_rects.size():
        collider_footprints[perimeter_names[index]] = perimeter_rects[index]
    for collider_name in collision_names:
        var collision := static_collision.get_node(collider_name) as CollisionPolygon2D
        if not _expect_polygon(
            collision.polygon,
            WorldMath.footprint_to_polygon(collider_footprints[collider_name]),
            "%s polygon" % collider_name,
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
    var entity_names := _static_entity_names()
    for farm_cell in farm_cells:
        entity_names.append("FarmCrop_%d_%d" % [farm_cell.x, farm_cell.y])
    if not _expect_names(entities, entity_names, "Entities"):
        return
    if not _expect_child_order(entities, entity_names, "Entities scene-tree order"):
        return

    var house := entities.get_node("House") as Node2D
    var shop_stall := entities.get_node("ShopStall") as Node2D
    var shipping := entities.get_node("Shipping") as Node2D
    var market := entities.get_node("HarvestMarket") as Node2D
    var workbench := entities.get_node("Workbench") as Node2D
    var village_sign := entities.get_node("VillageSign") as Node2D
    var villagers := [
        entities.get_node("VillagerShopkeeper") as Node2D,
        entities.get_node("VillagerFarmer") as Node2D,
        entities.get_node("VillagerResident") as Node2D,
    ]
    if not _expect_vec2(
        house.position,
        WorldMath.footprint_ground_anchor(WorldContract.HOUSE_FOOTPRINT),
        "house anchor",
    ):
        return
    if not _expect_vec2(
        shop_stall.position,
        WorldMath.footprint_ground_anchor(WorldContract.SHOP_STALL_FOOTPRINT),
        "shop stall anchor",
    ):
        return
    if not _expect_vec2(
        shipping.position, _cell_center(WorldContract.SHIPPING_CELL), "shipping anchor"
    ):
        return
    if not _expect_vec2(market.position, WorldContract.MARKET_ANCHOR, "market anchor"):
        return
    if not _expect_vec2(
        workbench.position, _cell_center(WorldContract.WORKBENCH_CELL), "workbench anchor"
    ):
        return
    if not _expect_vec2(
        village_sign.position, _cell_center(WorldContract.VILLAGE_SIGN_CELL), "village sign anchor"
    ):
        return
    for id in range(VillagerRules.VillagerId.size()):
        if not _expect_vec2(
            villagers[id].position,
            WorldMath.grid_to_world(Vector2(WorldContract.villager_cell(id)) + Vector2(0.5, 0.5)),
            "villager %d anchor" % id,
        ):
            return

    for entry in _prop_entities():
        var entity := entities.get_node(entry.node) as Node2D
        if not _expect(entity != null, "%s entity" % entry.label):
            return
        if not _expect_names(entity, ["Shadow", "Sprite2D"], "%s entity" % entry.label):
            return
        var entity_shadow := entity.get_node("Shadow") as Sprite2D
        if not _expect(
            entity_shadow.texture.resource_path == "res://assets/sprites/proof-shadow.png",
            "%s shadow texture" % entry.label,
        ):
            return
        var sprite := entity.get_node("Sprite2D") as Sprite2D
        if not _expect(
            sprite.texture.resource_path == PROPS_TEXTURE_PATH, "%s texture" % entry.label
        ):
            return
        if not _expect(sprite.hframes == 4, "%s prop frame columns" % entry.label):
            return
        if not _expect(sprite.vframes == 2, "%s prop frame rows" % entry.label):
            return
        if not _expect(sprite.frame == entry.frame, "%s prop frame" % entry.label):
            return
        if not _expect_vec2(
            sprite.offset, Vector2(0.0, -48.0), "%s bottom-center offset" % entry.label
        ):
            return

    for entry in _proof_entities():
        var entity := entities.get_node(entry.node) as Node2D
        if not _expect(entity != null, "%s entity" % entry.label):
            return
        if not _expect_names(entity, ["Shadow", "Sprite2D"], "%s entity" % entry.label):
            return
        var entity_shadow := entity.get_node("Shadow") as Sprite2D
        if not _expect(
            entity_shadow.texture.resource_path == "res://assets/sprites/proof-shadow.png",
            "%s shadow texture" % entry.label,
        ):
            return
        var sprite := entity.get_node("Sprite2D") as Sprite2D
        if not _expect(
            sprite.texture.resource_path == "res://assets/sprites/proof-scenery.png",
            "%s texture" % entry.label,
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
        if not _expect_names(villager, ["Shadow", "Sprite2D"], "villager %d entity" % id):
            return
        var villager_shadow := villager.get_node("Shadow") as Sprite2D
        if not _expect(
            villager_shadow.texture.resource_path == "res://assets/sprites/proof-shadow.png",
            "villager %d shadow texture" % id,
        ):
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

    var player_shadow := player.get_node_or_null("Shadow") as Sprite2D
    if not _expect(player_shadow != null, "Player must contain Shadow"):
        return
    if not _expect(
        player_shadow.texture.resource_path == "res://assets/sprites/proof-shadow.png",
        "player shadow texture",
    ):
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

    var shared_entity_z_index := house.z_index
    for prop in [shop_stall, shipping, market, workbench, village_sign, player]:
        if not _expect(
            prop.z_index == shared_entity_z_index, "%s shared entity z-index" % prop.name
        ):
            return
    for id in range(VillagerRules.VillagerId.size()):
        if not _expect(
            villagers[id].z_index == shared_entity_z_index,
            "villager %d shared entity z-index" % id,
        ):
            return
    for farm_cell in farm_cells:
        var crop_root := entities.get_node("FarmCrop_%d_%d" % [farm_cell.x, farm_cell.y]) as Node2D
        if not _expect_vec2(crop_root.position, _cell_center(farm_cell), "crop %s center" % farm_cell):
            return
        if not _expect(crop_root.z_index == shared_entity_z_index, "crop %s z-index" % farm_cell):
            return
        if not _expect_names(crop_root, ["Shadow", "Sprite2D"], "crop %s" % farm_cell):
            return
        var crop_shadow := crop_root.get_node("Shadow") as Sprite2D
        if not _expect(
            crop_shadow.texture.resource_path == "res://assets/sprites/proof-shadow.png",
            "crop %s shadow texture" % farm_cell,
        ):
            return
        if not _expect(not crop_shadow.visible, "crop %s shadow initially hidden" % farm_cell):
            return
        var crop_sprite := crop_root.get_node("Sprite2D") as Sprite2D
        if not _expect(
            crop_sprite.texture.resource_path == "res://assets/sprites/proof-crops.png",
            "crop %s texture" % farm_cell,
        ):
            return
        if not _expect(crop_sprite.hframes == 4, "crop %s frame columns" % farm_cell):
            return
        if not _expect(crop_sprite.vframes == 3, "crop %s frame rows" % farm_cell):
            return
        if not _expect_vec2(crop_sprite.offset, Vector2(0.0, -24.0), "crop %s offset" % farm_cell):
            return
        if not _expect(not crop_sprite.visible, "crop %s initially hidden" % farm_cell):
            return

    _place_player(player, Vector2(12.0, 9.0))
    await physics_frame
    if not _expect(
        is_equal_approx(player.global_position.y, house.global_position.y),
        "house exact-Y checkpoint",
    ):
        return
    if not _expect(player.get_index() < house.get_index(), "house exact-Y scene-tree order"):
        return

    _place_player(player, Vector2(12.0, 8.8))
    await physics_frame
    if not _expect(is_equal_approx(player.global_position.y, 332.8), "house behind ground Y"):
        return
    if not _expect(player.global_position.y < house.global_position.y, "player ground Y < house.y"):
        return

    _place_player(player, Vector2(12.0, 9.2))
    await physics_frame
    if not _expect(is_equal_approx(player.global_position.y, 339.2), "house in-front ground Y"):
        return
    if not _expect(player.global_position.y > house.global_position.y, "player ground Y > house.y"):
        return

    _place_player(player, Vector2(12.0, 13.0))
    await physics_frame
    if not _expect(
        is_equal_approx(player.global_position.y, shop_stall.global_position.y),
        "shop stall exact-Y checkpoint",
    ):
        return
    if not _expect(
        player.get_index() < shop_stall.get_index(), "shop stall exact-Y scene-tree order"
    ):
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
        {"action": "move_up", "facing": WorldMath.Facing.UP, "cell": Vector2i(10, 7)},
        {"action": "move_right", "facing": WorldMath.Facing.RIGHT, "cell": Vector2i(12, 7)},
        {"action": "move_down", "facing": WorldMath.Facing.DOWN, "cell": Vector2i(12, 9)},
        {"action": "move_left", "facing": WorldMath.Facing.LEFT, "cell": Vector2i(10, 9)},
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

    _place_player(player, Vector2(23.5, 10.5))
    await physics_frame
    Input.action_press("move_right")
    await physics_frame
    Input.action_release("move_right")
    await physics_frame
    if not _expect(player.get("facing") == WorldMath.Facing.RIGHT, "off-map player facing"):
        return
    if not _expect(not target_highlight.visible, "off-map target hidden"):
        return
    if not _expect(target_highlight.points.is_empty(), "off-map target points cleared"):
        return

    # The bin shares the old small-prop collider size class: approach along the
    # east vertex world-Y so the extreme-velocity stop is a symmetric vertex
    # hit instead of an edge slide.
    var bin_vertex := WorldMath.grid_to_world(WorldContract.SHIPPING_FOOTPRINT.end)
    _place_player(
        player,
        WorldMath.world_to_grid(bin_vertex + Vector2(3.0 * WorldContract.TILE_SIZE.x, 0.0)),
    )
    await physics_frame
    player.velocity = Vector2(-12000.0, 0.0)
    player.move_and_slide()
    var high_motion_stop := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        high_motion_stop.x >= 10.97
        and high_motion_stop.x <= 11.02
        and player.get_slide_collision_count() > 0,
        "high-motion shipping bin collision",
    ):
        return
    player.velocity = Vector2.ZERO

    # The house is approached from the south: an up-walk stops at its south
    # face, and a wide north-west detour clears the house and its west yard
    # flank, so the homestead never seals the map.
    _place_player(player, Vector2(12.5, 7.5))
    await physics_frame
    await _hold_actions(["move_up"], 60)
    var house_approach := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _outside_footprint(house_approach, WorldContract.HOUSE_FOOTPRINT),
        "house approach remains outside footprint",
    ):
        return
    if not _expect(
        house_approach.y >= 7.17 and house_approach.y <= 7.39,
        "house approach stops at the south face",
    ):
        return
    await _hold_actions(["move_left", "move_up"], 180)
    var house_detour := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _outside_footprint(house_detour, WorldContract.HOUSE_FOOTPRINT),
        "house detour remains outside footprint",
    ):
        return
    if not _expect(
        house_detour.x <= 9.4 and house_detour.y <= 6.8,
        "house west detour passes the yard flank",
    ):
        return

    # The west river is solid: an east-bank approach stops at the water line,
    # and a walk pressed along the bank stays ashore instead of wading.
    _place_player(player, Vector2(3.5, 10.0))
    await physics_frame
    await _hold_actions(["move_left"], 60)
    var river_approach := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _outside_footprint(river_approach, WorldContract.RIVER_WEST_FOOTPRINT),
        "river west approach remains outside water",
    ):
        return
    if not _expect(
        river_approach.x >= 2.18 and river_approach.x <= 2.39,
        "river west approach stops at the bank",
    ):
        return
    await _hold_actions(["move_left", "move_down"], 120)
    var bank_walk := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _outside_footprint(bank_walk, WorldContract.RIVER_WEST_FOOTPRINT)
        and _outside_footprint(bank_walk, WorldContract.RIVER_SOUTH_FOOTPRINT)
        and _within_player_bounds(bank_walk),
        "river west bank walk stays ashore",
    ):
        return

    _place_player(player, Vector2(2.5, 10.0))
    await physics_frame
    await _hold_actions(["move_left"], 120)
    if not _expect(_within_player_bounds(WorldMath.world_to_grid(player.global_position)), "west river boundary"):
        return
    _place_player(player, Vector2(23.5, 10.0))
    await physics_frame
    await _hold_actions(["move_right"], 120)
    if not _expect(_within_player_bounds(WorldMath.world_to_grid(player.global_position)), "right perimeter"):
        return
    _place_player(player, Vector2(12.0, 2.5))
    await physics_frame
    await _hold_actions(["move_up"], 120)
    if not _expect(_within_player_bounds(WorldMath.world_to_grid(player.global_position)), "north forest boundary"):
        return
    _place_player(player, Vector2(12.5, 19.0))
    await physics_frame
    await _hold_actions(["move_down"], 120)
    if not _expect(_within_player_bounds(WorldMath.world_to_grid(player.global_position)), "bottom perimeter"):
        return

    # Farm-edge reachability: a diagonal walk from the expanded patch's
    # north-west corner crosses every row and exits past its south-east edge.
    _place_player(player, Vector2(4.5, 10.5))
    await physics_frame
    await _hold_actions(["move_down"], 130)
    var farm_exit := WorldMath.world_to_grid(player.global_position)
    if not _expect(farm_exit.x > 9.0 and farm_exit.y > 14.0, "farm edge traversal exits south-east"):
        return

    for entry in EXPECTED_ASSETS:
        var texture := load(entry.path) as Texture2D
        if not _expect(texture != null, "%s must import" % entry.path):
            return
        if not _expect(
            Vector2i(texture.get_width(), texture.get_height()) == entry.size,
            "%s dimensions" % entry.path,
        ):
            return

    print("world shell smoke passed: 480 cells, alignment, water/paths, player, camera, collisions, assets")
    quit(0)

func _init() -> void:
    call_deferred("_run")
