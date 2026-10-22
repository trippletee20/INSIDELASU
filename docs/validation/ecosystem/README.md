# Campus ecosystem validation

The game export passed Chromium desktop and mobile touch emulation (393×873 DPR3 and landscape), including save/reload, actual movement, phone → wallet transitions, map and zero captured errors. These results do not certify a physical Android device.

`engine.log` records original gameplay/traffic checks plus 1,065 new ecosystem assertions and 15 real Godot social-client assertions. `phone-rooms-final.log` repeats the room/phone checks after deferring phone button transitions outside the touch event. The room traversal covers 165 destinations in the 55 unrestricted indoor buildings; LASU Radio retains its existing programme/invitation access rule.

`social-service.log` exercises three real HTTP accounts, message isolation, relationship consent, blocking/unblocking, reporting, deletion, malformed input, CORS and immediately usable committed sessions. `social-client.log` connects actual Godot HTTP clients, renders the conversation, and creates a nearby player placeholder. `social-container.log` verifies an initially empty mounted persistent volume, a server running without root privileges, and accounts/messages surviving container restart.

The social server is not publicly hosted or configured in the game. The prepared Render service requires the owner's hosting account; no resources have been purchased. See ../../SOCIAL_HOSTING.md.
