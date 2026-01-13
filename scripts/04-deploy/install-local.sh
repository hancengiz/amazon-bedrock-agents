#!/bin/bash
# =============================================================================
# Stage 4: Deploy - Install Locally
# =============================================================================
# Installs dependencies for local testing
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 4: Install Local Dependencies"
echo "=============================================="
echo ""

# Find project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Project root: $PROJECT_ROOT"
echo ""

# Check for virtual environment
if [ -z "$VIRTUAL_ENV" ]; then
    echo "No virtual environment detected."
    echo ""

    VENV_PATH="$PROJECT_ROOT/.venv"

    if [ -d "$VENV_PATH" ]; then
        echo "Found existing venv at $VENV_PATH"
        read -p "Activate it? [Y/n]: " ACTIVATE
        if [[ ! "$ACTIVATE" =~ ^[Nn]$ ]]; then
            source "$VENV_PATH/bin/activate"
            echo "Activated."
        fi
    else
        read -p "Create virtual environment? [Y/n]: " CREATE_VENV
        if [[ ! "$CREATE_VENV" =~ ^[Nn]$ ]]; then
            echo "Creating virtual environment..."
            python3 -m venv "$VENV_PATH"
            source "$VENV_PATH/bin/activate"
            echo "Created and activated: $VENV_PATH"
        fi
    fi
    echo ""
fi

# Install dependencies
echo "Installing dependencies..."
echo ""

pip install --upgrade pip
pip install -r "$PROJECT_ROOT/requirements.txt"

echo ""
echo "=============================================="
echo "  Local Installation Complete!"
echo "=============================================="
echo ""
echo "To run locally:"
echo ""
echo "  export GITHUB_TOKEN='your-token'"
echo "  export AWS_ACCESS_KEY_ID='your-key'"
echo "  export AWS_SECRET_ACCESS_KEY='your-secret'"
echo "  export AWS_REGION='us-east-1'"
echo ""
echo "  python -m src.main --repo owner/repo --pr 123 --dry-run"
