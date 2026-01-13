#!/bin/bash
# =============================================================================
# Stage 2: AWS Setup - Create IAM Policy
# =============================================================================
# Creates the IAM policy required for Bedrock access
# =============================================================================

set -e

POLICY_NAME="BedrockCodeReviewerPolicy"
POLICY_FILE="$(dirname "$0")/bedrock-policy.json"

echo "=============================================="
echo "  Stage 2: AWS Setup - Create IAM Policy"
echo "=============================================="
echo ""

# Check AWS CLI is configured
echo -n "Checking AWS credentials... "
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "OK (Account: $ACCOUNT_ID)"
else
    echo "FAILED"
    echo ""
    echo "Please configure AWS CLI first:"
    echo "  aws configure"
    echo ""
    echo "Or set environment variables:"
    echo "  export AWS_ACCESS_KEY_ID=..."
    echo "  export AWS_SECRET_ACCESS_KEY=..."
    exit 1
fi

echo ""

# Check if policy already exists
echo -n "Checking if policy '$POLICY_NAME' exists... "
if aws iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" &> /dev/null; then
    echo "EXISTS"
    echo ""
    echo "Policy already exists. Skipping creation."
    echo "ARN: arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"
else
    echo "NOT FOUND"
    echo ""
    echo "Creating policy '$POLICY_NAME'..."

    POLICY_ARN=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "file://$POLICY_FILE" \
        --description "Allows invoking Bedrock models for code review" \
        --query 'Policy.Arn' \
        --output text)

    echo "Created: $POLICY_ARN"
fi

echo ""
echo "=============================================="
echo "  Policy setup complete!"
echo "  Proceed to: create-iam-user.sh"
echo "=============================================="
