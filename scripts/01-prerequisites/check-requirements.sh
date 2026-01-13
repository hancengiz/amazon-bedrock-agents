#!/bin/bash
# =============================================================================
# Stage 1: Prerequisites Check
# =============================================================================
# Verifies all required tools and accounts are available before deployment
# =============================================================================

set -e

echo "=============================================="
echo "  Stage 1: Prerequisites Check"
echo "=============================================="
echo ""

ERRORS=0

# -----------------------------------------------------------------------------
# Check Python
# -----------------------------------------------------------------------------
echo -n "Checking Python 3.9+... "
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    if [ "$MAJOR" -ge 3 ] && [ "$MINOR" -ge 9 ]; then
        echo "OK (v$PYTHON_VERSION)"
    else
        echo "WARN (v$PYTHON_VERSION - recommend 3.9+)"
    fi
else
    echo "MISSING"
    echo "  Install: https://www.python.org/downloads/"
    ERRORS=$((ERRORS + 1))
fi

# -----------------------------------------------------------------------------
# Check pip
# -----------------------------------------------------------------------------
echo -n "Checking pip... "
if command -v pip3 &> /dev/null || command -v pip &> /dev/null; then
    PIP_VERSION=$(pip3 --version 2>/dev/null || pip --version)
    echo "OK"
else
    echo "MISSING"
    echo "  Install: python3 -m ensurepip --upgrade"
    ERRORS=$((ERRORS + 1))
fi

# -----------------------------------------------------------------------------
# Check AWS CLI
# -----------------------------------------------------------------------------
echo -n "Checking AWS CLI... "
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    echo "OK (v$AWS_VERSION)"
else
    echo "MISSING (optional but recommended)"
    echo "  Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
fi

# -----------------------------------------------------------------------------
# Check GitHub CLI
# -----------------------------------------------------------------------------
echo -n "Checking GitHub CLI (gh)... "
if command -v gh &> /dev/null; then
    GH_VERSION=$(gh --version | head -1 | cut -d' ' -f3)
    echo "OK (v$GH_VERSION)"
else
    echo "MISSING (optional but recommended)"
    echo "  Install: https://cli.github.com/"
fi

# -----------------------------------------------------------------------------
# Check git
# -----------------------------------------------------------------------------
echo -n "Checking git... "
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    echo "OK (v$GIT_VERSION)"
else
    echo "MISSING"
    echo "  Install: https://git-scm.com/downloads"
    ERRORS=$((ERRORS + 1))
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
if [ $ERRORS -eq 0 ]; then
    echo "  All prerequisites met!"
    echo "  Proceed to Stage 2: AWS Setup"
    echo "=============================================="
    exit 0
else
    echo "  $ERRORS required tool(s) missing"
    echo "  Please install missing tools and re-run"
    echo "=============================================="
    exit 1
fi
