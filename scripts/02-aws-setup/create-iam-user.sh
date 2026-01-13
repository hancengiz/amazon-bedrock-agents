#!/bin/bash
# =============================================================================
# Stage 2: AWS Setup - Create IAM User
# =============================================================================
# Creates an IAM user for the GitHub Action with Bedrock access
# =============================================================================

set -e

USER_NAME="github-bedrock-reviewer"
POLICY_NAME="BedrockCodeReviewerPolicy"

echo "=============================================="
echo "  Stage 2: AWS Setup - Create IAM User"
echo "=============================================="
echo ""

# Check AWS CLI is configured
echo -n "Checking AWS credentials... "
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "OK (Account: $ACCOUNT_ID)"
else
    echo "FAILED"
    echo "Please run 'aws configure' first"
    exit 1
fi

POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME"

echo ""

# Check if user already exists
echo -n "Checking if user '$USER_NAME' exists... "
if aws iam get-user --user-name "$USER_NAME" &> /dev/null; then
    echo "EXISTS"
    echo ""
    echo "User already exists. Checking for access keys..."
else
    echo "NOT FOUND"
    echo ""
    echo "Creating user '$USER_NAME'..."
    aws iam create-user --user-name "$USER_NAME" > /dev/null
    echo "User created."

    echo ""
    echo "Attaching policy..."
    aws iam attach-user-policy \
        --user-name "$USER_NAME" \
        --policy-arn "$POLICY_ARN"
    echo "Policy attached."
fi

echo ""

# Check for existing access keys
EXISTING_KEYS=$(aws iam list-access-keys --user-name "$USER_NAME" --query 'AccessKeyMetadata[*].AccessKeyId' --output text)

if [ -n "$EXISTING_KEYS" ]; then
    echo "Existing access keys found: $EXISTING_KEYS"
    echo ""
    read -p "Create new access key? (y/N): " CREATE_NEW
    if [[ ! "$CREATE_NEW" =~ ^[Yy]$ ]]; then
        echo "Skipping key creation."
        exit 0
    fi
fi

echo ""
echo "Creating access keys..."
echo ""

CREDENTIALS=$(aws iam create-access-key --user-name "$USER_NAME" --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)

ACCESS_KEY_ID=$(echo "$CREDENTIALS" | cut -f1)
SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | cut -f2)

echo "=============================================="
echo "  ACCESS CREDENTIALS (SAVE THESE!)"
echo "=============================================="
echo ""
echo "AWS_ACCESS_KEY_ID:     $ACCESS_KEY_ID"
echo "AWS_SECRET_ACCESS_KEY: $SECRET_ACCESS_KEY"
echo ""
echo "=============================================="
echo "  WARNING: Secret key shown only once!"
echo "  Save these for Stage 3: GitHub Setup"
echo "=============================================="

# Optionally save to file
CREDS_FILE="$(dirname "$0")/.credentials-$USER_NAME"
echo "AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID" > "$CREDS_FILE"
echo "AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY" >> "$CREDS_FILE"
chmod 600 "$CREDS_FILE"
echo ""
echo "Credentials also saved to: $CREDS_FILE"
echo "(Remember to delete this file after adding to GitHub!)"
