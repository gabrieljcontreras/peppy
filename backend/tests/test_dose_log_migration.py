import os
import sqlite3
import subprocess
import sys


def _run_alembic(tmp_db_path, command, revision):
    env = os.environ.copy()
    env["DEBUG"] = "true"
    env["DATABASE_URL"] = f"sqlite+aiosqlite:///{tmp_db_path}"
    return subprocess.run(
        [sys.executable, "-m", "alembic", "-c", "alembic.ini", command, revision],
        cwd=os.path.dirname(os.path.dirname(__file__)),
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_protocol_dose_logs_migration_upgrade_downgrade_upgrade(tmp_path):
    db_path = tmp_path / "dose-log-migration.sqlite"

    first_upgrade = _run_alembic(db_path, "upgrade", "head")
    assert first_upgrade.returncode == 0, first_upgrade.stderr

    with sqlite3.connect(db_path) as conn:
        table_names = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        assert "dose_logs" in table_names
        columns = {row[1] for row in conn.execute("PRAGMA table_info('dose_logs')")}
        assert {
            "user_id",
            "protocol_id",
            "compound_id",
            "dose",
            "unit",
            "administered_at",
            "route",
            "notes",
        }.issubset(columns)
        foreign_keys = list(conn.execute("PRAGMA foreign_key_list('dose_logs')"))
        assert {row[2] for row in foreign_keys} == {"users", "protocols", "compounds"}
        assert {row[6] for row in foreign_keys} == {"CASCADE"}
        indexes = {row[1] for row in conn.execute("PRAGMA index_list('dose_logs')")}
        assert {
            "ix_dose_logs_user_id",
            "ix_dose_logs_protocol_id",
            "ix_dose_logs_compound_id",
            "ix_dose_logs_administered_at",
        }.issubset(indexes)

    downgrade = _run_alembic(db_path, "downgrade", "b4c5d6e7f8a9")
    assert downgrade.returncode == 0, downgrade.stderr

    with sqlite3.connect(db_path) as conn:
        table_names = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        assert "dose_logs" not in table_names

    second_upgrade = _run_alembic(db_path, "upgrade", "head")
    assert second_upgrade.returncode == 0, second_upgrade.stderr

    with sqlite3.connect(db_path) as conn:
        table_names = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        assert "dose_logs" in table_names
