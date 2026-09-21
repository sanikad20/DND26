"""
migrate_db.py
────────────────────────────────────────────────────────────────────────────
Safely brings an EXISTING users.db up to date with the current models.py,
without dropping or rewriting any existing data. Specifically:

  1. Adds occupational_assessments.raw_answers if that column doesn't
     already exist (older databases created before raw-answer persistence
     was added won't have it). Existing rows get raw_answers = NULL -
     there's no way to recover answers that were never stored, but nothing
     already saved (id, firebase_uid, risk_level, score, model_version,
     created_at) is touched.
  2. Creates wellness_plans and plan_progress if they don't already exist,
     via SQLAlchemy's Base.metadata.create_all(). create_all() only creates
     TABLES THAT ARE MISSING - it never alters or drops a table that
     already exists, so this step is always safe to run, repeatedly,
     against a live database.

This script does NOT:
  - backfill wellness_plans for assessments that existed before this
    migration (those old assessments simply have no plan; the app already
    handles "no plan_id" by falling back to a generic plan / prompting a
    fresh assessment - see occupational_wellness_plan.dart's
    "_NoPlanNotice" and the dashboard's history fallback)
  - delete, rename, or reformat anything

Run from Backend/:
    python migrate_db.py

Safe to run multiple times - every step checks "does this already exist?"
before doing anything.
────────────────────────────────────────────────────────────────────────────
"""

import sqlite3

from core.config import settings
from database import Base, engine


def _sqlite_path_from_url(database_url: str) -> str | None:
    """Extract a plain filesystem path from a sqlite:/// URL. Returns None
    for non-sqlite URLs (e.g. Postgres) - the column-add step below only
    applies to sqlite; other engines would use a real migration tool
    (Alembic) instead."""
    prefix = "sqlite:///"
    if database_url.startswith(prefix):
        return database_url[len(prefix):]
    return None


def _column_exists(conn: sqlite3.Connection, table: str, column: str) -> bool:
    cur = conn.execute(f"PRAGMA table_info({table})")
    existing_columns = {row[1] for row in cur.fetchall()}
    return column in existing_columns


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    cur = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table,),
    )
    return cur.fetchone() is not None


def add_missing_columns(db_path: str) -> None:
    conn = sqlite3.connect(db_path)
    try:
        if not _table_exists(conn, "occupational_assessments"):
            print(
                "No occupational_assessments table found yet - nothing to "
                "migrate for it (create_all will create it fresh below)."
            )
            return

        if _column_exists(conn, "occupational_assessments", "raw_answers"):
            print("occupational_assessments.raw_answers already exists - skipping.")
        else:
            print("Adding occupational_assessments.raw_answers (TEXT, nullable)...")
            conn.execute(
                "ALTER TABLE occupational_assessments ADD COLUMN raw_answers TEXT"
            )
            conn.commit()
            print("  done. Existing rows now have raw_answers = NULL "
                  "(answers from before this column existed were never "
                  "captured, so there's nothing to backfill them with).")
    finally:
        conn.close()


def create_missing_tables() -> None:
    # Import models so their table definitions are registered on Base
    # before create_all runs.
    import models  # noqa: F401

    before = set(Base.metadata.tables.keys())
    print(f"Known tables in models.py: {sorted(before)}")
    print("Running create_all() - creates any of these that don't exist yet; "
          "never touches ones that already exist...")
    Base.metadata.create_all(bind=engine)
    print("  done.")


def report_current_schema(db_path: str) -> None:
    conn = sqlite3.connect(db_path)
    try:
        cur = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        )
        tables = [row[0] for row in cur.fetchall()]
        print("\nCurrent tables in the database:")
        for t in tables:
            if t == "sqlite_sequence":
                continue
            cols = conn.execute(f"PRAGMA table_info({t})").fetchall()
            col_names = ", ".join(c[1] for c in cols)
            count = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            print(f"  {t} ({count} rows): {col_names}")
    finally:
        conn.close()


def main():
    db_path = _sqlite_path_from_url(settings.database_url)
    if db_path is None:
        print(
            f"DATABASE_URL ({settings.database_url}) isn't a sqlite:/// URL - "
            "this script only handles the sqlite column-add step. Run "
            "create_missing_tables() equivalent via your normal migration "
            "tool (e.g. Alembic) for other databases; skipping straight to "
            "table creation, which is engine-agnostic."
        )
    else:
        print(f"Migrating sqlite database at: {db_path}")
        add_missing_columns(db_path)

    create_missing_tables()

    if db_path is not None:
        report_current_schema(db_path)


if __name__ == "__main__":
    main()
