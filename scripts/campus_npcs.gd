extends Node3D
## Nearby-only logical pool. One MultiMesh surface, zero NPC collision bodies/textures.
const PARTS = 10
var game: Node
var config: Dictionary
var pool: Array[Dictionary] = []
var anchors: Array[Dictionary] = []
var graph := AStar3D.new()
var batch := MultiMeshInstance3D.new()
var footprints: Array[Rect2] = []
var timer: float = 0
var pose_timer: float = 0
var elapsed: float = 0
var context: String = ""
var hour_override: int = -1 # Tests only. Live schedules follow the existing local clock.
var talking_id: String = ""
var decisions: int = 0
var ready_for_npcs: bool = false
var draw_updates: int = 0
var routes_requested: int = 0
var render_owners: Array[String] = []
var palette_owners: Array[String] = []

func _ready() -> void:
    config = preload("res://scripts/campus_rooms.gd").data()
    add_child(batch)
    call_deferred("_initialise")

func _initialise() -> void:
    var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/npc_paths.json"))
    graph.reserve_space(rows.size())
    for id in rows.size():
        var row: Array = rows[id]
        graph.add_point(id, Vector3(row[0] / 100.0, 0.13, row[1] / 100.0))
        for j in range(2, row.size()):
            graph.connect_points(id, int(row[j]))
    var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.LAYOUT_PATH))
    var positions := {}
    for feature in layout.features:
        var center := Vector2(feature.position[0], feature.position[1]) * float(game.WORLD_SCALE)
        positions[int(feature.id)] = Vector3(center.x, 0, center.y)
        if float(feature.height) > 0:
            var size := Vector2(feature.size[0], feature.size[1]) * float(game.WORLD_SCALE)
            footprints.append(Rect2(center - size / 2, size).grow(0.65))
    for record in config.locations:
        var anchor: Dictionary = record.duplicate()
        anchor["point"] = graph.get_closest_point(positions[int(record.feature_id)])
        anchor["position"] = graph.get_point_position(anchor.point)
        anchor["spots"] = _activity_spots(anchor)
        anchors.append(anchor)
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 1.0
    var mesh := BoxMesh.new()
    mesh.material = material
    batch.multimesh = MultiMesh.new()
    batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    batch.multimesh.use_colors = true
    batch.multimesh.mesh = mesh
    batch.multimesh.instance_count = mini(25,int(config.pool.maximum))*PARTS
    batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    batch.multimesh.visible_instance_count = 0
    render_owners.resize(mini(25, int(config.pool.maximum)))
    palette_owners.resize(mini(25, int(config.pool.maximum)))
    for i in range(mini(25,int(config.pool.maximum))):
        pool.append({"id":"","position":Vector3.ZERO,"yaw":0.0,"route":PackedVector3Array(),"step":0,"role":"student","site":"","activity":"phone","destination":"","routine":-1,"special":false,"slot":0,"services":false,"phase":i*0.7,"color":Color.WHITE})
    ready_for_npcs = true
    set_process(true)

func _path_clear(a: Vector3,b: Vector3) -> bool:
    var p := Vector2(a.x,a.z)
    var q := Vector2(b.x,b.z)
    for box in footprints:
        if not box.intersects(Rect2(p, Vector2.ZERO).expand(q), true): continue
        if box.has_point(p) or box.has_point(q): return false
        var corners: Array[Vector2] = [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
        for i in range(4):
            if Geometry2D.segment_intersects_segment(p,q,corners[i],corners[(i+1)%4]) != null: return false
    return true

func _activity_spots(anchor: Dictionary) -> Array:
    var result: Array = []
    var p: Vector3 = anchor.position
    var links: PackedInt64Array = graph.get_point_connections(anchor.point)
    if links.is_empty(): return result
    var direction: Vector3 = (graph.get_point_position(links[0])-p).normalized()
    var side: Vector3 = direction.cross(Vector3.UP)
    for j in config.ambient_slots.size():
        var pose: String = config.ambient_slots[j]
        var at: Vector3 = p+direction*(2.0+j*0.9)
        var yaw: float = atan2(-direction.x,-direction.z)
        if pose=="chat":
            var angle: float = (j-1)*TAU/3
            var center: Vector3 = p+direction*4
            at = center+direction*cos(angle)*0.9+side*sin(angle)*0.9
            yaw = atan2(-(center-at).x,-(center-at).z)
        elif pose=="queue":
            at = p+direction*(1.5+(j-7)*1.1)
            yaw += PI
        elif pose in ["sit","read","phone"]:
            at += side*1.4
        if not _path_clear(p,at):
            # Omit obstructed poses rather than spawning in walls.
            continue
        result.append({"slot":j,"position":at,"yaw":yaw,"activity":pose})
    return result

func hour() -> int:
    return hour_override if hour_override>=0 else int(Time.get_time_dict_from_system().hour)

func on_duty(role: String) -> bool:
    var hours: Array = config.roles[role].hours
    return hour()>=int(hours[0]) and hour()<int(hours[1])

func routine_index() -> int:
    for i in config.routine.size():
        if hour()>=int(config.routine[i].start) and hour()<int(config.routine[i].end): return i
    return 0

func _process(delta: float) -> void:
    if not ready_for_npcs or game.player==null: return
    elapsed+=delta
    timer-=delta
    pose_timer-=delta
    var next_context: String = game.social_location()
    if next_context!=context:
        context=next_context
        clear_pool()
        timer=0
    if timer<=0:
        timer=float(config.pool.decision_seconds)
        _refresh()
    if not game.task_panel.visible: talking_id=""
    # NPCs use a 20Hz visual update; distant gesture animation is omitted.
    if pose_timer>0: return
    var step_delta: float = minf(0.1,0.05-pose_timer)
    pose_timer=0.05
    var count: int = 0
    for npc in pool:
        if npc.id=="": continue
        if npc.id!=talking_id and npc.step<npc.route.size():
            var target: Vector3 = npc.route[npc.step]
            var direction: Vector3 = target-npc.position
            npc.yaw=lerp_angle(npc.yaw,atan2(-direction.x,-direction.z),minf(1,step_delta*8))
            npc.position=npc.position.move_toward(target,step_delta*float(config.pool.speed))
            if npc.position.distance_to(target)<0.05: npc.step+=1
        if npc.step < npc.route.size() or render_owners[count] != npc.id or npc.get("draw_activity", "") != npc.activity or npc.get("draw_position") != npc.position:
            _draw(npc,count)
            render_owners[count] = npc.id
            npc.draw_activity = npc.activity
            npc.draw_position = npc.position
        count+=1
    batch.multimesh.visible_instance_count=count*PARTS
    draw_updates+=1

func clear_pool() -> void:
    for npc in pool:npc.id=""
    for i in render_owners.size():
        render_owners[i] = ""
        palette_owners[i] = ""
    talking_id=""
    if batch.multimesh!=null:batch.multimesh.visible_instance_count=0

func role_for_site(site: String) -> String:
    for anchor in anchors:
        if anchor.site==site:return anchor.role
    return "adviser"

func _refresh() -> void:
    decisions+=1
    var cap: int = mini(pool.size(),int(config.pool.quality_caps[game.SETTINGS.effective_quality(game.preferences)]))
    if game.active_private_room or game.ride_bus!=null:
        clear_pool()
        return
    var candidates: Array[Dictionary] = []
    if not game.active_interior_site.is_empty():
        for point in get_tree().get_nodes_in_group("campus_actions"):
            if str(point.get_meta("action",""))!="staff":continue
            var role: String = str(point.get_meta("npc_role",role_for_site(game.active_interior_site)))
            if on_duty(role):candidates.append({"id":"room_staff","position":point.global_position,"yaw":0.0,"role":role,"site":game.active_interior_site,"special":true,"services":true,"activity":config.roles[role].activity,"slot":0})
    else:
        var nearby: Array[Dictionary] = []
        for anchor in anchors:
            if anchor.position.distance_squared_to(game.player.global_position)<pow(float(config.pool.radius),2):nearby.append(anchor)
        nearby.sort_custom(func(a,b):return a.position.distance_squared_to(game.player.global_position)<b.position.distance_squared_to(game.player.global_position))
        for anchor in nearby:
            if on_duty(anchor.role):candidates.append({"id":"staff_"+anchor.site,"position":anchor.position,"yaw":0.0,"site":anchor.site,"role":anchor.role,"special":true,"services":anchor.services,"activity":config.roles[anchor.role].activity,"slot":0})
        for anchor in nearby:
            var population: int = 12 if anchor.category==config.routine[routine_index()].category else 7
            for spot in anchor.spots.slice(0,population):
                var c: Dictionary = spot.duplicate()
                c.merge({"id":anchor.site+"_"+str(spot.slot),"site":anchor.site,"role":"student","special":false,"services":false})
                candidates.append(c)
    var wanted: Dictionary = {}
    for c in candidates.slice(0,cap):wanted[c.id]=c
    var active: int = 0
    for npc in pool:
        if npc.id=="":continue
        if active>=cap or (npc.id!=talking_id and (npc.position.distance_to(game.player.global_position)>float(config.pool.release_radius) or (npc.special and not wanted.has(npc.id)))):
            npc.id=""
        else:active+=1
    for c in candidates:
        var exists: bool = false
        for npc in pool:
            if npc.id==c.id:exists=true
        if exists:continue
        if active>=cap:
            if not c.special:break
            # Nearby staff must not be starved by retained ambient walkers.
            for npc in pool:
                if npc.id!="" and not npc.special and npc.id!=talking_id:
                    npc.id=""
                    active-=1
                    break
        if active>=cap:continue
        for npc in pool:
            if npc.id!="":continue
            npc.merge(c,true)
            npc.route=PackedVector3Array()
            npc.step=0
            npc.routine=routine_index()
            npc.destination=npc.site
            npc.color=Color.from_hsv(float(absi(str(npc.id).hash())%360)/360.0,0.45,0.65)
            active+=1
            break
    # Route only a bounded number per decision tick. Offscreen NPCs have no simulation.
    var route_budget: int = 2
    for npc in pool:
        if npc.id=="" or npc.special or context!="campus" or npc.id==talking_id:continue
        if route_budget<=0:break
        var routine: int = routine_index()
        if npc.routine!=routine:
            npc.routine=routine
            var goals: Array[Dictionary] = []
            for anchor in anchors:
                if anchor.category==config.routine[routine].category:goals.append(anchor)
            goals.sort_custom(func(a,b):return a.position.distance_squared_to(npc.position)<b.position.distance_squared_to(npc.position))
            for goal in goals.slice(0,3):
                if _route_to(npc,goal.point):
                    npc.destination=goal.site
                    npc.activity=config.routine[routine].activity
                    break
            route_budget-=1
        elif npc.activity=="walk" and npc.step>=npc.route.size() and decisions%4==0:
            var start: int = graph.get_closest_point(npc.position)
            var links: PackedInt64Array = graph.get_point_connections(start)
            if not links.is_empty():_route_to(npc,links[(decisions+int(npc.slot))%links.size()])
            route_budget-=1

func _route_to(npc: Dictionary, goal: int) -> bool:
    var start: int = graph.get_closest_point(npc.position)
    var route: PackedVector3Array = graph.get_point_path(start,goal)
    routes_requested+=1
    if route.size()<2 or not _path_clear(npc.position,route[0]):return false
    npc.route=route
    npc.step=0
    return true

func _part(index: int, base: Transform3D, at: Vector3, size: Vector3, tilt: float=0.0) -> void:
    # Palette colours are written only when a pooled slot changes owner or pose.
    batch.multimesh.set_instance_transform(index,base*Transform3D(Basis(Vector3.RIGHT,tilt).scaled(size),at))

func _set_palette(offset: int, color: Color, pose: String) -> void:
    var dark := Color("273549")
    batch.multimesh.set_instance_color(offset, color)
    batch.multimesh.set_instance_color(offset + 1, Color("965e3a"))
    batch.multimesh.set_instance_color(offset + 2, dark)
    batch.multimesh.set_instance_color(offset + 3, dark)
    batch.multimesh.set_instance_color(offset + 4, color)
    batch.multimesh.set_instance_color(offset + 5, color)
    batch.multimesh.set_instance_color(offset + 6, Color("dddac5") if pose == "read" else dark)
    batch.multimesh.set_instance_color(offset + 7, Color("76583a"))
    batch.multimesh.set_instance_color(offset + 8, dark)
    batch.multimesh.set_instance_color(offset + 9, dark)

func _draw(npc: Dictionary, index: int) -> void:
    var moving: bool = npc.step < npc.route.size()
    var pose: String = "walk" if moving else str(npc.activity)
    var seated: bool = pose in ["sit", "read"]
    var y: float = -0.45 if seated else 0.0
    var base := Transform3D(Basis(Vector3.UP, float(npc.yaw)), npc.position)
    var color: Color = npc.color
    var swing: float = sin(elapsed * 6.0 + npc.phase) * 0.45 if moving and npc.position.distance_to(game.player.global_position) < 20.0 else 0.0
    var offset: int = index * PARTS
    var palette_key: String = str(npc.id) + "|" + pose
    if palette_owners[index] != palette_key:
        _set_palette(offset, color, pose)
        palette_owners[index] = palette_key
    _part(offset, base, Vector3(0, 1.12 + y, 0), Vector3(0.52, 0.65, 0.3))
    _part(offset + 1, base, Vector3(0, 1.65 + y, 0), Vector3(0.32, 0.38, 0.32))
    for side in range(2):
        var x: float = -1.0 if side == 0 else 1.0
        _part(offset + 2 + side, base, Vector3(x * 0.15, 0.38, -0.28 if seated else 0.0), Vector3(0.21, 0.7, 0.23), PI / 2.0 if seated else swing * x)
        _part(offset + 4 + side, base, Vector3(x * 0.35, 1.05 + y, -0.18 if pose in ["phone", "read"] else 0.0), Vector3(0.16, 0.6, 0.18), -0.8 if pose in ["phone", "read", "chat"] else -swing * x)
    _part(offset + 6, base, Vector3(0, 1.12 + y, -0.4), Vector3(0.32, 0.035, 0.25) if pose == "read" else Vector3(0.12, 0.2, 0.025) if pose == "phone" else Vector3.ZERO)
    _part(offset + 7, base, Vector3(0, 0.45, 0.1), Vector3(0.65, 0.12, 0.6) if seated else Vector3.ZERO)
    _part(offset + 8, base, Vector3(-0.25, 0.22, 0.1), Vector3(0.08, 0.44, 0.5) if seated else Vector3.ZERO)
    _part(offset + 9, base, Vector3(0.25, 0.22, 0.1), Vector3(0.08, 0.44, 0.5) if seated else Vector3.ZERO)

func nearest(walker: Node3D) -> int:
    var result: int = -1
    var distance: float = 2.8
    for i in pool.size():
        if pool[i].id=="":continue
        var d: float = pool[i].position.distance_to(walker.global_position)
        if d<distance:
            distance=d
            result=i
    return result

func hint() -> String:
    var index: int = nearest(game.player)
    if index<0:return ""
    return str(config.dialogue.nearby).replace("{role}",config.roles[pool[index].role].title)

func try_interact(walker: Node3D) -> bool:
    var index: int = nearest(walker)
    if index<0 or game.profile_data.is_empty():return false
    talking_id=pool[index].id
    _dialogue(pool[index])
    return true

func _line(npc: Dictionary) -> String:
    var lines: Array = config.roles[npc.role].lines
    return str(lines[game.rng.randi_range(0,lines.size()-1)]).replace("{site}",npc.site).replace("{destination}",npc.destination)

func _dialogue(npc: Dictionary) -> void:
    game.task_title_label.text=str(config.roles[npc.role].title)+" · "+str(npc.site)
    game.task_status_label.text=_line(npc)
    for child in game.task_buttons_container.get_children():
        game.task_buttons_container.remove_child(child)
        child.queue_free()
    _button(config.dialogue.greet,func():game.task_status_label.text=config.dialogue.greeting)
    _button(config.dialogue.talk,func():game.task_status_label.text=_line(npc))
    if npc.special and npc.services:
        _button(config.dialogue.services,func():
            if npc.id!=talking_id or not on_duty(npc.role):
                game.task_status_label.text=str(config.dialogue.closed).replace("{start}",str(config.roles[npc.role].hours[0])).replace("{end}",str(config.roles[npc.role].hours[1]))
                return
            game._open_task_panel(npc.site))
    _button(config.dialogue.goodbye,game._close_task_panel)
    game.task_panel.visible=true
    game._layout_action_menus()
    game.player.velocity=Vector3.ZERO
    game.player.set_physics_process(false)
    game.player.set_process_unhandled_input(false)
    game._set_mouse_capture(false)

func _button(title: String, action: Callable) -> void:
    var button := Button.new()
    button.text=title
    button.custom_minimum_size.y=48
    button.pressed.connect(action)
    game.task_buttons_container.add_child(button)
