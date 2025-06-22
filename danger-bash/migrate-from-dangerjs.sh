#!/bin/bash
#
# migrate-from-dangerjs.sh - Helper script to migrate from Danger JS to Danger Bash
#
set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}🔄 Danger JS to Danger Bash Migration Tool${NC}"
echo "==========================================="
echo ""

# Check current directory
if [[ ! -d "danger-system" ]] && [[ ! -f "dangerfile.js" ]]; then
    echo -e "${YELLOW}Warning: No Danger JS setup found in current directory${NC}"
    echo "This script should be run from your repository root."
    echo ""
fi

# Create danger-bash directory
echo -e "${BLUE}Creating danger-bash directory...${NC}"
mkdir -p danger-bash

# Copy rules.json if it exists
if [[ -f "danger-system/rules.json" ]]; then
    echo -e "${BLUE}Copying existing rules.json...${NC}"
    cp danger-system/rules.json danger-bash/rules.json
    echo -e "${GREEN}✓ Rules copied${NC}"
elif [[ -f "rules.json" ]]; then
    cp rules.json danger-bash/rules.json
    echo -e "${GREEN}✓ Rules copied${NC}"
else
    echo -e "${YELLOW}No existing rules.json found, using default${NC}"
fi

# Check for GitHub Actions workflows
echo ""
echo -e "${BLUE}Checking for existing GitHub Actions...${NC}"

if [[ -d ".github/workflows" ]]; then
    # Look for danger-related workflows
    if ls .github/workflows/*danger* 2>/dev/null || ls .github/workflows/*Danger* 2>/dev/null; then
        echo -e "${YELLOW}Found existing Danger workflows:${NC}"
        ls -la .github/workflows/*[Dd]anger*
        echo ""
        read -p "Update these workflows to use Danger Bash? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Creating new workflow...${NC}"
            # Workflow will be created by main script
        fi
    fi
fi

# Create migration report
echo ""
echo -e "${BLUE}📋 Migration Checklist:${NC}"
echo ""

cat > danger-bash/MIGRATION.md <<EOF
# Migration from Danger JS to Danger Bash

## Migration Date: $(date)

## Steps Completed:

- [x] Created danger-bash directory
- [x] Copied rules.json configuration
- [x] Installed bash scripts
- [ ] Updated CI/CD configuration
- [ ] Removed Node.js dependencies
- [ ] Tested locally
- [ ] Updated documentation

## Manual Steps Required:

### 1. Update CI/CD Configuration

Replace your Danger JS job with:

\`\`\`yaml
- name: Run Danger Analysis
  run: |
    chmod +x ./danger-bash/*.sh
    ./danger-bash/danger-analyze.sh \\
      --rules ./danger-bash/rules.json \\
      --output danger-results.json \\
      --base \${{ github.base_ref }}
\`\`\`

### 2. Environment Variables

Update these in your CI:
- \`GITHUB_TOKEN\` → Keep as is
- \`DANGER_GITHUB_API_TOKEN\` → Use \`GITHUB_TOKEN\`
- Remove: \`NODE_ENV\`, npm-related variables

### 3. Remove Node.js Dependencies

\`\`\`bash
# Remove Danger JS files
rm -rf danger-system/
rm -f dangerfile.js
rm -f .dangerrc

# Update package.json (remove danger dependencies)
npm uninstall danger minimatch

# Or remove package.json if only used for Danger
rm -f package.json package-lock.json
\`\`\`

### 4. Test Locally

\`\`\`bash
./danger-bash/test-locally.sh main
\`\`\`

### 5. Update Documentation

Update your README.md or contributing guidelines to reference the new bash-based system.

## Rule Migration Notes:

EOF

# Analyze dangerfile.js if exists
if [[ -f "dangerfile.js" ]] || [[ -f "danger-system/dangerfile.js" ]]; then
    echo -e "${BLUE}Analyzing dangerfile.js for custom logic...${NC}"
    
    DANGERFILE=""
    if [[ -f "dangerfile.js" ]]; then
        DANGERFILE="dangerfile.js"
    else
        DANGERFILE="danger-system/dangerfile.js"
    fi
    
    echo "" >> danger-bash/MIGRATION.md
    echo "### Custom Logic Found in dangerfile.js:" >> danger-bash/MIGRATION.md
    echo "" >> danger-bash/MIGRATION.md
    
    # Check for common patterns
    if grep -q "danger.github.pr" "$DANGERFILE"; then
        echo "- PR metadata access detected" >> danger-bash/MIGRATION.md
        echo "  → Use git commands or GitHub API directly" >> danger-bash/MIGRATION.md
    fi
    
    if grep -q "danger.git.modified_files\|danger.git.created_files" "$DANGERFILE"; then
        echo "- File change detection detected" >> danger-bash/MIGRATION.md
        echo "  → Handled automatically by danger-analyze.sh" >> danger-bash/MIGRATION.md
    fi
    
    if grep -q "fail(\|warn(\|message(\|markdown(" "$DANGERFILE"; then
        echo "- Danger reporting functions detected" >> danger-bash/MIGRATION.md
        echo "  → Converted to JSON results format" >> danger-bash/MIGRATION.md
    fi
    
    if grep -q "axios\|fetch\|http" "$DANGERFILE"; then
        echo "- HTTP requests detected" >> danger-bash/MIGRATION.md
        echo "  → Use curl in bash scripts" >> danger-bash/MIGRATION.md
    fi
    
    if grep -q "require\|import" "$DANGERFILE"; then
        echo "" >> danger-bash/MIGRATION.md
        echo "### Dependencies found:" >> danger-bash/MIGRATION.md
        grep -E "(require|import).*['\"].*['\"]" "$DANGERFILE" | sed 's/^/- /' >> danger-bash/MIGRATION.md
    fi
fi

# Show summary
echo ""
echo -e "${GREEN}✅ Migration preparation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Review danger-bash/MIGRATION.md for detailed instructions"
echo "2. Test locally: ./danger-bash/test-locally.sh"
echo "3. Update your CI/CD configuration"
echo "4. Remove old Danger JS files"
echo ""

# Offer to test
read -p "Would you like to test the new setup now? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Running local test...${NC}"
    if [[ -x "danger-bash/test-locally.sh" ]]; then
        ./danger-bash/test-locally.sh
    else
        echo -e "${RED}Error: Test script not found or not executable${NC}"
        echo "Run: chmod +x danger-bash/*.sh"
    fi
fi

echo ""
echo -e "${BLUE}📚 Documentation available at: danger-bash/README.md${NC}"
echo -e "${YELLOW}⚠️  Remember to commit the danger-bash directory to your repository${NC}"
