# Deployment Scripts

Simple scripts for deploying the Amazon Bedrock PR Code Reviewer.

## Scripts

| Script | Description |
|--------|-------------|
| `setup-aws.sh` | Create IAM user, policy, and access keys |
| `setup-github.sh` | Configure GitHub repository secrets |
| `deploy.sh` | Full deployment: AWS + GitHub + git push |
| `run-local.sh` | Run code review locally on any PR |
| `cleanup.sh` | Remove all AWS and GitHub resources |

## Quick Start

### Full Deployment (GitHub Action)

```bash
# 1. Set up AWS (creates IAM user with Bedrock access)
./scripts/setup-aws.sh

# 2. Configure GitHub secrets
./scripts/setup-github.sh

# 3. Push code and create a PR - the action runs automatically!
```

### Local Testing Only

```bash
# Set credentials
export GITHUB_TOKEN='ghp_...'
export AWS_ACCESS_KEY_ID='AKIA...'
export AWS_SECRET_ACCESS_KEY='...'

# Review a PR locally (dry-run)
./scripts/run-local.sh --pr 123 --dry-run
```

### One-Command Deployment

```bash
# Does everything: AWS setup + GitHub secrets + git push
./scripts/deploy.sh
```

### Cleanup

```bash
# Remove all AWS resources and GitHub secrets
./scripts/cleanup.sh
```

## Requirements

- **Bash** (macOS/Linux or Git Bash on Windows)
- **AWS CLI** configured with admin access
- **GitHub CLI** (`gh`) authenticated
- **Python 3.9+** (for local testing)
