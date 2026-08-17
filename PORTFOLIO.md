# Shift-Left Security CI/CD Pipeline — Portfolio Log

**Project:** Building a secure CI/CD pipeline for a serverless (AWS Lambda) application, implementing shift-left security controls at every stage of the SDLC — from local pre-commit checks through automated CI gates to a protected, approval-gated production deployment.

**Stack:** Mac (local dev) · AWS Lambda · GitHub Actions · Python · Terraform · pytest · Gitleaks (secret scanning) · Bandit (SAST) · Trivy (dependency & IaC scanning) · Checkov (policy-as-code / IaC security)

**Target pipeline:**
`Mac → Local Checks → Feature Branch → Pull Request → CI Security Gates → Protected Main → DEV → Smoke Test → Production Approval → PROD → Verification/Rollback`

**Core security principle demonstrated:** PROD never deploys unless every mandatory security check (unit tests, secret scan, SAST, dependency scan, IaC scan, SBOM generation) passes AND deployment is explicitly, manually approved.

This log documents each stage as it's completed: the security concept, the exact tooling/commands used, the evidence produced, and the pass/fail outcome. It's written to double as portfolio material — proof of hands-on DevSecOps skill, not just a knowledge claim.

---

## Stage Tracker

| Stage | Control | Status | Evidence |
|---|---|---|---|
| 0 | Environment & Safety validation | ✅ PASS | See below |
| 1 | CI/CD Fundamentals (repo, Lambda, pytest, GitHub Actions) | Not Started | — |
| 2 | Secret Scanning (Gitleaks) | Not Started | — |
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
