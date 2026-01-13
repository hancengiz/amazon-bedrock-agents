#!/bin/bash
#
# GitHub Setup Script for Bedrock PR Code Reviewer
# Configures repository secrets using GitHub CLI
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Repository admin access
#
# Usage:
#   ./scripts/setup-github.sh [OPTIONS]
#
# Options:
#   --repo OWNER/REPO       GitHub repository (default: auto-detect from git remote)
#   --credentials FILE      AWS credentials file (default: .aws-credentials.json)
#   --access-key KEY        AWS access key ID (overrides credentials file)
#   --secret-key KEY        AWS secret access key (overrides credentials file)
#   --region REGION         AWS region (default: us-east-1)
#   --dry-run               Show what would be done without making changes
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
CREDENTIALS_FILE=".aws-credentials.json"
AGENT_FILE=".bedrock-agent.json"
ACCESS_KEY=""
SECRET_KEY=""
AGENT_ID=""
AGENT_ALIAS_ID=""
REGION="us-east-1"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --credentials)
            CREDENTIALS_FILE="$2"
            shift 2
            ;;
        --access-key)
            ACCESS_KEY="$2"
            shift 2
            ;;
        --secret-key)
            SECRET_KEY="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
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

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  GitHub Setup for Bedrock PR Code Reviewer   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI is not authenticated.${NC}"
    echo "Run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✓ GitHub CLI authenticated${NC}"

# Auto-detect repository if not specified
if [ -z "$REPO" ]; then
    if git remote get-url origin &> /dev/null; then
        REMOTE_URL=$(git remote get-url origin)
        # Extract owner/repo from various URL formats
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

# Get credentials
if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    if [ -f "$CREDENTIALS_FILE" ]; then
        echo -e "${YELLOW}Reading credentials from: $CREDENTIALS_FILE${NC}"

        if command -v jq &> /dev/null; then
            ACCESS_KEY=$(jq -r '.access_key_id' "$CREDENTIALS_FILE")
            SECRET_KEY=$(jq -r '.secret_access_key' "$CREDENTIALS_FILE")
            FILE_REGION=$(jq -r '.region // empty' "$CREDENTIALS_FILE")
            if [ -n "$FILE_REGION" ]; then
                REGION="$FILE_REGION"
            fi
        else
            # Fallback to grep if jq is not available
            ACCESS_KEY=$(grep -o '"access_key_id": "[^"]*"' "$CREDENTIALS_FILE" | cut -d'"' -f4)
            SECRET_KEY=$(grep -o '"secret_access_key": "[^"]*"' "$CREDENTIALS_FILE" | cut -d'"' -f4)
        fi

        echo -e "${GREEN}✓ Loaded credentials from file${NC}"
    else
        echo -e "${RED}Error: No credentials provided.${NC}"
        echo ""
        echo "Either:"
        echo "  1. Run ./scripts/01-setup-aws.sh first to create credentials file"
        echo "  2. Use --access-key and --secret-key options"
        echo "  3. Specify credentials file with --credentials FILE"
        exit 1
    fi
fi

# Get agent configuration
if [ -z "$AGENT_ID" ] || [ -z "$AGENT_ALIAS_ID" ]; then
    if [ -f "$AGENT_FILE" ]; then
        echo -e "${YELLOW}Reading agent config from: $AGENT_FILE${NC}"

        if command -v jq &> /dev/null; then
            AGENT_ID=$(jq -r '.agent_id' "$AGENT_FILE")
            AGENT_ALIAS_ID=$(jq -r '.agent_alias_id' "$AGENT_FILE")
        else
            AGENT_ID=$(grep -o '"agent_id": "[^"]*"' "$AGENT_FILE" | cut -d'"' -f4)
            AGENT_ALIAS_ID=$(grep -o '"agent_alias_id": "[^"]*"' "$AGENT_FILE" | cut -d'"' -f4)
        fi

        echo -e "${GREEN}✓ Loaded agent config from file${NC}"
    else
        echo -e "${RED}Error: Bedrock Agent not found.${NC}"
        echo ""
        echo "Run ./scripts/02-create-bedrock-agent.sh first to create the agent."
        exit 1
    fi
fi

# Validate credentials
if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    echo -e "${RED}Error: Missing access key or secret key.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Repository:     $REPO"
echo "  Access Key:     ${ACCESS_KEY:0:8}..."
echo "  Secret Key:     ****"
echo "  Region:         $REGION"
echo "  Agent ID:       $AGENT_ID"
echo "  Agent Alias ID: $AGENT_ALIAS_ID"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would configure the following:${NC}"
    echo ""
    echo "Repository: $REPO"
    echo ""
    echo "Secrets:"
    echo "  • AWS_ACCESS_KEY_ID = ${ACCESS_KEY:0:8}..."
    echo "  • AWS_SECRET_ACCESS_KEY = ****"
    echo "  • BEDROCK_AGENT_ID = $AGENT_ID"
    echo "  • BEDROCK_AGENT_ALIAS_ID = $AGENT_ALIAS_ID"
    echo ""
    echo "Variables:"
    echo "  • AWS_REGION = $REGION"
    echo ""
    exit 0
fi

# Check repository access
echo -e "${YELLOW}Checking repository access...${NC}"

if ! gh repo view "$REPO" &> /dev/null; then
    echo -e "${RED}Error: Cannot access repository $REPO${NC}"
    echo "Make sure you have admin access to the repository."
    exit 1
fi

echo -e "${GREEN}✓ Repository access confirmed${NC}"

# Set secrets
echo -e "${YELLOW}Step 1: Setting AWS secrets...${NC}"
echo "$ACCESS_KEY" | gh secret set AWS_ACCESS_KEY_ID --repo "$REPO"
echo "$SECRET_KEY" | gh secret set AWS_SECRET_ACCESS_KEY --repo "$REPO"
echo -e "${GREEN}✓ AWS credentials configured${NC}"

echo -e "${YELLOW}Step 2: Setting Bedrock Agent secrets...${NC}"
echo "$AGENT_ID" | gh secret set BEDROCK_AGENT_ID --repo "$REPO"
echo "$AGENT_ALIAS_ID" | gh secret set BEDROCK_AGENT_ALIAS_ID --repo "$REPO"
echo -e "${GREEN}✓ Bedrock Agent configured${NC}"

# Set variables
echo -e "${YELLOW}Step 3: Setting AWS_REGION variable...${NC}"
gh variable set AWS_REGION --repo "$REPO" --body "$REGION" 2>/dev/null || \
    echo "$REGION" | gh variable set AWS_REGION --repo "$REPO"
echo -e "${GREEN}✓ AWS_REGION variable set${NC}"

# Verify GitHub Actions is enabled
echo -e "${YELLOW}Step 4: Checking GitHub Actions status...${NC}"

# List secrets to verify
SECRETS=$(gh secret list --repo "$REPO" 2>/dev/null || echo "")
if echo "$SECRETS" | grep -q "AWS_ACCESS_KEY_ID"; then
    echo -e "${GREEN}✓ Secrets configured successfully${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify secrets (may require additional permissions)${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  GitHub Setup Complete!                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Configured for repository:${NC} $REPO"
echo ""
echo -e "${BLUE}Secrets set:${NC}"
echo "  • AWS_ACCESS_KEY_ID"
echo "  • AWS_SECRET_ACCESS_KEY"
echo "  • BEDROCK_AGENT_ID"
echo "  • BEDROCK_AGENT_ALIAS_ID"
echo ""
echo -e "${BLUE}Variables set:${NC}"
echo "  • AWS_REGION = $REGION"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Push the code to your repository"
echo "  2. Create a pull request to trigger the code reviewer"
echo ""
echo -e "${BLUE}Verify at:${NC}"
echo "  https://github.com/$REPO/settings/secrets/actions"
echo ""
echo -e "${BLUE}View workflow runs:${NC}"
echo "  https://github.com/$REPO/actions"
