extends Node3D
# INSIDE LASU v0.12 — Stylised modular building interiors.
# All completed indoor site entries share a walkable shell but use distinct
# room contents, palettes and floor arrangements. These are NOT field-surveyed
# architectural plans. Only the active floor is instantiated (low-end friendly).
const IDENTITY = preload("res://scripts/interior_identity.gd")
var designs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_experiences.json")).get("locations", {})
var current_floor: Node3D = null
var current_site: String = ""
const ROOM_BASE: Vector3 = Vector3(900.0, 0.0, 0.0)

func _material(tint: Color, glowing: bool = false) -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.64
    if glowing:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 0.55
    return mat

func _shape(parent: Node3D, piece_name: String, position_value: Vector3, dimensions: Vector3, tint: Color, solid: bool = false, glow: bool = false) -> void:
    var item: MeshInstance3D = MeshInstance3D.new()
    item.name = piece_name
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = dimensions
    item.mesh = mesh
    item.position = position_value
    item.material_override = _material(tint, glow)
    parent.add_child(item)
    if piece_name.to_lower().ends_with("seat"):
        item.add_to_group("sit_interactable")
    if solid:
        var body: StaticBody3D = StaticBody3D.new()
        body.name = piece_name + "Collision"
        body.position = position_value
        parent.add_child(body)
        var collider: CollisionShape3D = CollisionShape3D.new()
        var box: BoxShape3D = BoxShape3D.new()
        box.size = dimensions
        collider.shape = box
        body.add_child(collider)

func _label(parent: Node3D, caption: String, at: Vector3, size_value: int = 38, tint: Color = Color(0.98, 0.97, 0.91)) -> void:
    var label: Label3D = Label3D.new()
    label.name = "RoomSign"
    label.text = caption
    label.position = at
    label.font_size = size_value
    label.pixel_size = 0.009
    label.modulate = tint
    label.outline_size = 5
    label.outline_modulate = Color(0.06, 0.11, 0.18)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)

func _seat(parent: Node3D, at: Vector3, color: Color, seat_name: String = "ChairSeat") -> void:
    _shape(parent, seat_name, at + Vector3(0, 0.46, 0), Vector3(1.05, 0.17, 0.88), color)
    _shape(parent, "ChairBack", at + Vector3(0, 0.86, 0.43), Vector3(1.05, 0.82, 0.13), color.darkened(0.2))
    for side in [-0.39, 0.39]:
        _shape(parent, "ChairLeg", at + Vector3(side, 0.22, -0.26), Vector3(0.11, 0.45, 0.12), Color(0.24, 0.31, 0.37))

func _table(parent: Node3D, at: Vector3, dims: Vector3, wood: Color, name_value: String = "Table") -> void:
    _shape(parent, name_value, at + Vector3(0, 0.78, 0), Vector3(dims.x, 0.16, dims.z), wood, true)
    for side in [-1.0, 1.0]:
        for near in [-1.0, 1.0]:
            _shape(parent, "TableSupport", at + Vector3(side * (dims.x * 0.4), 0.37, near * (dims.z * 0.38)), Vector3(0.13, 0.68, 0.13), Color(0.26, 0.31, 0.35))

func _room_shell(node: Node3D, title_text: String, warm: Color, accent: Color, dark: Color, theme: String = "lecture") -> void:
    _shape(node, "WalkableInteriorFloor", Vector3(0, -0.16, 0), Vector3(29.0, 0.32, 25.0), accent.lightened(0.58) if theme not in ["library", "law", "auditorium", "hostel"] else Color(0.57, 0.43, 0.30), true)
    _shape(node, "EntranceRunner", Vector3(0, 0.017, 5.7), Vector3(4.6, 0.025, 12), Color(0.13, 0.32, 0.39))
    _shape(node, "BackWall", Vector3(0, 2.30, -12.35), Vector3(29.0, 4.6, 0.32), warm, true)
    _shape(node, "LeftWall", Vector3(-14.32, 2.30, 0), Vector3(0.32, 4.6, 24.8), warm, true)
    _shape(node, "RightWall", Vector3(14.32, 2.30, 0), Vector3(0.32, 4.6, 24.8), warm, true)
    _shape(node, "FrontLeft", Vector3(-9.2, 2.30, 12.3), Vector3(10.6, 4.6, 0.3), warm, true)
    _shape(node, "FrontRight", Vector3(9.2, 2.30, 12.3), Vector3(10.6, 4.6, 0.3), warm, true)
    # Central corridor opens into two wings through 3 m gaps in these partitions.
    var wing_sides: Array = [-1.0, 1.0] if theme in ["hostel", "clinic", "education", "lecture", "social"] else []
    for side in wing_sides:
        var xx: float = side * 4.2
        _shape(node, "UpperCorridorPartition", Vector3(xx, 2.0, -7.7), Vector3(0.25, 4.0, 9.0), warm.lightened(0.06), true)
        _shape(node, "LowerCorridorPartition", Vector3(xx, 2.0, 7.5), Vector3(0.25, 4.0, 8.2), warm.lightened(0.06), true)
        _shape(node, "RoomDoorHeader", Vector3(xx, 3.35, 0.05), Vector3(0.3, 0.47, 3.5), dark)
        for zed in [-8.0, -2.0, 4.4, 9.6]:
            _shape(node, "InteriorWindow", Vector3(side * 14.12, 2.75, zed), Vector3(0.08, 1.2, 2.0), Color(0.34, 0.70, 0.77))
    # Lightweight ceiling geometry leaves open sightlines in third-person.
    for zed in [-10.2, -4.5, 1.2, 7.0]:
        _shape(node, "CeilingBeam", Vector3(0, 4.45, zed), Vector3(28, 0.23, 0.5), accent.darkened(0.25))
        _shape(node, "CeilingLight", Vector3(0, 4.3, zed), Vector3(3.1, 0.06, 0.30), Color(1.0, 0.91, 0.65), false, true)
    _shape(node, "WelcomeBanner", Vector3(0, 3.25, -12.13), Vector3(10.6, 1.0, 0.10), dark)
    _label(node, title_text.to_upper(), Vector3(0, 3.24, -11.86), 33)
    _shape(node, "NoticeDisplay", Vector3(0, 2.05, -11.94), Vector3(4.2, 0.88, 0.11), accent)
    _label(node, "WELCOME • CAMPUS SERVICES", Vector3(0, 2.08, -11.78), 22)
    _shape(node, "ExitMarker", Vector3(0, 3.6, 12.05), Vector3(2.8, 0.6, 0.12), Color(0.12, 0.54, 0.40), false, true)
    _label(node, "EXIT", Vector3(0, 3.59, 11.87), 32)
    # Soft focus plant sculptures and seating in the entry lobby.
    for xx in [-12.6, 12.6]:
        _shape(node, "PlantPot", Vector3(xx, 0.40, 9.8), Vector3(0.8, 0.75, 0.8), Color(0.60, 0.36, 0.23))
        _shape(node, "Foliage", Vector3(xx, 1.26, 9.8), Vector3(1.2, 1.13, 0.95), Color(0.18, 0.56, 0.38))
    _label(node, "INTERACT: ACTIVITIES & FLOORS", Vector3(0, 2.0, 11.75), 22)

func _hostel_rooms(node: Node3D, floor_index: int, blue: Color, wood: Color) -> void:
    var rooms: Array = [Vector3(-9.1, 0, -6.1), Vector3(9.1, 0, -6.1)]
    for origin_variant in rooms:
        var origin: Vector3 = origin_variant
        for bed_index in range(2):
            var bed_at: Vector3 = origin + Vector3(-1.2 + bed_index * 2.6, 0, 0)
            _shape(node, "BedFrame", bed_at + Vector3(0, 0.45, 0), Vector3(1.9, 0.22, 3.2), Color(0.26, 0.31, 0.38))
            _shape(node, "Mattress", bed_at + Vector3(0, 0.64, 0), Vector3(1.75, 0.24, 2.9), Color(0.90, 0.92, 0.85))
            _shape(node, "Pillow", bed_at + Vector3(0, 0.79, -1.06), Vector3(1.1, 0.15, 0.55), Color(0.98, 0.81, 0.52))
            _shape(node, "HostelBlanket", bed_at + Vector3(0, 0.78, 0.58), Vector3(1.7, 0.10, 1.3), blue)
        _shape(node, "Wardrobe", origin + Vector3(0, 1.42, -3.5), Vector3(3.4, 2.8, 0.90), wood)
        _table(node, origin + Vector3(0, 0, 4.2), Vector3(2.9, 0, 1.35), wood, "HostelStudyDesk")
        _seat(node, origin + Vector3(0, 0, 2.9), blue, "HostelStudySeat")
        _label(node, "ROOM " + str(101 + floor_index * 10 + int((origin.x + 10.0) / 15.0)), origin + Vector3(0, 3.48, 0), 24)
    _shape(node, "HostelReception", Vector3(-9, 0.87, 5.6), Vector3(4.3, 1.7, 1.35), wood)
    _seat(node, Vector3(8.8, 0, 7.0), blue, "LoungeSeat")
    _seat(node, Vector3(10.2, 0, 7.0), blue, "LoungeSeat")
    _shape(node, "KitchenetteCounter", Vector3(8.9, 0.85, 9.8), Vector3(4.4, 1.7, 1.0), Color(0.78, 0.81, 0.79))
    _label(node, "HOSTEL LIFE • ROOMS • STUDY • LOUNGE", Vector3(0, 2.7, -4.0), 23)
    _shape(node, "ResidentsPrivateDoor", Vector3(0, 1.42, -12.05), Vector3(2.4, 2.75, 0.14), wood)
    _shape(node, "ResidentsDoorHandle", Vector3(0.81, 1.18, -11.95), Vector3(0.15, 0.16, 0.12), Color(0.96, 0.77, 0.35))
    _label(node, "PRIVATE ROOMS • RESIDENTS ONLY", Vector3(0, 3.65, -11.85), 23)

func _study_rooms(node: Node3D, wood: Color, accent: Color, library_mode: bool = false) -> void:
    for side in [-1.0, 1.0]:
        var xx: float = side * 9.0
        for j in range(3):
            _table(node, Vector3(xx, 0, -6.7 + float(j) * 4.0), Vector3(2.65, 0, 1.3), wood, "StudyDesk")
            _seat(node, Vector3(xx, 0, -5.65 + float(j) * 4.0), accent, "StudySeat")
        if library_mode:
            for row_index in range(3):
                _shape(node, "Bookcase", Vector3(xx + side * 3.5, 1.65, -9.1 + float(row_index) * 5.0), Vector3(0.85, 3.2, 2.6), wood)
                _shape(node, "BookSpines", Vector3(xx + side * 3.1, 1.72, -9.1 + float(row_index) * 5.0), Vector3(0.14, 1.9, 2.22), accent)
        else:
            _shape(node, "Whiteboard", Vector3(xx, 2.3, -11.9), Vector3(4.2, 1.75, 0.12), Color(0.93, 0.96, 0.92))
    _label(node, "LEARNING & STUDY ZONES", Vector3(0, 2.68, -5.4), 25)

func _service_rooms(node: Node3D, wood: Color, accent: Color, site: String) -> void:
    for side in [-1.0, 1.0]:
        var xx: float = side * 9.0
        _shape(node, "ShopCounter", Vector3(xx, 0.76, 0.6), Vector3(6.4, 1.45, 1.35), wood)
        for i in range(3):
            var shelf_x: float = xx - 2.5 + float(i) * 2.5
            _shape(node, "RetailShelf", Vector3(shelf_x, 1.3, -7.2), Vector3(1.8, 2.5, 0.75), accent.darkened(0.1))
            for level in range(3):
                _shape(node, "RetailProducts", Vector3(shelf_x, 0.65 + float(level) * 0.65, -6.64), Vector3(1.3, 0.32, 0.6), Color(0.95 - float(level) * 0.1, 0.72, 0.34))
        _label(node, "SERVICE COUNTER", Vector3(xx, 3.4, -1.5), 25)
    _shape(node, "PriceBoard", Vector3(0, 2.4, -11.7), Vector3(3.5, 1.65, 0.15), Color(0.11, 0.37, 0.37))
    _label(node, "VIEW SERVICES WITH E", Vector3(0, 2.4, -11.45), 20)
    if "laundry" in site or "laundromat" in site:
        for i in range(5):
            var xx: float = -11.5 + float(i) * 5.7
            _shape(node, "WashingMachine", Vector3(xx, 0.85, -8.6), Vector3(1.65, 1.7, 1.7), Color(0.80, 0.87, 0.90))
            _shape(node, "MachineDoor", Vector3(xx, 0.88, -7.67), Vector3(1.1, 1.0, 0.08), Color(0.15, 0.32, 0.43))

func _special_rooms(node: Node3D, site_name: String, floor_title: String, wood: Color, accent: Color) -> void:
    var text: String = (site_name + " " + floor_title).to_lower()
    if "arcade" in text:
        if "union" in text or "office" in text:
            _study_rooms(node, wood, accent)
            _label(node, "STUDENT UNION • PRESIDENT • VP • FINANCE", Vector3(0, 2.60, -4.8), 22)
        else:
            _service_rooms(node, wood, accent, "arcade")
            _shape(node, "PoolTable", Vector3(9, 0.75, 5.7), Vector3(4.4, 0.5, 2.4), Color(0.13, 0.54, 0.36))
            _shape(node, "GameConsole", Vector3(-9, 1.35, 4.1), Vector3(3.9, 1.8, 0.8), Color(0.12, 0.20, 0.30))
            _label(node, "HALLOWED CHAMBER • MEETINGS & EVENTS", Vector3(0, 2.65, -6.4), 22)
    elif "hostel" in text or "quarters" in text:
        _hostel_rooms(node, 0, accent, wood)
    elif "library" in text:
        _study_rooms(node, wood, accent, true)
    elif "radio" in text or "mass communication" in text:
        _shape(node, "MixingConsole", Vector3(-9, 0.96, -6), Vector3(5.6, 0.55, 2.1), Color(0.12, 0.25, 0.37))
        for k in range(4):
            _shape(node, "AudioMixer", Vector3(-10.6 + float(k) * 1.05, 1.30, -5.8), Vector3(0.5, 0.12, 0.5), Color(0.48, 0.81, 0.72))
        _shape(node, "SoundproofGlass", Vector3(9, 1.86, -7.6), Vector3(6.3, 3.7, 0.20), Color(0.26, 0.56, 0.62))
        _table(node, Vector3(9, 0, 1.4), Vector3(3.4, 0, 1.6), wood, "InterviewTable")
        _seat(node, Vector3(8.4, 0, 3.0), accent, "StudioSeat")
        _seat(node, Vector3(10.0, 0, 3.0), accent, "StudioSeat")
        _label(node, "RADIO • PRODUCTION • MEDIA", Vector3(0, 2.75, -5.2), 23)
    elif "health" in text:
        for i in range(3):
            _shape(node, "ExamBed", Vector3(-10 + float(i) * 8.5, 0.7, -6.2), Vector3(2.2, 1.1, 3.6), Color(0.86, 0.93, 0.92))
        _label(node, "TRIAGE • HEALTH • CONSULTATION", Vector3(0, 2.7, -5.3), 23)
    elif "chapel" in text:
        for i in range(4):
            for side in [-1.0, 1.0]:
                _shape(node, "PewSeat", Vector3(side * 9, 0.54, -7 + float(i) * 3.5), Vector3(5.2, 1.0, 1.1), wood)
        _shape(node, "Lectern", Vector3(0, 0.90, -8.0), Vector3(3.0, 1.75, 1.0), accent)
    elif "sports" in text:
        _shape(node, "TrainingMat", Vector3(9, 0.08, -6), Vector3(6.0, 0.15, 5.1), accent)
        for i in range(4):
            _shape(node, "GymLocker", Vector3(-11.5 + float(i) * 1.8, 1.5, -8.9), Vector3(1.45, 2.95, 0.9), wood)
    elif "auditorium" in text or "chamber" in text or "hall" in text and not "science" in text:
        _shape(node, "Stage", Vector3(0, 0.45, -9.0), Vector3(12.2, 0.9, 4.0), wood)
        for i in range(3):
            for side in [-1.0, 1.0]:
                _seat(node, Vector3(side * 9, 0, -3.5 + float(i) * 3.2), accent, "HallSeat")
    elif "cyber" in text or "registration" in text:
        _study_rooms(node, wood, accent)
        for i in range(5):
            _shape(node, "ComputerMonitor", Vector3(-11 + float(i) * 4.6, 1.3, -5.9), Vector3(0.85, 0.7, 0.13), Color(0.16, 0.24, 0.34))
    elif "banking" in text:
        _service_rooms(node, wood, accent, text)
        for i in range(3):
            _shape(node, "ATM", Vector3(-10 + float(i) * 9.5, 1.56, -8), Vector3(2, 3.1, 1.0), Color(0.18, 0.34, 0.47))
    elif "market" in text or "shops" in text or "kitchen" in text or "hut" in text or "laundromat" in text:
        _service_rooms(node, wood, accent, text)
    else:
        _study_rooms(node, wood, accent, false)
        _shape(node, "FacultyReception", Vector3(-9, 0.77, 5.7), Vector3(4.2, 1.5, 1.2), wood)
        _label(node, "ADMIN • RECEPTION • TEACHING", Vector3(0, 2.75, -5.3), 23)

func show_floor(site_name: String, floor_title: String, floor_index: int, own_room: int = -1) -> Vector3:
    if current_floor != null:
        remove_child(current_floor)
        current_floor.queue_free()
    current_floor = Node3D.new()
    current_floor.name = "InteriorFloor_" + str(floor_index)
    current_floor.position = ROOM_BASE
    add_child(current_floor)
    current_site = site_name
    visible = true
    var seed_value: int = absi(site_name.hash()) % 4
    var palette: Array[Color] = [Color(0.15, 0.52, 0.54), Color(0.22, 0.40, 0.62), Color(0.51, 0.34, 0.59), Color(0.28, 0.52, 0.38)]
    var accent: Color = palette[seed_value]
    var wood: Color = Color(0.52, 0.36, 0.24)
    var warm: Color = Color(0.88, 0.85, 0.77)
    var dark: Color = Color(0.09, 0.20, 0.28)
    var design: Dictionary = designs.get(site_name, {})
    var theme: String = str(design.get("theme", "lecture"))
    accent = Color(str(design.get("accent", "397777")))
    warm = accent.lightened(0.78)
    _room_shell(current_floor, site_name, warm, accent, dark, theme)
    _label(current_floor, floor_title.to_upper(), Vector3(0, 2.75, 4.7), 26)
    IDENTITY.new().build(self, current_floor, theme, floor_index, site_name, accent)
    if own_room > 0 and "hostel" in site_name.to_lower():
        _label(current_floor, "ROOM " + str(own_room) + " • INTERACT FOR YOUR ROOM", Vector3(0, 3.18, -11.8), 23)
    _action_point(current_floor, "rooms", "ROOMS & TASKS · INTERACT", Vector3(0, 0, 6.5))
    return ROOM_BASE + Vector3(0, 0.45, 9.5)

func show_private_room(hostel_name: String, room_number: int, chosen_furniture: Array) -> Vector3:
    # Single-player private-instance room: NEVER reused as another player's
    # room; visitors require explicit permission (future NPC/network hook).
    if current_floor != null:
        remove_child(current_floor)
        current_floor.queue_free()
    current_floor = Node3D.new()
    current_floor.name = "PrivateHostelRoom_" + str(room_number)
    current_floor.position = ROOM_BASE
    add_child(current_floor)
    current_site = hostel_name
    visible = true
    var node: Node3D = current_floor
    var cream: Color = Color(0.89, 0.86, 0.80)
    var teal: Color = Color(0.12, 0.46, 0.49)
    var wood: Color = Color(0.47, 0.30, 0.19)
    _shape(node, "PrivateBedroomFloor", Vector3(0, -0.17, 0), Vector3(15.8, 0.32, 16.5), Color(0.67, 0.56, 0.44), true)
    _shape(node, "RearPrivateWall", Vector3(0, 2.55, -8.20), Vector3(15.8, 5.1, 0.26), cream, true)
    _shape(node, "LeftPrivateWall", Vector3(-7.75, 2.55, 0), Vector3(0.26, 5.1, 16.25), cream, true)
    _shape(node, "RightPrivateWall", Vector3(7.75, 2.55, 0), Vector3(0.26, 5.1, 16.25), cream, true)
    _shape(node, "FrontWallLeft", Vector3(-4.7, 2.55, 8.1), Vector3(6.4, 5.1, 0.25), cream, true)
    _shape(node, "FrontWallRight", Vector3(4.7, 2.55, 8.1), Vector3(6.4, 5.1, 0.25), cream, true)
    _shape(node, "DoorLintel", Vector3(0, 4.25, 8.1), Vector3(3.0, 1.6, 0.25), cream, true)
    _shape(node, "PersonalDoor", Vector3(0, 1.37, 8.2), Vector3(2.3, 2.7, 0.12), wood)
    _shape(node, "DoorHandle", Vector3(0.78, 1.22, 8.35), Vector3(0.14, 0.16, 0.1), Color(0.93, 0.74, 0.38))
    _label(node, "ROOM " + str(room_number) + " • PRIVATE", Vector3(0, 3.42, 7.88), 30)
    _label(node, hostel_name.to_upper() + " • YOUR HOME", Vector3(0, 4.1, -7.92), 27)
    # Single student's real sleeping area, not a shared dormitory bed.
    _shape(node, "BedFrame", Vector3(-4.45, 0.38, -2.2), Vector3(2.65, 0.42, 4.2), wood, true)
    _shape(node, "Mattress", Vector3(-4.45, 0.67, -2.2), Vector3(2.45, 0.24, 3.95), Color(0.96, 0.95, 0.90))
    _shape(node, "BedDuvet", Vector3(-4.45, 0.86, -1.2), Vector3(2.43, 0.16, 2.0), teal)
    _shape(node, "BedPillow", Vector3(-4.45, 0.87, -3.78), Vector3(1.7, 0.21, 0.60), Color(0.98, 0.84, 0.55))
    _shape(node, "Headboard", Vector3(-4.45, 1.0, -4.35), Vector3(2.86, 1.95, 0.18), wood)
    # Wardrobe, clothing and ordinary student personal objects.
    _shape(node, "ClothesWardrobe", Vector3(5.7, 1.6, -5.6), Vector3(2.25, 3.15, 1.35), wood, true)
    _shape(node, "WardrobeDoorA", Vector3(5.12, 1.65, -4.85), Vector3(1.0, 2.85, 0.08), cream)
    _shape(node, "WardrobeDoorB", Vector3(6.23, 1.65, -4.85), Vector3(1.0, 2.85, 0.08), cream)
    for clothes_index in range(5):
        _shape(node, "FoldedClothes", Vector3(4.75 + float(clothes_index) * 0.40, 0.20, -2.9), Vector3(0.34, 0.20, 0.63), Color(0.24 + float(clothes_index) * 0.12, 0.40, 0.61 - float(clothes_index) * 0.07))
    _table(node, Vector3(4.15, 0, 0.7), Vector3(3.0, 0, 1.55), wood, "PrivateStudyDesk")
    _seat(node, Vector3(4.15, 0, 2.0), teal, "PrivateDeskSeat")
    _shape(node, "Laptop", Vector3(4.1, 1.05, 0.6), Vector3(0.93, 0.42, 0.16), Color(0.19, 0.27, 0.32))
    _shape(node, "StudyBooks", Vector3(5.0, 0.95, 0.2), Vector3(0.63, 0.28, 0.48), Color(0.92, 0.75, 0.42))
    _shape(node, "WindowGlass", Vector3(-7.56, 2.60, -0.1), Vector3(0.08, 1.9, 3.7), Color(0.27, 0.70, 0.81))
    _shape(node, "CurtainLeft", Vector3(-7.42, 2.60, -1.75), Vector3(0.10, 2.0, 0.58), teal)
    _shape(node, "CurtainRight", Vector3(-7.42, 2.60, 1.55), Vector3(0.10, 2.0, 0.58), teal)
    _shape(node, "FramedCampusPicture", Vector3(0.7, 2.55, -8.04), Vector3(3.6, 1.7, 0.10), wood)
    _shape(node, "CampusPictureArtwork", Vector3(0.7, 2.55, -7.94), Vector3(3.25, 1.4, 0.06), Color(0.31, 0.61, 0.55))
    _shape(node, "WarmCeilingLight", Vector3(0, 4.90, 0), Vector3(3.9, 0.16, 0.7), Color(1.0, 0.92, 0.64), false, true)
    _shape(node, "PersonalRug", Vector3(0, 0.02, 1.5), Vector3(3.6, 0.05, 3.5), Color(0.32, 0.53, 0.54))
    _shape(node, "Suitcase", Vector3(-5.6, 0.43, 3.4), Vector3(1.0, 0.75, 0.55), Color(0.22, 0.24, 0.35))
    for furniture_variant in chosen_furniture:
        var furniture_name: String = str(furniture_variant)
        match furniture_name:
            "bookshelf":
                _shape(node, "OwnedBookshelf", Vector3(6.65, 1.52, 4.8), Vector3(0.9, 2.95, 2.3), wood, true)
                for i in range(3):
                    _shape(node, "OwnedBookCollection", Vector3(6.12, 0.65 + float(i) * 0.85, 4.8), Vector3(0.16, 0.4, 1.9), Color(0.24, 0.53, 0.69))
            "lamp":
                _shape(node, "OwnedBedsideLamp", Vector3(-6.45, 1.42, -2.0), Vector3(0.42, 1.28, 0.44), Color(0.99, 0.82, 0.50), false, true)
            "plant":
                _shape(node, "OwnedPlantPot", Vector3(-6.0, 0.35, 5.1), Vector3(0.75, 0.7, 0.75), Color(0.66, 0.34, 0.23))
                _shape(node, "OwnedPlantLeaves", Vector3(-6.0, 1.15, 5.1), Vector3(1.10, 1.0, 1.0), Color(0.18, 0.56, 0.34))
            "gaming_setup":
                _shape(node, "OwnedGameMonitor", Vector3(3.55, 1.35, 0.25), Vector3(1.1, 0.65, 0.12), Color(0.18, 0.28, 0.44))
                _shape(node, "OwnedConsole", Vector3(5.2, 1.01, 1.05), Vector3(0.42, 0.17, 0.5), Color(0.16, 0.19, 0.29))
            "poster":
                _shape(node, "OwnedWallPoster", Vector3(6.95, 2.55, 2.8), Vector3(0.08, 1.75, 2.1), Color(0.86, 0.49, 0.37))
    _label(node, "PERSONAL SPACE • E: ROOM MENU", Vector3(0, 2.5, 5.3), 24)
    return ROOM_BASE + Vector3(0, 0.45, 5.75)

func clear_interior() -> void:
    if current_floor != null:
        remove_child(current_floor)
        current_floor.queue_free()
        current_floor = null
    visible = false


func _action_point(parent: Node3D, action: String, title: String, at: Vector3) -> Node3D:
    var point := Node3D.new()
    point.position = at
    point.set_meta("action", action)
    point.add_to_group("campus_actions")
    parent.add_child(point)
    _shape(point, "InteractionMat", Vector3(0, 0.035, 0), Vector3(1.8, 0.04, 1.6), Color("398e83"))
    _label(point, title, Vector3(0, 2.3, 0), 22)
    return point

func show_campus_room(site: String, definition: Array, floor_index: int) -> Vector3:
    # Create an independent room with its own identity, not a facade in the lobby.
    var spawn: Vector3 = show_floor(site, str(definition[0]), floor_index)
    var theme: String = str(definition[1])
    for child in current_floor.get_children():
        current_floor.remove_child(child)
        child.queue_free()
    var accent := Color.from_hsv(float(absi((site + str(definition[0]) + str(floor_index)).hash()) % 360) / 360.0, 0.46, 0.60)
    _room_shell(current_floor, str(definition[0]), accent.lightened(0.8), accent, Color("162e3c"), theme)
    IDENTITY.new().build(self, current_floor, theme, floor_index, site, accent)
    current_floor.set_meta("room_title", str(definition[0]))
    _label(current_floor, site + " · " + str(definition[0]), Vector3(0, 3.5, -10), 30)
    var staff: Node3D = _action_point(current_floor, "staff", str(definition[2]) + " · INTERACT", Vector3(-3.5, 0, 8))
    staff.set_meta("role", str(definition[2]))
    var dialogue: String = "Welcome to " + str(definition[0]) + ". I can help you find the activities on this floor."
    if theme in ["lecture", "education", "library"]:
        dialogue += " Use the notebook point to take your own notes, and choose a practice activity below."
    elif theme in ["food", "market", "bank", "laundry"]:
        dialogue += " Prices and requirements are shown before each service. All purchases use game money."
    elif theme == "clinic":
        dialogue += " Visit the wellbeing activities below; these are fictional game services."
    staff.set_meta("dialogue", dialogue)
    _shape(staff, "StaffTorso", Vector3(0, 1.05, 0), Vector3(0.65, 0.8, 0.35), accent)
    _shape(staff, "StaffHead", Vector3(0, 1.65, 0), Vector3(0.43, 0.46, 0.4), Color("865434"))
    for xx in [-0.18, 0.18]:
        _shape(staff, "StaffLeg", Vector3(xx, 0.38, 0), Vector3(0.24, 0.75, 0.27), Color("243345"))
        _shape(staff, "StaffArm", Vector3(xx * 2.4, 1.0, 0), Vector3(0.18, 0.7, 0.25), accent.darkened(0.2))
    var object_action: String = "notes" if theme in ["lecture", "education", "library", "computing", "science", "arts", "studio"] else "tasks"
    var object_name: String = "NOTEBOOK · INTERACT" if object_action == "notes" else "SERVICE COUNTER · INTERACT"
    var point: Node3D = _action_point(current_floor, object_action, object_name, Vector3(3.5, 0, 8))
    _table(point, Vector3.ZERO, Vector3(1.8, 0, 0.9), Color("94714e"))
    _shape(point, "NotebookOrTerminal", Vector3(0, 0.91, 0), Vector3(0.6, 0.06, 0.42), Color("e7dab7"))
    _action_point(current_floor, "rooms", "LOBBY / OTHER ROOMS · INTERACT", Vector3(0, 0, 10))
    return spawn
