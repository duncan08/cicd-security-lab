# Shift-Left Security CI/CD Lab

A minimal AWS Lambda project used to learn and demonstrate Shift-Left
Security practices across the full SDLC: local checks, pull-request
security gates, infrastructure-as-code scanning, SBOM generation, and a
protected, approval-gated deployment pipeline.

See `PORTFOLIO.md` for a full stage-by-stage log of what was built and why.

## Project layout

```
src/                  Lambda source code
tests/                pytest unit tests
requirements.txt      Runtime dependencies (ships with the Lambda)
requirements-dev.txt  Local/dev tooling (pytest, etc.)
```

## Local setup

```bash
pip3 install -r requirements-dev.txt
python3 -m pytest -v
```

## Stack

Mac · AWS Lambda · GitHub Actions · Python · Terraform · pytest ·
Gitleaks · Bandit · Trivy · Checkov
