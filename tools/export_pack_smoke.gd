extends SceneTree
## Exported-pack gate: proves the shipped PCK carries the world resources and
## can load them with no working checkout on disk.
##   godot --headless --main-pack Phoenix.pck --script res://tools/export_pack_smoke.gd
## Run it from a directory that holds only the extracted PCK. tests/* is
## excluded from the export, so a loadable checkout-only path means the run
## silently fell back to the source tree instead of the pack.

const SCENES: Array[String] = [
	"res://scenes/app/app.tscn",
	"res://scenes/world/world.tscn",
	"res://scenes/world/farm_map.tscn",
	"res://scenes/world/town_map.tscn",
	"res://scenes/world/terrain_tileset.tres",
	"res://scenes/world/town_tileset.tres",
]
const TEXTURES := {
	"res://assets/sprites/world-v2/crops.png": Vector2i(128, 144),
	"res://assets/sprites/world-v2/soil.png": Vector2i(128, 32),
	"res://assets/sprites/world-v2/cutouts/shipping-bin.png": Vector2i(96, 96),
	"res://assets/sprites/world-v2/cutouts/station.png": Vector2i(96, 96),
	"res://assets/sprites/world-v2/cutouts/seed-shop.png": Vector2i(96, 96),
	"res://assets/sprites/world-v2/cutouts/cafe.png": Vector2i(96, 96),
	"res://assets/sprites/world-v2/cutouts/market.png": Vector2i(96, 96),
	"res://assets/sprites/world-v2/ground/grass-phases.png": Vector2i(256, 32),
	"res://assets/sprites/world-v2/ground/paving-phases.png": Vector2i(256, 32),
	"res://assets/sprites/world-v2/ground/road-phases.png": Vector2i(256, 32),
	"res://assets/sprites/world-v2/ground/soil-phases.png": Vector2i(256, 32),
	"res://assets/sprites/world-v2/ground/multi-junctions.png": Vector2i(1024, 64),
	"res://assets/sprites/world-v2/cutouts/farmhouse.png": Vector2i(224, 192),
	"res://assets/sprites/world-v2/cutouts/storehouse.png": Vector2i(320, 256),
	"res://assets/sprites/world-v2/cutouts/bamboo.png": Vector2i(96, 96),
	"res://assets/sprites/player-walk.png": Vector2i(128, 192),
	"res://assets/sprites/kei-truck.png": Vector2i(192, 96),
	"res://assets/sprites/villagers.png": Vector2i(96, 48),
	"res://assets/sprites/proof-shadow.png": Vector2i(16, 8),
}
const CHECKOUT_ONLY := "res://tests/headless/project_smoke.gd"
# Source provenance is .gdignore'd in the checkout and excluded from the
# export. Raw files (README/source sheets) are checked with FileAccess because
# ResourceLoader.exists never sees unimported files; imported paths are checked
# with ResourceLoader. Any packed entry beneath either folder is a failure.
const PROVENANCE_DIRS: Array[String] = [
	"res://assets/sprites/hpa-861-review",
	"res://assets/sprites/provenance",
]
const PROVENANCE_RAW: Array[String] = [
	"res://assets/sprites/hpa-861-review/farm-source.png",
	"res://assets/sprites/hpa-861-review/README.md",
	"res://assets/sprites/provenance/starting-farm-tiles-source.webp",
	"res://assets/sprites/provenance/starting-farm-props-source.webp",
	"res://assets/sprites/provenance/town-art-source.webp",
	"res://assets/sprites/provenance/town-art-cutouts.png",
	"res://assets/sprites/provenance/town-truck-views.png",
	"res://assets/sprites/provenance/town-art-source.md",
]
const PROVENANCE_IMPORTED: Array[String] = [
	"res://assets/sprites/hpa-861-review/farm-source.png",
	"res://assets/sprites/provenance/town-art-cutouts.png",
	"res://assets/sprites/provenance/town-truck-views.png",
]

func _packed_files(directory: String) -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var path := directory.path_join(entry)
		if dir.current_is_dir():
			files.append_array(_packed_files(path))
		else:
			files.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return files

func _initialize() -> void:
	var failures := PackedStringArray()
	if FileAccess.file_exists(CHECKOUT_ONLY) or ResourceLoader.exists(CHECKOUT_ONLY):
		failures.append("%s resolved, so this run fell back to the checkout" % CHECKOUT_ONLY)
	for path in PROVENANCE_RAW:
		if FileAccess.file_exists(path):
			failures.append("raw provenance leaked into the pack: %s" % path)
	for path in PROVENANCE_IMPORTED:
		if ResourceLoader.exists(path):
			failures.append("imported provenance leaked into the pack: %s" % path)
	for directory in PROVENANCE_DIRS:
		for path in _packed_files(directory):
			failures.append("packed entry beneath provenance: %s" % path)
	for path in SCENES:
		if ResourceLoader.load(path) == null:
			failures.append("missing packed resource %s" % path)
	for path in TEXTURES:
		var texture := ResourceLoader.load(path) as Texture2D
		if texture == null:
			failures.append("missing packed texture %s" % path)
		elif Vector2i(texture.get_width(), texture.get_height()) != TEXTURES[path]:
			failures.append(
				"%s packed at %sx%s" % [path, texture.get_width(), texture.get_height()]
			)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("export_pack_smoke: %d scenes and %d textures load from the pack" % [
		SCENES.size(), TEXTURES.size(),
	])
	quit(0)
