class_name ResultScreen
extends Control

signal new_game_requested
signal return_to_title_requested

const BACKGROUND := preload("res://assets/ui/backgrounds/result.png")
const STAT_ICONS: Array[Texture2D] = [
    preload("res://assets/ui/crops/turnip.png"),
    preload("res://assets/ui/icons/coin-stack.png"),
    preload("res://assets/ui/icons/money-bag.png"),
]
const STAT_CAPTIONS: Array[String] = ["CROPS SHIPPED", "SHIPPED VALUE", "FINAL MONEY"]
const HEART_FILLED_ICON := preload("res://assets/ui/icons/heart-filled.png")
const HEART_OUTLINE_ICON := preload("res://assets/ui/icons/heart-outline.png")

var _featured_villager := ""
var _title: Label
var _tier_line: Label
var _stats: Array[Label] = []
var _save_status: Label
var _save_pill: PanelContainer
var _card_names: Array[Label] = []
var _card_levels: Array[Label] = []
var _card_quotes: Array[Label] = []
var _card_panels: Array[PanelContainer] = []
var _card_frames: Array[PanelContainer] = []
var _hearts: Array = []

func _ready() -> void:
    _build()
    visible = false

func _unhandled_input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed(&"ui_accept"):
        new_game_requested.emit()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed(&"ui_cancel"):
        return_to_title_requested.emit()
        get_viewport().set_input_as_handled()

func present(result: Dictionary, save_error: int = OK) -> void:
    _featured_villager = String(result["villager"])
    _title.text = String(result["title"])
    _tier_line.text = String(result["epilogue"])
    _stats[0].text = "%d" % int(result["shipped_count"])
    _stats[1].text = "%dG" % int(result["shipped_value"])
    _stats[2].text = "%dG" % int(result["final_money"])
    var villagers: Dictionary = result["villagers"]
    for id in range(VillagerRules.VillagerId.size()):
        var villager: Dictionary = villagers[VillagerRules.villager_key(id)]
        var level_key := StringName(villager["level"])
        var level := VillagerRules.RELATIONSHIP_KEYS.find(level_key)
        _card_names[id].text = String(villager["name"])
        _card_levels[id].text = _level_display_name(level_key)
        _card_quotes[id].text = tr("“%s”") % tr(String(villager["line"]))
        var heart_count := _heart_count(level)
        for heart_index in 3:
            (_hearts[id][heart_index] as TextureRect).texture = (
                HEART_FILLED_ICON if heart_index < heart_count else HEART_OUTLINE_ICON
            )
        var featured := String(villager["name"]) == _featured_villager
        var box := UiStyle.card(UiStyle.CARD, 26, [0, 0, 0, 0])
        box.shadow_color = (
            Color(1.0, 0.24, 0.5, 0.38) if featured else Color(0.0, 0.0, 0.0, 0.35)
        )
        box.shadow_size = 20
        box.shadow_offset = Vector2(0, 14)
        box.border_color = UiStyle.ACCENT if featured else UiStyle.LINE
        box.set_border_width_all(4 if featured else 1)
        _card_panels[id].add_theme_stylebox_override("panel", box)
        _card_frames[id].visible = featured
        _card_names[id].add_theme_color_override(
            "font_color", UiStyle.ACCENT_DEEP if featured else UiStyle.INK
        )
    _save_status.text = "" if save_error == OK else "Final result was not saved."
    _save_pill.visible = save_error != OK
    visible = true

func featured_villager_name() -> String:
    return _featured_villager

func result_state() -> Dictionary:
    var names := {}
    var levels := {}
    var quotes := {}
    var hearts := {}
    var featured := {}
    for id in range(VillagerRules.VillagerId.size()):
        var key := VillagerRules.villager_key(id)
        names[key] = _card_names[id].text
        levels[key] = _card_levels[id].text
        quotes[key] = _card_quotes[id].text
        var filled: Array = []
        for heart in _hearts[id]:
            filled.append((heart as TextureRect).texture == HEART_FILLED_ICON)
        hearts[key] = filled
        var box := _card_panels[id].get_theme_stylebox("panel") as StyleBoxFlat
        featured[key] = box != null and box.border_color == UiStyle.ACCENT
    var stat_values: Array[String] = []
    for label in _stats:
        stat_values.append(label.text)
    return {
        "title": _title.text,
        "tier_line": _tier_line.text,
        "save_status": _save_status.text,
        "stats": stat_values,
        "names": names,
        "levels": levels,
        "quotes": quotes,
        "hearts": hearts,
        "featured": featured,
    }

func _level_display_name(level_key: Variant) -> String:
    for level in range(VillagerRules.RelationshipLevel.size()):
        if VillagerRules.relationship_key(level) == level_key:
            return VillagerRules.relationship_display_name(level)
    return String(level_key)

func _heart_count(level: int) -> int:
    if level == VillagerRules.RelationshipLevel.CLOSE_FRIEND:
        return 3
    if level == VillagerRules.RelationshipLevel.FRIEND:
        return 2
    return 0

func _build() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    var background := TextureRect.new()
    background.name = "Background"
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    background.texture = BACKGROUND
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    add_child(background)

    var scrim := TextureRect.new()
    scrim.name = "Scrim"
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
    scrim.texture = _scrim_gradient()
    scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    scrim.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(scrim)

    var column := UiStyle.vbox(26)
    column.name = "Column"
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.anchor_right = 1.0
    column.anchor_bottom = 1.0
    column.offset_top = 60.0
    add_child(column)

    column.add_child(_header())
    column.add_child(_stats_row())
    column.add_child(_villager_cards())

    var actions := UiStyle.hbox(16)
    actions.name = "Actions"
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.anchor_left = 0.5
    actions.anchor_right = 0.5
    actions.anchor_top = 1.0
    actions.anchor_bottom = 1.0
    actions.offset_left = -330.0
    actions.offset_right = 330.0
    actions.offset_top = -96.0
    actions.offset_bottom = -44.0
    actions.grow_horizontal = Control.GROW_DIRECTION_BOTH
    actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
    add_child(actions)
    var new_game := UiStyle.primary_action("Enter", "NEW GAME")
    new_game.name = "NewGame"
    new_game.pressed.connect(func() -> void: new_game_requested.emit())
    actions.add_child(new_game)
    var to_title := UiStyle.ghost_action("Esc", "TITLE")
    to_title.name = "ReturnToTitle"
    to_title.pressed.connect(func() -> void: return_to_title_requested.emit())
    actions.add_child(to_title)

    _save_pill = PanelContainer.new()
    _save_pill.name = "SavePill"
    _save_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _save_pill.add_theme_stylebox_override(
        "panel", UiStyle.card(UiStyle.WARN, UiStyle.PILL_RADIUS, [18, 9, 18, 9])
    )
    _save_pill.anchor_left = 0.5
    _save_pill.anchor_right = 0.5
    _save_pill.anchor_top = 1.0
    _save_pill.anchor_bottom = 1.0
    _save_pill.offset_top = -112.0
    _save_pill.offset_bottom = -112.0
    _save_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _save_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _save_pill.visible = false
    add_child(_save_pill)
    _save_status = UiStyle.label("", 20, UiStyle.WARN_INK, 800)
    _save_status.name = "SaveStatus"
    _save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _save_pill.add_child(_save_status)

func _scrim_gradient() -> GradientTexture2D:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 1.0])
    gradient.colors = PackedColorArray([
        Color(0.047, 0.071, 0.125, 0.55),
        Color(0.047, 0.071, 0.125, 0.25),
    ])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 1920
    texture.height = 1080
    texture.fill_from = Vector2(0.5, 0)
    texture.fill_to = Vector2(0.5, 1)
    return texture

func _header() -> VBoxContainer:
    var header := UiStyle.vbox(10)
    header.name = "Header"
    var kicker := SlantTag.new("SEASON COMPLETE", [UiStyle.SUN], UiStyle.SUN_INK, 15)
    kicker.name = "Kicker"
    kicker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    header.add_child(kicker)
    _title = UiStyle.label("", 84, UiStyle.CARD, 900)
    _title.name = "Title"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(_title)
    _tier_line = UiStyle.label("", 20, Color(1.0, 1.0, 1.0, 0.85), 600)
    _tier_line.name = "TierLine"
    _tier_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _tier_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(_tier_line)
    return header

func _stats_row() -> HBoxContainer:
    var row := UiStyle.hbox(16)
    row.name = "Stats"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    for index in STAT_CAPTIONS.size():
        var accent := index == 1
        var card_node: PanelContainer
        if accent:
            card_node = UiStyle.gradient_surface(
                UiStyle.ACCENT_GRADIENT, 24, [18, 18, 18, 18]
            )
            var accent_box := card_node.get_theme_stylebox("panel") as StyleBoxFlat
            accent_box.shadow_size = 20
            accent_box.shadow_offset = Vector2(0, 14)
            accent_box.shadow_color = Color(1.0, 0.24, 0.5, 0.38)
        else:
            card_node = PanelContainer.new()
            card_node.add_theme_stylebox_override(
                "panel", UiStyle.card(UiStyle.CARD, 24, [18, 18, 18, 18])
            )
        card_node.name = "Card_%d" % index
        card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card_node.custom_minimum_size = Vector2(270, 0)
        var inner := UiStyle.vbox(4)
        inner.name = "Column"
        inner.alignment = BoxContainer.ALIGNMENT_CENTER
        card_node.add_child(inner)
        var icon := UiStyle.icon(STAT_ICONS[index], 64)
        icon.name = "Icon"
        icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        inner.add_child(icon)
        var value := UiStyle.label("", 44, UiStyle.CARD if accent else UiStyle.INK, 900)
        value.name = "Value"
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _stats.append(value)
        inner.add_child(value)
        var caption := UiStyle.label(
            STAT_CAPTIONS[index],
            15,
            Color(1.0, 1.0, 1.0, 0.85) if accent else UiStyle.INK_MUTED,
            900,
        )
        caption.name = "Caption"
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        inner.add_child(caption)
        row.add_child(card_node)
    return row

func _villager_cards() -> HBoxContainer:
    var row := UiStyle.hbox(20)
    row.name = "Cards"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    for id in range(VillagerRules.VillagerId.size()):
        row.add_child(_villager_card(id))
    return row

func _villager_card(id: int) -> PanelContainer:
    var card := PanelContainer.new()
    card.name = "Card_%s" % String(VillagerRules.villager_key(id)).capitalize()
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.custom_minimum_size = Vector2(440, 0)
    var box := UiStyle.card(UiStyle.CARD, 26, [0, 0, 0, 0])
    box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
    box.shadow_size = 20
    box.shadow_offset = Vector2(0, 14)
    box.border_color = UiStyle.LINE
    box.set_border_width_all(1)
    card.add_theme_stylebox_override("panel", box)
    _card_panels.append(card)

    var column := UiStyle.vbox(0)
    column.name = "Column"
    card.add_child(column)
    var frame := PanelContainer.new()
    frame.name = "Frame"
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var frame_box := UiStyle.card(Color(1.0, 1.0, 1.0, 0.0), 26, [0, 0, 0, 0], false)
    frame_box.border_color = UiStyle.ACCENT
    frame_box.set_border_width_all(4)
    frame.add_theme_stylebox_override("panel", frame_box)
    frame.visible = false
    card.add_child(frame)
    _card_frames.append(frame)
    var clip := Control.new()
    clip.name = "PortraitClip"
    clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip.clip_contents = true
    clip.custom_minimum_size = Vector2(440, 200)
    column.add_child(clip)
    var backdrop := TextureRect.new()
    backdrop.name = "Backdrop"
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.texture = UiStyle.rounded_gradient_texture(
        UiStyle.HEADER_GRADIENT, Vector2i(440, 200), 26, 0
    )
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_SCALE
    backdrop.position = Vector2.ZERO
    backdrop.size = Vector2(440, 200)
    clip.add_child(backdrop)
    var portrait := TextureRect.new()
    portrait.name = "Portrait"
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait.position = Vector2(92, 40)
    portrait.size = Vector2(256, 358)
    portrait.texture = (
        load("res://assets/ui/portraits/%s.png" % VillagerRules.PORTRAIT_NAMES[id]) as Texture2D
    )
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    clip.add_child(portrait)

    var body := MarginContainer.new()
    body.name = "Body"
    body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for side in [["left", 20], ["top", 14], ["right", 20], ["bottom", 18]]:
        body.add_theme_constant_override("margin_" + side[0], side[1])
    column.add_child(body)
    var stack := UiStyle.vbox(6)
    stack.name = "Stack"
    body.add_child(stack)
    var name_row := UiStyle.hbox(10)
    name_row.name = "NameRow"
    stack.add_child(name_row)
    var info := UiStyle.vbox(2)
    info.name = "Info"
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_row.add_child(info)
    var card_name := UiStyle.label("", 26, UiStyle.INK, 900)
    card_name.name = "Name"
    _card_names.append(card_name)
    info.add_child(card_name)
    var sub := UiStyle.hbox(4)
    sub.name = "Sub"
    info.add_child(sub)
    var role := UiStyle.label(VillagerRules.role_label(id), 14, UiStyle.INK_MUTED, 700)
    role.name = "Role"
    sub.add_child(role)
    var dot := UiStyle.label("·", 14, UiStyle.INK_MUTED, 700)
    dot.name = "Dot"
    sub.add_child(dot)
    var level := UiStyle.label("", 14, UiStyle.INK_MUTED, 700)
    level.name = "Level"
    _card_levels.append(level)
    sub.add_child(level)
    var hearts := UiStyle.hbox(4)
    hearts.name = "Hearts"
    hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_row.add_child(hearts)
    var card_hearts: Array = []
    for heart_index in 3:
        var heart := UiStyle.icon(HEART_OUTLINE_ICON, 24)
        heart.name = "Heart_%d" % heart_index
        hearts.add_child(heart)
        card_hearts.append(heart)
    _hearts.append(card_hearts)
    var quote := UiStyle.label("", 18, UiStyle.INK_MUTED, 600)
    quote.name = "Quote"
    quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    quote.custom_minimum_size = Vector2(0, 76)
    _card_quotes.append(quote)
    stack.add_child(quote)
    return card
