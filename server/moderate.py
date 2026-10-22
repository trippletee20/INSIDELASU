"""Operator access over the hosting shell only. No public admin endpoint."""
import argparse
import json
import app

parser = argparse.ArgumentParser()
parser.add_argument('action', choices=['reports', 'remove-message', 'suspend'])
parser.add_argument('value', nargs='?')
args = parser.parse_args()
app.init()
with app.connect() as db:
    if args.action == 'reports':
        for row in db.execute('SELECT r.id,a.username reporter,b.username reported,r.reason,r.created FROM reports r JOIN users a ON a.id=r.owner JOIN users b ON b.id=r.target ORDER BY r.id DESC LIMIT 100'):
            print(json.dumps(dict(row)))
    elif args.action == 'remove-message':
        if not args.value or not args.value.isdigit():
            parser.error('Supply a message ID')
        db.execute('DELETE FROM messages WHERE id=?', (int(args.value),))
        print('Message removed')
    else:
        user = db.execute('SELECT id FROM users WHERE username=?', (args.value,)).fetchone()
        if not user:
            parser.error('Username not found')
        # A suspension invalidates all sessions and prevents further sign-in.
        db.execute('DELETE FROM sessions WHERE user_id=?', (user['id'],))
        db.execute('DELETE FROM presence WHERE user_id=?', (user['id'],))
        db.execute("UPDATE users SET password='suspended' WHERE id=?", (user['id'],))
        print('Account suspended; existing reports retained')
