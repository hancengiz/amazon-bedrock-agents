#!/bin/bash
#
# Main Deployment Script for Bedrock PR Code Reviewer
# Orchestrates AWS and GitHub setup in one command
#
# Prerequisites:
#   - AWS CLI installed and configured
#   - GitHub CLI (gh) installed and authenticated
#   - Repository admin access
#
# Usage:
#   ./scripts/deploy.sh [OPTIONS]
#
# Options:
#   --repo OWNER/REPO       GitHub repository (default: auto-detect)
#   --region REGION         AWS region (default: us-east-1)
#   --user-name NAME        IAM user name (default: github-bedrock-reviewer)
#   --skip-aws              Skip AWS setup (use existing credentials)
#   --skip-github           Skip GitHub setup
#   --dry-run               Show what would be done without making changes
#   -h, --help              Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
REPO=""
REGION="us-east-1"
USER_NAME="github-bedrock-reviewer"
SKIP_AWS=false
SKIP_GITHUB=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --user-name)
            USER_NAME="$2"
            shift 2
            ;;
        --skip-aws)
            SKIP_AWS=true
            shift
            ;;
        --skip-github)
            SKIP_GITHUB=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# Banner
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║   🤖 Bedrock PR Code Reviewer - Deployment                 ║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Checking Prerequisites${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

MISSING_PREREQS=false

# Check AWS CLI
if ! $SKIP_AWS; then
    if command -v aws &> /dev/null; then
        if aws sts get-caller-identity &> /dev/null; then
            AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
            echo -e "${GREEN}✓ AWS CLI${NC} - Configured (Account: $AWS_ACCOUNT)"
        else
            echo -e "${RED}✗ AWS CLI${NC} - Not configured"
            echo "  Run: aws configure"
            MISSING_PREREQS=true
        fi
    else
        echo -e "${RED}✗ AWS CLI${NC} - Not installed"
        echo "  Install from: https://aws.amazon.com/cli/"
        MISSING_PREREQS=true
    fi
fi

# Check GitHub CLI
if ! $SKIP_GITHUB; then
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null 2>&1; then
            GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "authenticated")
            echo -e "${GREEN}✓ GitHub CLI${NC} - Authenticated as $GH_USER"
        else
            echo -e "${RED}✗ GitHub CLI${NC} - Not authenticated"
            echo "  Run: gh auth login"
            MISSING_PREREQS=true
        fi
    else
        echo -e "${RED}✗ GitHub CLI${NC} - Not installed"
        echo "  Install from: https://cli.github.com/"
        MISSING_PREREQS=true
    fi
fi

# Check jq (optional but helpful)
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq${NC} - Installed (for JSON parsing)"
else
    echo -e "${YELLOW}○ jq${NC} - Not installed (optional, will use fallback)"
fi

if $MISSING_PREREQS; then
    echo ""
    echo -e "${RED}Please install missing prerequisites and try again.${NC}"
    exit 1
fi

echo ""

# Auto-detect repository
if [ -z "$REPO" ] && ! $SKIP_GITHUB; then
    if git remote get-url origin &> /dev/null; then
        REMOTE_URL=$(git remote get-url origin)
        if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
            REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
            echo -e "${GREEN}✓ Auto-detected repository:${NC} $REPO"
        fi
    fi

    if [ -z "$REPO" ]; then
        echo -e "${YELLOW}Could not auto-detect repository.${NC}"
        read -p "Enter repository (OWNER/REPO): " REPO
        if [ -z "$REPO" ]; then
            echo -e "${RED}Repository is required for GitHub setup.${NC}"
            exit 1
        fi
    fi
fi

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Deployment Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Repository:     ${REPO:-N/A}"
echo "  AWS Region:     $REGION"
echo "  IAM User:       $USER_NAME"
echo "  Skip AWS:       $SKIP_AWS"
echo "  Skip GitHub:    $SKIP_GITHUB"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN MODE] No changes will be made.${NC}"
    echo ""
fi

# Confirmation
if ! $DRY_RUN; then
    read -p "Proceed with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

echo ""

# Step 1: AWS Setup
if ! $SKIP_AWS; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step 1: AWS Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    AWS_ARGS=(
        "--user-name" "$USER_NAME"
        "--region" "$REGION"
        "--output-file" "$PROJECT_DIR/.aws-credentials.json"
    )

    if $DRY_RUN; then
        AWS_ARGS+=("--dry-run")
    fi

    bash "$SCRIPT_DIR/setup-aws.sh" "${AWS_ARGS[@]}"
    echo ""
fi

# Step 2: GitHub Setup
if ! $SKIP_GITHUB; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step 2: GitHub Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    GH_ARGS=(
        "--repo" "$REPO"
        "--credentials" "$PROJECT_DIR/.aws-credentials.json"
        "--region" "$REGION"
    )

    if $DRY_RUN; then
        GH_ARGS+=("--dry-run")
    fi

    bash "$SCRIPT_DIR/setup-github.sh" "${GH_ARGS[@]}"
    echo ""
fi

# Final Summary
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Deployment Complete! 🎉${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}This was a dry run. No changes were made.${NC}"
    echo "Remove --dry-run to actually deploy."
else
    echo -e "${GREEN}The Bedrock PR Code Reviewer is now configured!${NC}"
    echo ""
    echo -e "${BLUE}What's next:${NC}"
    echo ""
    echo "  1. Push this code to your repository:"
    echo "     ${YELLOW}git add . && git commit -m 'Add Bedrock PR code reviewer' && git push${NC}"
    echo ""
    echo "  2. Create a pull request to test:"
    echo "     ${YELLOW}gh pr create --title 'Test code reviewer' --body 'Testing the AI code reviewer'${NC}"
    echo ""
    echo "  3. Watch the workflow run:"
    echo "     ${YELLOW}https://github.com/$REPO/actions${NC}"
    echo ""
    echo -e "${BLUE}Useful links:${NC}"
    echo "  • Repository secrets: https://github.com/$REPO/settings/secrets/actions"
    echo "  • Workflow runs:      https://github.com/$REPO/actions"
    echo "  • AWS IAM console:    https://console.aws.amazon.com/iam/home#/users/$USER_NAME"
    echo ""
fi
