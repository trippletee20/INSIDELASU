# Campus ecosystem update

The supplied Lagos Life screenshots inform the compact status controls, expandable HUD and phone app grid. Inside LASU uses its own interface, names and campus content; no third-party branding or assets were extracted.

## Playable features

- HUD starts collapsed. Expand/Hide controls reveal or dismiss the objectives, meters and help footer. Phone opens LASU Connect; desktop shortcut T. Phone Size changes between a narrow handset and the available screen width. Menus pause player movement and release touch fingers.
- Places & tasks indexes all 83 configured locations, with searchable activities and an explicit entry action when nearby. A nearby action in the HUD bypasses billboard/shuttle targeting ambiguity. Completed buildings have entrance labels. The 56 existing indoor locations retain their entry rules; incomplete/unverified structures remain closed. LASU Radio retains its programme/invitation requirement.
- Each of those 56 buildings has three named room destinations per floor, selected for its identity. A room replaces the current interior, with its own room kit, palette, role NPC, service/notes object and return marker. Only one interior is allocated at a time. Private hostel accommodation remains separate.
- Rooms are stylised kits, not surveyed LASU layouts. Kits and furniture are reused across relevant rooms; this is a playable expansion, not 168 individually hand-modelled environments. The original 24 building themes remain.
- Each room adds a short daily guided decision activity on its current floor. Existing building services, jobs and decision challenges remain. These are decision-based activities, not full lecture or job simulations.
- NPC staff have role-specific welcome/service dialogue and open working activities. They are scripted service NPCs, not freeform AI people. Notes objects open a private editable notebook. Furniture seats retain sit/stand interaction.
- Third-person camera uses a sphere SpringArm to shorten camera distance against solid walls.

## Phone apps and real actions

| App | Available action |
| --- | --- |
| Places & tasks | Search locations/tasks, inspect activities, open nearby actions or map |
| Messages | Real account chat after the social service is connected; otherwise clear offline explanation |
| Contacts | Username search, nearby real players, relationship invitations, block/report |
| Notes | Create/read/delete up to 100 private titled lecture notes, 4,000 characters each |
| Study planner | Add, complete and remove up to 60 study goals |
| Courses | Shows department/level and opens study activities, planner and notes; no official course registration |
| Campus jobs | Filters existing paid activities; rewards remain fictional game money |
| Wallet | Existing balance, daily support and transaction receipts |
| My room | Hostel details, enter assigned room while in its building; existing rest/decor/privacy menu |
| Ride | Map, shuttle instructions and in-ride cabin view switching; no remote taxi booking |
| Wellbeing | Live energy/stamina/stress and links to campus services/rest |
| Skill lab | Current skill levels and practice discovery |
| Campus quiz | Three-question daily study/digital-safety quiz; saved score, no money payout |
| Societies | Persistent local interest selections; not a shared club-management system |
| Guide | Controls and game help |
| Profile | Existing student profile, academic identity and hostel details |

Phone data is added to the existing versioned browser save. Existing money, profiles and rooms are preserved. Local data does not synchronise across devices; clearing browser storage removes local progress.

## Social service: implemented, not publicly connected yet

`data/social_config.json` intentionally has an empty URL until hosting exists. The game never shows invented usernames, online counts, conversations or accepted relationships. See [SOCIAL_HOSTING.md](SOCIAL_HOSTING.md) for the prepared deployment.

When connected: unique case-insensitive usernames, scrypt password hashes, expiring bearer sessions kept only in runtime memory, search, text conversations with automatic refresh, inbox, eight mutual relationship labels, block/report and permanent social account deletion. Relationships are Friends, Dating, BFFs, Gs, Reading partners, Project teammates, Roommates and Mentor buddies. Either participant can withdraw or end a relationship.

Presence updates every few seconds and renders lightweight labelled student placeholders in the same public location/floor/room. Interact within three metres to open that player's conversation. This is a polling beta, not authoritative real-time multiplayer: avatars can jump between samples, movement is client-reported, player appearance/animations are not replicated, and there is no shared physics, group quest state or synchronised economy. Private-room presence is excluded entirely; the existing visitor setting does not grant network entry.

Messages are stored on the server and are not end-to-end encrypted. The service includes owner-only message access, request/message/invitation limits, allowed-origin checks, block enforcement and an operator moderation command. No paid ads, merchant keys or real money are added by this update.

## Validation

`python3 tools/check_environment.py` runs original gameplay/traffic checks, mobile acceptance and the new room/phone engine checks plus HTTP social-service tests. `tools/test_mobile_web.py` exercises the exported WASM on a 393×873 DPR3 touch browser and landscape; `tools/test_web.py` exercises desktop save/reload and economy. `tools/test_social_client.py` checks the real Godot HTTP client against the local social server.

Physical Android device performance and the hosted social domain still require verification after deployment. Becoming a large multiplayer campus ecosystem additionally needs production load testing, recovery/account support, richer character replication, moderation operations and much deeper original content. This release is a foundation for that work.
