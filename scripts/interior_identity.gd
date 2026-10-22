extends RefCounted
## Stylised campus identities, deliberately not replicas of real floor plans.
var b: Node3D
var room: Node3D
var accent: Color
var wood := Color("865d3c")
var metal := Color("344652")

func box(title: String, at: Vector3, size: Vector3, color: Color, solid: bool = false) -> void:
    var blocks: bool = solid or title in ["LibraryShelving", "JudgeBench", "WitnessStand", "SafetyCabinet", "ConsultationBed", "TriageCounter", "TeamLocker", "WashingMachine", "ServiceStall", "RecordsCabinet", "ReceptionCounter", "PrototypeDisplay"]
    b._shape(room, title, at, size, color, blocks)

func sign_text(text: String, at: Vector3, size: int = 26) -> void:
    b._label(room, text, at, size)

func seat(at: Vector3, color: Color = Color("397777")) -> void:
    b._seat(room, at, color, "UsableSeat")

func table(at: Vector3, size: Vector3 = Vector3(3, 0, 1.5)) -> void:
    b._table(room, at, size, wood)

func screen(at: Vector3, title: String = "Display") -> void:
    box(title, at, Vector3(1.0, 0.65, 0.12), metal)
    box("ScreenGlow", at + Vector3(0, 0, 0.07), Vector3(0.85, 0.49, 0.02), accent.lightened(0.25))

func build(builder: Node3D, node: Node3D, theme: String, floor_index: int, site: String, color: Color) -> void:
    b = builder
    room = node
    accent = color
    room.set_meta("interior_theme", theme)
    room.set_meta("floor_index", floor_index)
    match theme:
        "hostel":
            b._hostel_rooms(room, floor_index, accent, wood)
            sign_text("RESIDENTS' LOUNGE • QUIET HOURS", Vector3(0, 2.7, 5.0))
        "lounge":
            for xx in [-9, 9]:
                table(Vector3(xx, 0, -4), Vector3(3.4, 0, 2.0))
                for zz in [-6, -1]:
                    box("ClubSofaSeat", Vector3(xx, 0.48, zz), Vector3(4.5, 0.4, 1.3), accent)
                    box("ClubSofaBack", Vector3(xx, 1, zz - 0.6), Vector3(4.5, 1.25, 0.25), accent.darkened(0.2))
            box("CommunityNoticeboard", Vector3(0, 2, -11.9), Vector3(7, 2.4, 0.1), wood)
            for i in range(4):
                box("CommunityNotice", Vector3(-2.2 + i * 1.5, 2, -11.8), Vector3(1, 1.6, 0.04), Color("e5d8ad"))
            table(Vector3(0, 0, 5), Vector3(5, 0, 2.5))
            sign_text("STAFF CLUB • LOUNGE & COMMUNITY", Vector3(0, 3.5, -10.8))
        "library":
            # A broad central reading hall with peripheral shelving, no corridor walls.
            for side in [-1, 1]:
                for row in range(3):
                    var at := Vector3(side * 11.0, 1.65, -7.5 + row * 5.0)
                    box("LibraryShelving", at, Vector3(2.1, 3.2, 3.2), wood)
                    for shelf in range(3):
                        for book in range(5):
                            box("IndividualBook", at + Vector3(-0.8 + book * 0.38, -0.9 + shelf * 0.85, 1.65), Vector3(0.25, 0.58, 0.14), Color.from_hsv(float((book + row + floor_index) % 8) / 8.0, 0.52, 0.77))
            for xx in [-4.8, 4.8]:
                for zz in [-6.5, 0.0]:
                    table(Vector3(xx, 0, zz), Vector3(4.0, 0, 2.0))
                    seat(Vector3(xx - 1.1, 0, zz + 1.6), accent)
                    seat(Vector3(xx + 1.1, 0, zz + 1.6), accent)
            box("LendingDesk", Vector3(-7, 0.8, 7.5), Vector3(6, 1.6, 1.5), accent)
            sign_text(["LENDING & CATALOGUE", "SILENT READING", "GROUP RESEARCH", "REFERENCE COLLECTION"][floor_index % 4], Vector3(0, 2.8, -9.6))
        "law":
            box("JudgeDais", Vector3(0, 0.18, -8.5), Vector3(12, 0.36, 5), wood)
            box("JudgeBench", Vector3(0, 1.0, -9), Vector3(8, 1.9, 1.1), wood)
            for xx in [-5.7, 5.7]:
                table(Vector3(xx, 0, -2.5), Vector3(4.2, 0, 1.8))
                seat(Vector3(xx, 0, -0.8), accent)
            for xx in [-8, 8]:
                for zz in [3, 6]:
                    box("PublicGallerySeat", Vector3(xx, 0.5, zz), Vector3(5.4, 0.8, 1.2), wood)
            sign_text("MOOT COURT • ARGUMENT • EVIDENCE", Vector3(0, 3.5, -11.7))
            box("WitnessStand", Vector3(8.5, 0.9, -7.8), Vector3(2.4, 1.8, 2), accent)
        "science":
            for xx in [-8, 8]:
                for zz in [-6, 0, 6]:
                    table(Vector3(xx, 0, zz), Vector3(5, 0, 2.0))
                    box("LabWorktop", Vector3(xx, 0.9, zz), Vector3(5, 0.12, 2), metal)
                    box("MicroscopeBase", Vector3(xx - 1, 1.08, zz), Vector3(0.6, 0.2, 0.6), Color("dce5df"))
                    box("MicroscopeStand", Vector3(xx - 1, 1.42, zz), Vector3(0.18, 0.65, 0.2), metal)
                    for i in range(3):
                        box("SampleTube", Vector3(xx + 0.3 + i * 0.35, 1.15, zz), Vector3(0.17, 0.5, 0.17), accent.lightened(i * 0.1))
                    seat(Vector3(xx, 0, zz + 1.6), accent)
            sign_text("TEACHING LAB • OBSERVE • RECORD • EXPLAIN", Vector3(0, 3.4, -11.7))
            box("SafetyCabinet", Vector3(0, 1.3, -10.7), Vector3(3, 2.6, 0.8), Color("d69e3e"))
        "studio":
            for i in range(8):
                box("AcousticPanel", Vector3(-12.5 + i * 3.5, 2.3, -12.08), Vector3(2.2, 2.8, 0.16), metal if i % 2 == 0 else accent)
            table(Vector3(-7, 0, -4), Vector3(6, 0, 2.2))
            for i in range(6):
                box("MixerFader", Vector3(-9.2 + i * 0.85, 0.95, -4), Vector3(0.42, 0.1, 1.2), accent)
            screen(Vector3(-7, 1.5, -5.0), "ProductionMonitor")
            table(Vector3(7, 0, -3), Vector3(4, 0, 2.2))
            for xx in [6, 8]:
                box("MicrophoneStand", Vector3(xx, 1.3, -3), Vector3(0.07, 0.9, 0.07), metal)
                box("Microphone", Vector3(xx, 1.78, -3), Vector3(0.22, 0.3, 0.22), Color("e7e6dc"))
                seat(Vector3(xx, 0, -1), accent)
            box("StudioCamera", Vector3(6, 1.9, 5), Vector3(0.9, 0.6, 0.9), metal)
            box("Tripod", Vector3(6, 0.9, 5), Vector3(0.15, 1.5, 0.15), metal)
            sign_text("ON AIR • RECORDING & PRODUCTION", Vector3(0, 3.4, -11.7))
        "clinic":
            for xx in [-9, 9]:
                for zz in [-7, 0]:
                    box("ConsultationBed", Vector3(xx, 0.7, zz), Vector3(2.5, 1.1, 3.2), Color("e5eee9"))
                    box("PrivacyCurtain", Vector3(xx + 2.1, 2.0, zz), Vector3(0.12, 3.0, 3.5), accent.lightened(0.35))
            box("TriageCounter", Vector3(-8, 0.8, 6.5), Vector3(5.5, 1.6, 1.4), accent)
            for x in [7, 9, 11]:
                seat(Vector3(x, 0, 6), accent)
            sign_text("RECEPTION → TRIAGE → CONSULTATION", Vector3(0, 3, -5))
        "sports":
            box("IndoorCourt", Vector3(0, 0.02, -2), Vector3(19, 0.03, 16), Color("b78954"))
            for x in [-9.0, 0.0, 9.0]:
                box("CourtMarking", Vector3(x, 0.05, -2), Vector3(0.08, 0.02, 16), Color.WHITE)
            for z in [-10.0, 6.0]:
                box("CourtMarking", Vector3(0, 0.05, z), Vector3(18, 0.02, 0.08), Color.WHITE)
            for i in range(5):
                box("TeamLocker", Vector3(-12.5, 1.4, -8 + i * 3), Vector3(1.2, 2.8, 2), accent)
                box("TrainingMat", Vector3(12, 0.08, -8 + i * 3), Vector3(2, 0.15, 2.2), accent)
            sign_text("TRAIN • RECOVER • TEAMWORK", Vector3(0, 3.4, -11.7))
        "auditorium", "chapel":
            box("RaisedStage", Vector3(0, 0.35, -9), Vector3(22, 0.7, 5), wood)
            box("StageBackdrop", Vector3(0, 2.4, -12.08), Vector3(20, 4, 0.1), accent)
            box("Lectern", Vector3(0, 1.2, -8), Vector3(1.3, 1.7, 1), wood)
            for row in range(4):
                for xx in [-10, -7, -4, 4, 7, 10]:
                    seat(Vector3(xx, 0, -3 + row * 3), accent)
            sign_text("REFLECTION & COMMUNITY" if theme == "chapel" else "PERFORMANCE • SPEAKING • EVENTS", Vector3(0, 3.7, -11.7))
        "laundry":
            for xx in [-10, 10]:
                for zz in [-7, -2, 3]:
                    box("WashingMachine", Vector3(xx, 0.9, zz), Vector3(2.5, 1.8, 2.5), Color("e4e7dc"))
                    box("MachineDrum", Vector3(xx, 0.9, zz + 1.28), Vector3(1.5, 1.2, 0.1), metal)
                    box("MachineControls", Vector3(xx, 1.55, zz + 1.29), Vector3(1.7, 0.22, 0.1), accent)
            table(Vector3(0, 0, -4), Vector3(7, 0, 3))
            box("FoldingLaundry", Vector3(0, 1, -4), Vector3(2, 0.35, 1.3), accent)
            sign_text("SORT • WASH • FOLD • COLLECT", Vector3(0, 3.4, -11.7))
        "food", "market", "arcade", "bank":
            for side in [-1, 1]:
                for row in range(3):
                    var at := Vector3(side * 9, 0, -7 + row * 5)
                    box("ServiceStall", at + Vector3(0, 0.8, 0), Vector3(5, 1.6, 1.5), wood)
                    box("StallAwning", at + Vector3(0, 2.8, 0), Vector3(5.6, 0.18, 2.0), accent)
                    match theme:
                        "food":
                            box("ServingTray", at + Vector3(0, 1.7, 0), Vector3(2.8, 0.18, 0.8), metal)
                            for i in range(3):
                                box("FoodBowl", at + Vector3(-1 + i, 1.9, 0), Vector3(0.65, 0.26, 0.65), Color("dca954"))
                        "market":
                            for i in range(4):
                                box("MarketStock", at + Vector3(-1.6 + i, 1.9, 0), Vector3(0.65, 0.55, 0.65), Color.from_hsv(i * 0.2, 0.6, 0.8))
                        "arcade":
                            screen(at + Vector3(0, 2, 0), "GameCabinetScreen")
                            box("GameControlDeck", at + Vector3(0, 1.4, 0.9), Vector3(2.8, 0.25, 0.7), metal)
                        "bank":
                            screen(at + Vector3(0, 2, 0), "BankTerminal")
                            box("ATMKeypad", at + Vector3(0, 1.7, 0.85), Vector3(0.6, 0.1, 0.4), metal)
            sign_text({"food": "CAMPUS KITCHEN • COUNTER SERVICE", "market": "STUDENT MARKET • BROWSE & TRADE", "arcade": "GAMES • STUDENT UNION • CHAMBER", "bank": "STUDENT FINANCE • SERVICE DESKS"}[theme], Vector3(0, 3.4, -11.7))
        _:
            _faculty(theme, floor_index, site)

func _faculty(theme: String, floor_index: int, site: String) -> void:
    match theme:
        "innovation", "computing":
            for xx in [-8, 8]:
                for zz in [-6, 0, 6]:
                    table(Vector3(xx, 0, zz), Vector3(5, 0, 1.8))
                    for x in [-1.3, 1.3]:
                        screen(Vector3(xx + x, 1.25, zz - 0.4), "Workstation")
                        seat(Vector3(xx + x, 0, zz + 1.5), accent)
            box("PrototypeDisplay", Vector3(0, 1, -9), Vector3(3, 2, 2), accent)
        "arts":
            for xx in [-9, 9]:
                for zz in [-6, 0, 6]:
                    box("Easel", Vector3(xx, 1.0, zz), Vector3(0.14, 2, 0.16), wood)
                    box("ArtCanvas", Vector3(xx, 1.8, zz), Vector3(2.5, 1.8, 0.12), Color("f0dfb4"))
                    box("StudentArtwork", Vector3(xx, 1.8, zz + 0.08), Vector3(1.7, 1, 0.06), accent)
            box("RehearsalPlatform", Vector3(0, 0.15, -8.5), Vector3(5, 0.3, 3), wood)
        "transport":
            for xx in [-8, 8]:
                table(Vector3(xx, 0, -4), Vector3(6, 0, 4))
                for i in range(4):
                    box("ModelRoad", Vector3(xx, 0.9, -5.5 + i), Vector3(5.4, 0.04, 0.5), metal)
                    box("ModelVehicle", Vector3(xx - 1.6 + i, 1.08, -5.5 + i), Vector3(0.8, 0.3, 0.4), accent)
                seat(Vector3(xx, 0, 0), accent)
            box("RoutePlanningBoard", Vector3(0, 2.1, -11.9), Vector3(10, 2.6, 0.1), accent)
        "civic", "management":
            table(Vector3(0, 0, -4), Vector3(10, 0, 3.4))
            for xx in [-4, -1.4, 1.4, 4]:
                seat(Vector3(xx, 0, -1.5), accent)
                seat(Vector3(xx, 0, -6.5), accent)
            box("ReceptionCounter", Vector3(-9, 0.9, 7), Vector3(5, 1.8, 1.3), wood)
            for i in range(4):
                box("RecordsCabinet", Vector3(8 + i * 1.3, 1.6, -9), Vector3(1, 3.2, 1), accent)
        _:
            for xx in [-9, 9]:
                for zz in [-5, 0, 5]:
                    table(Vector3(xx, 0, zz), Vector3(4, 0, 1.6))
                    seat(Vector3(xx - 1, 0, zz + 1.4), accent)
                    seat(Vector3(xx + 1, 0, zz + 1.4), accent)
                box("TeachingBoard", Vector3(xx, 2.2, -10.8), Vector3(6, 2.1, 0.1), Color("244c42"))
            if theme == "education":
                for i in range(4):
                    box("LearningResource", Vector3(-12 + i * 1.6, 1, 8.5), Vector3(1, 2, 0.7), Color.from_hsv(i * 0.19, 0.5, 0.8))
            elif theme == "social":
                box("SurveyDisplay", Vector3(0, 2.1, -11.9), Vector3(5, 2.3, 0.1), accent)
    sign_text(site.to_upper() + "\n" + ["DISCOVER & PRACTISE", "WORKSHOP & COLLABORATION", "PROJECTS & CONSULTATION"][floor_index % 3], Vector3(0, 3.3, -10.5), 22)
