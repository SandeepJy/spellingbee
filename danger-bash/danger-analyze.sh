#!/bin/bash
#
# danger-analyze.sh - Main analyzer script for checking git diffs against rules
# This script replaces the Danger JS functionality with pure bash
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Default configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${RULES_FILE:-${SCRIPT_DIR}/rules.json}"
OUTPUT_FILE="${OUTPUT_FILE:-danger-results.json}"
BASE_BRANCH="${BASE_BRANCH:-main}"
VERBOSE="${VERBOSE:-false}"

# Counters
errors=0
warnings=0
infos=0

# Initialize results JSON
init_results() {
    cat > "$OUTPUT_FILE" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "branch": "$(git rev-parse --abbrev-ref HEAD)",
  "base_branch": "${BASE_BRANCH}",
  "commit": "$(git rev-parse HEAD)",
  "results": {
    "errors": [],
    "warnings": [],
    "info": []
  },
  "summary": {
    "error_count": 0,
    "warning_count": 0,
    "info_count": 0,
    "passed": false
  }
}
EOF
}

# Log function
log() {
    local level=$1
    shift
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $level: $*" >&2
    fi
}

# Add result to JSON file
add_result() {
    local severity=$1
    local rule_id=$2
    local rule_name=$3
    local message=$4
    local details=$5
    local file=$6
    local line_number=${7:-0}

    # Escape JSON strings
    message=$(echo "$message" | jq -Rs .)
    details=$(echo "$details" | jq -Rs .)
    file=$(echo "$file" | jq -Rs .)
    rule_name=$(echo "$rule_name" | jq -Rs .)
    
    # Create result object
    local result=$(cat <<EOF
{
  "rule_id": "$rule_id",
  "rule_name": $rule_name,
  "severity": "$severity",
  "message": $message,
  "details": $details,
  "file": $file,
  "line": $line_number
}
EOF
)

    # Update results array in JSON file
    local temp_file=$(mktemp)
    local severity_key="${severity}s"  # Convert to plural
    
    jq ".results.${severity_key} += [${result}]" "$OUTPUT_FILE" > "$temp_file"
    mv "$temp_file" "$OUTPUT_FILE"

    # Update counters
    case $severity in
        error) ((errors++)) ;;
        warning) ((warnings++)) ;;
        info) ((infos++)) ;;
    esac
}

# Check file pattern rules
check_file_pattern() {
    local rule_json=$1
    local changed_files=$2
    
    local rule_id=$(echo "$rule_json" | jq -r '.id')
    local rule_name=$(echo "$rule_json" | jq -r '.name')
    local severity=$(echo "$rule_json" | jq -r '.severity')
    local message=$(echo "$rule_json" | jq -r '.message')
    local patterns=$(echo "$rule_json" | jq -r '.patterns[]')
    
    log "INFO" "Checking rule: $rule_name"
    
    while IFS= read -r file; do
        while IFS= read -r pattern; do
            # Convert glob pattern to find pattern
            if [[ "$file" == $pattern ]]; then
                log "MATCH" "File $file matches pattern $pattern"
                add_result "$severity" "$rule_id" "$rule_name" "$message" "File matched: $file" "$file"
            fi
        done <<< "$patterns"
    done <<< "$changed_files"
}

# Check code pattern rules (only in added lines)
check_code_pattern() {
    local rule_json=$1
    local changed_files=$2
    
    local rule_id=$(echo "$rule_json" | jq -r '.id')
    local rule_name=$(echo "$rule_json" | jq -r '.name')
    local severity=$(echo "$rule_json" | jq -r '.severity')
    local message=$(echo "$rule_json" | jq -r '.message')
    local patterns=$(echo "$rule_json" | jq -r '.patterns[]')
    local file_patterns=$(echo "$rule_json" | jq -r '.file_patterns[]?' 2>/dev/null || echo "**")
    local exclude_patterns=$(echo "$rule_json" | jq -r '.exclude_patterns[]?' 2>/dev/null || echo "")
    
    log "INFO" "Checking code pattern rule: $rule_name"
    
    while IFS= read -r file; do
        # Check if file matches file_patterns
        local should_check=false
        
        if [[ -z "$file_patterns" ]] || [[ "$file_patterns" == "**" ]]; then
            should_check=true
        else
            while IFS= read -r file_pattern; do
                if [[ -n "$file_pattern" ]] && [[ "$file" == $file_pattern ]]; then
                    should_check=true
                    break
                fi
            done <<< "$file_patterns"
        fi
        
        if [[ "$should_check" == "false" ]]; then
            continue
        fi
        
        # Get only added lines from the diff
        local added_lines=$(git diff "${BASE_BRANCH}...HEAD" -- "$file" 2>/dev/null | grep '^+' | grep -v '^+++' || true)
        
        if [[ -z "$added_lines" ]]; then
            continue
        fi
        
        # Check each pattern against added lines
        while IFS= read -r pattern; do
            [[ -z "$pattern" ]] && continue
            
            # Process each added line
            local line_num=0
            while IFS= read -r line; do
                ((line_num++))
                # Remove the + prefix
                line="${line:1}"
                
                # Check exclude patterns
                local excluded=false
                if [[ -n "$exclude_patterns" ]]; then
                    while IFS= read -r exclude_pattern; do
                        [[ -z "$exclude_pattern" ]] && continue
                        if [[ "$line" == *"$exclude_pattern"* ]]; then
                            excluded=true
                            break
                        fi
                    done <<< "$exclude_patterns"
                fi
                
                if [[ "$excluded" == "true" ]]; then
                    continue
                fi
                
                # Check if line matches pattern (using grep for regex)
                if echo "$line" | grep -qE "$pattern" 2>/dev/null; then
                    log "MATCH" "Pattern '$pattern' found in $file at line $line_num"
                    local detail="Pattern found in added line: $(echo "$line" | head -c 100)..."
                    add_result "$severity" "$rule_id" "$rule_name" "$message" "$detail" "$file" "$line_num"
                fi
            done <<< "$added_lines"
        done <<< "$patterns"
    done <<< "$changed_files"
}

# Check file size rules
check_file_size() {
    local rule_json=$1
    local changed_files=$2
    
    local rule_id=$(echo "$rule_json" | jq -r '.id')
    local rule_name=$(echo "$rule_json" | jq -r '.name')
    local severity=$(echo "$rule_json" | jq -r '.severity')
    local message=$(echo "$rule_json" | jq -r '.message')
    local max_size_kb=$(echo "$rule_json" | jq -r '.max_size_kb')
    local file_patterns=$(echo "$rule_json" | jq -r '.file_patterns[]?' 2>/dev/null || echo "**")
    local exclude_patterns=$(echo "$rule_json" | jq -r '.exclude_patterns[]?' 2>/dev/null || echo "")
    
    log "INFO" "Checking file size rule: $rule_name"
    
    while IFS= read -r file; do
        [[ ! -f "$file" ]] && continue
        
        # Check exclude patterns
        local excluded=false
        if [[ -n "$exclude_patterns" ]]; then
            while IFS= read -r exclude_pattern; do
                [[ -z "$exclude_pattern" ]] && continue
                if [[ "$file" == $exclude_pattern ]]; then
                    excluded=true
                    break
                fi
            done <<< "$exclude_patterns"
        fi
        
        [[ "$excluded" == "true" ]] && continue
        
        # Check file size
        local size_kb=$(( $(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0) / 1024 ))
        
        if (( size_kb > max_size_kb )); then
            log "MATCH" "File $file exceeds size limit: ${size_kb}KB > ${max_size_kb}KB"
            local detail="File size: ${size_kb}KB (limit: ${max_size_kb}KB)"
            add_result "$severity" "$rule_id" "$rule_name" "$message" "$detail" "$file"
        fi
    done <<< "$changed_files"
}

# Get list of changed files
get_changed_files() {
    # Get files that are modified or added in this branch compared to base
    git diff --name-only "${BASE_BRANCH}...HEAD" 2>/dev/null || \
    git diff --name-only HEAD~1 2>/dev/null || \
    echo ""
}

# Check if file should be excluded
is_excluded_file() {
    local file=$1
    local exclude_patterns=$(jq -r '.settings.exclude_files[]?' "$RULES_FILE" 2>/dev/null)
    
    if [[ -n "$exclude_patterns" ]]; then
        while IFS= read -r pattern; do
            [[ -z "$pattern" ]] && continue
            if [[ "$file" == $pattern ]]; then
                return 0  # File is excluded
            fi
        done <<< "$exclude_patterns"
    fi
    
    return 1  # File is not excluded
}

# Process all rules
process_rules() {
    local changed_files=$(get_changed_files)
    
    if [[ -z "$changed_files" ]]; then
        log "WARN" "No changed files found"
        return 0
    fi
    
    # Filter out excluded files
    local filtered_files=""
    while IFS= read -r file; do
        if ! is_excluded_file "$file"; then
            filtered_files+="${file}"$'\n'
        else
            log "INFO" "Excluding file: $file"
        fi
    done <<< "$changed_files"
    
    # Process each rule
    local rules=$(jq -c '.rules[]' "$RULES_FILE" 2>/dev/null)
    
    while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        
        local rule_type=$(echo "$rule" | jq -r '.type')
        
        case "$rule_type" in
            file_pattern)
                check_file_pattern "$rule" "$filtered_files"
                ;;
            code_pattern)
                check_code_pattern "$rule" "$filtered_files"
                ;;
            file_size)
                check_file_size "$rule" "$filtered_files"
                ;;
            *)
                log "WARN" "Unknown rule type: $rule_type"
                ;;
        esac
    done <<< "$rules"
}

# Update summary in results
update_summary() {
    local passed="true"
    local fail_on_errors=$(jq -r '.settings.fail_on_errors' "$RULES_FILE" 2>/dev/null || echo "true")
    local max_warnings=$(jq -r '.settings.max_warnings' "$RULES_FILE" 2>/dev/null || echo "999")
    
    # Check if should fail
    if [[ "$fail_on_errors" == "true" ]] && (( errors > 0 )); then
        passed="false"
    fi
    
    if (( warnings > max_warnings )); then
        passed="false"
    fi
    
    # Update summary
    local temp_file=$(mktemp)
    jq ".summary.error_count = $errors | 
        .summary.warning_count = $warnings | 
        .summary.info_count = $infos | 
        .summary.passed = $passed" "$OUTPUT_FILE" > "$temp_file"
    mv "$temp_file" "$OUTPUT_FILE"
}

# Print summary to stdout
print_summary() {
    echo ""
    echo "========================================="
    echo "         Danger Analysis Summary         "
    echo "========================================="
    
    if (( errors == 0 && warnings == 0 && infos == 0 )); then
        echo -e "${GREEN}✅ All checks passed!${NC}"
    else
        if (( errors > 0 )); then
            echo -e "${RED}❌ Errors: $errors${NC}"
        fi
        if (( warnings > 0 )); then
            echo -e "${YELLOW}⚠️  Warnings: $warnings${NC}"
        fi
        if (( infos > 0 )); then
            echo -e "${BLUE}ℹ️  Info: $infos${NC}"
        fi
    fi
    
    echo "========================================="
    echo ""
    echo "Full results saved to: $OUTPUT_FILE"
    
    # Return non-zero exit code if there are errors
    local passed=$(jq -r '.summary.passed' "$OUTPUT_FILE")
    if [[ "$passed" == "false" ]]; then
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    echo "🔍 Starting Danger Analysis..."
    
    # Check dependencies
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        echo "Error: git is required but not installed."
        exit 1
    fi
    
    # Check if rules file exists
    if [[ ! -f "$RULES_FILE" ]]; then
        echo "Error: Rules file not found at $RULES_FILE"
        exit 1
    fi
    
    # Initialize results
    init_results
    
    # Process rules
    process_rules
    
    # Update summary
    update_summary
    
    # Print summary and exit with appropriate code
    print_summary
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--rules)
            RULES_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -b|--base)
            BASE_BRANCH="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -r, --rules FILE     Path to rules.json file (default: ./rules.json)"
            echo "  -o, --output FILE    Output file for results (default: danger-results.json)"
            echo "  -b, --base BRANCH    Base branch to compare against (default: main)"
            echo "  -v, --verbose        Enable verbose logging"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
