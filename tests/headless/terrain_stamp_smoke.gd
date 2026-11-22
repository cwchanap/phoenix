extends SceneTree
## HPA-863 drift gate: the committed farm TileSet and both authored tile layers
## must equal what tools/stamp_farm_ground.gd derives from the contract today.
## Run headless: godot --headless --path . --script res://tests/headless/terrain_stamp_smoke.gd
## This never writes: a contract or selector edit without a restamp fails here.

const TILESET_PATH := "res://scenes/world/terrain_tileset.tres"
const MAP_PATH := "res://scenes/world/farm_map.tscn"
const SOURCE_COUNT := 35
const TILE_COUNT := 1542
const GROUND_CELLS := 1920
const Stamper := preload("res://tools/stamp_farm_ground.gd")

var _failed := false

func _initialize() -> void:
	_check_tileset()
	_check_layers()
	_check_fixtures()
	if _failed:
		quit(1)
		return
	print(
		"terrain_stamp_smoke: %d sources / %d tiles, %d ground + backdrop cells match tile_for"
		% [SOURCE_COUNT, TILE_COUNT, GROUND_CELLS]
	)
	quit(0)

func _check_tileset() -> void:
	var tileset := ResourceLoader.load(
		TILESET_PATH, "TileSet", ResourceLoader.CACHE_MODE_IGNORE
	) as TileSet
	if not _expect(tileset != null, "%s must load" % TILESET_PATH):
		return
	var sources: Array[Dictionary] = Stamper.farm_sources()
	if not _expect(
		sources.size() == SOURCE_COUNT, "manifest must hold %d sources" % SOURCE_COUNT
	):
		return
	if not _expect(
		tileset.get_source_count() == SOURCE_COUNT, "TileSet must hold %d sources" % SOURCE_COUNT
	):
		return
	_expect(tileset.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC, "TileSet must stay isometric")
	_expect(
		tileset.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN,
		"TileSet must keep the diamond-down layout",
	)
	_expect(tileset.tile_size == Vector2i(64, 32), "TileSet must keep 64x32 cells")
	var total := 0
	for id in SOURCE_COUNT:
		var source := tileset.get_source(id) as TileSetAtlasSource
		if not _expect(source != null, "source %d must be a TileSetAtlasSource" % id):
			continue
		total += source.get_tiles_count()
		_expect(
			source.texture != null and source.texture.resource_path == sources[id]["path"],
			"source %d texture must be %s" % [id, sources[id]["path"]],
		)
		var tiles: Array = sources[id]["tiles"]
		_expect(
			source.get_tiles_count() == tiles.size(),
			"source %d must hold %d tiles" % [id, tiles.size()],
		)
		for tile in tiles:
			_expect(source.has_tile(tile), "source %d is missing tile %s" % [id, tile])
	_expect(total == TILE_COUNT, "TileSet must hold %d tiles, got %d" % [TILE_COUNT, total])

func _check_layers() -> void:
	var scene := load(MAP_PATH) as PackedScene
	if not _expect(scene != null, "%s must load" % MAP_PATH):
		return
	var map := scene.instantiate()
	var ground := map.get_node_or_null("Ground") as TileMapLayer
	var backdrop := map.get_node_or_null("Backdrop") as TileMapLayer
	if not _expect(ground != null and backdrop != null, "farm Ground and Backdrop must exist"):
		map.free()
		return
	_expect(
		ground.tile_set != null and ground.tile_set.resource_path == TILESET_PATH,
		"Ground must use the stamped TileSet",
	)
	_expect(
		backdrop.tile_set != null and backdrop.tile_set.resource_path == TILESET_PATH,
		"Backdrop must use the stamped TileSet",
	)
	_expect(
		ground.get_used_cells().size() == GROUND_CELLS,
		"Ground must paint exactly %d cells" % GROUND_CELLS,
	)
	for y in WorldContract.MAP_SIZE.y:
		for x in WorldContract.MAP_SIZE.x:
			_check_tile(ground, Vector2i(x, y))
	var cells: Array[Vector2i] = WorldMath.backdrop_cells(
		WorldMath.map_camera_bounds(WorldContract.MAP_SIZE),
		WorldContract.MAP_SIZE,
	)
	_expect(
		backdrop.get_used_cells().size() == cells.size(),
		"Backdrop must paint exactly %d camera-overdraw cells" % cells.size(),
	)
	for cell in cells:
		_check_tile(backdrop, cell)
	map.free()

func _check_tile(layer: TileMapLayer, cell: Vector2i) -> void:
	var expected := Stamper.tile_for(cell)
	if not _expect(expected.x >= 0, "tile_for(%s) must resolve a source" % cell):
		return
	_expect(
		layer.get_cell_source_id(cell) == expected.x,
		"%s must use source %d" % [cell, expected.x],
	)
	_expect(
		layer.get_cell_atlas_coords(cell) == Vector2i(expected.y, expected.z),
		"%s must use atlas %s" % [cell, Vector2i(expected.y, expected.z)],
	)
	_expect(
		layer.get_cell_alternative_tile(cell) == 0,
		"%s must not carry Godot flip/transpose flags" % cell,
	)

## Independent anchors for the north river, road/paddy, pier and the
## three-material junctions, so a shared bug in tile_for cannot satisfy this
## smoke by comparing it with itself.
func _check_fixtures() -> void:
	var fixtures := [
		{
			"cell": Vector2i(1, 0),
			"material": "water",
			"blocked": true,
			"source": 30,
			"atlas": Vector2i(5, 1),
			"label": "north river",
		},
		{
			"cell": Vector2i(42, 0),
			"material": "road",
			"blocked": false,
			"source": 26,
			"atlas": Vector2i(5, 0),
			"label": "road reopening the forest",
		},
		{
			"cell": Vector2i(43, 2),
			"material": "road",
			"blocked": false,
			"source": 28,
			"atlas": Vector2i(10, 1),
			"label": "road/paddy edge",
		},
		{
			"cell": Vector2i(44, 0),
			"material": "paddy",
			"blocked": true,
			"source": 5,
			"atlas": Vector2i(0, 0),
			"label": "rice paddy",
		},
		{
			"cell": Vector2i(23, 35),
			"material": "pier",
			"blocked": false,
			"source": 29,
			"atlas": Vector2i(11, 3),
			"label": "pier reopening the water",
		},
		{
			"cell": Vector2i(24, 35),
			"material": "pier",
			"blocked": false,
			"source": 29,
			"atlas": Vector2i(7, 2),
			"label": "pier east cell",
		},
		{
			"cell": Vector2i(3, 4),
			"material": "bamboo",
			"blocked": true,
			"source": 34,
			"atlas": Vector2i(3, 1),
			"label": "three-material forest/water/bamboo corner",
		},
		{
			"cell": Vector2i(41, 5),
			"material": "grass",
			"blocked": false,
			"source": 34,
			"atlas": Vector2i(5, 0),
			"label": "three-material forest/road/grass corner",
		},
		{
			"cell": Vector2i(15, 19),
			"material": "field",
			"blocked": false,
			"source": 21,
			"atlas": Vector2i(8, 3),
			"label": "field edge",
		},
		{
			"cell": Vector2i(7, 7),
			"material": "path",
			"blocked": false,
			"source": 0,
			"atlas": Vector2i(3, 0),
			"label": "one-cell shrine path",
		},
	]
	for fixture in fixtures:
		var cell: Vector2i = fixture["cell"]
		_expect(
			WorldContract.material_at(cell) == fixture["material"],
			"%s material at %s" % [fixture["label"], cell],
		)
		_expect(
			WorldContract.blocks_movement(cell) == fixture["blocked"],
			"%s blocking at %s" % [fixture["label"], cell],
		)
		var tile := Stamper.tile_for(cell)
		_expect(
			tile == Vector3i(fixture["source"], fixture["atlas"].x, fixture["atlas"].y),
			"%s tile at %s must be %s" % [fixture["label"], cell, fixture["atlas"]],
		)
	for cell in [
		Vector2i(42, 0),
		Vector2i(43, 0),
		Vector2i(42, 1),
		Vector2i(43, 1),
		Vector2i(42, 2),
		Vector2i(43, 2),
		Vector2i(23, 35),
		Vector2i(24, 35),
	]:
		_expect(
			not WorldContract.blocks_movement(cell),
			"%s must stay open (road x42..43/y0..2, pier x23..24/y35)" % cell,
		)
	# Phase is part of the junction identity: the indexed forest/road/grass tile
	# exists only at phase (1,1). Moving the forest rect down one cell would put
	# the same corner materials on a (1,0) cell; it must reject, not reuse art.
	var junction_corners: Array[String] = ["forest", "road", "grass", "grass"]
	_expect(
		Stamper._multi_entry(junction_corners, Vector2i(1, 0)).is_empty(),
		"phase-(1,0) forest/road/grass junction must be rejected",
	)
	_expect(
		not Stamper._multi_entry(junction_corners, Vector2i(1, 1)).is_empty(),
		"phase-(1,1) forest/road/grass junction must resolve",
	)
	# Clamp-to-edge overdraw: no invented shore on the north river and no grass
	# rim around the paddy row. The negative cell also proves posmod phases.
	_expect(
		WorldContract.material_at(Vector2i(1, -1)) == WorldContract.material_at(Vector2i(1, 0)),
		"north overdraw must clamp to the edge water, not grass",
	)
	_expect(
		WorldContract.material_at(Vector2i(48, 0)) == WorldContract.material_at(Vector2i(47, 0)),
		"east overdraw must clamp to the edge paddy, not grass",
	)
	_expect(
		Stamper.tile_for(Vector2i(-1, -1)) == Vector3i(2, 3, 0),
		"negative overdraw must use the clamped forest phase 3",
	)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("terrain_stamp_smoke: " + message)
	_failed = true
	return false
