class_name WorldContract
extends RefCounted

const MAP_SIZE := Vector2i(24, 20)
const TILE_SIZE := Vector2(64.0, 32.0)
const PROJECTION_ORIGIN := Vector2(768.0, 0.0)
const PLAYER_SPAWN := Vector2(11.5, 8.5)
const PLAYER_HALF_EXTENT := 0.18
const MOVE_SPEED := 96.0
const HOUSE_FOOTPRINT := Rect2(11.0, 4.5, 2.75, 2.75)
const SHOP_CELL := Vector2i(17, 9)
const SHOP_STALL_FOOTPRINT := Rect2(15.0, 7.0, 1.0, 2.0)
const BED_CELL := Vector2i(12, 7)
const SHIPPING_CELL := Vector2i(10, 13)
const SHIPPING_FOOTPRINT := Rect2(10.2, 13.2, 0.6, 0.6)
const MARKET_CELL := Vector2i(19, 10)
const MARKET_FOOTPRINT := Rect2(19.2, 10.2, 0.6, 0.6)
const MARKET_ANCHOR := Vector2(1056.0, 480.0)
const FOREST_FOOTPRINT := Rect2(0.0, 0.0, 24.0, 2.0)
const RIVER_WEST_FOOTPRINT := Rect2(0.0, 0.0, 2.0, 20.0)
const RIVER_SOUTH_FOOTPRINT := Rect2(0.0, 18.0, 12.0, 2.0)
const WORKBENCH_CELL := Vector2i(13, 16)
const WORKBENCH_FOOTPRINT := Rect2(13.25, 16.25, 0.5, 0.5)
const VILLAGE_SIGN_CELL := Vector2i(21, 8)
const TRUCK_CELL := Vector2i(22, 9)
const TRUCK_ARRIVAL := Vector2i(21, 10)
# One world (art) pixel draws as CAMERA_ZOOM screen pixels on the 1920x1080
# canvas, so the camera still frames a 640x360 world view. A higher-res art
# set changes only this value.
const CAMERA_ZOOM := 3.0
const CAMERA_TOP_PADDING := 96.0
const CAMERA_BOUNDS := Rect2(128.0, -96.0, 1408.0, 800.0)

const FARM_PATCH := Rect2i(4, 10, 6, 5)

const PERIMETER_BAND_WIDTH := 1.0

static func perimeter_footprints(map_size: Vector2i) -> Array[Rect2]:
    var size := Vector2(map_size)
    return [
        Rect2(0.0, -PERIMETER_BAND_WIDTH, size.x, PERIMETER_BAND_WIDTH),
        Rect2(size.x, 0.0, PERIMETER_BAND_WIDTH, size.y),
        Rect2(0.0, size.y, size.x, PERIMETER_BAND_WIDTH),
        Rect2(-PERIMETER_BAND_WIDTH, 0.0, PERIMETER_BAND_WIDTH, size.y),
    ]

static func farm_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for y in range(FARM_PATCH.position.y, FARM_PATCH.end.y):
        for x in range(FARM_PATCH.position.x, FARM_PATCH.end.x):
            cells.append(Vector2i(x, y))
    return cells
