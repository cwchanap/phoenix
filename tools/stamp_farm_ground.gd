extends SceneTree
## Deterministic ground authoring for the authored maps. Run headless:
##   godot --headless --path . --script res://tools/stamp_farm_ground.gd
## One writer for the town phase layers and the farm's 35-source TileSet plus
## its 48x40 Ground/Backdrop cells, so source IDs and committed cells cannot
## drift. HPA-863's runtime never imports the layout or runs this selection.

const GROUND_DIR := "res://assets/sprites/world-v2/ground/"
const TOWN_TILESET_PATH := "res://scenes/world/town_tileset.tres"
const TOWN_MAP_PATH := "res://scenes/world/town_map.tscn"
const TOWN_SOURCES: Array[String] = ["grass", "paving", "road"]
const TOWN_LAYERS: Array[String] = ["Backdrop", "Ground"]

const FARM_TILESET_PATH := "res://scenes/world/terrain_tileset.tres"
const FARM_MAP_PATH := "res://scenes/world/farm_map.tscn"
const FARM_LAYERS: Array[String] = ["Backdrop", "Ground"]
# The source_id order is the manifest: 11 four-phase materials, 23 two-material
# transition sheets, then the indexed multi-junction atlas. Never reorder.
const FARM_MATERIALS: Array[String] = [
	"dirt", "fallow", "forest", "grass", "gravel", "paddy", "reeds", "road", "soil", "water", "yard"
]
const FARM_TRANSITIONS: Array[String] = [
	"dirt-to-gravel",
	"dirt-to-yard",
	"forest-to-reeds",
	"grass-to-dirt",
	"grass-to-fallow",
	"grass-to-forest",
	"grass-to-gravel",
	"grass-to-paddy",
	"grass-to-reeds",
	"grass-to-road",
	"grass-to-soil",
	"grass-to-water",
	"grass-to-yard",
	"paving-to-grass",
	"paving-to-road",
	"road-to-forest",
	"road-to-gravel",
	"road-to-paddy",
	"water-to-dirt",
	"water-to-forest",
	"water-to-reeds",
	"water-to-yard",
	"yard-to-gravel",
]
const FARM_MULTI_PATH := GROUND_DIR + "multi-junctions.png"
const FARM_MULTI_INDEX := GROUND_DIR + "multi-junctions.json"
const FARM_CORNERS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)
]
# The layout names areas by use; the supplied ground sheets are per material.
const FARM_ALIASES := {
	"bamboo": "grass", "field": "soil", "lot": "yard", "path": "dirt", "pier": "dirt"
}

var _failed := false
static var _multi_entries: Array = []


func _initialize() -> void:
	_stamp_town()
	if _failed:
		quit(1)
		return
	_stamp_farm()
	if _failed:
		quit(1)
		return
	print("stamp_farm_ground: town and farm tilesets and cells stamped")
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
	var text := FileAccess.get_file_as_string(TOWN_MAP_PATH)
	var tileset_id := _resource_id(text, TOWN_TILESET_PATH)
	if tileset_id == "":
		_fail("%s must declare %s" % [TOWN_MAP_PATH, TOWN_TILESET_PATH])
		return
	var scene := load(TOWN_MAP_PATH) as PackedScene
	if scene == null:
		_fail("cannot load %s" % TOWN_MAP_PATH)
		return
	var map := scene.instantiate()
	for layer_name in TOWN_LAYERS:
		if map.get_node_or_null(layer_name) as TileMapLayer == null:
			map.free()
			_fail("%s missing TileMapLayer %s" % [TOWN_MAP_PATH, layer_name])
			return
	_write(TOWN_TILESET_PATH, _town_tileset_text())
	if _failed:
		map.free()
		return
	var tileset := ResourceLoader.load(
		TOWN_TILESET_PATH, "TileSet", ResourceLoader.CACHE_MODE_IGNORE
	) as TileSet
	if tileset == null:
		map.free()
		_fail("cannot load %s" % TOWN_TILESET_PATH)
		return
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

## HPA-863 farm manifest: 35 ordered atlas sources. IDs are the array indexes,
## so the TileSet and every stamped cell shift together or the drift smoke fails.
static func farm_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for material in FARM_MATERIALS:
		sources.append({
			"path": GROUND_DIR + material + "-phases.png",
			"tiles": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		})
	for transition in FARM_TRANSITIONS:
		var tiles: Array[Vector2i] = []
		for mask in 16:
			for phase in 4:
				tiles.append(Vector2i(mask, phase))
		sources.append({"path": GROUND_DIR + transition + ".png", "tiles": tiles})
	var multi_tiles: Array[Vector2i] = []
	for entry in multi_entries():
		var atlas: Array = entry["atlas_cell"]
		multi_tiles.append(Vector2i(atlas[0], atlas[1]))
	sources.append({"path": FARM_MULTI_PATH, "tiles": multi_tiles})
	return sources

static func multi_entries() -> Array:
	if not _multi_entries.is_empty():
		return _multi_entries
	if not FileAccess.file_exists(FARM_MULTI_INDEX):
		push_error("stamp_farm_ground: missing " + FARM_MULTI_INDEX)
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FARM_MULTI_INDEX))
	if not (parsed is Dictionary and parsed.has("entries")):
		push_error("stamp_farm_ground: cannot parse " + FARM_MULTI_INDEX)
		return []
	_multi_entries = parsed["entries"]
	return _multi_entries

## One pure selector for both authored layers. Each corner takes its vertex
## majority (alphabetic ties), then the cell picks the supplied material phase,
## two-material transition mask, or indexed three-material junction for its
## exact corner tuple and parity.
static func tile_for(cell: Vector2i) -> Vector3i:
	var corners: Array[String] = []
	var distinct := {}
	for corner in FARM_CORNERS:
		var material := _vertex_material(cell + corner)
		corners.append(material)
		distinct[material] = true
	var parity := Vector2i(posmod(cell.x, 2), posmod(cell.y, 2))
	var phase: int = parity.x + 2 * parity.y
	if distinct.size() == 1:
		return Vector3i(FARM_MATERIALS.find(corners[0]), phase, 0)
	if distinct.size() == 2:
		var materials: Array = distinct.keys()
		var sheet := _transition_sheet(materials[0], materials[1])
		if sheet.is_empty():
			return Vector3i(-1, -1, -1)
		var mask := 0
		for bit in 4:
			if corners[bit] == sheet["b"]:
				mask |= 1 << bit
		return Vector3i(
			FARM_MATERIALS.size() + int(sheet["index"]), mask, phase
		)
	var entry := _multi_entry(corners, parity)
	if entry.is_empty():
		return Vector3i(-1, -1, -1)
	var atlas: Array = entry["atlas_cell"]
	return Vector3i(FARM_MATERIALS.size() + FARM_TRANSITIONS.size(), atlas[0], atlas[1])

static func _vertex_material(vertex: Vector2i) -> String:
	var counts := {}
	for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
		var raw := WorldContract.material_at(vertex + offset)
		var material: String = FARM_ALIASES.get(raw, raw)
		counts[material] = int(counts.get(material, 0)) + 1
	var best := ""
	var best_count := 0
	for material in counts:
		var count: int = counts[material]
		if count > best_count or (count == best_count and material < best):
			best = material
			best_count = count
	return best

static func _transition_sheet(a: String, b: String) -> Dictionary:
	for index in FARM_TRANSITIONS.size():
		var parts := FARM_TRANSITIONS[index].split("-to-")
		if (parts[0] == a and parts[1] == b) or (parts[0] == b and parts[1] == a):
			return {"index": index, "b": parts[1]}
	return {}

static func _multi_entry(corners: Array[String], phase: Vector2i) -> Dictionary:
	for entry in multi_entries():
		var entry_phase: Array = entry["phase"]
		if entry_phase[0] != phase.x or entry_phase[1] != phase.y:
			continue
		var entry_corners: Array = entry["corners"]
		var matches := true
		for bit in 4:
			if entry_corners[bit] != corners[bit]:
				matches = false
				break
		if matches:
			return entry
	return {}

static func farm_tileset_text() -> String:
	var sources := farm_sources()
	var ext := PackedStringArray()
	var sub := PackedStringArray()
	var refs := PackedStringArray()
	for id in sources.size():
		ext.append(
			'[ext_resource type="Texture2D" path="%s" id="t%d"]' % [sources[id]["path"], id]
		)
		sub.append('[sub_resource type="TileSetAtlasSource" id="farm_%d"]' % id)
		sub.append('texture = ExtResource("t%d")' % id)
		sub.append("texture_region_size = Vector2i(64, 32)")
		for tile in sources[id]["tiles"]:
			sub.append("%d:%d/0 = 0" % [tile.x, tile.y])
		sub.append("")
		refs.append('sources/%d = SubResource("farm_%d")' % [id, id])
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
			"\n".join(refs),
			"",
		])
	)

func _stamp_farm() -> void:
	if multi_entries().is_empty():
		_fail("cannot read the multi-junction index " + FARM_MULTI_INDEX)
		return
	var layers := {
		"Backdrop": WorldMath.backdrop_cells(
			WorldMath.map_camera_bounds(WorldContract.MAP_SIZE),
			WorldContract.MAP_SIZE,
		),
		"Ground": _farm_cells(),
	}
	# Resolve every cell before touching either authored file, so a missing
	# transition or junction can never leave the TileSet and scene out of step.
	for layer_name in FARM_LAYERS:
		for cell in layers[layer_name]:
			if tile_for(cell).x < 0:
				_fail("no farm tile resolves for %s in %s" % [cell, layer_name])
				return
	_write(FARM_TILESET_PATH, farm_tileset_text())
	if _failed:
		return
	var tileset := ResourceLoader.load(
		FARM_TILESET_PATH, "TileSet", ResourceLoader.CACHE_MODE_IGNORE
	) as TileSet
	if tileset == null:
		_fail("cannot load %s" % FARM_TILESET_PATH)
		return
	var map := (load(FARM_MAP_PATH) as PackedScene).instantiate()
	var layer_data := {}
	for layer_name in FARM_LAYERS:
		var layer := map.get_node(layer_name) as TileMapLayer
		layer.tile_set = tileset
		layer.clear()
		for cell in layers[layer_name]:
			var tile := tile_for(cell)
			layer.set_cell(cell, tile.x, Vector2i(tile.y, tile.z))
		layer_data[layer_name] = layer.tile_map_data
	map.free()
	var text := FileAccess.get_file_as_string(FARM_MAP_PATH)
	var tileset_id := _resource_id(text, FARM_TILESET_PATH)
	if tileset_id == "":
		_fail("%s must declare %s" % [FARM_MAP_PATH, FARM_TILESET_PATH])
		return
	_write(FARM_MAP_PATH, _drop_unused_ext_resources(_patch_layers(text, layer_data, tileset_id)))

func _farm_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in WorldContract.MAP_SIZE.y:
		for x in WorldContract.MAP_SIZE.x:
			cells.append(Vector2i(x, y))
	return cells

func _resource_id(text: String, path: String) -> String:
	var path_re := RegEx.new()
	path_re.compile('\\bpath="([^"]+)"')
	var id_re := RegEx.new()
	id_re.compile('\\bid="([^"]+)"')
	for line in text.split("\n"):
		if not line.begins_with("[ext_resource "):
			continue
		var path_match := path_re.search(line)
		var id_match := id_re.search(line)
		if path_match != null and id_match != null and path_match.get_string(1) == path:
			return id_match.get_string(1)
	return ""

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
