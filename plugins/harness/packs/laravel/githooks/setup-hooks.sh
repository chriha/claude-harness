#!/bin/sh
#
# One-time setup: point git at the versioned hooks in .githooks/.  Run once after cloning.
#
set -e

cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true

echo "✓ Git hooks enabled (core.hooksPath=.githooks):"
echo "    pre-commit  — blocks commits on main; auto-formats staged PHP"
echo "    commit-msg  — enforces Conventional Commits"
