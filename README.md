# aws-kos — Kos landscape (Python + Terraform)

Practice landscape that mirrors [`aws-delphi`](../aws-delphi) for the Argus CMDB, but replaces **Terragrunt** with a **Python orchestrator** wrapping Terraform. Built as a portfolio example of multi-stack AWS IaC (private first, public later).

Lab brand: **fifty9** (hostnames like `argus-dev.fifty9.net` are intentional). Apply only after `aws-kos-dev` is vended and **`account.local.json`** is filled in (see [Publishing / local secrets](#publishing--local-secrets)).

Sibling reference: `[aws-delos](../aws-delos)` is plain Terraform **without** Python orchestration (hand-run `cd` + `terraform`).

---

## Delphi vs Kos (quick map)


| Concern                             | aws-delphi                             | aws-kos                                                             |
| ----------------------------------- | -------------------------------------- | ------------------------------------------------------------------- |
| Stack driver                        | Terragrunt (`terragrunt.hcl`)          | Python (`orchestrator/`)                                            |
| Shared config                       | `root.hcl` + `account.hcl`             | `account.json` + `region.json`                                      |
| How shared config reaches Terraform | Terragrunt merges at plan time         | Python **writes** `terraform.tfvars.json` + `backend.hcl` per stack |
| Dependency **order**                | `dependency` / `dependencies`          | `stacks.json` DAG in Python                                         |
| Dependency **outputs**              | Terragrunt `dependency.x.outputs`      | Native `data.terraform_remote_state` in `remote_state.tf`           |
| Stack-specific inputs               | `inputs = { ... }` in `terragrunt.hcl` | Values in that stack’s `main.tf`                                    |
| Modules                             | `tf-modules/`                          | copied `tf-modules/` (same modules)                                 |
| App                                 | `argus`                                | `argus` (same)                                                      |


---

## Mental model: Terragrunt vs Python

### What Terragrunt was doing in Delphi

Each Delphi stack folder is thin: a `terragrunt.hcl` that mostly says “use this module” and “here are stack-specific inputs.” Terragrunt itself:

1. Walks up to `account.hcl` / `region.hcl` / `root.hcl`
2. **Injects** provider, backend, and shared inputs at plan time (`inputs = merge(...)`)
3. Resolves `dependency` blocks (and mocks for plan)
4. Runs Terraform in that folder

You do **not** hand-maintain shared account IDs across every stack — Terragrunt generates/merges them.

### What Kos does instead

Terraform **cannot** climb parent folders and merge config by itself. Each stack is a plain Terraform root: it only sees files in its directory (plus modules and remote state).

So Terragrunt’s jobs are split:


| Job                            | Delphi (Terragrunt)                     | Kos                                                                                 |
| ------------------------------ | --------------------------------------- | ----------------------------------------------------------------------------------- |
| Shared account/region values   | `account.hcl` → merged into every stack | **Source of truth:** `account.json` + `region.json`                                 |
| How values get into Terraform  | Runtime merge via Terragrunt            | Python **writes** `terraform.tfvars.json` (+ `backend.hcl`) before `terraform plan` |
| Dependency order               | `dependency` blocks                     | `stacks.json` DAG                                                                   |
| Passing outputs between stacks | `dependency.x.outputs`                  | `remote_state.tf` → `terraform_remote_state`                                        |
| Stack-specific config          | `inputs` in that stack’s HCL            | Still in that stack’s `main.tf` (CIDRs, Cognito, Lambda env, …)                     |


**Interview talk track:**

> Terraform stays the declarative source of truth. Python handles env inputs, sequencing, plan gates, and audit logging — it does not re-implement AWS resources.

### Side-by-side for one stack (`vpc`)


|                   | Delphi                                        | Kos                                                       |
| ----------------- | --------------------------------------------- | --------------------------------------------------------- |
| Edit              | `vpc/terragrunt.hcl` inputs (AZ, CIDR)        | `vpc/main.tf` (AZ, CIDR)                                  |
| Shared account ID | Comes from parent `account.hcl` automatically | Comes from `account.json` via orchestrator-written tfvars |
| Run               | `terragrunt plan` in the stack folder         | `python3 -m orchestrator plan vpc`                        |


Same AWS outcome; different “who merges the shared config” layer.

---

## FAQ

### Why both `stacks.json` and `stacks.yaml`?

Only `**stacks.json` is used** by the orchestrator (stdlib `json`, no PyYAML — better for interview demos).

`stacks.yaml` is an optional **human-readable mirror** of the same graph. If they drift, JSON wins. You could delete the YAML and nothing in Python would care.

### Why does every `terraform.tfvars.json` have the same values? Isn’t that not DRY?

On disk it looks duplicated. The **DRY source of truth** is `account.json` + `region.json`, not the per-stack tfvars.

Those identical files exist because **Terraform requires variables in (or pointed at) the stack directory**. There is no Terragrunt-style “read parent folders and merge.” Options people use:

1. **Generate at run time** (what Kos does) — parent JSON is canonical; tfvars are **derived artifacts**
2. Pass `-var-file=../../../something.tfvars` from a shared path (also fine; Python would still own the CLI)
3. Terragrunt / Atmos / etc. (hides the duplication)

So the duplication is the **delivery format**, not the source of truth. When you run the orchestrator (`plan`, `apply`, or `--dry-run-files-only`), `refresh_stack_files()` rewrites each stack’s tfvars from `account.json` / `region.json`.

**Stack-specific** settings (VPC CIDR, Cognito callbacks, Lambda env) live in `main.tf` — that is the real per-stack content (same role as Delphi’s `inputs = { ... }`).

### Do I need to update every `"account_id"` in every tfvars file?

**No.** Put real values in **`aws-kos-dev/account.local.json`** (gitignored). Committed `account.json` stays placeholders for the public repo.

The orchestrator merges `account.json` ← `account.local.json` (local wins), then regenerates each stack’s `terraform.tfvars.json` / `backend.hcl` (also gitignored).

```bash
cp aws-kos-dev/account.json.example aws-kos-dev/account.local.json
# edit account.local.json with real account_id, DNS role ARN, OIDC subjects, artifact bucket
python3 -m orchestrator plan --all --dry-run-files-only
```

### What should I edit vs leave alone?


| Edit this | Leave alone (orchestrator overwrites) |
| ----------------------------------- | ------------------------------------- |
| `account.local.json` (real IDs; gitignored) | Per-stack `terraform.tfvars.json` |
| `account.json` placeholders only (published) | Per-stack `backend.hcl` |
| Stack `main.tf` (resource-specific) | `audit/*.json` |
| `stacks.json` (add/reorder deps) | `stacks.yaml` (optional mirror) |
| Module code under `tf-modules/` | |


### Why is the state bucket empty after `plan`?

`**terraform plan` does not write remote state.** Only `**apply`** creates/updates objects under `s3://s3-kos-dev-ue1-terraform-state/…`.

An empty bucket after plan-only runs is expected. After a successful apply you should see keys like `us-east-1/cloudwatch_logging/terraform.tfstate`.

You usually do **not** need a custom bucket policy for the account that owns the bucket (SSO role in `aws-kos-dev` can read/write its own bucket). AccessDenied on PutObject/GetObject would be an IAM issue; `Unable to find remote state` means the key is missing because the dependency stack was never applied.

### Why did `plan --all` fail with `Unable to find remote state`?

Stacks that **consume** another stack’s outputs use `data.terraform_remote_state` (see that stack’s `remote_state.tf`). Terraform requires that parent’s state object to already exist in S3.


| Kind of dependency                                       | Where it lives                        | Needed for `plan`?                     |
| -------------------------------------------------------- | ------------------------------------- | -------------------------------------- |
| **Order-only** (Delphi `dependencies { paths = [...] }`) | `stacks.json` only                    | No — apply order hint for Python       |
| **Output wiring**                                        | `remote_state.tf` + used in `main.tf` | Yes — parent must be **applied** first |


So:

- `python3 -m orchestrator plan --all` will fail partway until upstream stacks have been applied.
- To bring up the **whole** landscape, use `**apply --all --execute`** (plans + applies each stack in DAG order so state exists for the next one).

### Do I need a bucket policy on the state bucket?

Not for the usual case. Create the bucket in the member account and use profile `aws-kos-dev`. Add a bucket policy only if a **different** account/role must access state (cross-account CI, etc.).

---

## Layout

```text
aws-kos/
├── stacks.json                 # stack graph (orchestrator source of truth)
├── stacks.yaml                 # optional human-readable mirror of stacks.json
├── orchestrator/               # Terragrunt replacement
├── tf-modules/                 # landscape-local Terraform modules
├── audit/                      # written by orchestrator (gitignored)
└── aws-kos-dev/
    ├── account.json            # committed placeholders (safe to publish)
    ├── account.local.json      # gitignored — real account IDs / OIDC subjects
    ├── account.json.example    # same as account.json (clone bootstrap)
    └── us-east-1/
        ├── region.json         # canonical region + region_short
        ├── vpc, cognito, cloudwatch_logging, github_oidc_*
        └── argus/              # rds, lambda, apigw, tls, cloudfront, dns, ssm, iam
```

Each stack directory is a Terraform root: `main.tf`, `variables.tf`, `providers.tf`, `versions.tf`, plus `remote_state.tf` / `outputs.tf` when the stack **reads** another stack’s outputs. Generated/refreshed: `terraform.tfvars.json`, `backend.hcl`.

Order-only edges (e.g. VPC after cloudwatch) live in `stacks.json` only — no unused `remote_state` data sources.

---

## Orchestrator behavior

Python owns what Terragrunt used to:

1. Load account/region config
2. Resolve stack dependency order (including transitive deps)
3. Refresh `terraform.tfvars.json` + `backend.hcl`
4. `terraform init` / `plan` (default); `apply` only with `--execute`
5. Write an audit JSON event (GxP-friendly narrative)
6. Refuse `--execute` while `account_id` is still a placeholder; refuse prod apply without `--i-know`

### Commands

```bash
cd ~/Projects/aws-kos

# List stacks / show apply order
python3 -m orchestrator list
python3 -m orchestrator order --all

# Refresh tfvars/backend only (no terraform / AWS needed)
python3 -m orchestrator plan --all --dry-run-files-only

# Plan one leaf stack (no remote_state deps), e.g. cloudwatch_logging or vpc
python3 -m orchestrator plan cloudwatch_logging
python3 -m orchestrator plan vpc

# Bring up the entire landscape (recommended)
# Applies in DAG order: each apply writes state so the next stack can plan.
python3 -m orchestrator apply --all --execute

# Or one stack at a time (still pulls transitive deps into the run list)
python3 -m orchestrator apply rds --execute
```

`apply` without `--execute` only plans (same as `plan`).

### Tests

```bash
cd ~/Projects/aws-kos
python3 -m unittest tests.test_orchestrator -v
```

---

## Before first apply

1. Vend account under `aws/us-east-1/aws-kos-dev` (copy `_template-account`).
2. Create local overrides (never commit):
   ```bash
   cp aws-kos-dev/account.json.example aws-kos-dev/account.local.json
   # set account_id, route53_account_id, dns_manager_role_arn,
   # artifact_bucket, oidc_subjects
   ```
3. Refresh generated files:
   ```bash
   python3 -m orchestrator plan --all --dry-run-files-only
   ```
4. Grant member account in mgmt shared services (`route53-dnsmgr`, shared Lambda bucket) if DNS/artifacts need it.
5. Log in and confirm the profile:
   ```bash
   aws sso login --profile aws-kos-dev
   aws sts get-caller-identity --profile aws-kos-dev
   ```
6. Create the Terraform state bucket (once per account/region):
   ```bash
   aws --profile aws-kos-dev s3 mb s3://s3-kos-dev-ue1-terraform-state --region us-east-1
   ```
7. Seed SSM SecureString values outside Terraform — never commit secrets.
8. Apply the landscape (writes state as it goes):
   ```bash
   python3 -m orchestrator apply --all --execute
   ```
9. Confirm state objects exist:
   ```bash
   aws --profile aws-kos-dev s3 ls s3://s3-kos-dev-ue1-terraform-state/ --recursive
   ```

Do **not** expect `plan --all` to succeed on a greenfield account before any applies — stacks with `remote_state.tf` need parent state in S3 first. Use `apply --all --execute` for the first bring-up.

---

## Publishing / local secrets

This repo is intended to be **private first, public later** as an IaC portfolio sample.

| Committed (safe) | Local only (gitignored) |
|---|---|
| `account.json` / `account.json.example` with `000000000000` placeholders | `account.local.json` with real account IDs, DNS role ARN, OIDC subjects, artifact bucket |
| Stack `main.tf` without hardcoded GitHub org/repo node IDs | Generated `terraform.tfvars.json`, `backend.hcl` |
| Modules, orchestrator, README | `audit/`, `.terraform/`, `*.tfstate*`, `.env*` |

Before `git push` (especially before making the repo public):

```bash
git status
# confirm account.local.json is NOT listed
git grep -E 'AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE' -- ':!*.lock.hcl' || true
```

Do not commit real AWS account IDs, GitHub OIDC subject node IDs, or SSM/DB passwords.

---

## Git: create the repo and push (ideal path)

`aws-kos` is not a git repo until you initialize it. Prefer **GitHub CLI** (`gh`) so the remote, default branch, and first push stay in one flow.

### Prerequisites

- `git` and `gh` installed (`gh auth status` succeeds)
- Decide visibility (`--private` recommended for IaC) and owner (`karlamber` or your org)

### One-shot create + push

```bash
cd ~/Projects/aws-kos

# 1. Local repo
git init -b main

# 2. First commit (respects .gitignore — no .terraform/, state, audit/, etc.)
git add .
git status   # sanity-check: no secrets, no .tfstate, no .terraform/
git commit -m "$(cat <<'EOF'
Initial aws-kos landscape: Python orchestrator + Terraform stacks.

EOF
)"

# 3. Create GitHub repo from this directory and push main
gh repo create aws-kos --private --source=. --remote=origin --push
```

If the repo should live under an org:

```bash
gh repo create YOUR_ORG/aws-kos --private --source=. --remote=origin --push
```

### Already created an empty GitHub repo?

```bash
cd ~/Projects/aws-kos
git init -b main
git add .
git commit -m "Initial aws-kos landscape: Python orchestrator + Terraform stacks."
git remote add origin git@github.com:YOUR_OWNER/aws-kos.git
git push -u origin main
```

### Day-2 workflow

```bash
git checkout -b PRDV-NNNN-short-description
# ... edit ...
git add -p
git commit -m "PRDV-NNNN: short description of why"
git push -u origin HEAD
gh pr create --fill
```

Team convention (when using ticket numbers): branch `PRDV-{number}-…`, commit `PRDV-{number}: …`.

### What must not be committed

Covered by `.gitignore`: `.terraform/`, `*.tfstate*`, `tfplan`, `audit/`, `account.local.json`, generated `terraform.tfvars.json` / `backend.hcl`, Python caches, `.venv/`, `.env*`.  
Still double-check `git status` before the first push — never commit SSO tokens, AWS keys, or real SSM SecureString values.

After the first successful `terraform init` on a machine, **do** commit any generated `.terraform.lock.hcl` files so provider versions stay reproducible across laptops/CI.

---

## Network

Account block `10.0.16.0/20`; us-east-1 VPC `10.0.16.0/21` (see `[docs/network-allocations.yaml](../docs/network-allocations.yaml)`). Does not overlap Delphi’s `10.0.0.0/20`.