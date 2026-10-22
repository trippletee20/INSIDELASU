"""Two/three real HTTP clients exercise privacy, auth, persistence and mutual consent."""
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

spec = importlib.util.spec_from_file_location('campus_service', Path(__file__).with_name('app.py'))
app = importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)


class SocialTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        app.DB = str(Path(cls.temp.name) / 'social.sqlite3')
        app.init()
        cls.server = ThreadingHTTPServer(('127.0.0.1', 0), app.Handler)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.base = f'http://127.0.0.1:{cls.server.server_port}'

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.temp.cleanup()

    def api(self, path, payload=None, token='', origin=app.ORIGIN):
        req = urllib.request.Request(self.base + path, data=None if payload is None else json.dumps(payload).encode(), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'Origin': origin})
        try:
            response = urllib.request.urlopen(req, timeout=10)
        except urllib.error.HTTPError as error:
            response = error
        return response.status, json.load(response)

    def test_full_two_player_flow(self):
        def register(name):
            code, reply = self.api('/register', {'username': name, 'password': 'distinct-test-password'})
            self.assertEqual(code, 200, reply)
            return reply['token']
        alice, bob, eve = [register(n) for n in ('alice', 'bob', 'eve')]
        self.assertEqual(self.api('/login', {'username': 'alice', 'password': 'wrong-password'})[0], 401)
        for _ in range(3):
            code, session = self.api('/login', {'username': 'alice', 'password': 'distinct-test-password'})
            self.assertEqual(code, 200)
            self.assertEqual(self.api('/inbox', token=session['token'])[0], 200)
        self.assertEqual(self.api('/users?q=bo', token=alice)[1]['users'], [{'username': 'bob'}])
        self.assertEqual(self.api('/users?q=bo', token='invalid')[0], 401)
        self.assertEqual(self.api('/users?q=bo', token=alice, origin='https://evil.example')[0], 403)
        self.assertEqual(self.api('/messages', {'to': 'bob', 'body': 'Study together? <b>literal text</b>'}, alice)[0], 200)
        self.assertEqual(self.api('/messages?to=alice', token=bob)[1]['messages'][0]['body'], 'Study together? <b>literal text</b>')
        self.assertEqual(self.api('/messages?to=alice', token=eve)[1]['messages'], [])
        self.assertEqual(self.api('/messages', {'to': 'bob', 'body': 'x' * 1001}, alice)[0], 400)
        self.assertEqual(self.api('/relationship', {'to': 'bob', 'kind': 'Reading partners'}, alice)[0], 200)
        rel = self.api('/inbox', token=bob)[1]['relationships'][0]
        self.assertEqual(rel['status'], 'pending')
        self.assertEqual(self.api('/relationship/respond', {'id': rel['id'], 'status': 'accepted'}, alice)[0], 403)
        self.assertEqual(self.api('/relationship/respond', {'id': rel['id'], 'status': 'accepted'}, eve)[0], 404)
        self.assertEqual(self.api('/relationship/respond', {'id': rel['id'], 'status': 'accepted'}, bob)[0], 200)
        self.assertEqual(self.api('/inbox', token=alice)[1]['relationships'][0]['status'], 'accepted')
        position = {'location': 'library:0:1', 'x': 900, 'y': 1, 'z': 2, 'yaw': 0}
        self.api('/presence', position, alice)
        peers = self.api('/presence', position, bob)[1]['peers']
        self.assertEqual(peers[0]['username'], 'alice')
        self.api('/presence', dict(position, location='private:hostel:42'), alice)
        self.assertEqual(self.api('/presence', position, bob)[1]['peers'], [])
        self.assertEqual(self.api('/presence', dict(position, x=float('nan')), alice)[0], 400)
        # New DB connection still reads actual messages; this is not an in-memory mock.
        app.init()
        self.assertEqual(len(self.api('/messages?to=alice', token=bob)[1]['messages']), 1)
        self.assertEqual(self.api('/report', {'to': 'alice', 'reason': 'Test report for moderation'}, bob)[0], 200)
        self.assertEqual(self.api('/block', {'to': 'alice'}, bob)[0], 200)
        self.assertEqual(self.api('/messages', {'to': 'bob', 'body': 'blocked'}, alice)[0], 403)
        self.assertEqual(self.api('/messages?to=alice', token=bob)[0], 403)
        self.assertEqual(self.api('/relationship', {'to': 'bob', 'kind': 'BFFs'}, alice)[0], 403)
        self.assertEqual(self.api('/inbox', token=alice)[1]['relationships'], [])
        self.assertEqual(self.api('/blocks', token=bob)[1]['users'], [{'username': 'alice'}])
        self.assertEqual(self.api('/blocks', token=alice)[1]['users'], [])
        self.assertEqual(self.api('/unblock', {'to': 'alice'}, bob)[0], 200)
        self.assertEqual(self.api('/messages', {'to': 'bob', 'body': 'Unblocked again'}, alice)[0], 200)
        self.assertEqual(self.api('/inbox', token=alice)[1]['relationships'], [])
        self.assertEqual(self.api('/account/delete', {}, alice)[0], 200)
        self.assertEqual(self.api('/inbox', token=alice)[0], 401)
        with app.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM messages').fetchone()[0], 0)
            self.assertNotEqual(db.execute('SELECT password FROM users LIMIT 1').fetchone()[0], 'distinct-test-password')
        self.assertEqual(self.api('/logout', {}, bob)[0], 200)
        self.assertEqual(self.api('/inbox', token=bob)[0], 401)


if __name__ == '__main__':
    unittest.main(verbosity=2)
