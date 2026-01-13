#!/bin/bash
# =============================================================================
# Stage 5: Verify - Create Test PR
# =============================================================================
# Creates a test pull request to verify the code reviewer is working
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 5: Create Test Pull Request"
echo "=============================================="
echo ""

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI required. Install: https://cli.github.com/"
    exit 1
fi

# Check auth
if ! gh auth status &> /dev/null; then
    echo "Please authenticate: gh auth login"
    exit 1
fi

# Get repo info
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null)

echo "Repository: $REPO"
echo "Default branch: $DEFAULT_BRANCH"
echo ""

# Create test branch
TEST_BRANCH="test/code-reviewer-$(date +%s)"
echo "Creating branch: $TEST_BRANCH"
git checkout -b "$TEST_BRANCH"

# Create a test file
TEST_FILE="test-code-review.py"
cat > "$TEST_FILE" << 'EOF'
# Test file for code reviewer verification
# This file intentionally contains some issues for the reviewer to catch

def calculate_sum(numbers):
    # Performance issue: could use sum()
    total = 0
    for n in numbers:
        total = total + n
    return total

def get_user_data(user_id):
    # Security issue: SQL injection vulnerability (example)
    query = "SELECT * FROM users WHERE id = " + user_id
    return query

def process_data(data):
    # Code quality: no input validation
    result = data["value"] * 2
    return result

# Unused variable
unused_var = "this is never used"

if __name__ == "__main__":
    print(calculate_sum([1, 2, 3, 4, 5]))
EOF

echo "Created test file: $TEST_FILE"
echo ""

# Commit and push
git add "$TEST_FILE"
git commit -m "Test: Add file for code reviewer verification"
git push -u origin "$TEST_BRANCH"

echo ""
echo "Creating pull request..."
echo ""

PR_URL=$(gh pr create \
    --title "Test: Verify Code Reviewer" \
    --body "This is a test PR to verify the Bedrock code reviewer is working.

This test file intentionally contains:
- Performance issues
- Security concerns
- Code quality problems

The code reviewer should identify these issues.

---
*This PR can be closed after verification.*" \
    --base "$DEFAULT_BRANCH" \
    --head "$TEST_BRANCH")

echo ""
echo "=============================================="
echo "  Test PR Created!"
echo "=============================================="
echo ""
echo "PR URL: $PR_URL"
echo ""
echo "Next steps:"
echo "  1. Go to: $PR_URL"
echo "  2. Wait for the 'AI Code Review' action to complete"
echo "  3. Check for the review comment"
echo "  4. Close the PR when verified"
echo ""
echo "Monitor action: https://github.com/$REPO/actions"
