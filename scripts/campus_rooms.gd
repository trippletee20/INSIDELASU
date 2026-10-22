extends RefCounted
## Each destination is its own walkable scene; only the active room is built.
const KITS: Dictionary = {
    "lecture": [["Lecture theatre", "lecture", "Course rep"], ["Seminar room", "education", "Peer tutor"], ["Staff office", "management", "Academic adviser"]],
    "science": [["Teaching laboratory", "science", "Lab technologist"], ["Research room", "computing", "Research assistant"], ["Seminar theatre", "lecture", "Peer tutor"]],
    "library": [["Silent reading room", "library", "Librarian"], ["Digital research suite", "computing", "Research assistant"], ["Study group room", "education", "Peer tutor"]],
    "hostel": [["Residents lounge", "lounge", "Hall representative"], ["Shared kitchen", "food", "Kitchen steward"], ["Laundry room", "laundry", "Laundry attendant"]],
    "law": [["Moot courtroom", "law", "Moot coordinator"], ["Law reading room", "library", "Librarian"], ["Legal clinic", "management", "Student adviser"]],
    "clinic": [["Consultation room", "clinic", "Campus nurse"], ["Pharmacy", "market", "Pharmacist"], ["Wellbeing lounge", "lounge", "Wellbeing adviser"]],
    "market": [["Campus essentials shop", "market", "Shopkeeper"], ["Print and copy studio", "computing", "Print attendant"], ["Snack corner", "food", "Food vendor"]],
    "food": [["Dining room", "food", "Food vendor"], ["Kitchen counter", "food", "Kitchen steward"], ["Student hangout", "lounge", "Hall representative"]],
    "studio": [["Recording booth", "studio", "Studio producer"], ["Editing suite", "computing", "Media tutor"], ["Interview lounge", "lounge", "Student journalist"]],
    "sports": [["Training court", "sports", "Campus coach"], ["Team changing room", "hostel", "Team captain"], ["Club meeting room", "education", "Club organiser"]],
    "arts": [["Creative studio", "arts", "Studio tutor"], ["Rehearsal room", "auditorium", "Drama coordinator"], ["Project gallery", "innovation", "Gallery steward"]],
    "bank": [["Service lounge", "bank", "Finance adviser"], ["Financial literacy room", "education", "Peer tutor"], ["Customer support", "management", "Service adviser"]],
    "transport": [["Transport desk", "transport", "Transport marshal"], ["Logistics studio", "computing", "Research assistant"], ["Driver rest lounge", "lounge", "Hall representative"]]
}
static func rooms(theme: String) -> Array:
    if KITS.has(theme):
        return KITS[theme].duplicate(true)
    return [["Main activity room", theme, "Student adviser"], ["Seminar room", "education", "Peer tutor"], ["Community lounge", "lounge", "Club organiser"]]

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
