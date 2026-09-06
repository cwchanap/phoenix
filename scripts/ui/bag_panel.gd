class_name BagPanel
extends Control

signal close_requested

const SHELF_NAMES: Array[String] = ["SEEDS", "HARVESTED", "IN THE SHIPPING BIN"]
const SHELF_KEYS: Array[StringName] = [&"seeds", &"harvested", &"pending_shipment"]
const SHELF_TEXTURES: Array[String] = [
    "res://assets/ui/crops/seed-packet-%s.png",
    "res://assets/ui/crops/%s.png",
    "res://assets/ui/crops/%s.png",
]
const SLOT_XS: Array[float] = [0.0, 58.0, 116.0]

var _snapshot: Dictionary = {}
var _shelf := 0
var _selected_kind := GameRules.CropKind.TURNIP
var _shelf_panels: Array[Panel] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    for shelf in SHELF_NAMES.size():
        _shelf_panels.append(get_node("Frame/Body/Left/Shelf_%d" % shelf) as Panel)
    _style_tree(self)
    _update_view()

func open_panel(snapshot: Dictionary) -> void:
    _shelf = 0
    _selected_kind = GameRules.CropKind.TURNIP
    present(snapshot)
    visible = true

func present(snapshot: Dictionary) -> void:
    _snapshot = snapshot.duplicate(true)
    _update_view()

func selected_shelf() -> int:
    return _shelf

func selected_kind() -> int:
    return _selected_kind

func _input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed("move_up"):
        _select_shelf(-1)
    elif event.is_action_pressed("move_down"):
        _select_shelf(1)
    elif event.is_action_pressed("move_left"):
        _select_kind(-1)
    elif event.is_action_pressed("move_right"):
        _select_kind(1)
    else:
        return
    get_viewport().set_input_as_handled()

func _select_shelf(delta: int) -> void:
    _shelf = posmod(_shelf + delta, SHELF_NAMES.size())
    if _shelf == 2:
        var first_pending_kind := _first_available_kind(2)
        if first_pending_kind >= 0:
            _selected_kind = first_pending_kind
    _update_view()

func _select_kind(delta: int) -> void:
    if _shelf != 2:
        _selected_kind = posmod(_selected_kind + delta, GameRules.CropKind.size())
    else:
        for _step in GameRules.CropKind.size():
            _selected_kind = posmod(_selected_kind + delta, GameRules.CropKind.size())
            if _count_for(2, _selected_kind) > 0:
                break
    _update_view()

func _first_available_kind(shelf: int) -> int:
    for kind in range(GameRules.CropKind.size()):
        if _count_for(shelf, kind) > 0:
            return kind
    return -1

func _counts_for(shelf: int) -> Dictionary:
    return _snapshot.get(SHELF_KEYS[shelf], {})

func _count_for(shelf: int, kind: int) -> int:
    var counts := _counts_for(shelf)
    return int(counts.get(GameRules.crop_key(kind), 0))

func _total_for(shelf: int) -> int:
    var total := 0
    for kind in range(GameRules.CropKind.size()):
        total += _count_for(shelf, kind)
    return total

func _update_view() -> void:
    if not has_node("Frame"):
        return
    if _shelf == 2 and _count_for(2, _selected_kind) == 0:
        var first_pending_kind := _first_available_kind(2)
        if first_pending_kind >= 0:
            _selected_kind = first_pending_kind
    (get_node("Frame/Header/SeedTotal") as Label).text = "%d" % _total_for(0)
    (get_node("Frame/Header/HarvestTotal") as Label).text = "%d" % _total_for(1)
    for shelf in SHELF_NAMES.size():
        var shelf_panel := _shelf_panels[shelf]
        var selected := shelf == _shelf
        (shelf_panel.get_node("Title") as Label).text = SHELF_NAMES[shelf]
        UiStyle.text(
            shelf_panel.get_node("Title") as Label,
            9,
            UiStyle.GOLD if selected else UiStyle.MUTED,
            700,
        )
        shelf_panel.add_theme_stylebox_override(
            "panel",
            UiStyle.panel(Color.TRANSPARENT, Color.TRANSPARENT, 0),
        )
        var visible_pending_index := 0
        for kind in range(GameRules.CropKind.size()):
            var slot := shelf_panel.get_node("Slot_%d" % kind) as Panel
            var icon := slot.get_node("Icon") as TextureRect
            var count := slot.get_node("Count") as Label
            icon.texture = load(SHELF_TEXTURES[shelf] % GameRules.crop_key(kind)) as Texture2D
            var amount := _count_for(shelf, kind)
            var is_visible := shelf != 2 or amount > 0
            slot.visible = is_visible
            if shelf == 2 and is_visible:
                slot.position = Vector2(SLOT_XS[visible_pending_index], 16.0)
                visible_pending_index += 1
            count.text = "%d" % amount
            count.visible = false
            slot.add_theme_stylebox_override(
                "panel",
                UiStyle.panel(
                    UiStyle.KEYCAP_FILL if selected and kind == _selected_kind else UiStyle.INSET,
                    UiStyle.GOLD if selected and kind == _selected_kind else UiStyle.BORDER,
                    2 if selected and kind == _selected_kind else 1,
                ),
            )
            slot.modulate = Color.WHITE if amount > 0 else Color(0.54, 0.58, 0.66, 1.0)
            _update_count_badge(slot, amount, shelf, selected and kind == _selected_kind)
        if shelf == 2:
            _update_pending_summary(visible_pending_index)
    _update_detail()

func _update_detail() -> void:
    var kind := _selected_kind
    var name := GameRules.crop_display_name(kind)
    var shelf_count := _count_for(_shelf, kind)
    var detail := get_node("Frame/Body/Detail") as Control
    var icon := detail.get_node("Icon") as TextureRect
    icon.texture = load(SHELF_TEXTURES[_shelf] % GameRules.crop_key(kind)) as Texture2D
    (detail.get_node("Title") as Label).text = (
        "%s seeds" % name if _shelf == 0 else name
    )
    var growth := GameRules.growth_nights(kind)
    var description := "Cheapest and fastest. %d nights of watering, then harvest." % growth
    if kind == GameRules.CropKind.POTATO:
        description = "A dependable middle crop. %d nights of watering, then harvest." % growth
    elif kind == GameRules.CropKind.PUMPKIN:
        description = "Slow and valuable. %d nights of watering, then harvest." % growth
    if _shelf == 1:
        description = "%d harvested and ready for the shipping bin." % shelf_count
    elif _shelf == 2:
        description = (
            "Payout is collected at season end."
            if int(_snapshot.get("day", 1)) >= GameRules.MAX_DAY
            else "Payout is collected tomorrow morning."
        )
    (detail.get_node("Description") as Label).text = description
    (detail.get_node("GrowthText") as Label).text = "%d nights" % growth
    for pip_index in 7:
        var pip := detail.get_node("Growth/Pip_%d" % pip_index) as ColorRect
        pip.color = UiStyle.GOLD if pip_index < growth else UiStyle.BORDER
    (detail.get_node("Economy") as Label).text = "%dG buy · %dG sell" % [
        GameRules.seed_price(kind),
        GameRules.sale_value(kind),
    ]
    var favourite := VillagerRules.favourite_villager_for_crop(kind)
    (detail.get_node("Favourite") as Label).text = "%s's favourite" % VillagerRules.display_name(favourite)
    var shipment := detail.get_node("Shipment") as Label
    shipment.visible = false
    shipment.text = ""
    UiStyle.text(detail.get_node("Title") as Label, 14, UiStyle.CREAM, 800)
    UiStyle.text(detail.get_node("Description") as Label, 10, UiStyle.TEXT, 400)
    UiStyle.text(detail.get_node("GrowthText") as Label, 10, UiStyle.CREAM, 700)
    UiStyle.text(detail.get_node("Economy") as Label, 10, UiStyle.CREAM, 700, true)
    UiStyle.text(detail.get_node("Favourite") as Label, 10, UiStyle.GOLD, 700)
    UiStyle.text(shipment, 10, UiStyle.GREEN, 700, true)

func _update_pending_summary(visible_count: int) -> void:
    var shelf := get_node("Frame/Body/Left/Shelf_2") as Control
    var payout_label := shelf.get_node("PayoutText") as Label
    var payout_value := shelf.get_node("PayoutValue") as Label
    var compact_summary := get_node("Frame/Body/Left/PayoutCompact") as Control
    var compact_label := compact_summary.get_node("Text") as Label
    var compact_value := compact_summary.get_node("Value") as Label
    var payout_total := 0
    for kind in range(GameRules.CropKind.size()):
        payout_total += _count_for(2, kind) * GameRules.sale_value(kind)
    var has_pending := visible_count > 0
    var use_compact := visible_count > 1
    payout_label.visible = has_pending and not use_compact
    payout_value.visible = has_pending and not use_compact
    compact_summary.visible = has_pending and use_compact
    var text := (
        "Paid at season end"
        if int(_snapshot.get("day", 1)) >= GameRules.MAX_DAY
        else "Pays out tomorrow morning"
    )
    if not use_compact:
        var text_x := 10.0 + float(visible_count) * 58.0
        payout_label.position.x = text_x
        payout_value.position.x = text_x
    payout_label.text = text
    payout_value.text = "%dG" % payout_total
    compact_label.text = text
    compact_value.text = "%dG" % payout_total
    UiStyle.text(payout_label, 8, UiStyle.MUTED, 700)
    UiStyle.text(payout_value, 14, UiStyle.GREEN, 800, true)
    UiStyle.text(compact_label, 8, UiStyle.MUTED, 700)
    UiStyle.text(compact_value, 12, UiStyle.GREEN, 800, true)

func _update_count_badge(slot: Panel, amount: int, shelf: int, selected: bool) -> void:
    var badge := slot.get_node("CountBadge") as Panel
    badge.visible = amount > 0
    var badge_color := UiStyle.GOLD if selected else UiStyle.BORDER_LIGHT
    if shelf == 2:
        badge_color = UiStyle.GREEN if amount > 0 else UiStyle.BORDER
    badge.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.KEYCAP_FILL, badge_color, 1))
    var value := badge.get_node("Value") as Label
    value.text = "%d" % amount
    UiStyle.text(value, 8, UiStyle.CREAM if selected else UiStyle.MUTED, 800, true)

func _style_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_tree(child)
    (get_node("Frame") as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.PRIMARY, UiStyle.FRAME_BORDER, 2)
    )
    var header_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
    header_style.border_width_bottom = 2
    (get_node("Frame/Header") as Panel).add_theme_stylebox_override("panel", header_style)
    (get_node("Frame/Body/Detail/IconFrame") as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.INSET, UiStyle.BORDER, 1)
    )
    var footer_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
    footer_style.border_width_top = 2
    (get_node("Frame/Footer") as Panel).add_theme_stylebox_override("panel", footer_style)
    UiStyle.text(get_node("Frame/Header/Title") as Label, 13, UiStyle.CREAM, 800)
    UiStyle.text(get_node("Frame/Header/SeedTotal") as Label, 12, UiStyle.CREAM, 800, true)
    UiStyle.text(get_node("Frame/Header/HarvestTotal") as Label, 12, UiStyle.CREAM, 800, true)
    UiStyle.text(get_node("Frame/Footer/Help") as Label, 9, UiStyle.MUTED, 600)
    UiStyle.button(get_node("Frame/Footer/Close") as Button, 9)
