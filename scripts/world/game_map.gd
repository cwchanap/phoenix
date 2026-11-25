class_name GameMap
extends Node2D

func spawn_position(_arrived_by_truck: bool = false) -> Vector2:
	return Vector2.ZERO

func camera_bounds() -> Rect2:
	return Rect2()

func map_size() -> Vector2i:
	return Vector2i.ZERO

func _install_sort_proxies(entities: Node2D, occluders: Dictionary) -> void:
	for prop_name in occluders:
		var prop := entities.get_node_or_null(prop_name) as Node2D
		if prop == null or prop.get_parent() != entities:
			continue
		var proxy := Node2D.new()
		proxy.name = "%sSortProxy" % prop_name
		var child_index := prop.get_index()
		var prop_position := prop.position
		entities.remove_child(prop)
		entities.add_child(proxy)
		entities.move_child(proxy, child_index)
		proxy.add_child(prop)
		proxy.position = prop_position
		prop.position = Vector2.ZERO

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

func _add_collisions(
	body: StaticBody2D,
	rects: Array[Rect2],
	prefix := "Collision",
) -> void:
	for index in rects.size():
		var collision := CollisionPolygon2D.new()
		collision.name = "%s%d" % [prefix, index]
		collision.polygon = WorldMath.footprint_to_polygon(rects[index])
		body.add_child(collision)
