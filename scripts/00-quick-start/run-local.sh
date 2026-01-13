#!/bin/bash
#
# Run Code Review Locally
# Reviews a pull request or local changes using the Bedrock code reviewer
#
# Prerequisites:
#   - Python 3.11+
#   - AWS credentials configured (or .aws-credentials.json file)
#   - GitHub token (for PR reviews)
#
# Usage:
#   ./scripts/run-local.sh [OPTIONS]
#
# Options:
#   --repo OWNER/REPO     GitHub repository (default: auto-detect)
#   --pr NUMBER           Pull request number to review
#   --branch BRANCH       Review changes between current branch and BRANCH (default: main)
#   --credentials FILE    AWS credentials file (default: .aws-credentials.json)
#   --dry-run             Print review without posting to GitHub
#   --force               Force review even if already reviewed
#   -h, --help            Show this help message
#
# Examples:
#   ./scripts/run-local.sh --pr 123                    # Review PR #123
#   ./scripts/run-local.sh --pr 123 --dry-run          # Preview without posting
#   ./scripts/run-local.sh --branch develop            # Compare with develop branch
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
REPO=""
PR_NUMBER=""
BASE_BRANCH="main"
CREDENTIALS_FILE="$PROJECT_DIR/.aws-credentials.json"
DRY_RUN=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --pr)
            PR_NUMBER="$2"
            shift 2
            ;;
        --branch)
            BASE_BRANCH="$2"
            shift 2
            ;;
        --credentials)
            CREDENTIALS_FILE="$2"
            shift 2
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
            head -35 "$0" | tail -30
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Local Code Review Runner                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed.${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo -e "${GREEN}✓ Python $PYTHON_VERSION${NC}"

# Check if virtual environment exists, create if not
VENV_DIR="$PROJECT_DIR/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"
echo -e "${GREEN}✓ Virtual environment activated${NC}"

# Install dependencies if needed
if ! python3 -c "import boto3" &> /dev/null; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    pip install -q -r "$PROJECT_DIR/requirements.txt"
fi
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Auto-detect repository
if [ -z "$REPO" ]; then
    if git remote get-url origin &> /dev/null; then
        REMOTE_URL=$(git remote get-url origin)
        if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
            REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        fi
    fi

    if [ -z "$REPO" ]; then
        echo -e "${RED}Error: Could not auto-detect repository.${NC}"
        echo "Use --repo OWNER/REPO to specify manually."
        exit 1
    fi
fi

echo -e "${GREEN}✓ Repository: $REPO${NC}"

# Set up AWS credentials
if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    if [ -f "$CREDENTIALS_FILE" ]; then
        echo -e "${YELLOW}Loading AWS credentials from $CREDENTIALS_FILE...${NC}"

        if command -v jq &> /dev/null; then
            export AWS_ACCESS_KEY_ID=$(jq -r '.access_key_id' "$CREDENTIALS_FILE")
            export AWS_SECRET_ACCESS_KEY=$(jq -r '.secret_access_key' "$CREDENTIALS_FILE")
            export AWS_REGION=$(jq -r '.region // "us-east-1"' "$CREDENTIALS_FILE")
        else
            export AWS_ACCESS_KEY_ID=$(grep -o '"access_key_id": "[^"]*"' "$CREDENTIALS_FILE" | cut -d'"' -f4)
            export AWS_SECRET_ACCESS_KEY=$(grep -o '"secret_access_key": "[^"]*"' "$CREDENTIALS_FILE" | cut -d'"' -f4)
            export AWS_REGION="us-east-1"
        fi

        echo -e "${GREEN}✓ AWS credentials loaded${NC}"
    else
        echo -e "${RED}Error: AWS credentials not found.${NC}"
        echo ""
        echo "Options:"
        echo "  1. Run ./scripts/setup-aws.sh to create credentials"
        echo "  2. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
        echo "  3. Use --credentials FILE to specify credentials file"
        exit 1
    fi
else
    echo -e "${GREEN}✓ AWS credentials from environment${NC}"
fi

# Set up GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
    # Try to get token from gh CLI
    if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
        export GITHUB_TOKEN=$(gh auth token)
        echo -e "${GREEN}✓ GitHub token from gh CLI${NC}"
    else
        echo -e "${RED}Error: GITHUB_TOKEN not set.${NC}"
        echo ""
        echo "Options:"
        echo "  1. Run: gh auth login"
        echo "  2. Set GITHUB_TOKEN environment variable"
        exit 1
    fi
else
    echo -e "${GREEN}✓ GitHub token from environment${NC}"
fi

echo ""

# Determine what to review
if [ -z "$PR_NUMBER" ]; then
    # Try to get PR number from current branch
    CURRENT_BRANCH=$(git branch --show-current)

    if [ "$CURRENT_BRANCH" == "$BASE_BRANCH" ] || [ "$CURRENT_BRANCH" == "master" ]; then
        echo -e "${YELLOW}You are on the $CURRENT_BRANCH branch.${NC}"
        echo ""
        echo "To review a PR, use: ./scripts/run-local.sh --pr NUMBER"
        echo ""

        # Show open PRs
        if command -v gh &> /dev/null; then
            echo -e "${BLUE}Open pull requests:${NC}"
            gh pr list --repo "$REPO" --limit 5 || true
        fi
        exit 0
    fi

    # Try to find PR for current branch
    if command -v gh &> /dev/null; then
        PR_NUMBER=$(gh pr view --repo "$REPO" --json number --jq '.number' 2>/dev/null || echo "")
    fi

    if [ -z "$PR_NUMBER" ]; then
        echo -e "${YELLOW}No PR found for branch: $CURRENT_BRANCH${NC}"
        echo ""
        echo "Options:"
        echo "  1. Create a PR: gh pr create"
        echo "  2. Specify PR number: ./scripts/run-local.sh --pr NUMBER"
        exit 0
    fi

    echo -e "${GREEN}✓ Found PR #$PR_NUMBER for branch: $CURRENT_BRANCH${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Running Code Review${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Repository: $REPO"
echo "  PR Number:  #$PR_NUMBER"
echo "  Dry Run:    $DRY_RUN"
echo "  Force:      $FORCE"
echo ""

# Build command arguments
ARGS=(
    "--repo" "$REPO"
    "--pr" "$PR_NUMBER"
)

if $DRY_RUN; then
    ARGS+=("--dry-run")
fi

if $FORCE; then
    ARGS+=("--force")
fi

# Run the code reviewer
echo -e "${YELLOW}Starting code review...${NC}"
echo ""

cd "$PROJECT_DIR"
python3 -m src.main "${ARGS[@]}"

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Code review completed successfully!${NC}"

    if ! $DRY_RUN; then
        echo ""
        echo -e "${BLUE}View the review at:${NC}"
        echo "  https://github.com/$REPO/pull/$PR_NUMBER"
    fi
else
    echo -e "${RED}✗ Code review failed (exit code: $EXIT_CODE)${NC}"
fi

# Deactivate virtual environment
deactivate

exit $EXIT_CODE
