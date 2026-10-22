extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const LAYOUT_PATH = "res://data/campus_layout.json"
const ROAD_NETWORK_PATH = "res://data/road_network_v0.4.json"
const WORLD_SCALE = 2.6
const ARCHITECTURE_SCRIPT = preload("res://scripts/architecture_builder.gd")
const LANDSCAPE_PATH = "res://data/landscape_v0.5.json"
const AMENITIES_PATH = "res://data/amenities_v0.6.json"
const AMENITIES_SCRIPT = preload("res://scripts/amenities_builder.gd")
const TRANSIT_SCRIPT = preload("res://scripts/transit_manager.gd")
const TRANSIT_ROUTES_PATH = "res://data/transit_routes_v0.7.json"
const TASK_CATALOG_PATH: String = "res://data/task_catalog_v0.9.json"
const INTERIOR_CATALOG_PATH: String = "res://data/interior_catalog_v0.10.json"
const INTERIOR_SCRIPT = preload("res://scripts/interior_builder.gd")
const SAVE_PATH = "user://inside_lasu_save.json"
const SAVE_STORE = preload("res://scripts/save_store.gd")
const STUDENT_UI = preload("res://scenes/ui/student_ui.tscn")
var student_ui
var campus_phone
var campus_social
var active_campus_room: int = -1
const CAMPUS_ROOMS = preload("res://scripts/campus_rooms.gd")
const MOBILE_CONTROLS = preload("res://scripts/mobile_controls.gd")
var mobile_controls
var billboard_slots: Array[Node3D] = []
var selected_billboard: String = ""
var transactions: Array = []
var save_extras: Dictionary = {}
var autosave_timer: float = 0.0
var ui_timer: float = 0.0
const HOSTEL_RENT_AMOUNT: int = 525000
const SHUTTLE_FARE: int = 150
const FACULTY_DEPARTMENTS: Dictionary = {
    "Faculty of Education": ["Adult Education", "Educational Management", "Guidance and Counselling", "English Education", "Mathematics Education", "Biology Education", "Chemistry Education", "Computer Science Education", "Physical and Health Education"],
    "Faculty of Science": ["Computer Science", "Microbiology", "Biology", "Chemistry", "Physics", "Mathematics", "Zoology", "Botany", "Fisheries", "Environmental Science"],
    "Faculty of Law": ["Law"],
    "Faculty of Social Sciences (FSS)": ["Economics", "Sociology", "Political Science", "Psychology", "Geography and Planning"],
    "Faculty of Management Sciences (FMS)": ["Accounting", "Business Administration", "Banking and Finance", "Marketing", "Insurance", "Industrial Relations and Personnel Management"],
    "Faculty of Arts": ["English", "History and International Studies", "Theatre Arts", "Music", "Philosophy", "French", "Yoruba", "Arabic"],
    "Communication and Media Studies": ["Mass Communication", "Broadcasting", "Journalism", "Public Relations"],
    "School of Transport Studies": ["Transport Management", "Logistics and Supply Chain Management"],
    "Other / Not listed": ["General Studies", "Other Department"]
}
var amenities_builder = AMENITIES_SCRIPT.new()
var architect = ARCHITECTURE_SCRIPT.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var player: CharacterBody3D
var overview_camera: Camera3D
var overview_on: bool = false
var hud_label: Label
var hud_energy_meter: ProgressBar
var hud_stamina_meter: ProgressBar
var hud_stress_meter: ProgressBar
var hud_time_chip: Label
var notice: String = ""
var notice_timer: float = 0.0
var campus_data: Dictionary = {}
var road_network: Dictionary = {}
var transit_system
var ride_bus: Node3D = null
var chosen_bus: Node3D = null
var shuttle_menu: PanelContainer
var shuttle_menu_title: Label
var destination_option: OptionButton
var shuttle_fare_label: Label
var destination_positions: Dictionary = {}
var destination_building_positions: Dictionary = {}
var location_visits: Dictionary = {}

# Student profile, economy and accommodation state.
var profile_data: Dictionary = {}
var wallet_balance: int = 0
var last_daily_reward_date: String = ""
var last_daily_reward_amount: int = 0
var total_earned: int = 0
var total_spent: int = 0
var last_curfew_notice_key: String = ""
var last_clock_stamp: String = ""
var profile_layer: CanvasLayer
var profile_error_label: Label
var profile_name_input: LineEdit
var profile_gender_option: OptionButton
var profile_faculty_option: OptionButton
var profile_department_option: OptionButton
var profile_study_mode_option: OptionButton
var profile_hostel_option: OptionButton
var wallet_panel: PanelContainer
var wallet_summary_label: Label
var wallet_balance_label: Label
var daily_reward_button: Button
var task_catalog: Dictionary = {}
var building_experiences: Dictionary = {}
var challenge_site: String = ""
var challenge_entry: Dictionary = {}
var challenge_step: int = 0
var task_panel: PanelContainer
var task_panel_layer: CanvasLayer
var task_title_label: Label
var task_status_label: Label
var task_buttons_container: VBoxContainer
var task_completion_counts: Dictionary = {}
var task_daily_completions: Dictionary = {}
var task_inventory: Array = []
var social_reputation: int = 0
var energy: float = 92.0
var stamina: float = 90.0
var stress: float = 8.0
var skills: Dictionary = {}
var skill_xp: Dictionary = {}
var skill_daily_xp: Dictionary = {}
var interior_catalog: Dictionary = {}
var interior_builder
var active_interior_site: String = ""
var active_interior_floor: int = 0
var active_private_room: bool = false
var room_furniture: Array = []
var room_visitors_allowed: bool = false
var last_room_rest_unix: int = 0
var outdoor_return_position: Vector3 = Vector3.ZERO

func _ready() -> void:
    var interface_font: Font = load("res://assets/fonts/NotoSans.ttf")
    ThemeDB.get_default_theme().default_font = interface_font
    ThemeDB.fallback_font = interface_font
    rng.randomize()
    _create_environment()
    _load_map_data()
    _load_task_catalog()
    _load_interior_catalog()
    interior_builder = INTERIOR_SCRIPT.new()
    interior_builder.name = "ModularInteriorSystem"
    add_child(interior_builder)
    interior_builder.visible = false
    _create_ground()
    _load_road_network()
    _create_roads()
    _create_features()
    _create_landscape()
    _create_amenities()
    _register_interactive_seats()
    _create_player()
    _create_overview_camera()
    _create_hud()
    _create_wallet_panel()
    _create_task_panel()
    _create_transit_system()
    _create_shuttle_menu()
    _initialise_student_profile()
    mobile_controls = MOBILE_CONTROLS.new()
    add_child(mobile_controls)
    mobile_controls.action_requested.connect(_mobile_action)
    mobile_controls.look_requested.connect(_look_around)
    mobile_controls.world_tapped.connect(_try_billboard_at)
    _register_billboards(self)
    campus_social = preload("res://scripts/campus_social.gd").new()
    campus_social.game = self
    add_child(campus_social)
    campus_phone = preload("res://scripts/campus_phone.gd").new()
    campus_phone.game = self
    campus_phone.online = campus_social
    var saved_phone: Variant = save_extras.get("campus_phone", {})
    if saved_phone is Dictionary:
        for key in campus_phone.state:
            if saved_phone.has(key) and typeof(saved_phone[key]) == typeof(campus_phone.state[key]):
                campus_phone.state[key] = saved_phone[key]
        if saved_phone.get("societies", []) is Array:
            campus_phone.state["societies"] = saved_phone.get("societies", [])
    add_child(campus_phone)
    campus_phone.opened_changed.connect(_on_student_modal)
    student_ui.phone_requested.connect(func(): campus_phone.open())
    student_ui.places_requested.connect(func():
        if not active_interior_site.is_empty(): _open_task_panel(active_interior_site)
        elif player.nearby_feature != null: show_interaction(str(player.nearby_feature.get_meta("campus_name", "")))
        else: campus_phone.open("Places & tasks"))
    _create_entrance_markers()

func _load_map_data() -> void:
    var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
    if file == null:
        push_error("Cannot open campus layout data: " + LAYOUT_PATH)
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        campus_data = parsed
    else:
        push_error("Campus JSON is invalid")

func _create_environment() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.30, 0.57, 0.80)
    sky_mat.sky_horizon_color = Color(0.78, 0.89, 0.96)
    sky.sky_material = sky_mat
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.76, 0.81, 0.86)
    env.ambient_light_energy = 0.7
    env_node.environment = env
    add_child(env_node)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-60, -40, 0)
    sun.light_energy = 1.2
    sun.shadow_enabled = not OS.has_feature("web")
    add_child(sun)

func _create_ground() -> void:
    var body := StaticBody3D.new()
    body.name = "Ground"
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(240.0 * WORLD_SCALE, 0.4, 195.0 * WORLD_SCALE)
    mesh_instance.mesh = mesh
    mesh_instance.position.y = -0.22
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.39, 0.57, 0.37)
    mat.roughness = 1.0
    mesh_instance.material_override = mat
    body.add_child(mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(240.0 * WORLD_SCALE, 0.4, 195.0 * WORLD_SCALE)
    collision.shape = shape
    collision.position.y = -0.22
    body.add_child(collision)
    add_child(body)

func _load_road_network() -> void:
    var file := FileAccess.open(ROAD_NETWORK_PATH, FileAccess.READ)
    if file == null:
        push_error("Road network file missing: " + ROAD_NETWORK_PATH)
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        road_network = parsed
    else:
        push_error("Road network JSON is invalid")

func _create_roads() -> void:
    # Inside LASU v0.12: widened two-way asphalt with protected-site safety envelopes. Avoid unsafe
    # road meshes through campus sites and per-segment material duplication.
    for route_variant in road_network.get("road_routes", []):
        var route: Dictionary = route_variant
        var pts: Array = route.get("points", [])
        if pts.size() < 2:
            continue
        var route_id: String = str(route.get("id", "unknown"))
        var main_road: bool = str(route.get("class", "local")) == "main"
        var route_clear: bool = true
        for i in range(pts.size() - 1):
            var raw_a: Array = pts[i]
            var raw_b: Array = pts[i + 1]
            var a: Vector2 = Vector2(float(raw_a[0]), float(raw_a[1]))
            var b: Vector2 = Vector2(float(raw_b[0]), float(raw_b[1]))
            if not _road_segment_clear_of_features(a, b, 1.2):
                push_warning("Road safety guard omitted unsafe route %s at segment %s." % [route_id, str(i)])
                route_clear = false
                break
        if not route_clear:
            continue
        # Build at least two 3.1 m lanes on every route, wider where there is
        # geometric space. Two pinch points beside open campus features use 6.2 m
        # instead of letting the asphalt clip those protected areas.
        for segment_index in range(pts.size() - 1):
            var segment_points: Array = [pts[segment_index], pts[segment_index + 1]]
            var point_a: Array = pts[segment_index]
            var point_b: Array = pts[segment_index + 1]
            var road_a: Vector2 = Vector2(float(point_a[0]), float(point_a[1]))
            var road_b: Vector2 = Vector2(float(point_b[0]), float(point_b[1]))
            var asphalt_width: float = 10.0
            if not _road_segment_clear_of_features(road_a, road_b, asphalt_width * 0.5 / WORLD_SCALE):
                asphalt_width = 8.0
            if not _road_segment_clear_of_features(road_a, road_b, asphalt_width * 0.5 / WORLD_SCALE):
                asphalt_width = 7.2
            if not _road_segment_clear_of_features(road_a, road_b, asphalt_width * 0.5 / WORLD_SCALE):
                asphalt_width = 6.2
            var sidewalk_width: float = asphalt_width + 1.2
            if not _road_segment_clear_of_features(road_a, road_b, sidewalk_width * 0.5 / WORLD_SCALE):
                # Preserve the adjacent garden/hostel footprint; omit the extra
                # shoulder on unusually tight schematic corners.
                sidewalk_width = asphalt_width
            _draw_path(segment_points, sidewalk_width, Color(0.72, 0.71, 0.66), 0.018)
            _draw_path(segment_points, asphalt_width, Color(0.18, 0.21, 0.24), 0.085)
            _draw_road_dashes(segment_points)
    # Individual footpaths connect the road to the facade of a building.
    for access in road_network.get("pedestrian_access", []):
        _draw_path(access.get("points", []), 1.45, Color(0.93, 0.85, 0.66), 0.12)
    # Preserve secondary paths as a distinct visual layer; they are not all roads.
    for pts in campus_data.get("water_or_secondary_paths", []):
        _draw_path(pts, 1.7, Color(0.30, 0.66, 0.69), 0.033)

func _road_segment_clear_of_features(a: Vector2, b: Vector2, clearance: float = 1.2) -> bool:
    for feature_variant in campus_data.get("features", []):
        var feature: Dictionary = feature_variant
        var kind: String = str(feature.get("kind", ""))
        if kind == "landmark" or kind == "unverified":
            continue
        var pos: Array = feature.get("position", [0.0, 0.0])
        var dims: Array = feature.get("size", [4.0, 4.0])
        var centre: Vector2 = Vector2(float(pos[0]), float(pos[1]))
        var size: Vector2 = Vector2(float(dims[0]), float(dims[1]))
        if _segment_intersects_expanded_rect(a, b, centre, size, clearance):
            return false
    return true

func _segment_intersects_expanded_rect(a: Vector2, b: Vector2, centre: Vector2, size: Vector2, margin: float) -> bool:
    # Exact segment-vs-expanded-AABB test prevents roads being rendered inside campus sites.
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

func _draw_path(points: Array, width: float, color: Color, y_level: float) -> void:
    if points.size() < 2:
        return
    var material := _make_material(color)
    for i in range(points.size() - 1):
        var a := Vector3(float(points[i][0]) * WORLD_SCALE, y_level, float(points[i][1]) * WORLD_SCALE)
        var b := Vector3(float(points[i + 1][0]) * WORLD_SCALE, y_level, float(points[i + 1][1]) * WORLD_SCALE)
        var length := a.distance_to(b)
        if length < 0.05:
            continue
        var segment := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(length + 0.15, 0.07, width)
        segment.mesh = mesh
        segment.position = (a + b) * 0.5
        segment.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
        segment.material_override = material
        add_child(segment)

func _draw_road_dashes(points: Array) -> void:
    if points.size() < 2:
        return
    var yellow := _make_material(Color(0.94, 0.83, 0.46))
    for i in range(points.size() - 1):
        var a := Vector3(float(points[i][0]) * WORLD_SCALE, 0.13, float(points[i][1]) * WORLD_SCALE)
        var b := Vector3(float(points[i + 1][0]) * WORLD_SCALE, 0.13, float(points[i + 1][1]) * WORLD_SCALE)
        var distance := a.distance_to(b)
        if distance < 5.0:
            continue
        var direction := (b - a).normalized()
        var t := 1.0
        while t + 1.8 < distance:
            var dash := MeshInstance3D.new()
            var mesh := BoxMesh.new()
            mesh.size = Vector3(1.8, 0.018, 0.12)
            dash.mesh = mesh
            dash.position = a + direction * (t + 0.9)
            dash.rotation.y = atan2(-direction.z, direction.x)
            dash.material_override = yellow
            add_child(dash)
            t += 5.0

func _create_features() -> void:
    for item in campus_data.get("features", []):
        _add_feature(item)

func _add_feature(item: Dictionary) -> void:
    var name := str(item.get("name", "Unnamed"))
    var kind := str(item.get("kind", "academic"))
    var p: Array = item.get("position", [0.0, 0.0])
    var dims: Array = item.get("size", [4.0, 4.0])
    var height := float(item.get("height", 4.0)) * WORLD_SCALE
    if name == "Arcade":
        # Ground floor + one full upper floor; collision matches the two-level facade.
        height = 4.45 * WORLD_SCALE
    var center := Vector3(float(p[0]) * WORLD_SCALE, 0, float(p[1]) * WORLD_SCALE)
    var w := float(dims[0]) * WORLD_SCALE
    var depth := float(dims[1]) * WORLD_SCALE
    var node := StaticBody3D.new()
    node.name = "Site_%02d" % int(item.get("id", 0))
    node.position = center
    node.set_meta("campus_name", name)
    node.set_meta("feature_half_width", w * 0.5)
    node.set_meta("feature_half_depth", depth * 0.5)
    node.add_to_group("campus_features")
    add_child(node)
    if kind == "landmark" or kind == "unverified":
        if kind == "landmark" and name.to_lower().contains("gate"):
            if name == "Main Gate 2 (Franklas Gate)":
                # Corrected facing: FRONT/ENTRANCE faces the campus's right/east
                # edge (+X), not the north/south direction of the through-road.
                # The gate's approved site marker remains unmodified in JSON.
                # Set its 3D portal back from the live traffic lane to avoid
                # placing solid columns in the middle of the north-south road.
                node.rotation_degrees.y = 90.0
                node.position.x += 6.0
            architect._gate(node, name, w, depth)
            if name == "Main Gate 2 (Franklas Gate)":
                # Collisions follow the rotated doorway; the clear centre stays open.
                var gate_span: float = maxf(w * 0.70, 8.0)
                for side in [-1.0, 1.0]:
                    var pillar_collision := CollisionShape3D.new()
                    var pillar_shape := BoxShape3D.new()
                    pillar_shape.size = Vector3(1.55, 5.5, 1.55)
                    pillar_collision.shape = pillar_shape
                    pillar_collision.position = Vector3(float(side) * gate_span * 0.5, 2.75, 0.0)
                    node.add_child(pillar_collision)
            _add_label(node, name, 8.0)
        else:
            var marker := MeshInstance3D.new()
            var marker_mesh := CylinderMesh.new()
            marker_mesh.top_radius = 0.45
            marker_mesh.bottom_radius = 0.45
            marker_mesh.height = 0.18
            marker.mesh = marker_mesh
            marker.position.y = 0.1
            marker.material_override = _make_material(Color(0.92, 0.68, 0.20) if kind == "landmark" else Color(0.72, 0.32, 0.31))
            node.add_child(marker)
            _add_label(node, name, 1.5)
        return
    architect.build(node, item, w, depth, height)
    # Only solid, completed buildings receive the original full-footprint collider.
    # Open-air markets, gardens, fields and incomplete hostels remain walkable.
    var is_incomplete := name.to_lower().contains("incomplete") or name.to_lower().contains("almost complete")
    if kind != "outdoor" and kind != "commercial" and not is_incomplete and height > 0.5:
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(w, height, depth)
        collision.shape = shape
        collision.position.y = height * 0.5
        node.add_child(collision)
    _add_label(node, name, max(height, 0.12) + 2.0)

func _make_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    return mat

func _feature_color(kind: String, name: String) -> Color:
    if "incomplete" in name.to_lower() or "almost complete" in name.to_lower():
        return Color(0.58, 0.60, 0.61)
    match kind:
        "residential": return Color(0.88, 0.66, 0.68)
        "academic": return Color(0.61, 0.73, 0.89)
        "religious": return Color(0.75, 0.67, 0.86)
        "commercial": return Color(0.95, 0.78, 0.43)
        "outdoor": return Color(0.35, 0.70, 0.43)
    return Color(0.75, 0.75, 0.75)

func _add_label(parent: Node3D, text: String, height: float) -> void:
    var label := Label3D.new()
    label.text = text
    label.position.y = height
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 36
    label.pixel_size = 0.012
    label.modulate = Color(0.09, 0.15, 0.20)
    label.outline_size = 8
    label.outline_modulate = Color(1, 1, 1, 0.95)
    label.no_depth_test = true
    label.visibility_range_end = 55.0
    parent.add_child(label)

func _create_landscape() -> void:
    var file := FileAccess.open(LANDSCAPE_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var trees: Array = parsed.get("trees", [])
    var poles: Array = parsed.get("streetlights", [])
    _place_tree_multimeshes(trees)
    _place_streetlights(poles)

func _place_tree_multimeshes(trees: Array) -> void:
    var trunks := MultiMesh.new()
    trunks.transform_format = MultiMesh.TRANSFORM_3D
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.26
    trunk_mesh.bottom_radius = 0.38
    trunk_mesh.height = 4.4
    trunk_mesh.radial_segments = 7
    trunks.mesh = trunk_mesh
    trunks.instance_count = trees.size()
    var canopies := MultiMesh.new()
    canopies.transform_format = MultiMesh.TRANSFORM_3D
    var foliage_mesh := SphereMesh.new()
    foliage_mesh.radius = 2.8
    foliage_mesh.height = 5.4
    foliage_mesh.radial_segments = 9
    foliage_mesh.rings = 5
    canopies.mesh = foliage_mesh
    canopies.instance_count = trees.size()
    for i in range(trees.size()):
        var x := float(trees[i][0]) * WORLD_SCALE
        var z := float(trees[i][1]) * WORLD_SCALE
        var scale_factor := float(trees[i][2])
        trunks.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(scale_factor, scale_factor, scale_factor)), Vector3(x, 2.2 * scale_factor, z)))
        canopies.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(scale_factor, scale_factor, scale_factor)), Vector3(x, 5.9 * scale_factor, z)))
    var trunk_inst := MultiMeshInstance3D.new()
    trunk_inst.multimesh = trunks
    trunk_inst.material_override = _make_material(Color(0.43, 0.29, 0.18))
    add_child(trunk_inst)
    var foliage_inst := MultiMeshInstance3D.new()
    foliage_inst.multimesh = canopies
    foliage_inst.material_override = _make_material(Color(0.16, 0.43, 0.25))
    add_child(foliage_inst)

func _place_streetlights(poles: Array) -> void:
    var posts := MultiMesh.new()
    posts.transform_format = MultiMesh.TRANSFORM_3D
    var post_mesh := CylinderMesh.new()
    post_mesh.top_radius = 0.09
    post_mesh.bottom_radius = 0.13
    post_mesh.height = 6.5
    post_mesh.radial_segments = 8
    posts.mesh = post_mesh
    posts.instance_count = poles.size()
    var globes := MultiMesh.new()
    globes.transform_format = MultiMesh.TRANSFORM_3D
    var globe_mesh := SphereMesh.new()
    globe_mesh.radius = 0.42
    globe_mesh.height = 0.84
    globe_mesh.radial_segments = 8
    globe_mesh.rings = 4
    globes.mesh = globe_mesh
    globes.instance_count = poles.size()
    for i in range(poles.size()):
        var x := float(poles[i][0]) * WORLD_SCALE
        var z := float(poles[i][1]) * WORLD_SCALE
        posts.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 3.25, z)))
        globes.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 6.7, z)))
    var pole_inst := MultiMeshInstance3D.new()
    pole_inst.multimesh = posts
    pole_inst.material_override = _make_material(Color(0.26, 0.30, 0.33))
    add_child(pole_inst)
    var globe_inst := MultiMeshInstance3D.new()
    globe_inst.multimesh = globes
    globe_inst.material_override = _make_material(Color(1.0, 0.92, 0.66))
    add_child(globe_inst)

func _create_amenities() -> void:
    # All shelter/billboard/parked-vehicle placement data lives in one editable JSON.
    var file := FileAccess.open(AMENITIES_PATH, FileAccess.READ)
    if file == null:
        push_warning("Optional v0.6 amenities file is missing")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Optional v0.6 amenities data could not be parsed")
        return
    amenities_builder.create_all(self, parsed, WORLD_SCALE)

func _create_transit_system() -> void:
    var file := FileAccess.open(TRANSIT_ROUTES_PATH, FileAccess.READ)
    if file == null:
        push_warning("Shuttle route data missing: " + TRANSIT_ROUTES_PATH)
        return
    var raw_data = JSON.parse_string(file.get_as_text())
    if typeof(raw_data) != TYPE_DICTIONARY:
        push_warning("Shuttle route data is not valid JSON")
        return
    var amenity_file := FileAccess.open(AMENITIES_PATH, FileAccess.READ)
    if amenity_file == null:
        push_warning("Cannot load waiting shelter stops")
        return
    var raw_amenities = JSON.parse_string(amenity_file.get_as_text())
    if typeof(raw_amenities) != TYPE_DICTIONARY:
        return
    transit_system = TRANSIT_SCRIPT.new()
    transit_system.name = "ShuttleServices"
    add_child(transit_system)
    var route_data: Dictionary = raw_data
    var stop_data: Dictionary = raw_amenities
    var shelter_list: Array = stop_data.get("shelters", [])
    transit_system.initialise(route_data, shelter_list, WORLD_SCALE, road_network, campus_data.get("features", []))

func _create_shuttle_menu() -> void:
    var layer: CanvasLayer = CanvasLayer.new()
    layer.name = "ShuttleInteractionLayer"
    layer.layer = 5
    add_child(layer)
    shuttle_menu = PanelContainer.new()
    shuttle_menu.name = "DestinationBoardingMenu"
    shuttle_menu.position = Vector2(340, 80)
    shuttle_menu.custom_minimum_size = Vector2.ZERO
    shuttle_menu.visible = false
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.055, 0.12, 0.17, 0.97)
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    style.content_margin_left = 16
    style.content_margin_top = 14
    style.content_margin_right = 16
    style.content_margin_bottom = 14
    shuttle_menu.add_theme_stylebox_override("panel", style)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    var boarding_scroll := ScrollContainer.new()
    boarding_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    shuttle_menu.add_child(boarding_scroll)
    boarding_scroll.add_child(column)
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    shuttle_menu_title = Label.new()
    shuttle_menu_title.add_theme_font_size_override("font_size", 17)
    shuttle_menu_title.add_theme_color_override("font_color", Color.WHITE)
    shuttle_menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(shuttle_menu_title)
    var destination_label: Label = Label.new()
    destination_label.text = "Choose your destination. Every destination has a designated roadside stop."
    destination_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.97))
    destination_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(destination_label)
    destination_option = OptionButton.new()
    destination_option.custom_minimum_size = Vector2(0, 48)
    destination_option.fit_to_longest_item = false
    destination_option.clip_text = true
    destination_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    destination_option.item_selected.connect(_on_destination_selected)
    column.add_child(destination_option)
    _populate_shuttle_destinations()
    shuttle_fare_label = Label.new()
    shuttle_fare_label.add_theme_color_override("font_color", Color(0.80, 0.92, 0.83))
    shuttle_fare_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(shuttle_fare_label)
    _refresh_shuttle_fare_label()
    var travel_buttons: BoxContainer = VBoxContainer.new() if MOBILE_CONTROLS.touch_device() else HBoxContainer.new()
    travel_buttons.add_theme_constant_override("separation", 12)
    column.add_child(travel_buttons)
    var ride_button: Button = Button.new()
    ride_button.text = "RIDE & WATCH • ₦150"
    ride_button.custom_minimum_size = Vector2(0, 48)
    ride_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ride_button.pressed.connect(_confirm_board_shuttle)
    travel_buttons.add_child(ride_button)
    var quick_button: Button = Button.new()
    quick_button.text = "QUICK TRAVEL • ₦150"
    quick_button.custom_minimum_size = Vector2(0, 48)
    quick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quick_button.pressed.connect(_confirm_quick_travel)
    travel_buttons.add_child(quick_button)
    var pass_row: HBoxContainer = HBoxContainer.new()
    pass_row.add_theme_constant_override("separation", 12)
    column.add_child(pass_row)
    var pass_button: Button = Button.new()
    pass_button.text = "PASS / WALK"
    pass_button.custom_minimum_size = Vector2(0, 48)
    pass_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pass_button.pressed.connect(_decline_board_shuttle)
    pass_row.add_child(pass_button)
    layer.add_child(shuttle_menu)

func _populate_shuttle_destinations() -> void:
    if destination_option == null:
        return
    destination_option.clear()
    destination_positions.clear()
    destination_building_positions.clear()
    var destination_names: Array[String] = []
    for raw_item in campus_data.get("features", []):
        var item: Dictionary = raw_item
        var name: String = str(item.get("name", ""))
        if name.is_empty():
            continue
        if transit_system != null and not transit_system.is_selectable_destination(item):
            continue
        var coords: Array = item.get("position", [0.0, 0.0])
        var feature_center: Vector2 = Vector2(float(coords[0]), float(coords[1]))
        destination_building_positions[name] = feature_center
        if transit_system != null:
            destination_positions[name] = transit_system.destination_road_target(name, feature_center)
        else:
            destination_positions[name] = feature_center
        destination_names.append(name)
    destination_names.sort()
    for name in destination_names:
        destination_option.add_item(name)
    if destination_option.item_count > 0:
        destination_option.select(0)
    _refresh_shuttle_fare_label()

func _on_destination_selected(_index: int) -> void:
    _refresh_shuttle_fare_label()

func _refresh_shuttle_fare_label() -> void:
    if shuttle_fare_label == null:
        return
    var balance_text: String = _format_naira(wallet_balance)
    var destination_name: String = "the selected stop"
    var walk_note: String = ""
    var eta_note: String = ""
    if destination_option != null and destination_option.item_count > 0 and destination_option.get_selected() >= 0:
        destination_name = destination_option.get_item_text(destination_option.get_selected())
        if transit_system != null:
            var walk_distance: float = transit_system.destination_walk_distance(destination_name)
            if walk_distance >= 30.0:
                walk_note = " • longer final walk"
            elif walk_distance > 0.0:
                walk_note = " • short walk to building"
            if chosen_bus != null:
                var eta_minutes: int = transit_system.estimate_destination_minutes(chosen_bus, destination_name)
                if eta_minutes > 0:
                    eta_note = " • approx. " + str(eta_minutes) + " min ride"
    shuttle_fare_label.text = "Fare: ₦150 per ride • Wallet: " + balance_text + "\nDestination: " + destination_name + eta_note + walk_note + "\nRide & Watch shows the trip; Quick Travel skips the animation."

func try_vehicle_interaction(walker: Node3D) -> bool:
    if profile_data.is_empty():
        return true
    if ride_bus != null:
        if transit_system != null and transit_system.has_arrived(ride_bus):
            _disembark_shuttle()
        else:
            notice = "You're riding. Wait until the shuttle reaches your destination."
            notice_timer = 3.0
        return true
    if shuttle_menu != null and shuttle_menu.visible:
        return true
    if transit_system == null or overview_on:
        return false
    var near_bus: Node3D = transit_system.nearest_boardable_bus(walker.global_position, 7.0)
    if near_bus == null:
        var nearby_stop_name: String = transit_system.nearest_destination_stop_name(walker.global_position, 3.0)
        if nearby_stop_name.is_empty():
            return false
        var pickup_eta: int = transit_system.estimate_pickup_minutes(nearby_stop_name)
        if transit_system.has_pickup_en_route_to_stop(nearby_stop_name):
            notice = "A shuttle is already on its way to this stand. Stay nearby; press E when it arrives."
            notice_timer = 5.0
        elif transit_system.request_pickup(nearby_stop_name):
            var eta_text: String = ""
            if pickup_eta > 0:
                eta_text = " Approximate arrival: " + str(pickup_eta) + " min."
            notice = "Shuttle dispatched to " + nearby_stop_name + ". Stay near the stand; press E when it arrives to choose your destination." + eta_text
            notice_timer = 7.0
        else:
            notice = "No shuttle can reach this stand right now. Try again shortly."
            notice_timer = 4.0
        return true
    transit_system.prepare_for_pickup_boarding(near_bus)
    chosen_bus = near_bus
    transit_system.set_menu_hold(chosen_bus, true)
    shuttle_menu_title.text = transit_system.line_name(chosen_bus) + "\nChoose your destination and travel style."
    _refresh_shuttle_fare_label()
    shuttle_menu.visible = true
    _set_mouse_capture(false)
    return true

func _decline_board_shuttle() -> void:
    if chosen_bus != null and transit_system != null:
        transit_system.set_menu_hold(chosen_bus, false)
    chosen_bus = null
    shuttle_menu.visible = false
    if not overview_on:
        _set_mouse_capture(true)

func _confirm_board_shuttle() -> void:
    if chosen_bus == null or transit_system == null or player == null:
        _decline_board_shuttle()
        return
    if wallet_balance < SHUTTLE_FARE:
        notice = "You need ₦150 for this ride. Your wallet has " + _format_naira(wallet_balance) + "."
        notice_timer = 4.0
        return
    if destination_option == null or destination_option.item_count == 0:
        notice = "No campus destinations are available yet."
        notice_timer = 4.0
        return
    var destination_name: String = destination_option.get_item_text(destination_option.get_selected())
    var target_raw: Vector2 = destination_positions.get(destination_name, Vector2.ZERO)
    var selected_bus: Node3D = chosen_bus
    if not transit_system.prepare_destination(selected_bus, target_raw, destination_name):
        notice = "A safe continuous road route could not be calculated from this stop. Please try another destination or shuttle."
        notice_timer = 5.0
        return
    var route_note: String = transit_system.destination_route_note(selected_bus)
    if not transit_system.board(selected_bus):
        transit_system.finish_quick_travel(selected_bus)
        _decline_board_shuttle()
        notice = "Shuttle unavailable. Your fare was not charged."
        notice_timer = 4.0
        return
    _decline_board_shuttle()
    _change_balance(-SHUTTLE_FARE, "Shuttle", "Travel to " + destination_name)
    _save_game()
    ride_bus = selected_bus
    player.visible = false
    player.set_physics_process(false)
    player.set_process_unhandled_input(false)
    overview_on = false
    overview_camera.current = false
    var ride_camera: Camera3D = transit_system.onboard_camera(ride_bus)
    if ride_camera != null:
        ride_camera.current = true
    _set_mouse_capture(false)
    notice = "Paid ₦150. Travelling to " + destination_name + ". You'll alight near the destination and walk to the entrance." + route_note
    notice_timer = 6.0
    _update_wallet_panel()

func _confirm_quick_travel() -> void:
    if chosen_bus == null or transit_system == null or player == null:
        _decline_board_shuttle()
        return
    if wallet_balance < SHUTTLE_FARE:
        notice = "You need ₦150 for this ride. Your wallet has " + _format_naira(wallet_balance) + "."
        notice_timer = 4.0
        return
    if destination_option == null or destination_option.item_count == 0:
        notice = "No campus destinations are available yet."
        notice_timer = 4.0
        return
    var destination_name: String = destination_option.get_item_text(destination_option.get_selected())
    var target_raw: Vector2 = destination_positions.get(destination_name, Vector2.ZERO)
    var selected_bus: Node3D = chosen_bus
    if not transit_system.prepare_destination(selected_bus, target_raw, destination_name):
        notice = "A safe continuous road route could not be calculated. Your fare has not been charged."
        notice_timer = 5.0
        return
    var stand_position: Vector3 = transit_system.destination_stand_position(destination_name, target_raw)
    var route_note: String = transit_system.destination_route_note(selected_bus)
    # Restore the shuttle to its current route without moving it; only the player skips
    # watching the trip. This prevents a hidden bus teleport or broken return path.
    transit_system.finish_quick_travel(selected_bus)
    _decline_board_shuttle()
    _change_balance(-SHUTTLE_FARE, "Shuttle", "Travel to " + destination_name)
    player.global_position = stand_position
    player.velocity = Vector3.ZERO
    var building_raw: Vector2 = destination_building_positions.get(destination_name, target_raw)
    player.look_at(Vector3(building_raw.x * WORLD_SCALE, player.global_position.y, building_raw.y * WORLD_SCALE), Vector3.UP)
    _save_game()
    _update_wallet_panel()
    notice = "Quick travel complete. Arrived at the " + destination_name + " bus stand. Walk to the entrance." + route_note
    notice_timer = 6.0

func _disembark_shuttle() -> void:
    if ride_bus == null or transit_system == null or player == null:
        return
    var arrived_at: String = transit_system.current_stop_name(ride_bus)
    var exit_point: Vector3 = transit_system.disembark(ride_bus)
    player.global_position = exit_point
    player.velocity = Vector3.ZERO
    if destination_building_positions.has(arrived_at):
        var building_raw: Vector2 = destination_building_positions[arrived_at]
        player.look_at(Vector3(building_raw.x * WORLD_SCALE, player.global_position.y, building_raw.y * WORLD_SCALE), Vector3.UP)
    player.visible = true
    player.set_physics_process(true)
    player.set_process_unhandled_input(true)
    var walk_camera := player.get("camera") as Camera3D
    if walk_camera != null:
        walk_camera.current = true
    ride_bus = null
    if not overview_on:
        _set_mouse_capture(true)
    notice = "Arrived at " + arrived_at + ". You're back on foot."
    notice_timer = 5.0

func _register_interactive_seats() -> void:
    # Register real bench-seat meshes from shelters, gardens and the sports pavilion.
    # The anchor is placed just in front of each seat so sitting does not put the
    # character inside the bench collision/geometry.
    var seat_meshes: Array = []
    _collect_seat_meshes(self, seat_meshes)
    var seat_index: int = 0
    for seat_variant in seat_meshes:
        var seat_mesh: MeshInstance3D = seat_variant as MeshInstance3D
        if seat_mesh == null or not is_instance_valid(seat_mesh):
            continue
        if bool(seat_mesh.get_meta("seat_registered", false)):
            continue
        seat_mesh.set_meta("seat_registered", true)
        var seat_name: String = str(seat_mesh.name)
        var local_forward: Vector3 = seat_mesh.global_transform.basis.z.normalized()
        var lowered_seat_name: String = seat_name.to_lower()
        if lowered_seat_name == "parkbench" or lowered_seat_name == "spectatorbench" or lowered_seat_name.contains("chairseat"):
            local_forward = -local_forward
        # Shelter benches have their backrest on -Z, so the approach is +Z.
        var surface_position: Vector3 = seat_mesh.global_position
        var seat_top: float = surface_position.y + 0.08
        if seat_mesh.mesh is BoxMesh:
            var box_mesh: BoxMesh = seat_mesh.mesh as BoxMesh
            seat_top = surface_position.y + box_mesh.size.y * 0.5
        var anchor := Node3D.new()
        anchor.name = "SeatAnchor_%03d" % seat_index
        anchor.add_to_group("campus_seats")
        anchor.set_meta("seat_name", seat_name)
        anchor.set_meta("seat_surface_position", surface_position)
        add_child(anchor)
        anchor.global_position = Vector3(surface_position.x + local_forward.x * 0.66, maxf(0.02, seat_top - 0.75), surface_position.z + local_forward.z * 0.66)
        seat_index += 1

func _collect_seat_meshes(root: Node, result: Array) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            var mesh_node: MeshInstance3D = child as MeshInstance3D
            var lowered_name: String = str(mesh_node.name).to_lower()
            if lowered_name.contains("benchseat") or lowered_name == "parkbench" or lowered_name == "spectatorbench" or lowered_name.contains("chairseat") or lowered_name.contains("seatsurface") or lowered_name.contains("stoolseat") or lowered_name.contains("sofaseat") or lowered_name.ends_with("seat") or mesh_node.is_in_group("sit_interactable"):
                result.append(mesh_node)
        _collect_seat_meshes(child, result)

func try_seat_interaction(walker: Node3D) -> bool:
    if walker == null or ride_bus != null or (shuttle_menu != null and shuttle_menu.visible):
        return false
    var nearest_seat: Node3D = null
    var best_distance: float = 3.5
    for seat_variant in get_tree().get_nodes_in_group("campus_seats"):
        var seat: Node3D = seat_variant as Node3D
        if seat == null:
            continue
        var distance: float = Vector2(seat.global_position.x - walker.global_position.x, seat.global_position.z - walker.global_position.z).length()
        if distance < best_distance:
            best_distance = distance
            nearest_seat = seat
    if nearest_seat == null:
        return false
    if walker.has_method("sit_on_seat"):
        walker.call("sit_on_seat", nearest_seat)
        notice = "You sit down to rest. Press E again to stand up."
        notice_timer = 4.0
        return true
    return false

func _create_player() -> void:
    player = CharacterBody3D.new()
    player.set_script(PLAYER_SCRIPT)
    # Spawn on the Main Gate road, just inside the entrance; not in the gate footprint.
    player.position = Vector3(-45.0 * WORLD_SCALE, 0.25, -59.0 * WORLD_SCALE)
    player.rotation_degrees.y = 180.0
    add_child(player)

func _create_overview_camera() -> void:
    overview_camera = Camera3D.new()
    overview_camera.name = "CampusOverviewCamera"
    overview_camera.position = Vector3(0, 180.0 * WORLD_SCALE, 0)
    overview_camera.rotation_degrees.x = -90
    overview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    overview_camera.size = 170.0 * WORLD_SCALE
    overview_camera.current = false
    add_child(overview_camera)

func _hud_meter(row_parent: VBoxContainer, text_value: String, tint: Color) -> ProgressBar:
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    row_parent.add_child(row)
    var name_label: Label = Label.new()
    name_label.text = text_value
    name_label.custom_minimum_size = Vector2(90, 18)
    name_label.add_theme_font_size_override("font_size", 12)
    name_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.90))
    row.add_child(name_label)
    var meter: ProgressBar = ProgressBar.new()
    meter.custom_minimum_size = Vector2(268, 15)
    meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    meter.min_value = 0.0
    meter.max_value = 100.0
    meter.show_percentage = true
    var empty_box: StyleBoxFlat = StyleBoxFlat.new()
    empty_box.bg_color = Color(0.14, 0.22, 0.27)
    empty_box.set_corner_radius_all(7)
    meter.add_theme_stylebox_override("background", empty_box)
    var fill_box: StyleBoxFlat = StyleBoxFlat.new()
    fill_box.bg_color = tint
    fill_box.set_corner_radius_all(7)
    meter.add_theme_stylebox_override("fill", fill_box)
    meter.add_theme_font_size_override("font_size", 11)
    meter.add_theme_color_override("font_color", Color.WHITE)
    row.add_child(meter)
    return meter

func _create_hud() -> void:
    student_ui = STUDENT_UI.instantiate()
    add_child(student_ui)
    student_ui.modal_changed.connect(_on_student_modal)
    student_ui.reward_requested.connect(_claim_daily_reward)
    student_ui.ad_preview_requested.connect(_preview_advertisement)
    hud_label = student_ui.prompt
    hud_time_chip = student_ui.clock
    hud_energy_meter = student_ui.energy
    hud_stamina_meter = student_ui.stamina
    hud_stress_meter = student_ui.stress

func _create_wallet_panel() -> void:
    daily_reward_button = student_ui.reward
    wallet_balance_label = student_ui.balance
    wallet_summary_label = student_ui.wallet_summary

func _on_student_modal(open: bool) -> void:
    if open and (profile_layer != null or (task_panel != null and task_panel.visible) or (shuttle_menu != null and shuttle_menu.visible)):
        student_ui.close()
        return
    if open:
        _update_wallet_panel()
    if player == null or profile_data.is_empty():
        return
    var can_walk: bool = not open and ride_bus == null and (task_panel == null or not task_panel.visible) and (shuttle_menu == null or not shuttle_menu.visible)
    player.set_physics_process(can_walk)
    player.set_process_unhandled_input(can_walk)
    if open:
        player.velocity = Vector3.ZERO
    _set_mouse_capture(not open)
    if not open:
        _save_game()

func _initialise_student_profile() -> void:
    var save_data: Dictionary = SAVE_STORE.load_profile()
    save_extras = save_data.duplicate(true)
    transactions = save_data.get("transactions", []).duplicate(true)
    if not save_data.is_empty():
        var raw_profile: Variant = save_data.get("profile", {})
        if typeof(raw_profile) == TYPE_DICTIONARY:
            profile_data = raw_profile
        wallet_balance = int(save_data.get("wallet_balance", 0))
        last_daily_reward_date = str(save_data.get("last_daily_reward_date", ""))
        last_daily_reward_amount = int(save_data.get("last_daily_reward_amount", 0))
        total_earned = int(save_data.get("total_earned", 0))
        total_spent = int(save_data.get("total_spent", 0))
        var raw_visits: Variant = save_data.get("location_visits", {})
        if typeof(raw_visits) == TYPE_DICTIONARY:
            location_visits = raw_visits
        last_curfew_notice_key = str(save_data.get("last_curfew_notice_key", ""))
        task_completion_counts = save_data.get("task_completion_counts", {})
        task_daily_completions = save_data.get("task_daily_completions", {})
        task_inventory = save_data.get("task_inventory", [])
        room_furniture = save_data.get("room_furniture", [])
        room_visitors_allowed = bool(save_data.get("room_visitors_allowed", false))
        last_room_rest_unix = int(save_data.get("last_room_rest_unix", 0))
        social_reputation = int(save_data.get("social_reputation", 0))
        energy = clampf(float(save_data.get("energy", 92.0)), 0.0, 100.0)
        stamina = clampf(float(save_data.get("stamina", 90.0)), 0.0, 100.0)
        stress = clampf(float(save_data.get("stress", 8.0)), 0.0, 100.0)
        var saved_skills: Variant = save_data.get("skills", {})
        if typeof(saved_skills) == TYPE_DICTIONARY:
            skills = saved_skills
        var saved_xp: Variant = save_data.get("skill_xp", {})
        if typeof(saved_xp) == TYPE_DICTIONARY:
            skill_xp = saved_xp
        var saved_claims: Variant = save_data.get("skill_daily_xp", {})
        if typeof(saved_claims) == TYPE_DICTIONARY:
            skill_daily_xp = saved_claims
    if not profile_data.is_empty() and skills.is_empty():
        _roll_initial_skills()
        _save_game()
    if profile_data.is_empty():
        if player != null:
            player.set_physics_process(false)
            player.set_process_unhandled_input(false)
        _set_mouse_capture(false)
        _create_profile_ui()
    else:
        if player != null:
            player.set_physics_process(true)
            player.set_process_unhandled_input(true)
        if player.has_method("apply_profile_appearance"):
            player.call("apply_profile_appearance", str(profile_data.get("gender", "Prefer not to say")), str(profile_data.get("student_name", "Student")))
        _set_mouse_capture(not OS.has_feature("web"))
        if wallet_panel != null:
            wallet_panel.visible = true
        _update_wallet_panel()
        _update_hud()

func _create_profile_ui() -> void:
    profile_layer = CanvasLayer.new()
    profile_layer.name = "NewStudentProfileOverlay"
    profile_layer.layer = 20
    add_child(profile_layer)
    var backdrop: ColorRect = ColorRect.new()
    backdrop.color = Color(0.015, 0.035, 0.055, 0.82)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    profile_layer.add_child(backdrop)
    var panel: PanelContainer = PanelContainer.new()
    panel.name = "CreateStudentPanel"
    panel.custom_minimum_size = Vector2(0, 0)
    var layout_profile: Callable = func():
        var viewport: Vector2 = get_viewport().get_visible_rect().size
        panel.size = Vector2(minf(740, viewport.x - 24), minf(620, viewport.y - 24))
        panel.position = (viewport - panel.size) * 0.5
    get_viewport().size_changed.connect(layout_profile)
    panel.tree_exiting.connect(func():
        if get_viewport().size_changed.is_connected(layout_profile):
            get_viewport().size_changed.disconnect(layout_profile))
    layout_profile.call()
    var panel_style: StyleBoxFlat = StyleBoxFlat.new()
    panel_style.bg_color = Color(0.94, 0.96, 0.97, 0.99)
    panel_style.corner_radius_top_left = 16
    panel_style.corner_radius_top_right = 16
    panel_style.corner_radius_bottom_left = 16
    panel_style.corner_radius_bottom_right = 16
    panel_style.content_margin_left = 22
    panel_style.content_margin_right = 22
    panel_style.content_margin_top = 20
    panel_style.content_margin_bottom = 18
    panel.add_theme_stylebox_override("panel", panel_style)
    profile_layer.add_child(panel)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    var profile_scroll := ScrollContainer.new()
    profile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(profile_scroll)
    profile_scroll.add_child(column)
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title: Label = Label.new()
    title.text = "WELCOME TO INSIDE LASU"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.add_theme_color_override("font_color", Color(0.06, 0.19, 0.29))
    title.add_theme_font_size_override("font_size", 18 if MOBILE_CONTROLS.touch_device() else 25)
    column.add_child(title)
    var subtitle: Label = Label.new()
    subtitle.text = "Create your student profile. Your level, CGPA, background and starting money will be assigned randomly."
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color(0.20, 0.28, 0.34))
    subtitle.add_theme_font_size_override("font_size", 13)
    column.add_child(subtitle)

    profile_name_input = LineEdit.new()
    profile_name_input.max_length = 40
    if not MOBILE_CONTROLS.touch_device():
        profile_name_input.call_deferred("grab_focus")
    profile_name_input.placeholder_text = "Enter your student's name"
    profile_name_input.custom_minimum_size = Vector2(440, 36)
    _add_profile_row(column, "Student name", profile_name_input)

    profile_gender_option = OptionButton.new()
    profile_gender_option.add_item("Female")
    profile_gender_option.add_item("Male")
    profile_gender_option.add_item("Prefer not to say")
    profile_gender_option.select(0)
    profile_gender_option.item_selected.connect(_on_profile_gender_changed)
    _add_profile_row(column, "Character gender", profile_gender_option)

    profile_faculty_option = OptionButton.new()
    for faculty_name in FACULTY_DEPARTMENTS.keys():
        profile_faculty_option.add_item(str(faculty_name))
    profile_faculty_option.select(0)
    profile_faculty_option.item_selected.connect(_on_profile_faculty_changed)
    _add_profile_row(column, "Faculty / school", profile_faculty_option)

    profile_department_option = OptionButton.new()
    _add_profile_row(column, "Department", profile_department_option)
    _populate_profile_departments(profile_faculty_option.get_item_text(profile_faculty_option.get_selected()))

    profile_study_mode_option = OptionButton.new()
    profile_study_mode_option.add_item("Full-time")
    profile_study_mode_option.add_item("Part-time")
    profile_study_mode_option.select(0)
    _add_profile_row(column, "Study mode", profile_study_mode_option)

    profile_hostel_option = OptionButton.new()
    _add_profile_row(column, "Preferred hostel", profile_hostel_option)
    _refresh_profile_hostels()

    var rent_note: Label = Label.new()
    rent_note.text = "HOSTEL: ₦525,000 per full academic session. Your first session is prepaid; future renewals are your responsibility."
    rent_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rent_note.add_theme_color_override("font_color", Color(0.06, 0.40, 0.25))
    rent_note.add_theme_font_size_override("font_size", 13)
    column.add_child(rent_note)

    profile_error_label = Label.new()
    profile_error_label.text = ""
    profile_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    profile_error_label.add_theme_color_override("font_color", Color(0.72, 0.12, 0.12))
    column.add_child(profile_error_label)

    var create_button: Button = Button.new()
    create_button.text = "GENERATE MY STUDENT LIFE"
    create_button.custom_minimum_size = Vector2(0, 48)
    create_button.add_theme_font_size_override("font_size", 16)
    create_button.pressed.connect(_create_student_profile)
    column.add_child(create_button)
    var footer: Label = Label.new()
    footer.text = "In-game currency only • Your first hostel rent is prepaid • Daily rewards use your real system date"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    footer.add_theme_color_override("font_color", Color(0.30, 0.36, 0.40))
    footer.add_theme_font_size_override("font_size", 11)
    column.add_child(footer)

func _add_profile_row(parent: VBoxContainer, label_text: String, control: Control) -> void:
    var row: BoxContainer = VBoxContainer.new() if MOBILE_CONTROLS.touch_device() else HBoxContainer.new()
    row.add_theme_constant_override("separation", 6 if MOBILE_CONTROLS.touch_device() else 12)
    var label: Label = Label.new()
    label.text = label_text
    label.custom_minimum_size = Vector2(0 if MOBILE_CONTROLS.touch_device() else 170, 26)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", Color(0.09, 0.17, 0.22))
    label.add_theme_font_size_override("font_size", 14)
    row.add_child(label)
    control.custom_minimum_size = Vector2(0, maxf(control.custom_minimum_size.y, 44.0 if MOBILE_CONTROLS.touch_device() else 36.0))
    if control is OptionButton:
        control.fit_to_longest_item = false
        control.clip_text = true
    control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(control)
    parent.add_child(row)

func _on_profile_faculty_changed(index: int) -> void:
    if profile_faculty_option == null:
        return
    _populate_profile_departments(profile_faculty_option.get_item_text(index))

func _on_profile_gender_changed(_index: int) -> void:
    _refresh_profile_hostels()

func _populate_profile_departments(faculty_name: String) -> void:
    if profile_department_option == null:
        return
    profile_department_option.clear()
    var departments: Array = FACULTY_DEPARTMENTS.get(faculty_name, ["General Studies"])
    for department_name in departments:
        profile_department_option.add_item(str(department_name))
    if profile_department_option.item_count > 0:
        profile_department_option.select(0)

func _eligible_hostel_names(gender: String) -> Array[String]:
    var eligible: Array[String] = []
    for raw_item in campus_data.get("features", []):
        var item: Dictionary = raw_item
        var name: String = str(item.get("name", ""))
        var kind: String = str(item.get("kind", ""))
        var lowered: String = name.to_lower()
        if kind != "residential" or not lowered.contains("hostel"):
            continue
        if lowered.contains("incomplete") or lowered.contains("almost complete"):
            continue
        if lowered.contains("girls-only") and gender != "Female":
            continue
        eligible.append(name)
    return eligible

func _refresh_profile_hostels() -> void:
    if profile_hostel_option == null or profile_gender_option == null:
        return
    profile_hostel_option.clear()
    profile_hostel_option.add_item("Auto-assign an eligible hostel (recommended)")
    var gender: String = profile_gender_option.get_item_text(profile_gender_option.get_selected())
    var hostels: Array[String] = _eligible_hostel_names(gender)
    for hostel_name in hostels:
        profile_hostel_option.add_item(hostel_name)
    profile_hostel_option.select(0)

func _create_student_profile() -> void:
    if profile_name_input == null or profile_faculty_option == null or profile_department_option == null:
        return
    var student_name: String = profile_name_input.text.strip_edges()
    if student_name.is_empty():
        profile_error_label.text = "Please enter a student name before continuing."
        return
    var gender: String = profile_gender_option.get_item_text(profile_gender_option.get_selected())
    var faculty_name: String = profile_faculty_option.get_item_text(profile_faculty_option.get_selected())
    var department_name: String = profile_department_option.get_item_text(profile_department_option.get_selected())
    var study_mode: String = profile_study_mode_option.get_item_text(profile_study_mode_option.get_selected())
    var level_options: Array[int] = [100, 200, 300, 400]
    if study_mode == "Part-time":
        level_options.append(500)
    var assigned_level: int = level_options[rng.randi_range(0, level_options.size() - 1)]
    var cgpa_value: Variant = null
    if assigned_level > 100:
        cgpa_value = _roll_starting_cgpa()
    var background_data: Dictionary = _roll_student_background()
    var eligible_hostels: Array[String] = _eligible_hostel_names(gender)
    if eligible_hostels.is_empty():
        profile_error_label.text = "No eligible completed hostels were found in the map data. Please report this issue."
        return
    var hostel_choice: String = profile_hostel_option.get_item_text(profile_hostel_option.get_selected())
    var hostel_name: String = ""
    if profile_hostel_option.get_selected() == 0 or not eligible_hostels.has(hostel_choice):
        hostel_name = eligible_hostels[rng.randi_range(0, eligible_hostels.size() - 1)]
    else:
        hostel_name = hostel_choice
    var room_number: int = rng.randi_range(1, 48)
    profile_data = {
        "student_name": student_name,
        "gender": gender,
        "faculty": faculty_name,
        "department": department_name,
        "study_mode": study_mode,
        "level": assigned_level,
        "cgpa": cgpa_value,
        "background": str(background_data.get("name", "Independent Hustler")),
        "starting_balance": int(background_data.get("balance", 50000)),
        "hostel_name": hostel_name,
        "room_number": room_number,
        "hostel_rent_amount": HOSTEL_RENT_AMOUNT,
        "first_session_rent_paid": true,
        "first_session_rent_payer": "Prepaid family / sponsor arrangement",
        "academic_session_number": 1,
        "hostel_renewal_due": false,
        "hostel_checked_in": false,
        "created_date": Time.get_date_string_from_system()
    }
    room_furniture.clear()
    room_visitors_allowed = false
    last_room_rest_unix = 0
    transactions.clear()
    save_extras.clear()
    wallet_balance = int(background_data.get("balance", 50000))
    last_daily_reward_date = ""
    last_daily_reward_amount = 0
    total_earned = 0
    total_spent = 0
    location_visits.clear()
    task_completion_counts.clear()
    task_daily_completions.clear()
    task_inventory.clear()
    social_reputation = 0
    _roll_initial_skills()
    if player != null and player.has_method("apply_profile_appearance"):
        player.call("apply_profile_appearance", gender, student_name)
    _save_game()
    if profile_layer != null:
        profile_layer.queue_free()
        profile_layer = null
    if player != null:
        player.set_physics_process(true)
        player.set_process_unhandled_input(true)
    if wallet_panel != null:
        wallet_panel.visible = true
    _set_mouse_capture(true)
    var cgpa_text: String = "Not yet assigned (100 Level starts from scratch)" if assigned_level == 100 else str(cgpa_value)
    notice = "Welcome, " + student_name + "! " + str(profile_data["background"]) + " background • Level " + str(assigned_level) + " • CGPA: " + cgpa_text + " • First-session rent prepaid. First objective: check in at " + hostel_name + "."
    notice_timer = 10.0
    _update_wallet_panel()
    _update_hud()

func _roll_student_background() -> Dictionary:
    var roll: float = rng.randf()
    if roll < 0.05:
        var rich_tier: float = rng.randf()
        var rich_balance: int = 0
        if rich_tier < 0.55:
            rich_balance = rng.randi_range(500000, 1500000)
        elif rich_tier < 0.82:
            rich_balance = rng.randi_range(1500000, 3000000)
        elif rich_tier < 0.96:
            rich_balance = rng.randi_range(3000000, 5000000)
        else:
            rich_balance = rng.randi_range(5000000, 10000000)
        return {"name": "Wealthy Family", "balance": rich_balance}
    if roll < 0.55:
        var supported_tier: float = rng.randf()
        var supported_balance: int = 0
        if supported_tier < 0.70:
            supported_balance = rng.randi_range(200000, 600000)
        elif supported_tier < 0.94:
            supported_balance = rng.randi_range(600000, 1200000)
        else:
            supported_balance = rng.randi_range(1200000, 2000000)
        return {"name": "Supported Student", "balance": supported_balance}
    if roll < 0.85:
        return {"name": "Independent Hustler", "balance": rng.randi_range(50000, 250000)}
    return {"name": "Scholarship Student", "balance": rng.randi_range(50000, 300000)}

func _roll_starting_cgpa() -> float:
    var roll: float = rng.randf()
    var value: float = 0.0
    if roll < 0.35:
        value = rng.randf_range(2.00, 2.99)
    elif roll < 0.80:
        value = rng.randf_range(3.00, 3.99)
    else:
        value = rng.randf_range(4.00, 4.89)
    return roundf(value * 100.0) / 100.0

func _roll_daily_reward() -> int:
    return rng.randi_range(500, 1500)

func _claim_daily_reward() -> void:
    if profile_data.is_empty():
        return
    var today: String = Time.get_date_string_from_system()
    if last_daily_reward_date == today:
        notice = "You've already claimed today's reward. Come back after the next real-world date."
        notice_timer = 4.0
        _update_wallet_panel()
        return
    last_daily_reward_amount = _roll_daily_reward()
    _change_balance(last_daily_reward_amount, "Daily support", "Daily campus living allowance")
    last_daily_reward_date = today
    _save_game()
    notice = "DAILY REWARD: You received " + _format_naira(last_daily_reward_amount) + "!"
    notice_timer = 7.0
    _update_wallet_panel()
    _update_hud()

func _format_naira(amount: int) -> String:
    var digits: String = str(maxi(0, amount))
    var formatted: String = ""
    var group_count: int = 0
    for index in range(digits.length() - 1, -1, -1):
        formatted = digits.substr(index, 1) + formatted
        group_count += 1
        if group_count % 3 == 0 and index > 0:
            formatted = "," + formatted
    return "₦" + formatted

func _update_wallet_panel() -> void:
    if student_ui == null:
        return
    student_ui.update_student(profile_data, skills, wallet_balance, transactions, last_daily_reward_amount,
        last_daily_reward_date == Time.get_date_string_from_system(), _format_naira)

func _change_balance(amount: int, source: String, description: String) -> void:
    wallet_balance += amount
    total_earned += maxi(0, amount)
    total_spent += maxi(0, -amount)
    transactions.append({"amount": amount, "source": source, "description": description,
        "date": Time.get_date_string_from_system(), "time": Time.get_datetime_string_from_system(false, true)})
    if transactions.size() > 500:
        transactions.pop_front()

func _save_game() -> void:
    if profile_data.is_empty():
        return
    var save_data: Dictionary = {
        "save_version": SAVE_STORE.VERSION,
        "transactions": transactions,
        "profile": profile_data,
        "wallet_balance": wallet_balance,
        "last_daily_reward_date": last_daily_reward_date,
        "last_daily_reward_amount": last_daily_reward_amount,
        "total_earned": total_earned,
        "total_spent": total_spent,
        "location_visits": location_visits,
        "last_curfew_notice_key": last_curfew_notice_key,
        "task_completion_counts": task_completion_counts,
        "task_daily_completions": task_daily_completions,
        "task_inventory": task_inventory,
        "room_furniture": room_furniture,
        "room_visitors_allowed": room_visitors_allowed,
        "last_room_rest_unix": last_room_rest_unix,
        "energy": energy,
        "stamina": stamina,
        "stress": stress,
        "skills": skills,
        "skill_xp": skill_xp,
        "skill_daily_xp": skill_daily_xp,
        "campus_phone": campus_phone.state if campus_phone != null else save_extras.get("campus_phone", {}),
        "social_reputation": social_reputation
    }
    var merged: Dictionary = save_extras.duplicate(true)
    merged.merge(save_data, true)
    var result: Error = SAVE_STORE.save_profile(merged)
    if result != OK:
        notice = "Your browser could not save progress. Keep this page open and allow site storage."
        notice_timer = 10.0
        push_warning("Could not save Inside LASU profile to user data: " + error_string(result))

func _check_hostel_curfew() -> void:
    if profile_data.is_empty():
        return
    var clock: Dictionary = Time.get_time_dict_from_system()
    var hour: int = int(clock.get("hour", 12))
    var minute: int = int(clock.get("minute", 0))
    var today: String = Time.get_date_string_from_system()
    var stage: String = ""
    if hour >= 23 or hour < 6:
        stage = "closed"
    elif hour == 22 and minute >= 50:
        stage = "final"
    elif hour == 22 and minute >= 30:
        stage = "warning"
    if stage.is_empty():
        return
    var key: String = today + "_" + stage
    if key == last_curfew_notice_key:
        return
    last_curfew_notice_key = key
    if stage == "warning":
        notice = "Hostel curfew reminder: doors close at 11:00 PM. Start heading to " + str(profile_data.get("hostel_name", "your hostel")) + "."
    elif stage == "final":
        notice = "Final hostel reminder: 10 minutes until the 11:00 PM curfew. Faculties remain available for permitted night classes."
    else:
        notice = "Hostel curfew is active. Faculty buildings and permitted night-study spaces remain available; resting in active rooms may be interrupted."
    notice_timer = 8.0
    _save_game()

func _unhandled_input(event: InputEvent) -> void:
    if campus_phone != null and campus_phone.panel.visible:
        if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
            campus_phone.close()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T and campus_phone != null:
        campus_phone.open()
        get_viewport().set_input_as_handled()
        return
    if not MOBILE_CONTROLS.touch_device() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if _try_billboard_at(event.position):
            get_viewport().set_input_as_handled()
            return
    if student_ui != null and profile_layer == null and event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE and student_ui.modal.visible:
            student_ui.close()
            get_viewport().set_input_as_handled()
            return
        if (task_panel == null or not task_panel.visible) and (shuttle_menu == null or not shuttle_menu.visible):
            var key: String = {KEY_P: "profile", KEY_B: "wallet", KEY_H: "help"}.get(event.keycode, "")
            if not key.is_empty():
                student_ui.toggle(key)
                _update_wallet_panel()
                get_viewport().set_input_as_handled()
                return
    if student_ui != null and student_ui.modal.visible:
        return
    if task_panel != null and task_panel.visible:
        if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
            _close_task_panel()
            get_viewport().set_input_as_handled()
        return
    if not active_interior_site.is_empty() and event.is_action_pressed("interact"):
        if not active_private_room and active_interior_site == str(profile_data.get("hostel_name", "")) and player != null:
            var resident_door: Vector3 = Vector3(900.0, 0.5, -11.55)
            if player.global_position.distance_to(resident_door) <= 3.8:
                _enter_private_room()
                get_viewport().set_input_as_handled()
                return
        if not try_campus_interaction(player):
            _open_task_panel(active_interior_site)
        get_viewport().set_input_as_handled()
        return
    if ride_bus != null and event.is_action_pressed("interact"):
        if transit_system != null and transit_system.has_arrived(ride_bus):
            _disembark_shuttle()
        else:
            notice = "Stay seated until the shuttle reaches its stop."
            notice_timer = 3.0
        return
    if shuttle_menu != null and shuttle_menu.visible:
        if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
            _decline_board_shuttle()
        return
    if ride_bus != null:
        if event is InputEventKey and event.pressed and event.keycode == KEY_V:
            transit_system.toggle_passenger_view(ride_bus)
        elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            transit_system.look_passenger(ride_bus, event.relative)
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
        overview_on = not overview_on
        overview_camera.current = overview_on
        if not overview_on and player != null:
            var walk_camera := player.get("camera") as Camera3D
            if walk_camera != null:
                walk_camera.current = true
        _set_mouse_capture(not overview_on)

func _process(delta: float) -> void:
    _sync_mobile_controls()
    autosave_timer += delta
    if autosave_timer >= 30.0:
        autosave_timer = 0.0
        _save_game()
    if notice_timer > 0.0:
        notice_timer -= delta
        if notice_timer <= 0.0:
            notice = ""
    var clock_stamp: String = Time.get_date_string_from_system() + " " + Time.get_time_string_from_system().substr(0, 5)
    if clock_stamp != last_clock_stamp:
        last_clock_stamp = clock_stamp
        _check_hostel_curfew()
        _update_wallet_panel()
    if player != null and not profile_data.is_empty() and ride_bus == null and (task_panel == null or not task_panel.visible):
        var walk_rate: float = Vector2(player.velocity.x, player.velocity.z).length()
        if walk_rate > 0.5 and not bool(player.get("is_sitting")):
            var sprinting: bool = Input.is_key_pressed(KEY_SHIFT) or bool(player.get("touch_running"))
            energy = maxf(0.0, energy - delta * (0.095 if sprinting else 0.022))
            stamina = maxf(0.0, stamina - delta * (0.32 if sprinting else 0.055))
            stress = minf(100.0, stress + delta * 0.007)
        else:
            stamina = minf(100.0, stamina + delta * 0.16)
    ui_timer += delta
    if ui_timer >= 0.2:
        ui_timer = 0.0
        _update_hud()

func _update_hud() -> void:
    if student_ui == null:
        return
    hud_energy_meter.value = energy
    hud_stamina_meter.value = stamina
    hud_stress_meter.value = stress
    hud_time_chip.text = Time.get_time_string_from_system().substr(0, 5)
    var location_name: String = "Main Gate / Campus"
    if not active_interior_site.is_empty():
        location_name = active_interior_site + (" · My room" if active_private_room else " · Floor " + str(active_interior_floor + 1))
    elif player != null:
        var nearby: Node3D = player.get("nearby_feature") as Node3D
        if nearby != null:
            location_name = str(nearby.get_meta("campus_name", "Campus"))
    if active_campus_room >= 0:
        location_name += " · " + str(CAMPUS_ROOMS.for_site(active_interior_site, building_experiences)[active_campus_room][0])
    student_ui.location.text = location_name
    if not active_interior_site.is_empty():
        student_ui.places_button.text = "Rooms, tasks & exit  ›"
    elif player != null and player.nearby_feature != null:
        student_ui.places_button.text = "Enter / activities  ›"
    else:
        student_ui.places_button.text = "Places & tasks  ›"
    student_ui.objective.text = "Create your student profile to begin." if profile_data.is_empty() else ("Check in at " + str(profile_data.get("hostel_name", "your hostel")) if not profile_data.get("hostel_checked_in", false) else "Explore campus · study, work and build your skills")
    var message: String = "Left stick: move · Swipe right: look · Tap Interact near a building" if MOBILE_CONTROLS.touch_device() else "E interact · F sit · M map · B wallet · P profile · H help"
    if not active_interior_site.is_empty():
        message = "Interact: activities, rooms, floors and exit" if MOBILE_CONTROLS.touch_device() else "E — Activities, room access, floors and exit"
    if ride_bus != null and transit_system != null:
        message = "Arrived — tap Alight / press E to leave" if transit_system.has_arrived(ride_bus) else "Onboard: " + transit_system.next_stop_name(ride_bus)
    if not notice.is_empty():
        message += "\n" + notice
    hud_label.text = message
    student_ui.toast.text = notice if not student_ui.hud_expanded else ""

func _nearest_seat_for_hud(position_value: Vector3, radius: float) -> Node3D:
    var nearest: Node3D = null
    var best_distance: float = radius
    for seat_variant in get_tree().get_nodes_in_group("campus_seats"):
        var seat: Node3D = seat_variant as Node3D
        if seat == null:
            continue
        var distance: float = Vector2(seat.global_position.x - position_value.x, seat.global_position.z - position_value.z).length()
        if distance < best_distance:
            best_distance = distance
            nearest = seat
    return nearest

func show_interaction(location_name: String) -> void:
    var is_new: bool = not location_visits.has(location_name)
    location_visits[location_name] = true
    if not profile_data.is_empty() and location_name == str(profile_data.get("hostel_name", "")) and not bool(profile_data.get("hostel_checked_in", false)):
        profile_data["hostel_checked_in"] = true
        notice = "Hostel check-in complete! " + location_name + ", Room " + str(profile_data.get("room_number", "?")) + ". Your first-session rent is prepaid."
    elif is_new:
        notice = "Checked in: " + location_name + " | Unique sites visited: " + str(location_visits.size())
    else:
        notice = "Welcome back to " + location_name + " | Unique sites visited: " + str(location_visits.size())
    notice_timer = 5.0
    _save_game()
    _update_wallet_panel()
    _open_task_panel(location_name)

func _load_task_catalog() -> void:
    var source: FileAccess = FileAccess.open(TASK_CATALOG_PATH, FileAccess.READ)
    if source == null:
        push_error("Missing task catalogue: " + TASK_CATALOG_PATH)
        return
    var parsed: Variant = JSON.parse_string(source.get_as_text())
    source.close()
    if typeof(parsed) == TYPE_DICTIONARY:
        task_catalog = parsed.get("locations", {})
        building_experiences = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_experiences.json")).get("locations", {})
        for site in building_experiences:
            var original: Array = task_catalog.get(site, [])
            task_catalog[site] = building_experiences[site].get("tasks", []).duplicate(true) + original
    else:
        push_error("Invalid task catalogue JSON.")

func _layout_action_menus() -> void:
    var viewport: Vector2 = get_viewport().get_visible_rect().size
    for panel in [task_panel, shuttle_menu]:
        if panel != null:
            panel.size = Vector2(minf(660, viewport.x - 24), minf(560 if panel == task_panel else 420, viewport.y - 24))
            panel.position = (viewport - panel.size) * 0.5

func _create_task_panel() -> void:
    task_panel_layer = CanvasLayer.new()
    task_panel_layer.name = "CampusActivitiesUI"
    task_panel_layer.layer = 12
    add_child(task_panel_layer)
    task_panel = PanelContainer.new()
    task_panel.name = "ActivityPanel"
    task_panel.visible = false
    task_panel.custom_minimum_size = Vector2.ZERO
    task_panel.position = Vector2(310, 80)
    get_viewport().size_changed.connect(_layout_action_menus)
    call_deferred("_layout_action_menus")
    var background: StyleBoxFlat = StyleBoxFlat.new()
    background.bg_color = Color(0.06, 0.14, 0.20, 0.98)
    background.corner_radius_top_left = 15
    background.corner_radius_top_right = 15
    background.corner_radius_bottom_left = 15
    background.corner_radius_bottom_right = 15
    background.content_margin_left = 18
    background.content_margin_right = 18
    background.content_margin_top = 16
    background.content_margin_bottom = 16
    task_panel.add_theme_stylebox_override("panel", background)
    task_panel_layer.add_child(task_panel)
    var column: VBoxContainer = VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    task_panel.add_child(column)
    task_title_label = Label.new()
    task_title_label.add_theme_font_size_override("font_size", 20)
    task_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    task_title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 0.97))
    column.add_child(task_title_label)
    var help: Label = Label.new()
    help.text = "Services, errands and activities are location-specific. Prices are illustrative in-game prices."
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.add_theme_color_override("font_color", Color(0.67, 0.85, 0.85))
    column.add_child(help)
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 80)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)
    task_buttons_container = VBoxContainer.new()
    task_buttons_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    task_buttons_container.add_theme_constant_override("separation", 7)
    scroll.add_child(task_buttons_container)
    task_status_label = Label.new()
    task_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    task_status_label.custom_minimum_size = Vector2(0, 48)
    task_status_label.add_theme_color_override("font_color", Color(0.98, 0.83, 0.55))
    column.add_child(task_status_label)
    var close_button: Button = Button.new()
    close_button.text = "BACK TO CAMPUS"
    close_button.custom_minimum_size = Vector2(180, 40)
    close_button.pressed.connect(_close_task_panel)
    column.add_child(close_button)

func _open_task_panel(site_name: String) -> void:
    if task_panel == null or profile_data.is_empty() or ride_bus != null:
        return
    var entries: Array = task_catalog.get(site_name, []).duplicate(true)
    if active_interior_site == site_name and active_campus_room >= 0:
        var room_definition: Array = CAMPUS_ROOMS.for_site(site_name, building_experiences)[active_campus_room]
        entries.push_front(CAMPUS_ROOMS.activity(site_name, room_definition, active_campus_room, active_interior_floor))
    if entries.is_empty() and not interior_catalog.has(site_name):
        notice = "No activities are configured at this site yet."
        notice_timer = 4.0
        return
    for child in task_buttons_container.get_children():
        task_buttons_container.remove_child(child)
        child.queue_free()
    task_title_label.text = site_name.to_upper()
    if interior_catalog.has(site_name):
        if active_interior_site == site_name:
            if site_name == str(profile_data.get("hostel_name", "")):
                if active_private_room:
                    _populate_private_room_menu()
                    _fit_activity_navigation()
                    _layout_action_menus()
                    task_panel.visible = true
                    if player != null:
                        player.velocity = Vector3.ZERO
                        player.set_physics_process(false)
                        player.set_process_unhandled_input(false)
                    _set_mouse_capture(false)
                    return
                var private_button := Button.new()
                private_button.text = "UNLOCK MY ROOM " + str(profile_data.get("room_number", "?")) + "  •  Private personal space"
                private_button.custom_minimum_size = Vector2(0, 48)
                private_button.pressed.connect(_enter_private_room)
                task_buttons_container.add_child(private_button)
            var floor_list: Array = interior_catalog[site_name]
            for floor_idx in range(floor_list.size()):
                var floor_button := Button.new()
                floor_button.text = ("● " if floor_idx == active_interior_floor else "↗ ") + str(floor_list[floor_idx])
                floor_button.pressed.connect(_go_to_interior_floor.bind(floor_idx))
                task_buttons_container.add_child(floor_button)
            if not active_private_room:
                var room_list: Array = CAMPUS_ROOMS.for_site(site_name, building_experiences)
                for room_index in range(room_list.size()):
                    var room_button := Button.new()
                    room_button.text = "ENTER ROOM · " + str(room_list[room_index][0])
                    room_button.pressed.connect(_enter_campus_room.bind(room_index))
                    task_buttons_container.add_child(room_button)
                if active_campus_room >= 0:
                    var lobby_button := Button.new()
                    lobby_button.text = "RETURN TO FLOOR LOBBY"
                    lobby_button.pressed.connect(_go_to_interior_floor.bind(active_interior_floor))
                    task_buttons_container.add_child(lobby_button)
            var exit_button := Button.new()
            exit_button.text = "EXIT BUILDING — BACK TO CAMPUS"
            exit_button.pressed.connect(_leave_interior)
            task_buttons_container.add_child(exit_button)
        else:
            var enter_button := Button.new()
            enter_button.text = "ENTER BUILDING  •  Rooms, activities and services"
            enter_button.pressed.connect(_enter_interior.bind(site_name))
            task_buttons_container.add_child(enter_button)
    task_status_label.text = "Choose an activity. Press BACK TO CAMPUS to return."
    if site_name == "Arcade":
        task_status_label.text = ("GRID POWER ON — normal game prices." if _arcade_grid_is_available() else "GENERATOR ON — higher gaming prices.")
    for task_variant in entries:
        var entry: Dictionary = task_variant
        if interior_catalog.has(site_name):
            if active_interior_site != site_name:
                # You can ask directions from outside; business services and
                # studio tasks require actually entering the pilot interior.
                if str(entry.get("kind", "")) not in ["information", "radio_invite"] and not (site_name == "Sports Centre" and str(entry.get("kind", "")) == "sports"):
                    continue
            elif _task_floor_for_site(site_name, entry) != active_interior_floor:
                continue
        var action: Button = Button.new()
        action.custom_minimum_size = Vector2(0, 72)
        action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var caption: String = str(entry.get("title", "Activity"))
        var cost: int = _activity_price(entry)
        var reward: int = int(entry.get("reward", 0))
        if cost > 0:
            caption += "   −" + _format_naira(cost)
        elif reward > 0:
            caption += "   +" + _format_naira(reward)
        var task_label := Label.new()
        task_label.text = caption + "\n" + str(entry.get("description", ""))
        task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        task_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        task_label.add_theme_font_size_override("font_size", 13)
        task_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        task_label.offset_left = 12
        task_label.offset_right = -12
        task_label.offset_top = 8
        task_label.offset_bottom = -8
        action.add_child(task_label)
        task_label.resized.connect(func(): action.custom_minimum_size.y = maxf(72, task_label.get_minimum_size().y + 16))
        var task_box: StyleBoxFlat = StyleBoxFlat.new()
        task_box.bg_color = Color(0.105, 0.25, 0.31)
        task_box.border_color = Color(0.22, 0.53, 0.53)
        task_box.set_border_width_all(1)
        task_box.set_corner_radius_all(8)
        task_box.content_margin_left = 12
        task_box.content_margin_top = 8
        task_box.content_margin_bottom = 8
        action.add_theme_stylebox_override("normal", task_box)
        var hover_box: StyleBoxFlat = task_box.duplicate()
        hover_box.bg_color = Color(0.17, 0.38, 0.42)
        action.add_theme_stylebox_override("hover", hover_box)
        action.add_theme_font_size_override("font_size", 13)
        action.pressed.connect(_run_location_task.bind(site_name, entry))
        task_buttons_container.add_child(action)
    _fit_activity_navigation()
    task_panel.visible = true
    _layout_action_menus()
    if player != null:
        player.velocity = Vector3.ZERO
        player.set_physics_process(false)
        player.set_process_unhandled_input(false)
    _set_mouse_capture(false)

func _close_task_panel() -> void:
    if task_panel != null:
        task_panel.visible = false
    if player != null and not profile_data.is_empty() and ride_bus == null:
        player.set_physics_process(true)
        player.set_process_unhandled_input(true)
    if not overview_on and ride_bus == null:
        _set_mouse_capture(true)

func _run_location_task(site_name: String, entry: Dictionary) -> void:
    var kind: String = str(entry.get("kind", "information"))
    var title: String = str(entry.get("title", "Activity"))
    var task_id: String = site_name + "|" + str(entry.get("id", "task"))
    var today: String = Time.get_date_string_from_system()
    var cost: int = _activity_price(entry)
    var reward: int = int(entry.get("reward", 0))
    var message: String = ""
    if interior_catalog.has(site_name) and active_interior_site != site_name and kind not in ["information", "radio_invite"] and not (site_name == "Sports Centre" and kind == "sports"):
        task_status_label.text = "Enter this building and go to the correct floor before performing this task."
        return
    if energy < 9.0 and kind in ["academic", "arcade_match", "arcade_solo", "sports", "job"]:
        task_status_label.text = "You're exhausted. Eat, rest or sleep before doing another demanding activity."
        return
    if str(entry.get("requires", "")) == "radio_major_or_invitation" and not _radio_eligible(today):
        task_status_label.text = "LASU Radio studio access requires a related media department or a confirmed interview invitation."
        return
    if entry.has("floor") and active_interior_floor != _task_floor_for_site(site_name, entry):
        task_status_label.text = "Go to the indicated floor to begin this activity."
        return
    if entry.has("challenge"):
        if bool(entry.get("once_daily", false)) and str(task_daily_completions.get(task_id, "")) == today:
            task_status_label.text = "You have completed this activity today. Come back tomorrow."
            return
        challenge_site = site_name
        challenge_entry = entry.duplicate(true)
        challenge_step = 0
        _show_challenge_step()
        return
    if kind == "arcade_match":
        var fee: int = cost
        var npc_score: int = rng.randi_range(1, 10)
        var player_score: int = int(skills.get("gaming", 1)) + rng.randi_range(0, 4) - int(stress / 35.0)
        var did_win: bool = player_score >= npc_score
        var payer: String = str(entry.get("payment_mode", "split"))
        cost = (0 if did_win else fee * 2) if payer == "loser" else fee
        message = ("You won" if did_win else "NPC challenger won") + ". " + ("Loser pays the combined bill." if payer == "loser" else "Each player pays their share.") + " Your charge: " + _format_naira(cost) + "."
    elif kind == "arcade_solo":
        message = "Solo arcade challenge completed. This is a prototype activity, not a licensed commercial video game."
    elif kind == "radio_invite":
        if str(profile_data.get("radio_invite_attempt", "")) == today:
            task_status_label.text = "You already requested an interview invitation today."
            return
        profile_data["radio_invite_attempt"] = today
        if rng.randf() < 0.25:
            profile_data["radio_invited_for"] = today
            message = "Your invitation was approved. You may participate in LASU Radio activities today."
        else:
            message = "No studio interview slot was available today. Check back another day."
    if str(entry.get("requires", "")) == "home_faculty":
        var student_faculty: String = str(profile_data.get("faculty", ""))
        if not student_faculty.begins_with(site_name):
            task_status_label.text = "This coursework is limited to enrolled students of " + site_name + ". You can still use public activities."
            return
    if bool(entry.get("once_daily", false)) and str(task_daily_completions.get(task_id, "")) == today:
        task_status_label.text = "Already completed this paid activity today. Please return tomorrow."
        return
    if kind == "event" or kind == "event_job":
        var clock: Dictionary = Time.get_time_dict_from_system()
        var weekday: int = int(Time.get_date_dict_from_system().get("weekday", 0))
        var hour: int = int(clock.get("hour", 0))
        # Prototype: event windows, not verified LASU schedules.
        if not ((weekday == 5 or weekday == 6) and hour >= 16 and hour <= 21):
            task_status_label.text = "No public event is active. Prototype events: Friday/Saturday, 4 PM–9 PM (local time)."
            return
    if kind == "arcade_match" or kind == "arcade_solo" or kind == "radio_invite":
        pass
    elif kind == "sports":
        message = "Training session recorded. Sporting skill practice added."
    elif kind == "social":
        message = "Social activity recorded. You connected with another student."
    elif kind == "restricted":
        var stopped: bool = rng.randf() < 0.75
        if stopped:
            social_reputation -= 1
            message = "Venue security stopped you and escorted you outside. Reputation -1. No physical violence."
        else:
            message = "You slipped into the foyer, but entry is unauthorized. Leave before security arrives."
    elif kind == "hostel":
        if site_name != str(profile_data.get("hostel_name", "")):
            task_status_label.text = "This is not your assigned hostel. Check your wallet panel for your own hostel."
            return
        profile_data["hostel_checked_in"] = true
        message = "Checked into room " + str(profile_data.get("room_number", "?")) + ". First academic session's ₦525,000 rent is prepaid."
    elif kind == "review":
        message = "Wallet " + _format_naira(wallet_balance) + "; completed activities " + str(task_completion_counts.size()) + "."
    elif kind == "information":
        message = str(entry.get("description", ""))
    elif kind == "academic":
        message = "Study activity logged. Academic progression and course grading will be expanded in the next milestone."
    elif kind == "health":
        message = "Clinic request recorded in this prototype. No real medical appointment was created."
    elif kind == "admin":
        message = "Administrative enquiry logged in-game. No real LASU submission was made."
    elif kind == "rest":
        message = "You take a restful break. Find a bench nearby and press F to sit."
    elif kind == "job":
        message = "Job shift completed. Payment added to your in-game wallet."
    elif kind == "event_job":
        message = "Approved event shift completed. Payment added to your in-game wallet."
    elif kind == "purchase" or kind == "laundry" or kind == "print" or kind == "service":
        message = title + " completed. Digital receipt recorded in your inventory."
    else:
        message = str(entry.get("description", ""))
    if cost > wallet_balance:
        task_status_label.text = "Insufficient funds: " + _format_naira(cost) + " needed; wallet " + _format_naira(wallet_balance) + "."
        return
    if kind in ["purchase", "laundry", "print", "service", "arcade_match", "arcade_solo"]:
        task_inventory.append({"date": today, "site": site_name, "item": title, "amount": cost})
    if cost > 0:
        _change_balance(-cost, site_name, title)
    if reward > 0:
        _change_balance(reward, site_name, title)
    if kind != "information" and kind != "review":
        task_completion_counts[task_id] = int(task_completion_counts.get(task_id, 0)) + 1
    if bool(entry.get("once_daily", false)):
        task_daily_completions[task_id] = today
    _apply_activity_stats(entry, task_id, today)
    _save_game()
    _update_wallet_panel()
    message = str(entry.get("success", message))
    task_status_label.text = message
    notice = title + " • " + message
    notice_timer = 7.0


func _load_interior_catalog() -> void:
    var file: FileAccess = FileAccess.open(INTERIOR_CATALOG_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        interior_catalog = parsed.get("locations", {})

func _enter_interior(site_name: String) -> void:
    if interior_builder == null or not interior_catalog.has(site_name) or player == null:
        return
    if not active_interior_site.is_empty():
        return
    if site_name == "LASU Radio" and not _radio_eligible(Time.get_date_string_from_system()):
        task_status_label.text = "Studio floor access requires a media programme or a confirmed student interview invitation."
        return
    outdoor_return_position = player.global_position
    overview_on = false
    if overview_camera != null:
        overview_camera.current = false
    var walking_camera: Camera3D = player.get("camera") as Camera3D
    if walking_camera != null:
        walking_camera.current = true
    active_interior_site = site_name
    active_interior_floor = 0
    _close_task_panel()
    _go_to_interior_floor(0)
    _close_task_panel()
    notice = "Entered " + site_name + ". Press E for rooms, floor selection and exit."
    notice_timer = 5.0

func _go_to_interior_floor(index: int) -> void:
    if active_interior_site.is_empty() or player == null or interior_builder == null:
        return
    var floors: Array = interior_catalog.get(active_interior_site, [])
    if index < 0 or index >= floors.size():
        return
    if player.is_sitting: player.stand_up_from_seat()
    active_interior_floor = index
    active_campus_room = -1
    if campus_social != null: campus_social.clear_peers()
    active_private_room = false
    _close_task_panel()
    var room_marker: int = int(profile_data.get("room_number", 0)) if active_interior_site == str(profile_data.get("hostel_name", "")) else -1
    var inside_position: Vector3 = interior_builder.show_floor(active_interior_site, str(floors[index]), index, room_marker)
    _register_interior_seats()
    player.global_position = inside_position
    player.velocity = Vector3.ZERO
    player.rotation.y = 0.0
    notice = str(floors[index]) + ". Press E to choose a task or change floor."
    notice_timer = 5.0

func _leave_interior() -> void:
    if active_interior_site.is_empty():
        return
    if player.is_sitting: player.stand_up_from_seat()
    _close_task_panel()
    if interior_builder != null:
        interior_builder.clear_interior()
    for seat_item in get_tree().get_nodes_in_group("campus_seats"):
        var seat_node: Node3D = seat_item as Node3D
        if seat_node != null and bool(seat_node.get_meta("inside_pilot", false)):
            seat_node.queue_free()
    player.global_position = outdoor_return_position
    player.velocity = Vector3.ZERO
    active_interior_site = ""
    active_campus_room = -1
    if campus_social != null: campus_social.clear_peers()
    active_interior_floor = 0
    active_private_room = false
    notice = "Exited the building."
    notice_timer = 3.0

func _enter_private_room() -> void:
    if active_interior_site.is_empty() or active_interior_site != str(profile_data.get("hostel_name", "")):
        return
    if player.is_sitting: player.stand_up_from_seat()
    active_private_room = true
    active_campus_room = -1
    if campus_social != null: campus_social.clear_peers()
    profile_data["hostel_checked_in"] = true
    _close_task_panel()
    var position_value: Vector3 = interior_builder.show_private_room(active_interior_site, int(profile_data.get("room_number", 1)), room_furniture)
    _register_interior_seats()
    player.global_position = position_value
    player.velocity = Vector3.ZERO
    notice = "Welcome to your private hostel room. Press E to rest, decorate or control visitors."
    notice_timer = 6.0
    _save_game()

func _return_to_hostel_lobby() -> void:
    if not active_private_room:
        return
    active_private_room = false
    _go_to_interior_floor(0)
    notice = "Returned to your hostel's shared reception. Your room remains private."
    notice_timer = 4.0

func _populate_private_room_menu() -> void:
    task_title_label.text = "MY ROOM " + str(profile_data.get("room_number", "?"))
    task_status_label.text = "Assigned to " + str(profile_data.get("student_name", "Student")) + ". Visitors: " + ("ALLOWED by you" if room_visitors_allowed else "PRIVATE • no visitor access")
    var back_button := Button.new()
    back_button.text = "↩ RETURN TO HOSTEL RECEPTION"
    back_button.pressed.connect(_return_to_hostel_lobby)
    task_buttons_container.add_child(back_button)
    var rest_button := Button.new()
    rest_button.text = "REST ON MY BED • Restore energy and reduce stress (real-time cooldown)"
    rest_button.pressed.connect(_rest_in_room)
    task_buttons_container.add_child(rest_button)
    var privacy_button := Button.new()
    privacy_button.text = "VISITOR PERMISSION: " + ("ON • disable invitations" if room_visitors_allowed else "OFF • allow invited visitors")
    privacy_button.pressed.connect(_toggle_room_visitors)
    task_buttons_container.add_child(privacy_button)
    var furniture_options: Array = [
        ["bookshelf", "Bookshelf & study books", 3800],
        ["lamp", "Warm bedside lamp", 1500],
        ["plant", "Decorative room plant", 2200],
        ["gaming_setup", "Small gaming setup", 24000],
        ["poster", "Framed wall poster", 900]
    ]
    for option_value in furniture_options:
        var option: Array = option_value
        if room_furniture.has(str(option[0])):
            continue
        var buy_button := Button.new()
        buy_button.text = "BUY  " + str(option[1]) + "   •   " + _format_naira(int(option[2]))
        buy_button.pressed.connect(_buy_room_furniture.bind(str(option[0]), int(option[2])))
        task_buttons_container.add_child(buy_button)
    var exit_button := Button.new()
    exit_button.text = "EXIT HOSTEL TO CAMPUS"
    exit_button.pressed.connect(_leave_interior)
    task_buttons_container.add_child(exit_button)

func _refresh_private_room_menu() -> void:
    if active_private_room:
        _close_task_panel()
        _open_task_panel(active_interior_site)

func _toggle_room_visitors() -> void:
    room_visitors_allowed = not room_visitors_allowed
    _save_game()
    notice = "Visitor permission " + ("enabled" if room_visitors_allowed else "disabled") + ". NPC invitations are planned for a later release."
    notice_timer = 5.0
    _refresh_private_room_menu()

func _rest_in_room() -> void:
    var now: int = int(Time.get_unix_time_from_system())
    if now - last_room_rest_unix < 2700:
        var minutes_remaining: int = int(ceil(float(2700 - (now - last_room_rest_unix)) / 60.0))
        task_status_label.text = "You can rest again in " + str(minutes_remaining) + " minutes."
        return
    last_room_rest_unix = now
    energy = minf(100.0, energy + 22.0)
    stamina = minf(100.0, stamina + 16.0)
    stress = maxf(0.0, stress - 17.0)
    _save_game()
    _update_hud()
    task_status_label.text = "You feel refreshed! Energy +22, Stamina +16, Stress -17."

func _buy_room_furniture(furniture_id: String, price: int) -> void:
    if room_furniture.has(furniture_id):
        task_status_label.text = "You already own this furnishing."
        return
    if wallet_balance < price:
        task_status_label.text = "Insufficient funds. This costs " + _format_naira(price) + "."
        return
    _change_balance(-price, "Hostel furniture", furniture_id.replace("_", " "))
    room_furniture.append(furniture_id)
    interior_builder.show_private_room(active_interior_site, int(profile_data.get("room_number", 1)), room_furniture)
    _register_interior_seats()
    _save_game()
    _update_wallet_panel()
    _refresh_private_room_menu()
    notice = "Your room has a new " + furniture_id.replace("_", " ") + "!"
    notice_timer = 4.0

func _roll_initial_skills() -> void:
    skills.clear()
    skill_xp.clear()
    skill_daily_xp.clear()
    for name_value in ["intellect", "social", "gaming", "media", "business", "sports", "creativity", "stamina"]:
        var name_text: String = str(name_value)
        skills[name_text] = rng.randi_range(1, 7)
        skill_xp[name_text] = 0
    energy = float(rng.randi_range(70, 100))
    stamina = float(rng.randi_range(70, 100))
    stress = float(rng.randi_range(0, 20))

func _arcade_grid_is_available() -> bool:
    # Stable for each real-world clock hour; avoids random price changes while
    # someone is deciding whether to buy a game.
    var stamp: String = Time.get_date_string_from_system() + str(Time.get_time_dict_from_system().get("hour", 0))
    return posmod(stamp.hash(), 100) < 66

func _activity_price(entry: Dictionary) -> int:
    if entry.has("grid_cost"):
        return int(entry.get("grid_cost", 0)) if _arcade_grid_is_available() else int(entry.get("generator_cost", 0))
    return int(entry.get("cost", 0))

func _radio_eligible(today: String) -> bool:
    var subject: String = str(profile_data.get("department", "")).to_lower()
    var faculty: String = str(profile_data.get("faculty", "")).to_lower()
    if subject.contains("communication") or subject.contains("broadcast") or subject.contains("journalism") or subject.contains("media") or faculty.contains("media"):
        return true
    return str(profile_data.get("radio_invited_for", "")) == today

func _apply_activity_stats(entry: Dictionary, task_id: String, today: String) -> void:
    var kind: String = str(entry.get("kind", ""))
    var fatigue: float = float(entry.get("energy_cost", 4.0 if kind in ["academic", "arcade_match", "sports", "job", "arcade_solo"] else 0.0))
    var energy_gain: float = float(entry.get("energy_gain", 0.0))
    if kind == "rest":
        energy_gain += 16.0
        stamina = minf(100.0, stamina + 12.0)
        stress = maxf(0.0, stress - 12.0)
    else:
        stress = clampf(stress + float(entry.get("stress_delta", 2.0 if fatigue > 0.0 else 0.0)), 0.0, 100.0)
    energy = clampf(energy - fatigue + energy_gain, 0.0, 100.0)
    var skill_name: String = str(entry.get("skill", ""))
    if skill_name.is_empty():
        if kind == "academic":
            skill_name = "intellect"
        elif kind == "sports":
            skill_name = "sports"
        elif kind == "arcade_match" or kind == "arcade_solo":
            skill_name = "gaming"
        elif kind == "job" or kind == "purchase":
            skill_name = "business"
        elif kind == "social":
            skill_name = "social"
    if skill_name.is_empty() or not skills.has(skill_name):
        return
    # Once per task/day for XP prevents free-click skill grinding.
    if str(skill_daily_xp.get(task_id, "")) == today:
        return
    skill_daily_xp[task_id] = today
    var current_level: int = clampi(int(skills.get(skill_name, 1)), 1, 10)
    if current_level >= 10:
        return
    var points: int = 20
    if energy < 25.0 or stress > 75.0:
        points = 10
    var xp: int = int(skill_xp.get(skill_name, 0)) + points
    var required: int = 65 + current_level * 45
    if xp >= required:
        skills[skill_name] = mini(current_level + 1, 10)
        xp -= required
        notice = skill_name.capitalize() + " level increased to " + str(skills[skill_name]) + "!"
        notice_timer = 5.0
    skill_xp[skill_name] = xp


func _task_floor_for_site(site_name: String, entry: Dictionary) -> int:
    var options: Array = interior_catalog.get(site_name, [])
    if entry.has("floor"):
        return clampi(int(entry.floor), 0, maxi(0, options.size() - 1))
    if options.size() < 2:
        return 0
    var taskid: String = str(entry.get("id", "")).to_lower()
    var kind: String = str(entry.get("kind", ""))
    if site_name == "Arcade":
        if taskid.contains("hallowed") or taskid.contains("chamber"):
            return 0
        if taskid.contains("union") or taskid.contains("permit") or taskid.contains("representative"):
            return 1
        return 0
    if site_name == "LASU Radio":
        return 0 if kind == "information" or kind == "radio_invite" else 1
    if kind in ["purchase", "laundry", "print", "service", "health", "information", "admin", "hostel"]:
        return 0
    return posmod(taskid.hash(), options.size() - 1) + 1


func _register_interior_seats() -> void:
    for old_seat_variant in get_tree().get_nodes_in_group("campus_seats"):
        var old_seat: Node3D = old_seat_variant as Node3D
        if old_seat != null and bool(old_seat.get_meta("inside_pilot", false)):
            old_seat.remove_from_group("campus_seats")
            old_seat.queue_free()
    if interior_builder == null:
        return
    var seat_meshes: Array = []
    _collect_seat_meshes(interior_builder, seat_meshes)
    for mesh_variant in seat_meshes:
        var mesh: MeshInstance3D = mesh_variant as MeshInstance3D
        if mesh == null:
            continue
        var anchor := Node3D.new()
        anchor.name = "IndoorSeat"
        anchor.set_meta("inside_pilot", true)
        anchor.set_meta("seat_name", active_interior_site + " waiting chair")
        anchor.add_to_group("campus_seats")
        add_child(anchor)
        var world: Vector3 = mesh.global_position
        anchor.set_meta("seat_surface_position", world)
        anchor.global_position = Vector3(world.x, maxf(0.05, world.y - 0.37), world.z - 0.40)


func _set_mouse_capture(capture: bool) -> void:
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture and not MOBILE_CONTROLS.touch_device() else Input.MOUSE_MODE_VISIBLE

func _sync_mobile_controls() -> void:
    if mobile_controls == null or player == null:
        return
    var playable: bool = not profile_data.is_empty() and profile_layer == null and not student_ui.modal.visible and not (campus_phone != null and campus_phone.panel.visible) and not task_panel.visible and not shuttle_menu.visible
    mobile_controls.set_enabled(playable, ride_bus != null, overview_on)
    player.touch_movement = mobile_controls.movement if playable and ride_bus == null and not overview_on else Vector2.ZERO
    player.touch_running = mobile_controls.running if playable and ride_bus == null and not overview_on else false
    if not playable:
        player.touch_jump = false

func _mobile_action(action: String) -> void:
    if profile_data.is_empty() or student_ui.modal.visible or (campus_phone != null and campus_phone.panel.visible) or task_panel.visible or shuttle_menu.visible:
        return
    match action:
        "interact":
            if ride_bus != null:
                if transit_system.has_arrived(ride_bus):
                    _disembark_shuttle()
                else:
                    notice = "Stay seated until the shuttle reaches its stop."
                    notice_timer = 3
            elif not active_interior_site.is_empty():
                if not try_campus_interaction(player):
                    _open_task_panel(active_interior_site)
            else:
                player.perform_interaction()
        "sit":
            player.perform_seat_interaction()
        "jump":
            player.touch_jump = true
        "map":
            overview_on = not overview_on
            overview_camera.current = overview_on
            if not overview_on:
                player.camera.current = true
        "view":
            if ride_bus != null:
                transit_system.toggle_passenger_view(ride_bus)
    _sync_mobile_controls()

func _look_around(relative: Vector2) -> void:
    if ride_bus != null:
        transit_system.look_passenger(ride_bus, relative)
    elif not overview_on:
        player.look(relative * 1.35)

func _fit_activity_navigation() -> void:
    for control in task_buttons_container.get_children():
        if control is Button and control.get_child_count() == 0:
            var caption: String = control.text
            control.text = ""
            control.custom_minimum_size = Vector2(0, 52)
            var text := Label.new()
            text.text = caption
            text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            text.mouse_filter = Control.MOUSE_FILTER_IGNORE
            text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            text.offset_left = 10
            text.offset_right = -10
            text.offset_top = 6
            text.offset_bottom = -6
            text.add_theme_font_size_override("font_size", 13)
            control.add_child(text)
            text.resized.connect(func(): control.custom_minimum_size.y = maxf(52, text.get_minimum_size().y + 12))

func _register_billboards(root: Node) -> void:
    if root is Node3D and root.has_meta("ad_slot_id") and root.has_meta("ad_tier"):
        billboard_slots.append(root)
        for child in root.get_children():
            if child is MeshInstance3D and child.name.begins_with("AdvertisingPanel"):
                var area := Area3D.new()
                area.name = "AdInteractionArea"
                area.collision_layer = 2
                area.collision_mask = 0
                area.set_meta("ad_slot_id", root.get_meta("ad_slot_id"))
                var collision := CollisionShape3D.new()
                var box := BoxShape3D.new()
                box.size = Vector3(child.mesh.size.x, child.mesh.size.y, 0.4)
                collision.shape = box
                area.position = child.position
                area.add_child(collision)
                root.add_child(area)
                break
    for child in root.get_children():
        _register_billboards(child)

func try_billboard_interaction(walker: Node3D) -> bool:
    var closest: Node3D = null
    var distance: float = 7.0
    for slot in billboard_slots:
        var d: float = Vector2(walker.global_position.x - slot.global_position.x, walker.global_position.z - slot.global_position.z).length()
        if d < distance:
            closest = slot
            distance = d
    if closest == null:
        return false
    _open_advertising(str(closest.get_meta("ad_slot_id")))
    return true

func _open_advertising(slot: String) -> void:
    selected_billboard = slot
    student_ui.toggle("advertise")
    student_ui.profile_text.text = "BILLBOARD " + slot + "\n\nBusiness advertising is planned for after launch.\n\nChoose a billboard, preview your business image, select a campaign duration, and pay through Paystack or Flutterwave when bookings open. Campaigns will be reviewed before publication.\n\nReal-money booking is not open yet. No game-wallet money is charged.\n\nUse the Preview ad button to try the design form. Your image stays on your device during this preview."

func _preview_advertisement() -> void:
    var url: String = "https://trippletee20.github.io/INSIDELASU/advertise.html?slot=" + selected_billboard.uri_encode()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.open(" + JSON.stringify(url) + ", '_blank', 'noopener,noreferrer')")
    else:
        OS.shell_open(url)

func _show_challenge_step() -> void:
    for child in task_buttons_container.get_children():
        task_buttons_container.remove_child(child)
        child.queue_free()
    var steps: Array = challenge_entry.get("challenge", [])
    if challenge_step >= steps.size():
        var completed: Dictionary = challenge_entry.duplicate(true)
        completed.erase("challenge")
        var site: String = challenge_site
        _open_task_panel(site)
        _run_location_task(site, completed)
        return
    var step: Dictionary = steps[challenge_step]
    task_title_label.text = str(challenge_entry.get("title", "Activity"))
    task_status_label.text = "Step %d of %d • %s" % [challenge_step + 1, steps.size(), str(step.prompt)]
    for i in range(step.options.size()):
        var choice := Button.new()
        choice.text = str(step.options[i])
        choice.pressed.connect(_answer_challenge.bind(i))
        task_buttons_container.add_child(choice)
    var back := Button.new()
    back.text = "Cancel activity • no charge or reward"
    back.pressed.connect(_open_task_panel.bind(challenge_site))
    task_buttons_container.add_child(back)
    _fit_activity_navigation()
    _layout_action_menus()

func _answer_challenge(answer: int) -> void:
    var steps: Array = challenge_entry.get("challenge", [])
    if challenge_step >= steps.size():
        return
    if answer != int(steps[challenge_step].answer):
        task_status_label.text = "Try again: " + str(steps[challenge_step].prompt) + " No reward has been claimed."
        return
    challenge_step += 1
    _show_challenge_step()

func _try_billboard_at(at: Vector2) -> bool:
    if profile_data.is_empty() or student_ui.modal.visible or (campus_phone != null and campus_phone.panel.visible) or task_panel.visible or shuttle_menu.visible or ride_bus != null or overview_on:
        return false
    var camera: Camera3D = get_viewport().get_camera_3d()
    if camera == null:
        return false
    var start: Vector3 = camera.project_ray_origin(at)
    var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(at) * 100, 3)
    query.collide_with_areas = true
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty() or not hit.collider.has_meta("ad_slot_id"):
        return false
    _open_advertising(str(hit.collider.get_meta("ad_slot_id")))
    return true


func is_near_site(site: String) -> bool:
    if player == null: return false
    for feature in get_tree().get_nodes_in_group("campus_features"):
        if str(feature.get_meta("campus_name", "")) != site: continue
        var offset: Vector3 = player.global_position - feature.global_position
        return Vector2(maxf(absf(offset.x) - float(feature.get_meta("feature_half_width", 0)), 0), maxf(absf(offset.z) - float(feature.get_meta("feature_half_depth", 0)), 0)).length() <= 12.0
    return false

func _create_entrance_markers() -> void:
    for feature in get_tree().get_nodes_in_group("campus_features"):
        var site: String = str(feature.get_meta("campus_name", ""))
        if not interior_catalog.has(site): continue
        var caption := Label3D.new()
        caption.text = "ENTER · INTERACT\n" + site
        caption.font_size = 30
        caption.pixel_size = 0.014
        caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        caption.position = Vector3(0, 2.2, float(feature.get_meta("feature_half_depth", 0)) + 1.5)
        caption.modulate = Color("7ce6be")
        caption.no_depth_test = false
        feature.add_child(caption)

func _enter_campus_room(index: int) -> void:
    if active_interior_site.is_empty() or active_private_room: return
    var rooms: Array = CAMPUS_ROOMS.for_site(active_interior_site, building_experiences)
    if index < 0 or index >= rooms.size(): return
    if player.is_sitting: player.stand_up_from_seat()
    _close_task_panel()
    active_campus_room = index
    if campus_social != null: campus_social.clear_peers()
    player.global_position = interior_builder.show_campus_room(active_interior_site, rooms[index], active_interior_floor)
    player.velocity = Vector3.ZERO
    _register_interior_seats()
    notice = str(rooms[index][0]) + " · Explore, meet the staff or use the marked objects."
    notice_timer = 6

func social_location() -> String:
    if active_private_room:
        return "private:" + str(profile_data.get("hostel_name", "")) + ":" + str(profile_data.get("room_number", ""))
    if active_interior_site.is_empty(): return "campus"
    return active_interior_site + ":" + str(active_interior_floor) + ":" + str(active_campus_room)

func try_campus_interaction(walker: Node3D) -> bool:
    if campus_phone == null: return false
    for peer in get_tree().get_nodes_in_group("online_students"):
        if peer.global_position.distance_to(walker.global_position) < 3:
            campus_phone.open("Contacts")
            campus_social.conversation(campus_phone, str(peer.get_meta("username", "")))
            return true
    var nearest: Node3D = null
    var distance: float = 2.8
    for point in get_tree().get_nodes_in_group("campus_actions"):
        var value: float = point.global_position.distance_to(walker.global_position)
        if value < distance:
            nearest = point
            distance = value
    if nearest == null: return false
    var action: String = str(nearest.get_meta("action", "tasks"))
    if action == "notes":
        campus_phone.open("Notes")
    elif action == "rooms":
        _open_task_panel(active_interior_site)
    elif action == "staff":
        _open_task_panel(active_interior_site)
        task_title_label.text = str(nearest.get_meta("role", "Campus staff"))
        task_status_label.text = str(nearest.get_meta("dialogue", "Welcome. Choose a service or activity below."))
    else:
        _open_task_panel(active_interior_site)
    return true
