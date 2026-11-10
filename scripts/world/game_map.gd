class_name GameMap
extends Node2D

func spawn_position(_arrived_by_truck: bool = false) -> Vector2:
	return Vector2.ZERO

func camera_bounds() -> Rect2:
	return Rect2()

func map_size() -> Vector2i:
	return Vector2i.ZERO

func _fill_collision(
	static_collision: StaticBody2D,
	node_name: String,
	footprint: Rect2,
) -> void:
	var collision := static_collision.get_node(node_name) as CollisionPolygon2D
	collision.polygon = WorldMath.footprint_to_polygon(footprint)

func _fill_perimeters(
	static_collision: StaticBody2D,
	size: Vector2i,
) -> void:
	var perimeter_names := ["PerimeterTop", "PerimeterRight", "PerimeterBottom", "PerimeterLeft"]
	var perimeter_rects := WorldContract.perimeter_footprints(size)
	for index in perimeter_rects.size():
		_fill_collision(static_collision, perimeter_names[index], perimeter_rects[index])
