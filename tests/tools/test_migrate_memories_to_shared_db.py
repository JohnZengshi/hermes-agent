import sqlite3
from pathlib import Path

from scripts.migrate_memories_to_shared_db import (
    GLOBAL_USER_ID,
    discover_legacy_entries,
    migrate_to_shared_db,
)


def _write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _create_legacy_db(path: Path, rows: list[tuple[str, int, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    try:
        conn.execute(
            "CREATE TABLE memory_entries (target TEXT NOT NULL, position INTEGER NOT NULL, content TEXT NOT NULL, PRIMARY KEY (target, position))"
        )
        conn.executemany(
            "INSERT INTO memory_entries(target, position, content) VALUES (?, ?, ?)",
            rows,
        )
        conn.commit()
    finally:
        conn.close()


def _read_shared_entries(db_path: Path, user_id: str, target: str) -> list[str]:
    conn = sqlite3.connect(str(db_path))
    try:
        rows = conn.execute(
            "SELECT content FROM memory_entries WHERE user_id = ? AND target = ? ORDER BY position ASC",
            (user_id, target),
        ).fetchall()
        return [row[0] for row in rows]
    finally:
        conn.close()


def test_discover_legacy_entries_from_file_and_sqlite(tmp_path):
    hermes_home = tmp_path / ".hermes"
    memories_root = hermes_home / "memories"

    _write_text(memories_root / "alice" / "MEMORY.md", "file-a\n§\nfile-b")
    _write_text(memories_root / "alice" / "USER.md", "alice-user")
    _create_legacy_db(
        memories_root / "alice" / "memory.db",
        [
            ("memory", 0, "db-a"),
            ("user", 0, "db-u"),
        ],
    )
    _write_text(memories_root / "MEMORY.md", "global-file")

    discovered = discover_legacy_entries(memories_root, include_guests=False)

    assert discovered[("alice", "memory")] == ["file-a", "file-b", "db-a"]
    assert discovered[("alice", "user")] == ["alice-user", "db-u"]
    assert discovered[(GLOBAL_USER_ID, "memory")] == ["global-file"]


def test_migrate_dry_run_does_not_write(tmp_path):
    hermes_home = tmp_path / ".hermes"
    memories_root = hermes_home / "memories"
    shared_db = hermes_home / "memories.db"

    _write_text(memories_root / "alice" / "MEMORY.md", "m1\n§\nm2")

    stats = migrate_to_shared_db(hermes_home=hermes_home, execute=False)
    assert stats.entries_added == 2
    assert not shared_db.exists()


def test_migrate_execute_merges_without_duplicate(tmp_path):
    hermes_home = tmp_path / ".hermes"
    memories_root = hermes_home / "memories"
    shared_db = hermes_home / "memories.db"

    _write_text(memories_root / "alice" / "MEMORY.md", "m1\n§\nm2")
    _create_legacy_db(
        memories_root / "alice" / "memory.db",
        [
            ("memory", 0, "m2"),
            ("memory", 1, "m3"),
            ("user", 0, "u1"),
        ],
    )

    stats = migrate_to_shared_db(hermes_home=hermes_home, execute=True)

    assert shared_db.exists()
    assert stats.entries_added == 4
    assert _read_shared_entries(shared_db, "alice", "memory") == ["m1", "m2", "m3"]
    assert _read_shared_entries(shared_db, "alice", "user") == ["u1"]


def test_guest_skipped_by_default_and_opt_in_with_flag(tmp_path):
    hermes_home = tmp_path / ".hermes"
    memories_root = hermes_home / "memories"
    shared_db = hermes_home / "memories.db"

    _write_text(memories_root / "guest_42" / "MEMORY.md", "guest-memory")
    _write_text(memories_root / "alice" / "MEMORY.md", "alice-memory")

    migrate_to_shared_db(hermes_home=hermes_home, execute=True, include_guests=False)
    assert _read_shared_entries(shared_db, "alice", "memory") == ["alice-memory"]
    assert _read_shared_entries(shared_db, "guest_42", "memory") == []

    migrate_to_shared_db(hermes_home=hermes_home, execute=True, include_guests=True)
    assert _read_shared_entries(shared_db, "guest_42", "memory") == ["guest-memory"]


def test_preserves_user_id_when_legacy_sqlite_has_user_id(tmp_path):
    hermes_home = tmp_path / ".hermes"
    memories_root = hermes_home / "memories"
    shared_db = hermes_home / "memories.db"

    legacy_db = memories_root / "memory.db"
    legacy_db.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(legacy_db))
    try:
        conn.execute(
            "CREATE TABLE memory_entries (user_id TEXT NOT NULL, target TEXT NOT NULL, position INTEGER NOT NULL, content TEXT NOT NULL, PRIMARY KEY (user_id, target, position))"
        )
        conn.executemany(
            "INSERT INTO memory_entries(user_id, target, position, content) VALUES (?, ?, ?, ?)",
            [
                ("alice", "memory", 0, "alice-m1"),
                ("bob", "memory", 0, "bob-m1"),
                ("bob", "user", 0, "bob-u1"),
            ],
        )
        conn.commit()
    finally:
        conn.close()

    migrate_to_shared_db(hermes_home=hermes_home, execute=True)

    assert _read_shared_entries(shared_db, "alice", "memory") == ["alice-m1"]
    assert _read_shared_entries(shared_db, "bob", "memory") == ["bob-m1"]
    assert _read_shared_entries(shared_db, "bob", "user") == ["bob-u1"]
    assert _read_shared_entries(shared_db, "__global__", "memory") == []


def test_user_scoped_sqlite_file_does_not_relabel_other_users(tmp_path):
    hermes_home = tmp_path / ".hermes"
    memories_root = hermes_home / "memories"
    shared_db = hermes_home / "memories.db"

    legacy_db = memories_root / "alice" / "memory.db"
    legacy_db.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(legacy_db))
    try:
        conn.execute(
            "CREATE TABLE memory_entries (user_id TEXT NOT NULL, target TEXT NOT NULL, position INTEGER NOT NULL, content TEXT NOT NULL, PRIMARY KEY (user_id, target, position))"
        )
        conn.executemany(
            "INSERT INTO memory_entries(user_id, target, position, content) VALUES (?, ?, ?, ?)",
            [
                ("alice", "memory", 0, "alice-from-alice-db"),
                ("charlie", "memory", 0, "charlie-from-alice-db"),
            ],
        )
        conn.commit()
    finally:
        conn.close()

    migrate_to_shared_db(hermes_home=hermes_home, execute=True)

    assert _read_shared_entries(shared_db, "alice", "memory") == ["alice-from-alice-db"]
    assert _read_shared_entries(shared_db, "charlie", "memory") == [
        "charlie-from-alice-db"
    ]


def test_dry_run_with_existing_shared_db_reports_only_new_entries(tmp_path):
    hermes_home = tmp_path / ".hermes"
    memories_root = hermes_home / "memories"
    shared_db = hermes_home / "memories.db"

    _write_text(memories_root / "alice" / "MEMORY.md", "m1\n§\nm2")

    conn = sqlite3.connect(str(shared_db))
    try:
        conn.execute(
            "CREATE TABLE memory_entries (user_id TEXT NOT NULL, target TEXT NOT NULL, position INTEGER NOT NULL, content TEXT NOT NULL, PRIMARY KEY (user_id, target, position))"
        )
        conn.execute(
            "INSERT INTO memory_entries(user_id, target, position, content) VALUES (?, ?, ?, ?)",
            ("alice", "memory", 0, "m1"),
        )
        conn.commit()
    finally:
        conn.close()

    stats = migrate_to_shared_db(hermes_home=hermes_home, execute=False)
    assert stats.entries_added == 1
    assert stats.targets_changed == 1
