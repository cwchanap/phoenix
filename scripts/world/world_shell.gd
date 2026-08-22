class_name WorldShell
extends Node2D

const PERIMETER_BAND_WIDTH := 1.0

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
    tree_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.TREE_FOOTPRINT)
    building_collision.polygon = WorldMath.footprint_to_polygon(WorldContract.BUILDING_FOOTPRINT)

    var perimeter_names := ["PerimeterTop", "PerimeterRight", "PerimeterBottom", "PerimeterLeft"]
    var perimeter_rects := perimeter_footprints()
    for index in perimeter_rects.size():
        var perimeter := static_collision.get_node(perimeter_names[index]) as CollisionPolygon2D
        perimeter.polygon = WorldMath.footprint_to_polygon(perimeter_rects[index])
