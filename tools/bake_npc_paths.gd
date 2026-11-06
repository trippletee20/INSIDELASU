extends SceneTree
## Regenerate when campus roads or building footprints change.
const Game = preload("res://scripts/main.gd")
var graph := AStar3D.new()
var footprints: Array[Rect2] = []
var lookup: Dictionary = {}
var cells: Dictionary = {}

func _initialize() -> void:
    _build_paths()
    var rows: Array = []
    for id in graph.get_point_ids():
        var position := graph.get_point_position(id)
        var row := [roundi(position.x * 100), roundi(position.z * 100)]
        for other in graph.get_point_connections(id):
            if other < id:
                row.append(other)
        rows.append(row)
    var serialized := JSON.stringify(rows) + "\n"
    var target := "res://data/npc_paths.json"
    if "--check" in OS.get_cmdline_user_args():
        quit(0 if FileAccess.get_file_as_string(target) == serialized else 1)
        return
    var file := FileAccess.open(target, FileAccess.WRITE)
    file.store_string(serialized)
    file.close()
    quit()

func _path_clear(a: Vector3,b: Vector3) -> bool:
    var p := Vector2(a.x,a.z)
    var q := Vector2(b.x,b.z)
    for box in footprints:
        if box.has_point(p) or box.has_point(q): return false
        var corners: Array[Vector2] = [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
        for i in range(4):
            if Geometry2D.segment_intersects_segment(p,q,corners[i],corners[(i+1)%4]) != null: return false
    return true

func _point(p: Vector3) -> int:
    var key := Vector2(snappedf(p.x,0.01),snappedf(p.z,0.01))
    if lookup.has(key): return lookup[key]
    var id: int = graph.get_point_count()
    graph.add_point(id,Vector3(key.x,0.13,key.y))
    lookup[key] = id
    var cell := Vector2i(floori(key.x/10),floori(key.y/10))
    if not cells.has(cell): cells[cell] = []
    cells[cell].append(id)
    return id

func _build_paths() -> void:
    var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.LAYOUT_PATH))
    for feature in layout.features:
        if float(feature.height)<=0: continue
        var center: Vector2 = Vector2(feature.position[0],feature.position[1])*Game.WORLD_SCALE
        var size: Vector2 = Vector2(feature.size[0],feature.size[1])*Game.WORLD_SCALE
        footprints.append(Rect2(center-size/2,size).grow(0.65))
    var roads: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.ROAD_NETWORK_PATH))
    # Slice initial graph work over frames. No duplicate map is shipped in the pack.
    for road in roads.road_routes:
        for i in range(road.points.size()-1):
            var a: Vector3 = Vector3(road.points[i][0],0,road.points[i][1])*Game.WORLD_SCALE
            var b: Vector3 = Vector3(road.points[i+1][0],0,road.points[i+1][1])*Game.WORLD_SCALE
            var offset: Vector3 = (b-a).normalized().cross(Vector3.UP)*4.7
            for side in [-1,1]:
                var start: Vector3 = a+offset*side
                var end: Vector3 = b+offset*side
                if not _path_clear(start,end): continue
                var count: int = maxi(1,ceili(start.distance_to(end)/16))
                var previous: int = -1
                for j in range(count+1):
                    var id: int = _point(start.lerp(end,float(j)/count))
                    if previous>=0 and previous!=id: graph.connect_points(previous,id)
                    previous=id
    for id in graph.get_point_ids():
        var p: Vector3 = graph.get_point_position(id)
        var cell := Vector2i(floori(p.x/10),floori(p.z/10))
        var nearby: Array = []
        for x in range(-1,2):
            for z in range(-1,2):
                for other in cells.get(cell+Vector2i(x,z),[]):
                    var d: float = p.distance_squared_to(graph.get_point_position(other))
                    if other!=id and d<100: nearby.append([d,other])
        nearby.sort_custom(func(a,b):return a[0]<b[0])
        for entry in nearby.slice(0,3):
            if not graph.are_points_connected(id,entry[1]) and _path_clear(p,graph.get_point_position(entry[1])):
                graph.connect_points(id,entry[1])
    lookup.clear()
    cells.clear()

