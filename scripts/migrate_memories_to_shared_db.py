#!/usr/bin/env python3
"""One-time migration: legacy memories/ storage -> shared memories.db.

Migrates legacy sources under <HERMES_HOME>/memories into
<HERMES_HOME>/memories.db (profile-scoped shared SQLite DB):

- File backend legacy data:
  - memories/<user_id>/MEMORY.md
  - memories/<user_id>/USER.md
  - memories/MEMORY.md and memories/USER.md (mapped to __global__)
- Old per-user SQLite data:
  - memories/<user_id>/memory.db
  - memories/memory.db (mapped to __global__)

Behavior:
- Dry-run by default (no writes).
- On --execute, merges legacy entries into shared DB without deleting existing
  shared rows (dedupe by exact content, preserving existing order).
- Guest users are skipped by default; pass --include-guests to migrate them.
"""

from __future__ import annotations

import argparse
import sqlite3
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import DefaultDict

from hermes_constants import get_hermes_home

ENTRY_DELIMITER = "\n§\n"
GLOBAL_USER_ID = "__global__"


@dataclass
class MigrationStats:
    users_seen: int = 0
    targets_seen: int = 0
    legacy_entries_seen: int = 0
    targets_changed: int = 0
    entries_added: int = 0


def _parse_file_entries(content: str) -> list[str]:
    if not content.strip():
        return []
    entries = [part.strip() for part in content.split(ENTRY_DELIMITER)]
    return [entry for entry in entries if entry]


def _read_entries_from_markdown(path: Path) -> list[str]:
    if not path.exists():
        return []
    try:
        return _parse_file_entries(path.read_text(encoding="utf-8"))
    except OSError:
        return []


def _extend_unique(base: list[str], additions: list[str]) -> None:
    seen = set(base)
    for item in additions:
        if item not in seen:
            base.append(item)
            seen.add(item)


def _read_entries_from_legacy_sqlite(
    db_path: Path,
    fallback_user_id: str,
    include_guests: bool,
) -> dict[tuple[str, str], list[str]]:
    """Read entries from a legacy sqlite DB.

    Supports both old schema (target, position, content) and newer schema with
    user_id while preserving source user isolation.
    """
    if not db_path.exists():
        return {}

    conn = sqlite3.connect(str(db_path))
    try:
        cols = [row[1] for row in conn.execute("PRAGMA table_info(memory_entries)")]
        if (
            not cols
            or "target" not in cols
            or "position" not in cols
            or "content" not in cols
        ):
            return {}

        by_user_target: DefaultDict[tuple[str, str], list[str]] = defaultdict(list)

        def _eligible(uid: str) -> bool:
            if include_guests:
                return True
            return not uid.startswith("guest_")

        if "user_id" in cols:
            rows = conn.execute(
                "SELECT user_id, target, content FROM memory_entries ORDER BY user_id ASC, target ASC, position ASC"
            ).fetchall()
            for raw_user_id, target, content in rows:
                user_id = str(raw_user_id or fallback_user_id)
                if not user_id or not target or not content:
                    continue
                if not _eligible(user_id):
                    continue
                by_user_target[(user_id, str(target))].append(str(content))
        else:
            rows = conn.execute(
                "SELECT target, content FROM memory_entries ORDER BY target ASC, position ASC"
            ).fetchall()
            for target, content in rows:
                if not target or not content:
                    continue
                if not _eligible(fallback_user_id):
                    continue
                by_user_target[(fallback_user_id, str(target))].append(str(content))
        return dict(by_user_target)
    except sqlite3.Error:
        return {}
    finally:
        conn.close()


def discover_legacy_entries(
    memories_root: Path,
    include_guests: bool = False,
) -> dict[tuple[str, str], list[str]]:
    """Collect legacy entries grouped by (user_id, target)."""
    collected: DefaultDict[tuple[str, str], list[str]] = defaultdict(list)

    def _eligible_user(user_id: str) -> bool:
        if include_guests:
            return True
        return not user_id.startswith("guest_")

    def _ingest_user_dir(user_id: str, user_dir: Path) -> None:
        if not _eligible_user(user_id):
            return

        memory_md = _read_entries_from_markdown(user_dir / "MEMORY.md")
        user_md = _read_entries_from_markdown(user_dir / "USER.md")
        _extend_unique(collected[(user_id, "memory")], memory_md)
        _extend_unique(collected[(user_id, "user")], user_md)

        sqlite_entries = _read_entries_from_legacy_sqlite(
            user_dir / "memory.db",
            fallback_user_id=user_id,
            include_guests=include_guests,
        )
        for key, entries in sqlite_entries.items():
            _extend_unique(collected[key], entries)

    # Global legacy files/db directly under memories/
    _ingest_user_dir(GLOBAL_USER_ID, memories_root)

    # Per-user legacy directories under memories/<user_id>/
    if memories_root.exists():
        for child in memories_root.iterdir():
            if child.is_dir():
                _ingest_user_dir(child.name, child)

    # Remove empty targets
    return {key: entries for key, entries in collected.items() if entries}


def _ensure_shared_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        "CREATE TABLE IF NOT EXISTS memory_entries ("
        "user_id TEXT NOT NULL, "
        "target TEXT NOT NULL, "
        "position INTEGER NOT NULL, "
        "content TEXT NOT NULL, "
        "PRIMARY KEY (user_id, target, position)"
        ")"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_memory_user ON memory_entries(user_id, target)"
    )


def _load_shared_entries(
    conn: sqlite3.Connection, user_id: str, target: str
) -> list[str]:
    rows = conn.execute(
        "SELECT content FROM memory_entries WHERE user_id = ? AND target = ? ORDER BY position ASC",
        (user_id, target),
    ).fetchall()
    return [row[0] for row in rows if row and row[0]]


def _save_shared_entries(
    conn: sqlite3.Connection,
    user_id: str,
    target: str,
    entries: list[str],
) -> None:
    conn.execute(
        "DELETE FROM memory_entries WHERE user_id = ? AND target = ?",
        (user_id, target),
    )
    conn.executemany(
        "INSERT INTO memory_entries(user_id, target, position, content) VALUES (?, ?, ?, ?)",
        [(user_id, target, idx, entry) for idx, entry in enumerate(entries)],
    )


def migrate_to_shared_db(
    hermes_home: Path,
    execute: bool = False,
    include_guests: bool = False,
) -> MigrationStats:
    memories_root = hermes_home / "memories"
    shared_db = hermes_home / "memories.db"

    discovered = discover_legacy_entries(memories_root, include_guests=include_guests)

    stats = MigrationStats(
        users_seen=len({user_id for user_id, _ in discovered.keys()}),
        targets_seen=len(discovered),
        legacy_entries_seen=sum(len(entries) for entries in discovered.values()),
    )

    if not discovered:
        return stats

    if not execute:
        if not shared_db.exists():
            stats.targets_changed = len(discovered)
            stats.entries_added = sum(len(entries) for entries in discovered.values())
            return stats

        conn = sqlite3.connect(f"file:{shared_db}?mode=ro", uri=True)
        try:
            for (user_id, target), legacy_entries in sorted(discovered.items()):
                existing = _load_shared_entries(conn, user_id, target)
                merged = list(existing)
                _extend_unique(merged, legacy_entries)
                added_now = len(merged) - len(existing)
                if added_now > 0:
                    stats.targets_changed += 1
                    stats.entries_added += added_now
        finally:
            conn.close()
        return stats

    conn = sqlite3.connect(str(shared_db))
    try:
        _ensure_shared_schema(conn)

        for (user_id, target), legacy_entries in sorted(discovered.items()):
            existing = _load_shared_entries(conn, user_id, target)
            merged = list(existing)
            _extend_unique(merged, legacy_entries)

            added_now = len(merged) - len(existing)
            if added_now > 0:
                stats.targets_changed += 1
                stats.entries_added += added_now
                _save_shared_entries(conn, user_id, target, merged)

        conn.commit()
    finally:
        conn.close()

    return stats


def _format_stats(stats: MigrationStats, execute: bool, include_guests: bool) -> str:
    mode = "EXECUTE" if execute else "DRY-RUN"
    lines = [
        f"[memory-migration] Mode: {mode}",
        f"[memory-migration] include_guests={include_guests}",
        f"[memory-migration] users_seen={stats.users_seen}",
        f"[memory-migration] targets_seen={stats.targets_seen}",
        f"[memory-migration] legacy_entries_seen={stats.legacy_entries_seen}",
        f"[memory-migration] targets_changed={stats.targets_changed}",
        f"[memory-migration] entries_added={stats.entries_added}",
    ]
    if not execute:
        lines.append(
            "[memory-migration] This was a dry-run. Re-run with --execute to apply changes."
        )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Migrate legacy memories/<user_id> data into shared memories.db"
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Apply writes to shared memories.db (default is dry-run)",
    )
    parser.add_argument(
        "--include-guests",
        action="store_true",
        help="Also migrate guest_* users (default skips guest users)",
    )
    parser.add_argument(
        "--hermes-home",
        type=Path,
        default=None,
        help="Override HERMES_HOME for migration target",
    )
    args = parser.parse_args()

    hermes_home = args.hermes_home or get_hermes_home()
    stats = migrate_to_shared_db(
        hermes_home=hermes_home,
        execute=args.execute,
        include_guests=args.include_guests,
    )

    print(
        _format_stats(stats, execute=args.execute, include_guests=args.include_guests)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
