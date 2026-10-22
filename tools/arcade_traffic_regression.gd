extends "res://tools/traffic_regression.gd"
func _run() -> void:
    var m = manager()
    m.vehicle_blocking = false
    var straight: Array = [Vector3(-100, 0.12, 0), Vector3(100, 0.12, 0)]
    bus(m, "held-passenger", straight, 100)
    bus(m, "moving-behind", straight, 75)
    m._services[0].menu_hold = true
    m._services[0].passenger = true
    m._reservations.add_zone(Vector2.ZERO, "junction")
    var previous: Vector3 = m._services[1].node.position
    var continuous: bool = true
    for tick in range(600):
        m._physics_process(DT)
        continuous = continuous and m._services[1].node.position.distance_to(previous) < 0.6
        previous = m._services[1].node.position
    check(m._services[1].progress > 125, "arcade traffic passes a held occupied bus and reserved crossing")
    check(m._services[0].progress == 100 and m._services[0].passenger, "passing does not displace a held passenger")
    check(continuous, "passing remains continuous without teleporting")
    var blocked: Dictionary = m._services[0].duplicate()
    blocked.parking_blend = 1.0
    var bay: Vector3 = m._point_and_heading(blocked)[0]
    m._cache_road_obstacles([{"position": [bay.x, bay.z], "size": [2.0, 2.0]}])
    check(not m._bay_position_is_clear(0, blocked), "arcade mode retains campus-feature bay checks")
    m.free()
    m = manager()
    m.vehicle_blocking = false
    m.initialise(JSON.parse_string(FileAccess.get_file_as_string("res://data/transit_routes_v0.7.json")), JSON.parse_string(FileAccess.get_file_as_string("res://data/amenities_v0.6.json")).shelters, 2.6, JSON.parse_string(FileAccess.get_file_as_string("res://data/road_network_v0.4.json")), JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_layout.json")).features)
    var max_wait: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
    var wait: Array = max_wait.duplicate()
    var trips: Array = [0, 0, 0, 0, 0]
    continuous = true
    for tick in range(18000):
        var positions: Array = []
        var directions: Array = []
        for service in m._services:
            positions.append(service.node.position)
            directions.append(service.direction)
        m._physics_process(DT)
        for i in range(m._services.size()):
            var step: float = m._services[i].node.position.distance_to(positions[i])
            continuous = continuous and step < 0.6
            wait[i] = float(wait[i]) + DT if step < 0.001 else 0.0
            max_wait[i] = maxf(max_wait[i], wait[i])
            if m._services[i].direction != directions[i]:
                trips[i] += 1
    check(continuous, "five-service arcade run has no position jumps")
    for i in range(m._services.size()):
        check(max_wait[i] < 45 and trips[i] >= 2, "arcade service circulates for 300s: " + str(m._services[i].id))
    print("ARCADE TRAFFIC: %d checks, %d failures; max stops %s; trips %s" % [checks, failures.size(), max_wait, trips])
    m.free()
    quit(0 if failures.is_empty() else 1)
