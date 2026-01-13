#!/bin/bash
# =============================================================================
# Stage 3: GitHub Setup - Verify Actions Enabled
# =============================================================================
# Checks that GitHub Actions is enabled for the repository
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 3: Verify GitHub Actions Enabled"
echo "=============================================="
echo ""

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI not found. Please check manually at:"
    echo "https://github.com/<owner>/<repo>/settings/actions"
    exit 0
fi

# Check auth
if ! gh auth status &> /dev/null; then
    echo "Not authenticated. Please run: gh auth login"
    exit 1
fi

# Get repository
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
    echo "Could not detect repository."
    exit 1
fi

echo "Repository: $REPO"
echo ""

# Check for workflow file
echo -n "Checking workflow file exists... "
if [ -f ".github/workflows/code-review.yml" ]; then
    echo "OK"
else
    echo "NOT FOUND"
    echo ""
    echo "Workflow file missing at .github/workflows/code-review.yml"
    echo "Please ensure the code has been deployed first."
    exit 1
fi

# List workflows
echo ""
echo "Checking repository workflows..."
echo ""

WORKFLOWS=$(gh workflow list --repo "$REPO" 2>/dev/null)

if [ -n "$WORKFLOWS" ]; then
    echo "Active workflows:"
    echo "$WORKFLOWS"
    echo ""

    if echo "$WORKFLOWS" | grep -q "AI Code Review"; then
        echo "=============================================="
        echo "  GitHub Actions is properly configured!"
        echo "=============================================="
    else
        echo "Note: 'AI Code Review' workflow not yet visible."
        echo "It will appear after the first PR triggers it."
    fi
else
    echo "No workflows found or Actions may be disabled."
    echo ""
    echo "Enable at: https://github.com/$REPO/settings/actions"
fi

echo ""
echo "Actions settings: https://github.com/$REPO/settings/actions"
echo ""
echo "Proceed to Stage 4: Deploy"
