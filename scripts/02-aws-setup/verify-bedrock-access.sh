#!/bin/bash
# =============================================================================
# Stage 2: AWS Setup - Verify Bedrock Access
# =============================================================================
# Tests that Bedrock can be accessed with current credentials
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 2: Verify Bedrock Access"
echo "=============================================="
echo ""

REGION=${AWS_REGION:-us-east-1}
MODEL_ID="us.anthropic.claude-sonnet-4-5-20250514-v1:0"

echo "Region: $REGION"
echo "Model:  $MODEL_ID"
echo ""

# Check AWS CLI is configured
echo -n "Checking AWS credentials... "
if aws sts get-caller-identity &> /dev/null; then
    IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
    echo "OK"
    echo "Identity: $IDENTITY"
else
    echo "FAILED"
    exit 1
fi

echo ""
echo "Testing Bedrock model invocation..."
echo ""

# Create test payload
PAYLOAD=$(cat <<EOF
{
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 50,
    "messages": [
        {
            "role": "user",
            "content": "Say 'Bedrock access verified!' and nothing else."
        }
    ]
}
EOF
)

# Invoke model
RESPONSE=$(aws bedrock-runtime invoke-model \
    --region "$REGION" \
    --model-id "$MODEL_ID" \
    --content-type "application/json" \
    --accept "application/json" \
    --body "$PAYLOAD" \
    /dev/stdout 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "=============================================="
    echo "  Bedrock Access Verified!"
    echo "=============================================="
    echo ""
    echo "Response: $(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['content'][0]['text'])" 2>/dev/null || echo "$RESPONSE")"
    echo ""
    echo "Proceed to Stage 3: GitHub Setup"
else
    echo "=============================================="
    echo "  Bedrock Access FAILED"
    echo "=============================================="
    echo ""
    echo "Possible issues:"
    echo "  1. Anthropic usage form not submitted"
    echo "  2. IAM policy not attached"
    echo "  3. Wrong region (try us-east-1 or us-west-2)"
    echo ""
    echo "Visit: https://console.aws.amazon.com/bedrock/home#/modelaccess"
    exit 1
fi
