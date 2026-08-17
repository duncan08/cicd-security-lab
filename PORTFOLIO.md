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
| 3 | SAST & Dependencies (Bandit, Trivy) | Not Started | — |
| 4 | SBOM (CycloneDX) | Not Started | — |
| 5 | Terraform & IaC Security (Checkov, Trivy IaC) | Not Started | — |
| 6 | Security Gates (full PR pipeline) | Not Started | — |
| 7 | Protected Main branch | Not Started | — |
| 8+ | DEV deploy → Smoke Test → PROD approval → Verification/Rollback | Not Started | — |

---

## Stage 0 — Environment & Safety

**Date:** 2026-08-17

**Concept:** Before any code is written or any AWS resource touched, confirm the toolchain is installed and AWS credentials resolve to the expected identity/account. This is the earliest possible point to prevent accidental changes in the wrong environment — a foundational shift-left practice: verify context before you build, not after.

**Commands run and evidence:**

```
$ git --version
git version 2.50.1 (Apple Git-155)

$ aws --version
aws-cli/2.36.8 Python/3.14.6 Darwin/25.5.0 exe/x86_64

$ terraform version
Terraform v1.15.8

$ python3 --version
Python 3.13.5

$ aws sts get-caller-identity
(confirmed: valid UserId, Account, and Arn returned — AWS CLI access confirmed)
```

**Result:** PASS — full toolchain (Git, AWS CLI, Terraform, Python 3) installed and current; AWS credentials active and resolving to a known identity.

**Planned AWS footprint (cost control):** 1 Lambda function (free-tier: 1M requests + 400,000 GB-seconds/month), 1 minimal-scope IAM execution role (no cost), 1 CloudWatch Log Group with short retention (1–3 days, negligible cost). No EC2/EKS/ECS, no NAT Gateway, no load balancer, no RDS, no API Gateway (Lambda invoked directly via CLI to avoid an always-on HTTP endpoint). Estimated cost: **$0**, with teardown planned at lab completion.

**Skill demonstrated:** Environment validation and blast-radius planning before any infrastructure exists.

---

## Stage 1 — CI/CD Fundamentals

**Date:** 2026-08-17

**Concept:** Establish the repo and the smallest possible testable application — a Lambda handler with business logic separated into a pure function — then prove it locally before any CI system ever sees it, and finally automate that same proof in GitHub Actions. This stage covers the core SDLC vocabulary: repo, commit, branch, PR, workflow, runner, build, test.

### 1a. Repository initialized

```
$ git init
$ git status
On branch main
No commits yet
```

Result: PASS.

### 1b. Application scaffolded

```
src/lambda_function.py         Lambda handler + pure build_greeting() function
tests/test_lambda_function.py  4 pytest unit tests
pytest.ini                     Test discovery config (pythonpath = src)
requirements.txt               Runtime deps (empty — stdlib only)
requirements-dev.txt           Dev tooling: pytest==8.3.3
.gitignore                     Excludes __pycache__, venv, secrets, build artifacts
README.md                      Project overview + local setup instructions
```

Design decision: `requirements.txt` (what ships to prod) is kept separate from `requirements-dev.txt` (local tooling) — matters again in Stage 3 when dependency scanning needs to target what actually deploys.

### 1c. Local unit tests — proof before CI exists

```
$ pip3 install -r requirements-dev.txt --break-system-packages
$ python3 -m pytest -v
tests/test_lambda_function.py::test_build_greeting_with_name PASSED             [ 25%]
tests/test_lambda_function.py::test_build_greeting_default_when_empty PASSED    [ 50%]
tests/test_lambda_function.py::test_lambda_handler_returns_200 PASSED           [ 75%]
tests/test_lambda_function.py::test_lambda_handler_defaults_when_no_name PASSED [100%]
```

Result: PASS — 4/4 unit tests passed locally, before automating the same check.

### 1d. First commit + Git identity correction

```
$ git add .
$ git commit -m "Add minimal Lambda handler with pytest unit tests"
[main (root-commit) 31ad9a4] Add minimal Lambda handler with pytest unit tests
```

Git auto-inferred committer identity (`rgrullon@wonderland.local`). Corrected before this became public portfolio history:

```
$ git config --global user.name "Robinson Grullon"
$ git config --global user.email "<github-associated email>"
$ git commit --amend --reset-author --no-edit
```

Result: PASS.

### 1e. Feature branch + GitHub remote (with real-world SSH troubleshooting)

```
$ git checkout -b feature/ci-workflow
```

Created GitHub remote `duncan08/cicd-security-lab` (empty — no auto-generated README/.gitignore/license, to avoid diverging histories with the local repo).

Hit and resolved a realistic auth issue: HTTPS push was rejected (`Password authentication is not supported for Git operations`). Diagnosed that the remote was still HTTPS despite having SSH keys — `git remote -v` confirmed it. Fixed by loading an existing key (`terraform-learning-key`) into the SSH agent, verifying with `ssh -T git@github.com` → `Hi duncan08! You've successfully authenticated`, then repointing the remote:

```
$ git remote set-url origin git@github.com:duncan08/cicd-security-lab.git
$ git push -u origin main
$ git push -u origin feature/ci-workflow
```

Result: PASS — both branches live on GitHub over SSH.

**Skill demonstrated:** Diagnosing and fixing real Git authentication failures (HTTPS-vs-SSH remote misconfiguration), not just following a script.

### 1f. GitHub Actions CI workflow

`.github/workflows/ci.yml` — Checkout → Python setup → Install dependencies → Run unit tests, triggered on push to `main`/`feature/**` and on PRs to `main`.

First automated run: **Status Success, 13s total duration.**

### 1g. Proving CI is a real gate, not decoration

Deliberately broke `test_build_greeting_with_name`, committed, pushed — **CI FAILED**, red X on the "Run unit tests" step. (Caught and corrected a false-pass along the way: an initial `sed` edit silently failed to apply due to shell quoting around the `!` character — verified via `cat` before trusting the result.) Restored the correct assertion, committed, pushed — **CI PASSED** again.

### 1h. Pull Request → Protected merge to main

Opened a PR (`feature/ci-workflow` → `main`). CI ran again automatically as a PR check. Merged once green.

**Skill demonstrated:** Full local-to-CI feedback loop — branch, automate, break, catch, fix, verify, review, merge.

---

## Stage 2 — Secret Scanning (Gitleaks)

**Date:** 2026-08-17

**Concept:** A hardcoded credential committed to Git is one of the most common, costly security incidents — Git history is permanent, and once pushed, a secret must be treated as compromised regardless of whether it's later deleted. Gitleaks can run at three points in the SDLC: **pre-commit** (local, earliest/cheapest), **CI** (the mandatory safety net), and **full-history scan** (catches what predates scanning, or slipped through). This stage proved all three — including an unplanned but highly instructive detour into *why* pre-commit beats after-the-fact cleanup.

### 2a. Install + baseline

```
$ brew install gitleaks
$ gitleaks version
8.30.1

$ gitleaks detect --source . -v
4 commits scanned.
no leaks found
```

Result: PASS — clean baseline established before introducing anything synthetic.

### 2b. Pre-commit layer — detection, with a real debugging detour

First attempt used a synthetic AWS Access Key pattern (`AKIA1234567890ABCDEF`) — unexpectedly returned `no leaks found` even on a direct filesystem scan bypassing Git entirely. Diagnosed systematically (confirmed the file was genuinely staged via `git diff --staged`, ruled out `.gitignore`, ruled out a stray custom config) before concluding the installed Gitleaks ruleset wasn't matching that specific pattern as expected — a real lesson that scanner rule coverage varies by version and should never be assumed.

Pivoted to a private-key PEM header (`-----BEGIN RSA PRIVATE KEY-----`) — one of the simplest, least ambiguous secret patterns (pure regex match, no entropy/keyword dependency):

```
$ gitleaks protect --staged -v
```

Result: PASS — leak detected (`RuleID: private-key`).

### 2c. Pre-commit hook — automated local enforcement

Installed a native Git hook (`.git/hooks/pre-commit`) running `gitleaks protect --staged` automatically before every commit:

```
$ git commit -m "TEST: this commit should be blocked by the pre-commit hook"
```

Result: PASS — commit refused automatically; the secret never entered Git history at all. Cleaned up (`git reset` + `rm`) and confirmed `git status` returned to clean — proving zero trace was left, because it was never committed.

**Key limitation surfaced:** `.git/hooks/` is local-only and not tracked by Git — it does not travel with the repo to other contributors. This is the direct justification for the next layer.

### 2d. CI layer — the safety net that can't be skipped

Added a second job, `secret-scan`, to `.github/workflows/ci.yml`, installing Gitleaks in the runner and running `gitleaks detect --source . -v` (`fetch-depth: 0` to scan full history, not just the latest commit). Verified clean baseline first — both `Unit Tests` and `Secret Scan (Gitleaks)` green on unmodified code.

Reintroduced the synthetic private-key secret, this time deliberately bypassing the local hook with `git commit --no-verify` — simulating a contributor without the hook installed:

- **Result: CI FAILED** — `Secret Scan (Gitleaks)` red X, `Unit Tests` unaffected (independent job pass/fail). Proof the mandatory gate works even when the first layer is skipped.

### 2e. The unplanned lesson — why earlier detection is stronger

Attempted the "obvious" fix: delete the secret file, commit, push. **CI failed again**, even though the file was gone from the working tree. Root cause: `gitleaks detect` scans full commit **history**, not just the latest snapshot — the secret was still present in the earlier commit that introduced it. This is the exact real-world failure mode `full-history detection` exists to catch, and it directly demonstrates the stage's core lesson:

- **Pre-commit** — secret never becomes a commit. Nothing to clean up, ever.
- **CI on push** — catches it before merge, but by then it's already a commit and already sent to GitHub's servers.
- **Delete-and-recommit is cosmetic, not remediation** — the exposure already happened; the data is still retrievable from history.

**Correct remediation performed:** identified the last clean commit (`git log --oneline`), then rewrote the branch's history to remove the secret-introducing and secret-deleting commits entirely:

```
$ git reset --hard 331c2c0
$ git push --force
```

Result: PASS — with the secret commit gone from history (not just the file), both CI jobs passed cleanly. (In a real incident, the credential itself would also need to be rotated immediately, regardless of history cleanup, since a pushed secret must be assumed compromised the moment it left the local machine — synthetic here, so no rotation needed.)

### 2f. Pull Request → merge

Opened and merged the PR (`feature/gitleaks-ci` → `main`) with both checks green and a history clean of the synthetic secret.

**Skill demonstrated:** Full defense-in-depth secret-scanning implementation (pre-commit hook + CI gate + history awareness), systematic debugging of an unexpected scanner false-negative, and — critically — hands-on proof of *why* shift-left detection beats after-the-fact cleanup, including the correct incident-response pattern (rotate + rewrite history) rather than the naive one (delete + recommit).

---
