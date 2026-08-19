# Shift-Left Security CI/CD Pipeline — Portfolio Log

**Project:** Building a secure CI/CD pipeline for a serverless (AWS Lambda) application, implementing shift-left security controls at every stage of the SDLC — from local pre-commit checks through automated CI gates to a protected, approval-gated production deployment.

**Stack:** Mac (local dev) · AWS Lambda · GitHub Actions · Python · Terraform · pytest · Gitleaks (secret scanning) · Bandit (SAST) · Trivy (dependency & IaC scanning) · Checkov (policy-as-code / IaC security) · CycloneDX (SBOM) · AWS IAM OIDC federation

**Repository:** https://github.com/duncan08/cicd-security-lab

**Target pipeline:**
`Mac → Local Checks → Feature Branch → Pull Request → CI Security Gates → Protected Main → DEV → Smoke Test → Production Approval → PROD → Verification/Rollback`

**Core security principle demonstrated:** PROD never deploys unless every mandatory security check (unit tests, secret scan, SAST, dependency scan, IaC scan, SBOM generation, Terraform plan) passes AND deployment is explicitly, manually approved.

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
| 6 | Security Gates (full 9-job PR pipeline) | ✅ PASS | See below |
| 7 | Protected Main branch | Not Started | — |
| 8+ | DEV deploy → Smoke Test → PROD approval → Verification/Rollback | Not Started | — |

---

## Stage 0 — Environment & Safety

**Date:** 2026-08-17

Toolchain (Git, AWS CLI, Terraform, Python) and AWS identity validated before any code or infrastructure existed. Planned AWS footprint: 1 Lambda (free tier), 1 IAM role, 1 short-retention CloudWatch Log Group. Estimated cost: $0. **PASS.**

---

## Stage 1 — CI/CD Fundamentals

**Date:** 2026-08-17

Repo, minimal Lambda + pytest suite, GitHub remote (SSH-vs-HTTPS auth troubleshooting), GitHub Actions CI (Checkout → Python setup → Dependencies → Unit tests). Proved CI is a real gate: broke a test → failed → fixed → passed. **PASS.**

---

## Stage 2 — Secret Scanning (Gitleaks)

**Date:** 2026-08-17

Three-layer secret scanning: pre-commit hook, CI gate, full-history awareness. Proved deleting a secret doesn't clear a history-scanning CI check; performed correct remediation via `git reset --hard` + force-push. **PASS.**

---

## Stage 3 — SAST & Dependencies (Bandit + Trivy)

**Date:** 2026-08-17

Bandit scans `src/` only, proven against an isolated negative-test fixture. Trivy dependency gate proven against a real CVE (`PyYAML==5.1`). **PASS** — 4 mandatory CI gates.

---

## Stage 4 — SBOM (CycloneDX)

**Date:** 2026-08-18

Generated, validated, and demonstrated real transitive dependencies in a CycloneDX SBOM; wired into CI as a 14-day-retention artifact, downloaded and confirmed valid. **PASS** — 5 mandatory CI gates.

---

## Stage 5 — Terraform & IaC Security (Checkov + Trivy IaC)

**Date:** 2026-08-18

Secure-by-default Lambda Terraform, 5 Checkov findings triaged with engineering judgment (1 fixed — X-Ray tracing; 4 documented, justified skips conflicting with this project's own cost/complexity constraints). Cross-checked with Trivy, including real scanner-specific ignore-syntax debugging (Checkov's `# checkov:skip=` vs. Trivy's stricter `#trivy:ignore:AVD-...` format). Both scanners proven to catch an isolated insecure fixture while staying clean on deployable infrastructure. **PASS** — 8 mandatory CI gates.

---

## Stage 6 — Security Gates (the full 9-job PR pipeline)

**Date:** 2026-08-19

**Concept:** "Scanning detects. Gating enforces." A finding that doesn't block anything is just a log entry. Stage 6 completes the required pipeline sequence — `Unit Tests → Secret Scan → SAST → Dependency Scan → Terraform Format → Terraform Validate → IaC Scan → SBOM → Terraform Plan` — by adding the final piece: **Terraform Plan**, which for the first time required CI to actually authenticate to AWS.

### 6a. AWS OIDC federation (no static credentials in CI)

Rather than storing a long-lived AWS access key as a GitHub secret, implemented **OIDC federation**: GitHub issues a short-lived, cryptographically signed identity token per workflow run; AWS trusts it via a registered OIDC provider and a purpose-built IAM role. Built from scratch:

- Created the `token.actions.githubusercontent.com` OIDC identity provider in IAM (account-level, one-time).
- Created `github-actions-terraform-plan`, an IAM role trusting that provider, with a trust policy scoped to this specific repository.
- Attached a **strictly read-only** inline policy (`Get*`/`List*`/`Describe*` only, across IAM, Lambda, and CloudWatch Logs) — this role is structurally incapable of running `apply`, even if compromised. (Stage 7 will introduce a second, more privileged role, scoped further to the protected `main` branch only, for actual deployment — deliberate privilege separation between "can preview" and "can change.")
- Stored the role ARN as a GitHub Actions secret and added the `terraform-plan` job using `aws-actions/configure-aws-credentials`.

### 6b. Real-world OIDC debugging — a genuine GitHub security feature, not a typo

First attempt failed: `Not authorized to perform sts:AssumeRoleWithWebIdentity`. Diagnosed methodically rather than guessing — in order: confirmed the trust policy's `Federated` principal matched the actual OIDC provider ARN (`diff`-based comparison, no credentials exposed); confirmed the OIDC provider's own `ClientIDList`/`ThumbprintList` were correctly registered; ruled out a corrupted GitHub secret by re-setting it via clipboard (`pbcopy`, stripped of trailing newline) rather than manual retyping. With every configuration element individually verified correct, added a temporary diagnostic job to decode and print (not the token itself, just its claims) the actual `aud`/`sub`/`iss` values GitHub was generating for this real workflow run.

That revealed the root cause: GitHub's `sub` claim was `repo:duncan08@7233330/cicd-security-lab@1337577260:ref:refs/heads/feature/terraform-plan-oidc` — **not** the assumed `repo:OWNER/REPO:ref:...` format. GitHub inserts immutable numeric IDs after the owner and repo name specifically to prevent a renamed repository or org from hijacking an old trust relationship — a real, intentional security hardening feature, not a bug. Fixed by updating the trust policy's `StringLike` condition to `repo:duncan08*/cicd-security-lab*:*`, tolerating the ID segments while still scoping tightly to this exact repository. Verified, removed the temporary debug job, re-ran clean.

### 6c. Full 9-job pipeline live

`terraform-plan` now runs a genuine `terraform plan` in CI, authenticated via short-lived OIDC credentials, producing a real infrastructure diff. All 9 jobs (unit tests, secret scan, SAST, dependency scan, SBOM, Terraform fmt, Terraform validate, IaC scan, Terraform plan) green on clean code.

### 6d. Break → stop → fix → pass, on the newest gate

Per Stage 6's requirement, deliberately broke a control and proved deployment stops: referenced a non-existent Terraform attribute (`aws_lambda_function.app.nonexistent_attribute`). This is a schema-level error, not a policy finding — resolved by the AWS provider plugin's schema (not Terraform core, which has no built-in knowledge of AWS resource shapes), caught statically with no AWS API call required. Both `Terraform Validate` and `Terraform Plan` independently failed with the identical error — genuine defense-in-depth, the same mistake caught by two separate gates. Reverted the reference; both passed again. Merged via PR with all 9 checks green.

**Skill demonstrated:** Secure, credential-less CI-to-cloud authentication (OIDC federation) built from first principles; privilege separation by design (read-only plan role, distinct from a future apply role); rigorous, evidence-based debugging of a genuine, undocumented-in-most-tutorials GitHub security behavior — verifying each layer independently before escalating to token-claim inspection, rather than guessing; and a clear technical explanation of *where* Terraform's schema validation actually lives (the provider plugin, not Terraform core).

---
