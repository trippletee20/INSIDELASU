"""Inside LASU social beta service. Run behind HTTPS; no game-money authority."""
import hashlib
import hmac
import json
import math
import os
import re
import secrets
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

DB = os.environ.get('DATABASE_PATH', 'campus-social.sqlite3')
ORIGIN = os.environ.get('ALLOWED_ORIGIN', 'https://trippletee20.github.io')
RELATIONS = {'Dating', 'BFFs', 'Gs', 'Reading partners', 'Project teammates', 'Roommates', 'Mentor buddies', 'Friends'}
LIMITS = {}
LOCK = threading.Lock()


def connect():
    db = sqlite3.connect(DB, timeout=15)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    return db


def init():
    with connect() as db:
        db.executescript('''
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, username TEXT UNIQUE NOT NULL,
            salt TEXT NOT NULL, password TEXT NOT NULL, created REAL NOT NULL);
        CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY, user_id INTEGER REFERENCES users(id) ON DELETE CASCADE, expires REAL);
        CREATE TABLE IF NOT EXISTS presence(user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, location TEXT, x REAL, y REAL, z REAL, yaw REAL, updated REAL);
        CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY, sender INTEGER REFERENCES users(id), recipient INTEGER REFERENCES users(id), body TEXT NOT NULL, created REAL);
        CREATE INDEX IF NOT EXISTS inbox ON messages(recipient, sender, id);
        CREATE TABLE IF NOT EXISTS relations(id INTEGER PRIMARY KEY, sender INTEGER REFERENCES users(id), recipient INTEGER REFERENCES users(id), kind TEXT, status TEXT, created REAL);
        CREATE TABLE IF NOT EXISTS blocks(owner INTEGER REFERENCES users(id), target INTEGER REFERENCES users(id), PRIMARY KEY(owner,target));
        CREATE TABLE IF NOT EXISTS reports(id INTEGER PRIMARY KEY, owner INTEGER REFERENCES users(id), target INTEGER REFERENCES users(id), reason TEXT, created REAL);
        ''')


def password_hash(password, salt):
    return hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=16384, r=8, p=1).hex()


def text(value, low=1, high=1000):
    if not isinstance(value, str) or not low <= len(value.strip()) <= high or '\x00' in value:
        raise ValueError('Invalid text length')
    return value.strip()


def number(value, bound=5000):
    if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value) or abs(value) > bound:
        raise ValueError('Invalid position')
    return value


def blocked(db, me, other):
    return db.execute('SELECT 1 FROM blocks WHERE (owner=? AND target=?) OR (owner=? AND target=?)', (me, other, other, me)).fetchone() is not None


class Handler(BaseHTTPRequestHandler):
    # Tokens/passwords never go into access logs, URLs or the local game save.
    def log_message(self, *_args):
        pass

    def reply(self, code, data):
        # A client may issue its next request as soon as it receives this body.
        # Persist sessions/messages before sending success, not on context exit.
        if code < 400 and getattr(self, "db", None) is not None:
            self.db.commit()
        payload = json.dumps(data).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Access-Control-Allow-Origin', ORIGIN)
        self.send_header('Vary', 'Origin')
        self.end_headers()
        self.wfile.write(payload)

    def do_OPTIONS(self):
        if self.headers.get('Origin', ORIGIN) != ORIGIN:
            return self.reply(403, {'error': 'Origin not allowed'})
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', ORIGIN)
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type')
        self.send_header('Access-Control-Max-Age', '600')
        self.end_headers()

    def do_GET(self):
        self.handle_api('GET')

    def do_POST(self):
        self.handle_api('POST')

    def handle_api(self, method):
        self.db = None
        try:
            if self.headers.get('Origin', ORIGIN) != ORIGIN:
                return self.reply(403, {'error': 'Origin not allowed'})
            route = urlparse(self.path)
            data = {}
            if method == 'POST':
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 8192:
                    return self.reply(413, {'error': 'Request too large'})
                data = json.loads(self.rfile.read(length))
                if not isinstance(data, dict):
                    raise ValueError('Expected object')
            now = time.time()
            # Bound every client, including repeated expensive password hashing.
            # Ignore untrusted X-Forwarded-For: proxies must sanitize it before enabling it.
            ip = self.client_address[0]
            auth_route = route.path in ('/register', '/login')
            key = (ip, 'auth') if auth_route else (hashlib.sha256(self.headers.get('Authorization', ip).encode()).hexdigest(), 'api')
            with LOCK:
                window, count = LIMITS.get(key, (now, 0))
                if now - window >= 60:
                    window, count = now, 0
                LIMITS[key] = (window, count + 1)
                if len(LIMITS) > 10000:
                    for old in [k for k, v in LIMITS.items() if now - v[0] > 120]:
                        del LIMITS[old]
                if count >= (12 if auth_route else 240):
                    return self.reply(429, {'error': 'Too many requests. Wait a minute.'})
            with connect() as db:
                self.db = db
                if route.path == '/health' and method == 'GET':
                    return self.reply(200, {'status': 'ok', 'service': 'Inside LASU social beta'})
                if auth_route and method == 'POST':
                    username = text(data.get('username'), 3, 24).lower()
                    if not re.fullmatch('[a-z][a-z0-9_]{2,23}', username):
                        raise ValueError('Username: 3–24 letters, numbers or underscores; start with a letter')
                    password = text(data.get('password'), 10, 128)
                    if route.path == '/register':
                        salt = secrets.token_hex(16)
                        hashed = password_hash(password, salt)
                        try:
                            user_id = db.execute('INSERT INTO users(username,salt,password,created) VALUES(?,?,?,?)', (username, salt, hashed, now)).lastrowid
                        except sqlite3.IntegrityError:
                            return self.reply(409, {'error': 'Username unavailable'})
                    else:
                        user = db.execute('SELECT * FROM users WHERE username=?', (username,)).fetchone()
                        salt = user['salt'] if user else '00' * 16
                        candidate = password_hash(password, salt)
                        if not user or not hmac.compare_digest(candidate, user['password']):
                            return self.reply(401, {'error': 'Incorrect username or password'})
                        user_id = user['id']
                    token = secrets.token_urlsafe(32)
                    db.execute('DELETE FROM sessions WHERE expires<?', (now,))
                    db.execute('INSERT INTO sessions VALUES(?,?,?)', (hashlib.sha256(token.encode()).hexdigest(), user_id, now + 86400))
                    return self.reply(200, {'token': token, 'username': username})
                auth = self.headers.get('Authorization', '')
                token = auth[7:] if auth.startswith('Bearer ') else ''
                user = db.execute('SELECT u.id,u.username FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token=? AND s.expires>?', (hashlib.sha256(token.encode()).hexdigest(), now)).fetchone()
                if not user:
                    return self.reply(401, {'error': 'Sign in to your social account'})
                me = user['id']
                if route.path == '/logout' and method == 'POST':
                    db.execute('DELETE FROM sessions WHERE token=?', (hashlib.sha256(token.encode()).hexdigest(),))
                    db.execute('DELETE FROM presence WHERE user_id=?', (me,))
                    return self.reply(200, {'ok': True})
                if route.path == '/account/delete' and method == 'POST':
                    for table, condition in [('messages', 'sender=? OR recipient=?'), ('relations', 'sender=? OR recipient=?'), ('blocks', 'owner=? OR target=?'), ('reports', 'owner=? OR target=?')]:
                        db.execute(f'DELETE FROM {table} WHERE {condition}', (me, me))
                    db.execute('DELETE FROM users WHERE id=?', (me,))
                    return self.reply(200, {'ok': True})
                if route.path == '/presence' and method == 'POST':
                    location = text(data.get('location'), 1, 160)
                    # Never publish private-room coordinates/presence to other players.
                    if location.startswith('private:'):
                        db.execute('DELETE FROM presence WHERE user_id=?', (me,))
                    else:
                        coords = [number(data.get(k, 0)) for k in ('x', 'y', 'z', 'yaw')]
                        db.execute('INSERT OR REPLACE INTO presence VALUES(?,?,?,?,?,?,?)', (me, location, *coords, now))
                    peers = [dict(r) for r in db.execute('SELECT u.username,p.* FROM presence p JOIN users u ON u.id=p.user_id WHERE p.location=? AND p.updated>? AND u.id!=? LIMIT 50', (location, now - 25, me)) if not blocked(db, me, r['user_id'])]
                    return self.reply(200, {'peers': peers})
                if route.path == '/users' and method == 'GET':
                    query = parse_qs(route.query).get('q', [''])[0].lower()
                    if not re.fullmatch('[a-z0-9_]{2,24}', query):
                        raise ValueError('Search with at least two username characters')
                    rows = db.execute('SELECT id,username FROM users WHERE instr(username,?)>0 AND id!=? ORDER BY username LIMIT 20', (query, me)).fetchall()
                    return self.reply(200, {'users': [{'username': r['username']} for r in rows if not blocked(db, me, r['id'])]})
                if route.path == '/blocks' and method == 'GET':
                    rows = db.execute('SELECT u.username FROM blocks b JOIN users u ON u.id=b.target WHERE b.owner=? ORDER BY u.username', (me,)).fetchall()
                    return self.reply(200, {'users': [dict(r) for r in rows]})
                if route.path == '/inbox' and method == 'GET':
                    names = db.execute('SELECT DISTINCT u.username,u.id FROM users u JOIN messages m ON (m.sender=u.id AND m.recipient=?) OR (m.recipient=u.id AND m.sender=?) ORDER BY u.username LIMIT 100', (me, me)).fetchall()
                    rels = db.execute('SELECT r.*,a.username sender_name,b.username recipient_name FROM relations r JOIN users a ON a.id=r.sender JOIN users b ON b.id=r.recipient WHERE (r.sender=? OR r.recipient=?) AND r.status IN (\'pending\',\'accepted\') ORDER BY r.id DESC LIMIT 100', (me, me)).fetchall()
                    return self.reply(200, {'username': user['username'], 'threads': [{'username': r['username']} for r in names if not blocked(db, me, r['id'])], 'relationships': [dict(r) for r in rels if not blocked(db, me, r['recipient'] if r['sender'] == me else r['sender'])]})
                if route.path == '/relationship/respond' and method == 'POST':
                    rel_id = data.get('id')
                    status = data.get('status')
                    if not isinstance(rel_id, int) or status not in ('accepted', 'declined', 'ended'):
                        raise ValueError('Invalid relationship response')
                    rel = db.execute('SELECT * FROM relations WHERE id=?', (rel_id,)).fetchone()
                    if not rel or me not in (rel['sender'], rel['recipient']):
                        return self.reply(404, {'error': 'Request not found'})
                    if status != 'ended' and (me != rel['recipient'] or rel['status'] != 'pending'):
                        return self.reply(403, {'error': 'Only the recipient can accept a pending invitation'})
                    if blocked(db, rel['sender'], rel['recipient']):
                        return self.reply(403, {'error': 'Contact unavailable'})
                    db.execute('UPDATE relations SET status=? WHERE id=?', (status, rel_id))
                    return self.reply(200, {'ok': True})
                if route.path in ('/messages', '/relationship', '/block', '/unblock', '/report'):
                    target_name = (parse_qs(route.query).get('to', [''])[0] if method == 'GET' else data.get('to', ''))
                    target = db.execute('SELECT id FROM users WHERE username=?', (text(target_name, 3, 24).lower(),)).fetchone()
                    if not target or target['id'] == me:
                        return self.reply(404, {'error': 'Player not found'})
                    other = target['id']
                    if route.path == '/unblock' and method == 'POST':
                        db.execute('DELETE FROM blocks WHERE owner=? AND target=?', (me, other))
                        return self.reply(200, {'ok': True})
                    if route.path == '/block' and method == 'POST':
                        db.execute('INSERT OR IGNORE INTO blocks VALUES(?,?)', (me, other))
                        db.execute("UPDATE relations SET status='ended' WHERE (sender=? AND recipient=?) OR (sender=? AND recipient=?)", (me, other, other, me))
                        return self.reply(200, {'ok': True})
                    if route.path == '/report' and method == 'POST':
                        db.execute('INSERT INTO reports(owner,target,reason,created) VALUES(?,?,?,?)', (me, other, text(data.get('reason'), 5, 500), now))
                        return self.reply(200, {'ok': True})
                    if blocked(db, me, other):
                        return self.reply(403, {'error': 'Contact unavailable'})
                    if route.path == '/messages' and method == 'GET':
                        rows = db.execute('SELECT m.id,u.username sender,m.body,m.created FROM messages m JOIN users u ON u.id=m.sender WHERE (m.sender=? AND m.recipient=?) OR (m.sender=? AND m.recipient=?) ORDER BY m.id DESC LIMIT 80', (me, other, other, me)).fetchall()
                        return self.reply(200, {'messages': [dict(r) for r in reversed(rows)]})
                    if route.path == '/messages' and method == 'POST':
                        body = text(data.get('body'), 1, 1000)
                        recent = db.execute('SELECT COUNT(*) FROM messages WHERE sender=? AND created>?', (me, now - 60)).fetchone()[0]
                        if recent >= 20:
                            return self.reply(429, {'error': 'Message limit reached. Wait a minute.'})
                        db.execute('INSERT INTO messages(sender,recipient,body,created) VALUES(?,?,?,?)', (me, other, body, now))
                        return self.reply(200, {'ok': True})
                    if route.path == '/relationship' and method == 'POST':
                        kind = data.get('kind')
                        if kind not in RELATIONS:
                            raise ValueError('Unknown relationship type')
                        if db.execute("SELECT 1 FROM relations WHERE ((sender=? AND recipient=?) OR (sender=? AND recipient=?)) AND status IN ('pending','accepted') AND kind=?", (me, other, other, me, kind)).fetchone():
                            return self.reply(409, {'error': 'This relationship already exists or is pending'})
                        if db.execute('SELECT COUNT(*) FROM relations WHERE sender=? AND created>?', (me, now - 3600)).fetchone()[0] >= 20:
                            return self.reply(429, {'error': 'Invitation limit reached'})
                        db.execute("INSERT INTO relations(sender,recipient,kind,status,created) VALUES(?,?,?,'pending',?)", (me, other, kind, now))
                        return self.reply(200, {'ok': True})
                return self.reply(404, {'error': 'Endpoint not found'})
        except (ValueError, TypeError, json.JSONDecodeError):
            self.reply(400, {'error': 'Invalid request. Check the field lengths and values.'})
        except sqlite3.Error:
            self.reply(503, {'error': 'Service busy. Try again shortly.'})
        finally:
            if self.db is not None:
                self.db.close()
                self.db = None


if __name__ == '__main__':
    init()
    ThreadingHTTPServer(('0.0.0.0', int(os.environ.get('PORT', '8080'))), Handler).serve_forever()
