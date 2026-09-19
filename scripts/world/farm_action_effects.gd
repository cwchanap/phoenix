class_name FarmActionEffects
extends Node2D
## Transient success presentation for the four farming commands.
##
## Cell FX live under this non-Y-sorted direct World child (z_index 5), tool
## overlays under the Player root, and the harvest pop under the Entities
## Y-sort owner. Owns no gameplay state and no action framework: WorldShell
## hands over one captured success context per dispatch, transient sprites and
## tweens free themselves on completion, and _exit_tree() clears the rest.

const HOE_TEXTURE: Texture2D = preload("res://assets/sprites/polish/hoe-overlay.png")
const CAN_TEXTURE: Texture2D = preload("res://assets/sprites/polish/watering-can-overlay.png")
const SOIL_IMPACT_TEXTURE: Texture2D = preload("res://assets/sprites/polish/soil-impact.png")
const WATER_SPLASH_TEXTURE: Texture2D = preload("res://assets/sprites/polish/water-splash.png")
const SEED_TEXTURE: Texture2D = preload("res://assets/sprites/polish/planting-seed.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/sprites/polish/harvest-sparkle.png")
const CROP_TEXTURE: Texture2D = preload("res://assets/sprites/proof-crops.png")

# tests/visual/hpa-458/README.md tool-facing contract, encoded exactly once.
const TOOL_FACING := {
    WorldMath.Facing.UP: {"frame": 1, "flip": false, "anchor": Vector2(0, -22)},
    WorldMath.Facing.RIGHT: {"frame": 2, "flip": false, "anchor": Vector2(10, -21)},
    WorldMath.Facing.DOWN: {"frame": 0, "flip": false, "anchor": Vector2(4, -16)},
    WorldMath.Facing.LEFT: {"frame": 2, "flip": true, "anchor": Vector2(-10, -21)},
}

const TOOL_MOTION_SECONDS := 0.15
const TOOL_DIP := Vector2(2, 3)
const SEED_DROP_SECONDS := 0.2
const SEED_DROP_HEIGHT := 20.0
# tests/visual/hpa-458/README.md one-shot strip timing: soil ~7 fps,
# splash ~9 fps, sparkle ~8 fps ascending 0→1→2 then clear.
const SOIL_IMPACT_SECONDS := 3.0 / 7.0
const WATER_SPLASH_SECONDS := 3.0 / 9.0
const SPARKLE_SECONDS := 3.0 / 8.0
const HARVEST_POP_SECONDS := 0.3

var _player: PlayerController
var _entities: FarmView
var _tweens: Array[Tween] = []
var _tool_tween: Tween
var _external_nodes: Array[Node] = []

func setup(player: PlayerController, entities: FarmView) -> void:
    _player = player
    _entities = entities

func _exit_tree() -> void:
    for tween in _tweens:
        if is_instance_valid(tween) and tween.is_valid():
            tween.kill()
    for node in _external_nodes:
        if is_instance_valid(node):
            node.queue_free()
    _tweens.clear()
    _external_nodes.clear()

func play_success(
    code: GameRules.CommandCode,
    preview: Dictionary,
    cell: Vector2i,
    facing: int,
    player_position: Vector2,
) -> void:
    match code:
        GameRules.CommandCode.SOIL_TILLED:
            _play_tool(HOE_TEXTURE, facing)
            _play_cell_strip(cell, SOIL_IMPACT_TEXTURE, "SoilFx", SOIL_IMPACT_SECONDS)
        GameRules.CommandCode.CROP_PLANTED:
            _play_seed(cell)
        GameRules.CommandCode.CROP_WATERED:
            _play_tool(CAN_TEXTURE, facing)
            _play_cell_strip(cell, WATER_SPLASH_TEXTURE, "SplashFx", WATER_SPLASH_SECONDS)
        GameRules.CommandCode.CROP_HARVESTED:
            _play_harvest(cell, preview["crop"], player_position)

func _play_tool(texture: Texture2D, facing: int) -> void:
    # Replacing a live overlay must retire its tween too: a surviving trailing
    # _release would fire on the freed node ("previously freed instance").
    if _tool_tween != null and _tool_tween.is_valid():
        _tool_tween.kill()
    var previous := _player.get_node_or_null("ToolFx")
    if previous != null:
        _external_nodes.erase(previous)
        # Free immediately so the replacement reuses the ToolFx name.
        previous.free()
    var entry: Dictionary = TOOL_FACING[facing]
    var tool := Sprite2D.new()
    tool.name = "ToolFx"
    tool.texture = texture
    tool.hframes = 3
    tool.frame = entry["frame"]
    tool.flip_h = entry["flip"]
    tool.position = entry["anchor"]
    _player.add_child(tool)
    _external_nodes.append(tool)
    # Small Player-local dip around the HPA-458 anchor; never touches the
    # CharacterBody2D root or its collision.
    var tween := _track(create_tween())
    _tool_tween = tween
    tween.tween_property(tool, "position", entry["anchor"] + TOOL_DIP, TOOL_MOTION_SECONDS)
    tween.tween_callback(_release.bind(tool))

func _play_cell_strip(cell: Vector2i, texture: Texture2D, prefix: String, seconds: float) -> void:
    var fx := Sprite2D.new()
    fx.name = "%s_%d_%d" % [prefix, cell.x, cell.y]
    fx.texture = texture
    fx.hframes = 3
    # Bottom-anchored at the projected cell center; HPA-458 draw contract is
    # integer scale 2 with no rotation or flip.
    fx.offset = Vector2(0, -texture.get_height() / 2.0)
    fx.scale = Vector2(2, 2)
    fx.position = _cell_center(cell)
    add_child(fx)
    var tween := _track(create_tween())
    tween.tween_property(fx, "frame", 2, seconds).from(0)
    tween.tween_callback(fx.queue_free)

func _play_seed(cell: Vector2i) -> void:
    var seed_fx := Sprite2D.new()
    seed_fx.name = "SeedFx_%d_%d" % [cell.x, cell.y]
    seed_fx.texture = SEED_TEXTURE
    seed_fx.scale = Vector2(2, 2)
    var center := _cell_center(cell)
    seed_fx.position = center + Vector2(0, -SEED_DROP_HEIGHT)
    add_child(seed_fx)
    var tween := _track(create_tween())
    tween.set_parallel(true)
    tween.tween_property(seed_fx, "position", center + Vector2(0, -4), SEED_DROP_SECONDS)
    tween.tween_property(seed_fx, "modulate:a", 0.0, SEED_DROP_SECONDS)
    tween.chain().tween_callback(seed_fx.queue_free)

func _play_harvest(cell: Vector2i, crop_kind: Variant, player_position: Vector2) -> void:
    if crop_kind == null:
        return
    var pop := Node2D.new()
    pop.name = "HarvestPop_%d_%d" % [cell.x, cell.y]
    pop.position = _cell_center(cell)

    var crop := Sprite2D.new()
    crop.name = "Sprite2D"
    crop.texture = CROP_TEXTURE
    crop.hframes = 4
    crop.vframes = 3
    crop.offset = Vector2(0, -24)
    crop.frame = int(crop_kind) * 4 + 3
    pop.add_child(crop)

    var sparkle := Sprite2D.new()
    sparkle.name = "Sparkle"
    sparkle.texture = SPARKLE_TEXTURE
    sparkle.hframes = 3
    sparkle.offset = FarmView.SPARKLE_CROP_OFFSET
    crop.add_child(sparkle)

    var plus_one := Label.new()
    plus_one.name = "PlusOne"
    plus_one.text = "+1"
    UiStyle.text(plus_one, 10, UiStyle.GOLD, 700)
    pop.add_child(plus_one)
    plus_one.reset_size()
    plus_one.position = Vector2(-plus_one.size.x * 0.5, -64)

    _entities.add_child(pop)
    _external_nodes.append(pop)

    var tween := _track(create_tween())
    tween.set_parallel(true)
    tween.tween_property(
        pop, "position", pop.position.lerp(player_position, 0.25), HARVEST_POP_SECONDS,
    )
    tween.tween_property(pop, "modulate:a", 0.0, HARVEST_POP_SECONDS)
    var strip := _track(create_tween())
    strip.tween_property(sparkle, "frame", 2, SPARKLE_SECONDS).from(0)
    strip.chain().tween_callback(_release.bind(pop))

func _cell_center(cell: Vector2i) -> Vector2:
    return WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))

func _track(tween: Tween) -> Tween:
    # Finished or killed tweens stay referenced until pruned; drop them here so
    # _tweens only ever holds live tweens for _exit_tree().
    _tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid())
    _tweens.append(tween)
    return tween

func _release(node: Node) -> void:
    _external_nodes.erase(node)
    if is_instance_valid(node):
        node.queue_free()
