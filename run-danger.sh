#!/bin/bash
#
# run-danger.sh - Downloads danger core scripts and runs analysis
#
set -euo pipefail

# Configuration
DANGER_VERSION="${DANGER_VERSION:-v5.3}"
DANGER_REPO_NAME="danger-core"
DANGER_REPO="https://github.com/SandeepJy/${DANGER_REPO_NAME}"
DANGER_DIR="Danger"
SCRIPTS_DIR="$DANGER_DIR/$DANGER_REPO_NAME-${DANGER_VERSION#v}"
SCRIPTS_FULL_PATH="${SCRIPTS_DIR}/scripts"
LOCAL_MODE="${LOCAL_MODE:-true}"
CUR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"



# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure we're in the repository root
cd "$(dirname "$0")"

echo -e "${BLUE}🔍 Danger Analysis Runner${NC}"
echo "=========================="

# Check if Danger directory exists
if [[ ! -d "$DANGER_DIR" ]]; then
    echo -e "${RED}Error: Danger directory not found${NC}"
    echo "Please create a 'Danger' directory with rules.json"
    exit 1
fi

# Check if rules.json exists
if [[ ! -f "$DANGER_DIR/rules.json" ]]; then
    echo -e "${RED}Error: rules.json not found in Danger directory${NC}"
    exit 1
fi

# Download core scripts if not present or if UPDATE_DANGER is set
if [[ ! -d "$SCRIPTS_DIR" ]] || [[ "${UPDATE_DANGER:-}" == "true" ]]; then
    echo -e "${BLUE}Downloading Danger core scripts ${DANGER_VERSION}...${NC}"
    
    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    
    # Download the release
    curl -L "${DANGER_REPO}/archive/refs/tags/${DANGER_VERSION}.tar.gz" \
         -o "${TEMP_DIR}/danger-core.tar.gz" || {
        echo -e "${RED}Failed to download Danger core scripts${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    }
    
    # Extract scripts
    rm -rf "$SCRIPTS_DIR"
    mkdir -p "$SCRIPTS_DIR"
    tar -xzf "${TEMP_DIR}/danger-core.tar.gz" -C "$DANGER_DIR" || {
        echo -e "${RED}Failed to extract Danger core scripts${NC}"
        rm -rf "$TEMP_DIR"
        exit 1
    }
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✓ Downloaded Danger core scripts${NC}"
else
    echo -e "${BLUE}Using existing Danger core scripts${NC}"
fi

# Make scripts executable
chmod +x "$SCRIPTS_FULL_PATH"/*.sh
chmod +x "$SCRIPTS_FULL_PATH"/lib/*.sh 2>/dev/null || true

# Run danger analysis
echo ""
echo -e "${BLUE}Running Danger analysis...${NC}"
echo ""

if [[ "${LOCAL_MODE}" == "true" ]]; then
    "$SCRIPTS_FULL_PATH/run-danger-local.sh"
else
    # CI mode
    "${SCRIPTS_FULL_PATH}/danger-analyze.sh" \
        --rules "${CUR_DIR}/Danger/rules.json" \
        --custom-dir "${CUR_DIR}/Danger/custom-checks" \
        --output "${CUR_DIR}/Danger/danger-results.json" \
        --base "${GITHUB_BASE_REF:-main}" \
        --verbose
    
    # Post comment if in GitHub Actions
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
        GITHUB_PR_NUMBER="${GITHUB_EVENT_NUMBER:-${PR_NUMBER:-0}}" \
        "${SCRIPTS_FULL_PATH}/github-pr-comment.sh" "danger-results.json"
    fi
fi