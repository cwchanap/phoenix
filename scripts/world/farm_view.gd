class_name FarmView
extends Node2D

const CROP_TEXTURE: Texture2D = preload("res://assets/sprites/proof-crops.png")
const SHADOW_TEXTURE: Texture2D = preload("res://assets/sprites/proof-shadow.png")
const SOIL_TEXTURE: Texture2D = preload("res://assets/sprites/proof-soil.png")
const SPARKLE_TEXTURE: Texture2D = preload("res://assets/sprites/polish/harvest-sparkle.png")
const SPARKLE_CROP_OFFSET := Vector2(0, -44)

var _farm_soil: Node2D
var _soil_sprites: Dictionary = {}
var _crop_sprites: Dictionary = {}
var _crop_shadows: Dictionary = {}
var _crop_sparkles: Dictionary = {}
var _crop_mature: Dictionary = {}
var _target_cell: Variant = null

func _crop_name(cell: Vector2i) -> StringName:
    return StringName("FarmCrop_%d_%d" % [cell.x, cell.y])

func _ready() -> void:
    _farm_soil = get_node("../FarmSoil") as Node2D
    for cell in WorldContract.farm_cells():
        var soil := Sprite2D.new()
        soil.name = StringName("Soil_%d_%d" % [cell.x, cell.y])
        soil.texture = SOIL_TEXTURE
        soil.hframes = 2
        soil.position = WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
        soil.visible = false
        _farm_soil.add_child(soil)
        _soil_sprites[cell] = soil

        var crop_root := Node2D.new()
        crop_root.name = _crop_name(cell)
        crop_root.position = WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))

        var crop_shadow := Sprite2D.new()
        crop_shadow.name = "Shadow"
        crop_shadow.texture = SHADOW_TEXTURE
        crop_shadow.visible = false
        crop_root.add_child(crop_shadow)

        var crop_sprite := Sprite2D.new()
        crop_sprite.name = "Sprite2D"
        crop_sprite.texture = CROP_TEXTURE
        crop_sprite.hframes = 4
        crop_sprite.vframes = 3
        crop_sprite.offset = Vector2(0, -24)
        crop_sprite.visible = false
        crop_root.add_child(crop_sprite)

        var sparkle := Sprite2D.new()
        sparkle.name = "ReadinessSparkle"
        sparkle.texture = SPARKLE_TEXTURE
        sparkle.hframes = 3
        # tests/visual/hpa-458/README.md: frame 1 is the 4-point star peak.
        sparkle.frame = 1
        sparkle.offset = SPARKLE_CROP_OFFSET
        sparkle.visible = false
        crop_sprite.add_child(sparkle)

        add_child(crop_root)
        _crop_sprites[cell] = crop_sprite
        _crop_shadows[cell] = crop_shadow
        _crop_sparkles[cell] = sparkle

func refresh(snapshot: Dictionary) -> void:
    var rainy: bool = snapshot.get(
        "weather",
        GameRules.weather_key(GameRules.Weather.SUNNY),
    ) == GameRules.weather_key(GameRules.Weather.RAINY)
    for entry_variant in snapshot["farm"]:
        var entry: Dictionary = entry_variant
        var cell: Vector2i = entry["cell"]
        var soil: Sprite2D = _soil_sprites[cell]
        var crop: Sprite2D = _crop_sprites[cell]
        var tilled := bool(entry["tilled"])
        var crop_data: Variant = entry["crop"]

        soil.visible = tilled
        crop.visible = tilled and crop_data != null
        (_crop_shadows[cell] as Sprite2D).visible = crop.visible
        if not tilled:
            continue

        soil.frame = 1 if rainy or (crop_data != null and bool(crop_data["watered_today"])) else 0
        var mature := false
        if crop_data != null:
            var kind: GameRules.CropKind = _crop_kind(crop_data["kind"])
            mature = GameRules.is_mature(kind, int(crop_data["growth"]))
            crop.frame = int(kind) * 4 + GameRules.visual_stage(kind, int(crop_data["growth"]))
        _crop_mature[cell] = mature
    _update_readiness_cue()

func set_target_cell(target: Variant) -> void:
    _target_cell = target
    _update_readiness_cue()

func _update_readiness_cue() -> void:
    for cell in _crop_sparkles:
        var sparkle: Sprite2D = _crop_sparkles[cell]
        sparkle.visible = (
            cell == _target_cell
            and bool(_crop_mature.get(cell, false))
        )

func _crop_kind(value: Variant) -> GameRules.CropKind:
    if value is StringName:
        return GameRules.CROP_KEYS.find(value)
    return int(value)
