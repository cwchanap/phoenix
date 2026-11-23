extends SceneTree

const Stamper := preload("res://tools/stamp_farm_ground.gd")
const FARM_TILESET_PATH := "res://scenes/world/terrain_tileset.tres"
const FARM_SOURCE_COUNT := 35
const FARM_TILE_COUNT := 1542
const FARM_MAP_CELLS := 1920
const FARM_TEXTURE_DIR := "res://assets/sprites/world-v2/cutouts/"
const TOWN_TILESET_PATH := "res://scenes/world/town_tileset.tres"
const TOWN_PROP_TEXTURE_DIR := "res://assets/sprites/world-v2/cutouts/"
const BIN_TEXTURE_PATH := "res://assets/sprites/world-v2/cutouts/shipping-bin.png"
# HPA-863 Task 4 passable decor: approved layout records for the two flower
# beds and the torii, plus the five lot rope markers. Visual-only — no
# collision, no interact, no occluder. The pier planks are a walkable deck, so
# they live below the actor layer (PierDeck), not in the Y-sorted Entities.
const FARM_DECOR := [
    {"node": "Flowers1", "footprint": Rect2(21.0, 10.0, 1.0, 1.0), "texture": "flowers.png"},
    {"node": "Flowers2", "footprint": Rect2(25.0, 10.0, 1.0, 1.0), "texture": "flowers.png"},
    {"node": "Torii", "footprint": Rect2(7.0, 6.0, 1.0, 1.0), "texture": "torii.png"},
    {"node": "LotRope1", "footprint": Rect2(3.0, 8.0, 4.0, 3.0), "texture": "stakes-rope.png"},
    {"node": "LotRope2", "footprint": Rect2(8.0, 8.0, 3.0, 3.0), "texture": "stakes-rope.png"},
    {"node": "LotRope3", "footprint": Rect2(3.0, 13.0, 4.0, 3.0), "texture": "stakes-rope.png"},
    {"node": "LotRope4", "footprint": Rect2(8.0, 13.0, 4.0, 3.0), "texture": "stakes-rope.png"},
    {"node": "LotRope5", "footprint": Rect2(13.0, 13.0, 4.0, 3.0), "texture": "stakes-rope.png"},
]
const PIER_DECK := [
    {"node": "PierPlank1", "footprint": Rect2(23.0, 33.0, 2.0, 1.0), "texture": "pier.png"},
    {"node": "PierPlank2", "footprint": Rect2(23.0, 34.0, 2.0, 1.0), "texture": "pier.png"},
    {"node": "PierPlank3", "footprint": Rect2(23.0, 35.0, 2.0, 1.0), "texture": "pier.png"},
]
# The farmhouse cutout's drawn base is 28 px right of frame centre; its sprite
# offset centres the base and doorway on the authored 3x3 footprint.
const HOUSE_ART_OFFSET := Vector2(-28.0, -96.0)
# Building contact shadows scale at the prop's ground root, like every other
# prop shadow. Sprite2D.offset is scaled by the sprite's own scale, so the
# effective centre is position + offset * scale; the smoke checks that it is
# the root (no scale-amplified displacement), plus the intended size.
const BUILDING_SHADOWS := {
    "House": 13.0,
    "Storehouse": 19.0,
    "Greenhouse": 19.0,
    "ToolShed": 9.0,
    "Shrine": 9.0,
    "Camphor": 9.0,
}
const TOWN_SOURCE_TEXTURES: Array[String] = [
    "res://assets/sprites/world-v2/ground/grass-phases.png",
    "res://assets/sprites/world-v2/ground/paving-phases.png",
    "res://assets/sprites/world-v2/ground/road-phases.png",
]
const EXPECTED_ASSETS := [
    {"path": "res://assets/sprites/player-walk.png", "size": Vector2i(128, 192), "hframes": 4, "vframes": 4},
    {"path": "res://assets/sprites/world-v2/soil.png", "size": Vector2i(128, 32)},
    {"path": "res://assets/sprites/world-v2/crops.png", "size": Vector2i(128, 144)},
    {"path": "res://assets/sprites/world-v2/cutouts/shipping-bin.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/farmhouse.png", "size": Vector2i(224, 192)},
    {"path": "res://assets/sprites/world-v2/cutouts/storehouse.png", "size": Vector2i(320, 256)},
    {"path": "res://assets/sprites/world-v2/cutouts/greenhouse.png", "size": Vector2i(320, 256)},
    {"path": "res://assets/sprites/world-v2/cutouts/tool-shed.png", "size": Vector2i(160, 144)},
    {"path": "res://assets/sprites/world-v2/cutouts/shrine.png", "size": Vector2i(160, 144)},
    {"path": "res://assets/sprites/world-v2/cutouts/camphor-tree.png", "size": Vector2i(160, 144)},
    {"path": "res://assets/sprites/world-v2/cutouts/persimmon.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/bamboo-fence-a.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/bamboo-fence-b.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/wood-fence-a.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/wood-fence-b.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/flowers.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/torii.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/stakes-rope.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/cutouts/pier.png", "size": Vector2i(96, 96)},
    {"path": "res://assets/sprites/world-v2/ground/grass-phases.png", "size": Vector2i(256, 32)},
    {"path": "res://assets/sprites/world-v2/ground/paving-phases.png", "size": Vector2i(256, 32)},
    {"path": "res://assets/sprites/world-v2/ground/road-phases.png", "size": Vector2i(256, 32)},
    {"path": "res://assets/sprites/villagers.png", "size": Vector2i(96, 48)},
    {"path": "res://assets/sprites/proof-shadow.png", "size": Vector2i(16, 8)},
    {"path": "res://assets/sprites/starting-farm-tiles-source.webp", "size": Vector2i(384, 192)},
    {"path": "res://assets/sprites/starting-farm-props-source.webp", "size": Vector2i(384, 192)},
    {"path": "res://assets/sprites/polish/hoe-overlay.png", "size": Vector2i(72, 24), "hframes": 3},
    {"path": "res://assets/sprites/polish/watering-can-overlay.png", "size": Vector2i(72, 24), "hframes": 3},
    {"path": "res://assets/sprites/polish/soil-impact.png", "size": Vector2i(96, 32), "hframes": 3},
    {"path": "res://assets/sprites/polish/planting-seed.png", "size": Vector2i(8, 8)},
    {"path": "res://assets/sprites/polish/water-splash.png", "size": Vector2i(192, 32), "hframes": 3},
    {"path": "res://assets/sprites/polish/harvest-sparkle.png", "size": Vector2i(48, 16), "hframes": 3},
    {"path": "res://assets/ui/icons/watering-can-efficient.png", "size": Vector2i(32, 32)},
    {"path": "res://assets/sprites/polish/river-ripple.png", "size": Vector2i(192, 32), "hframes": 3},
    {"path": "res://assets/sprites/polish/house-window-light.png", "size": Vector2i(96, 96)},
]

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _finish_travel(hud: GameHud) -> void:
    var overlay := hud.get_node("HudRoot/TravelOverlay") as TravelOverlay
    var steps := 0
    while (
        overlay.visible
        and overlay._tween != null
        and overlay._tween.is_valid()
        and steps < 16
    ):
        overlay._tween.custom_step(0.5)
        steps += 1

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    _fail(message)
    return false

func _expect_vec2(actual: Vector2, expected: Vector2, label: String) -> bool:
    return _expect(actual.distance_to(expected) <= 1e-4, "%s: %s != %s" % [label, actual, expected])

func _expect_vec2i(actual: Vector2i, expected: Vector2i, label: String) -> bool:
    return _expect(actual == expected, "%s: %s != %s" % [label, actual, expected])

func _town_phase(cell: Vector2i) -> int:
    return posmod(cell.x, 2) + 2 * posmod(cell.y, 2)

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
    accepted.action = &"ui_cancel"
    accepted.pressed = true
    world.get_viewport().push_input(accepted)
    var released := InputEventAction.new()
    released.action = &"ui_cancel"
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

func _terrain_run_rects() -> Array[Rect2]:
    # Independent re-derivation of FarmMap's row runs from the final grid.
    var rects: Array[Rect2] = []
    for y in WorldContract.MAP_SIZE.y:
        var start := -1
        for x in WorldContract.MAP_SIZE.x + 1:
            var blocking := (
                x < WorldContract.MAP_SIZE.x
                and WorldContract.blocks_movement(Vector2i(x, y))
            )
            if blocking and start < 0:
                start = x
            elif not blocking and start >= 0:
                rects.append(Rect2(start, y, x - start, 1))
                start = -1
    return rects

func _polygon_key(polygon: PackedVector2Array) -> String:
    var parts := PackedStringArray()
    for point in polygon:
        parts.append("%.3f,%.3f" % [point.x, point.y])
    return ";".join(parts)

func _expected_collision_counts() -> Dictionary:
    var counts := {}
    var rects: Array[Rect2] = _terrain_run_rects()
    for entry in WorldContract.blocking_props():
        rects.append(entry["footprint"])
    rects.append_array(WorldContract.fence_footprints())
    rects.append_array(WorldContract.perimeter_footprints(WorldContract.MAP_SIZE))
    for rect in rects:
        var key := _polygon_key(WorldMath.footprint_to_polygon(rect))
        counts[key] = int(counts.get(key, 0)) + 1
    return counts

func _fence_materials() -> Dictionary:
    var materials := {}
    for run in WorldContract.fence_runs():
        for index in int(run["length"]):
            materials[run["start"] + run["step"] * index] = run["material"]
    return materials

func _fence_textures(material: String) -> Array[String]:
    return [
        FARM_TEXTURE_DIR + "%s-fence-a.png" % material,
        FARM_TEXTURE_DIR + "%s-fence-b.png" % material,
    ]

func _run() -> void:
    var packed := load("res://scenes/world/world.tscn") as PackedScene
    if packed == null:
        _fail("world.tscn must load")
        return
    var world := packed.instantiate() as WorldShell
    if world == null:
        _fail("world.tscn must instantiate as WorldShell")
        return
    world.clock_running = false
    root.add_child(world)
    await process_frame

    var world_names := [
        "FarmMap",
        "RainLayer",
        "TargetHighlight",
        "GameHud",
    ]
    if not _expect_names(world, world_names, "World"):
        return
    if not _expect_child_order(world, world_names, "World scene-tree order"):
        return

    var farm_map := world.get_node("FarmMap") as FarmMap
    if not _expect(farm_map != null, "World must contain a FarmMap"):
        return
    var map_names := [
        "Backdrop",
        "Ground",
        "FarmSoil",
        "PierDeck",
        "FarmActionEffects",
        "HomesteadAmbience",
        "StaticCollision",
        "Entities",
    ]
    if not _expect_names(farm_map, map_names, "FarmMap"):
        return
    if not _expect_child_order(farm_map, map_names, "FarmMap scene-tree order"):
        return

    # --- Static ground: the committed 35-source manifest and stamped cells ---
    var ground := farm_map.get_node("Ground") as TileMapLayer
    if not _expect(ground.position == Vector2(736.0, 0.0), "Ground alignment transform"):
        return
    var tile_set := ground.tile_set
    if not _expect(tile_set != null, "Ground must have a TileSet"):
        return
    if not _expect(
        tile_set.resource_path == FARM_TILESET_PATH, "farm Ground uses the committed TileSet"
    ):
        return
    if not _expect(tile_set.tile_size == Vector2i(64, 32), "ground tile size"):
        return
    if not _expect(tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC, "ground tile shape"):
        return
    if not _expect(tile_set.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN, "ground tile layout"):
        return
    if not _expect(tile_set.get_source_count() == FARM_SOURCE_COUNT, "35 farm atlas sources"):
        return
    var manifest: Array[Dictionary] = Stamper.farm_sources()
    var tile_count := 0
    for source_id in FARM_SOURCE_COUNT:
        var source := tile_set.get_source(source_id) as TileSetAtlasSource
        if not _expect(source != null, "farm source %d must be an atlas" % source_id):
            return
        if not _expect(
            source.texture.resource_path == manifest[source_id]["path"],
            "farm source %d texture manifest" % source_id,
        ):
            return
        if not _expect(
            source.texture_region_size == Vector2i(64, 32),
            "farm source %d tile size" % source_id,
        ):
            return
        tile_count += source.get_tiles_count()
    if not _expect(tile_count == FARM_TILE_COUNT, "1,542 registered farm atlas tiles"):
        return

    var farm_backdrop := farm_map.get_node("Backdrop") as TileMapLayer
    if not _expect(farm_backdrop != null, "FarmMap Backdrop must exist"):
        return
    if not _expect(
        farm_backdrop.position == Vector2(736.0, 0.0), "farm Backdrop alignment transform"
    ):
        return
    if not _expect(
        farm_backdrop.tile_set == tile_set,
        "FarmMap Backdrop must share the terrain TileSet",
    ):
        return
    var expected_backdrop := WorldMath.backdrop_cells(
        WorldMath.map_camera_bounds(WorldContract.MAP_SIZE), WorldContract.MAP_SIZE
    )
    if not _expect(
        farm_backdrop.get_used_cells().size() == expected_backdrop.size(),
        "farm Backdrop paints exactly the camera overdraw cells",
    ):
        return
    var farm_map_rect := Rect2i(Vector2i.ZERO, WorldContract.MAP_SIZE)
    for cell in expected_backdrop:
        if not _expect(
            not farm_map_rect.has_point(cell), "farm Backdrop %s stays off the map" % cell
        ):
            return
    # A few independent cell fixtures: interior materials, plus clamped
    # edge overdraw (the stamper's contract clamp, never grass or a new shore).
    for cell in [
        Vector2i(0, 0),
        Vector2i(23, 14),
        Vector2i(1, 0),
        Vector2i(44, 0),
        Vector2i(15, 19),
        Vector2i(42, 0),
        Vector2i(23, 35),
    ]:
        var expected := Stamper.tile_for(cell)
        if not _expect_vec2i(
            ground.get_cell_atlas_coords(cell),
            Vector2i(expected.y, expected.z),
            "ground %s tile" % cell,
        ):
            return
        if not _expect(
            ground.get_cell_source_id(cell) == expected.x, "ground %s source" % cell
        ):
            return
    var used_cells := ground.get_used_cells()
    if not _expect(used_cells.size() == FARM_MAP_CELLS, "Ground must contain 1,920 cells"):
        return
    for cell in [Vector2i(0, 0), Vector2i(47, 39), Vector2i(20, 23)]:
        if not _expect(used_cells.has(cell), "Ground missing cell %s" % cell):
            return
        if not _expect_vec2(
            ground.to_global(ground.map_to_local(cell)),
            _cell_center(cell),
            "cell %s center" % cell,
        ):
            return
    for backdrop_cell in [Vector2i(-1, 0), Vector2i(48, 9), Vector2i(20, -1)]:
        # The material clamps to the edge cell while the phase keeps the raw
        # (possibly negative) cell parity, exactly as the stamper authored it.
        var expected := Stamper.tile_for(backdrop_cell)
        if not _expect_vec2i(
            farm_backdrop.get_cell_atlas_coords(backdrop_cell),
            Vector2i(expected.y, expected.z),
            "farm Backdrop %s clamped edge tile" % backdrop_cell,
        ):
            return
        if not _expect(
            farm_backdrop.get_cell_source_id(backdrop_cell) == expected.x,
            "farm Backdrop %s clamped edge source" % backdrop_cell,
        ):
            return

    var farm_soil := farm_map.get_node("FarmSoil") as Node2D
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

    var farm_effects := farm_map.get_node("FarmActionEffects") as Node2D
    if not _expect(farm_effects != null, "FarmActionEffects must exist"):
        return
    if not _expect(not farm_effects.y_sort_enabled, "FarmActionEffects must not enable y-sort"):
        return
    if not _expect(farm_effects.z_index == 5, "FarmActionEffects z-index"):
        return

    var ambience := farm_map.get_node("HomesteadAmbience") as HomesteadAmbience
    if not _expect(ambience != null, "HomesteadAmbience must exist"):
        return
    var ripples: Array[Sprite2D] = []
    for child in ambience.get_children():
        var ripple := child as Sprite2D
        if ripple != null:
            ripples.append(ripple)
    if not _expect(
        ripples.size() == WorldContract.RIVER_RIPPLE_CELLS.size(),
        "HomesteadAmbience ripple count",
    ):
        return
    for index in ripples.size():
        var ripple := ripples[index]
        if not _expect(
            ripple.texture.resource_path == "res://assets/sprites/polish/river-ripple.png",
            "ripple %d texture" % index,
        ):
            return
        if not _expect(ripple.hframes == 3, "ripple %d frame columns" % index):
            return
        if not _expect_vec2(ripple.scale, Vector2(1, 1), "ripple %d scale" % index):
            return
        if not _expect_vec2(ripple.offset, Vector2.ZERO, "ripple %d offset" % index):
            return
        if not _expect_vec2(
            ripple.position,
            _cell_center(WorldContract.RIVER_RIPPLE_CELLS[index]),
            "ripple %d sits on its contract water cell" % index,
        ):
            return
    if not _expect(
        farm_soil.z_index < ambience.z_index
        and farm_effects.z_index < ambience.z_index
        and ambience.z_index < (world.get_node("TargetHighlight") as Line2D).z_index
        and ambience.z_index < (farm_map.get_node("Entities") as Node2D).z_index,
        "ambience renders above soil/effects below target/entities",
    ):
        return
    var rain_layer := world.get_node("RainLayer") as Node2D
    if not _expect(rain_layer != null, "World must contain a RainLayer"):
        return
    if not _expect(
        farm_soil.z_index < rain_layer.z_index
        and farm_effects.z_index < rain_layer.z_index
        and rain_layer.z_index < ambience.z_index
        and rain_layer.z_index < (world.get_node("TargetHighlight") as Line2D).z_index
        and rain_layer.z_index < (farm_map.get_node("Entities") as Node2D).z_index,
        "rain renders above soil/effects and below ambience/target/entities",
    ):
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
            soil.texture.resource_path == "res://assets/sprites/world-v2/soil.png",
            "soil %s texture" % farm_cells[index],
        ):
            return
        if not _expect(soil.hframes == 2, "soil %s frame columns" % farm_cells[index]):
            return

    # --- Collision: every contract-bearing polygon exists exactly once ---
    var static_collision := farm_map.get_node("StaticCollision") as StaticBody2D
    if not _expect(
        static_collision.position == Vector2.ZERO, "StaticCollision must be at world origin"
    ):
        return
    var expected_collisions := _expected_collision_counts()
    var actual_collisions := {}
    for child in static_collision.get_children():
        var collision := child as CollisionPolygon2D
        if not _expect(collision != null, "StaticCollision children must be polygons"):
            return
        var key := _polygon_key(collision.polygon)
        actual_collisions[key] = int(actual_collisions.get(key, 0)) + 1
    if not _expect(
        actual_collisions.size() == expected_collisions.size(),
        "collision polygon set must equal terrain runs + props + fences + perimeter",
    ):
        return
    for key in expected_collisions:
        if not _expect(
            int(actual_collisions.get(key, 0)) == int(expected_collisions[key]),
            "missing or duplicated collision polygon %s" % key,
        ):
            return
    for named in [
        {"node": "HouseCollision", "footprint": WorldContract.HOUSE_FOOTPRINT},
        {"node": "ShippingCollision", "footprint": WorldContract.SHIPPING_FOOTPRINT},
        {"node": "TruckCollision", "footprint": WorldContract.TRUCK_FOOTPRINT},
    ]:
        var collision := static_collision.get_node_or_null(named["node"]) as CollisionPolygon2D
        if not _expect(collision != null, "%s must stay authored" % named["node"]):
            return
        if not _expect_polygon(
            collision.polygon,
            WorldMath.footprint_to_polygon(named["footprint"]),
            "%s polygon" % named["node"],
        ):
            return
    var perimeter_names := ["PerimeterTop", "PerimeterRight", "PerimeterBottom", "PerimeterLeft"]
    var perimeter_rects := WorldContract.perimeter_footprints(WorldContract.MAP_SIZE)
    for index in perimeter_rects.size():
        var collision := static_collision.get_node(perimeter_names[index]) as CollisionPolygon2D
        if not _expect_polygon(
            collision.polygon,
            WorldMath.footprint_to_polygon(perimeter_rects[index]),
            "%s polygon" % perimeter_names[index],
        ):
            return

    var entities := farm_map.get_node("Entities") as Node2D
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
    var prop_count := WorldContract.blocking_props().size()
    var fence_count := WorldContract.fence_cells().size()
    if not _expect(
        entities.get_child_count()
        == 1 + prop_count + fence_count + FARM_DECOR.size() + farm_cells.size(),
        "Entities holds the player, every contract prop/fence, passable decor and the 30 crops",
    ):
        return

    # --- Contract-bearing sprite roots: anchor, parts and approved 1x1s ---
    for entry in WorldContract.blocking_props():
        var prop := entities.get_node_or_null(entry["node"]) as Node2D
        if not _expect(prop != null, "%s blocking prop root" % entry["node"]):
            return
        var footprint: Rect2 = entry["footprint"]
        if not _expect_vec2(
            prop.position,
            WorldMath.footprint_ground_anchor(footprint),
            "%s ground anchor" % entry["node"],
        ):
            return
        if not _expect_names(prop, ["Shadow", "Sprite2D"], "%s entity" % entry["node"]):
            return
        var shadow := prop.get_node("Shadow") as Sprite2D
        if not _expect(
            shadow.texture.resource_path == "res://assets/sprites/proof-shadow.png",
            "%s shadow texture" % entry["node"],
        ):
            return
        var sprite := prop.get_node("Sprite2D") as Sprite2D
        if not _expect(sprite.texture != null, "%s sprite texture" % entry["node"]):
            return
        var expected_offset := Vector2(0.0, -sprite.texture.get_height() * 0.5)
        if entry["node"] == "House":
            expected_offset = HOUSE_ART_OFFSET
        if not _expect_vec2(
            sprite.offset,
            expected_offset,
            "%s bottom-center offset" % entry["node"],
        ):
            return
        if footprint.size == Vector2.ONE:
            if not _expect(
                footprint.position == footprint.position.floor(),
                "%s 1x1 footprint sits on an approved cell" % entry["node"],
            ):
                return
    # --- HPA-863 passable decor: approved anchors, textures, no collision ---
    for entry in FARM_DECOR:
        var decor := entities.get_node_or_null(entry["node"]) as Node2D
        if not _expect(decor != null, "%s passable decor root" % entry["node"]):
            return
        if not _expect_names(decor, ["Shadow", "Sprite2D"], "%s decor entity" % entry["node"]):
            return
        if not _expect_vec2(
            decor.position,
            WorldMath.footprint_ground_anchor(entry["footprint"]),
            "%s decor ground anchor" % entry["node"],
        ):
            return
        var decor_sprite := decor.get_node("Sprite2D") as Sprite2D
        if not _expect(
            decor_sprite.texture.resource_path == FARM_TEXTURE_DIR + entry["texture"],
            "%s decor texture" % entry["node"],
        ):
            return
        if not _expect_vec2(
            decor_sprite.offset,
            Vector2(0.0, -decor_sprite.texture.get_height() * 0.5),
            "%s decor bottom-center offset" % entry["node"],
        ):
            return
        if not _expect(
            not decor.is_in_group("player_occluder"),
            "%s passable decor never fades the player" % entry["node"],
        ):
            return

    # --- HPA-863 walkable pier deck: below actors, same approved anchors ---
    var pier_deck := farm_map.get_node_or_null("PierDeck") as Node2D
    if not _expect(pier_deck != null, "PierDeck container"):
        return
    if not _expect(pier_deck.get_parent() == farm_map, "PierDeck is a direct map child"):
        return
    if not _expect(not pier_deck.y_sort_enabled, "PierDeck is never Y-sorted with actors"):
        return
    if not _expect(
        pier_deck.z_index < entities.z_index,
        "the walkable pier deck draws below the Y-sorted actor layer",
    ):
        return
    # The review's legal stance: player root (464,930) stands on a plank rooted
    # at Y=944. Because the deck is not in Entities and has a lower z, the
    # player is drawn above the whole deck instead of being covered by it.
    var legal_deck_stance := WorldMath.grid_to_world(Vector2(24.3125, 33.8125))
    if not _expect_vec2(
        legal_deck_stance,
        Vector2(464.0, 930.0),
        "the deck-standing stance resolves to the reviewed player root",
    ):
        return
    for entry in PIER_DECK:
        var plank := pier_deck.get_node_or_null(entry["node"]) as Node2D
        if not _expect(plank != null, "%s pier deck root" % entry["node"]):
            return
        if not _expect(plank.get_parent() == pier_deck, "%s stays out of Entities" % entry["node"]):
            return
        if not _expect_names(plank, ["Shadow", "Sprite2D"], "%s deck entity" % entry["node"]):
            return
        if not _expect_vec2(
            plank.position,
            WorldMath.footprint_ground_anchor(entry["footprint"]),
            "%s deck ground anchor" % entry["node"],
        ):
            return
        var plank_sprite := plank.get_node("Sprite2D") as Sprite2D
        if not _expect(
            plank_sprite.texture.resource_path == FARM_TEXTURE_DIR + entry["texture"],
            "%s deck texture" % entry["node"],
        ):
            return
        if not _expect_vec2(
            plank_sprite.offset,
            Vector2(0.0, -plank_sprite.texture.get_height() * 0.5),
            "%s deck bottom-center offset" % entry["node"],
        ):
            return
    if not _expect(
        entities.get_node_or_null("PierPlank1") == null,
        "pier planks are absent from the Y-sorted actor layer",
    ):
        return

    # --- HPA-863 art polish: building shadows and the farmhouse art offset ---
    for node_name in BUILDING_SHADOWS:
        var building := entities.get_node_or_null(node_name) as Node2D
        if not _expect(building != null, "%s building root" % node_name):
            return
        var building_shadow := building.get_node("Shadow") as Sprite2D
        var shadow_scale := float(BUILDING_SHADOWS[node_name])
        if not _expect_vec2(
            building_shadow.scale,
            Vector2(shadow_scale, shadow_scale),
            "%s grounded shadow scale" % node_name,
        ):
            return
        var effective_shadow := (
            building_shadow.position + building_shadow.offset * building_shadow.scale
        )
        if not _expect_vec2(
            effective_shadow,
            Vector2.ZERO,
            "%s shadow draws at the building ground root" % node_name,
        ):
            return

    var house := entities.get_node("House") as Node2D
    if not _expect_vec2(house.scale, Vector2.ONE, "the 224x192 farmhouse uses native scale 1"):
        return
    if not _expect(
        (house.get_node("Sprite2D") as Sprite2D).texture.resource_path
        == FARM_TEXTURE_DIR + "farmhouse.png",
        "farmhouse cutout",
    ):
        return
    var shipping := entities.get_node("Shipping") as Node2D
    if not _expect(
        (shipping.get_node("Sprite2D") as Sprite2D).texture.resource_path == BIN_TEXTURE_PATH,
        "shipping bin cutout",
    ):
        return
    var truck := entities.get_node("Truck") as Node2D
    if not _expect_vec2(
        truck.position,
        WorldMath.footprint_ground_anchor(WorldContract.TRUCK_FOOTPRINT),
        "farm truck anchor",
    ):
        return
    var truck_sprite := truck.get_node("Sprite2D") as Sprite2D
    if not _expect(
        truck_sprite.texture.resource_path == "res://assets/sprites/kei-truck.png",
        "farm truck texture",
    ):
        return
    if not _expect(truck_sprite.hframes == 2, "farm truck frame columns"):
        return
    if not _expect(truck_sprite.frame == 0, "farm truck front-view frame"):
        return
    if not _expect(truck_sprite.flip_h, "farm truck faces the east road"):
        return
    if not _expect_vec2(
        truck_sprite.offset, Vector2(0.0, -48.0), "farm truck bottom-center offset"
    ):
        return

    # --- All 85 fence sprites sit on their approved cells ---
    var fence_materials := _fence_materials()
    for cell in WorldContract.fence_cells():
        var material: String = fence_materials[cell]
        var prefix := "BambooFence" if material == "bamboo" else "WoodFence"
        var fence := entities.get_node_or_null("%s_%d_%d" % [prefix, cell.x, cell.y]) as Node2D
        if not _expect(fence != null, "%s fence at %s" % [material, cell]):
            return
        if not _expect_vec2(
            fence.position,
            WorldMath.footprint_ground_anchor(Rect2(cell, Vector2.ONE)),
            "fence %s anchor" % cell,
        ):
            return
        if not _expect_names(fence, ["Shadow", "Sprite2D"], "fence %s entity" % cell):
            return
        var sprite := fence.get_node("Sprite2D") as Sprite2D
        if not _expect(
            _fence_textures(material).has(sprite.texture.resource_path),
            "fence %s uses the %s fence art" % [cell, material],
        ):
            return

    var player := world.player
    if not _expect(player != null, "World must expose its Player"):
        return
    if not _expect(player.get_parent() == entities, "Player must sit under FarmMap/Entities"):
        return
    if not _expect(entities.get_child(0) == player, "Player must be the first Entities child"):
        return
    if not _expect(world.get_node("%Player") == player, "%Player must resolve to world.player"):
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
    if not _expect(player_sprite.vframes == 4, "player frame rows"):
        return
    # _ready()/enter_map() repaint the frame, so the authored value can only be
    # read on an instance that never entered the tree.
    var authored_player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
    var authored_sprite := authored_player.get_node_or_null("Sprite2D") as Sprite2D
    var authored_frame := -1
    if authored_sprite != null:
        authored_frame = authored_sprite.frame
    authored_player.free()
    if not _expect(authored_frame == 8, "player.tscn authored DOWN idle frame"):
        return
    if not _expect(player_sprite.frame == 8, "player repaints DOWN idle after enter_map"):
        return
    if not _expect(
        player_sprite.texture.resource_path == "res://assets/sprites/player-walk.png",
        "player walk texture",
    ):
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
    for prop in [shipping, truck, player]:
        if not _expect(
            prop.z_index == shared_entity_z_index, "%s shared entity z-index" % prop.name
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
            crop_sprite.texture.resource_path == "res://assets/sprites/world-v2/crops.png",
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
    if not _expect(
        camera_bounds == WorldMath.map_camera_bounds(WorldContract.MAP_SIZE),
        "camera bounds derive from the 48x40 map",
    ):
        return
    if not _expect(camera.zoom == Vector2.ONE * WorldContract.CAMERA_ZOOM, "camera zoom"):
        return
    if not _expect(root.get_window().min_size == UiSettings.MIN_WINDOW_SIZE, "minimum window size"):
        return

    for entry in [
        {"action": "move_up", "physical": 87},
        {"action": "move_left", "physical": 65},
        {"action": "move_down", "physical": 83},
        {"action": "move_right", "physical": 68},
        {"action": "select_seeds", "physical": 50},
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
    for removed_action in ["select_hoe", "select_water", "select_hands"]:
        if not _expect(not InputMap.has_action(removed_action), "%s is retired" % removed_action):
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

    var spawn_cell := Vector2i(
        floori(WorldContract.PLAYER_SPAWN.x), floori(WorldContract.PLAYER_SPAWN.y)
    )
    var target_cases := [
        {"action": "move_up", "facing": WorldMath.Facing.UP, "cell": spawn_cell + Vector2i(-1, -1)},
        {"action": "move_right", "facing": WorldMath.Facing.RIGHT, "cell": spawn_cell + Vector2i(1, -1)},
        {"action": "move_down", "facing": WorldMath.Facing.DOWN, "cell": spawn_cell + Vector2i(1, 1)},
        {"action": "move_left", "facing": WorldMath.Facing.LEFT, "cell": spawn_cell + Vector2i(-1, 1)},
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

    _place_player(player, Vector2(0.5, 0.5))
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

    # High-motion collision against the full-cell shipping bin: the real stop
    # lands outside the footprint rather than tunnelling through it.
    _place_player(player, Vector2(22.5, 17.5))
    await physics_frame
    player.velocity = Vector2(0.0, 12000.0)
    player.move_and_slide()
    var bin_stop := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _outside_footprint(bin_stop, WorldContract.SHIPPING_FOOTPRINT)
        and player.get_slide_collision_count() > 0,
        "high-motion shipping bin collision",
    ):
        return
    player.velocity = Vector2.ZERO

    # The door approach stops on the house's southern slice; the yard gate and
    # the field gate are real openings, not sealed walls.
    _place_player(player, Vector2(23.5, 11.5))
    await physics_frame
    await _hold_actions(["move_up"], 40)
    var door_approach := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _outside_footprint(door_approach, WorldContract.HOUSE_FOOTPRINT),
        "door approach remains outside the house footprint",
    ):
        return
    if not _expect(
        door_approach.y >= 10.0 and door_approach.y <= 10.6,
        "door approach stops at the bed-side house face (%s)" % door_approach,
    ):
        return
    _place_player(player, Vector2(23.5, 13.5))
    await physics_frame
    await _hold_actions(["move_down"], 60)
    var yard_exit := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        yard_exit.y > 14.5 and yard_exit.x > 22.5,
        "the yard's south gate lets the player leave the homestead",
    ):
        return
    _place_player(player, Vector2(22.5, 20.5))
    await physics_frame
    await _hold_actions(["move_left"], 60)
    var field_entry := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        field_entry.x < 21.0 and field_entry.x > 18.0,
        "the field gate opens from the path into the wooden yard",
    ):
        return

    # Perimeter and blocking terrain: every edge walk stays in bounds and off
    # the blocking band.
    _place_player(player, Vector2(2.5, 10.0))
    await physics_frame
    await _hold_actions(["move_left"], 120)
    if not _expect(
        _within_player_bounds(WorldMath.world_to_grid(player.global_position)),
        "west river boundary",
    ):
        return
    _place_player(player, Vector2(41.5, 10.0))
    await physics_frame
    await _hold_actions(["move_right"], 120)
    var east_stop := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _within_player_bounds(east_stop) and east_stop.x < 44.0,
        "east road boundary stops before the paddy",
    ):
        return
    _place_player(player, Vector2(12.5, 5.5))
    await physics_frame
    await _hold_actions(["move_up"], 120)
    var north_stop := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        _within_player_bounds(north_stop) and north_stop.y > 3.0,
        "north forest boundary blocks the player",
    ):
        return
    _place_player(player, Vector2(32.5, 34.5))
    await physics_frame
    await _hold_actions(["move_down"], 120)
    if not _expect(
        _within_player_bounds(WorldMath.world_to_grid(player.global_position)),
        "bottom perimeter",
    ):
        return

    # The canonical 30-cell patch is open ground: a diagonal walk crosses it.
    _place_player(player, Vector2(15.5, 19.5))
    await physics_frame
    await _hold_actions(["move_down"], 130)
    var farm_exit := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        farm_exit.x > 18.0 and farm_exit.y > 22.0,
        "farm edge traversal crosses the patch freely",
    ):
        return

    _place_player(player, Vector2(WorldContract.TRUCK_ARRIVAL) + Vector2(0.5, 0.5))
    player.facing = WorldMath.Facing.RIGHT
    await physics_frame
    world._process(0.0)
    if not _expect(world.hud.prompt_text() == "[E] Drive to town", "farm truck prompt"):
        return
    world.interact()
    if not _expect(
        world._session.snapshot()["location"] == GameRules.MapId.FARM,
        "farm session keeps FARM until mid-beat swap",
    ):
        return
    if not _expect(world.hud.toast_text() == "", "farm truck travel raises no toast"):
        return
    _finish_travel(world.hud)
    if not _expect(
        world._session.snapshot()["location"] == GameRules.MapId.TOWN,
        "farm truck E interaction drives to town",
    ):
        return

    var town_names := ["TownMap", "RainLayer", "TargetHighlight", "GameHud"]
    if not _expect_names(world, town_names, "World after travel"):
        return
    if not _expect_child_order(world, town_names, "World scene-tree order after travel"):
        return
    var town_map := world.get_node("TownMap") as Node2D
    if not _expect(town_map != null, "World must contain a TownMap"):
        return
    var town_map_names := ["Backdrop", "Ground", "StaticCollision", "Entities"]
    if not _expect_names(town_map, town_map_names, "TownMap"):
        return
    if not _expect_child_order(town_map, town_map_names, "TownMap scene-tree order"):
        return

    var backdrop := town_map.get_node("Backdrop") as TileMapLayer
    if not _expect(backdrop != null, "TownMap Backdrop must exist"):
        return
    if not _expect(backdrop.position == Vector2(736.0, 0.0), "town Backdrop alignment"):
        return
    var town_ground := town_map.get_node("Ground") as TileMapLayer
    if not _expect(town_ground != null, "TownMap Ground must exist"):
        return
    if not _expect(town_ground.position == Vector2(736.0, 0.0), "town Ground alignment transform"):
        return
    var town_tile_set := town_ground.tile_set
    if not _expect(town_tile_set != null, "town Ground must have a TileSet"):
        return
    if not _expect(
        town_tile_set.resource_path == TOWN_TILESET_PATH, "town Ground uses the town-owned tileset"
    ):
        return
    if not _expect(
        backdrop.tile_set == town_tile_set, "town Backdrop shares the town-owned tileset"
    ):
        return
    if not _expect(town_tile_set.tile_size == Vector2i(64, 32), "town tile size"):
        return
    if not _expect(town_tile_set.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC, "town tile shape"):
        return
    if not _expect(town_tile_set.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN, "town tile layout"):
        return
    if not _expect(town_tile_set.get_source_count() == 3, "town tileset source count"):
        return
    for source_id in TOWN_SOURCE_TEXTURES.size():
        var town_source := town_tile_set.get_source(source_id) as TileSetAtlasSource
        if not _expect(town_source != null, "town source %d must be an atlas" % source_id):
            return
        if not _expect(
            town_source.texture.resource_path == TOWN_SOURCE_TEXTURES[source_id],
            "town source %d texture" % source_id,
        ):
            return
        if not _expect(
            town_source.texture_region_size == Vector2i(64, 32),
            "town source %d tile size" % source_id,
        ):
            return
        if not _expect(town_source.get_tiles_count() == 4, "town source %d phase count" % source_id):
            return

    var backdrop_used := backdrop.get_used_cells()
    var backdrop_cells := WorldMath.backdrop_cells(
        TownContract.CAMERA_BOUNDS, TownContract.MAP_SIZE
    )
    var map_rect := Rect2i(Vector2i.ZERO, TownContract.MAP_SIZE)
    for backdrop_cell in backdrop_cells:
        if not _expect(
            not map_rect.has_point(backdrop_cell),
            "town Backdrop %s must stay outside the map" % backdrop_cell,
        ):
            return
        if not _expect(backdrop_used.has(backdrop_cell), "town Backdrop missing cell %s" % backdrop_cell):
            return
        # Pinned literally rather than via TownContract.is_backdrop_road — the
        # same predicate the stamper calls — so a predicate regression cannot
        # pass this check.
        var road_cell: bool = backdrop_cell.y == 9 or (
            backdrop_cell.y == 10 and backdrop_cell.x <= 4
        )
        if not _expect(
            backdrop.get_cell_source_id(backdrop_cell) == (2 if road_cell else 0),
            "town Backdrop %s source" % backdrop_cell,
        ):
            return
        if not _expect_vec2i(
            backdrop.get_cell_atlas_coords(backdrop_cell),
            Vector2i(_town_phase(backdrop_cell), 0),
            "town Backdrop %s phase" % backdrop_cell,
        ):
            return
    if not _expect(
        backdrop_used.size() == backdrop_cells.size(),
        "town Backdrop must paint only the camera coverage outside the map",
    ):
        return

    var town_used := town_ground.get_used_cells()
    if not _expect(town_used.size() == 192, "town Ground must contain exactly 192 cells"):
        return
    for y in TownContract.MAP_SIZE.y:
        for x in TownContract.MAP_SIZE.x:
            var cell := Vector2i(x, y)
            if not _expect(town_used.has(cell), "town Ground missing cell %s" % cell):
                return
            var expected_center := WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
            if not _expect_vec2(
                town_ground.to_global(town_ground.map_to_local(cell)),
                expected_center,
                "town cell %s center" % cell,
            ):
                return
            var cell_road: bool = cell.y == 9 or (cell.y == 10 and cell.x <= 4)
            if not _expect(
                town_ground.get_cell_source_id(cell) == (2 if cell_road else 1),
                "town cell %s source" % cell,
            ):
                return
            if not _expect_vec2i(
                town_ground.get_cell_atlas_coords(cell),
                Vector2i(_town_phase(cell), 0),
                "town cell %s phase" % cell,
            ):
                return

    var town_collision := town_map.get_node("StaticCollision") as StaticBody2D
    var town_collision_names := [
        "StationCollision",
        "SeedShopCollision",
        "CafeCollision",
        "MarketCollision",
        "TruckCollision",
        "VillagerShopkeeperCollision",
        "VillagerFarmerCollision",
        "VillagerResidentCollision",
        "PerimeterTop",
        "PerimeterRight",
        "PerimeterBottom",
        "PerimeterLeft",
    ]
    if not _expect_names(town_collision, town_collision_names, "TownMap StaticCollision"):
        return
    if not _expect_child_order(
        town_collision, town_collision_names, "TownMap StaticCollision scene-tree order"
    ):
        return
    var town_footprints := {
        "StationCollision": TownContract.STATION_FOOTPRINT,
        "SeedShopCollision": TownContract.SHOP_FOOTPRINT,
        "CafeCollision": TownContract.CAFE_FOOTPRINT,
        "MarketCollision": TownContract.MARKET_FOOTPRINT,
        "TruckCollision": TownContract.TRUCK_FOOTPRINT,
        "VillagerShopkeeperCollision": TownContract.VILLAGER_FOOTPRINTS[0],
        "VillagerFarmerCollision": TownContract.VILLAGER_FOOTPRINTS[1],
        "VillagerResidentCollision": TownContract.VILLAGER_FOOTPRINTS[2],
    }
    var town_perimeter := WorldContract.perimeter_footprints(TownContract.MAP_SIZE)
    for index in town_perimeter.size():
        town_footprints[town_collision_names[8 + index]] = town_perimeter[index]
    for collider_name in town_collision_names:
        var collision := town_collision.get_node(collider_name) as CollisionPolygon2D
        if not _expect_polygon(
            collision.polygon,
            WorldMath.footprint_to_polygon(town_footprints[collider_name]),
            "town %s polygon" % collider_name,
        ):
            return

    var town_entities := town_map.get_node("Entities") as Node2D
    if not _expect(town_entities.y_sort_enabled, "town Entities must enable y-sort"):
        return
    var town_rain_layer := world.get_node_or_null("RainLayer") as Node2D
    if not _expect(
        town_rain_layer == rain_layer
        and town_rain_layer.is_inside_tree()
        and town_rain_layer.visible
        and backdrop.z_index < town_rain_layer.z_index
        and town_ground.z_index < town_rain_layer.z_index
        and town_rain_layer.z_index < target_highlight.z_index
        and town_rain_layer.z_index < town_entities.z_index,
        "town keeps the same visible RainLayer above backdrop/ground and below target/entities",
    ):
        return
    var town_y_sort_nodes: Array[CanvasItem] = []
    if world.y_sort_enabled:
        town_y_sort_nodes.append(world)
    for node in world.find_children("*", "CanvasItem", true, false):
        var canvas_item := node as CanvasItem
        if canvas_item.y_sort_enabled:
            town_y_sort_nodes.append(canvas_item)
    if not _expect(
        town_y_sort_nodes.size() == 1 and town_y_sort_nodes[0] == town_entities,
        "town Entities must be the only enabled y-sort CanvasItem",
    ):
        return
    var town_entity_names := [
        "Player",
        "Station",
        "SeedShop",
        "Cafe",
        "Market",
        "Truck",
        "VillagerShopkeeper",
        "VillagerFarmer",
        "VillagerResident",
    ]
    if not _expect_names(town_entities, town_entity_names, "town Entities"):
        return
    if not _expect_child_order(town_entities, town_entity_names, "town Entities scene-tree order"):
        return

    var town_props := [
        {"node": "Station", "texture": TOWN_PROP_TEXTURE_DIR + "station.png", "footprint": TownContract.STATION_FOOTPRINT},
        {"node": "SeedShop", "texture": TOWN_PROP_TEXTURE_DIR + "seed-shop.png", "footprint": TownContract.SHOP_FOOTPRINT},
        {"node": "Cafe", "texture": TOWN_PROP_TEXTURE_DIR + "cafe.png", "footprint": TownContract.CAFE_FOOTPRINT},
        {"node": "Market", "texture": TOWN_PROP_TEXTURE_DIR + "market.png", "footprint": TownContract.MARKET_FOOTPRINT},
    ]
    for entry in town_props:
        var prop := town_entities.get_node(entry.node) as Node2D
        if not _expect(prop != null, "town %s entity" % entry.node):
            return
        if not _expect_vec2(
            prop.position,
            WorldMath.footprint_ground_anchor(entry.footprint),
            "town %s anchor" % entry.node,
        ):
            return
        if not _expect_names(prop, ["Shadow", "Sprite2D"], "town %s entity" % entry.node):
            return
        var prop_shadow := prop.get_node("Shadow") as Sprite2D
        if not _expect(
            prop_shadow.texture.resource_path == "res://assets/sprites/proof-shadow.png",
            "town %s shadow texture" % entry.node,
        ):
            return
        var prop_sprite := prop.get_node("Sprite2D") as Sprite2D
        if not _expect(
            prop_sprite.texture.resource_path == entry.texture,
            "town %s texture" % entry.node,
        ):
            return
        if not _expect(prop_sprite.hframes == 1, "town %s single-frame cutout" % entry.node):
            return
        if not _expect_vec2(
            prop_sprite.offset, Vector2(0.0, -48.0), "town %s bottom-center offset" % entry.node
        ):
            return

    var town_truck := town_entities.get_node("Truck") as Node2D
    if not _expect_vec2(
        town_truck.position,
        WorldMath.footprint_ground_anchor(TownContract.TRUCK_FOOTPRINT),
        "town truck anchor",
    ):
        return
    if not _expect_names(town_truck, ["Shadow", "Sprite2D"], "town truck entity"):
        return
    var town_truck_sprite := town_truck.get_node("Sprite2D") as Sprite2D
    if not _expect(
        town_truck_sprite.texture.resource_path == "res://assets/sprites/kei-truck.png",
        "town truck texture",
    ):
        return
    if not _expect(town_truck_sprite.hframes == 2, "town truck frame columns"):
        return
    if not _expect(town_truck_sprite.frame == 1, "town truck rear-view frame"):
        return
    if not _expect(town_truck_sprite.flip_h, "town truck faces the west road"):
        return
    if not _expect_vec2(
        town_truck_sprite.offset, Vector2(0.0, -48.0), "town truck bottom-center offset"
    ):
        return

    if not _expect(player.get_parent() == town_entities, "Player must sit under TownMap/Entities"):
        return
    if not _expect(town_entities.get_child(0) == player, "Player must be the first town child"):
        return
    if not _expect(world.get_node("%Player") == player, "%Player must resolve after travel"):
        return
    if not _expect_vec2(
        player.global_position,
        WorldMath.grid_to_world(Vector2(TownContract.TRUCK_ARRIVAL) + Vector2(0.5, 0.5)),
        "town truck arrival position",
    ):
        return
    if not _expect(world.farm_view == null, "farm view is null in town"):
        return
    var town_camera_bounds := Rect2(
        camera.limit_left,
        camera.limit_top,
        camera.limit_right - camera.limit_left,
        camera.limit_bottom - camera.limit_top,
    )
    if not _expect(town_camera_bounds == TownContract.CAMERA_BOUNDS, "town camera bounds"):
        return

    _place_player(player, Vector2(15.5, 11.5))
    player.facing = WorldMath.Facing.RIGHT
    await physics_frame
    if not _expect(not target_highlight.visible, "town east edge target hidden"):
        return
    _place_player(player, Vector2(14.5, 10.5))
    player.facing = WorldMath.Facing.DOWN
    await physics_frame
    if not _expect(
        target_highlight.visible
        and target_highlight.points == WorldMath.cell_diamond(Vector2i(15, 11)),
        "town in-bounds target drawn",
    ):
        return
    _place_player(player, Vector2(14.5, 10.5))
    await _hold_actions(["move_right"], 90)
    var town_grid := WorldMath.world_to_grid(player.global_position)
    if not _expect(
        town_grid.x > 14.5 and town_grid.x < 16.0 and town_grid.y > 0.0,
        "town perimeter walk travels east and stops at the band",
    ):
        return
    _place_player(player, Vector2(TownContract.TRUCK_ARRIVAL) + Vector2(0.5, 0.5))
    player.facing = WorldMath.Facing.LEFT
    await physics_frame
    world._process(0.0)
    if not _expect(world.hud.prompt_text() == "[E] Drive home", "town truck prompt"):
        return
    world.interact()
    if not _expect(
        world._session.snapshot()["location"] == GameRules.MapId.TOWN,
        "town session keeps TOWN until mid-beat swap",
    ):
        return
    if not _expect(world.hud.toast_text() == "", "town truck travel raises no toast"):
        return
    _finish_travel(world.hud)
    if not _expect(
        world._session.snapshot()["location"] == GameRules.MapId.FARM,
        "town truck E interaction drives home",
    ):
        return

    var return_names := ["FarmMap", "RainLayer", "TargetHighlight", "GameHud"]
    if not _expect_names(world, return_names, "World after driving home"):
        return
    if not _expect_child_order(world, return_names, "World scene-tree order after driving home"):
        return
    var returned_farm := world.get_node("FarmMap") as FarmMap
    if not _expect(player.get_parent() == returned_farm.get_node("Entities"), "player rejoins farm"):
        return
    if not _expect_vec2(
        player.global_position,
        WorldMath.grid_to_world(Vector2(WorldContract.TRUCK_ARRIVAL) + Vector2(0.5, 0.5)),
        "farm truck arrival position",
    ):
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
        var hframes: int = entry.get("hframes", 1)
        var vframes: int = entry.get("vframes", 1)
        if not _expect(texture.get_width() % hframes == 0, "%s width divides by hframes" % entry.path):
            return
        if not _expect(texture.get_height() % vframes == 0, "%s height divides by vframes" % entry.path):
            return
        var image := texture.get_image()
        var frame_width := texture.get_width() / hframes
        var frame_height := texture.get_height() / vframes
        for row in vframes:
            for column in hframes:
                var has_opaque := false
                var has_transparent := false
                for y in range(row * frame_height, (row + 1) * frame_height):
                    for x in range(column * frame_width, (column + 1) * frame_width):
                        if image.get_pixel(x, y).a > 0.0:
                            has_opaque = true
                        else:
                            has_transparent = true
                var frame_label := "cell %d,%d" % [column, row]
                if not _expect(has_opaque, "%s %s has non-transparent pixels" % [entry.path, frame_label]):
                    return
                if not _expect(has_transparent, "%s %s has transparent pixels" % [entry.path, frame_label]):
                    return

    world.hud._sfx_player.stop()
    await create_timer(0.2).timeout

    print("world shell smoke passed: 48x40 stamped ground/backdrop, 47 props, 85 fences, 8 passable decor, a 3-plank below-actor pier deck, collisions, player, camera, assets")
    quit(0)

func _init() -> void:
    call_deferred("_run")
