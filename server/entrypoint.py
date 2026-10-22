"""Make a newly mounted persistent disk writable, then drop root privileges."""
import os
from pathlib import Path
import pwd
import runpy

if os.geteuid() == 0:
    user = pwd.getpwnam('campus')
    database = Path(os.environ.get('DATABASE_PATH', '/data/campus-social.sqlite3'))
    database.parent.mkdir(parents=True, exist_ok=True)
    os.chown(database.parent, user.pw_uid, user.pw_gid)
    for path in (database, Path(str(database) + '-wal'), Path(str(database) + '-shm')):
        if path.exists():
            os.chown(path, user.pw_uid, user.pw_gid)
    os.setgroups([])
    os.setgid(user.pw_gid)
    os.setuid(user.pw_uid)
runpy.run_path('/app/app.py', run_name='__main__')
