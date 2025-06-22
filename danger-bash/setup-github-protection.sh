#!/bin/bash
#
# setup-github-protection.sh - Configure GitHub branch protection to require Danger checks
#
set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
BRANCH="${1:-main}"

echo -e "${BLUE}🔒 GitHub Branch Protection Setup${NC}"
echo "=================================="
echo ""

# Validate inputs
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo -e "${RED}Error: GITHUB_TOKEN environment variable is not set${NC}"
    echo ""
    echo "Please create a personal access token with 'repo' scope:"
    echo "https://github.com/settings/tokens"
    echo ""
    echo "Then export it:"
    echo "  export GITHUB_TOKEN=your_token_here"
    exit 1
fi

if [[ -z "$GITHUB_REPOSITORY" ]]; then
    # Try to get from git remote
    if git remote get-url origin &>/dev/null; then
        ORIGIN_URL=$(git remote get-url origin)
        if [[ "$ORIGIN_URL" =~ github.com[:/]([^/]+/[^/.]+)(\.git)?$ ]]; then
            GITHUB_REPOSITORY="${BASH_REMATCH[1]}"
            echo -e "${BLUE}Detected repository: ${GITHUB_REPOSITORY}${NC}"
        else
            echo -e "${RED}Error: Could not parse GitHub repository from remote${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Error: GITHUB_REPOSITORY not set and could not detect from git${NC}"
        echo "Set it manually: export GITHUB_REPOSITORY=owner/repo"
        exit 1
    fi
fi

echo -e "${BLUE}Repository:${NC} $GITHUB_REPOSITORY"
echo -e "${BLUE}Branch:${NC} $BRANCH"
echo ""

# Function to make GitHub API calls
github_api() {
    local method=$1
    local endpoint=$2
    local data=${3:-}
    
    if [[ -n "$data" ]]; then
        curl -s -X "$method" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -d "$data" \
            "https://api.github.com/repos/${GITHUB_REPOSITORY}${endpoint}"
    else
        curl -s -X "$method" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${GITHUB_REPOSITORY}${endpoint}"
    fi
}

# Get current protection rules
echo -e "${BLUE}Fetching current protection rules...${NC}"
CURRENT_RULES=$(github_api GET "/branches/${BRANCH}/protection" 2>/dev/null || echo "{}")

if echo "$CURRENT_RULES" | jq -e '.message' &>/dev/null; then
    if echo "$CURRENT_RULES" | jq -r '.message' | grep -q "Branch not protected"; then
        echo -e "${YELLOW}Branch is not currently protected${NC}"
        PROTECTED=false
    else
        echo -e "${RED}Error fetching protection rules:${NC}"
        echo "$CURRENT_RULES" | jq -r '.message'
        exit 1
    fi
else
    echo -e "${GREEN}Branch is already protected${NC}"
    PROTECTED=true
fi

# Prepare protection rules
echo ""
echo -e "${BLUE}Configuring protection rules...${NC}"

# Build the protection rules JSON
PROTECTION_RULES=$(cat <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Danger Analysis",
      "Danger Status Check"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismissal_restrictions": {},
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "bypass_pull_request_allowances": {}
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": false
}
EOF
)

# If branch is already protected, merge with existing rules
if [[ "$PROTECTED" == "true" ]]; then
    echo "Merging with existing protection rules..."
    
    # Get existing required checks
    EXISTING_CHECKS=$(echo "$CURRENT_RULES" | jq -r '.required_status_checks.contexts[]?' 2>/dev/null || echo "")
    
    # Add Danger checks if not already present
    DANGER_CHECKS=("Danger Analysis" "Danger Status Check")
    ALL_CHECKS=""
    
    # Add existing checks
    if [[ -n "$EXISTING_CHECKS" ]]; then
        while IFS= read -r check; do
            [[ -z "$check" ]] && continue
            ALL_CHECKS+="\"$check\","
        done <<< "$EXISTING_CHECKS"
    fi
    
    # Add Danger checks if not present
    for check in "${DANGER_CHECKS[@]}"; do
        if [[ -z "$EXISTING_CHECKS" ]] || ! echo "$EXISTING_CHECKS" | grep -q "^$check$"; then
            ALL_CHECKS+="\"$check\","
        fi
    done
    
    # Remove trailing comma
    ALL_CHECKS=${ALL_CHECKS%,}
    
    # Update protection rules with all checks
    PROTECTION_RULES=$(echo "$PROTECTION_RULES" | jq ".required_status_checks.contexts = [$ALL_CHECKS]")
fi

# Apply protection rules
echo ""
read -p "Apply these protection rules to branch '$BRANCH'? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo -e "${BLUE}Applying protection rules...${NC}"

RESPONSE=$(github_api PUT "/branches/${BRANCH}/protection" "$PROTECTION_RULES")

if echo "$RESPONSE" | jq -e '.message' &>/dev/null; then
    echo -e "${RED}Error applying protection rules:${NC}"
    echo "$RESPONSE" | jq -r '.message'
    exit 1
else
    echo -e "${GREEN}✅ Protection rules applied successfully!${NC}"
fi

# Show summary
echo ""
echo -e "${BLUE}📋 Protection Summary:${NC}"
echo ""
echo "Branch '$BRANCH' now requires:"
echo "  ✓ Danger Analysis check to pass"
echo "  ✓ Danger Status Check to pass"
echo "  ✓ PR reviews before merging"
echo "  ✓ Branches to be up to date before merging"
echo ""
echo "The following checks will block PRs:"
echo "  • Any error-level violations in Danger Analysis"
echo "  • Exceeding the maximum warning threshold"
echo "  • Failed status checks"
echo ""

# Create status badge markdown
echo -e "${BLUE}📛 Status Badge:${NC}"
echo ""
echo "Add this to your README.md:"
echo ""
echo "[![Danger Check](https://github.com/${GITHUB_REPOSITORY}/workflows/Danger%20Check/badge.svg)](https://github.com/${GITHUB_REPOSITORY}/actions/workflows/danger-check.yml)"
echo ""

# Instructions for manual configuration
cat > danger-bash/GITHUB_SETUP.md <<EOF
# GitHub Branch Protection Setup

## Automated Setup Complete

Branch protection has been configured for: **${BRANCH}**

## Required Status Checks

The following checks must pass before merging:
- Danger Analysis
- Danger Status Check

## Manual Configuration (if needed)

1. Go to: https://github.com/${GITHUB_REPOSITORY}/settings/branches
2. Click "Add rule" or edit existing rule for '${BRANCH}'
3. Enable "Require status checks to pass before merging"
4. Search and add:
   - "Danger Analysis"
   - "Danger Status Check"
5. Enable "Require branches to be up to date before merging"
6. Save changes

## Testing Protection

1. Create a test PR with a known violation
2. Verify that Danger comments appear
3. Verify that merge is blocked
4. Fix the violation
5. Verify that merge is allowed

## Bypass Protection (Emergency)

Administrators can bypass protection if needed:
1. Use "Merge without waiting for requirements to be met"
2. Document why protection was bypassed
3. Fix issues in a follow-up PR

## Status Badge

\`\`\`markdown
[![Danger Check](https://github.com/${GITHUB_REPOSITORY}/workflows/Danger%20Check/badge.svg)](https://github.com/${GITHUB_REPOSITORY}/actions/workflows/danger-check.yml)
\`\`\`

## Troubleshooting

If checks don't appear:
1. Ensure workflow file is in .github/workflows/
2. Check that workflow triggers on pull_request events
3. Verify GITHUB_TOKEN permissions
4. Check Actions tab for workflow runs

Generated: $(date)
EOF

echo -e "${BLUE}📄 Setup documentation saved to: danger-bash/GITHUB_SETUP.md${NC}"
