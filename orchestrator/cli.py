from __future__ import annotations

import argparse
import sys
from pathlib import Path

from . import __version__
from .audit import default_actor, git_sha, write_audit
from .config import REPO_ROOT, load_config, write_json
from .stacks import StackGraphError, build_graph, resolve_targets
from .terraform import TerraformError, apply, init, output_json, plan


ALLOWED_ENVS = {"sb", "dev", "tst", "prod"}
DNS_STACKS = {"tls", "dns_record"}
# Extra account fields only declared on these stacks' variables.tf
STACK_EXTRA_VARS: dict[str, set[str]] = {
    "tls": {"route53_account_id", "dns_manager_role_arn"},
    "dns_record": {"route53_account_id", "dns_manager_role_arn"},
    "github_oidc_role": {"oidc_subjects", "artifact_bucket"},
    "lambda-argus_api": {"artifact_bucket"},
}
COMMON_DROP = {
    "route53_account_id",
    "dns_manager_role_arn",
    "oidc_subjects",
    "artifact_bucket",
}


class OrchestratorError(RuntimeError):
    pass


def refresh_stack_files(stack_dir: Path, cfg, stack_name: str) -> tuple[Path, Path]:
    """Rewrite terraform.tfvars.json and backend.hcl for this stack."""
    tfvars = cfg.as_tfvars()
    keep = STACK_EXTRA_VARS.get(stack_name, set())
    for key in COMMON_DROP:
        if key not in keep:
            tfvars.pop(key, None)

    var_file = stack_dir / "terraform.tfvars.json"
    write_json(var_file, tfvars)

    # State key is path relative to account dir (Delphi/Terragrunt convention).
    rel = stack_dir.relative_to(cfg.account_dir).as_posix()
    backend = stack_dir / "backend.hcl"
    backend.write_text(
        "\n".join(
            [
                f'bucket  = "{cfg.state_bucket}"',
                f'key     = "{rel}/terraform.tfstate"',
                f'region  = "{cfg.region}"',
                f'profile = "{cfg.aws_profile}"',
                "",
            ]
        )
    )
    return var_file, backend


def validate_request(*, env: str, execute: bool, i_know: bool, account_id: str) -> None:
    if env not in ALLOWED_ENVS:
        raise OrchestratorError(f"env must be one of {sorted(ALLOWED_ENVS)}")
    if account_id in {"", "000000000000", "<ACCOUNT_ID>", "PLACEHOLDER"}:
        if execute:
            raise OrchestratorError(
                "account_id is still a placeholder — update account.json "
                "(or account.local.json) in the account folder before --execute"
            )
    if env == "prod" and execute and not i_know:
        raise OrchestratorError("refusing prod apply without --i-know")


def cmd_list(_: argparse.Namespace) -> int:
    graph = build_graph()
    for name, stack in graph.items():
        deps = ", ".join(stack.depends_on) if stack.depends_on else "-"
        print(f"{name:24} {stack.relative_path:40} deps=[{deps}]")
    return 0


def cmd_order(args: argparse.Namespace) -> int:
    cfg = load_config(Path(args.account_dir) if args.account_dir else None)
    targets = resolve_targets(cfg, stack_names=args.stacks, all_stacks=args.all)
    for stack in targets:
        print(stack.name)
    return 0


def run_stacks(args: argparse.Namespace, *, action: str) -> int:
    cfg = load_config(Path(args.account_dir) if args.account_dir else None)
    validate_request(
        env=cfg.env,
        execute=args.execute if action == "apply" else False,
        i_know=getattr(args, "i_know", False),
        account_id=cfg.account_id,
    )
    targets = resolve_targets(cfg, stack_names=args.stacks, all_stacks=args.all)
    actor = args.actor or default_actor()
    sha = git_sha(REPO_ROOT)
    audit_dir = REPO_ROOT / "audit"

    print(f"landscape={cfg.landscape} env={cfg.env} action={action} execute={getattr(args, 'execute', False)}")
    print(f"stacks ({len(targets)}): {', '.join(s.name for s in targets)}")

    for stack in targets:
        stack_dir = stack.absolute_path(cfg.account_dir)
        if not stack_dir.is_dir():
            raise OrchestratorError(f"missing stack directory: {stack_dir}")

        var_file, backend = refresh_stack_files(stack_dir, cfg, stack.name)
        print(f"\n==> {stack.name} ({stack.relative_path})")

        if args.dry_run_files_only:
            print(f"    refreshed {var_file.name} and {backend.name}")
            write_audit(
                audit_dir / f"{stack.name}-{action}.json",
                actor=actor,
                git_sha_value=sha,
                action=f"{action}:files-only",
                detail=str(stack_dir),
                extra={"stack": stack.name, "env": cfg.env},
            )
            continue

        init(stack_dir, backend)
        plan_path = stack_dir / "tfplan"
        plan(stack_dir, var_file=var_file, out=plan_path)

        if action == "plan" or not args.execute:
            print(f"    plan written to {plan_path.name} (apply skipped; pass --execute)")
            write_audit(
                audit_dir / f"{stack.name}-plan.json",
                actor=actor,
                git_sha_value=sha,
                action="plan",
                detail=str(stack_dir),
                extra={"stack": stack.name, "env": cfg.env},
            )
            continue

        apply(stack_dir, var_file=var_file, plan_file=plan_path)
        write_audit(
            audit_dir / f"{stack.name}-apply.json",
            actor=actor,
            git_sha_value=sha,
            action="apply",
            detail=str(stack_dir),
            extra={"stack": stack.name, "env": cfg.env},
        )
        print(f"    apply complete for {stack.name}")

    return 0


def cmd_output(args: argparse.Namespace) -> int:
    cfg = load_config(Path(args.account_dir) if args.account_dir else None)
    graph = build_graph()
    if args.stack not in graph:
        raise OrchestratorError(f"unknown stack: {args.stack}")
    stack = graph[args.stack]
    stack_dir = stack.absolute_path(cfg.account_dir)
    _, backend = refresh_stack_files(stack_dir, cfg, stack.name)
    init(stack_dir, backend)
    raw = output_json(stack_dir)
    print(raw)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="kos",
        description="Python orchestrator for aws-kos (Terragrunt replacement).",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.add_argument(
        "--account-dir",
        default=None,
        help="Path to account folder (default: aws-kos-dev; use aws-kos-prod for prod)",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    p_list = sub.add_parser("list", help="List stacks and dependencies")
    p_list.set_defaults(func=cmd_list)

    p_order = sub.add_parser("order", help="Print apply order for selected stacks")
    p_order.add_argument("stacks", nargs="*", help="Stack names")
    p_order.add_argument("--all", action="store_true", help="All stacks")
    p_order.set_defaults(func=cmd_order)

    for name, help_text in (
        ("plan", "terraform init + plan for stacks (default; no apply)"),
        ("apply", "plan then apply (requires --execute)"),
    ):
        p = sub.add_parser(name, help=help_text)
        p.add_argument("stacks", nargs="*", help="Stack names (include transitive deps)")
        p.add_argument("--all", action="store_true", help="All stacks in dependency order")
        p.add_argument(
            "--execute",
            action="store_true",
            help="Actually apply (apply subcommand only; plan ignores this)",
        )
        p.add_argument(
            "--i-know",
            action="store_true",
            help="Required with --execute when env=prod",
        )
        p.add_argument(
            "--dry-run-files-only",
            action="store_true",
            help="Only refresh tfvars/backend.hcl; do not call terraform",
        )
        p.add_argument("--actor", default=None, help="Audit actor (default: $USER)")
        p.set_defaults(func=lambda a, action=name: run_stacks(a, action=action))

    p_out = sub.add_parser("output", help="terraform output -json for one stack")
    p_out.add_argument("stack", help="Stack name")
    p_out.set_defaults(func=cmd_output)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except (OrchestratorError, StackGraphError, TerraformError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
