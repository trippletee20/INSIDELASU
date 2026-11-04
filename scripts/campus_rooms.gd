extends RefCounted
## Each destination is its own walkable scene; only the active room is built.
static var npc_data: Dictionary = {}
static func data() -> Dictionary:
    if npc_data.is_empty(): npc_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/npc_life.json"))
    return npc_data

static func rooms(theme: String) -> Array:
    var definitions: Dictionary = data()
    if definitions.room_kits.has(theme): return definitions.room_kits[theme].duplicate(true)
    var result: Array = definitions.default_rooms.duplicate(true)
    result[0][1] = theme
    return result

static func for_site(site: String, designs: Dictionary) -> Array:
    return rooms(str(designs.get(site, {}).get("theme", "lecture")))

static func activity(site: String, definition: Array, room_index: int, floor_index: int) -> Dictionary:
    var theme: String = str(definition[1])
    var question: String = "What helps a campus group work well?"
    var options: Array = ["Agree on roles and listen to each other", "Leave all work to one person", "Ignore the agreed plan"]
    match theme:
        "lecture", "education", "library":
            question = "After this study session, what helps you remember the ideas?"
            options = ["Summarise in your own words and test recall", "Only photograph the board", "Avoid revisiting the topic"]
        "science", "computing", "innovation":
            question = "Before starting practical work, what should you do?"
            options = ["Read the instructions and check your setup", "Change every setting at random", "Ignore unexpected results"]
        "food", "market", "bank", "laundry":
            question = "Before confirming a service, what should you check?"
            options = ["The item, price and service details", "Only the vendor's outfit", "Nothing until after paying"]
        "clinic", "sports":
            question = "You feel unwell during an activity. What is a sensible next step?"
            options = ["Stop, rest and ask appropriate staff for help", "Push through every symptom", "Use another person's medicine"]
        "law", "civic", "management":
            question = "Before advising a student on a dispute, what comes first?"
            options = ["Hear the facts and check the relevant rules", "Promise a result without details", "Share their private story publicly"]
        "arts", "studio", "auditorium":
            question = "Before publishing collaborative creative work, what matters?"
            options = ["Get permission and credit contributors", "Use everyone's work without credit", "Publish private recordings without asking"]
    return {"id": "room_practice_" + str(floor_index) + "_" + str(room_index), "title": str(definition[0]) + " · guided practice", "description": "Complete a short practical decision with the room's staff.", "kind": "academic", "cost": 0, "reward": 0, "once_daily": true, "skill": "intellect", "energy_cost": 2, "floor": floor_index, "challenge": [{"prompt": question, "options": options, "answer": 0}], "success": "Room practice completed at " + site + "."}
