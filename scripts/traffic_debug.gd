extends Node3D
## Opt-in observer: never changes routing, passenger state, priority or save data.
## --traffic-debug [--traffic-log=/absolute/path.jsonl], toggle drawing with F8.
var manager: Node3D
var tick: int = 0
var drawing: bool = true
var mesh_node: MeshInstance3D
var status: Label
var log_file: FileAccess
var last_snapshot: Array = []

func attach(target: Node3D) -> void:
    manager = target
    process_physics_priority = 100
    mesh_node = MeshInstance3D.new()
    mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh_node)
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.no_depth_test = true
    mesh_node.material_override = material
    var layer := CanvasLayer.new()
    layer.layer = 100
    add_child(layer)
    status = Label.new()
    status.position = Vector2(12, 180)
    status.add_theme_font_size_override("font_size", 14)
    status.add_theme_color_override("font_shadow_color", Color.BLACK)
    status.add_theme_constant_override("shadow_outline_size", 4)
    layer.add_child(status)
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--traffic-log="):
            var path: String = arg.trim_prefix("--traffic-log=")
            log_file = FileAccess.open(path, FileAccess.WRITE)
            if log_file == null:
                push_error("Cannot open traffic telemetry: " + path)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
        drawing = not drawing
        mesh_node.visible = drawing
        status.visible = drawing

static func vector(value: Vector3) -> Array:
    return [value.x, value.y, value.z]

func snapshot() -> Array:
    var result: Array = []
    for i in range(manager._services.size()):
        var s: Dictionary = manager._services[i]
        var node: Node3D = s.node
        var direction: int = -1 if s.get("returning", false) else int(s.get("direction", 1))
        var next: float = clampf(float(s.progress) + direction * float(s.speed) / 60.0, 0.0, float(s.total))
        var blocker: int = int(s.get("traffic_blocker", -1))
        if blocker < 0:
            blocker = manager._find_traffic_blocker(i, next)
        var blocked: float = float(s.get("blocked_duration", 0.0))
        var state: String = "DRIVING"
        if float(s.get("waiting", 0.0)) > 0.0 or s.get("arrived", false):
            state = "STOPPED"
        if float(s.get("parking_blend", 0.0)) > 0.01:
            state = "PARKING"
        if s.get("menu_hold", false):
            state = "MENU_HOLD"
        if blocked > 0.0:
            state = "FOLLOWING"
        if float(s.get("yield_retreat_distance", 0.0)) > 0.0:
            state = "REVERSING"
        if blocked > 25.0:
            state = "SAFE_WAIT"
        result.append({"id": str(s.id), "position": vector(node.position),
            "heading": node.rotation.y, "progress": float(s.progress), "state": state,
            "blocker": str(manager._services[blocker].id) if blocker >= 0 else "",
            "stuck_seconds": blocked, "retreat_metres": float(s.get("yield_retreat_distance", 0.0)),
            "retreat_direction": -direction, "passenger": bool(s.get("passenger", false)),
            "pickup": bool(s.get("pickup_dispatch", false)), "reservation": manager._reservations.records(i),
            "reason": str(s.get("traffic_reason", "")),
            "priority_index": i})
    return result

func _physics_process(_delta: float) -> void:
    tick += 1
    if tick % 6 == 0:
        last_snapshot = snapshot()
        if drawing:
            redraw()
    if tick % 60 == 0 and log_file != null:
        log_file.store_line(JSON.stringify({"tick": tick, "seconds": tick / 60.0,
            "engine": Engine.get_version_info().string, "services": snapshot()}))
        log_file.flush()

func line(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
    mesh.surface_set_color(color)
    mesh.surface_add_vertex(a + Vector3.UP * 0.7)
    mesh.surface_set_color(color)
    mesh.surface_add_vertex(b + Vector3.UP * 0.7)

func footprint(mesh: ImmediateMesh, pos: Vector3, heading: float, color: Color) -> void:
    var front: Vector3 = Vector3(cos(heading), 0, -sin(heading)) * (manager.BUS_LENGTH * 0.5 + manager.COLLISION_BUFFER)
    var side: Vector3 = Vector3(-front.z, 0, front.x).normalized() * (manager.BUS_WIDTH * 0.5 + manager.COLLISION_BUFFER)
    var corners: Array = [pos + front + side, pos + front - side, pos - front - side, pos - front + side]
    for i in range(4):
        line(mesh, corners[i], corners[(i + 1) % 4], color)

func redraw() -> void:
    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    var text: String = "TRAFFIC DEBUG · F8 drawing · fixed 60 Hz\nCyan: centreline / green: lane / yellow: swept poses / red: blocker\nReservations: FIFO / protected terminal exits\n"
    for i in range(manager._services.size()):
        var s: Dictionary = manager._services[i]
        var row: Dictionary = last_snapshot[i]
        var points: Array = s.points
        for p in range(1, points.size()):
            line(mesh, points[p - 1], points[p], Color.CYAN)
        var sample: Dictionary = s.duplicate()
        var prior: Vector3 = manager._point_and_heading(sample)[0]
        # Show the actual chosen lane path ahead, including corner transitions.
        for distance in range(1, 41):
            sample["progress"] = clampf(float(s.progress) + int(s.direction) * distance, 0.0, float(s.total))
            var state: Array = manager._point_and_heading(sample)
            line(mesh, prior, state[0], Color.GREEN)
            if distance <= 8:
                footprint(mesh, state[0], float(state[1]), Color.YELLOW)
            prior = state[0]
        footprint(mesh, s.node.position, s.node.rotation.y, Color.WHITE)
        var blocker: int = manager._find_traffic_blocker(i, float(sample.progress))
        for lease in row.reservation:
            var center: Vector3 = Vector3(lease.position[0], 0.12, lease.position[1])
            var color: Color = Color.MAGENTA if int(lease.owner) == i else Color.ORANGE
            var prior_corner: Vector3 = center + Vector3(9, 0, 0)
            for edge in range(1, 25):
                var corner: Vector3 = center + Vector3(cos(edge * TAU / 24.0), 0, sin(edge * TAU / 24.0)) * 9.0
                line(mesh, prior_corner, corner, color)
                prior_corner = corner
        if blocker >= 0:
            line(mesh, s.node.position, manager._services[blocker].node.position, Color.RED)
        # Blue arrow is the potential retreat direction along the existing route.
        sample["progress"] = clampf(float(s.progress) - int(s.direction) * 5.0, 0.0, float(s.total))
        line(mesh, s.node.position, manager._point_and_heading(sample)[0], Color.BLUE)
        text += "%s [%s] blocker=%s stuck=%.1fs retreat=%.2fm passenger=%s\n" % [row.id, row.state, row.blocker, row.stuck_seconds, row.retreat_metres, row.passenger]
    mesh.surface_end()
    mesh_node.mesh = mesh
    status.text = text
