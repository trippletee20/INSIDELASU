extends Node3D
signal traffic_safe_wait(service_id: String, reason: String)
# Inside LASU v0.13 — bus-bay staging, horns, rear-bus priority and deadlock recovery,
# and junction right-of-way. Existing road graph / campus coordinates stay immutable.
# Physics-tick movement with smooth steering and endpoint lane merging.

## Arcade beta: only peer-vehicle blocking is disabled; paths and world checks remain.
var vehicle_blocking: bool = false
var _services: Array = []
var _shelter_positions: Dictionary = {}
var _shelter_names: Dictionary = {}
var _scale: float = 2.6
var _bus_y: float = 0.12
var _road_nodes: Array = []
var _road_adjacency: Array = []
var _road_component_ids: Array = []
var _last_route_used_fallback: bool = false
var _last_route_access_distance: float = 0.0
var _main_component_id: int = -1
var _destination_stops: Dictionary = {}
var _destination_stop_visuals: Array = []
var _destination_footprints: Array = []
var _shared_stand_positions: Array = []
var _junction_positions: Array = []
var _lane_offset_cache: Dictionary = {}
var _reservations = preload("res://scripts/traffic_reservations.gd").new()
const LANE_OFFSET_METRES: float = 2.12
const LANE_MERGE_DISTANCE: float = 9.0
const BUS_LENGTH: float = 6.6
const BUS_WIDTH: float = 2.35
const COLLISION_BUFFER: float = 0.22
const JUNCTION_APPROACH: float = 18.0
const PARK_BAY_EXTRA_METRES: float = 3.55
const HORN_WAIT_SECONDS: float = 2.5
const HORN_REPEAT_SECONDS: float = 7.0
const MAX_YIELD_DISTANCE: float = 38.0

func initialise(transit_data: Dictionary, shelter_data: Array, scale_factor: float, road_data: Dictionary = {}, campus_features: Array = []) -> void:
    _scale = scale_factor
    _cache_road_obstacles(campus_features)
    _build_road_graph(road_data)
    for stop in shelter_data:
        var item: Dictionary = stop
        var stop_id: String = str(item.get("id", ""))
        var coords: Array = item.get("position", [0.0, 0.0])
        _shelter_positions[stop_id] = Vector3(float(coords[0]) * _scale, 0.28, float(coords[1]) * _scale)
        _shelter_names[stop_id] = str(item.get("name", stop_id))

    # Anchor the service network to the first approved shuttle route's road component.
    # All destination stops are projected onto this connected component; disconnected
    # schematic fragments are never bridged with invented diagonal shortcuts.
    var raw_lines: Array = transit_data.get("lines", [])
    if not raw_lines.is_empty():
        var first_line: Dictionary = raw_lines[0]
        var reference_points: Array = first_line.get("points", [])
        if not reference_points.is_empty():
            var first_coords: Array = reference_points[0]
            var reference_snap: Dictionary = _nearest_road_edge(Vector2(float(first_coords[0]), float(first_coords[1])) )
            if not reference_snap.is_empty():
                _main_component_id = int(_road_component_ids[int(reference_snap["a"])])
    if _main_component_id < 0 and not _road_nodes.is_empty():
        _main_component_id = _largest_road_component()

    for raw_line in raw_lines:
        var line: Dictionary = raw_line
        var stop_ids: Array = line.get("stop_ids", [])
        if stop_ids.size() != 2:
            push_warning("Skipping incomplete shuttle service: " + str(line.get("id", "unknown")))
            continue
        if not _shelter_positions.has(str(stop_ids[0])) or not _shelter_positions.has(str(stop_ids[1])):
            push_warning("Shuttle service references a missing waiting shelter")
            continue
        var start_world: Vector3 = _shelter_positions[str(stop_ids[0])]
        var end_world: Vector3 = _shelter_positions[str(stop_ids[1])]
        var start_raw: Vector2 = Vector2(start_world.x / _scale, start_world.z / _scale)
        var end_raw: Vector2 = Vector2(end_world.x / _scale, end_world.z / _scale)
        # Shelters are pedestrian waiting areas, not guaranteed road points.
        # Project only the initial route origin; no off-road driving connector.
        var origin_edge: Dictionary = _nearest_road_edge(start_raw, _main_component_id)
        if not origin_edge.is_empty():
            start_raw = origin_edge["point"]
        var raw_route: Array = _road_path_between(start_raw, end_raw)
        if raw_route.size() < 2:
            push_warning("Skipping shuttle service because no continuous road route connects its stops: " + str(line.get("id", "unknown")))
            continue
        var points: Array = []
        var total_length: float = 0.0
        for raw_point in raw_route:
            var coords: Vector2 = raw_point
            points.append(Vector3(coords.x * _scale, _bus_y, coords.y * _scale))
        for i in range(1, points.size()):
            var prior: Vector3 = points[i - 1]
            var later: Vector3 = points[i]
            total_length += prior.distance_to(later)
        if total_length < 1.0:
            continue
        var bus := Node3D.new()
        bus.name = "MovingShuttle_" + str(line.get("id", "service"))
        bus.add_to_group("moving_shuttles")
        bus.set_meta("line_id", str(line.get("id", "")))
        add_child(bus)
        _build_bus(bus, str(line.get("display_name", "LASU SHUTTLE")), str(line.get("id", "")))
        var service: Dictionary = {
            "id": str(line.get("id", "")),
            "name": str(line.get("display_name", "LASU SHUTTLE")),
            "node": bus,
            "points": points,
            "total": total_length,
            "progress": 0.0,
            "direction": 1,
            "lane_shift": 1.0,
            "blocked_duration": 0.0,
            "yield_retreat_distance": 0.0,
            "parking_blend": 0.0,
            "horn_cooldown": 0.0,
            "force_yield": false,
            "speed": float(line.get("speed_metres_per_second", 8.0)),
            "stop_ids": stop_ids,
            "at_stop_index": 0,
            "waiting": 9.0,
            "menu_hold": false,
            "passenger": false,
            "arrived": false,
            "base_points": points.duplicate(),
            "base_total": total_length,
            "base_progress": 0.0,
            "base_direction": 1,
            "destination_mode": false,
            "destination_name": "",
            "returning": false,
            "pickup_dispatch": false,
            "pickup_only": false,
            "pickup_waiting": false,
            "pickup_wait_timer": 0.0,
            "loop_points": [],
            "loop_total": total_length,
            "loop_progress": 0.0,
            "loop_direction": 1,
            "loop_at_stop_index": 0
        }
        # Space newly activated shuttles along existing safe paths; never spawn
        # multiple large vehicles at the same shelter position.
        var clear_spawn: bool = false
        for candidate_index in range(12):
            service["progress"] = total_length * (0.04 + float(candidate_index) / 13.0)
            var spawn_state: Array = _point_and_heading(service)
            var spawn_position: Vector3 = spawn_state[0]
            var nearby_bus: bool = false
            for previous_variant in _services:
                var previous: Dictionary = previous_variant
                var other: Node3D = previous.get("node") as Node3D
                if other != null and Vector2(other.position.x - spawn_position.x, other.position.z - spawn_position.z).length() < 11.0:
                    nearby_bus = true
                    break
            if not nearby_bus:
                clear_spawn = true
                break
        if not clear_spawn:
            bus.queue_free()
            push_warning("Traffic slot unavailable for shuttle " + str(line.get("id", "service")))
            continue
        service["base_progress"] = float(service["progress"])
        service["loop_progress"] = float(service["progress"])
        service["waiting"] = float(_services.size()) * 9.0 + 3.0
        _services.append(service)
        _place_service(service)

    _reservations.initialise(self)
    _build_terminal_bays()
    _build_destination_stops(campus_features, road_data)
    if OS.get_cmdline_user_args().has("--traffic-debug"):
        var observer = load("res://scripts/traffic_debug.gd").new()
        observer.name = "TrafficDiagnostics"
        add_child(observer)
        observer.attach(self)

func _build_terminal_bays() -> void:
    # Visible pull-off pockets are separate from the running carriageway.
    # Skip a bay rather than drawing concrete through an existing building.
    for idx in range(_services.size()):
        var base: Dictionary = _services[idx]
        for terminal_idx in range(2):
            var test: Dictionary = base.duplicate()
            test["progress"] = 0.0 if terminal_idx == 0 else float(base.get("total", 0.0))
            test["direction"] = 1 if terminal_idx == 0 else -1
            test["lane_shift"] = 1.0
            test["parking_blend"] = 1.0
            if not _bay_position_is_clear(idx, test):
                continue
            var state: Array = _point_and_heading(test)
            var bay: MeshInstance3D = MeshInstance3D.new()
            bay.name = "PavedShuttleBay_" + str(idx) + "_" + str(terminal_idx)
            var mesh: BoxMesh = BoxMesh.new()
            mesh.size = Vector3(10.0, 0.06, 3.2)
            bay.mesh = mesh
            bay.position = state[0] + Vector3(0, 0.0, 0)
            bay.rotation.y = float(state[1])
            bay.material_override = _material(Color(0.34, 0.38, 0.39))
            add_child(bay)

func _physics_process(delta: float) -> void:
    _lane_offset_cache.clear()
    # Batch requests before movement so service iteration cannot steal a lease.
    if vehicle_blocking:
        _reservations.update(self, delta)
    # Drive on fixed physics ticks; project physics interpolation smooths the render.
    for index in range(_services.size()):
        var service: Dictionary = _services[index]
        service["horn_cooldown"] = maxf(0.0, float(service.get("horn_cooldown", 0.0)) - delta)
        _services[index] = service
        if not bool(service.get("destination_mode", false)):
            if _update_parking_bay(index, delta):
                continue
            service = _services[index]
        if bool(service.get("menu_hold", false)):
            continue
        if bool(service.get("destination_mode", false)):
            # A dispatched pickup waits at the requested stand for a limited time.
            # If nobody boards, it returns along the same road path instead of being
            # stranded indefinitely at the stop.
            if bool(service.get("pickup_waiting", false)):
                var pickup_timer: float = float(service.get("pickup_wait_timer", 0.0)) - delta
                if pickup_timer <= 0.0:
                    _set_stop_status(str(service.get("destination_name", "")), "")
                    service["points"] = service.get("base_points", []).duplicate()
                    service["total"] = float(service.get("base_total", 1.0))
                    service["progress"] = float(service.get("base_total", 1.0))
                    service["direction"] = -1
                    service["lane_shift"] = -1.0
                    service["destination_mode"] = false
                    service["destination_name"] = ""
                    service["returning"] = false
                    service["arrived"] = false
                    service["pickup_waiting"] = false
                    service["pickup_only"] = false
                    service["waiting"] = 5.0
                else:
                    service["pickup_wait_timer"] = pickup_timer
                _services[index] = service
                _place_service(service, delta)
                continue
            if bool(service.get("arrived", false)):
                continue
            var destination_wait: float = float(service.get("waiting", 0.0))
            if destination_wait > 0.0:
                service["waiting"] = maxf(0.0, destination_wait - delta)
                if float(service.get("lane_shift", 1.0)) < 1.0:
                    var turning: Dictionary = service.duplicate()
                    turning["lane_shift"] = minf(1.0, float(service.get("lane_shift", -1.0)) + delta * 0.52)
                    if _swept_pose_is_clear(index, turning):
                        service = turning
                        service["blocked_duration"] = 0.0
                        service["traffic_warning_issued"] = false
                    else:
                        service["waiting"] = destination_wait
                        _note_pose_wait(index, service, turning, delta, "turnaround")
                    _services[index] = service
                    _place_service(service, delta)
                else:
                    _services[index] = service
                continue
            var destination_speed: float = float(service.get("speed", 8.0))
            var destination_progress: float = float(service.get("progress", 0.0))
            var destination_total: float = float(service.get("total", 1.0))
            if bool(service.get("returning", false)):
                destination_progress = maxf(0.0, destination_progress - destination_speed * delta)
                if not _attempt_traffic_advance(index, destination_progress, delta):
                    continue
                service = _services[index]
                service["progress"] = destination_progress
                if destination_progress <= 0.0:
                    # The destination route begins at the exact boarding position,
                    # so restoring the pickup/base route is spatially continuous.
                    service["points"] = service.get("base_points", []).duplicate()
                    service["total"] = float(service.get("base_total", 1.0))
                    service["progress"] = float(service.get("base_progress", 0.0))
                    service["direction"] = int(service.get("base_direction", 1))
                    service["lane_shift"] = float(service.get("base_lane_shift", 1.0))
                    service["parking_blend"] = float(service.get("base_parking_blend", 0.0))
                    service["destination_mode"] = false
                    service["destination_name"] = ""
                    service["returning"] = false
                    service["waiting"] = 8.0
                    service["at_stop_index"] = int(service.get("base_at_stop_index", 0))
            else:
                destination_progress = minf(destination_total, destination_progress + destination_speed * delta)
                if not _attempt_traffic_advance(index, destination_progress, delta):
                    continue
                service = _services[index]
                service["progress"] = destination_progress
                if destination_progress >= destination_total:
                    service["arrived"] = true
                    if bool(service.get("pickup_only", false)):
                        service["pickup_waiting"] = true
                        service["pickup_wait_timer"] = 45.0
                        _set_stop_status(str(service.get("destination_name", "")), "SHUTTLE HERE")
            _services[index] = service
            _place_service(service, delta)
            continue
        if bool(service.get("arrived", false)):
            continue
        var waiting: float = float(service.get("waiting", 0.0))
        if waiting > 0.0:
            service["waiting"] = maxf(0.0, waiting - delta)
            if float(service.get("lane_shift", 1.0)) < 1.0:
                var turning: Dictionary = service.duplicate()
                turning["lane_shift"] = minf(1.0, float(service.get("lane_shift", -1.0)) + delta * 0.5)
                if _swept_pose_is_clear(index, turning):
                    service = turning
                    service["blocked_duration"] = 0.0
                    service["traffic_warning_issued"] = false
                else:
                    service["waiting"] = waiting
                    _note_pose_wait(index, service, turning, delta, "turnaround")
                _services[index] = service
                _place_service(service, delta)
            else:
                _services[index] = service
            continue
        var travel_direction: int = int(service.get("direction", 1))
        var speed: float = float(service.get("speed", 8.0))
        var progress: float = float(service.get("progress", 0.0))
        var total: float = float(service.get("total", 1.0))
        progress = clampf(progress + float(travel_direction) * speed * delta, 0.0, total)
        if not _attempt_traffic_advance(index, progress, delta):
            continue
        service = _services[index]
        service["progress"] = progress
        var reached_end: bool = travel_direction == 1 and progress >= total
        var reached_start: bool = travel_direction == -1 and progress <= 0.0
        if reached_end or reached_start:
            if bool(service.get("pickup_dispatch", false)) and reached_start:
                # A dispatched shuttle has completed its return to the exact point on
                # its normal loop where it was called. Restore the loop state there.
                service["points"] = service.get("loop_points", []).duplicate()
                service["total"] = float(service.get("loop_total", 1.0))
                service["progress"] = float(service.get("loop_progress", 0.0))
                service["direction"] = int(service.get("loop_direction", 1))
                service["lane_shift"] = float(service.get("loop_lane_shift", 1.0))
                service["parking_blend"] = float(service.get("loop_parking_blend", 0.0))
                service["at_stop_index"] = int(service.get("loop_at_stop_index", 0))
                service["pickup_dispatch"] = false
                service["pickup_only"] = false
                service["pickup_waiting"] = false
                service["waiting"] = 8.0
            else:
                service["at_stop_index"] = 1 if reached_end else 0
                service["direction"] = -travel_direction
                # Hold at the stop while gradually changing lane and heading.
                service["lane_shift"] = -1.0
                service["waiting"] = 9.0
        _services[index] = service
        _place_service(service, delta)

func _note_pose_wait(index: int, service: Dictionary, proposed: Dictionary, delta: float, reason: String) -> void:
    service["blocked_duration"] = float(service.get("blocked_duration", 0.0)) + delta
    service["traffic_reason"] = reason
    var state: Array = _point_and_heading(proposed)
    service["traffic_blocker"] = -1
    for other_index in range(_services.size()):
        if other_index == index:
            continue
        var other: Node3D = _services[other_index].node
        if _vehicle_rectangles_overlap(Vector2(state[0].x, state[0].z), float(state[1]), Vector2(other.position.x, other.position.z), other.rotation.y):
            service["traffic_blocker"] = other_index
            break
    if float(service.blocked_duration) > 25.0 and not service.get("traffic_warning_issued", false):
        service["traffic_warning_issued"] = true
        push_warning("Shuttle still waiting at bottleneck: " + str(service.get("name", "shuttle")) + ". Blocked " + reason + ".")
        traffic_safe_wait.emit(str(service.get("id", "")), reason)

func _attempt_traffic_advance(index: int, proposed_progress: float, delta: float) -> bool:
    # No colliding or teleporting: a standing bus is asked to clear the road;
    # otherwise a lower-priority bus reverses only on its existing valid route.
    if _safe_to_advance(index, proposed_progress):
        var moving: Dictionary = _services[index]
        moving["blocked_duration"] = 0.0
        moving["yield_retreat_distance"] = 0.0
        moving["force_yield"] = false
        moving["traffic_warning_issued"] = false
        moving["traffic_reason"] = ""
        moving["traffic_blocker"] = -1
        _services[index] = moving
        return true
    var blocked: Dictionary = _services[index]
    var elapsed: float = float(blocked.get("blocked_duration", 0.0)) + delta
    blocked["blocked_duration"] = elapsed
    var probe: Dictionary = blocked.duplicate()
    probe.progress = proposed_progress
    blocked["traffic_reason"] = "reservation" if not _reservations.permits(self, index, probe) else "vehicle"
    blocked["traffic_blocker"] = _find_traffic_blocker(index, proposed_progress)
    _services[index] = blocked
    if elapsed >= HORN_WAIT_SECONDS and float(blocked.get("horn_cooldown", 0.0)) <= 0.0:
        var obstructing_index: int = _find_traffic_blocker(index, proposed_progress)
        _sound_horn(index)
        blocked = _services[index]
        blocked["horn_cooldown"] = HORN_REPEAT_SECONDS
        _services[index] = blocked
        if obstructing_index >= 0:
            var front_bus: Dictionary = _services[obstructing_index]
            if not bool(front_bus.get("menu_hold", false)) and not bool(front_bus.get("passenger", false)):
                # A parked shuttle responds to the horn by clearing its bay;
                # a waiting shuttle may leave its stop early.
                if float(front_bus.get("waiting", 0.0)) > 0.0:
                    front_bus["waiting"] = 0.0
                if _must_yield_to_higher_priority(obstructing_index):
                    front_bus["force_yield"] = true
                _services[obstructing_index] = front_bus
    if elapsed > 3.5 and (_must_yield_to_higher_priority(index) or bool(_services[index].get("force_yield", false))):
        var yielding: Dictionary = _services[index]
        var direction: int = int(yielding.get("direction", 1))
        if bool(yielding.get("returning", false)):
            direction = -1
        var current: float = float(yielding.get("progress", 0.0))
        var retreat_budget: float = maxf(0.0, MAX_YIELD_DISTANCE - float(yielding.get("yield_retreat_distance", 0.0)))
        var retreat: float = clampf(current - float(direction) * minf(delta * 2.8, retreat_budget), 0.0, float(yielding.get("total", 0.0)))
        if absf(retreat - current) > 0.0001 and float(yielding.get("yield_retreat_distance", 0.0)) < MAX_YIELD_DISTANCE and _safe_to_advance(index, retreat):
            yielding["progress"] = retreat
            yielding["yield_retreat_distance"] = float(yielding.get("yield_retreat_distance", 0.0)) + absf(retreat - current)
            _services[index] = yielding
            _place_service(yielding, delta)
            return false
    if elapsed > 25.0 and not bool(_services[index].get("traffic_warning_issued", false)):
        push_warning("Shuttle still waiting at bottleneck: " + str(_services[index].get("name", "shuttle")) + ". No unsafe teleport was used.")
        traffic_safe_wait.emit(str(_services[index].get("id", "")), "Blocked route; bounded retreat unavailable")
        blocked = _services[index]
        blocked["traffic_warning_issued"] = true
        _services[index] = blocked
    return false

func _find_traffic_blocker(index: int, proposed_progress: float) -> int:
    var candidate: Dictionary = _services[index].duplicate()
    candidate["progress"] = proposed_progress
    var state: Array = _point_and_heading(candidate)
    var position_2d: Vector2 = Vector2(state[0].x, state[0].z)
    var heading: float = float(state[1])
    for other_index in range(_services.size()):
        if other_index == index:
            continue
        var other: Dictionary = _services[other_index]
        var other_bus: Node3D = other.get("node") as Node3D
        if other_bus == null:
            continue
        var other_heading: float = other_bus.rotation.y
        if _vehicle_rectangles_overlap(position_2d, heading, Vector2(other_bus.position.x, other_bus.position.z), other_heading):
            return other_index
    return -1

func _sound_horn(index: int) -> void:
    # Lightweight synthetic double beep; no external audio asset required.
    var bus: Node3D = _services[index].get("node") as Node3D
    if bus == null:
        return
    var horn: AudioStreamPlayer3D = bus.get_node_or_null("Horn") as AudioStreamPlayer3D
    if horn == null:
        horn = AudioStreamPlayer3D.new()
        horn.name = "Horn"
        horn.unit_size = 12.0
        horn.max_distance = 65.0
        var stream: AudioStreamGenerator = AudioStreamGenerator.new()
        stream.mix_rate = 22050.0
        stream.buffer_length = 0.40
        horn.stream = stream
        bus.add_child(horn)
    horn.play()
    var playback: AudioStreamGeneratorPlayback = horn.get_stream_playback() as AudioStreamGeneratorPlayback
    if playback == null:
        return
    for frame_index in range(6600):
        var elapsed: float = float(frame_index) / 22050.0
        var gate: float = 1.0 if elapsed < 0.12 or elapsed > 0.17 else 0.0
        var envelope: float = minf(1.0, elapsed * 45.0) * minf(1.0, (0.30 - elapsed) * 45.0)
        var sample: float = sin(elapsed * TAU * 345.0) * 0.10 * gate * maxf(0.0, envelope)
        playback.push_frame(Vector2(sample, sample))

func _bay_position_is_clear(index: int, proposed: Dictionary) -> bool:
    var state: Array = _point_and_heading(proposed)
    var pos: Vector3 = state[0]
    var point: Vector2 = Vector2(pos.x / _scale, pos.z / _scale)
    var forward: Vector2 = Vector2(cos(float(state[1])), -sin(float(state[1])))
    # Conservative capsule includes nose, tail and corners, unlike a centre test.
    var half_length: float = (BUS_LENGTH * 0.5 + COLLISION_BUFFER) / _scale
    if not _segment_clear_of_campus_features(point - forward * half_length, point + forward * half_length, (BUS_WIDTH * 0.5 + 0.32) / _scale):
        return false
    if not vehicle_blocking:
        return true
    for other_index in range(_services.size()):
        if index == other_index:
            continue
        var other: Dictionary = _services[other_index]
        var other_bus: Node3D = other.get("node") as Node3D
        if other_bus == null:
            continue
        var other_rotation: float = float(_point_and_heading(other)[1])
        if _vehicle_rectangles_overlap(Vector2(pos.x, pos.z), float(state[1]), Vector2(other_bus.position.x, other_bus.position.z), other_rotation):
            return false
    return true

func _update_parking_bay(index: int, delta: float) -> bool:
    var service: Dictionary = _services[index]
    if bool(service.get("passenger", false)) or bool(service.get("pickup_dispatch", false)):
        return false
    # Roadside bay is only requested while a shuttle is dwelling at its terminal.
    # Vehicle may not leave the road if the bay would clip a building or a bus.
    var dwell: bool = float(service.get("waiting", 0.0)) > 0.0 or bool(service.get("menu_hold", false))
    var current: float = float(service.get("parking_blend", 0.0))
    # Merge back to the carriageway before turning; never sweep a full bay
    # offset across both lanes while changing direction.
    var turning: bool = float(service.get("lane_shift", 1.0)) < 0.9999
    var target: float = 1.0 if dwell and not turning else 0.0
    if absf(target - current) < 0.0001:
        return false
    var change: float = delta * 0.75
    var future: float = move_toward(current, target, change)
    var test: Dictionary = service.duplicate()
    test["parking_blend"] = future
    if _bay_position_is_clear(index, test) and _swept_pose_is_clear(index, test, true):
        service["parking_blend"] = future
        _services[index] = service
        _place_service(service, delta)
        # Keep road progress fixed until the bus completes a safe merge.
        return target < current or bool(service.get("menu_hold", false))
    if dwell and not bool(service.get("menu_hold", false)):
        # Never trap a bus in a stop that has no safe shoulder.
        service["waiting"] = minf(float(service.get("waiting", 0.0)), 0.55)
        _services[index] = service
    if current > 0.01 and not dwell:
        _note_pose_wait(index, service, test, delta, "bay merge")
        _services[index] = service
    # A failed outward parking attempt must still let the dwell timer expire.
    # An unsafe inward merge holds position until the carriageway is clear.
    return current > 0.01 and not dwell

func _must_yield_to_higher_priority(index: int) -> bool:
    var service: Dictionary = _services[index]
    var direction: int = -1 if service.get("returning", false) else int(service.get("direction", 1))
    var blocker: int = _find_traffic_blocker(index, clampf(float(service.progress) + direction, 0.0, float(service.total)))
    if blocker < 0:
        return false  # Queued reservations are not a reason to reverse.
    var other: Dictionary = _services[blocker]
    if other.get("menu_hold", false) or other.get("arrived", false):
        return true
    for zone in _reservations.zones:
        if zone.queue.has(index) and zone.queue.has(blocker):
            if int(zone.owner) == blocker:
                return true
            if int(zone.owner) == index:
                return false
            return int(zone.queue[blocker].ticket) < int(zone.queue[index].ticket)
    # Outside reserved areas, let the older blocked request clear first.
    var own_wait: float = float(service.get("blocked_duration", 0.0))
    var other_wait: float = float(other.get("blocked_duration", 0.0))
    if absf(own_wait - other_wait) > 0.1:
        return other_wait > own_wait
    return str(other.get("id", "")) < str(service.get("id", ""))

func _safe_to_advance(index: int, next_progress: float) -> bool:
    # A circular 8.5 m keep-out zone previously locked opposing buses nose-to-nose.
    # Compare actual oriented shuttle footprints instead; oncoming vehicles in their
    # separate lanes can pass without needing to stop.
    if index < 0 or index >= _services.size():
        return false
    var service: Dictionary = _services[index]
    var proposed: Dictionary = service.duplicate()
    proposed["progress"] = next_progress
    if vehicle_blocking and not _reservations.permits(self, index, proposed):
        return false
    if not _swept_pose_is_clear(index, proposed):
        return false
    if not vehicle_blocking:
        return true
    var proposed_state: Array = _point_and_heading(proposed)
    var position_value: Vector3 = proposed_state[0]
    var heading: float = float(proposed_state[1])
    var own_node: Node3D = service.get("node") as Node3D
    if own_node == null:
        return false
    var candidate_xz: Vector2 = Vector2(position_value.x, position_value.z)
    for other_index in range(_services.size()):
        if other_index == index:
            continue
        var other: Dictionary = _services[other_index]
        var other_node: Node3D = other.get("node") as Node3D
        if other_node == null:
            continue
        var other_state: Array = _point_and_heading(other)
        var other_position: Vector3 = other_node.position
        var other_heading: float = float(other_state[1])
        var other_xz: Vector2 = Vector2(other_position.x, other_position.z)
        # Stopped vehicles are checked by their real oriented footprints.
        # The old 11-metre exclusion bubble around waiting buses blocked
        # traffic even when a bus was fully parked inside an off-road bay.
        if _vehicle_rectangles_overlap(candidate_xz, heading, other_xz, other_heading):
            return false
    return true

func _swept_pose_is_clear(index: int, proposed: Dictionary, check_features: bool = false) -> bool:
    # Sample intermediate route poses as well as the endpoint. Bound sample spacing
    # and angular steps so a long physics tick cannot skip a stationary shuttle.
    if not vehicle_blocking and not check_features:
        return true
    var service: Dictionary = _services[index]
    var own: Node3D = service.get("node") as Node3D
    if own == null:
        return false
    var target_state: Array = _point_and_heading(proposed)
    var travel: float = absf(float(proposed.get("progress", 0.0)) - float(service.get("progress", 0.0)))
    travel = maxf(travel, own.position.distance_to(target_state[0]))
    var angle: float = absf(angle_difference(own.rotation.y, float(target_state[1])))
    var steps: int = maxi(1, maxi(int(ceil(travel / 0.25)), int(ceil(angle / deg_to_rad(5.0)))))
    for step in range(1, steps + 1):
        var t: float = float(step) / float(steps)
        var sample: Dictionary = proposed.duplicate()
        sample["progress"] = lerpf(float(service.get("progress", 0.0)), float(proposed.get("progress", 0.0)), t)
        sample["lane_shift"] = lerpf(float(service.get("lane_shift", 1.0)), float(proposed.get("lane_shift", 1.0)), t)
        sample["parking_blend"] = lerpf(float(service.get("parking_blend", 0.0)), float(proposed.get("parking_blend", 0.0)), t)
        var state: Array = _point_and_heading(sample)
        var pos: Vector3 = state[0]
        var xz: Vector2 = Vector2(pos.x, pos.z)
        # Include the rendered body's rotation, which can lag the route tangent.
        for heading in [float(state[1]), lerp_angle(own.rotation.y, float(target_state[1]), t)]:
            if check_features:
                var forward: Vector2 = Vector2(cos(heading), -sin(heading))
                var half_length: float = (BUS_LENGTH * 0.5 + COLLISION_BUFFER) / _scale
                if not _segment_clear_of_campus_features(xz / _scale - forward * half_length, xz / _scale + forward * half_length, (BUS_WIDTH * 0.5 + 0.32) / _scale):
                    return false
            for other_index in range(_services.size()):
                if not vehicle_blocking or other_index == index:
                    continue
                var other_node: Node3D = _services[other_index].get("node") as Node3D
                if other_node != null and _vehicle_rectangles_overlap(xz, heading, Vector2(other_node.position.x, other_node.position.z), other_node.rotation.y):
                    return false
    return true

func _vehicle_rectangles_overlap(a_position: Vector2, a_heading: float, b_position: Vector2, b_heading: float) -> bool:
    # SAT collision for two oriented 6.6 m x 2.35 m shuttle rectangles in XZ.
    # Unlike circles, this allows two buses travelling side by side to pass.
    var a_front: Vector2 = Vector2(cos(a_heading), -sin(a_heading))
    var b_front: Vector2 = Vector2(cos(b_heading), -sin(b_heading))
    var a_side: Vector2 = Vector2(-a_front.y, a_front.x)
    var b_side: Vector2 = Vector2(-b_front.y, b_front.x)
    var half_length: float = BUS_LENGTH * 0.5 + COLLISION_BUFFER
    var half_width: float = BUS_WIDTH * 0.5 + COLLISION_BUFFER
    var relative_position: Vector2 = b_position - a_position
    var axes: Array = [a_front, a_side, b_front, b_side]
    for axis_variant in axes:
        var axis: Vector2 = axis_variant
        var separation: float = absf(relative_position.dot(axis))
        var radius_a: float = half_length * absf(a_front.dot(axis)) + half_width * absf(a_side.dot(axis))
        var radius_b: float = half_length * absf(b_front.dot(axis)) + half_width * absf(b_side.dot(axis))
        if separation > radius_a + radius_b:
            return false
    return true

func _cache_road_obstacles(campus_features: Array) -> void:
    _lane_offset_cache.clear()
    _destination_footprints.clear()
    for feature_variant in campus_features:
        var feature: Dictionary = feature_variant
        var feature_position: Array = feature.get("position", [0.0, 0.0])
        var feature_size: Array = feature.get("size", [4.0, 4.0])
        _destination_footprints.append({
            "name": str(feature.get("name", "")),
            "kind": str(feature.get("kind", "academic")),
            "position": Vector2(float(feature_position[0]), float(feature_position[1])),
            "size": Vector2(float(feature_size[0]), float(feature_size[1]))
        })

func _endpoint_gap_is_clear(a: Vector2, b: Vector2) -> bool:
    # Endpoint repairs use the same vehicle-clearance guard as normal road segments.
    return _segment_clear_of_campus_features(a, b, 1.2)

func _segment_clear_of_campus_features(a: Vector2, b: Vector2, clearance: float = 1.2) -> bool:
    for obstacle_variant in _destination_footprints:
        var obstacle: Dictionary = obstacle_variant
        var kind: String = str(obstacle.get("kind", ""))
        if kind == "landmark" or kind == "unverified":
            continue
        var centre: Vector2 = obstacle.get("position", Vector2.ZERO)
        var size: Vector2 = obstacle.get("size", Vector2(4.0, 4.0))
        if _segment_intersects_expanded_rect(a, b, centre, size, clearance):
            return false
    return true

func _segment_intersects_expanded_rect(a: Vector2, b: Vector2, centre: Vector2, size: Vector2, margin: float) -> bool:
    # Exact segment-vs-expanded-AABB test in map coordinates (not sparse point sampling).
    var min_x: float = centre.x - size.x * 0.5 - margin
    var max_x: float = centre.x + size.x * 0.5 + margin
    var min_y: float = centre.y - size.y * 0.5 - margin
    var max_y: float = centre.y + size.y * 0.5 + margin
    var dx: float = b.x - a.x
    var dy: float = b.y - a.y
    var p_values: Array = [-dx, dx, -dy, dy]
    var q_values: Array = [a.x - min_x, max_x - a.x, a.y - min_y, max_y - a.y]
    var t_min: float = 0.0
    var t_max: float = 1.0
    for i in range(4):
        var p_value: float = float(p_values[i])
        var q_value: float = float(q_values[i])
        if absf(p_value) < 0.000001:
            if q_value < 0.0:
                return false
        else:
            var ratio: float = q_value / p_value
            if p_value < 0.0:
                if ratio > t_max:
                    return false
                t_min = maxf(t_min, ratio)
            else:
                if ratio < t_min:
                    return false
                t_max = minf(t_max, ratio)
            if t_min > t_max:
                return false
    return t_min <= t_max

func _build_road_graph(road_data: Dictionary) -> void:
    # Build a true road graph from the approved road centre-lines. We split only at
    # real segment intersections and join only very small route-endpoint gaps.
    # We deliberately DO NOT connect every pair of nearby points: that made buses
    # cut diagonally across blocks and buildings in the previous version.
    _road_nodes.clear()
    _road_adjacency.clear()
    _road_component_ids.clear()
    var segments: Array = []
    var route_endpoints: Array = []
    var raw_routes: Array = road_data.get("road_routes", [])
    for route_index in range(raw_routes.size()):
        var route: Dictionary = raw_routes[route_index]
        var route_points: Array = []
        for raw_point in route.get("points", []):
            var coords: Array = raw_point
            route_points.append(Vector2(float(coords[0]), float(coords[1])))
        if route_points.size() < 2:
            continue
        route_endpoints.append({"route": route_index, "point": route_points[0]})
        route_endpoints.append({"route": route_index, "point": route_points[route_points.size() - 1]})
        for segment_index in range(route_points.size() - 1):
            var a: Vector2 = route_points[segment_index]
            var b: Vector2 = route_points[segment_index + 1]
            if a.distance_to(b) < 0.001:
                continue
            # Fail-safe: a vehicle route must never pass through a building, playing field,
            # garden, market footprint or other protected campus site. The source road data
            # is also audited at build time; this guard prevents future regressions.
            if not _segment_clear_of_campus_features(a, b, 1.2):
                push_warning("Rejected unsafe shuttle road segment on route %s, segment %s." % [str(route.get("id", route_index)), str(segment_index)])
                continue
            segments.append({
                "route": route_index,
                "segment": segment_index,
                "a": a,
                "b": b,
                "splits": [
                    {"t": 0.0, "point": a},
                    {"t": 1.0, "point": b}
                ]
            })

    # Find true intersections before creating graph edges so a junction is shared
    # by both routes instead of being approximated by a long diagonal shortcut.
    for i in range(segments.size()):
        var first: Dictionary = segments[i]
        for j in range(i + 1, segments.size()):
            var second: Dictionary = segments[j]
            if int(first["route"]) == int(second["route"]) and abs(int(first["segment"]) - int(second["segment"])) <= 1:
                continue
            var hits: Array = _segment_intersection_points(first, second)
            for hit_variant in hits:
                var hit: Dictionary = hit_variant
                _append_segment_split(segments, i, float(hit["t_a"]), hit["point"])
                _append_segment_split(segments, j, float(hit["t_b"]), hit["point"])

    for segment_variant in segments:
        var segment: Dictionary = segment_variant
        var splits: Array = segment["splits"]
        splits.sort_custom(Callable(self, "_split_point_compare"))
        var previous_index: int = -1
        for split_variant in splits:
            var split: Dictionary = split_variant
            var point: Vector2 = split["point"]
            var node_index: int = _get_or_add_road_node(point)
            if previous_index >= 0 and previous_index != node_index:
                _connect_road_nodes(previous_index, node_index)
            previous_index = node_index

    # The trace has a few tiny gaps at obvious route ends. Close only endpoint-to-
    # endpoint gaps of <= 1 map unit; never connect an interior point to a nearby
    # vertex just because it happens to be close.
    for i in range(route_endpoints.size()):
        var first_end: Dictionary = route_endpoints[i]
        var first_point: Vector2 = first_end["point"]
        var first_node: int = _get_or_add_road_node(first_point)
        for j in range(i + 1, route_endpoints.size()):
            var second_end: Dictionary = route_endpoints[j]
            if int(first_end["route"]) == int(second_end["route"]):
                continue
            var second_point: Vector2 = second_end["point"]
            var gap: float = first_point.distance_to(second_point)
            if gap > 0.02 and gap <= 1.0 and _endpoint_gap_is_clear(first_point, second_point):
                var second_node: int = _get_or_add_road_node(second_point)
                _connect_road_nodes(first_node, second_node)

    _label_road_components()
    # Real multi-arm intersections receive deterministic right-of-way handling.
    _junction_positions.clear()
    for node_index in range(_road_nodes.size()):
        if _road_adjacency[node_index].size() >= 3:
            var raw_junction: Vector2 = _road_nodes[node_index]
            _junction_positions.append(Vector2(raw_junction.x * _scale, raw_junction.y * _scale))

func _segment_intersection_points(first: Dictionary, second: Dictionary) -> Array:
    var hits: Array = []
    var a: Vector2 = first["a"]
    var b: Vector2 = first["b"]
    var c: Vector2 = second["a"]
    var d: Vector2 = second["b"]
    var r: Vector2 = b - a
    var s: Vector2 = d - c
    var denominator: float = _cross_2d(r, s)
    var offset: Vector2 = c - a

    if absf(denominator) > 0.00001:
        var t_a: float = _cross_2d(offset, s) / denominator
        var t_b: float = _cross_2d(offset, r) / denominator
        if t_a >= -0.00001 and t_a <= 1.00001 and t_b >= -0.00001 and t_b <= 1.00001:
            var safe_t_a: float = clampf(t_a, 0.0, 1.0)
            var safe_t_b: float = clampf(t_b, 0.0, 1.0)
            var point: Vector2 = a + r * safe_t_a
            hits.append({"t_a": safe_t_a, "t_b": safe_t_b, "point": point})
        return hits

    # Parallel lines are only joined when collinear and sharing an actual point.
    if absf(_cross_2d(offset, r)) > 0.0001:
        return hits
    var first_endpoints: Array = [{"point": a, "t": 0.0}, {"point": b, "t": 1.0}]
    for endpoint_variant in first_endpoints:
        var endpoint: Dictionary = endpoint_variant
        var point_a: Vector2 = endpoint["point"]
        var t_b_collinear: float = _raw_segment_parameter(point_a, c, d)
        var projected_b: Vector2 = c + s * t_b_collinear
        if t_b_collinear >= -0.00001 and t_b_collinear <= 1.00001 and projected_b.distance_to(point_a) < 0.001:
            hits.append({"t_a": float(endpoint["t"]), "t_b": clampf(t_b_collinear, 0.0, 1.0), "point": point_a})
    var second_endpoints: Array = [{"point": c, "t": 0.0}, {"point": d, "t": 1.0}]
    for endpoint_b_variant in second_endpoints:
        var endpoint_b: Dictionary = endpoint_b_variant
        var point_b: Vector2 = endpoint_b["point"]
        var t_a_collinear: float = _raw_segment_parameter(point_b, a, b)
        var projected_a: Vector2 = a + r * t_a_collinear
        if t_a_collinear >= -0.00001 and t_a_collinear <= 1.00001 and projected_a.distance_to(point_b) < 0.001:
            hits.append({"t_a": clampf(t_a_collinear, 0.0, 1.0), "t_b": float(endpoint_b["t"]), "point": point_b})
    return hits

func _cross_2d(a: Vector2, b: Vector2) -> float:
    return a.x * b.y - a.y * b.x

func _raw_segment_parameter(point: Vector2, a: Vector2, b: Vector2) -> float:
    var segment: Vector2 = b - a
    var length_squared: float = segment.length_squared()
    if length_squared < 0.000001:
        return 0.0
    return (point - a).dot(segment) / length_squared

func _segment_parameter(point: Vector2, a: Vector2, b: Vector2) -> float:
    return clampf(_raw_segment_parameter(point, a, b), 0.0, 1.0)

func _append_segment_split(segments: Array, segment_index: int, t: float, point: Vector2) -> void:
    var segment: Dictionary = segments[segment_index]
    var splits: Array = segment["splits"]
    var safe_t: float = clampf(t, 0.0, 1.0)
    for split_variant in splits:
        var split: Dictionary = split_variant
        if absf(float(split["t"]) - safe_t) < 0.0001:
            return
    splits.append({"t": safe_t, "point": point})
    segment["splits"] = splits
    segments[segment_index] = segment

func _split_point_compare(left: Dictionary, right: Dictionary) -> bool:
    return float(left.get("t", 0.0)) < float(right.get("t", 0.0))

func _get_or_add_road_node(point: Vector2) -> int:
    for i in range(_road_nodes.size()):
        var existing: Vector2 = _road_nodes[i]
        if existing.distance_to(point) < 0.02:
            return i
    _road_nodes.append(point)
    _road_adjacency.append({})
    return _road_nodes.size() - 1

func _connect_road_nodes(a: int, b: int) -> void:
    if a == b or a < 0 or b < 0 or a >= _road_nodes.size() or b >= _road_nodes.size():
        return
    var distance: float = _road_nodes[a].distance_to(_road_nodes[b])
    if distance < 0.0001:
        return
    var neighbours_a: Dictionary = _road_adjacency[a]
    var neighbours_b: Dictionary = _road_adjacency[b]
    neighbours_a[b] = distance
    neighbours_b[a] = distance
    _road_adjacency[a] = neighbours_a
    _road_adjacency[b] = neighbours_b

func _label_road_components() -> void:
    _road_component_ids.clear()
    for _i in range(_road_nodes.size()):
        _road_component_ids.append(-1)
    var component_id: int = 0
    for start in range(_road_nodes.size()):
        if int(_road_component_ids[start]) >= 0:
            continue
        var queue: Array = [start]
        _road_component_ids[start] = component_id
        var queue_index: int = 0
        while queue_index < queue.size():
            var current: int = int(queue[queue_index])
            queue_index += 1
            var neighbours: Dictionary = _road_adjacency[current]
            for neighbour_variant in neighbours.keys():
                var neighbour: int = int(neighbour_variant)
                if int(_road_component_ids[neighbour]) < 0:
                    _road_component_ids[neighbour] = component_id
                    queue.append(neighbour)
        component_id += 1

func _nearest_road_edge(point: Vector2, required_component: int = -1) -> Dictionary:
    var best: Dictionary = {}
    var best_distance: float = 1.0e20
    for i in range(_road_adjacency.size()):
        var neighbours: Dictionary = _road_adjacency[i]
        for neighbour_variant in neighbours.keys():
            var j: int = int(neighbour_variant)
            if j <= i:
                continue
            if required_component >= 0:
                if int(_road_component_ids[i]) != required_component or int(_road_component_ids[j]) != required_component:
                    continue
            var a: Vector2 = _road_nodes[i]
            var b: Vector2 = _road_nodes[j]
            var t: float = _segment_parameter(point, a, b)
            var projected: Vector2 = a.lerp(b, t)
            var distance: float = point.distance_to(projected)
            if distance < best_distance:
                best_distance = distance
                best = {"a": i, "b": j, "t": t, "point": projected, "distance": distance}
    return best

func _connect_local_nodes(adjacency: Array, a: int, b: int, weight: float) -> void:
    if a == b or a < 0 or b < 0 or a >= adjacency.size() or b >= adjacency.size():
        return
    var neighbours_a: Dictionary = adjacency[a]
    var neighbours_b: Dictionary = adjacency[b]
    neighbours_a[b] = maxf(0.0, weight)
    neighbours_b[a] = maxf(0.0, weight)
    adjacency[a] = neighbours_a
    adjacency[b] = neighbours_b

func _shortest_path_indices(adjacency: Array, start_index: int, end_index: int) -> Array:
    var result: Array = []
    var node_count: int = adjacency.size()
    if start_index < 0 or end_index < 0 or node_count == 0:
        return result
    var distances: Array = []
    var previous: Array = []
    var visited: Array = []
    for _i in range(node_count):
        distances.append(1.0e20)
        previous.append(-1)
        visited.append(false)
    distances[start_index] = 0.0
    for _iteration in range(node_count):
        var current: int = -1
        var current_distance: float = 1.0e20
        for i in range(node_count):
            if not bool(visited[i]) and float(distances[i]) < current_distance:
                current_distance = float(distances[i])
                current = i
        if current < 0 or current == end_index:
            break
        visited[current] = true
        var neighbours: Dictionary = adjacency[current]
        for neighbour_variant in neighbours.keys():
            var neighbour: int = int(neighbour_variant)
            var candidate_distance: float = float(distances[current]) + float(neighbours[neighbour_variant])
            if candidate_distance < float(distances[neighbour]):
                distances[neighbour] = candidate_distance
                previous[neighbour] = current
    if start_index != end_index and int(previous[end_index]) < 0:
        return result
    var cursor: int = end_index
    for _step in range(node_count + 1):
        result.append(cursor)
        if cursor == start_index:
            break
        cursor = int(previous[cursor])
        if cursor < 0:
            result.clear()
            return result
    result.reverse()
    return result

func _road_path_between(start_raw: Vector2, target_raw: Vector2) -> Array:
    var result: Array = []
    var start_snap: Dictionary = _nearest_road_edge(start_raw, _main_component_id)
    if start_snap.is_empty():
        start_snap = _nearest_road_edge(start_raw)
    if start_snap.is_empty():
        return result
    # Initial shelter centres can sit on the pavement side of the carriageway.
    # We project them onto a real road edge, then drive from that projected point;
    # we never add a straight off-road connector from a shelter into the route.
    if float(start_snap.get("distance", 1.0e20)) > 5.0:
        return result
    var start_component: int = int(_road_component_ids[int(start_snap["a"])])
    var nearest_target_anywhere: Dictionary = _nearest_road_edge(target_raw)
    if nearest_target_anywhere.is_empty():
        return result
    var target_component: int = int(_road_component_ids[int(nearest_target_anywhere["a"])])
    _last_route_used_fallback = target_component != start_component
    # Always route to the closest edge on the same connected component as the bus.
    # A disconnected edge-of-map segment must never be joined with a diagonal line.
    var target_snap: Dictionary = _nearest_road_edge(target_raw, start_component)
    if target_snap.is_empty():
        return result
    _last_route_access_distance = float(target_snap.get("distance", 0.0)) * _scale

    var local_nodes: Array = _road_nodes.duplicate()
    var local_adjacency: Array = []
    for i in range(_road_adjacency.size()):
        var original_neighbours: Dictionary = _road_adjacency[i]
        local_adjacency.append(original_neighbours.duplicate())

    var start_point: Vector2 = start_snap["point"]
    var target_point: Vector2 = target_snap["point"]
    var virtual_start: int = local_nodes.size()
    local_nodes.append(start_point)
    local_adjacency.append({})
    var virtual_end: int = local_nodes.size()
    local_nodes.append(target_point)
    local_adjacency.append({})

    var start_a: int = int(start_snap["a"])
    var start_b: int = int(start_snap["b"])
    var target_a: int = int(target_snap["a"])
    var target_b: int = int(target_snap["b"])
    _connect_local_nodes(local_adjacency, virtual_start, start_a, start_point.distance_to(_road_nodes[start_a]))
    _connect_local_nodes(local_adjacency, virtual_start, start_b, start_point.distance_to(_road_nodes[start_b]))
    _connect_local_nodes(local_adjacency, virtual_end, target_a, target_point.distance_to(_road_nodes[target_a]))
    _connect_local_nodes(local_adjacency, virtual_end, target_b, target_point.distance_to(_road_nodes[target_b]))
    var same_edge: bool = (start_a == target_a and start_b == target_b) or (start_a == target_b and start_b == target_a)
    if same_edge:
        _connect_local_nodes(local_adjacency, virtual_start, virtual_end, start_point.distance_to(target_point))

    var path_indices: Array = _shortest_path_indices(local_adjacency, virtual_start, virtual_end)
    if path_indices.size() < 2:
        return result
    for node_variant in path_indices:
        result.append(local_nodes[int(node_variant)])
    return result

func prepare_destination(bus: Node3D, target_raw: Vector2, target_name: String) -> bool:
    var service_index: int = _find_service(bus)
    if service_index < 0 or _road_nodes.is_empty():
        return false
    var service: Dictionary = _services[service_index]
    if bool(service.get("passenger", false)) or bool(service.get("returning", false)) or bool(service.get("destination_mode", false)):
        return false
    var start_raw: Vector2 = Vector2(bus.global_position.x / _scale, bus.global_position.z / _scale)
    var raw_path: Array = _road_path_between(start_raw, target_raw)
    if raw_path.size() < 2:
        return false

    var new_points: Array = []
    var bus_start: Vector3 = bus.global_position
    bus_start.y = _bus_y
    new_points.append(bus_start)
    for raw_point_variant in raw_path:
        var raw_point: Vector2 = raw_point_variant
        var world_point: Vector3 = Vector3(raw_point.x * _scale, _bus_y, raw_point.y * _scale)
        var last_point: Vector3 = new_points[new_points.size() - 1]
        if last_point.distance_to(world_point) > 0.08:
            new_points.append(world_point)
    if new_points.size() < 2:
        return false

    var path_length: float = 0.0
    for i in range(1, new_points.size()):
        var prior: Vector3 = new_points[i - 1]
        var later: Vector3 = new_points[i]
        path_length += prior.distance_to(later)
    if path_length < 2.0:
        return false

    service["base_points"] = service.get("points", []).duplicate()
    service["base_total"] = float(service.get("total", 1.0))
    service["base_progress"] = float(service.get("progress", 0.0))
    service["base_direction"] = int(service.get("direction", 1))
    service["base_lane_shift"] = float(service.get("lane_shift", 1.0))
    service["base_parking_blend"] = float(service.get("parking_blend", 0.0))
    service["base_at_stop_index"] = int(service.get("at_stop_index", 0))
    service["base_waiting"] = float(service.get("waiting", 0.0))
    var stop_record: Dictionary = _destination_stops.get(target_name, {})
    service["destination_stand_position"] = stop_record.get("stand_world", Vector3(bus.global_position.x, 0.25, bus.global_position.z))
    service["destination_feature_position"] = stop_record.get("feature_world", Vector3(target_raw.x * _scale, 0.25, target_raw.y * _scale))
    service["destination_walk_distance"] = float(stop_record.get("walk_distance", 0.0))
    service["points"] = new_points
    service["total"] = path_length
    service["progress"] = 0.0
    service["direction"] = 1
    service["destination_mode"] = true
    # The new path already starts at the actual lane/bay-offset bus position.
    # Applying its old parking offset again would jump the occupied bus sideways.
    service["parking_blend"] = 0.0
    service["lane_shift"] = 1.0
    service["destination_name"] = target_name
    service["returning"] = false
    service["arrived"] = false
    service["at_stop_index"] = 0
    service["destination_road_fallback"] = _last_route_used_fallback
    service["destination_access_distance"] = _last_route_access_distance
    _services[service_index] = service
    return true

func estimate_destination_minutes(bus: Node3D, destination_name: String) -> int:
    if bus == null or not _destination_stops.has(destination_name):
        return -1
    var service_index: int = _find_service(bus)
    if service_index < 0:
        return -1
    var service: Dictionary = _services[service_index]
    var start_raw: Vector2 = Vector2(bus.global_position.x / _scale, bus.global_position.z / _scale)
    var stop_record: Dictionary = _destination_stops[destination_name]
    var target_raw: Vector2 = stop_record.get("road_point", Vector2.ZERO)
    var route: Array = _road_path_between(start_raw, target_raw)
    if route.size() < 2:
        return -1
    var distance: float = 0.0
    for i in range(1, route.size()):
        var prior: Vector2 = route[i - 1]
        var later: Vector2 = route[i]
        distance += prior.distance_to(later) * _scale
    var speed: float = maxf(1.0, float(service.get("speed", 8.0)))
    return maxi(1, int(ceil(distance / speed / 60.0)))

func destination_route_note(bus: Node3D) -> String:
    var index: int = _find_service(bus)
    if index < 0:
        return ""
    var service: Dictionary = _services[index]
    var note: String = ""
    if bool(service.get("destination_road_fallback", false)):
        note = " This area is not directly connected to the mapped shuttle roads yet, so you'll alight at the nearest connected road and walk from there."
    var walk_distance: float = float(service.get("destination_walk_distance", 0.0))
    if walk_distance >= 30.0:
        note += " The stop is a little farther from the building; follow the pedestrian access path on foot."
    return note

func _centreline_position(service: Dictionary, distance_along_path: float) -> Vector3:
    # Sample a world-space road centreline at a travelled distance.
    var points: Array = service.get("points", [])
    if points.is_empty():
        return Vector3.ZERO
    if points.size() == 1:
        return points[0]
    var remaining: float = maxf(0.0, distance_along_path)
    for i in range(points.size() - 1):
        var start_point: Vector3 = points[i]
        var finish_point: Vector3 = points[i + 1]
        var segment_length: float = start_point.distance_to(finish_point)
        if segment_length < 0.001:
            continue
        if remaining <= segment_length or i == points.size() - 2:
            return start_point.lerp(finish_point, clampf(remaining / segment_length, 0.0, 1.0))
        remaining -= segment_length
    return points[points.size() - 1]

func _point_and_heading(service: Dictionary) -> Array:
    # Driving on the RIGHT side of the current travel direction gives opposing
    # traffic physically distinct lanes. Smooth tangent sampling reduces the
    # sudden side shifts at polyline corners.
    var points: Array = service.get("points", [])
    if points.is_empty():
        return [Vector3.ZERO, 0.0]
    var total: float = maxf(0.001, float(service.get("total", 0.001)))
    var progress: float = clampf(float(service.get("progress", 0.0)), 0.0, total)
    var direction: int = int(service.get("direction", 1))
    var centre: Vector3 = _centreline_position(service, progress)
    var before: Vector3 = _centreline_position(service, maxf(0.0, progress - 2.0))
    var after: Vector3 = _centreline_position(service, minf(total, progress + 2.0))
    var tangent: Vector3 = after - before
    if tangent.length_squared() < 0.0001:
        tangent = Vector3(1.0, 0.0, 0.0)
    var travel: Vector3 = tangent.normalized() * float(direction)
    var right: Vector3 = Vector3(-travel.z, 0.0, travel.x)
    # Two-way lanes must remain separated even near normal shuttle terminals.
    # Only a temporary destination route tapers smoothly at its ORIGINAL
    # boarding position (which is an already lane-offset bus world position).
    var blend: float = 1.0
    if bool(service.get("destination_mode", false)):
        blend = clampf(progress / LANE_MERGE_DISTANCE, 0.0, 1.0)
        blend = blend * blend * (3.0 - 2.0 * blend)
    var lane_shift: float = float(service.get("lane_shift", 1.0))
    var offset: float = _safe_lane_offset_at(centre)
    var parking_extra: float = float(service.get("parking_blend", 0.0)) * PARK_BAY_EXTRA_METRES
    var lane_position: Vector3 = centre + right * (offset * blend + parking_extra) * lane_shift
    return [lane_position, atan2(-travel.z, travel.x)]

func _safe_lane_offset_at(point: Vector3) -> float:
    # Reuse only exact positions within this physics tick; no quantisation or
    # approximation changes the validated clearance at tight campus corridors.
    var cache_key: Vector2 = Vector2(point.x, point.z)
    if _lane_offset_cache.has(cache_key):
        return float(_lane_offset_cache[cache_key])
    # Keep opposing lanes apart while preventing the outside wheel from
    # leaving the two tight corridors identified in the protected-map audit.
    var raw: Vector2 = Vector2(point.x / _scale, point.z / _scale)
    var local_width: float = 10.0
    for margin_world in [5.0, 4.0, 3.6, 3.1]:
        if _segment_clear_of_campus_features(raw, raw + Vector2(0.000001, 0), margin_world / _scale):
            local_width = margin_world * 2.0
            break
    var result: float = clampf(local_width * 0.5 - BUS_WIDTH * 0.5 - COLLISION_BUFFER - 0.20, 1.55, LANE_OFFSET_METRES)
    _lane_offset_cache[cache_key] = result
    return result

func _place_service(service: Dictionary, smoothing_delta: float = 0.0) -> void:
    var bus: Node3D = service["node"]
    var state: Array = _point_and_heading(service)
    bus.position = state[0]
    var target_heading: float = float(state[1])
    if smoothing_delta <= 0.0:
        bus.rotation.y = target_heading
    else:
        # Smooth the vehicle body through corners while keeping its centre on the road.
        var next_heading: float = lerp_angle(bus.rotation.y, target_heading, clampf(smoothing_delta * 14.0, 0.0, 1.0))
        var rotation_clear: bool = true
        for other in _services:
            var other_bus: Node3D = other.get("node") as Node3D
            if not vehicle_blocking or other_bus == null or other_bus == bus:
                continue
            if _vehicle_rectangles_overlap(Vector2(bus.position.x, bus.position.z), next_heading, Vector2(other_bus.position.x, other_bus.position.z), other_bus.rotation.y):
                rotation_clear = false
                break
        if rotation_clear:
            bus.rotation.y = next_heading

func _find_service(bus: Node3D) -> int:
    for i in range(_services.size()):
        var service: Dictionary = _services[i]
        if service.get("node") == bus:
            return i
    return -1

func nearest_boardable_bus(at_position: Vector3, radius: float = 7.0) -> Node3D:
    var nearest: Node3D = null
    var closest: float = radius
    for item in _services:
        var service: Dictionary = item
        if bool(service.get("passenger", false)) or bool(service.get("returning", false)):
            continue
        var pickup_waiting: bool = bool(service.get("pickup_waiting", false))
        if bool(service.get("destination_mode", false)) and bool(service.get("arrived", false)) and not pickup_waiting:
            continue
        if float(service.get("waiting", 0.0)) <= 0.0 and not bool(service.get("menu_hold", false)) and not pickup_waiting:
            continue
        var bus: Node3D = service["node"]
        var horizontal: Vector2 = Vector2(bus.global_position.x - at_position.x, bus.global_position.z - at_position.z)
        if horizontal.length() < closest:
            closest = horizontal.length()
            nearest = bus
    return nearest

func nearest_destination_stop_name(at_position: Vector3, radius: float = 3.0) -> String:
    var nearest_name: String = ""
    var closest: float = radius
    for name_variant in _destination_stops.keys():
        var stop_name: String = str(name_variant)
        var record: Dictionary = _destination_stops[stop_name]
        var stand: Vector3 = record.get("stand_world", Vector3.ZERO)
        var distance: float = Vector2(stand.x - at_position.x, stand.z - at_position.z).length()
        if distance < closest:
            closest = distance
            nearest_name = stop_name
    return nearest_name

func estimate_pickup_minutes(stop_name: String) -> int:
    var stop_record: Dictionary = _destination_stops.get(stop_name, {})
    if stop_record.is_empty():
        return -1
    var target_raw: Vector2 = stop_record.get("road_point", Vector2.ZERO)
    var best_seconds: float = 1.0e20
    for service_variant in _services:
        var service: Dictionary = service_variant
        if bool(service.get("passenger", false)) or bool(service.get("returning", false)) or bool(service.get("destination_mode", false)) or bool(service.get("menu_hold", false)) or bool(service.get("pickup_dispatch", false)):
            continue
        var bus: Node3D = service.get("node") as Node3D
        if bus == null:
            continue
        var start_raw: Vector2 = Vector2(bus.global_position.x / _scale, bus.global_position.z / _scale)
        var route: Array = _road_path_between(start_raw, target_raw)
        if route.size() < 2:
            continue
        var distance: float = 0.0
        for i in range(1, route.size()):
            var prior: Vector2 = route[i - 1]
            var later: Vector2 = route[i]
            distance += prior.distance_to(later) * _scale
        var speed: float = maxf(1.0, float(service.get("speed", 8.0)))
        best_seconds = minf(best_seconds, distance / speed)
    if best_seconds >= 1.0e19:
        return -1
    return maxi(1, int(ceil(best_seconds / 60.0)))

func has_pickup_en_route_to_stop(stop_name: String) -> bool:
    var requested_record: Dictionary = _destination_stops.get(stop_name, {})
    if requested_record.is_empty():
        return false
    var requested_stand: Vector3 = requested_record.get("stand_world", Vector3.ZERO)
    for service_variant in _services:
        var service: Dictionary = service_variant
        if not bool(service.get("pickup_only", false)) or not bool(service.get("destination_mode", false)):
            continue
        if bool(service.get("pickup_waiting", false)):
            continue
        var dispatched_stand: Vector3 = service.get("destination_stand_position", Vector3.ZERO)
        var distance: float = Vector2(dispatched_stand.x - requested_stand.x, dispatched_stand.z - requested_stand.z).length()
        if distance <= 5.0:
            return true
    return false

func request_pickup(stop_name: String) -> bool:
    var stop_record: Dictionary = _destination_stops.get(stop_name, {})
    if stop_record.is_empty():
        return false
    var target_raw: Vector2 = stop_record.get("road_point", Vector2.ZERO)
    var target_world: Vector3 = stop_record.get("road_world", Vector3(target_raw.x * _scale, _bus_y, target_raw.y * _scale))
    var stand_world: Vector3 = stop_record.get("stand_world", Vector3(target_raw.x * _scale, 0.25, target_raw.y * _scale))
    var attempted: Array[int] = []
    for _attempt in range(_services.size()):
        var nearest_index: int = -1
        var nearest_distance: float = 1.0e20
        for index in range(_services.size()):
            if attempted.has(index):
                continue
            var service: Dictionary = _services[index]
            if bool(service.get("passenger", false)) or bool(service.get("returning", false)) or bool(service.get("destination_mode", false)) or bool(service.get("menu_hold", false)) or bool(service.get("pickup_dispatch", false)):
                continue
            var bus: Node3D = service.get("node") as Node3D
            if bus == null:
                continue
            var distance: float = Vector2(bus.global_position.x - target_world.x, bus.global_position.z - target_world.z).length()
            if distance < nearest_distance:
                nearest_distance = distance
                nearest_index = index
        if nearest_index < 0:
            break
        attempted.append(nearest_index)
        var candidate_bus: Node3D = _services[nearest_index].get("node") as Node3D
        if candidate_bus == null or not prepare_destination(candidate_bus, target_raw, stop_name):
            continue
        var service_index: int = _find_service(candidate_bus)
        if service_index < 0:
            continue
        var service: Dictionary = _services[service_index]
        # Preserve the normal shuttle loop separately. The pickup path becomes a
        # temporary base route so the bus can return to its original loop position
        # after the passenger's ride, without teleporting.
        service["loop_points"] = service.get("base_points", []).duplicate()
        service["loop_total"] = float(service.get("base_total", 1.0))
        service["loop_progress"] = float(service.get("base_progress", 0.0))
        service["loop_direction"] = int(service.get("base_direction", 1))
        service["loop_lane_shift"] = float(service.get("base_lane_shift", 1.0))
        service["loop_parking_blend"] = float(service.get("base_parking_blend", 0.0))
        service["loop_at_stop_index"] = int(service.get("base_at_stop_index", 0))
        var pickup_points: Array = service.get("points", []).duplicate()
        var pickup_total: float = float(service.get("total", 1.0))
        service["base_points"] = pickup_points.duplicate()
        service["base_total"] = pickup_total
        service["base_progress"] = pickup_total
        service["base_direction"] = -1
        service["base_lane_shift"] = -1.0
        service["base_parking_blend"] = 0.0
        service["base_at_stop_index"] = int(service.get("loop_at_stop_index", 0))
        service["destination_stand_position"] = stand_world
        service["destination_feature_position"] = stop_record.get("feature_world", stand_world)
        service["destination_walk_distance"] = float(stop_record.get("walk_distance", 0.0))
        service["destination_name"] = stop_name
        service["destination_mode"] = true
        service["returning"] = false
        service["arrived"] = false
        service["passenger"] = false
        service["menu_hold"] = false
        service["waiting"] = 0.0
        service["pickup_dispatch"] = true
        service["pickup_only"] = true
        service["pickup_waiting"] = false
        service["pickup_wait_timer"] = 0.0
        _services[service_index] = service
        _set_stop_status(stop_name, "SHUTTLE COMING")
        _place_service(service, 0.016)
        return true
    return false

func prepare_for_pickup_boarding(bus: Node3D) -> bool:
    var index: int = _find_service(bus)
    if index < 0:
        return false
    var service: Dictionary = _services[index]
    if not bool(service.get("pickup_waiting", false)):
        return false
    # The pickup path is now the route base for the passenger trip. Its end point is
    # exactly the current bus position, so the transition is continuous.
    service["points"] = service.get("base_points", []).duplicate()
    service["total"] = float(service.get("base_total", 1.0))
    service["progress"] = float(service.get("base_progress", 0.0))
    service["direction"] = int(service.get("base_direction", -1))
    service["lane_shift"] = -1.0
    service["destination_mode"] = false
    service["destination_name"] = ""
    service["returning"] = false
    service["arrived"] = false
    service["pickup_only"] = false
    service["pickup_waiting"] = false
    service["pickup_wait_timer"] = 0.0
    service["waiting"] = 9.0
    service["menu_hold"] = false
    _services[index] = service
    return true

func set_menu_hold(bus: Node3D, enabled: bool) -> void:
    var index: int = _find_service(bus)
    if index < 0:
        return
    var service: Dictionary = _services[index]
    service["menu_hold"] = enabled
    _services[index] = service

func current_stop_name(bus: Node3D) -> String:
    var index: int = _find_service(bus)
    if index < 0:
        return "Unknown stop"
    var service: Dictionary = _services[index]
    if bool(service.get("destination_mode", false)) and bool(service.get("arrived", false)):
        return str(service.get("destination_name", "Campus destination"))
    var ids: Array = service["stop_ids"]
    var stop_id: String = str(ids[int(service["at_stop_index"])])
    return str(_shelter_names.get(stop_id, stop_id))

func next_stop_name(bus: Node3D) -> String:
    var index: int = _find_service(bus)
    if index < 0:
        return "Unknown destination"
    var service: Dictionary = _services[index]
    if bool(service.get("destination_mode", false)):
        return str(service.get("destination_name", "Campus destination"))
    var ids: Array = service["stop_ids"]
    var next_index: int = 1 - int(service["at_stop_index"])
    var stop_id: String = str(ids[next_index])
    return str(_shelter_names.get(stop_id, stop_id))

func line_name(bus: Node3D) -> String:
    var index: int = _find_service(bus)
    if index < 0:
        return "Campus shuttle"
    var service: Dictionary = _services[index]
    return str(service.get("name", "Campus shuttle"))

func board(bus: Node3D) -> bool:
    var index: int = _find_service(bus)
    if index < 0:
        return false
    var service: Dictionary = _services[index]
    if bool(service.get("passenger", false)):
        return false
    service["passenger"] = true
    service["menu_hold"] = false
    service["arrived"] = false
    service["waiting"] = 1.6
    _services[index] = service
    return true

func finish_quick_travel(bus: Node3D) -> void:
    # Quick travel skips only the viewing animation. The shuttle itself stays at its
    # original road position and resumes its base loop without teleporting.
    var index: int = _find_service(bus)
    if index < 0:
        return
    var service: Dictionary = _services[index]
    if not bool(service.get("destination_mode", false)):
        return
    service["points"] = service.get("base_points", []).duplicate()
    service["total"] = float(service.get("base_total", 1.0))
    service["progress"] = float(service.get("base_progress", 0.0))
    service["direction"] = int(service.get("base_direction", 1))
    service["lane_shift"] = float(service.get("base_lane_shift", 1.0))
    service["parking_blend"] = float(service.get("base_parking_blend", 0.0))
    service["at_stop_index"] = int(service.get("base_at_stop_index", 0))
    service["waiting"] = maxf(float(service.get("base_waiting", 0.0)), 2.0)
    service["destination_mode"] = false
    service["destination_name"] = ""
    service["returning"] = false
    service["arrived"] = false
    service["passenger"] = false
    _services[index] = service
    _place_service(service, 0.016)

func destination_road_target(destination_name: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
    var stop_record: Dictionary = _destination_stops.get(destination_name, {})
    if stop_record.is_empty():
        return fallback
    return stop_record.get("road_point", fallback)

func destination_stand_position(destination_name: String, fallback: Vector2 = Vector2.ZERO) -> Vector3:
    var stop_record: Dictionary = _destination_stops.get(destination_name, {})
    if stop_record.is_empty():
        return Vector3(fallback.x * _scale, 0.25, fallback.y * _scale)
    return stop_record.get("stand_world", Vector3(fallback.x * _scale, 0.25, fallback.y * _scale))

func destination_walk_distance(destination_name: String) -> float:
    var stop_record: Dictionary = _destination_stops.get(destination_name, {})
    return float(stop_record.get("walk_distance", 0.0))

func destination_feature_position(destination_name: String, fallback: Vector2 = Vector2.ZERO) -> Vector3:
    var stop_record: Dictionary = _destination_stops.get(destination_name, {})
    if stop_record.is_empty():
        return Vector3(fallback.x * _scale, 0.25, fallback.y * _scale)
    return stop_record.get("feature_world", Vector3(fallback.x * _scale, 0.25, fallback.y * _scale))

func is_selectable_destination(item: Dictionary) -> bool:
    var name: String = str(item.get("name", "")).strip_edges()
    var kind: String = str(item.get("kind", "academic"))
    var lowered: String = name.to_lower()
    if name.is_empty() or kind == "unverified":
        return false
    if lowered.contains("incomplete") or lowered.contains("almost complete"):
        return false
    if lowered.contains("junction") or lowered.begins_with("road to") or lowered.contains("unresolved") or lowered.contains("route marker"):
        return false
    if lowered.contains("road label") or lowered.contains("connecting road"):
        return false
    if kind == "landmark" and not (lowered.contains("gate") or lowered.contains("student waiting / shuttle area")):
        return false
    return true

func _largest_road_component() -> int:
    if _road_component_ids.is_empty():
        return -1
    var counts: Dictionary = {}
    for component_value in _road_component_ids:
        var component_id: int = int(component_value)
        counts[component_id] = int(counts.get(component_id, 0)) + 1
    var best_component: int = -1
    var best_count: int = -1
    for key in counts.keys():
        if int(counts[key]) > best_count:
            best_count = int(counts[key])
            best_component = int(key)
    return best_component

func _build_destination_stops(campus_features: Array, road_data: Dictionary) -> void:
    _destination_stops.clear()
    _destination_stop_visuals.clear()
    _shared_stand_positions.clear()
    # Register the existing covered shelters first. Nearby destinations reuse these
    # rather than creating duplicate poles, benches, or platforms in the same space.
    for shelter_id_variant in _shelter_positions.keys():
        var shelter_id: String = str(shelter_id_variant)
        var shelter_world: Vector3 = _shelter_positions[shelter_id]
        var shelter_raw: Vector2 = Vector2(shelter_world.x / _scale, shelter_world.z / _scale)
        var shelter_snap: Dictionary = _nearest_road_edge(shelter_raw, _main_component_id)
        var shelter_road_point: Vector2 = shelter_snap.get("point", shelter_raw)
        var toward_road: Vector2 = shelter_road_point - shelter_raw
        var shelter_stand_map: Vector2 = shelter_raw
        if toward_road.length() > 0.01:
            shelter_stand_map += toward_road.normalized() * 0.72
        _shared_stand_positions.append({
            "map_position": shelter_stand_map,
            "road_point": shelter_road_point,
            "node": null,
            "names": [str(_shelter_names.get(shelter_id, shelter_id))],
            "is_shelter": true,
            "shelter_id": shelter_id
        })

    var access_by_id: Dictionary = {}
    for access_variant in road_data.get("pedestrian_access", []):
        var access: Dictionary = access_variant
        access_by_id[int(access.get("feature_id", 0))] = access.get("points", [])

    for feature_variant in campus_features:
        var feature: Dictionary = feature_variant
        if not is_selectable_destination(feature):
            continue
        var feature_name: String = str(feature.get("name", ""))
        var feature_coords: Array = feature.get("position", [0.0, 0.0])
        var feature_raw: Vector2 = Vector2(float(feature_coords[0]), float(feature_coords[1]))
        var feature_size_raw: Array = feature.get("size", [4.0, 4.0])
        var feature_size: Vector2 = Vector2(float(feature_size_raw[0]), float(feature_size_raw[1]))
        var desired_raw: Vector2 = feature_raw
        var access_distance: float = -1.0
        var access_points: Array = access_by_id.get(int(feature.get("id", 0)), [])
        if access_points.size() >= 2:
            var best_access_error: float = 1.0e20
            for access_index in range(access_points.size()):
                var access_coords: Array = access_points[access_index]
                var access_raw: Vector2 = Vector2(float(access_coords[0]), float(access_coords[1]))
                var access_snap: Dictionary = _nearest_road_edge(access_raw, _main_component_id)
                if access_snap.is_empty():
                    continue
                var access_error: float = float(access_snap.get("distance", 1.0e20))
                if access_error < best_access_error:
                    best_access_error = access_error
                    desired_raw = access_raw
            if best_access_error < 1.0e19:
                var access_start: Array = access_points[0]
                var access_end: Array = access_points[access_points.size() - 1]
                access_distance = Vector2(float(access_start[0]), float(access_start[1])).distance_to(Vector2(float(access_end[0]), float(access_end[1]))) * _scale

        var snap: Dictionary = _nearest_road_edge(desired_raw, _main_component_id)
        if snap.is_empty():
            snap = _nearest_road_edge(feature_raw, _main_component_id)
        if snap.is_empty():
            push_warning("No connected road edge available for destination stop: " + feature_name)
            continue

        var raw_road_point: Vector2 = snap.get("point", feature_raw)
        var edge_a: Vector2 = _road_nodes[int(snap["a"])]
        var edge_b: Vector2 = _road_nodes[int(snap["b"])]
        var tangent: Vector2 = (edge_b - edge_a).normalized()
        if tangent.length() < 0.01:
            tangent = Vector2.RIGHT
        var normal: Vector2 = Vector2(-tangent.y, tangent.x)
        var toward_feature: Vector2 = feature_raw - raw_road_point
        var primary_side: float = 1.0 if normal.dot(toward_feature) >= 0.0 else -1.0
        var candidate_stand_map: Vector2 = raw_road_point + normal * primary_side * 1.65
        var chosen_road_point: Vector2 = raw_road_point
        var chosen_stand_map: Vector2 = candidate_stand_map
        var found_clear: bool = false
        var side_options: Array[float] = [primary_side, -primary_side]
        var offset_options: Array[float] = [1.65, 2.0, 2.4]
        for offset_distance in offset_options:
            for side in side_options:
                var candidate: Vector2 = raw_road_point + normal * side * offset_distance
                if not _is_clear_stand(candidate):
                    continue
                if _stand_is_too_close(candidate):
                    continue
                chosen_stand_map = candidate
                found_clear = true
                break
            if found_clear:
                break

        var shared_index: int = -1
        if not found_clear:
            # Adjacent faculties or shops can deliberately share a physical stop.
            # Keep the bus aligned with that stand instead of stacking signs or
            # placing a new stand inside a building footprint.
            shared_index = _nearest_shared_stand(candidate_stand_map, 5.0)
            if shared_index >= 0:
                var shared_record: Dictionary = _shared_stand_positions[shared_index]
                chosen_stand_map = shared_record.get("map_position", candidate_stand_map)
                chosen_road_point = shared_record.get("road_point", raw_road_point)
            else:
                var fallback_clear: bool = false
                for side in side_options:
                    for offset_distance in [2.4, 2.8, 3.2]:
                        var fallback_candidate: Vector2 = raw_road_point + normal * side * offset_distance
                        if _is_clear_stand(fallback_candidate):
                            chosen_stand_map = fallback_candidate
                            fallback_clear = true
                            break
                    if fallback_clear:
                        break
                if not fallback_clear:
                    shared_index = _nearest_shared_stand(candidate_stand_map, 8.0)
                    if shared_index >= 0:
                        var shared_record: Dictionary = _shared_stand_positions[shared_index]
                        chosen_stand_map = shared_record.get("map_position", candidate_stand_map)
                        chosen_road_point = shared_record.get("road_point", raw_road_point)

        if shared_index < 0:
            shared_index = _nearest_shared_stand(chosen_stand_map, 2.3)
        if shared_index >= 0:
            var existing_record: Dictionary = _shared_stand_positions[shared_index]
            chosen_stand_map = existing_record.get("map_position", chosen_stand_map)
            chosen_road_point = existing_record.get("road_point", chosen_road_point)

        var stand_world: Vector3 = Vector3(chosen_stand_map.x * _scale, 0.25, chosen_stand_map.y * _scale)
        var visual_node: Node3D = null
        var shared_shelter_id: String = ""
        if shared_index < 0:
            var stop_side: float = 1.0 if normal.dot(chosen_stand_map - chosen_road_point) >= 0.0 else -1.0
            visual_node = _create_destination_stop_visual(feature_name, stand_world, tangent, stop_side)
            _destination_stop_visuals.append(visual_node)
            _shared_stand_positions.append({
                "map_position": chosen_stand_map,
                "road_point": chosen_road_point,
                "node": visual_node,
                "names": [feature_name],
                "is_shelter": false,
                "shelter_id": ""
            })
        else:
            var shared_record: Dictionary = _shared_stand_positions[shared_index]
            var shared_names: Array = shared_record.get("names", [])
            if not shared_names.has(feature_name):
                shared_names.append(feature_name)
            shared_record["names"] = shared_names
            _shared_stand_positions[shared_index] = shared_record
            if bool(shared_record.get("is_shelter", false)):
                shared_shelter_id = str(shared_record.get("shelter_id", ""))
            var shared_node: Node3D = shared_record.get("node") as Node3D
            if shared_node != null:
                shared_node.set_meta("serves_destinations", shared_names)
                if shared_names.size() > 1:
                    var destination_sign := shared_node.get_node_or_null("DestinationNameSign") as Label3D
                    if destination_sign != null:
                        destination_sign.text = "Shared Campus Stop"

        var stand_node_for_record: Node3D = visual_node
        if stand_node_for_record == null and shared_index >= 0:
            stand_node_for_record = _shared_stand_positions[shared_index].get("node") as Node3D
        var walk_distance: float = access_distance
        if walk_distance < 0.0:
            var direction_to_feature: Vector2 = feature_raw - chosen_road_point
            var length_to_center: float = direction_to_feature.length()
            var half_extent: float = 0.0
            if length_to_center > 0.01:
                var unit: Vector2 = direction_to_feature / length_to_center
                half_extent = absf(unit.x) * feature_size.x * 0.5 + absf(unit.y) * feature_size.y * 0.5
            walk_distance = maxf(0.0, length_to_center - half_extent) * _scale
        _destination_stops[feature_name] = {
            "road_point": chosen_road_point,
            "road_world": Vector3(chosen_road_point.x * _scale, _bus_y, chosen_road_point.y * _scale),
            "stand_world": stand_world,
            "feature_world": Vector3(feature_raw.x * _scale, 0.25, feature_raw.y * _scale),
            "walk_distance": walk_distance,
            "shared_shelter_id": shared_shelter_id,
            "stand_node": stand_node_for_record,
            "feature_id": int(feature.get("id", 0))
        }

    # Existing covered shelters are pickup points too. If a shelter's name also
    # belongs to a building but its building stop is elsewhere, preserve both stops
    # with distinct names rather than silently losing the actual shelter pickup.
    for shelter_id_variant in _shelter_positions.keys():
        var pickup_shelter_id: String = str(shelter_id_variant)
        var shelter_name: String = str(_shelter_names.get(pickup_shelter_id, pickup_shelter_id))
        var shelter_record_index: int = -1
        for stand_index in range(_shared_stand_positions.size()):
            var stand_record: Dictionary = _shared_stand_positions[stand_index]
            if bool(stand_record.get("is_shelter", false)) and str(stand_record.get("shelter_id", "")) == pickup_shelter_id:
                shelter_record_index = stand_index
                break
        if shelter_record_index < 0:
            continue
        var pickup_record: Dictionary = _shared_stand_positions[shelter_record_index]
        var pickup_map: Vector2 = pickup_record.get("map_position", Vector2.ZERO)
        var pickup_road: Vector2 = pickup_record.get("road_point", Vector2.ZERO)
        var pickup_world: Vector3 = Vector3(pickup_map.x * _scale, 0.25, pickup_map.y * _scale)
        var pickup_name: String = shelter_name
        if _destination_stops.has(shelter_name):
            var existing_destination: Dictionary = _destination_stops[shelter_name]
            var existing_stand: Vector3 = existing_destination.get("stand_world", pickup_world)
            var existing_distance: float = Vector2(existing_stand.x - pickup_world.x, existing_stand.z - pickup_world.z).length()
            if existing_distance > 4.5:
                pickup_name = shelter_name + " Shuttle Stand"
            else:
                continue
        if _destination_stops.has(pickup_name):
            pickup_name = shelter_name + " Shelter Pickup"
        _destination_stops[pickup_name] = {
            "road_point": pickup_road,
            "road_world": Vector3(pickup_road.x * _scale, _bus_y, pickup_road.y * _scale),
            "stand_world": pickup_world,
            "feature_world": pickup_world,
            "walk_distance": 0.0,
            "shared_shelter_id": pickup_shelter_id,
            "stand_node": null,
            "feature_id": 0
        }

func _is_clear_stand(candidate: Vector2) -> bool:
    for footprint_variant in _destination_footprints:
        var footprint: Dictionary = footprint_variant
        var kind: String = str(footprint.get("kind", ""))
        if kind == "landmark" or kind == "unverified":
            continue
        var centre: Vector2 = footprint.get("position", Vector2.ZERO)
        var size: Vector2 = footprint.get("size", Vector2(4.0, 4.0))
        if absf(candidate.x - centre.x) <= size.x * 0.5 + 0.40 and absf(candidate.y - centre.y) <= size.y * 0.5 + 0.40:
            return false
    return true

func _stand_is_too_close(candidate: Vector2) -> bool:
    for shared_variant in _shared_stand_positions:
        var shared: Dictionary = shared_variant
        var existing: Vector2 = shared.get("map_position", Vector2.ZERO)
        if candidate.distance_to(existing) < 2.3:
            return true
    return false

func _nearest_shared_stand(candidate: Vector2, radius: float) -> int:
    var best_index: int = -1
    var best_distance: float = radius
    for i in range(_shared_stand_positions.size()):
        var record: Dictionary = _shared_stand_positions[i]
        var existing: Vector2 = record.get("map_position", Vector2.ZERO)
        var distance: float = candidate.distance_to(existing)
        if distance < best_distance:
            best_distance = distance
            best_index = i
    return best_index

func _create_destination_stop_visual(destination_name: String, stand_world: Vector3, tangent: Vector2, stand_side: float = 1.0) -> Node3D:
    var node := Node3D.new()
    node.name = "DestinationStop_" + destination_name.replace(" ", "_").replace("/", "_").replace(":", "")
    node.position = Vector3(stand_world.x, 0.0, stand_world.z)
    node.rotation.y = atan2(-tangent.y, tangent.x)
    # The sign face and tactile edge face the carriageway, not away from it.
    if stand_side > 0.0:
        node.rotation.y += PI
    node.add_to_group("destination_bus_stops")
    node.set_meta("destination_name", destination_name)
    add_child(node)
    _box(node, "WaitingPad", Vector3(0, 0.06, 0), Vector3(1.8, 0.12, 1.15), Color(0.70, 0.70, 0.66))
    _box(node, "TactileEdge", Vector3(0, 0.13, 0.47), Vector3(1.8, 0.07, 0.10), Color(0.93, 0.82, 0.53))
    _pole(node, Vector3(0.58, 1.10, -0.20), 0.07, 2.20, Color(0.16, 0.23, 0.28), "StopSignPole")
    _box(node, "BusStopSign", Vector3(0.58, 1.75, -0.20), Vector3(1.10, 0.70, 0.12), Color(0.08, 0.43, 0.51))
    _label(node, "BUS", Vector3(0.58, 1.75, -0.12), 24, Color(1.0, 0.98, 0.90))
    var destination_label := Label3D.new()
    destination_label.name = "DestinationNameSign"
    destination_label.text = _short_destination_name(destination_name)
    destination_label.position = Vector3(0, 2.45, 0)
    destination_label.font_size = 22
    destination_label.pixel_size = 0.007
    destination_label.modulate = Color(0.08, 0.18, 0.23)
    destination_label.outline_size = 5
    destination_label.outline_modulate = Color.WHITE
    destination_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    destination_label.no_depth_test = true
    destination_label.visibility_range_end = 32.0
    node.add_child(destination_label)
    var status_label := Label3D.new()
    status_label.name = "StopStatusLabel"
    status_label.text = ""
    status_label.position = Vector3(0, 2.95, 0)
    status_label.font_size = 18
    status_label.pixel_size = 0.006
    status_label.modulate = Color(0.96, 0.83, 0.36)
    status_label.outline_size = 4
    status_label.outline_modulate = Color(0.08, 0.12, 0.14)
    status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    status_label.no_depth_test = true
    status_label.visibility_range_end = 32.0
    status_label.visible = false
    node.add_child(status_label)
    return node

func _set_stop_status(destination_name: String, status: String) -> void:
    var record: Dictionary = _destination_stops.get(destination_name, {})
    if record.is_empty():
        return
    var stand_node: Node3D = record.get("stand_node") as Node3D
    if stand_node == null:
        return
    var status_label: Label3D = stand_node.get_node_or_null("StopStatusLabel") as Label3D
    if status_label == null:
        return
    status_label.text = status
    status_label.visible = not status.is_empty()
    if status == "SHUTTLE HERE":
        status_label.modulate = Color(0.45, 0.96, 1.2)
    else:
        status_label.modulate = Color(0.96, 0.83, 0.36)

func _short_destination_name(destination_name: String) -> String:
    var value: String = destination_name
    value = value.replace("Faculty of ", "")
    value = value.replace("LASU ", "")
    if value.length() > 27:
        value = value.substr(0, 26) + "…"
    return value

func has_arrived(bus: Node3D) -> bool:
    var index: int = _find_service(bus)
    if index < 0:
        return false
    var service: Dictionary = _services[index]
    return bool(service.get("arrived", false))

func disembark(bus: Node3D) -> Vector3:
    var index: int = _find_service(bus)
    if index < 0:
        return Vector3.ZERO
    var service: Dictionary = _services[index]
    var bus_position: Vector3 = bus.global_position
    var exit_position: Vector3 = bus_position
    if bool(service.get("destination_mode", false)):
        # Alight at the mapped roadside stand, never at an arbitrary bus-side offset.
        exit_position = service.get("destination_stand_position", bus_position)
        exit_position.y = float(exit_position.y)
        service["passenger"] = false
        service["arrived"] = false
        service["returning"] = true
        service["direction"] = -1
        service["lane_shift"] = -1.0
        service["waiting"] = 5.0
        _services[index] = service
        return exit_position
    var stops: Array = service["stop_ids"]
    var stop_id: String = str(stops[int(service["at_stop_index"])])
    var shelter_position: Vector3 = _shelter_positions.get(stop_id, bus_position)
    exit_position = bus_position.lerp(shelter_position, 0.58)
    exit_position.y = 0.25
    service["passenger"] = false
    service["arrived"] = false
    service["waiting"] = 9.0
    _services[index] = service
    return exit_position

func onboard_camera(bus: Node3D) -> Camera3D:
    return bus.get_node_or_null("PassengerCamera") as Camera3D

func _material(tint: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.78
    if tint.a < 1.0:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return mat


func _pole(parent: Node3D, position_value: Vector3, radius: float, height: float, tint: Color, name_text: String) -> void:
    # Reusable vertical cylinder for stop-sign posts and other small poles.
    var pole_node := MeshInstance3D.new()
    pole_node.name = name_text
    var pole_mesh := CylinderMesh.new()
    pole_mesh.top_radius = radius
    pole_mesh.bottom_radius = radius
    pole_mesh.height = height
    pole_mesh.radial_segments = 12
    pole_node.mesh = pole_mesh
    pole_node.position = position_value
    pole_node.material_override = _material(tint)
    parent.add_child(pole_node)

func _label(parent: Node3D, text_value: String, position_value: Vector3, font_size_value: int, tint: Color) -> void:
    # Reusable world-space label for stop signs and other transit markers.
    var label_node := Label3D.new()
    label_node.name = "Label_" + text_value.replace(" ", "_")
    label_node.text = text_value
    label_node.position = position_value
    label_node.font_size = font_size_value
    label_node.pixel_size = 0.007
    label_node.modulate = tint
    label_node.outline_size = 3
    label_node.outline_modulate = Color(0.08, 0.12, 0.14)
    label_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label_node.no_depth_test = true
    parent.add_child(label_node)

func _box(parent: Node3D, name_text: String, position_value: Vector3, box_size: Vector3, tint: Color) -> void:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = name_text
    var mesh := BoxMesh.new()
    mesh.size = box_size
    mesh_node.mesh = mesh
    mesh_node.position = position_value
    mesh_node.material_override = _material(tint)
    parent.add_child(mesh_node)

func _wheel(parent: Node3D, at_x: float, at_z: float) -> void:
    var tire := MeshInstance3D.new()
    var tire_mesh := CylinderMesh.new()
    tire_mesh.top_radius = 0.48
    tire_mesh.bottom_radius = 0.48
    tire_mesh.height = 0.26
    tire_mesh.radial_segments = 12
    tire.mesh = tire_mesh
    tire.position = Vector3(at_x, 0.48, at_z)
    tire.rotation_degrees.x = 90
    tire.material_override = _material(Color(0.09, 0.11, 0.13))
    parent.add_child(tire)

func _build_bus(bus: Node3D, display_name: String, line_id: String) -> void:
    # +X is the front of the bus, for stable turn rotation along paved paths.
    var ivory := Color(0.97, 0.91, 0.68)
    var teal := Color(0.10, 0.48, 0.54)
    var glass := Color(0.28, 0.62, 0.70, 0.20)
    var steel := Color(0.18, 0.22, 0.26)
    _box(bus, "ShuttleChassis", Vector3(0.0, 0.85, 0.0), Vector3(6.6, 0.55, 2.35), steel)
    # Open volume: lower panels, pillars and transparent windows enclose a real cabin.
    _box(bus, "CabinFloor", Vector3(0, 1.18, 0), Vector3(6.2, 0.12, 2.25), steel)
    _box(bus, "RearPanel", Vector3(-3.06, 1.60, 0), Vector3(0.15, 0.75, 2.24), ivory)
    _box(bus, "FrontPanel", Vector3(3.06, 1.60, 0), Vector3(0.15, 0.75, 2.24), ivory)
    for side in [-1.0, 1.0]:
        _box(bus, "LowerSidePanel", Vector3(0, 1.53, side * 1.12), Vector3(6.2, 0.58, 0.12), ivory)
        for x in [-3.02, -1.82, -0.62, 0.58, 1.78, 3.02]:
            _box(bus, "WindowPillar", Vector3(x, 2.36, side * 1.12), Vector3(0.10, 1.04, 0.10), ivory)
        for x in [-2.20, -0.75, 0.70]:
            _box(bus, "PassengerSeat", Vector3(x, 1.58, side * 0.72), Vector3(0.85, 0.18, 0.61), teal)
            _box(bus, "SeatBack", Vector3(x - 0.38, 1.95, side * 0.72), Vector3(0.14, 0.85, 0.63), teal.darkened(0.25))
        _box(bus, "HandRail", Vector3(0, 2.73, side * 0.62), Vector3(5.4, 0.06, 0.06), steel)
    _box(bus, "DriverSeat", Vector3(2.0, 1.55, -0.65), Vector3(0.8, 0.22, 0.68), steel)
    _box(bus, "DriverSeatBack", Vector3(1.65, 1.96, -0.65), Vector3(0.15, 0.9, 0.68), steel)
    _box(bus, "Dashboard", Vector3(2.78, 1.87, 0), Vector3(0.45, 0.38, 2.0), steel)
    _box(bus, "InstrumentPanel", Vector3(2.52, 2.06, -0.57), Vector3(0.05, 0.22, 0.52), Color(0.24, 0.72, 0.67))
    _box(bus, "AisleRunner", Vector3(-0.3, 1.25, 0), Vector3(4.9, 0.02, 0.65), Color(0.27, 0.29, 0.32))
    _box(bus, "Roof", Vector3(0.0, 2.97, 0.0), Vector3(6.3, 0.18, 2.4), teal)
    _box(bus, "WindowFront", Vector3(3.13, 2.23, 0.0), Vector3(0.07, 0.93, 1.92), glass)
    _box(bus, "WindowRear", Vector3(-3.13, 2.23, 0.0), Vector3(0.07, 0.84, 1.94), glass)
    for side in [-1.0, 1.0]:
        var z: float = float(side) * 1.195
        for i in range(5):
            var x: float = -2.43 + float(i) * 1.12
            _box(bus, "ShuttleWindow", Vector3(x, 2.25, z), Vector3(0.86, 0.80, 0.06), glass)
        _box(bus, "ShuttleSideStripe", Vector3(0.0, 1.25, z), Vector3(6.16, 0.19, 0.07), teal)
        _wheel(bus, -2.17, float(side) * 1.15)
        _wheel(bus, 2.12, float(side) * 1.15)
        _box(bus, "Headlamp", Vector3(3.33, 1.00, float(side) * 0.78), Vector3(0.11, 0.21, 0.40), Color(1.0, 0.96, 0.74))
    var label := Label3D.new()
    label.name = "ShuttleLineSign"
    label.text = "LASU SHUTTLE  " + line_id
    label.font_size = 34
    label.pixel_size = 0.009
    label.position = Vector3(0, 3.24, 0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = Color(0.08, 0.19, 0.24)
    label.outline_size = 6
    label.outline_modulate = Color.WHITE
    label.no_depth_test = true
    bus.add_child(label)
    var camera := Camera3D.new()
    camera.name = "OnboardCamera"
    camera.position = Vector3(-10.8, 5.1, 0.0)
    bus.add_child(camera)
    camera.look_at(bus.to_global(Vector3(2.7, 1.4, 0.0)), Vector3.UP)
    camera.current = false
    var passenger := Camera3D.new()
    passenger.name = "PassengerCamera"
    passenger.position = Vector3(-1.75, 2.25, 0)
    passenger.rotation = Vector3(deg_to_rad(-4), -PI * 0.5, 0)
    passenger.near = 0.06
    passenger.fov = 78
    passenger.far = 220
    bus.add_child(passenger)
    passenger.current = false


func toggle_passenger_view(bus: Node3D) -> void:
    var inside: Camera3D = onboard_camera(bus)
    var outside: Camera3D = bus.get_node_or_null("OnboardCamera") as Camera3D
    if inside == null or outside == null:
        return
    if inside.current:
        outside.current = true
    else:
        inside.current = true

func look_passenger(bus: Node3D, relative: Vector2) -> void:
    var camera: Camera3D = onboard_camera(bus)
    if camera == null or not camera.current:
        return
    camera.rotation.y = clampf(camera.rotation.y - relative.x * 0.004, -PI * 0.5 - 2.35, -PI * 0.5 + 2.35)
    camera.rotation.x = clampf(camera.rotation.x - relative.y * 0.004, deg_to_rad(-45), deg_to_rad(35))
