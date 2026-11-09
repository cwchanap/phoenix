extends SceneTree

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

func _cell_blocked(cell: Vector2i, footprints: Array) -> bool:
    var half := WorldContract.PLAYER_HALF_EXTENT
    var box := Rect2(
        Vector2(cell) + Vector2.ONE * (0.5 - half),
        Vector2.ONE * half * 2.0,
    )
    for footprint: Rect2 in footprints:
        if box.intersects(footprint):
            return true
    return false

func _flood_reachable(map_size: Vector2i, start: Vector2i, footprints: Array) -> Dictionary:
    var reached := {}
    if _cell_blocked(start, footprints):
        return reached
    var queue: Array[Vector2i] = [start]
    reached[start] = true
    while not queue.is_empty():
        var cell: Vector2i = queue.pop_back()
        for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
            var next: Vector2i = cell + direction
            if (
                next.x < 0
                or next.y < 0
                or next.x >= map_size.x
                or next.y >= map_size.y
            ):
                continue
            if reached.has(next) or _cell_blocked(next, footprints):
                continue
            reached[next] = true
            queue.append(next)
    return reached

func _expect_stand_reachable(reached: Dictionary, target: Vector2i, label: String) -> bool:
    for facing in WorldMath.TARGET_OFFSETS:
        if reached.has(target - WorldMath.TARGET_OFFSETS[facing]):
            return true
    return _expect(false, "%s: no reachable facing stand for %s" % [label, target])

func _init() -> void:
    if not _expect(WorldContract.MAP_SIZE == Vector2i(24, 20), "map size contract"):
        return
    if not _expect(WorldContract.TILE_SIZE == Vector2(64.0, 32.0), "tile size contract"):
        return
    if not _expect(WorldContract.PROJECTION_ORIGIN == Vector2(768.0, 0.0), "origin contract"):
        return
    if not _expect(WorldContract.PLAYER_SPAWN == Vector2(11.5, 8.5), "spawn contract"):
        return
    if not _expect(is_equal_approx(WorldContract.PLAYER_HALF_EXTENT, 0.18), "player extent contract"):
        return
    if not _expect(is_equal_approx(WorldContract.MOVE_SPEED, 96.0), "move speed contract"):
        return
    if not _expect(is_equal_approx(WorldContract.CAMERA_TOP_PADDING, 96.0), "camera padding contract"):
        return
    if not _expect(
        WorldContract.CAMERA_BOUNDS == Rect2(128.0, -96.0, 1408.0, 800.0), "camera bounds contract"
    ):
        return
    if not _expect(WorldContract.FARM_PATCH == Rect2i(4, 10, 6, 5), "farm patch contract"):
        return
    if not _expect(
        WorldContract.HOUSE_FOOTPRINT == Rect2(11.0, 4.5, 2.75, 2.75), "house footprint contract"
    ):
        return
    if not _expect(WorldContract.BED_CELL == Vector2i(12, 7), "bed cell contract"):
        return
    if not _expect(WorldContract.SHIPPING_CELL == Vector2i(10, 13), "shipping cell contract"):
        return
    if not _expect(
        WorldContract.SHIPPING_FOOTPRINT == Rect2(10.2, 13.2, 0.6, 0.6),
        "shipping footprint contract",
    ):
        return
    if not _expect(WorldContract.TRUCK_CELL == Vector2i(22, 9), "farm truck cell contract"):
        return
    if not _expect(
        WorldContract.TRUCK_ARRIVAL == Vector2i(21, 10), "farm truck arrival contract"
    ):
        return
    if not _expect(
        WorldContract.TRUCK_FOOTPRINT == Rect2(22.0, 9.0, 1.0, 1.0),
        "farm truck footprint contract",
    ):
        return
    if not _expect(TownContract.MAP_SIZE == Vector2i(16, 12), "town map size contract"):
        return
    if not _expect(TownContract.TRUCK_CELL == Vector2i(2, 9), "town truck cell contract"):
        return
    if not _expect(
        TownContract.TRUCK_ARRIVAL == Vector2i(3, 8), "town truck arrival contract"
    ):
        return
    if not _expect(
        TownContract.TRUCK_FOOTPRINT == Rect2(2.0, 9.0, 1.0, 1.0),
        "town truck footprint contract",
    ):
        return
    if not _expect(
        TownContract.STATION_FOOTPRINT == Rect2(1.85, 3.85, 1.3, 1.3),
        "station footprint contract",
    ):
        return
    if not _expect(
        TownContract.SHOP_FOOTPRINT == Rect2(6.85, 2.85, 1.3, 1.3),
        "town shop footprint contract",
    ):
        return
    if not _expect(
        TownContract.CAFE_FOOTPRINT == Rect2(10.85, 2.85, 1.3, 1.3),
        "cafe footprint contract",
    ):
        return
    if not _expect(
        TownContract.MARKET_FOOTPRINT == Rect2(12.85, 5.85, 1.3, 1.3),
        "town market footprint contract",
    ):
        return
    if not _expect(TownContract.SHOP_CELL == Vector2i(7, 4), "town shop cell contract"):
        return
    if not _expect(TownContract.MARKET_CELL == Vector2i(13, 7), "town market cell contract"):
        return
    if not _expect(
        TownContract.VILLAGER_CELLS == [Vector2i(9, 4), Vector2i(5, 7), Vector2i(11, 6)],
        "town villager cells contract",
    ):
        return
    if not _expect(
        TownContract.VILLAGER_FOOTPRINTS
        == [Rect2(9.2, 4.2, 0.6, 0.6), Rect2(5.2, 7.2, 0.6, 0.6), Rect2(11.2, 6.2, 0.6, 0.6)],
        "town villager footprints contract",
    ):
        return
    if not _expect(
        TownContract.villager_at(Vector2i(9, 4)) == VillagerRules.VillagerId.SHOPKEEPER
        and TownContract.villager_at(Vector2i(5, 7)) == VillagerRules.VillagerId.FARMER
        and TownContract.villager_at(Vector2i(11, 6)) == VillagerRules.VillagerId.RESIDENT
        and TownContract.villager_at(Vector2i(0, 0)) == -1,
        "town villager lookup",
    ):
        return
    if not _expect(
        TownContract.CAMERA_BOUNDS == Rect2(384.0, -96.0, 896.0, 544.0),
        "town camera bounds contract",
    ):
        return
    if not _expect(
        TownContract.CAMERA_BOUNDS == WorldMath.map_camera_bounds(TownContract.MAP_SIZE),
        "frozen town camera bounds must equal derived map camera bounds",
    ):
        return
    var expected_perimeter: Array[Rect2] = [
        Rect2(0.0, -1.0, 24.0, 1.0),
        Rect2(24.0, 0.0, 1.0, 20.0),
        Rect2(0.0, 20.0, 24.0, 1.0),
        Rect2(-1.0, 0.0, 1.0, 20.0),
    ]
    if not _expect(
        WorldContract.perimeter_footprints(WorldContract.MAP_SIZE) == expected_perimeter,
        "perimeter footprints contract",
    ):
        return
    var expected_town_perimeter: Array[Rect2] = [
        Rect2(0.0, -1.0, 16.0, 1.0),
        Rect2(16.0, 0.0, 1.0, 12.0),
        Rect2(0.0, 12.0, 16.0, 1.0),
        Rect2(-1.0, 0.0, 1.0, 12.0),
    ]
    if not _expect(
        WorldContract.perimeter_footprints(TownContract.MAP_SIZE) == expected_town_perimeter,
        "town perimeter footprints contract",
    ):
        return
    var farm_cells := WorldContract.farm_cells()
    if not _expect(farm_cells.size() == 30, "farm cell count"):
        return
    if not _expect_vec2i(farm_cells[0], Vector2i(4, 10), "first farm cell"):
        return
    if not _expect_vec2i(farm_cells[29], Vector2i(9, 14), "last farm cell"):
        return

    for point in [Vector2(0.0, 0.0), Vector2(11.5, 8.5), Vector2(24.0, 20.0)]:
        var projected := WorldMath.grid_to_world(point)
        var round_trip := WorldMath.world_to_grid(projected)
        if not _expect_vec2(round_trip, point, "fractional round trip %s" % point):
            return

    var edge_cases := [
        [Vector2(0.5, 0.5), Vector2i(0, 0)],
        [Vector2(23.999999, 19.999999), Vector2i(23, 19)],
        [Vector2(0.5, 10.5), Vector2i(0, 10)],
        [Vector2(23.5, 10.5), Vector2i(23, 10)],
        [Vector2(12.5, 0.5), Vector2i(12, 0)],
        [Vector2(12.5, 19.5), Vector2i(12, 19)],
    ]
    for edge_case in edge_cases:
        var cell := WorldMath.grid_cell_at_world(WorldMath.grid_to_world(edge_case[0]))
        if not _expect_vec2i(cell, edge_case[1], "map edge cell %s" % edge_case[0]):
            return

    var epsilon_below := WorldMath.grid_cell_at_world(
        WorldMath.grid_to_world(Vector2(0.999999, 4.5))
    )
    if not _expect_vec2i(epsilon_below, Vector2i(0, 4), "boundary epsilon below"):
        return
    var epsilon_inside := WorldMath.grid_cell_at_world(
        WorldMath.grid_to_world(Vector2(0.9999999995, 4.5))
    )
    if not _expect_vec2i(epsilon_inside, Vector2i(1, 4), "boundary epsilon inside"):
        return

    var diamond := WorldMath.cell_diamond(Vector2i(0, 0))
    if not _expect_polygon(
        diamond,
        PackedVector2Array([
            Vector2(768.0, 0.0),
            Vector2(800.0, 16.0),
            Vector2(768.0, 32.0),
            Vector2(736.0, 16.0),
        ]),
        "cell diamond",
    ):
        return

    if not _expect(
        WorldMath.facing_for_input(Vector2(0.0, -1.0), WorldMath.Facing.DOWN)
            == WorldMath.Facing.UP,
        "up facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2(1.0, 1.0), WorldMath.Facing.UP)
            == WorldMath.Facing.RIGHT,
        "horizontal tie facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2(-1.0, -1.0), WorldMath.Facing.DOWN)
            == WorldMath.Facing.LEFT,
        "negative horizontal tie facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2(0.0, 1.0), WorldMath.Facing.UP)
            == WorldMath.Facing.DOWN,
        "down facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2(-1.0, 0.0), WorldMath.Facing.RIGHT)
            == WorldMath.Facing.LEFT,
        "left facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2.ZERO, WorldMath.Facing.UP) == WorldMath.Facing.UP,
        "idle facing retention",
    ):
        return

    var player := Vector2(5.5, 5.5)
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.UP, WorldContract.MAP_SIZE) == Vector2i(4, 4),
        "up target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.RIGHT, WorldContract.MAP_SIZE) == Vector2i(6, 4),
        "right target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.DOWN, WorldContract.MAP_SIZE) == Vector2i(6, 6),
        "down target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.LEFT, WorldContract.MAP_SIZE) == Vector2i(4, 6),
        "left target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(0.25, 0.25), WorldMath.Facing.UP, WorldContract.MAP_SIZE) == null,
        "off-map target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(23.75, 19.75), WorldMath.Facing.DOWN, WorldContract.MAP_SIZE) == null,
        "expanded off-map corner target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(22.5, 17.5), WorldMath.Facing.DOWN, WorldContract.MAP_SIZE) == Vector2i(23, 18),
        "expanded in-bounds south-east target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(22.5, 17.5), WorldMath.Facing.DOWN, TownContract.MAP_SIZE) == null,
        "same position is off the smaller town map",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(14.5, 10.5), WorldMath.Facing.DOWN, TownContract.MAP_SIZE) == Vector2i(15, 11),
        "town in-bounds south-east target",
    ):
        return

    if not _expect_polygon(
        WorldMath.footprint_to_polygon(WorldContract.HOUSE_FOOTPRINT),
        PackedVector2Array([
            Vector2(976.0, 248.0),
            Vector2(1064.0, 292.0),
            Vector2(976.0, 336.0),
            Vector2(888.0, 292.0),
        ]),
        "house footprint polygon",
    ):
        return
    if not _expect_polygon(
        WorldMath.centered_player_footprint_polygon(WorldContract.PLAYER_SPAWN),
        PackedVector2Array([
            Vector2(864.0, 314.24),
            Vector2(875.52, 320.0),
            Vector2(864.0, 325.76),
            Vector2(852.48, 320.0),
        ]),
        "centered player footprint polygon",
    ):
        return

    if not _expect(
        WorldContract.CAMERA_BOUNDS == WorldMath.map_camera_bounds(WorldContract.MAP_SIZE),
        "frozen camera bounds must equal derived map camera bounds",
    ):
        return
    if not _expect(
        WorldMath.map_camera_bounds(TownContract.MAP_SIZE) == Rect2(384.0, -96.0, 896.0, 544.0),
        "town camera bounds derive from the 16x12 map",
    ):
        return
    if not _expect_vec2(
        WorldMath.footprint_ground_anchor(WorldContract.HOUSE_FOOTPRINT),
        Vector2(976.0, 336.0),
        "derived house ground anchor",
    ):
        return

    var farm_blockers: Array = [
        WorldContract.HOUSE_FOOTPRINT,
        WorldContract.FOREST_FOOTPRINT,
        WorldContract.RIVER_WEST_FOOTPRINT,
        WorldContract.RIVER_SOUTH_FOOTPRINT,
        WorldContract.WORKBENCH_FOOTPRINT,
        WorldContract.SHIPPING_FOOTPRINT,
        WorldContract.TRUCK_FOOTPRINT,
    ]
    farm_blockers.append_array(WorldContract.perimeter_footprints(WorldContract.MAP_SIZE))
    var town_blockers: Array = [
        TownContract.STATION_FOOTPRINT,
        TownContract.SHOP_FOOTPRINT,
        TownContract.CAFE_FOOTPRINT,
        TownContract.MARKET_FOOTPRINT,
        TownContract.TRUCK_FOOTPRINT,
    ]
    town_blockers.append_array(TownContract.VILLAGER_FOOTPRINTS)
    town_blockers.append_array(WorldContract.perimeter_footprints(TownContract.MAP_SIZE))

    var spawn_cell := Vector2i(
        floori(WorldContract.PLAYER_SPAWN.x), floori(WorldContract.PLAYER_SPAWN.y)
    )
    if not _expect(not _cell_blocked(spawn_cell, farm_blockers), "farm spawn cell is collision-free"):
        return
    if not _expect(
        not _cell_blocked(WorldContract.TRUCK_ARRIVAL, farm_blockers),
        "farm truck arrival is collision-free",
    ):
        return
    if not _expect(
        not _cell_blocked(TownContract.TRUCK_ARRIVAL, town_blockers),
        "town truck arrival is collision-free",
    ):
        return

    var farm_reached := _flood_reachable(
        WorldContract.MAP_SIZE, WorldContract.TRUCK_ARRIVAL, farm_blockers
    )
    if not _expect(farm_reached.has(spawn_cell), "farm arrival reaches the house spawn cell"):
        return
    var farm_walkable := 0
    for y in WorldContract.MAP_SIZE.y:
        for x in WorldContract.MAP_SIZE.x:
            if not _cell_blocked(Vector2i(x, y), farm_blockers):
                farm_walkable += 1
    if not _expect(
        farm_reached.size() == farm_walkable,
        "farm flood reaches every walkable cell",
    ):
        return
    for target in [
        WorldContract.BED_CELL,
        WorldContract.SHIPPING_CELL,
        WorldContract.TRUCK_CELL,
    ]:
        if not _expect_stand_reachable(farm_reached, target, "farm target"):
            return

    var town_reached := _flood_reachable(
        TownContract.MAP_SIZE, TownContract.TRUCK_ARRIVAL, town_blockers
    )
    var town_walkable := 0
    for y in TownContract.MAP_SIZE.y:
        for x in TownContract.MAP_SIZE.x:
            if not _cell_blocked(Vector2i(x, y), town_blockers):
                town_walkable += 1
    if not _expect(
        town_reached.size() == town_walkable,
        "town flood reaches every walkable cell",
    ):
        return
    var town_targets: Array[Vector2i] = [
        TownContract.SHOP_CELL,
        TownContract.MARKET_CELL,
        TownContract.TRUCK_CELL,
    ]
    town_targets.append_array(TownContract.VILLAGER_CELLS)
    for target in town_targets:
        if not _expect_stand_reachable(town_reached, target, "town target"):
            return

    print("world math smoke passed")
    quit(0)
