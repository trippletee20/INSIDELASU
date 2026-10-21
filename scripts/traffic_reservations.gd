extends RefCounted
## Exclusive conflict areas. Requests are collected before any shuttle moves.
## FIFO tickets age with waiting; occupied leases never expire under a passenger.
var zones: Array = []
var clock: float = 0.0
var next_ticket: int = 0
var refresh_after: float = 0.0
const RADIUS: float = 9.0
const ENTRY: float = 14.0
const REQUEST_DISTANCE: float = 28.0

func add_zone(point: Vector2, kind: String) -> void:
    for zone in zones:
        if point.distance_to(zone.position) < 14.0:
            if kind == "terminal":
                zone.kind = kind
            return
    zones.append({"position": point, "kind": kind, "owner": -1, "queue": {}, "entered": false})

func initialise(manager) -> void:
    zones.clear()
    clock = 0.0
    next_ticket = 0
    refresh_after = 0.0
    # Terminals first: shared boarding/turning areas must have a single owner.
    for service in manager._services:
        var points: Array = service.points
        for point in [points[0], points[-1]]:
            add_zone(Vector2(point.x, point.z), "terminal")
    for point in manager._junction_positions:
        add_zone(point, "junction")

func _exit_clear(manager, index: int, zone: Dictionary) -> bool:
    var service: Dictionary = manager._services[index]
    if bool(service.get("menu_hold", false)):
        return false
    var direction: int = -1 if service.get("returning", false) else int(service.get("direction", 1))
    var probe: Dictionary = service.duplicate()
    var entered: bool = false
    # Require space through the crossing and one bus length beyond its core.
    # Terminal paths end in the zone: retain ownership through dwell/turn/departure.
    for distance in range(2, int(REQUEST_DISTANCE + ENTRY * 2) + 1, 2):
        probe.progress = clampf(float(service.progress) + direction * distance, 0.0, float(service.total))
        var position: Vector3 = manager._point_and_heading(probe)[0]
        var gap: float = Vector2(position.x, position.z).distance_to(zone.position)
        entered = entered or gap < RADIUS
        if not manager._swept_pose_is_clear(index, probe):
            return false
        if entered and gap > RADIUS + manager.BUS_LENGTH:
            return true
        if probe.progress <= 0.0 or probe.progress >= service.total:
            return entered
    return entered

func update(manager, delta: float) -> void:
    clock += delta
    if clock < refresh_after:
        return
    refresh_after = clock + 0.1
    var probes: Array = []
    for service in manager._services:
        var samples: Array = []
        var direction: int = -1 if service.get("returning", false) else int(service.get("direction", 1))
        for distance in range(0, int(REQUEST_DISTANCE) + 1, 4):
            var point: Vector3 = manager._centreline_position(service, clampf(float(service.progress) + direction * distance, 0.0, float(service.total)))
            samples.append(Vector2(point.x, point.z))
        probes.append(samples)
    for z in range(zones.size()):
        var zone: Dictionary = zones[z]
        var queue: Dictionary = zone.queue
        var occupants: Array = []
        for i in range(manager._services.size()):
            var s: Dictionary = manager._services[i]
            var position: Vector3 = s.node.position
            var distance: float = Vector2(position.x, position.z).distance_to(zone.position)
            var entry: float = 22.0 if zone.kind == "terminal" else ENTRY
            if distance < entry:
                occupants.append(i)
            var requests: bool = false
            for point in probes[i]:
                if point.distance_to(zone.position) < RADIUS:
                    requests = true
                    break
            if requests or distance < entry:
                if not queue.has(i):
                    queue[i] = {"ticket": next_ticket, "since": clock}
                    next_ticket += 1
            else:
                queue.erase(i)
        var owner: int = int(zone.owner)
        if owner >= 0:
            # Release after the whole bus clears, never on a timeout while occupied.
            if not queue.has(owner):
                owner = -1
            elif occupants.has(owner):
                zone.entered = true
            elif zone.entered:
                owner = -1
        if owner < 0:
            zone.entered = false
            # A bus already inside gets clearance to leave before a queued entrant.
            var candidates: Array = occupants if not occupants.is_empty() else queue.keys()
            var oldest: int = 2147483647
            for i in candidates:
                if int(queue[i].ticket) < oldest and (occupants.has(i) or _exit_clear(manager, i, zone)):
                    oldest = int(queue[i].ticket)
                    owner = i
            zone.entered = occupants.has(owner)
        zone.owner = owner

func permits(manager, index: int, proposed: Dictionary) -> bool:
    var current: Vector3 = manager._services[index].node.position
    var next: Vector3 = manager._point_and_heading(proposed)[0]
    for zone in zones:
        # Nearby parallel roads can pass the stop-line radius without entering
        # the conflict core. Only constrain services whose actual route requests it.
        if not zone.queue.has(index):
            continue
        var before: float = Vector2(current.x, current.z).distance_to(zone.position)
        var after: float = Vector2(next.x, next.z).distance_to(zone.position)
        var entry: float = 22.0 if zone.kind == "terminal" else ENTRY
        if after >= entry or after >= before - 0.0001:
            continue
        # Existing occupants may clear; physical footprint checks still apply.
        if before < RADIUS:
            continue
        if int(zone.owner) != index:
            return false
    return true

func records(index: int) -> Array:
    var result: Array = []
    for z in range(zones.size()):
        var zone: Dictionary = zones[z]
        if zone.queue.has(index):
            result.append({"zone": z, "kind": zone.kind, "owner": zone.owner,
                "position": [zone.position.x, zone.position.y],
                "wait_seconds": clock - float(zone.queue[index].since),
                "ticket": int(zone.queue[index].ticket)})
    return result
