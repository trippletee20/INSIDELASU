extends CanvasLayer
## Independent finger ownership permits moving, looking and pressing a button together.
signal action_requested(action: String)
signal look_requested(relative: Vector2)
signal world_tapped(at: Vector2)
var look_travel: float = 0.0
var enabled: bool = false
var movement: Vector2 = Vector2.ZERO
var running: bool = false
var move_finger: int = -1
var look_finger: int = -1
var center: Vector2
var stick_radius: float = 54.0
var knob: Vector2 = Vector2.ZERO
var surface: Control
var buttons: Dictionary = {}
var button_fingers: Dictionary = {}
var riding: bool = false
var map_view: bool = false
var available: bool = false
var secondary_open: bool = false
var control_scale: float = 1.0
var stick_right: bool = false
const APP_THEME = preload("res://scripts/ui_theme.gd")

static var _touch_available: int = -1
static func touch_device() -> bool:
    if _touch_available < 0:
        var touch: bool = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
        if OS.has_feature("web"):
            touch = touch or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || window.matchMedia('(pointer: coarse)').matches"))
        _touch_available = 1 if touch else 0
    return _touch_available == 1

func _ready() -> void:
    name = "MobileControls"
    layer = 16
    available = touch_device()
    surface = Control.new()
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    surface.draw.connect(_draw_stick)
    add_child(surface)
    for item in [["more", "..."], ["interact", "Interact"], ["jump", "Up"], ["sit", "Sit / stand"], ["run", "Run: off"], ["map", "Map"], ["view", "Inside / outside"]]:
        var button := Button.new()
        button.name = "Touch_" + item[0]
        button.text = item[1]
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_theme_font_size_override("font_size", 14)
        var action: String = item[0]
        button.pressed.connect(_activate.bind(action))
        surface.add_child(button)
        buttons[action] = button
    get_viewport().size_changed.connect(_layout)
    _layout()
    set_enabled(false)

func _layout() -> void:
    reset_fingers()
    var size: Vector2 = get_viewport().get_visible_rect().size
    stick_radius = 40.0 * control_scale
    center = Vector2(72, size.y - 192)
    if size.y < 460: center = Vector2(72, size.y - 143)
    center.y = minf(center.y, size.y - 130 - stick_radius - 9)
    if stick_right: center.x = size.x - center.x
    var positions := {"interact": Vector2(size.x - 134, size.y - 190), "jump": Vector2(size.x - 66, size.y - 252), "more": Vector2(size.x - 124, size.y - 252), "sit": Vector2(size.x - 134, size.y - 310), "run": Vector2(16, size.y - 288), "map": Vector2(size.x - 80, 80), "view": Vector2(size.x - 170, size.y - 252)}
    for key in buttons:
        var button: Button = buttons[key]
        button.position = positions[key]
        button.size = Vector2(118, 48)
        if key in ["jump", "more", "map"]: button.size = Vector2(50, 50)
        elif key == "view": button.size.x = 154
        button.size = button.size.max(Vector2.ONE * (44.0 / control_scale))
        button.scale = Vector2.ONE * control_scale
        var anchor := Vector2(16 if key == "run" else size.x - 16, size.y - 130)
        button.position = anchor + (button.position - anchor) * control_scale
        button.position.x = clampf(button.position.x, 8, size.x - button.size.x * control_scale - 8)
        button.position.y = clampf(button.position.y, 80, size.y - 130 - button.size.y * control_scale)
        if size.y < 460 and key in ["sit", "run"]:
            button.position = Vector2(size.x * 0.5 + (8 if key == "sit" else -button.size.x * control_scale - 8), 80)
        if stick_right: button.position.x = size.x - button.position.x - button.size.x * control_scale
    surface.queue_redraw()

func _activate(action: String) -> void:
    if action == "more":
        secondary_open = not secondary_open
        buttons.sit.visible = secondary_open
        buttons.run.visible = secondary_open
    elif action == "run":
        running = not running
        buttons.run.text = "Run: on" if running else "Run: off"
    else:
        action_requested.emit(action)

func reset_fingers() -> void:
    button_fingers.clear()
    for button in buttons.values():
        button.modulate = Color.WHITE
    movement = Vector2.ZERO
    knob = Vector2.ZERO
    move_finger = -1
    look_finger = -1
    if surface != null:
        surface.queue_redraw()

func set_enabled(value: bool, on_bus: bool = false, map_open: bool = false) -> void:
    var next: bool = value and available
    if enabled != next or riding != on_bus or map_view != map_open:
        reset_fingers()
    enabled = next
    riding = on_bus
    map_view = map_open
    if surface == null:
        return
    surface.visible = enabled
    for key in ["jump", "more"]:
        buttons[key].visible = not riding and not map_open
    for key in ["sit", "run"]:
        buttons[key].visible = secondary_open and not riding and not map_open
    buttons.view.visible = riding
    buttons.interact.text = "Alight" if riding else "Interact"
    buttons.interact.visible = not map_open
    buttons.map.visible = false
    buttons.map.text = "Back" if map_view else "Map"
    surface.queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        reset_fingers()
        running = false
        if buttons.has("run"):
            buttons.run.text = "Run: off"

func _draw_stick() -> void:
    if riding or map_view or not enabled:
        return
    surface.draw_circle(center, stick_radius + 9, Color(APP_THEME.colors.surface, 0.8))
    surface.draw_arc(center, stick_radius + 9, 0, TAU, 40, APP_THEME.colors.accent, 2)
    surface.draw_circle(center + knob, 19 * control_scale, APP_THEME.colors.accent)

func _input(event: InputEvent) -> void:
    if not enabled:
        return
    if event is InputEventScreenTouch:
        if not event.pressed:
            if button_fingers.has(event.index):
                var action: String = str(button_fingers[event.index])
                button_fingers.erase(event.index)
                buttons[action].modulate = Color.WHITE
                if buttons[action].visible and Rect2(buttons[action].position, buttons[action].size * buttons[action].scale).has_point(event.position):
                    _activate(action)
                get_viewport().set_input_as_handled()
                return
            if event.index == move_finger:
                move_finger = -1
                movement = Vector2.ZERO
                knob = Vector2.ZERO
                surface.queue_redraw()
            if event.index == look_finger:
                look_finger = -1
                if look_travel < 12:
                    world_tapped.emit(event.position)
            return
        for action in buttons:
            var button: Button = buttons[action]
            if button.visible and Rect2(button.position, button.size * button.scale).has_point(event.position):
                button_fingers[event.index] = action
                button.modulate = Color(0.65, 1.0, 0.85)
                get_viewport().set_input_as_handled()
                return
        if map_view:
            return
        # Let the HUD dock and location strip receive their own touch events.
        if event.position.y >= get_viewport().get_visible_rect().size.y - 126:
            return
        if not riding and move_finger < 0 and event.position.distance_to(center) <= stick_radius + 32:
            move_finger = event.index
            _move_stick(event.position)
            get_viewport().set_input_as_handled()
        elif look_finger < 0 and (event.position.x < get_viewport().get_visible_rect().size.x * 0.57 if stick_right else event.position.x > get_viewport().get_visible_rect().size.x * 0.43) and event.position.y > (90 if get_viewport().get_visible_rect().size.y < 500 else 110):
            look_finger = event.index
            look_travel = 0
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if event.index == move_finger:
            _move_stick(event.position)
            get_viewport().set_input_as_handled()
        elif event.index == look_finger:
            look_travel += event.relative.length()
            look_requested.emit(event.relative)
            get_viewport().set_input_as_handled()

func _move_stick(at: Vector2) -> void:
    knob = (at - center).limit_length(stick_radius)
    movement = knob / stick_radius
    if movement.length() < 0.15:
        movement = Vector2.ZERO
    surface.queue_redraw()
