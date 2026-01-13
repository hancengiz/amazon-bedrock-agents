# Deployment Scripts

Scripts for deploying the Amazon Bedrock Agent PR Code Reviewer.

## Scripts

| Script | Description |
|--------|-------------|
| `01-setup-aws.sh` | Create IAM user, policy, and access keys |
| `02-create-bedrock-agent.sh` | Create the Bedrock Agent for code review |
| `03-setup-github.sh` | Configure GitHub repository secrets |
| `04-deploy.sh` | Full deployment (all steps + git push) |
| `05-cleanup.sh` | Remove all AWS and GitHub resources |

## Deployment Steps

```bash
# 1. Create IAM user with Bedrock permissions
./scripts/01-setup-aws.sh

# 2. Create the Bedrock Agent
./scripts/02-create-bedrock-agent.sh

# 3. Configure GitHub secrets
./scripts/03-setup-github.sh

# 4. Push code and create a PR - the action runs automatically!
```

## One-Command Deployment

```bash
# Does everything: AWS setup + Agent creation + GitHub secrets + git push
./scripts/04-deploy.sh
```

## Cleanup

```bash
# Remove all AWS resources (IAM user, policy, agent) and GitHub secrets
./scripts/05-cleanup.sh
```

## Requirements

- **Bash** (macOS/Linux or Git Bash on Windows)
- **AWS CLI** configured with admin access
- **GitHub CLI** (`gh`) authenticated
- **Python 3.9+** (for the code reviewer)
