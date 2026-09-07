# aws-kos — Kos landscape (Python + Terraform)

This repo builds the same Argus app infrastructure as [`aws-delphi`](../aws-delphi), but drives Terraform with a small **Python** tool instead of **Terragrunt**.

In short: same AWS resources and modules, different way of running the stacks.

Hostnames in this lab use the **fifty9** domain (for example `argus-dev.fifty9.net`). The repo is meant as a learnable / portfolio example of multi-stack AWS infrastructure — keep it private while it contains real account details; publish later only after placeholders and gitignore are solid.

A third sibling, [`aws-delos`](../aws-delos), is the same landscape with plain Terraform only (`live/<env>/…` stacks — you `cd` into each folder yourself, no Terragrunt, no Python).

---

## Delphi vs Kos

| | Delphi (`aws-delphi`) | Kos (`aws-kos`) |
|---|---|---|
| What runs the stacks | Terragrunt | Python (`orchestrator/`) |
| Shared account settings | `account.hcl` + `root.hcl` | `account.json` + `region.json` |
| Which stack runs when | `dependency` blocks in HCL | `stacks.json` |
| How one stack reads another’s outputs | Terragrunt `dependency.x.outputs` | Terraform `data.terraform_remote_state` |

Do not run Kos until the `aws-kos-dev` AWS account exists and you have filled in local secret/config values (see [Before first apply](#before-first-apply)).

---

## How it works

Terraform only looks at files inside a stack folder. It cannot walk up to a parent folder and pull in shared settings the way Terragrunt does.

In Delphi, Terragrunt fills that gap. In Kos, the Python orchestrator does:

1. Read account and region settings (`account.json`, optional `account.local.json`, `region.json`)
2. Figure out stack order from `stacks.json` (including stacks that depend on other stacks)
3. Write each stack’s `terraform.tfvars.json` and `backend.hcl`
4. Run `terraform init` and `plan` (and `apply` only if you pass `--execute`)
5. Write a short audit record under `audit/`

Terraform still creates and changes AWS resources. Python only handles shared config, run order, safety checks, and audit logging.

### What you edit vs what Python generates

| File | Purpose |
|---|---|
| `aws-kos-dev/` or `aws-kos-prod/` `account.json` + gitignored `account.local.json` | Shared values: AWS account ID, DNS role, GitHub OIDC subjects, artifact bucket |
| `aws-kos-*/us-east-1/region.json` | AWS region and short region code |
| Each stack’s `main.tf` | Settings unique to that stack (VPC CIDRs, Cognito URLs, Lambda env, …) |
| Generated `terraform.tfvars.json` / `backend.hcl` | Written by the orchestrator before each run — **do not edit by hand** |

Many stacks end up with similar-looking tfvars files. That is normal: Terraform needs those values *inside* each stack folder. The single place to change shared values is still `account.json` / `account.local.json` / `region.json`. When you run the orchestrator, it rewrites the per-stack copies.

### Dependencies between stacks

`stacks.json` decides apply order. There are two kinds of relationships:

| Kind | Meaning | Needed before `plan`? |
|---|---|---|
| Order-only | “Run B after A” (same idea as Delphi’s `dependencies { paths = [...] }`) | No |
| Output wiring | Stack B reads values from stack A’s state via `remote_state.tf` | Yes — A must already be **applied** so its state file exists in S3 |

On a brand-new account, use `apply --all --execute`. That plans and applies each stack in order so state exists for the next one. Running `plan --all` alone will fail partway until those upstream stacks have been applied.

---

## Compared to Delphi (one stack)

Example: the `vpc` stack

| | Delphi | Kos |
|---|---|---|
| Where you edit stack settings | `vpc/terragrunt.hcl` | `vpc/main.tf` |
| Where the shared account ID comes from | Parent `account.hcl` (merged by Terragrunt) | `account.json` → written into tfvars by Python |
| How you run it | `terragrunt plan` in the stack folder | `python3 -m orchestrator plan vpc` |

Reusable modules live under `tf-modules/` in both repos. The application name is still **argus**.

---

## Layout

```text
aws-kos/
├── stacks.json                 # which stacks exist and what they depend on
├── stacks.yaml                 # same graph in YAML (for humans; Python does not read it)
├── orchestrator/               # Python replacement for Terragrunt
├── tf-modules/                 # shared Terraform modules for this landscape
├── audit/                      # run history written by the orchestrator (gitignored)
├── aws-kos-dev/
│   ├── account.json            # committed placeholders (safe to publish)
│   ├── account.local.json      # gitignored — your real account IDs and OIDC subjects
│   ├── account.json.example    # copy this to create account.local.json
│   └── us-east-1/
│       ├── region.json
│       ├── vpc, cognito, cloudwatch_logging, github_oidc_*
│       └── argus/              # rds, lambda, apigw, tls, cloudfront, dns, ssm, iam
└── aws-kos-prod/               # same stack layout; pass --account-dir aws-kos-prod
    ├── account.json
    └── us-east-1/…
```

Each stack folder is a normal Terraform root: `main.tf`, `variables.tf`, `providers.tf`, `versions.tf`, and when needed `remote_state.tf` / `outputs.tf`.

---

## Commands

```bash
cd ~/Projects/aws-kos

python3 -m orchestrator list
python3 -m orchestrator order --all

# Rewrite tfvars/backend only (no Terraform or AWS needed)
python3 -m orchestrator plan --all --dry-run-files-only

# Plan a single stack
python3 -m orchestrator plan cloudwatch_logging
python3 -m orchestrator plan vpc

# Create/update everything in dependency order
python3 -m orchestrator apply --all --execute

# One stack (still runs its dependencies first)
python3 -m orchestrator apply rds --execute

# Prod account folder (requires --i-know with --execute)
python3 -m orchestrator --account-dir aws-kos-prod plan --all --dry-run-files-only
python3 -m orchestrator --account-dir aws-kos-prod apply --all --execute --i-know
```

`apply` without `--execute` only plans — it does not change AWS. The orchestrator blocks `--execute` if `account_id` is still a placeholder, and blocks production applies unless you pass `--i-know`.

### Tests

```bash
python3 -m unittest tests.test_orchestrator -v
```

---

## Before first apply

1. Create the AWS account from the account-factory repo (`aws/us-east-1/aws-kos-dev`, copy `_template-account`).
2. Create your local config (never commit this file):
   ```bash
   cp aws-kos-dev/account.json.example aws-kos-dev/account.local.json
   # set account_id, route53_account_id, dns_manager_role_arn,
   # artifact_bucket, oidc_subjects
   ```
3. Generate per-stack tfvars and backend files:
   ```bash
   python3 -m orchestrator plan --all --dry-run-files-only
   ```
4. If this environment needs DNS or shared Lambda artifacts, grant the member account access in the management shared-services account (`route53-dnsmgr`, shared Lambda bucket).
5. Sign in and confirm you are in the right account:
   ```bash
   aws sso login --profile aws-kos-dev
   aws sts get-caller-identity --profile aws-kos-dev
   ```
6. Create the S3 bucket that stores Terraform state (once per account/region):
   ```bash
   aws --profile aws-kos-dev s3 mb s3://s3-kos-dev-ue1-terraform-state --region us-east-1
   ```
7. Put secrets into SSM Parameter Store yourself (SecureString). Do not put real passwords in Terraform or git.
8. Apply the landscape:
   ```bash
   python3 -m orchestrator apply --all --execute
   ```
9. Confirm state files appeared in the bucket:
   ```bash
   aws --profile aws-kos-dev s3 ls s3://s3-kos-dev-ue1-terraform-state/ --recursive
   ```

`terraform plan` only previews changes; it does not write state to S3. An empty bucket after plan-only runs is normal. State appears after a successful `apply`.

---

## What belongs in git vs what stays local

| Safe to commit | Keep local (gitignored) |
|---|---|
| `account.json` / `account.json.example` with placeholder IDs | `account.local.json` with real account IDs, DNS role ARN, OIDC subjects, artifact bucket |
| Stack `main.tf` without hardcoded GitHub org/repo node IDs | Generated `terraform.tfvars.json`, `backend.hcl` |
| Modules, orchestrator, README | `audit/`, `.terraform/`, `*.tfstate*`, `.env*` |

Before you push (especially before making the repo public):

```bash
git status
# confirm account.local.json is NOT listed
git grep -E 'AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE' -- ':!*.lock.hcl' || true
```

Do not commit real AWS account IDs, GitHub OIDC subject IDs, or database/SSM passwords. After the first successful `terraform init` on a machine, **do** commit any generated `.terraform.lock.hcl` files so everyone uses the same provider versions.

---

## Network

Each env account gets its own `/20` (no CIDR overlap between dev and prod):

| Account folder | Account block | us-east-1 VPC | Set in |
|---|---|---|---|
| `aws-kos-dev` | `10.0.16.0/20` | `10.0.16.0/21` | `aws-kos-dev/us-east-1/vpc/main.tf` |
| `aws-kos-prod` | `10.0.64.0/20` | `10.0.64.0/21` | `aws-kos-prod/us-east-1/vpc/main.tf` |

These blocks do not overlap Delphi (`10.0.0.0/20` dev, `10.0.48.0/20` prod) or Delos (`10.0.32.0/20` dev, `10.0.80.0/20` prod).
