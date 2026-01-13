#!/bin/bash
# =============================================================================
# Stage 3: GitHub Setup - Configure Secrets
# =============================================================================
# Adds AWS credentials as GitHub repository secrets using GitHub CLI
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 3: GitHub Setup - Configure Secrets"
echo "=============================================="
echo ""

# Check GitHub CLI
echo -n "Checking GitHub CLI... "
if ! command -v gh &> /dev/null; then
    echo "NOT FOUND"
    echo ""
    echo "GitHub CLI is required for this script."
    echo "Install: https://cli.github.com/"
    echo ""
    echo "Alternatively, add secrets manually at:"
    echo "https://github.com/<owner>/<repo>/settings/secrets/actions"
    exit 1
fi
echo "OK"

# Check GitHub auth
echo -n "Checking GitHub authentication... "
if ! gh auth status &> /dev/null; then
    echo "NOT AUTHENTICATED"
    echo ""
    echo "Please authenticate with GitHub CLI:"
    echo "  gh auth login"
    exit 1
fi
echo "OK"

# Get repository
echo ""
echo -n "Detecting repository... "
if git remote get-url origin &> /dev/null; then
    REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
    if [ -n "$REPO" ]; then
        echo "$REPO"
    else
        echo "FAILED"
        echo "Could not detect repository. Please run from within your git repo."
        exit 1
    fi
else
    echo "NOT A GIT REPO"
    read -p "Enter repository (owner/repo): " REPO
fi

echo ""
echo "Repository: $REPO"
echo ""

# Check for credentials file from Stage 2
CREDS_FILE="$(dirname "$0")/../02-aws-setup/.credentials-github-bedrock-reviewer"
if [ -f "$CREDS_FILE" ]; then
    echo "Found credentials file from Stage 2"
    source "$CREDS_FILE"
fi

# Get AWS credentials
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    read -p "Enter AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    read -s -p "Enter AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
    echo ""
fi

echo ""
echo "Adding secrets to repository..."
echo ""

# Add AWS_ACCESS_KEY_ID
echo -n "Setting AWS_ACCESS_KEY_ID... "
echo "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID --repo "$REPO"
echo "OK"

# Add AWS_SECRET_ACCESS_KEY
echo -n "Setting AWS_SECRET_ACCESS_KEY... "
echo "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY --repo "$REPO"
echo "OK"

# Optionally set region variable
echo ""
read -p "Set AWS_REGION variable? (default: us-east-1) [y/N]: " SET_REGION
if [[ "$SET_REGION" =~ ^[Yy]$ ]]; then
    read -p "Enter region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    echo -n "Setting AWS_REGION... "
    gh variable set AWS_REGION --repo "$REPO" --body "$AWS_REGION"
    echo "OK"
fi

echo ""
echo "=============================================="
echo "  GitHub Secrets Configured!"
echo "=============================================="
echo ""
echo "Secrets added:"
echo "  - AWS_ACCESS_KEY_ID"
echo "  - AWS_SECRET_ACCESS_KEY"
echo ""
echo "View at: https://github.com/$REPO/settings/secrets/actions"
echo ""
echo "Proceed to Stage 4: Deploy"

# Clean up credentials file
if [ -f "$CREDS_FILE" ]; then
    echo ""
    read -p "Delete local credentials file? [Y/n]: " DELETE_CREDS
    if [[ ! "$DELETE_CREDS" =~ ^[Nn]$ ]]; then
        rm -f "$CREDS_FILE"
        echo "Credentials file deleted."
    fi
fi
