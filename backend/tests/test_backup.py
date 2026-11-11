import glob
import os
import sqlite3
import time
from app.config import settings
from app.tools.backup import run_backup


def test_backup_tool_execution(test_db_path, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(settings, "DATABASE_URL", f"sqlite+aiosqlite:///{test_db_path}")

    backup_dir = os.path.join(tmp_path, "backups")
    os.makedirs(backup_dir, exist_ok=True)

    # Create dummy file that should not be touched
    untouched_file = os.path.join(backup_dir, "leave_me_alone.txt")
    with open(untouched_file, "w") as f:
        f.write("safe")

    # 1. Run backup
    backup_file = run_backup(keep=2)
    assert os.path.exists(backup_file)

    # Verify backup is a valid SQLite DB
    conn = sqlite3.connect(backup_file)
    cur = conn.cursor()
    cur.execute("SELECT count(*) FROM users;")
    row = cur.fetchone()
    assert row is not None
    conn.close()

    # Verify mode 600
    st = os.stat(backup_file)
    assert oct(st.st_mode)[-3:] == "600"

    # 2. Test keep N pruning with distinct historical backup files
    for idx in range(3):
        old_path = os.path.join(backup_dir, f"music-20260101-00000{idx}.db")
        with open(old_path, "wb") as f:
            f.write(b"old")

    # Run backup with keep=2 -> total music-*.db files must be pruned to 2
    latest_backup = run_backup(keep=2)
    assert os.path.exists(latest_backup)

    all_backups = sorted(glob.glob(os.path.join(backup_dir, "music-*.db")))
    assert len(all_backups) == 2
    assert os.path.abspath(latest_backup) in [os.path.abspath(p) for p in all_backups]
    assert os.path.exists(untouched_file)  # Untouched file must remain intact
