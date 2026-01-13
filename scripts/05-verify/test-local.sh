#!/bin/bash
# =============================================================================
# Stage 5: Verify - Test Locally
# =============================================================================
# Runs the code reviewer locally in dry-run mode
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 5: Test Code Reviewer Locally"
echo "=============================================="
echo ""

# Find project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

# Check environment variables
MISSING_VARS=0

echo "Checking environment variables..."
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
    echo "  GITHUB_TOKEN:          MISSING"
    MISSING_VARS=$((MISSING_VARS + 1))
else
    echo "  GITHUB_TOKEN:          SET"
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "  AWS_ACCESS_KEY_ID:     MISSING"
    MISSING_VARS=$((MISSING_VARS + 1))
else
    echo "  AWS_ACCESS_KEY_ID:     SET"
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "  AWS_SECRET_ACCESS_KEY: MISSING"
    MISSING_VARS=$((MISSING_VARS + 1))
else
    echo "  AWS_SECRET_ACCESS_KEY: SET"
fi

echo "  AWS_REGION:            ${AWS_REGION:-us-east-1 (default)}"

if [ $MISSING_VARS -gt 0 ]; then
    echo ""
    echo "Please set the missing environment variables:"
    echo ""
    echo "  export GITHUB_TOKEN='ghp_...'"
    echo "  export AWS_ACCESS_KEY_ID='AKIA...'"
    echo "  export AWS_SECRET_ACCESS_KEY='...'"
    echo "  export AWS_REGION='us-east-1'"
    echo ""
    exit 1
fi

echo ""

# Get PR to test
if [ -z "$1" ]; then
    # Try to get from current branch
    CURRENT_PR=$(gh pr view --json number -q '.number' 2>/dev/null || echo "")

    if [ -n "$CURRENT_PR" ]; then
        echo "Found PR #$CURRENT_PR for current branch"
        PR_NUMBER="$CURRENT_PR"
    else
        read -p "Enter PR number to review: " PR_NUMBER
    fi
else
    PR_NUMBER="$1"
fi

# Get repo
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
    read -p "Enter repository (owner/repo): " REPO
fi

echo ""
echo "Running code reviewer (dry-run)..."
echo "  Repository: $REPO"
echo "  PR Number:  $PR_NUMBER"
echo ""
echo "=============================================="
echo ""

# Run the reviewer
python -m src.main --repo "$REPO" --pr "$PR_NUMBER" --dry-run

echo ""
echo "=============================================="
echo "  Local Test Complete!"
echo "=============================================="
echo ""
echo "The above is what would be posted to the PR."
echo "Remove --dry-run to actually post the comment."
