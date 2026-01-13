#!/bin/bash
# =============================================================================
# Stage 5: Verify - Check Workflow Status
# =============================================================================
# Monitors the status of the code review workflow
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 5: Check Workflow Status"
echo "=============================================="
echo ""

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI required. Install: https://cli.github.com/"
    exit 1
fi

# Get repo
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
echo "Repository: $REPO"
echo ""

# Get recent workflow runs
echo "Recent 'AI Code Review' workflow runs:"
echo ""

gh run list --workflow="code-review.yml" --limit 5 2>/dev/null || {
    echo "No workflow runs found yet."
    echo ""
    echo "The workflow will appear after the first PR triggers it."
    echo ""
    echo "Create a test PR with:"
    echo "  ./scripts/05-verify/create-test-pr.sh"
    exit 0
}

echo ""
echo "=============================================="

# Get latest run details
LATEST_RUN=$(gh run list --workflow="code-review.yml" --limit 1 --json databaseId,status,conclusion,headBranch -q '.[0]' 2>/dev/null)

if [ -n "$LATEST_RUN" ]; then
    RUN_ID=$(echo "$LATEST_RUN" | jq -r '.databaseId')
    STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
    CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion')
    BRANCH=$(echo "$LATEST_RUN" | jq -r '.headBranch')

    echo ""
    echo "Latest run:"
    echo "  ID:         $RUN_ID"
    echo "  Branch:     $BRANCH"
    echo "  Status:     $STATUS"
    echo "  Conclusion: $CONCLUSION"
    echo ""

    if [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ]; then
        echo "Workflow is still running..."
        echo ""
        echo "Watch live: gh run watch $RUN_ID"
        echo "Or view at: https://github.com/$REPO/actions/runs/$RUN_ID"
    elif [ "$CONCLUSION" = "success" ]; then
        echo "=============================================="
        echo "  Workflow completed successfully!"
        echo "=============================================="
        echo ""
        echo "Check the PR for the review comment."
    else
        echo "=============================================="
        echo "  Workflow failed or was cancelled"
        echo "=============================================="
        echo ""
        echo "View logs: gh run view $RUN_ID --log-failed"
        echo "Or at: https://github.com/$REPO/actions/runs/$RUN_ID"
    fi
fi
