# Shift-Left Security CI/CD Pipeline — Portfolio Log

**Project:** Building a secure CI/CD pipeline for a serverless (AWS Lambda) application, implementing shift-left security controls at every stage of the SDLC — from local pre-commit checks through automated CI gates to a protected, approval-gated production deployment.

**Stack:** Mac (local dev) · AWS Lambda · GitHub Actions · Python · Terraform · pytest · Gitleaks (secret scanning) · Bandit (SAST) · Trivy (dependency & IaC scanning) · Checkov (policy-as-code / IaC security) · CycloneDX (SBOM)

**Repository:** https://github.com/duncan08/cicd-security-lab

**Target pipeline:**
`Mac → Local Checks → Feature Branch → Pull Request → CI Security Gates → Protected Main → DEV → Smoke Test → Production Approval → PROD → Verification/Rollback`

**Core security principle demonstrated:** PROD never deploys unless every mandatory security check (unit tests, secret scan, SAST, dependency scan, IaC scan, SBOM generation) passes AND deployment is explicitly, manually approved.

This log documents each stage as it's completed: the security concept, the exact tooling/commands used, the evidence produced, and the pass/fail outcome. It's written to double as portfolio material — proof of hands-on DevSecOps skill, not just a knowledge claim.

---

## Stage Tracker

| Stage | Control | Status | Evidence |
|---|---|---|---|
| 0 | Environment & Safety validation | ✅ PASS | See below |
| 1 | CI/CD Fundamentals (repo, Lambda, pytest, GitHub Actions) | ✅ PASS | See below |
| 2 | Secret Scanning (Gitleaks) | ✅ PASS | See below |
| 3 | SAST & Dependencies (Bandit, Trivy) | ✅ PASS | See below |
| 4 | SBOM (CycloneDX) | ✅ PASS | See below |
| 5 | Terraform & IaC Security (Checkov, Trivy IaC) | ✅ PASS | See below |
| 6 | Security Gates (full PR pipeline) | Not Started | — |
| 7 | Protected Main branch | Not Started | — |
| 8+ | DEV deploy → Smoke Test → PROD approval → Verification/Rollback | Not Started | — |

---

## Stage 0 — Environment & Safety

**Date:** 2026-08-17

Toolchain (Git 2.50.1, AWS CLI 2.36.8, Terraform 1.15.8, Python 3.13.5) and AWS identity validated before any code or infrastructure existed. Planned AWS footprint: 1 Lambda (free tier), 1 IAM role, 1 short-retention CloudWatch Log Group. No EC2/EKS/ECS/NAT/LB/RDS/API Gateway. Estimated cost: $0. **Result: PASS.**

---

## Stage 1 — CI/CD Fundamentals

**Date:** 2026-08-17

Repo, minimal Lambda + pytest suite, GitHub remote (with a real SSH-vs-HTTPS auth troubleshooting detour), and a GitHub Actions CI workflow (Checkout → Python setup → Dependencies → Unit tests). Proved CI is a real gate: broke a test → CI failed → fixed it → CI passed. Opened and merged first PR. **Result: PASS.**

---

## Stage 2 — Secret Scanning (Gitleaks)

**Date:** 2026-08-17

Three-layer secret scanning: local pre-commit hook (blocks a commit outright — secret never enters history), CI gate (catches secrets pushed via `--no-verify` bypass), and a hands-on lesson in full-history exposure — deleting a secret in a follow-up commit did **not** clear the CI scan, because `gitleaks detect` scans full history. Performed the correct remediation: `git reset --hard` + `git push --force` to actually remove the secret-containing commits, not just their content. **Result: PASS.**

---

## Stage 3 — SAST & Dependencies (Bandit + Trivy)

**Date:** 2026-08-17

Bandit (SAST) scans `src/` only, proven to fail on 4 planted vulnerability patterns in an isolated `negative-tests/bandit/` fixture and pass when clean. Trivy (SCA) dependency gate proven against a real CVE — temporarily pinned `PyYAML==5.1`, watched CI fail, reverted, watched it pass. **Result: PASS** — 4 mandatory CI gates on `main`.

---

## Stage 4 — SBOM (CycloneDX)

**Date:** 2026-08-18

Generated a CycloneDX SBOM in a clean throwaway venv, validated it (JSON structure, `bomFormat`, component count), and demonstrated real transitive dependencies (`PyYAML`, `stevedore`, `rich`, `pluggy` — none installed directly). Wired into CI as a job that generates and uploads `sbom.cdx.json` via `actions/upload-artifact` (14-day retention); downloaded and confirmed the artifact was valid and retained. **Result: PASS** — 5 mandatory CI gates on `main`.

---

## Stage 5 — Terraform & IaC Security (Checkov + Trivy IaC)

**Date:** 2026-08-18

**Concept:** Infrastructure as Code (Terraform) makes infrastructure changes reviewable in a PR like application code. Policy-as-code (Checkov, Trivy's IaC scanner) encodes security rules — encryption, least privilege, public exposure — as automated CI checks instead of manual review.

### 5a. Secure-by-default Terraform for the Lambda

Wrote `terraform/` (provider, variables, IAM role, Lambda, log group, outputs) — least-privilege IAM (logging permissions scoped to this function's specific log group ARN, never `"*"`), an explicitly created log group with short (3-day) retention, no public exposure, and `reserved_concurrent_executions` as a free cost/blast-radius cap (distinct from *provisioned* concurrency, which this project avoids). `terraform fmt -check` and `terraform validate` both clean — no AWS resources touched.

### 5b. Real Checkov findings, triaged with judgment, not blanket compliance

Initial scan surfaced 5 findings. Rather than reflexively "fixing" all of them, each was individually reasoned through:

| Finding | Decision | Why |
|---|---|---|
| No X-Ray tracing | **Fixed** | Free tier, cheap, genuine observability value — added `tracing_config { mode = "Active" }` + scoped IAM permissions |
| Log retention < 1 year | **Documented skip** | Directly conflicts with this project's own short-retention, low-cost design goal |
| No VPC | **Documented skip** | A VPC would require a NAT Gateway for outbound access — exactly what this project's instructions say to avoid; nothing here needs VPC-only resources |
| No Dead Letter Queue | **Documented skip** | DLQs matter for async invocations; this Lambda is only ever invoked synchronously in this lab |
| No code signing | **Documented skip** | Real production value in a multi-team pipeline; disproportionate overhead for a single-developer lab |

Each decision was written directly into the Terraform as a `checkov:skip=<ID>:<reason>` comment — a documented, auditable exception, not a silently ignored finding. Re-scan: clean, with only the intentional skips showing.

### 5c. Cross-checked with a second scanner (Trivy), including real ignore-syntax debugging

`trivy config .` flagged the same KMS-encryption trade-off under its own rule ID (`AVD-AWS-0017`). Applying the same documented-exception approach took two attempts: Trivy's inline-ignore comment requires no space after `#`, the full `AVD-`-prefixed rule ID (not the short form printed in output), and must sit on the line immediately before the resource block — none of which matched the first attempt (`# trivy:ignore:AWS-0017`, inside the block). Diagnosed via the actual scanner output rather than guessing twice, corrected to `#trivy:ignore:AVD-AWS-0017` directly above the resource, verified locally before pushing again.

### 5d. Proving detection — isolated negative-test fixture

Created `negative-tests/terraform/insecure_examples.tf` — a public-read S3 bucket, a wildcard (`Action: *`, `Resource: *`) IAM policy, and a security group open to `0.0.0.0/0` on all ports. Standalone, never referenced by `terraform/`, never applied. Both Checkov and Trivy independently flagged multiple violations against it (Test A: `insecure IaC → violation detected → FAIL`), while the deployable `terraform/` stayed clean (Test B: `deployable IaC → validation PASS → security PASS`).

### 5e. CI gates — proven real, not decorative

Added three CI jobs: `terraform-fmt`, `terraform-validate` (both credential-free — `init -backend=false`), and `iac-scan` (Checkov + Trivy config, scoped to `terraform/` only). All 8 jobs (unit tests, secret scan, SAST, dependency scan, SBOM, fmt, validate, IaC scan) green on clean code. Then, same fail → fix → pass pattern as every prior gate: temporarily widened the IaC scan to include `negative-tests/terraform/` → CI failed on the planted findings → reverted → CI passed again. Merged via PR with all 8 checks green.

**Skill demonstrated:** Dual-scanner IaC security implementation with genuine engineering judgment — not every finding was "fixed" by adding resources; several were deliberately and transparently accepted as trade-offs against this project's own explicit cost/complexity constraints, documented in-line for anyone auditing the code later. Also: real debugging of scanner-specific ignore-comment syntax using actual tool output rather than assumption.

---
