#!/bin/bash
# =============================================================================
# Stage 4: Deploy
# =============================================================================
# Commits and pushes the code reviewer to the repository
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 4: Deploy Code Reviewer"
echo "=============================================="
echo ""

# Check we're in a git repo
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: Not inside a git repository"
    exit 1
fi

# Get current branch
BRANCH=$(git branch --show-current)
echo "Current branch: $BRANCH"
echo ""

# Check for uncommitted changes
if git diff --quiet && git diff --cached --quiet; then
    echo "No changes to commit."
    echo ""

    # Check if remote is ahead
    git fetch origin "$BRANCH" 2>/dev/null || true

    if git diff --quiet "origin/$BRANCH" 2>/dev/null; then
        echo "Repository is up to date."
    else
        echo "Local changes not pushed. Pushing..."
        git push origin "$BRANCH"
        echo "Pushed to origin/$BRANCH"
    fi
else
    echo "Uncommitted changes detected:"
    git status --short
    echo ""

    read -p "Commit and push all changes? [Y/n]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    # Stage all changes
    git add -A

    # Commit
    COMMIT_MSG="Add Bedrock PR code reviewer

- GitHub Action workflow for automated PR reviews
- Uses Claude Sonnet 4.5 via Amazon Bedrock
- Reviews code quality, performance, and security"

    git commit -m "$COMMIT_MSG"
    echo ""
    echo "Committed changes."

    # Push
    echo ""
    echo "Pushing to origin/$BRANCH..."
    git push origin "$BRANCH"
    echo "Pushed."
fi

echo ""
echo "=============================================="
echo "  Deployment Complete!"
echo "=============================================="
echo ""

# Get repo URL
REPO_URL=$(git remote get-url origin | sed 's/\.git$//' | sed 's/git@github.com:/https:\/\/github.com\//')
echo "Repository: $REPO_URL"
echo "Actions:    $REPO_URL/actions"
echo ""
echo "Proceed to Stage 5: Verify"
