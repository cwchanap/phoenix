class_name UiCaptureHost
extends Control

const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")

var _state: Dictionary = {}
var _hud: GameHud

func configure(state: Dictionary) -> void:
    _state = state.duplicate(true)

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var plate := TextureRect.new()
    plate.name = "FarmPlate"
    plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    plate.texture = ImageTexture.create_from_image(load_raw("res://tests/visual/plates/farm.png"))
    plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    plate.stretch_mode = TextureRect.STRETCH_SCALE
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(plate)

    _hud = HUD_SCENE.instantiate() as GameHud
    add_child(_hud)
    _hud.render(_state)
    _hud.set_interaction_hint("E SHOP")
    _hud.show_feedback(GameRules.CommandCode.SOIL_TILLED)

func capture_root() -> Image:
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    assert(image.get_width() == 640)
    assert(image.get_height() == 360)
    return image

static func evidence_2x(source: Image) -> Image:
    var result := source.duplicate()
    result.resize(1280, 720, Image.INTERPOLATE_NEAREST)
    return result

static func load_raw(path: String) -> Image:
    return Image.load_from_file(ProjectSettings.globalize_path(path))
