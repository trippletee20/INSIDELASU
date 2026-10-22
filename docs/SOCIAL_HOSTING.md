# Connect real-player social features

The browser game continues to run on GitHub Pages. Pages cannot host a database or messaging process. The repository now includes a separate Python social server and a Render Blueprint with a persistent disk.

## One-time hosting action

1. Create/sign in to a Render account and open [Deploy this repository](https://render.com/deploy?repo=https://github.com/trippletee20/INSIDELASU).
2. Select the repository's `render.yaml` Blueprint. Review Render's displayed price before creating resources. The configured `starter` web service and 1 GB persistent disk are paid resources; nothing has been purchased or provisioned by Codex. A free ephemeral disk would lose accounts/messages on restart, so it is not configured here.
3. Render builds `server/Dockerfile`, attaches `/data`, runs the service and checks `/health`. Default allowed browser origin is `https://trippletee20.github.io` (no `/INSIDELASU` path). Keep it exact; update it if using a custom domain.
4. Send the public `https://…onrender.com` service URL to Codex. Do not send passwords, API keys or database contents. Codex can verify it and connect the game with `python3 tools/configure_social_server.py https://YOUR-SERVICE.onrender.com`, then rebuild, test and push.
5. Test with two separate browsers/accounts: search username, send/reply, accept/decline/end relationship, see public-room presence, block/report, delete a test account. Private hostel rooms must not show other players.

Only after step 4 is deployed will the game's Messages/Contacts apps expose account sign-in. Existing local game profiles are not social accounts and are not automatically assigned public usernames.

## Operator responsibilities for a beta

- Use HTTPS through the hosting platform. The server's HTTP port stays behind that proxy.
- Keep the persistent disk and take regular SQLite backups (`sqlite3.Connection.backup`); never commit the database.
- Review reports from the hosting shell: `python moderate.py reports`. Remove a message with `python moderate.py remove-message MESSAGE_ID`; suspend an account with `python moderate.py suspend username`. No public administrator endpoint is exposed.
- Messages and reports contain player data. Publish a privacy notice/contact before inviting a broad audience; the service provides social account deletion, but no email/password recovery yet. Password sessions expire after 24 hours and are deliberately not persisted in the browser save.
- The small service stores up to 80 messages per conversation response and 50 same-location presence entries per response; storage retention/archival remains an operator task. It does not implement push notifications, attachments, voice calls, read receipts, public chat channels or WhatsApp integration.
- This SQLite/polling configuration is a small beta deployment. Load test and move to a managed database and websocket gateway before promising large concurrent crowds. IP-based login limits may be shared behind a reverse proxy; tune carefully using trusted proxy metadata, never arbitrary client headers.

## Local verification

```
python3 server/test_app.py
python3 tools/test_social_client.py
DATABASE_PATH=/tmp/inside-lasu-social-test.sqlite3 PORT=8080 python3 server/app.py
```

For a local web test set `ALLOWED_ORIGIN` to that web test's exact origin. The shipped game accepts only HTTPS service URLs, with a loopback exception for automated local tests. No merchant credentials or real payment processing belongs in this server.
