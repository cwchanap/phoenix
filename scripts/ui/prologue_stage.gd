class_name PrologueStage
extends Control
## The prologue's painted stage (HPA-1250): one still painting under a slow
## camera drift, with each scene's code-drawn motion layered on top — lights,
## particles, the kei truck and screen tints — from the scene's "motion" data
## in ContentRules.PROLOGUE_SCENES. Positions are 1920x1080 stage space over
## the 1.5x painting. Transient presentation only: OnboardingOverlay owns it
## and all text and UI, and nothing here touches GameSession or saves.

## One grade shared by both night scenes; it darkens the painting only.
const NIGHT_GRADE := Color(0.5, 0.5, 0.66)
const CAMERA_SECONDS := 10.0
const WINDOW_FADE_SECONDS := 0.8
const TRUCK_SHEET := preload("res://assets/sprites/kei-truck.png")
## Frame 1 of the sheet: the kei truck from behind, driving away up the road.
const TRUCK_FRAME := Rect2(96, 0, 96, 96)
const TRUCK_ART_SCALE := 3.0
## The truck's drive up the road eases out with this time constant.
const TRUCK_EASE_SECONDS := 14.0
## Truck-local points in its 288 px art box, measured from the bottom centre.
const TRUCK_HEADLIGHT := Vector2(92, -110)
const TRUCK_TAIL_LIGHTS: Array[Vector2] = [Vector2(-87, -45), Vector2(-36, -24)]
const TRUCK_WHEELS := Vector2(-44, -8)
const GLOW_SIZE := 128.0
## Light looks: [colour, base alpha, swing, wave, rate]. A light's alpha is
## base + swing * wave(t * rate), and lights that share an x share a phase.
const LIGHT_LOOKS := {
    &"halo": [Color("ffce82"), 0.10, 0.14, &"flicker", 1.0],
    &"flame": [Color("fff0c8"), 0.30, 0.30, &"flicker", 1.0],
    &"spill": [Color("ffc878"), 0.05, 0.06, &"flicker", 1.0],
    &"window": [Color("ffc878"), 0.03, 0.08, &"breathe", 1.2],
    &"glow": [Color("ffc46e"), 0.08, 0.07, &"breathe", 1.1],
    &"bulb": [Color("ffecaa"), 0.45, 0.0, &"steady", 1.0],
    &"neon": [Color("ff8c78"), 0.08, 0.08, &"breathe", 7.3],
    &"signal": [Color("ffaa3c"), 0.18, 0.52, &"blink", 1.25],
    &"village": [Color("ffc86e"), 0.35, 0.30, &"flicker", 0.5],
}
const ROOM_LAMP_RATE := 0.6
const FIREFLY := Color("d6ff78")
const DUST := Color(206.0 / 255.0, 160.0 / 255.0, 118.0 / 255.0, 0.3)
const DAWN_NIGHT := Color("141a46")
const DAWN_WARM := Color("ff8a4a")
const BIRD_INK := Color(45.0 / 255.0, 36.0 / 255.0, 48.0 / 255.0, 0.85)

var animate := true
var _camera: Node2D
var _background: TextureRect
var _effects: Node2D
var _tints: Control
var _windows: Node2D
var _updaters: Array[Callable] = []
var _camera_motion: Dictionary = {}
var _camera_tween: Tween
var _windows_tween: Tween
var _time := 0.0
var _scene_time := 0.0
var _additive: CanvasItemMaterial
var _glow: GradientTexture2D
var _soft_edge: GradientTexture2D

func _init() -> void:
    name = "Stage"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _additive = CanvasItemMaterial.new()
    _additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _glow = _radial([Color.WHITE, Color(1, 1, 1, 0)], [0.0, 1.0])
    _soft_edge = GradientTexture2D.new()
    _soft_edge.gradient = _gradient(
        [Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)], [0.0, 0.5, 1.0]
    )
    _soft_edge.width = 64
    _soft_edge.height = 1
    _camera = Node2D.new()
    _camera.name = "Camera"
    add_child(_camera)
    _background = TextureRect.new()
    _background.name = "IntroBackground"
    _background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _background.size = Vector2(1920, 1080)
    _background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _camera.add_child(_background)
    _effects = Node2D.new()
    _effects.name = "Effects"
    _effects.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _camera.add_child(_effects)
    _tints = Control.new()
    _tints.name = "Tints"
    _tints.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _tints.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_tints)
    set_process(false)

func background() -> TextureRect:
    return _background

## Paints a scene and starts its motion. Rebuilds every effect, so call it once per scene.
func show_scene(scene: Dictionary) -> void:
    _clear_effects()
    var path := String(scene["background"])
    if _background.texture == null or _background.texture.resource_path != path:
        _background.texture = load(path)
    _background.modulate = NIGHT_GRADE if bool(scene["night"]) else Color.WHITE
    var motion: Dictionary = scene.get("motion", {})
    _camera_motion = motion.get("camera", {})
    _time = 0.0
    _scene_time = 0.0
    _set_camera(0.0)
    if animate and not _camera_motion.is_empty():
        _camera_tween = create_tween()
        _camera_tween.tween_method(_set_camera, 0.0, 1.0, CAMERA_SECONDS) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _build_effects(motion)
    # Still mode shows each effect's settled frame once.
    _update(0.0, 0.0 if animate else 1000.0)
    set_process(animate)

## Runs the scene's per-line cues; the house windows light on their line and stay lit.
func show_line(line: Dictionary) -> void:
    if line.get("cue", &"") == &"windows" and _windows != null and not windows_lit():
        _windows.set_meta(&"lit", true)
        if animate:
            _windows_tween = _windows.create_tween()
            _windows_tween.tween_property(_windows, "modulate:a", 1.0, WINDOW_FADE_SECONDS)
        else:
            _windows.modulate.a = 1.0

func windows_lit() -> bool:
    return _windows != null and bool(_windows.get_meta(&"lit", false))

## Stops all motion and releases the painting; the overlay calls it when the prologue closes.
func clear() -> void:
    _clear_effects()
    _background.texture = null
    _background.modulate = Color.WHITE
    _camera_motion = {}
    _set_camera(0.0)

func _process(delta: float) -> void:
    _time += delta
    _scene_time += delta
    _update(_time, _scene_time)

func _update(t: float, scene_t: float) -> void:
    for updater in _updaters:
        updater.call(t, scene_t)

func _clear_effects() -> void:
    set_process(false)
    if _camera_tween != null:
        _camera_tween.kill()
        _camera_tween = null
    _updaters.clear()
    _windows = null
    _windows_tween = null
    for layer: Node in [_effects, _tints]:
        for child in layer.get_children():
            layer.remove_child(child)
            child.queue_free()

## Zoom around the pivot and pan, eased from the scene's start (0) to its end (1).
func _set_camera(progress: float) -> void:
    if _camera_motion.is_empty():
        _camera.position = Vector2.ZERO
        _camera.scale = Vector2.ONE
        return
    var pivot: Vector2 = _camera_motion["pivot"]
    var zoom: Vector2 = _camera_motion["zoom"]
    var pan: Array = _camera_motion.get("pan", [Vector2.ZERO, Vector2.ZERO])
    var factor := lerpf(zoom.x, zoom.y, progress)
    var offset: Vector2 = (pan[0] as Vector2).lerp(pan[1], progress)
    _camera.scale = Vector2(factor, factor)
    _camera.position = pivot * (1.0 - factor) + offset

func _build_effects(motion: Dictionary) -> void:
    for entry in motion.get("lights", []):
        _build_light(entry)
    if motion.has("moths"):
        _build_moths(motion["moths"])
    if motion.has("fireflies"):
        _build_fireflies(motion["fireflies"][0], motion["fireflies"][1])
    if motion.has("stars"):
        _build_stars(motion["stars"])
    if motion.has("truck"):
        _build_truck(motion["truck"])
    if motion.has("headlights"):
        _build_headlights(motion["headlights"])
    if motion.has("windows"):
        _build_windows(motion["windows"])
    if motion.has("room_lamp"):
        _build_room_lamp(motion["room_lamp"])
    if motion.has("moonlight"):
        _build_moonlight(motion["moonlight"])
    if motion.has("sun"):
        _build_sun(motion["sun"])
    if motion.has("mist"):
        _build_mist(motion["mist"])
    if motion.has("birds"):
        _build_birds(motion["birds"])
    if motion.has("dawn"):
        _build_dawn()

## [look, centre, radius, optional phase] from LIGHT_LOOKS.
func _build_light(entry: Array) -> void:
    var look: Array = LIGHT_LOOKS[entry[0]]
    var centre: Vector2 = entry[1]
    var sprite := _glow_sprite(String(entry[0]).capitalize(), centre, float(entry[2]), look[0])
    var base: float = look[1]
    var swing: float = look[2]
    var wave: StringName = look[3]
    var rate: float = look[4]
    var phase: float = float(entry[3]) if entry.size() > 3 else centre.x * 0.01
    _updaters.append(func(t: float, _scene_t: float) -> void:
        sprite.modulate.a = base + swing * _wave(wave, t * rate, phase)
    )

## Moths circling a lamp: particles orbiting its centre on a flattened ring.
func _build_moths(centre: Vector2) -> void:
    var moths := _particles("Moths", 9, 3.5, _radial([Color("fffff0"), Color(1.0, 0.94, 0.78, 0.45), Color(1, 1, 1, 0)], [0.0, 0.3, 1.0]), true)
    moths.position = centre
    moths.scale = Vector2(1.35, 0.75)
    moths.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    moths.emission_sphere_radius = 70.0
    moths.gravity = Vector2.ZERO
    moths.initial_velocity_min = 0.0
    moths.initial_velocity_max = 12.0
    moths.spread = 180.0
    moths.orbit_velocity_min = 0.25
    moths.orbit_velocity_max = 0.55
    moths.radial_accel_min = -18.0
    moths.radial_accel_max = 10.0
    moths.scale_amount_min = 0.1
    moths.scale_amount_max = 0.14
    moths.color_ramp = _fade_ramp(0.15)

## Fireflies drifting over a rect of grass, each blinking once per life.
func _build_fireflies(area: Rect2, amount: int) -> void:
    var flies := _particles("Fireflies", amount, 5.0, _radial([Color("faffc8"), Color(FIREFLY, 0.45), Color(FIREFLY, 0.0)], [0.0, 0.22, 1.0]), true)
    _emit_from(flies, area)
    flies.direction = Vector2.UP
    flies.spread = 180.0
    flies.gravity = Vector2.ZERO
    flies.initial_velocity_min = 4.0
    flies.initial_velocity_max = 14.0
    flies.scale_amount_min = 0.22
    flies.scale_amount_max = 0.3
    flies.color_ramp = _fade_ramp(0.4)

## Stars that twinkle in place across a band of sky.
func _build_stars(area: Rect2) -> void:
    var stars := _particles("Stars", 22, 4.0, _radial([Color.WHITE, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)], [0.0, 0.25, 1.0]), true)
    _emit_from(stars, area)
    stars.gravity = Vector2.ZERO
    stars.initial_velocity_min = 0.0
    stars.initial_velocity_max = 0.0
    stars.lifetime_randomness = 0.5
    stars.scale_amount_min = 0.08
    stars.scale_amount_max = 0.12
    stars.color_ramp = _fade_ramp(0.5)

## The kei truck drives away up the road, shrinking, bumping and tilting,
## with a headlight beam, tail lights and a dust trail.
func _build_truck(data: Dictionary) -> void:
    var truck := Node2D.new()
    truck.name = "Truck"
    _effects.add_child(truck)
    var beam := _beam("Beam", 380.0, 0.17, Color("fff1b8"))
    truck.add_child(beam)
    var body := Node2D.new()
    body.name = "Body"
    truck.add_child(body)
    var dust := _particles("Dust", 28, 1.4, _radial([Color.WHITE, Color(1, 1, 1, 0)], [0.55, 1.0]), false, body)
    dust.local_coords = false
    dust.position = TRUCK_WHEELS
    dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    dust.emission_rect_extents = Vector2(30, 4)
    var heading: Vector2 = ((data["to"] as Vector2) - (data["from"] as Vector2)).normalized()
    dust.direction = -heading
    dust.spread = 18.0
    dust.gravity = Vector2(0, -14)
    dust.initial_velocity_min = 60.0
    dust.initial_velocity_max = 100.0
    dust.scale_amount_min = 0.35
    dust.scale_amount_max = 0.35
    dust.scale_amount_curve = _rising_curve(0.3, 1.0)
    dust.color = DUST
    dust.color_ramp = _gradient([Color.WHITE, Color(1, 1, 1, 0)], [0.0, 1.0])
    var frame := AtlasTexture.new()
    frame.atlas = TRUCK_SHEET
    frame.region = TRUCK_FRAME
    var sprite := Sprite2D.new()
    sprite.name = "Sprite"
    sprite.texture = frame
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.offset = Vector2(0, -TRUCK_FRAME.size.y / 2.0)
    sprite.scale = Vector2(TRUCK_ART_SCALE, TRUCK_ART_SCALE)
    body.add_child(sprite)
    var tails: Array[Sprite2D] = []
    for tail in TRUCK_TAIL_LIGHTS:
        tails.append(_glow_sprite("TailLight", tail, 22.0, Color("ff3c3c"), body))
    var head := _glow_sprite("HeadLight", TRUCK_HEADLIGHT, 30.0, Color("fff6d2"), body)
    var from: Vector2 = data["from"]
    var to: Vector2 = data["to"]
    var sizes: Vector2 = data["scale"]
    var aim: Vector2 = data["beam_to"]
    _updaters.append(func(t: float, scene_t: float) -> void:
        var progress := 1.0 - exp(-scene_t / TRUCK_EASE_SECONDS)
        var shrink := lerpf(sizes.x, sizes.y, progress)
        truck.position = from.lerp(to, progress)
        var bump := 2.4 * absf(sin(t * 8.7)) + 1.3 * absf(sin(t * 13.1 + 1.0))
        body.position = Vector2(0, -bump * shrink)
        body.rotation = deg_to_rad(0.9 * sin(t * 6.3))
        body.scale = Vector2(shrink, shrink)
        var lamp := body.transform * TRUCK_HEADLIGHT
        beam.position = lamp
        beam.rotation = (aim - truck.position - lamp).angle()
        var flutter := 0.85 + 0.15 * sin(t * 8.7)
        beam.modulate.a = 0.5 * flutter
        head.modulate.a = 0.6 * flutter
        var glow := 0.6 * (0.75 + 0.25 * flicker(t, 7.0))
        for tail_light in tails:
            tail_light.modulate.a = glow
    )

## The truck's headlights at the farm, fading after the engine stops.
func _build_headlights(centre: Vector2) -> void:
    var lights := _glow_sprite("Headlights", centre, 300.0, Color("ffe8aa"))
    lights.scale.x *= 2.0
    _updaters.append(func(_t: float, scene_t: float) -> void:
        lights.modulate.a = 0.1 + 0.5 * exp(-scene_t / 4.0)
    )

## The farmhouse windows: unlit until their cue line, then a warm flickering glow.
func _build_windows(quads: Array) -> void:
    _windows = Node2D.new()
    _windows.name = "Windows"
    _windows.modulate.a = 0.0
    _effects.add_child(_windows)
    var glows: Array[CanvasItem] = []
    for quad: Array in quads:
        var points := PackedVector2Array(quad)
        var centre := Vector2.ZERO
        for point in points:
            centre += point / float(points.size())
        glows.append(_glow_sprite("WindowGlow", centre, 150.0, Color("ffb45a"), _windows))
        var pane := Polygon2D.new()
        pane.name = "Pane"
        pane.polygon = points
        pane.color = Color("ffa848")
        pane.material = _additive
        _windows.add_child(pane)
        glows.append(pane)
    _updaters.append(func(t: float, _scene_t: float) -> void:
        var warmth := 0.9 + 0.1 * flicker(t, 3.0)
        for index in glows.size():
            glows[index].modulate.a = (0.2 if index % 2 == 0 else 0.7) * warmth
    )

## The bedroom lamp: a flickering light, the room tint breathing with it, and dust motes in its glow.
func _build_room_lamp(centre: Vector2) -> void:
    var halo := _glow_sprite("LampHalo", centre, 340.0, Color("ffc878"))
    var core := _glow_sprite("Lamp", centre, 90.0, Color("ffecbe"))
    var shade := ColorRect.new()
    shade.name = "RoomShade"
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.color = Color.BLACK
    _tints.add_child(shade)
    var motes := _particles("Motes", 34, 9.0, _radial([Color("fffaeb"), Color(1.0, 0.94, 0.82, 0.4), Color(1, 1, 1, 0)], [0.0, 0.3, 1.0]), true)
    motes.position = centre + Vector2(0, 70)
    motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    motes.emission_sphere_radius = 250.0
    motes.direction = Vector2.UP
    motes.spread = 25.0
    motes.gravity = Vector2.ZERO
    motes.initial_velocity_min = 8.0
    motes.initial_velocity_max = 16.0
    motes.scale_amount_min = 0.08
    motes.scale_amount_max = 0.14
    motes.color_ramp = _fade_ramp(0.3)
    _updaters.append(func(t: float, _scene_t: float) -> void:
        var light := flicker(t * ROOM_LAMP_RATE, 4.0)
        halo.modulate.a = 0.08 + 0.12 * light
        core.modulate.a = 0.2 + 0.18 * light
        shade.color.a = 0.12 - 0.09 * light
    )

## Cool moonlight falling from the window, soft at its edges and fading along its length.
func _build_moonlight(points: Array) -> void:
    var moon := Polygon2D.new()
    moon.name = "Moonlight"
    moon.polygon = PackedVector2Array(points)
    moon.texture = _soft_edge
    moon.uv = PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(64, 0), Vector2(0, 0)])
    var blue := Color(150.0 / 255.0, 180.0 / 255.0, 1.0)
    moon.vertex_colors = PackedColorArray([blue, blue, Color(blue, 0.0), Color(blue, 0.0)])
    moon.material = _additive
    _effects.add_child(moon)
    _updaters.append(func(t: float, _scene_t: float) -> void:
        moon.modulate.a = 0.22 * (0.75 + 0.25 * sin(t * 0.6))
    )

## The morning sun: a glow and five swaying rays that come up with the dawn.
func _build_sun(centre: Vector2) -> void:
    var sun := _glow_sprite("Sun", centre, 280.0, Color("ffd696"))
    var rays: Array[Polygon2D] = []
    for index in 5:
        var ray := _beam("Ray", 1500.0, 0.035 + 0.004 * index, Color("ffecbe"))
        ray.position = centre
        _effects.add_child(ray)
        rays.append(ray)
    _updaters.append(func(t: float, scene_t: float) -> void:
        var reveal := smoothstep(0.0, 1.0, (scene_t - 1.5) / 3.0)
        sun.modulate.a = (0.2 + 0.06 * sin(t * 0.8)) * (0.4 + 0.6 * reveal)
        for index in rays.size():
            rays[index].rotation = 0.32 + index * 0.2 + 0.025 * sin(t * 0.4 + index * 1.3)
            rays[index].modulate.a = (0.1 + 0.05 * sin(t * 0.7 + index * 1.7)) * reveal
    )

## Soft bands of morning mist drifting sideways over the field, one per height.
func _build_mist(heights: Array) -> void:
    var banks: Array[Sprite2D] = []
    for height in heights:
        var bank := _glow_sprite("Mist", Vector2(0, float(height)), 90.0, Color.WHITE)
        bank.scale.x *= 5.2
        bank.modulate.a = 0.1
        banks.append(bank)
    _updaters.append(func(t: float, _scene_t: float) -> void:
        for index in banks.size():
            banks[index].position.x = fmod(t * 16.0 + index * 900.0, 2700.0) - 400.0
    )

## Birds crossing the sky: [delay, height] per bird, wings flapping.
func _build_birds(flights: Array) -> void:
    var birds: Array[Line2D] = []
    for _flight in flights:
        var bird := Line2D.new()
        bird.name = "Bird"
        bird.width = 3.0
        bird.default_color = BIRD_INK
        bird.begin_cap_mode = Line2D.LINE_CAP_ROUND
        bird.end_cap_mode = Line2D.LINE_CAP_ROUND
        bird.joint_mode = Line2D.LINE_JOINT_ROUND
        bird.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
        bird.visible = false
        _effects.add_child(bird)
        birds.append(bird)
    _updaters.append(func(_t: float, scene_t: float) -> void:
        for index in birds.size():
            var flight: Vector2 = flights[index]
            var age := scene_t - flight.x
            birds[index].visible = age >= 0.0
            if age < 0.0:
                continue
            var speed := 140.0 + 13.0 * index
            var x := fmod(age * speed, 2300.0) - 60.0
            var y := flight.y + 10.0 * sin(age * 1.4 + index)
            var span := 11.0 + index
            var wing := span * (0.25 + 0.55 * (0.5 + 0.5 * sin(age * 11.0 + index * 2.0)))
            birds[index].points = PackedVector2Array([
                Vector2(x - span, y - wing), Vector2(x, y), Vector2(x + span, y - wing),
            ])
    )

## Dawn: a night tint lifts over 4.5 s while a warm wash rises and fades.
func _build_dawn() -> void:
    var night := _tint("DawnNight", DAWN_NIGHT)
    var warm := _tint("DawnWarm", DAWN_WARM)
    warm.material = _additive
    _updaters.append(func(_t: float, scene_t: float) -> void:
        night.color.a = 0.78 * (1.0 - smoothstep(0.0, 1.0, scene_t / 4.5))
        warm.color.a = 0.32 * exp(-pow((scene_t - 2.6) / 1.4, 2.0))
    )

func _tint(tint_name: String, color: Color) -> ColorRect:
    var tint := ColorRect.new()
    tint.name = tint_name
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tint.set_anchors_preset(Control.PRESET_FULL_RECT)
    tint.color = Color(color, 0.0)
    _tints.add_child(tint)
    return tint

## A radial glow of the given radius, added on top of whatever is beneath it.
func _glow_sprite(sprite_name: String, centre: Vector2, radius: float, color: Color, parent: Node = null) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.name = sprite_name
    sprite.texture = _glow
    sprite.position = centre
    sprite.scale = Vector2.ONE * (radius * 2.0 / GLOW_SIZE)
    sprite.modulate = Color(color, 0.0)
    sprite.material = _additive
    (parent if parent != null else _effects).add_child(sprite)
    return sprite

## A light cone pointing along +x from its apex, soft at both edges, fading with length.
func _beam(beam_name: String, length: float, spread: float, color: Color) -> Polygon2D:
    var beam := Polygon2D.new()
    beam.name = beam_name
    beam.polygon = PackedVector2Array([
        Vector2.ZERO,
        Vector2(cos(-spread), sin(-spread)) * length,
        Vector2(cos(spread), sin(spread)) * length,
    ])
    beam.texture = _soft_edge
    beam.uv = PackedVector2Array([Vector2(32, 0), Vector2(0, 0), Vector2(64, 0)])
    beam.vertex_colors = PackedColorArray([color, Color(color, 0.0), Color(color, 0.0)])
    beam.material = _additive
    beam.modulate.a = 0.0
    return beam

func _particles(particles_name: String, amount: int, lifetime: float, texture: Texture2D, additive: bool, parent: Node = null) -> CPUParticles2D:
    var particles := CPUParticles2D.new()
    particles.name = particles_name
    particles.amount = amount
    particles.lifetime = lifetime
    particles.preprocess = lifetime
    particles.local_coords = true
    particles.texture = texture
    if additive:
        particles.material = _additive
    particles.emitting = animate
    particles.visible = animate
    (parent if parent != null else _effects).add_child(particles)
    return particles

func _emit_from(particles: CPUParticles2D, area: Rect2) -> void:
    particles.position = area.get_center()
    particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    particles.emission_rect_extents = area.size / 2.0

## Alpha ramps up, holds near the middle, then fades; `edge` is the share spent fading each way.
func _fade_ramp(edge: float) -> Gradient:
    return _gradient(
        [Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)],
        [0.0, edge, 1.0 - edge, 1.0]
    )

func _rising_curve(from: float, to: float) -> Curve:
    var curve := Curve.new()
    curve.add_point(Vector2(0, from))
    curve.add_point(Vector2(1, to))
    return curve

func _radial(colors: Array[Color], offsets: Array[float]) -> GradientTexture2D:
    var texture := GradientTexture2D.new()
    texture.gradient = _gradient(colors, offsets)
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1.0, 0.5)
    texture.width = int(GLOW_SIZE)
    texture.height = int(GLOW_SIZE)
    return texture

func _gradient(colors: Array[Color], offsets: Array[float]) -> Gradient:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array(offsets)
    gradient.colors = PackedColorArray(colors)
    return gradient

func _wave(kind: StringName, t: float, phase: float) -> float:
    match kind:
        &"flicker":
            return flicker(t, phase)
        &"breathe":
            return 0.5 + 0.5 * sin(t + phase)
        &"blink":
            return 1.0 if int(floor(t + phase)) % 2 == 0 else 0.0
    return 0.0

## A lamp's uneven flicker in 0..1, from three detuned sines.
static func flicker(t: float, phase: float) -> float:
    return clampf(
        0.5 + 0.22 * sin(t * 11.3 + phase) + 0.16 * sin(t * 23.7 + phase * 2.1)
            + 0.12 * sin(t * 4.9 + phase * 3.3),
        0.0, 1.0
    )
