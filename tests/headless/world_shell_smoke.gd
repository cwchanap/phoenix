extends SceneTree

const DEFAULT_TILE := Vector2i(0, 0)
const FARM_TILE := Vector2i(1, 0)
const PATH_TILE := Vector2i(2, 0)
const EXPECTED_ASSETS := {
    "proof-tiles": Vector2i(192, 32),
    "proof-player": Vector2i(128, 48),
    "proof-scenery": Vector2i(288, 96),
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

func _expected_tile(cell: Vector2i) -> Vector2i:
    if cell.x >= 3 and cell.x <= 9 and cell.y == 6:
        return PATH_TILE
    if cell.x >= 2 and cell.x <= 4 and cell.y >= 7 and cell.y <= 9:
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

    if not _expect_names(world, ["Ground", "StaticCollision", "Entities"], "World"):
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

    var static_collision := world.get_node("StaticCollision") as StaticBody2D
    var collision_names := [
        "TreeCollision",
        "BuildingCollision",
        "PerimeterTop",
        "PerimeterRight",
        "PerimeterBottom",
        "PerimeterLeft",
    ]
    if not _expect_names(static_collision, collision_names, "StaticCollision"):
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
    var map_size := Vector2(WorldContract.MAP_SIZE)
    var perimeter_rects := [
        Rect2(0.0, -1.0, map_size.x, 1.0),
        Rect2(map_size.x, 0.0, 1.0, map_size.y),
        Rect2(0.0, map_size.y, map_size.x, 1.0),
        Rect2(-1.0, 0.0, 1.0, map_size.y),
    ]
    for index in perimeter_rects.size():
        var collision := static_collision.get_node(collision_names[index + 2]) as CollisionPolygon2D
        if not _expect_polygon(
            collision.polygon,
            WorldMath.footprint_to_polygon(perimeter_rects[index]),
            "%s collision" % collision.name,
        ):
            return

    var entities := world.get_node("Entities") as Node2D
    if not _expect(entities.y_sort_enabled, "Entities must enable y-sort"):
        return
    if not _expect_names(entities, ["Tree", "Building"], "Entities"):
        return
    var scenery_texture_path := "res://assets/sprites/proof-scenery.png"
    var tree := entities.get_node("Tree") as Node2D
    var building := entities.get_node("Building") as Node2D
    if not _expect_vec2(tree.position, WorldContract.TREE_ANCHOR, "tree anchor"):
        return
    if not _expect_vec2(building.position, WorldContract.BUILDING_ANCHOR, "building anchor"):
        return
    for entry in [
        {"node": tree, "frame": 0, "label": "tree"},
        {"node": building, "frame": 1, "label": "building"},
    ]:
        var entity: Node2D = entry.node
        if not _expect_names(entity, ["Sprite2D"], "%s entity" % entry.label):
            return
        var sprite := entity.get_node("Sprite2D") as Sprite2D
        if not _expect(
            sprite.texture.resource_path == scenery_texture_path, "%s texture" % entry.label
        ):
            return
        if not _expect(sprite.hframes == 3, "%s scenery frame columns" % entry.label):
            return
        if not _expect(sprite.frame == entry.frame, "%s scenery frame" % entry.label):
            return
        if not _expect_vec2(
            sprite.offset, Vector2(0.0, -48.0), "%s bottom-center offset" % entry.label
        ):
            return

    for asset in EXPECTED_ASSETS:
        var texture := load("res://assets/sprites/%s.png" % asset) as Texture2D
        if not _expect(texture != null, "%s must import" % asset):
            return
        if not _expect(
            Vector2i(texture.get_width(), texture.get_height()) == EXPECTED_ASSETS[asset],
            "%s dimensions" % asset,
        ):
            return

    print("world shell smoke passed: 144 cells, alignment, anchors, collisions, assets")
    quit(0)

func _init() -> void:
    call_deferred("_run")
