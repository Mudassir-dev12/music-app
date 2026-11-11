import argparse
import datetime
import glob
import os
import sqlite3
import sys
from app.config import settings


def run_backup(keep: int = 7) -> str:
    # 1. Determine database file path
    db_url = settings.DATABASE_URL
    if "sqlite" not in db_url:
        print(f"Skipping sqlite backup: DATABASE_URL is not SQLite ({db_url})")
        return ""

    if ":///" in db_url:
        db_path = db_url.split(":///", 1)[1]
    else:
        db_path = "./data/music.db"

    if not os.path.exists(db_path) and db_path.startswith("./"):
        backend_rel = os.path.join("backend", db_path[2:])
        if os.path.exists(backend_rel):
            db_path = backend_rel

    if not os.path.exists(db_path):
        print(f"Source database file does not exist: {db_path}", file=sys.stderr)
        return ""

    # 2. Ensure backups directory exists
    backup_dir = "./backups"
    os.makedirs(backup_dir, exist_ok=True)
    try:
        os.chmod(backup_dir, 0o700)
    except OSError:
        pass

    # 3. Create timestamped backup
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup_file = os.path.join(backup_dir, f"music-{timestamp}.db")

    source_conn = sqlite3.connect(db_path)
    dest_conn = sqlite3.connect(backup_file)

    try:
        source_conn.backup(dest_conn)
    finally:
        dest_conn.close()
        source_conn.close()

    try:
        os.chmod(backup_file, 0o600)
    except OSError:
        pass

    print(f"Backup created successfully: {backup_file}")

    # 4. Prune older backups
    all_backups = sorted(
        glob.glob(os.path.join(backup_dir, "music-*.db")),
        reverse=True,
    )
    if len(all_backups) > keep:
        for old_backup in all_backups[keep:]:
            try:
                # Ensure we only remove files strictly inside backup_dir
                if os.path.dirname(os.path.abspath(old_backup)) == os.path.abspath(backup_dir):
                    os.remove(old_backup)
                    print(f"Pruned old backup: {old_backup}")
            except OSError as err:
                print(f"Failed to prune old backup {old_backup}: {err}", file=sys.stderr)

    return backup_file


def main():
    parser = argparse.ArgumentParser(description="SQLite database backup tool")
    parser.add_argument(
        "--keep",
        type=int,
        default=7,
        help="Number of newest backup files to keep (default: 7)",
    )
    args = parser.parse_args()
    run_backup(keep=args.keep)


if __name__ == "__main__":
    main()
