from __future__ import annotations

import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def git_sha(repo_root: Path) -> str:
    proc = subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode == 0:
        return proc.stdout.strip()
    return "unknown"


def write_audit(
    path: Path,
    *,
    actor: str,
    git_sha_value: str,
    action: str,
    detail: str,
    extra: dict[str, Any] | None = None,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    event = {
        "timestamp": utc_now(),
        "actor": actor,
        "git_sha": git_sha_value,
        "action": action,
        "detail": detail,
    }
    if extra:
        event.update(extra)
    path.write_text(json.dumps(event, indent=2) + "\n")


def default_actor() -> str:
    return os.environ.get("USER") or os.environ.get("USERNAME") or "unknown"
