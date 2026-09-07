from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ACCOUNT_DIR = REPO_ROOT / "aws-kos-dev"
STACKS_MANIFEST = REPO_ROOT / "stacks.json"


@dataclass(frozen=True)
class LandscapeConfig:
    env: str
    account_name: str
    account_id: str
    aws_profile: str
    landscape: str
    region: str
    region_short: str
    route53_account_id: str
    dns_manager_role_arn: str
    artifact_bucket: str
    oidc_subjects: tuple[str, ...]
    account_dir: Path

    @property
    def state_bucket(self) -> str:
        return f"s3-{self.landscape}-{self.env}-{self.region_short}-terraform-state"

    def as_tfvars(self) -> dict[str, Any]:
        return {
            "env": self.env,
            "account_name": self.account_name,
            "account_id": self.account_id,
            "aws_profile": self.aws_profile,
            "landscape": self.landscape,
            "region": self.region,
            "region_short": self.region_short,
            "route53_account_id": self.route53_account_id,
            "dns_manager_role_arn": self.dns_manager_role_arn,
            "artifact_bucket": self.artifact_bucket,
            "oidc_subjects": list(self.oidc_subjects),
        }


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def _load_account(account_dir: Path) -> dict[str, Any]:
    """Merge account.json with optional account.local.json (local wins)."""
    base_path = account_dir / "account.json"
    if not base_path.is_file():
        raise FileNotFoundError(
            f"missing {base_path}; copy account.json.example if needed"
        )
    account = load_json(base_path)
    local_path = account_dir / "account.local.json"
    if local_path.is_file():
        account = {**account, **load_json(local_path)}
    return account


def load_config(account_dir: Path | None = None) -> LandscapeConfig:
    account_dir = (account_dir or DEFAULT_ACCOUNT_DIR).resolve()
    account = _load_account(account_dir)
    region = load_json(account_dir / "us-east-1" / "region.json")
    subjects = account.get("oidc_subjects") or []
    if isinstance(subjects, str):
        subjects = [subjects]
    return LandscapeConfig(
        env=account["env"],
        account_name=account["account_name"],
        account_id=account["account_id"],
        aws_profile=account["aws_profile"],
        landscape=account["landscape"],
        region=region["region"],
        region_short=region["region_short"],
        route53_account_id=account["route53_account_id"],
        dns_manager_role_arn=account["dns_manager_role_arn"],
        artifact_bucket=account.get(
            "artifact_bucket", "s3-EXAMPLE-mgmt-ue1-shared-lambda"
        ),
        oidc_subjects=tuple(subjects),
        account_dir=account_dir,
    )


def load_stacks_manifest(path: Path | None = None) -> dict[str, dict[str, Any]]:
    data = load_json(path or STACKS_MANIFEST)
    return data["stacks"]
