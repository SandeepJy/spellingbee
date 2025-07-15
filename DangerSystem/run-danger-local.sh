#!/bin/bash
#
# run-danger-local.sh - Convenient wrapper for running danger locally
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Check if running from root or DangerSystem folder
if [[ "${SCRIPT_DIR##*/}" == "DangerSystem" ]]; then
    # Running from inside DangerSystem folder
    DANGER_DIR="${SCRIPT_DIR}"
else
    # Running from project root
    DANGER_DIR="${SCRIPT_DIR}/DangerSystem"
fi
BASE_BRANCH="${1:-main}"

echo "🔍 Running Danger Analysis on committed changes..."
echo "Comparing current branch against: $BASE_BRANCH"
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

# Fetch latest changes from remote
echo "Fetching latest changes from remote..."
git fetch origin "$BASE_BRANCH" 2>/dev/null || {
    echo "Warning: Could not fetch from remote. Using local $BASE_BRANCH branch."
}

# Run the test script
exec "${DANGER_DIR}/test-locally.sh" "$BASE_BRANCH"