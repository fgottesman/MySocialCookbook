#!/bin/bash

# Install Git Hooks for ClipCook Backend
# This script sets up pre-commit hooks to prevent problematic code from being committed

set -e

echo "📦 Installing Git hooks..."

# Get the root of the Git repository
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$GIT_ROOT" ]; then
    echo "❌ Error: Not in a Git repository"
    exit 1
fi

# Path to the backend directory
BACKEND_DIR="$GIT_ROOT/backend"
HOOKS_SOURCE="$BACKEND_DIR/.git-hooks"
HOOKS_TARGET="$GIT_ROOT/.git/hooks"

# Check if we're in the right place
if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Error: backend directory not found"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_TARGET"

# Copy pre-commit hook
echo "Copying pre-commit hook..."
cp "$HOOKS_SOURCE/pre-commit" "$HOOKS_TARGET/pre-commit"
chmod +x "$HOOKS_TARGET/pre-commit"

echo "✅ Git hooks installed successfully!"
echo ""
echo "The following checks will run before each commit:"
echo "  • TypeScript build verification"
echo "  • Secret/API key detection"
echo "  • Environment variable validation"
echo "  • Console.log detection"
echo "  • Unit tests"
echo "  • Direct commits to main branch prevention"
echo ""
echo "To bypass hooks (use sparingly): git commit --no-verify"
