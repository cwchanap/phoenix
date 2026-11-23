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
	"res://assets/sprites/player-walk.png": Vector2i(128, 192),
	"res://assets/sprites/kei-truck.png": Vector2i(192, 96),
	"res://assets/sprites/villagers.png": Vector2i(96, 48),
	"res://assets/sprites/proof-shadow.png": Vector2i(16, 8),
}
const CHECKOUT_ONLY := "res://tests/headless/project_smoke.gd"
# Source provenance is .gdignore'd in the checkout and excluded from the
# export, so neither the run directory nor the pack may resolve it.
const PROVENANCE_ONLY := [
	"res://assets/sprites/hpa-861-review/farm-source.png",
	"res://assets/sprites/hpa-861-review/README.md",
]

func _initialize() -> void:
	var failures := PackedStringArray()
	if ResourceLoader.exists(CHECKOUT_ONLY):
		failures.append("%s resolved, so this run fell back to the checkout" % CHECKOUT_ONLY)
	for path in PROVENANCE_ONLY:
		if ResourceLoader.exists(path):
			failures.append("%s resolved, so provenance leaked into the pack" % path)
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
