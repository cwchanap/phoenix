class_name UiCaptureHost
extends Control

const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")

var _state: Dictionary = {}
var _state_name := "01-hud"
var _hud: GameHud

func configure(state: Dictionary, state_name: String = "01-hud") -> void:
    _state = state.duplicate(true)
    _state_name = state_name

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var restored := GameSession.new()
    assert(restored.restore_state(_state), "visual fixture must restore through GameSession")
    _state = restored.snapshot()

    var plate := TextureRect.new()
    plate.name = "WorldPlate"
    plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var plate_path := (
        "res://tests/visual/plates/shipping.png"
        if _state_name == "03-shipping-day14"
        else "res://tests/visual/plates/farm.png"
    )
    plate.texture = ImageTexture.create_from_image(load_raw(plate_path))
    plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    plate.stretch_mode = TextureRect.STRETCH_SCALE
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(plate)

    _hud = HUD_SCENE.instantiate() as GameHud
    add_child(_hud)
    _hud.render(_state)
    _hud.set_interaction_hint("E SHOP")
    _hud.show_feedback(GameRules.CommandCode.SOIL_TILLED)

func prepare_state() -> void:
    match _state_name:
        "02-seed-shop":
            _hud.open_shop()
            for _step in 4:
                await _press_panel_action("move_right")
        "03-shipping-day14":
            _hud.open_shipping()
            await _press_panel_action("panel_max")

func _press_panel_action(action: StringName) -> void:
    var press := InputEventAction.new()
    press.action = action
    press.pressed = true
    get_viewport().push_input(press)
    var release := InputEventAction.new()
    release.action = action
    release.pressed = false
    get_viewport().push_input(release)
    await get_tree().process_frame

func capture_root() -> Image:
    if DisplayServer.get_name() == "headless":
        await get_tree().process_frame
        await get_tree().process_frame
    else:
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
