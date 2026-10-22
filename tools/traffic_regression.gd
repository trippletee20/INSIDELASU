extends SceneTree
## Deterministic engine simulations of the production transit manager, not pattern checks.
const Transit = preload("res://scripts/transit_manager.gd")
var failures: Array[String] = []
var checks: int = 0
var overlap_reported: bool = false
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        print("FAIL: ", message)

func manager() -> Node3D:
    var m = Transit.new()
    # Historical collision/reservation mode remains covered explicitly.
    m.vehicle_blocking = true
    root.add_child(m)
    m.set_physics_process(false)
    m._scale = 1.0
    return m

func bus(m, id: String, points: Array, progress: float, direction: int = 1) -> Node3D:
    var node := Node3D.new()
    m.add_child(node)
    var total: float = 0.0
    for i in range(1, points.size()):
        total += points[i - 1].distance_to(points[i])
    var s: Dictionary = {"id": id, "name": id, "node": node, "points": points,
        "total": total, "progress": progress, "direction": direction, "lane_shift": 1.0,
        "speed": 8.0, "waiting": 0.0, "stop_ids": ["A", "B"], "at_stop_index": 0,
        "base_points": points.duplicate(), "base_total": total, "base_progress": progress,
        "base_direction": direction}
    m._services.append(s)
    m._place_service(s)
    return node

func collision_free(m) -> bool:
    for a in range(m._services.size()):
        for b in range(a + 1, m._services.size()):
            var na: Node3D = m._services[a].node
            var nb: Node3D = m._services[b].node
            if m._vehicle_rectangles_overlap(Vector2(na.position.x, na.position.z), na.rotation.y,
                    Vector2(nb.position.x, nb.position.z), nb.rotation.y):
                if not overlap_reported:
                    print("OVERLAP ", m._services[a].id, " / ", m._services[b].id, " at ", na.position, " / ", nb.position,
                        " headings ", na.rotation.y, " / ", nb.rotation.y, " waits ", m._services[a].waiting, " / ", m._services[b].waiting,
                        " parking ", m._services[a].get("parking_blend"), " / ", m._services[b].get("parking_blend"))
                    overlap_reported = true
                return false
    return true

func simulate(m, seconds: float) -> bool:
    var clear: bool = true
    for tick in range(int(seconds / DT)):
        m._physics_process(DT)
        clear = collision_free(m) and clear
    return clear

func _run() -> void:
    seed(14014)
    var straight: Array = [Vector3(0, 0.12, 0), Vector3(200, 0.12, 0)]
    var m = manager()
    bus(m, "east", straight, 50)
    bus(m, "west", straight, 100, -1)
    check(simulate(m, 6.0), "two-way passing: no footprint overlap at 60 Hz")
    check(m._services[0].progress > m._services[1].progress, "two-way passing: both buses pass")
    m.free()
    print("SCENARIO: two-way passing completed")

    m = manager()
    bus(m, "east", [Vector3(-100, 0.12, 0), Vector3(100, 0.12, 0)], 75)
    bus(m, "south", [Vector3(0, 0.12, -100), Vector3(0, 0.12, 100)], 75)
    m._junction_positions = [Vector2.ZERO]
    check(simulate(m, 10.0), "junction contention: no footprint overlap")
    check(m._services[0].progress > 120 and m._services[1].progress > 120, "junction contention: both clear within 10 seconds")
    m.free()
    print("SCENARIO: junction contention completed")

    m = manager()
    bus(m, "bay", straight, 50)
    # A narrow building touches the bus nose, but is outside the old centre-only test.
    m._cache_road_obstacles([{"name": "test wall", "position": [53.0, 5.67], "size": [0.5, 1.0]}])
    var parked: Dictionary = m._services[0].duplicate()
    parked["parking_blend"] = 1.0
    check(not m._bay_position_is_clear(0, parked), "blocked bay: full bus nose cannot penetrate a protected wall")
    m._services[0]["waiting"] = 9.0
    check(simulate(m, 5.0), "blocked bay: simulation remains collision-free")
    check(m._services[0].progress > 50.0, "blocked bay: unavailable shoulder does not hold service indefinitely")
    m.free()
    print("SCENARIO: blocked bay completed")

    m = manager()
    bus(m, "priority", straight, 65)
    bus(m, "yield", straight, 57)
    m._services[0]["menu_hold"] = true
    m._services[1]["blocked_duration"] = 4.0
    m._services[1]["yield_retreat_distance"] = 37.99
    m._services[1]["force_yield"] = true
    m._attempt_traffic_advance(1, 58.0, DT)
    check(m._services[1].progress < 57.0, "backing: lower-priority shuttle safely retreats")
    check(m._services[1].yield_retreat_distance <= 38.000001, "backing: retreat never exceeds 38 metre budget")
    check(collision_free(m), "backing: no overlap during retreat")
    # Exhausted retreat must be observable and preserve the occupied bus and route.
    var safe_wait_events: Array = []
    m.traffic_safe_wait.connect(func(id: String, reason: String): safe_wait_events.append([id, reason]))
    m._services[1]["blocked_duration"] = 26.0
    m._services[1]["passenger"] = true
    m._attempt_traffic_advance(1, 65.0, DT)
    check(m._services[1].get("traffic_warning_issued", false), "backing: exhausted recovery logs safe wait")
    check(m._services[1].passenger and m._services[1].points == straight, "backing: passenger and route survive safe wait")
    check(safe_wait_events.size() == 1, "backing: safe wait emits an observable event")
    m._services[1]["passenger"] = false
    m._services[1]["waiting"] = 9.0
    check(simulate(m, 2.0), "backing to bay: retreat and shoulder entry stay collision-free")
    check(m._services[1].get("parking_blend", 0.0) > 0.9, "backing to bay: yielding bus reaches clear shoulder")
    m.free()
    print("SCENARIO: backing to safe route / bounded safe wait completed")

    m = manager()
    bus(m, "moving", straight, 30)
    bus(m, "stationary", straight, 50)
    check(not m._safe_to_advance(0, 70.0), "swept movement: cannot jump through a bus on a long tick")
    m.free()

    m = manager()
    m._build_road_graph({"road_routes": [{"id": 0, "points": [[0, 0], [200, 0]]}]})
    m._main_component_id = 0
    var node: Node3D = bus(m, "pickup", straight, 20)
    m._destination_stops["Test stop"] = {"road_point": Vector2(70, 0), "stand_world": Vector3(70, 0.25, 8)}
    check(m.request_pickup("Test stop"), "summoned pickup: request accepted")
    check(simulate(m, 10.0), "summoned pickup: collision-free approach")
    check(m._services[0].pickup_waiting and m.has_arrived(node), "summoned pickup: reaches and waits at requested stop")
    var pickup_position: Vector3 = node.position
    check(m.prepare_for_pickup_boarding(node), "summoned pickup: boarding preparation accepted")
    m._place_service(m._services[0])
    check(node.position.distance_to(pickup_position) < 0.001, "summoned pickup: boarding transition preserves bus position")
    check(m.prepare_destination(node, Vector2(120, 0), "Passenger destination"), "passenger trip: road route accepted")
    check(m.board(node), "passenger trip: boarding accepted")
    check(simulate(m, 12.0), "passenger trip: collision-free ride")
    check(m.has_arrived(node) and m._services[0].passenger, "passenger trip: passenger reaches destination")
    var destination_position: Vector3 = node.position
    m.disembark(node)
    m._place_service(m._services[0])
    check(node.position.distance_to(destination_position) < 0.001, "passenger trip: disembark transition preserves bus position")
    simulate(m, 35.0)
    check(not m._services[0].destination_mode and not m._services[0].pickup_dispatch, "passenger trip: shuttle returns to its regular loop")
    check(not m._services[0].passenger, "passenger trip: passenger flag cleared only on disembark")
    m.free()
    print("SCENARIO: summoned pickup and onboard passenger completed")

    m = manager()
    var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transit_routes_v0.7.json"))
    var amenities: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/amenities_v0.6.json"))
    var roads: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/road_network_v0.4.json"))
    var campus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_layout.json"))
    m.initialise(routes, amenities.shelters, 2.6, roads, campus.features)
    check(m._services.size() == 5, "campus: all five configured shuttles initialise")
    var observer = load("res://scripts/traffic_debug.gd").new()
    m.add_child(observer)
    observer.attach(m)
    observer.set_physics_process(false)
    var snapshot: Array = observer.snapshot()
    check(snapshot.size() == 5 and snapshot == observer.snapshot(), "diagnostics: deterministic snapshots include every service")
    check(snapshot.all(func(row): return row.has("blocker") and row.has("state") and row.has("stuck_seconds") and row.has("reservation")), "diagnostics: blocker, state, duration and reservation exposed")
    var starts: Array = []
    for s in m._services:
        starts.append(s.node.position)
    check(simulate(m, 60.0), "campus: five-shuttle 60 second simulation has no overlaps")
    for i in range(m._services.size()):
        check(starts[i].distance_to(m._services[i].node.position) > 1.0, "campus: service %s moves" % m._services[i].id)
    m.free()
    print("SCENARIO: five-shuttle campus simulation completed")
    print("TRAFFIC REGRESSION: %d checks, %d failures (seed 14014, 60 Hz)" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
