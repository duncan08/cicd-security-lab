# Shift-Left Security CI/CD Pipeline — Portfolio Log

**Project:** Building a secure CI/CD pipeline for a serverless (AWS Lambda) application, implementing shift-left security controls at every stage of the SDLC — from local pre-commit checks through automated CI gates to a protected, approval-gated production deployment.

**Stack:** Mac (local dev) · AWS Lambda · GitHub Actions · Python · Terraform · pytest · Gitleaks (secret scanning) · Bandit (SAST) · Trivy (dependency & IaC scanning) · Checkov (policy-as-code / IaC security)

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
| 4 | SBOM (CycloneDX) | Not Started | — |
| 5 | Terraform & IaC Security (Checkov, Trivy IaC) | Not Started | — |
| 6 | Security Gates (full PR pipeline) | Not Started | — |
| 7 | Protected Main branch | Not Started | — |
| 8+ | DEV deploy → Smoke Test → PROD approval → Verification/Rollback | Not Started | — |

---

## Stage 0 — Environment & Safety

**Date:** 2026-08-17

**Concept:** Before any code is written or any AWS resource touched, confirm the toolchain is installed and AWS credentials resolve to the expected identity/account.

**Result:** PASS — Git 2.50.1, AWS CLI 2.36.8, Terraform 1.15.8, Python 3.13.5, valid AWS identity confirmed. Planned AWS footprint: 1 Lambda (free tier), 1 IAM execution role, 1 CloudWatch Log Group (short retention). No EC2/EKS/ECS/NAT/LB/RDS/API Gateway. Estimated cost: $0.

---

## Stage 1 — CI/CD Fundamentals

**Date:** 2026-08-17

**Concept:** Establish the repo and a minimal testable Lambda, prove it locally, then automate the same proof in GitHub Actions. Covers repo, commit, branch, PR, workflow, runner, build, test.

**Highlights:**
- Repo initialized, Lambda handler + pure `build_greeting()` function + 4 pytest unit tests scaffolded, all passing locally before any CI existed.
- Corrected Git committer identity before pushing (auto-guessed local hostname email → real identity), since this repo is public portfolio evidence.
- Diagnosed and fixed a real GitHub authentication failure: HTTPS push rejected (password auth deprecated) → confirmed via `git remote -v` the remote was still HTTPS despite SSH keys existing → loaded existing key into agent, verified with `ssh -T git@github.com`, repointed remote to SSH, pushed successfully.
- Built `.github/workflows/ci.yml` (Checkout → Python setup → Dependencies → Unit tests). First run: Success, 13s.
- **Proved CI is a real gate:** deliberately broke a test → CI red X → fixed it → CI green. (Along the way, caught a `sed` edit that silently failed to apply due to shell quoting around `!` — verified with `cat` before trusting the result.)
- Opened and merged first PR, with CI running as a PR check.

**Result:** PASS.

---

## Stage 2 — Secret Scanning (Gitleaks)

**Date:** 2026-08-17

**Concept:** A committed secret must be treated as compromised the moment it's pushed, regardless of later deletion. Gitleaks was implemented at three layers: pre-commit (local), CI (mandatory), and full-history awareness.

**Highlights:**
- Installed Gitleaks 8.30.1; established a clean baseline scan.
- Hit and systematically debugged a scanner false-negative: a synthetic AWS Access Key pattern wasn't detected even on a raw filesystem scan. Ruled out staging and `.gitignore` issues before concluding it was a ruleset/version quirk, and pivoted to a private-key PEM header pattern — simpler, unambiguous, reliably detected.
- Installed a local `.git/hooks/pre-commit` hook — proved it **blocks a commit outright**, so the secret never enters history at all. Noted the key limitation: hooks are local-only and don't travel with the repo, which is the direct justification for a CI-level gate.
- Added a `secret-scan` CI job (full-history Gitleaks scan). Proved it catches a secret pushed via `git commit --no-verify` (simulating a contributor without the hook).
- **Unplanned but core lesson:** deleting the secret file and committing that deletion did **not** clear CI — because `gitleaks detect` scans full commit history, and the secret was still present in an earlier commit. This directly proved why pre-commit prevention beats after-the-fact cleanup. Performed the *correct* remediation: identified the last clean commit and used `git reset --hard` + `git push --force` to actually remove the secret-containing commits from history, not just their content.

**Result:** PASS.

---

## Stage 3 — SAST & Dependencies (Bandit + Trivy)

**Date:** 2026-08-17

**Concept:** Two more categories of risk beyond secrets: **SAST** (insecure patterns in your own code — Bandit) and **SCA/dependency scanning** (known CVEs in third-party packages — Trivy). Both are mandatory CI gates that must return non-zero status on findings, same enforcement model as Stages 1–2.

### 3a. Bandit (SAST)

- Installed Bandit 1.8.3; baseline scan of `src/` — clean (`No issues identified`).
- Created an isolated negative-test fixture, `negative-tests/bandit/insecure_examples.py` — 4 classic vulnerability patterns (hardcoded password, `eval()` on untrusted input, MD5 for security use, `subprocess` shell injection via `shell=True`). Clearly commented as a test-only fixture; never imported by `src/`, never deployed.
- Confirmed locally that Bandit flags all 4 issues (`bandit -r negative-tests/`) before wiring into CI.
- Added a `sast` CI job scanning **`src/` only** — the actual deployable code, mirroring the `requirements.txt` vs `requirements-dev.txt` split from Stage 1. All 4 CI jobs green on clean code.
- **Proved the gate is real:** temporarily widened the CI scan path to include `negative-tests/` → CI failed with all 4 findings, non-zero exit. Reverted the scan path to `src/` only → CI passed again.

### 3b. Trivy (Dependency / SCA scan)

- Installed Trivy 0.74.0; baseline scan (`trivy fs --scanners vuln --severity HIGH,CRITICAL .`) — clean, since `requirements.txt` ships no runtime dependencies.
- Added a `dependency-scan` CI job using the official `aquasecurity/trivy-action`, filtering to `HIGH,CRITICAL` severity as the mandatory threshold. All 4 CI jobs green on clean code.
- **Proved the gate is real:** temporarily pinned a genuinely outdated, CVE-known package (`PyYAML==5.1`, critical arbitrary-code-execution CVE) into `requirements.txt` → CI failed with the CVE listed. Removed the pin, reverted to the clean `requirements.txt` → CI passed again.

### 3c. Final state

All four CI jobs (`Unit Tests`, `Secret Scan`, `SAST`, `Dependency Scan`) pass on `main` after merge, satisfying Stage 3's requirement: Unit Tests PASS, SAST PASS, Dependency Scan PASS, with every mandatory finding proven capable of returning non-zero CI status.

**Skill demonstrated:** End-to-end SAST and SCA gate implementation with real proof of enforcement (not just tool installation) — including using a genuine outdated dependency (not synthetic code) to validate the SCA gate against a real-world CVE.

---
