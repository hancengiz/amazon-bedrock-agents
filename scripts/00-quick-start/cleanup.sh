#!/bin/bash
#
# Cleanup Script for Bedrock PR Code Reviewer
# Removes AWS resources and GitHub secrets created by deployment scripts
#
# Prerequisites:
#   - AWS CLI installed and configured
#   - GitHub CLI (gh) installed and authenticated
#
# Usage:
#   ./scripts/cleanup.sh [OPTIONS]
#
# Options:
#   --repo OWNER/REPO       GitHub repository (default: auto-detect)
#   --user-name NAME        IAM user name (default: github-bedrock-reviewer)
#   --policy-name NAME      IAM policy name (default: BedrockCodeReviewerPolicy)
#   --aws-only              Only cleanup AWS resources
#   --github-only           Only cleanup GitHub secrets
#   --dry-run               Show what would be done without making changes
#   --force                 Skip confirmation prompts
#   -h, --help              Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
REPO=""
USER_NAME="github-bedrock-reviewer"
POLICY_NAME="BedrockCodeReviewerPolicy"
AWS_ONLY=false
GITHUB_ONLY=false
DRY_RUN=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --user-name)
            USER_NAME="$2"
            shift 2
            ;;
        --policy-name)
            POLICY_NAME="$2"
            shift 2
            ;;
        --aws-only)
            AWS_ONLY=true
            shift
            ;;
        --github-only)
            GITHUB_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            head -30 "$0" | tail -25
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${RED}╔══════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  Cleanup Bedrock PR Code Reviewer            ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Warning
if ! $FORCE && ! $DRY_RUN; then
    echo -e "${RED}⚠ WARNING: This will permanently delete:${NC}"
    if ! $GITHUB_ONLY; then
        echo "  • IAM User: $USER_NAME"
        echo "  • IAM Policy: $POLICY_NAME"
        echo "  • All access keys for $USER_NAME"
    fi
    if ! $AWS_ONLY; then
        echo "  • GitHub secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"
        echo "  • GitHub variable: AWS_REGION"
    fi
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Cleanup cancelled."
        exit 0
    fi
    echo ""
fi

# Auto-detect repository
if [ -z "$REPO" ] && ! $AWS_ONLY; then
    if git remote get-url origin &> /dev/null; then
        REMOTE_URL=$(git remote get-url origin)
        if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
            REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        fi
    fi
fi

# Cleanup GitHub
if ! $AWS_ONLY; then
    echo -e "${YELLOW}Cleaning up GitHub resources...${NC}"

    if [ -z "$REPO" ]; then
        echo -e "${YELLOW}⚠ Repository not specified, skipping GitHub cleanup${NC}"
    elif ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}⚠ GitHub CLI not installed, skipping GitHub cleanup${NC}"
    elif ! gh auth status &> /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ GitHub CLI not authenticated, skipping GitHub cleanup${NC}"
    else
        echo "  Repository: $REPO"

        if $DRY_RUN; then
            echo -e "${YELLOW}  [DRY RUN] Would delete secrets: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY${NC}"
            echo -e "${YELLOW}  [DRY RUN] Would delete variable: AWS_REGION${NC}"
        else
            # Delete secrets
            gh secret delete AWS_ACCESS_KEY_ID --repo "$REPO" 2>/dev/null && \
                echo -e "${GREEN}  ✓ Deleted secret: AWS_ACCESS_KEY_ID${NC}" || \
                echo -e "${YELLOW}  ○ Secret not found: AWS_ACCESS_KEY_ID${NC}"

            gh secret delete AWS_SECRET_ACCESS_KEY --repo "$REPO" 2>/dev/null && \
                echo -e "${GREEN}  ✓ Deleted secret: AWS_SECRET_ACCESS_KEY${NC}" || \
                echo -e "${YELLOW}  ○ Secret not found: AWS_SECRET_ACCESS_KEY${NC}"

            # Delete variable
            gh variable delete AWS_REGION --repo "$REPO" 2>/dev/null && \
                echo -e "${GREEN}  ✓ Deleted variable: AWS_REGION${NC}" || \
                echo -e "${YELLOW}  ○ Variable not found: AWS_REGION${NC}"
        fi
    fi
    echo ""
fi

# Cleanup AWS
if ! $GITHUB_ONLY; then
    echo -e "${YELLOW}Cleaning up AWS resources...${NC}"

    if ! command -v aws &> /dev/null; then
        echo -e "${YELLOW}⚠ AWS CLI not installed, skipping AWS cleanup${NC}"
    elif ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${YELLOW}⚠ AWS CLI not configured, skipping AWS cleanup${NC}"
    else
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

        # Check if user exists
        if aws iam get-user --user-name "$USER_NAME" &> /dev/null; then
            echo "  Found user: $USER_NAME"

            if $DRY_RUN; then
                echo -e "${YELLOW}  [DRY RUN] Would delete access keys${NC}"
                echo -e "${YELLOW}  [DRY RUN] Would detach policies${NC}"
                echo -e "${YELLOW}  [DRY RUN] Would delete user${NC}"
            else
                # Delete access keys
                ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query "AccessKeyMetadata[].AccessKeyId" --output text)
                for KEY in $ACCESS_KEYS; do
                    aws iam delete-access-key --user-name "$USER_NAME" --access-key-id "$KEY"
                    echo -e "${GREEN}  ✓ Deleted access key: $KEY${NC}"
                done

                # Detach policies
                ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USER_NAME" --query "AttachedPolicies[].PolicyArn" --output text)
                for POLICY in $ATTACHED_POLICIES; do
                    aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY"
                    echo -e "${GREEN}  ✓ Detached policy: $POLICY${NC}"
                done

                # Delete user
                aws iam delete-user --user-name "$USER_NAME"
                echo -e "${GREEN}  ✓ Deleted user: $USER_NAME${NC}"
            fi
        else
            echo -e "${YELLOW}  ○ User not found: $USER_NAME${NC}"
        fi

        # Delete policy
        if aws iam get-policy --policy-arn "$POLICY_ARN" &> /dev/null; then
            if $DRY_RUN; then
                echo -e "${YELLOW}  [DRY RUN] Would delete policy: $POLICY_ARN${NC}"
            else
                aws iam delete-policy --policy-arn "$POLICY_ARN"
                echo -e "${GREEN}  ✓ Deleted policy: $POLICY_ARN${NC}"
            fi
        else
            echo -e "${YELLOW}  ○ Policy not found: $POLICY_NAME${NC}"
        fi
    fi
    echo ""
fi

# Remove local credentials file
CREDS_FILE=".aws-credentials.json"
if [ -f "$CREDS_FILE" ]; then
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY RUN] Would delete local file: $CREDS_FILE${NC}"
    else
        rm -f "$CREDS_FILE"
        echo -e "${GREEN}✓ Deleted local credentials file: $CREDS_FILE${NC}"
    fi
fi

# Summary
echo ""
if $DRY_RUN; then
    echo -e "${YELLOW}Dry run complete. No changes were made.${NC}"
    echo "Remove --dry-run to actually clean up resources."
else
    echo -e "${GREEN}Cleanup complete!${NC}"
fi
