#!/bin/bash
#
# AWS Setup Script for Bedrock PR Code Reviewer
# Creates IAM user, policy, and access keys
#
# Prerequisites:
#   - AWS CLI installed and configured (aws configure)
#   - Sufficient IAM permissions to create users and policies
#
# Usage:
#   ./scripts/setup-aws.sh [OPTIONS]
#
# Options:
#   --user-name NAME     IAM user name (default: github-bedrock-reviewer)
#   --policy-name NAME   IAM policy name (default: BedrockCodeReviewerPolicy)
#   --region REGION      AWS region (default: us-east-1)
#   --output-file FILE   File to save credentials (default: .aws-credentials.json)
#   --dry-run            Show what would be done without making changes
#   -h, --help           Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
USER_NAME="github-bedrock-reviewer"
POLICY_NAME="BedrockCodeReviewerPolicy"
REGION="us-east-1"
OUTPUT_FILE=".aws-credentials.json"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user-name)
            USER_NAME="$2"
            shift 2
            ;;
        --policy-name)
            POLICY_NAME="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --output-file)
            OUTPUT_FILE="$2"
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
echo -e "${BLUE}║  AWS Setup for Bedrock PR Code Reviewer      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed.${NC}"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not configured or credentials are invalid.${NC}"
    echo "Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS CLI configured (Account: $ACCOUNT_ID)${NC}"

# Define the IAM policy document
POLICY_DOCUMENT=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "BedrockInvokeAgent",
            "Effect": "Allow",
            "Action": "bedrock:InvokeAgent",
            "Resource": "arn:aws:bedrock:*:${ACCOUNT_ID}:agent-alias/*"
        },
        {
            "Sid": "BedrockInvokeModel",
            "Effect": "Allow",
            "Action": "bedrock:InvokeModel",
            "Resource": [
                "arn:aws:bedrock:*::foundation-model/anthropic.claude-*",
                "arn:aws:bedrock:*:*:inference-profile/us.anthropic.claude-*"
            ]
        }
    ]
}
EOF
)

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  User name:   $USER_NAME"
echo "  Policy name: $POLICY_NAME"
echo "  Region:      $REGION"
echo "  Output file: $OUTPUT_FILE"
echo ""

if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would create the following:${NC}"
    echo ""
    echo "1. IAM Policy: $POLICY_NAME"
    echo "   $POLICY_DOCUMENT" | head -20
    echo ""
    echo "2. IAM User: $USER_NAME"
    echo ""
    echo "3. Access Keys for $USER_NAME"
    echo ""
    exit 0
fi

# Create IAM Policy
echo -e "${YELLOW}Step 1: Creating IAM Policy...${NC}"

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

if aws iam get-policy --policy-arn "$POLICY_ARN" &> /dev/null; then
    echo -e "${GREEN}✓ Policy already exists: $POLICY_ARN${NC}"
else
    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "$POLICY_DOCUMENT" \
        --description "Allows invoking Bedrock Claude models for PR code review" \
        --output text > /dev/null
    echo -e "${GREEN}✓ Created policy: $POLICY_ARN${NC}"
fi

# Create IAM User
echo -e "${YELLOW}Step 2: Creating IAM User...${NC}"

if aws iam get-user --user-name "$USER_NAME" &> /dev/null; then
    echo -e "${GREEN}✓ User already exists: $USER_NAME${NC}"
else
    aws iam create-user --user-name "$USER_NAME" --output text > /dev/null
    echo -e "${GREEN}✓ Created user: $USER_NAME${NC}"
fi

# Attach policy to user
echo -e "${YELLOW}Step 3: Attaching policy to user...${NC}"

ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USER_NAME" --query "AttachedPolicies[].PolicyArn" --output text)

if echo "$ATTACHED_POLICIES" | grep -q "$POLICY_ARN"; then
    echo -e "${GREEN}✓ Policy already attached to user${NC}"
else
    aws iam attach-user-policy \
        --user-name "$USER_NAME" \
        --policy-arn "$POLICY_ARN"
    echo -e "${GREEN}✓ Attached policy to user${NC}"
fi

# Create access keys
echo -e "${YELLOW}Step 4: Creating access keys...${NC}"

# Check if user already has access keys
EXISTING_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query "AccessKeyMetadata[].AccessKeyId" --output text)

if [ -n "$EXISTING_KEYS" ]; then
    echo -e "${YELLOW}⚠ User already has access keys: $EXISTING_KEYS${NC}"
    read -p "Create new access keys anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipping access key creation.${NC}"
        echo ""
        echo -e "${GREEN}AWS setup complete!${NC}"
        echo -e "${YELLOW}Use existing access keys or run this script again to create new ones.${NC}"
        exit 0
    fi
fi

# Create new access keys
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USER_NAME" --output json)

ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | grep -o '"AccessKeyId": "[^"]*"' | cut -d'"' -f4)
SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | grep -o '"SecretAccessKey": "[^"]*"' | cut -d'"' -f4)

echo -e "${GREEN}✓ Created access keys${NC}"

# Save credentials to file
cat > "$OUTPUT_FILE" <<EOF
{
    "user_name": "$USER_NAME",
    "policy_arn": "$POLICY_ARN",
    "region": "$REGION",
    "access_key_id": "$ACCESS_KEY_ID",
    "secret_access_key": "$SECRET_ACCESS_KEY"
}
EOF

chmod 600 "$OUTPUT_FILE"
echo -e "${GREEN}✓ Saved credentials to: $OUTPUT_FILE${NC}"

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  AWS Setup Complete!                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Resources created:${NC}"
echo "  • IAM Policy: $POLICY_ARN"
echo "  • IAM User:   $USER_NAME"
echo "  • Access Key: $ACCESS_KEY_ID"
echo ""
echo -e "${BLUE}Credentials saved to:${NC} $OUTPUT_FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Run ./scripts/setup-github.sh to configure GitHub secrets"
echo "  2. Or manually add these secrets to your GitHub repository:"
echo ""
echo "     AWS_ACCESS_KEY_ID:     $ACCESS_KEY_ID"
echo "     AWS_SECRET_ACCESS_KEY: [saved in $OUTPUT_FILE]"
echo ""
echo -e "${RED}⚠ IMPORTANT: Keep $OUTPUT_FILE secure and add it to .gitignore${NC}"

# Add to .gitignore if not present
if [ -f ".gitignore" ]; then
    if ! grep -q "^\.aws-credentials\.json$" .gitignore; then
        echo ".aws-credentials.json" >> .gitignore
        echo -e "${GREEN}✓ Added $OUTPUT_FILE to .gitignore${NC}"
    fi
else
    echo ".aws-credentials.json" > .gitignore
    echo -e "${GREEN}✓ Created .gitignore with $OUTPUT_FILE${NC}"
fi
