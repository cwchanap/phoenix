class_name ShippingPanel
extends Control

signal deposit_requested(kind: int, quantity: int)

var _snapshot: Dictionary = {}
var _selected_kind := GameRules.CropKind.TURNIP
var _quantity := 1
var _rows: Array[Panel] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    for kind in range(GameRules.CropKind.size()):
        var row := get_node("Frame/Body/Row_%d" % kind) as Panel
        _rows.append(row)
        (row.get_node("Minus") as Button).pressed.connect(_adjust_quantity.bind(-1))
        (row.get_node("Plus") as Button).pressed.connect(_adjust_quantity.bind(1))
        (row.get_node("Max") as Button).pressed.connect(_select_max)
        _style_crop_button(row.get_node("Quantity") as Button)
    _style_tree(self)
    _update_rows()

func open_panel(snapshot: Dictionary) -> void:
    _selected_kind = GameRules.CropKind.TURNIP
    _quantity = 1
    present(snapshot)
    visible = true

func present(snapshot: Dictionary) -> void:
    _snapshot = snapshot.duplicate(true)
    _quantity = _clamped_quantity(_quantity)
    _update_rows()

func selected_kind() -> int:
    return _selected_kind

func selected_quantity() -> int:
    return _quantity

func _input(event: InputEvent) -> void:
    if not visible or not event.is_pressed() or event.is_echo():
        return
    if event.is_action_pressed("move_up"):
        _select_kind(-1)
    elif event.is_action_pressed("move_down"):
        _select_kind(1)
    elif event.is_action_pressed("move_left"):
        _adjust_quantity(-1)
    elif event.is_action_pressed("move_right"):
        _adjust_quantity(1)
    elif event.is_action_pressed("panel_max"):
        _select_max()
    elif event.is_action_pressed("ui_accept"):
        _deposit()
    else:
        return
    get_viewport().set_input_as_handled()

func _select_kind(delta: int) -> void:
    _selected_kind = posmod(_selected_kind + delta, GameRules.CropKind.size())
    _quantity = _clamped_quantity(_quantity)
    _update_rows()

func _adjust_quantity(delta: int) -> void:
    _quantity = clampi(_quantity + delta, 0, _max_quantity(_selected_kind))
    _update_rows()

func _select_max() -> void:
    _quantity = _max_quantity(_selected_kind)
    _update_rows()

func _deposit() -> void:
    deposit_requested.emit(_selected_kind, _quantity)

func _clamped_quantity(quantity: int) -> int:
    return clampi(quantity, 0, _max_quantity(_selected_kind))

func _max_quantity(kind: int) -> int:
    var harvested: Dictionary = _snapshot.get("harvested", {})
    return int(harvested.get(GameRules.crop_key(kind), 0))

func _pending_value() -> int:
    var pending: Dictionary = _snapshot.get("pending_shipment", {})
    var result := 0
    for kind in range(GameRules.CropKind.size()):
        result += int(pending.get(GameRules.crop_key(kind), 0)) * GameRules.sale_value(kind)
    return result

func _update_rows() -> void:
    var boundary := get_node("Boundary") as Label
    boundary.visible = int(_snapshot.get("day", 1)) == GameRules.MAX_DAY
    boundary.text = "Day 14 — only crops deposited here count toward the finale. Anything still in the bag scores nothing."
    (get_node("Frame/Header/PendingValue") as Label).text = "%dG" % _pending_value()
    (get_node("Frame/Footer/Action") as Label).text = "DEPOSIT ×%d" % _quantity
    for kind in range(GameRules.CropKind.size()):
        var row := _rows[kind]
        var selected := kind == _selected_kind
        var harvested: Dictionary = _snapshot.get("harvested", {})
        var held := int(harvested.get(GameRules.crop_key(kind), 0))
        var row_name := row.get_node("Name") as Label
        var details := row.get_node("Details") as Label
        var quantity := row.get_node("Quantity") as Button
        var max_button := row.get_node("Max") as Button
        var value_caption := row.get_node("MetaCaption") as Label
        var value := row.get_node("MetaValue") as Label
        row_name.text = GameRules.crop_display_name(kind)
        details.text = "%d in bag · %dG each" % [held, GameRules.sale_value(kind)]
        quantity.text = "×%d" % _quantity
        max_button.text = "M ALL"
        value_caption.text = "VALUE" if selected else ""
        value.text = "%d" % (GameRules.sale_value(kind) * _quantity) if selected else "—"
        UiStyle.text(row_name, 12, UiStyle.CREAM if selected else UiStyle.TEXT, 800)
        UiStyle.text(details, 9, UiStyle.MUTED, 400)
        UiStyle.text(value_caption, 8, UiStyle.MUTED, 700, true)
        UiStyle.text(value, 13, UiStyle.GREEN if selected else UiStyle.MUTED, 800, true)
        UiStyle.button(quantity, 14, selected)
        quantity.add_theme_font_override("font", UiStyle.font(700, true))
        quantity.visible = selected
        UiStyle.button(row.get_node("Minus") as Button, 9)
        UiStyle.button(row.get_node("Plus") as Button, 9)
        UiStyle.button(max_button, 8)
        max_button.visible = selected
        (row.get_node("Minus") as Button).visible = selected
        (row.get_node("Plus") as Button).visible = selected
        (row.get_node("Accent") as ColorRect).visible = selected
        row.modulate = Color.WHITE if selected or held > 0 else Color(0.58, 0.61, 0.68, 1.0)

func _style_crop_button(button: Button) -> void:
    button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _style_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_tree(child)
    for row in _rows:
        row.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.INSET, UiStyle.BORDER, 1))
    (get_node("Frame") as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.PRIMARY, UiStyle.FRAME_BORDER, 2)
    )
    var header_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
    header_style.border_width_bottom = 2
    (get_node("Frame/Header") as Panel).add_theme_stylebox_override(
        "panel", header_style
    )
    var footer_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
    footer_style.border_width_top = 2
    (get_node("Frame/Footer") as Panel).add_theme_stylebox_override(
        "panel", footer_style
    )
    (get_node("Frame/Warning") as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.WARNING_FILL, UiStyle.GOLD, 1)
    )
    UiStyle.text(get_node("Frame/Header/Title") as Label, 13, UiStyle.CREAM, 800)
    UiStyle.text(get_node("Frame/Header/PendingCaption") as Label, 8, UiStyle.MUTED, 700, true)
    UiStyle.text(get_node("Frame/Header/PendingValue") as Label, 13, UiStyle.GREEN, 800, true)
    UiStyle.text(get_node("Boundary") as Label, 8, UiStyle.GOLD, 400)
    UiStyle.text(get_node("Frame/Footer/Choose") as Label, 9, UiStyle.MUTED, 600)
    UiStyle.text(get_node("Frame/Footer/Action") as Label, 10, UiStyle.GOLD, 800)
    var enter := get_node("Frame/Footer/Enter") as Button
    UiStyle.text(enter, 8, UiStyle.GOLD, 700)
    enter.add_theme_stylebox_override("normal", UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1))
    enter.add_theme_stylebox_override("hover", UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1))
    enter.add_theme_stylebox_override("pressed", UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1))
    enter.add_theme_stylebox_override("focus", UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1))
