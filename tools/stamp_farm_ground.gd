extends SceneTree
## Deterministic ground authoring for the authored maps. Run headless:
##   godot --headless --path . --script res://tools/stamp_farm_ground.gd
## HPA-863 task 1 covers the town phase branch only; the farm manifest and its
## 48x40 ground/backdrop stamping extend this same script in task 2 so the
## TileSet source IDs and the committed scene cell data can never drift.

const GROUND_DIR := "res://assets/sprites/world-v2/ground/"
const TOWN_TILESET_PATH := "res://scenes/world/town_tileset.tres"
const TOWN_MAP_PATH := "res://scenes/world/town_map.tscn"
const TOWN_SOURCES: Array[String] = ["grass", "paving", "road"]
const TOWN_LAYERS: Array[String] = ["Backdrop", "Ground"]

var _failed := false

func _initialize() -> void:
	_stamp_town()
	if _failed:
		quit(1)
		return
	print("stamp_farm_ground: town tileset and cells stamped")
	quit(0)

## Neighbouring logical cells share corners, so the four mirrored phases of a
## material sheet are chosen by the cell's parity.
static func phase(cell: Vector2i) -> int:
	return posmod(cell.x, 2) + 2 * posmod(cell.y, 2)

## Town Ground is paving except the authored road rows; the off-map Backdrop
## continues grass and the same road rows.
static func town_source_id(cell: Vector2i, backdrop: bool) -> int:
	if TownContract.is_backdrop_road(cell):
		return TOWN_SOURCES.find("road")
	return TOWN_SOURCES.find("grass" if backdrop else "paving")

func _stamp_town() -> void:
	_write(TOWN_TILESET_PATH, _town_tileset_text())
	if _failed:
		return
	var tileset := ResourceLoader.load(
		TOWN_TILESET_PATH, "TileSet", ResourceLoader.CACHE_MODE_IGNORE
	) as TileSet
	var map := (load(TOWN_MAP_PATH) as PackedScene).instantiate()
	var layer_data := {}
	for layer_name in TOWN_LAYERS:
		var layer := map.get_node(layer_name) as TileMapLayer
		var backdrop := layer_name == "Backdrop"
		layer.tile_set = tileset
		layer.clear()
		var cells: Array[Vector2i] = (
			WorldMath.backdrop_cells(TownContract.CAMERA_BOUNDS, TownContract.MAP_SIZE)
			if backdrop
			else _town_cells()
		)
		for cell in cells:
			layer.set_cell(cell, town_source_id(cell, backdrop), Vector2i(phase(cell), 0))
		layer_data[layer_name] = layer.tile_map_data
	map.free()

	var text := FileAccess.get_file_as_string(TOWN_MAP_PATH)
	var tileset_id := _resource_id(text, TOWN_TILESET_PATH)
	if tileset_id == "":
		_fail("%s must declare %s" % [TOWN_MAP_PATH, TOWN_TILESET_PATH])
		return
	_write(
		TOWN_MAP_PATH,
		_drop_unused_ext_resources(_patch_layers(text, layer_data, tileset_id)),
	)

func _town_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in TownContract.MAP_SIZE.y:
		for x in TownContract.MAP_SIZE.x:
			cells.append(Vector2i(x, y))
	return cells

func _town_tileset_text() -> String:
	var ext := PackedStringArray()
	var sub := PackedStringArray()
	var sources := PackedStringArray()
	for id in TOWN_SOURCES.size():
		ext.append(
			'[ext_resource type="Texture2D" path="%s%s-phases.png" id="t%d"]'
			% [GROUND_DIR, TOWN_SOURCES[id], id]
		)
		sub.append('[sub_resource type="TileSetAtlasSource" id="phase_%s"]' % TOWN_SOURCES[id])
		sub.append('texture = ExtResource("t%d")' % id)
		sub.append("texture_region_size = Vector2i(64, 32)")
		for tile in 4:
			sub.append("%d:0/0 = 0" % tile)
		sub.append("")
		sources.append('sources/%d = SubResource("phase_%s")' % [id, TOWN_SOURCES[id]])
	return "\n".join(
		PackedStringArray([
			'[gd_resource type="TileSet" format=3]',
			"",
			"\n".join(ext),
			"",
			"\n".join(sub),
			"[resource]",
			"tile_shape = 1",
			"tile_layout = 5",
			"tile_size = Vector2i(64, 32)",
			"\n".join(sources),
			"",
		])
	)

func _resource_id(text: String, path: String) -> String:
	var re := RegEx.new()
	re.compile('\\[ext_resource type="[^"]+" path="%s" id="([^"]+)"\\]' % path)
	var match := re.search(text)
	return match.get_string(1) if match != null else ""

## Replaces the two ground properties of each stamped layer in place so the
## scene diff stays cells-only instead of a full Godot re-save.
func _patch_layers(text: String, layer_data: Dictionary, tileset_id: String) -> String:
	var out := PackedStringArray()
	var block := PackedStringArray()
	var layer := ""
	for line in text.split("\n"):
		if line.begins_with("["):
			if layer != "":
				_flush_layer(out, block, layer, layer_data, tileset_id)
			block = PackedStringArray()
			layer = ""
			for name in layer_data:
				if line.begins_with('[node name="%s" ' % name):
					layer = name
			if layer == "":
				out.append(line)
			else:
				block.append(line)
			continue
		if layer == "":
			out.append(line)
		elif not (line.begins_with("tile_map_data = ") or line.begins_with("tile_set = ")):
			block.append(line)
	if layer != "":
		_flush_layer(out, block, layer, layer_data, tileset_id)
	return "\n".join(out)

func _flush_layer(
	out: PackedStringArray,
	block: PackedStringArray,
	layer: String,
	layer_data: Dictionary,
	tileset_id: String,
) -> void:
	# Trailing blank separator lines belong between nodes, after the cells.
	while block.size() > 1 and block[block.size() - 1].strip_edges() == "":
		block.remove_at(block.size() - 1)
	block.append('tile_map_data = PackedByteArray("%s")' % Marshalls.raw_to_base64(layer_data[layer]))
	block.append('tile_set = ExtResource("%s")' % tileset_id)
	block.append("")
	out.append_array(block)

func _drop_unused_ext_resources(text: String) -> String:
	var re := RegEx.new()
	re.compile('\\[ext_resource [^\\]]*id="([^"]+)"\\]')
	var out := PackedStringArray()
	for line in text.split("\n"):
		var match := re.search(line)
		if match == null or text.contains('ExtResource("%s")' % match.get_string(1)):
			out.append(line)
	return "\n".join(out)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("cannot write %s" % path)
		return
	file.store_string(text)

func _fail(message: String) -> void:
	push_error("stamp_farm_ground: " + message)
	_failed = true
