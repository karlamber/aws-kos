from __future__ import annotations

import subprocess
from pathlib import Path


class TerraformError(RuntimeError):
    pass


def run_terraform(args: list[str], *, cwd: Path) -> str:
    """Run terraform; raise with stderr on non-zero exit."""
    cmd = ["terraform", *args]
    proc = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise TerraformError(
            f"terraform failed ({proc.returncode}): {' '.join(cmd)}\n"
            f"cwd={cwd}\n{proc.stderr or proc.stdout}"
        )
    return proc.stdout


def init(cwd: Path, backend_config: Path) -> str:
    return run_terraform(
        ["init", "-input=false", f"-backend-config={backend_config.name}"],
        cwd=cwd,
    )


def plan(cwd: Path, *, var_file: Path, out: Path | None = None) -> str:
    args = ["plan", "-input=false", f"-var-file={var_file.name}"]
    if out is not None:
        args.extend(["-out", str(out.name)])
    return run_terraform(args, cwd=cwd)


def apply(cwd: Path, *, var_file: Path, plan_file: Path | None = None) -> str:
    if plan_file is not None:
        return run_terraform(["apply", "-input=false", str(plan_file.name)], cwd=cwd)
    return run_terraform(
        ["apply", "-input=false", "-auto-approve", f"-var-file={var_file.name}"],
        cwd=cwd,
    )


def output_json(cwd: Path) -> str:
    return run_terraform(["output", "-json"], cwd=cwd)
