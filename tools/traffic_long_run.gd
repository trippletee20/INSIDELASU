extends "res://tools/traffic_regression.gd"
## Natural campus reproduction: track real movement rather than trusting blocked_duration.
func _run() -> void:
    seed(14014)
    var m = manager()
    var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/transit_routes_v0.7.json"))
    var amenities: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/amenities_v0.6.json"))
    var roads: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/road_network_v0.4.json"))
    var campus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_layout.json"))
    m.initialise(routes, amenities.shelters, 2.6, roads, campus.features)
    var held_passenger: bool = OS.get_cmdline_user_args().has("--held-passenger")
    if held_passenger:
        m.board(m._services[2].node)
        m.set_menu_hold(m._services[2].node, true)
    var duration: float = 300.0
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--seconds="):
            duration = float(arg.trim_prefix("--seconds="))
    var stationary: Array = []
    var max_stationary: Array = []
    var distance: Array = []
    var trips: Array = []
    for s in m._services:
        stationary.append(0.0)
        max_stationary.append(0.0)
        distance.append(0.0)
        trips.append(0)
        print("ROUTE ", s.id, " ", s.points[0], " -> ", s.points[-1], " length ", s.total)
    var clear: bool = true
    var continuous: bool = true
    for tick in range(int(duration / DT)):
        var previous: Array = []
        var directions: Array = []
        for s in m._services:
            previous.append(s.node.position)
            directions.append(s.direction)
        if held_passenger and tick == 1200:
            m.set_menu_hold(m._services[2].node, false)
        m._physics_process(DT)
        clear = collision_free(m) and clear
        for i in range(m._services.size()):
            var s: Dictionary = m._services[i]
            var step: float = previous[i].distance_to(s.node.position)
            if continuous and step >= 0.6:
                print("JUMP ", s.id, " tick ", tick, " step ", step, " from ", previous[i], " to ", s.node.position)
            continuous = continuous and step < 0.6
            distance[i] += step
            stationary[i] = float(stationary[i]) + DT if step < 0.001 else 0.0
            max_stationary[i] = maxf(max_stationary[i], stationary[i])
            if s.direction != directions[i]:
                trips[i] += 1
        if tick % 3600 == 3599:
            print("TIME ", (tick + 1) / 60.0, " stationary=", stationary, " trips=", trips)
            for i in range(m._services.size()):
                var s: Dictionary = m._services[i]
                print("DETAIL ", s.id, " pos ", s.node.position, " p ", s.progress, " dir ", s.direction,
                    " lane ", s.lane_shift, " park ", s.get("parking_blend"), " wait ", s.waiting,
                    " leases ", m._reservations.records(i))
    check(clear, "long run: no bus footprint overlap")
    check(continuous, "long run: no per-tick jump above 0.6 metres")
    check(m._services.size() == 5, "long run: five services retained")
    for i in range(m._services.size()):
        var s: Dictionary = m._services[i]
        print("SUMMARY ", s.id, " max_stationary=", max_stationary[i], " distance=", distance[i], " trips=", trips[i],
            " lane=", s.lane_shift, " parking=", s.get("parking_blend"), " waiting=", s.waiting)
        check(max_stationary[i] < 45.0, "long run: %s never stationary for 45 seconds" % s.id)
        if duration >= 300:
            check(trips[i] >= 2, "long run: %s completes at least two one-way trips" % s.id)
    if held_passenger:
        check(m._services[2].passenger, "long run: occupied shuttle retains passenger after held-stop recovery")
    print("LONG TRAFFIC: %d checks, %d failures (%ds, seed 14014, 60 Hz)" % [checks, failures.size(), duration])
    m.free()
    quit(0 if failures.is_empty() else 1)
