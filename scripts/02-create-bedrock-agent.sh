#!/bin/bash
#
# Create Bedrock Agent for Code Review
# This script creates a persistent Bedrock Agent that can be invoked for PR reviews
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
AGENT_NAME="pr-code-reviewer"
AGENT_DESCRIPTION="AI-powered code reviewer for pull requests"
REGION="${AWS_REGION:-us-east-1}"
# Use direct model ID for agents (not inference profile)
MODEL_ID="anthropic.claude-sonnet-4-20250514-v1:0"

# Find project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Create Bedrock Agent for Code Review        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS CLI configured (Account: $ACCOUNT_ID, Region: $REGION)${NC}"

# Check if agent already exists
EXISTING_AGENT=$(aws bedrock-agent list-agents --region "$REGION" \
    --query "agentSummaries[?agentName=='${AGENT_NAME}'].agentId" \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_AGENT" ]; then
    echo -e "${YELLOW}Agent '$AGENT_NAME' already exists (ID: $EXISTING_AGENT)${NC}"

    # Get the alias
    ALIAS_ID=$(aws bedrock-agent list-agent-aliases --agent-id "$EXISTING_AGENT" --region "$REGION" \
        --query "agentAliasSummaries[?agentAliasName=='live'].agentAliasId" \
        --output text 2>/dev/null || echo "")

    if [ -n "$ALIAS_ID" ] && [ "$ALIAS_ID" != "None" ]; then
        echo -e "${GREEN}✓ Agent alias exists: $ALIAS_ID${NC}"

        # Save agent info
        cat > "$PROJECT_ROOT/.bedrock-agent.json" << EOF
{
    "agent_id": "$EXISTING_AGENT",
    "agent_alias_id": "$ALIAS_ID",
    "agent_name": "$AGENT_NAME",
    "region": "$REGION"
}
EOF
        echo -e "${GREEN}✓ Agent info saved to .bedrock-agent.json${NC}"
        exit 0
    fi
fi

# Step 1: Create IAM role for the agent
echo ""
echo -e "${YELLOW}Step 1: Creating IAM role for Bedrock Agent...${NC}"

ROLE_NAME="BedrockAgentRole-${AGENT_NAME}"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

# Trust policy for Bedrock Agent
TRUST_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "bedrock.amazonaws.com"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "aws:SourceAccount": "${ACCOUNT_ID}"
                },
                "ArnLike": {
                    "aws:SourceArn": "arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:agent/*"
                }
            }
        }
    ]
}
EOF
)

if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
    echo -e "${GREEN}✓ Role already exists: $ROLE_NAME${NC}"
else
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --description "Execution role for Bedrock Agent ${AGENT_NAME}" \
        --output text > /dev/null
    echo -e "${GREEN}✓ Created role: $ROLE_NAME${NC}"
fi

# Attach policy to allow model invocation
AGENT_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
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

AGENT_POLICY_NAME="BedrockAgentModelAccess-${AGENT_NAME}"
AGENT_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${AGENT_POLICY_NAME}"

if aws iam get-policy --policy-arn "$AGENT_POLICY_ARN" &> /dev/null; then
    echo -e "${GREEN}✓ Policy already exists: $AGENT_POLICY_NAME${NC}"
else
    aws iam create-policy \
        --policy-name "$AGENT_POLICY_NAME" \
        --policy-document "$AGENT_POLICY" \
        --description "Model access for Bedrock Agent" \
        --output text > /dev/null
    echo -e "${GREEN}✓ Created policy: $AGENT_POLICY_NAME${NC}"
fi

# Attach policy to role
ATTACHED=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" \
    --query "AttachedPolicies[?PolicyArn=='${AGENT_POLICY_ARN}'].PolicyArn" --output text)
if [ -z "$ATTACHED" ]; then
    aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$AGENT_POLICY_ARN"
    echo -e "${GREEN}✓ Attached policy to role${NC}"
fi

# Wait for role to propagate
echo "Waiting for IAM role to propagate..."
sleep 10

# Step 2: Create the Bedrock Agent
echo ""
echo -e "${YELLOW}Step 2: Creating Bedrock Agent...${NC}"

# Agent instruction (system prompt)
AGENT_INSTRUCTION=$(cat <<'EOF'
You are an expert code reviewer. When given code changes from a pull request, analyze them and provide constructive feedback.

Focus your review on:

1. **Code Quality & Best Practices**
   - Code readability and maintainability
   - Naming conventions and code organization
   - DRY principles and code duplication
   - Error handling and edge cases
   - Documentation where needed

2. **Performance Issues**
   - Inefficient algorithms or data structures
   - Unnecessary computations or memory usage
   - N+1 queries or database performance
   - Resource leaks

3. **Security Vulnerabilities**
   - Input validation and sanitization
   - Authentication/authorization issues
   - Injection vulnerabilities (SQL, XSS, command injection)
   - Sensitive data exposure
   - Insecure deserialization

Format your response as:

### Summary
Brief overall assessment (2-3 sentences).

### Code Quality
List specific issues with file names and line numbers. If none, say "No issues found."

### Performance
List performance concerns. If none, say "No issues found."

### Security
List security issues. If none, say "No issues found."

### Suggestions
Additional recommendations.

Be constructive, specific, and reference line numbers when pointing out issues.
EOF
)

# Create the agent
AGENT_RESPONSE=$(aws bedrock-agent create-agent \
    --agent-name "$AGENT_NAME" \
    --description "$AGENT_DESCRIPTION" \
    --agent-resource-role-arn "$ROLE_ARN" \
    --foundation-model "$MODEL_ID" \
    --instruction "$AGENT_INSTRUCTION" \
    --idle-session-ttl-in-seconds 600 \
    --region "$REGION" \
    --output json)

AGENT_ID=$(echo "$AGENT_RESPONSE" | grep -o '"agentId": "[^"]*"' | cut -d'"' -f4)
echo -e "${GREEN}✓ Created agent: $AGENT_ID${NC}"

# Wait for agent to be ready
echo "Waiting for agent to be ready..."
for i in {1..30}; do
    STATUS=$(aws bedrock-agent get-agent --agent-id "$AGENT_ID" --region "$REGION" \
        --query 'agent.agentStatus' --output text)
    if [ "$STATUS" = "NOT_PREPARED" ] || [ "$STATUS" = "PREPARED" ]; then
        break
    fi
    sleep 2
done

# Step 3: Prepare the agent
echo ""
echo -e "${YELLOW}Step 3: Preparing agent...${NC}"

aws bedrock-agent prepare-agent --agent-id "$AGENT_ID" --region "$REGION" > /dev/null
echo "Waiting for agent preparation..."

for i in {1..60}; do
    STATUS=$(aws bedrock-agent get-agent --agent-id "$AGENT_ID" --region "$REGION" \
        --query 'agent.agentStatus' --output text)
    if [ "$STATUS" = "PREPARED" ]; then
        echo -e "${GREEN}✓ Agent prepared${NC}"
        break
    elif [ "$STATUS" = "FAILED" ]; then
        echo -e "${RED}✗ Agent preparation failed${NC}"
        exit 1
    fi
    sleep 3
done

# Step 4: Create agent alias
echo ""
echo -e "${YELLOW}Step 4: Creating agent alias...${NC}"

ALIAS_RESPONSE=$(aws bedrock-agent create-agent-alias \
    --agent-id "$AGENT_ID" \
    --agent-alias-name "live" \
    --description "Production alias for code review agent" \
    --region "$REGION" \
    --output json)

ALIAS_ID=$(echo "$ALIAS_RESPONSE" | grep -o '"agentAliasId": "[^"]*"' | cut -d'"' -f4)
echo -e "${GREEN}✓ Created alias: $ALIAS_ID${NC}"

# Wait for alias to be ready
echo "Waiting for alias to be ready..."
for i in {1..30}; do
    ALIAS_STATUS=$(aws bedrock-agent get-agent-alias \
        --agent-id "$AGENT_ID" \
        --agent-alias-id "$ALIAS_ID" \
        --region "$REGION" \
        --query 'agentAlias.agentAliasStatus' --output text)
    if [ "$ALIAS_STATUS" = "PREPARED" ]; then
        echo -e "${GREEN}✓ Alias ready${NC}"
        break
    fi
    sleep 2
done

# Save agent configuration
cat > "$PROJECT_ROOT/.bedrock-agent.json" << EOF
{
    "agent_id": "$AGENT_ID",
    "agent_alias_id": "$ALIAS_ID",
    "agent_name": "$AGENT_NAME",
    "region": "$REGION",
    "role_arn": "$ROLE_ARN"
}
EOF

chmod 600 "$PROJECT_ROOT/.bedrock-agent.json"

# Add to .gitignore
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    if ! grep -q "^\.bedrock-agent\.json$" "$PROJECT_ROOT/.gitignore"; then
        echo ".bedrock-agent.json" >> "$PROJECT_ROOT/.gitignore"
    fi
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Bedrock Agent Created Successfully!         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Agent Details:${NC}"
echo "  Agent ID:    $AGENT_ID"
echo "  Alias ID:    $ALIAS_ID"
echo "  Agent Name:  $AGENT_NAME"
echo "  Region:      $REGION"
echo ""
echo -e "${BLUE}Configuration saved to:${NC} .bedrock-agent.json"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Add BEDROCK_AGENT_ID and BEDROCK_AGENT_ALIAS_ID to GitHub secrets"
echo "  2. Or set environment variables for local testing"
echo ""
