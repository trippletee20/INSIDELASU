extends "res://tools/traffic_regression.gd"

func crossing(m) -> void:
    m._reservations.add_zone(Vector2.ZERO, "junction")

func _run() -> void:
    var m = manager()
    var horizontal: Array = [Vector3(-100, 0.12, 0), Vector3(100, 0.12, 0)]
    var vertical: Array = [Vector3(0, 0.12, -100), Vector3(0, 0.12, 100)]
    bus(m, "west", horizontal, 65)
    bus(m, "north", vertical, 65)
    bus(m, "east", horizontal, 135, -1)
    crossing(m)
    var owners: Array = []
    var clear: bool = true
    for tick in range(900):
        m._physics_process(DT)
        clear = collision_free(m) and clear
        var owner: int = m._reservations.zones[0].owner
        if owner >= 0 and not owners.has(owner):
            owners.append(owner)
    check(clear, "three-way reservations: no collision")
    check(owners == [0, 1, 2], "three-way reservations: FIFO entry and eventual service for all")
    check(m._services[0].progress > 120 and m._services[1].progress > 120 and m._services[2].progress < 80,
        "three-way reservations: all cross within 15 seconds")
    m.free()

    m = manager()
    bus(m, "younger-low-index", horizontal, 40)
    bus(m, "older-high-index", vertical, 75)
    m._services[1].speed = 3.0
    crossing(m)
    m._reservations.update(m, DT)
    check(m._reservations.zones[0].owner == 1, "aging: earlier higher-index requester owns crossing")
    check(simulate(m, 7.0), "aging: late arrival remains collision-free")
    check(m._reservations.zones[0].owner == 1, "aging: younger lower-index service cannot steal an active lease")
    check(simulate(m, 15.0), "aging: both eventually leave safely")
    check(m._services[0].progress > 120 and m._services[1].progress > 120, "aging: both complete crossing")
    m.free()

    m = manager()
    bus(m, "approaching", horizontal, 70)
    bus(m, "exit-blocker", horizontal, 118)
    m._services[1].menu_hold = true
    m._services[1].passenger = true
    crossing(m)
    check(simulate(m, 3.0), "exit protection: approaching bus stays clear of held bus")
    check(m._reservations.zones[0].owner == -1, "exit protection: no entry lease when departure lane is blocked")
    check(Vector2(m._services[0].node.position.x, m._services[0].node.position.z).length() >= 14.0, "exit protection: approach remains outside the crossing")
    m._services[1].menu_hold = false
    check(simulate(m, 8.0), "exit protection: released exit permits safe travel")
    check(m._services[0].progress > 120, "exit protection: queue resumes after exit clears")
    check(m._services[1].passenger, "exit protection: passenger survives held and released stop")
    m.free()

    m = manager()
    bus(m, "entrant", horizontal, 70)
    bus(m, "occupied", vertical, 97)
    m._services[1].menu_hold = true
    m._services[1].passenger = true
    crossing(m)
    m._reservations.update(m, DT)
    check(m._reservations.zones[0].owner == 1, "occupied lease: current occupant can clear first")
    for tick in range(1800):
        m._reservations.update(m, DT)
    check(m._reservations.zones[0].owner == 1, "occupied lease: 30 seconds never expires under a passenger")
    check(m._services[1].passenger, "occupied lease: no passenger reset")
    m._services[1].menu_hold = false
    check(simulate(m, 10.0), "occupied lease: both leave collision-free after release")
    check(m._services[0].progress > 120, "occupied lease: queued entrant eventually crosses")
    m.free()
    for lane in [1.0, 0.3]:
        m = manager()
        m._scale = 2.6
        m._build_road_graph({"road_routes": [{"id": 0, "points": [[-100 / 2.6, 0], [100 / 2.6, 0]]}]})
        m._main_component_id = 0
        var parked_bus: Node3D = bus(m, "parked passenger", horizontal, 120)
        m._services[0].parking_blend = 1.0
        m._services[0].lane_shift = lane
        m._place_service(m._services[0])
        var original: Vector3 = parked_bus.position
        check(m.prepare_destination(parked_bus, Vector2(80 / 2.6, 0), "ride"), "parked passenger: destination accepted")
        m._place_service(m._services[0])
        check(parked_bus.position.distance_to(original) < 0.001, "parked passenger: departure starts at actual parked position")
        m.finish_quick_travel(parked_bus)
        check(parked_bus.position.distance_to(original) < 0.001, "parked passenger: quick travel restores exact lane and parking pose")
        m.free()
    print("RESERVATION REGRESSION: %d checks, %d failures" % [checks, failures.size()])
    quit(0 if failures.is_empty() else 1)
