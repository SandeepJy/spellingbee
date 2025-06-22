#!/bin/bash
#
# install.sh - Quick installer for Danger Bash
#
set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Banner
echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║     Danger Bash Installation         ║${NC}"
echo -e "${BOLD}${BLUE}║   Git Diff Static Analysis System    ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""

# Check requirements
echo -e "${BLUE}Checking requirements...${NC}"

MISSING_DEPS=()

if ! command -v git &> /dev/null; then
    MISSING_DEPS+=("git")
fi

if ! command -v jq &> /dev/null; then
    MISSING_DEPS+=("jq")
fi

if ! command -v curl &> /dev/null; then
    MISSING_DEPS+=("curl")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}Missing dependencies: ${MISSING_DEPS[*]}${NC}"
    echo ""
    echo "Please install missing dependencies:"
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  brew install ${MISSING_DEPS[*]}"
    elif [[ -f /etc/debian_version ]]; then
        echo "  sudo apt-get install ${MISSING_DEPS[*]}"
    elif [[ -f /etc/redhat-release ]]; then
        echo "  sudo yum install ${MISSING_DEPS[*]}"
    fi
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ All requirements met${NC}"
echo ""

# Get installation directory
INSTALL_DIR="${1:-danger-bash}"

if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Directory '$INSTALL_DIR' already exists${NC}"
    read -p "Overwrite existing installation? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    rm -rf "$INSTALL_DIR"
fi

# Create directory structure
echo -e "${BLUE}Creating directory structure...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p ".github/workflows"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy files
echo -e "${BLUE}Installing scripts...${NC}"

# Core scripts
cp "$SCRIPT_DIR/danger-analyze.sh" "$INSTALL_DIR/" 2>/dev/null || echo "  ⚠️  danger-analyze.sh not found"
cp "$SCRIPT_DIR/github-pr-comment.sh" "$INSTALL_DIR/" 2>/dev/null || echo "  ⚠️  github-pr-comment.sh not found"
cp "$SCRIPT_DIR/test-locally.sh" "$INSTALL_DIR/" 2>/dev/null || echo "  ⚠️  test-locally.sh not found"
cp "$SCRIPT_DIR/setup-github-protection.sh" "$INSTALL_DIR/" 2>/dev/null || echo "  ⚠️  setup-github-protection.sh not found"

# Configuration
cp "$SCRIPT_DIR/rules.json" "$INSTALL_DIR/" 2>/dev/null || echo "  ⚠️  rules.json not found"

# Documentation
cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/" 2>/dev/null || echo "  ⚠️  README.md not found"

# Make scripts executable
chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true

echo -e "${GREEN}✓ Scripts installed${NC}"

# Install GitHub Actions workflow
echo ""
echo -e "${BLUE}GitHub Actions Setup${NC}"
echo "Would you like to install the GitHub Actions workflow?"
echo "This will create: .github/workflows/danger-check.yml"
read -p "Install workflow? (Y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    if [[ -f "$SCRIPT_DIR/.github/workflows/danger-check.yml" ]]; then
        cp "$SCRIPT_DIR/.github/workflows/danger-check.yml" ".github/workflows/"
        echo -e "${GREEN}✓ GitHub Actions workflow installed${NC}"
    else
        echo -e "${YELLOW}Creating workflow from template...${NC}"
        cat > .github/workflows/danger-check.yml <<'EOF'
name: Danger Check

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  danger-analysis:
    name: Run Danger Analysis
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
          
      - name: Run Danger Analysis
        run: |
          chmod +x ./danger-bash/*.sh
          ./danger-bash/danger-analyze.sh \
            --rules ./danger-bash/rules.json \
            --output danger-results.json \
            --base ${{ github.base_ref }}
        continue-on-error: true
        
      - name: Post PR comment
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITHUB_REPOSITORY: ${{ github.repository }}
          GITHUB_PR_NUMBER: ${{ github.event.pull_request.number }}
        run: |
          ./danger-bash/github-pr-comment.sh danger-results.json
EOF
        echo -e "${GREEN}✓ Workflow created${NC}"
    fi
fi

# Check for existing Danger JS installation
if [[ -d "danger-system" ]] || [[ -f "dangerfile.js" ]] || [[ -f "package.json" ]] && grep -q "danger" package.json 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}⚠️  Existing Danger JS installation detected${NC}"
    echo "Would you like help migrating from Danger JS?"
    read -p "Run migration assistant? (Y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if [[ -x "$INSTALL_DIR/migrate-from-dangerjs.sh" ]]; then
            "$INSTALL_DIR/migrate-from-dangerjs.sh"
        else
            echo -e "${YELLOW}Migration assistant not available${NC}"
        fi
    fi
fi

# Quick test
echo ""
echo -e "${BLUE}Testing installation...${NC}"

if "$INSTALL_DIR/danger-analyze.sh" --help &>/dev/null; then
    echo -e "${GREEN}✓ Installation successful!${NC}"
else
    echo -e "${RED}✗ Installation test failed${NC}"
    echo "Please check the installation manually"
fi

# Summary
echo ""
echo -e "${BOLD}${GREEN}🎉 Installation Complete!${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. ${BOLD}Test locally:${NC}"
echo "   ./$INSTALL_DIR/test-locally.sh"
echo ""
echo "2. ${BOLD}Configure rules:${NC}"
echo "   Edit $INSTALL_DIR/rules.json"
echo ""
echo "3. ${BOLD}Commit changes:${NC}"
echo "   git add $INSTALL_DIR .github/workflows/danger-check.yml"
echo "   git commit -m 'Add Danger Bash static analysis'"
echo ""
echo "4. ${BOLD}Set up branch protection (optional):${NC}"
echo "   ./$INSTALL_DIR/setup-github-protection.sh"
echo ""
echo -e "${BLUE}Documentation:${NC} $INSTALL_DIR/README.md"
echo ""

# Create quick start guide
cat > "$INSTALL_DIR/QUICK_START.md" <<EOF
# Danger Bash Quick Start

## Installation Complete! 🎉

### Test Your Setup

1. Make some changes to your code
2. Run local test:
   \`\`\`bash
   ./$INSTALL_DIR/test-locally.sh
   \`\`\`

### Create a Test PR

1. Create a branch with intentional issues:
   \`\`\`bash
   git checkout -b test-danger
   echo "print('test')" >> test.swift
   git add test.swift
   git commit -m "Test Danger checks"
   git push origin test-danger
   \`\`\`

2. Create a PR and watch Danger comment!

### Customize Rules

Edit \`$INSTALL_DIR/rules.json\` to:
- Add new patterns
- Change severity levels  
- Exclude certain files
- Adjust thresholds

### Get Help

- README: $INSTALL_DIR/README.md
- Test locally: ./$INSTALL_DIR/test-locally.sh --help
- Analyzer: ./$INSTALL_DIR/danger-analyze.sh --help

Installation Date: $(date)
EOF

echo -e "${GREEN}Quick start guide created: $INSTALL_DIR/QUICK_START.md${NC}"
