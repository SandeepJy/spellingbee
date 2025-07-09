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
info=0
results=()

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
    "infos": []
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

# Add result to results array
add_result() {
    local severity=$1
    local rule_id=$2
    local rule_name=$3
    local message=$4
    local details=$5
    local file=$6
    local line_number=${7:-0}

   
    # Escape JSON strings
    message=$(echo "$message" | jq -Rs . 2>&1)
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to escape message: $message"
        return 1
    fi

    details=$(echo "$details" | jq -Rs . 2>&1)
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to escape details: $details"
        return 1
    fi

    file=$(echo "$file" | jq -Rs . 2>&1)
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to escape file: $file"
        return 1
    fi

    rule_name=$(echo "$rule_name" | jq -Rs . 2>&1)
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to escape rule_name: $rule_name"
        return 1
    fi
    
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
    log "DEBUG" "sandeep appending result"
    # Append result to results array
    results+=("$result")
    log "DEBUG" "sandeep appending result $severity"
    # Update counters
    case $severity in
        error) let errors+=1 ;;
        warning) let warnings+=1 ;;
        info) let info+=1 ;;
    esac

    log "DEBUG" "Errors: $errors, Warnings: $warnings, Info: $info"

    log "DEBUG" "Result added successfully"
}

# Update results in JSON file after processing all rules
update_results() {
    local temp_file=$(mktemp)

    # Create initial JSON structure with empty results arrays
    cat > "$temp_file" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "branch": "$(git rev-parse --abbrev-ref HEAD)",
  "base_branch": "${BASE_BRANCH}",
  "commit": "$(git rev-parse HEAD)",
  "results": {
    "errors": [],
    "warnings": [],
    "infos": []
  },
  "summary": {
    "error_count": $errors,
    "warning_count": $warnings,
    "info_count": $info,
    "passed": false
  }
}
EOF

    # Append results to the appropriate arrays
    for result in "${results[@]}"; do
        local severity=$(echo "$result" | jq -r '.severity')
        local severity_key="${severity}s"
        
        jq ".results.${severity_key} += [$result]" "$temp_file" > "$OUTPUT_FILE"
        if [[ $? -ne 0 ]]; then
            log "ERROR" "Failed to update results in JSON file: $OUTPUT_FILE"
            return 1
        fi
        
        mv "$OUTPUT_FILE" "$temp_file"
    done

    # Update summary
    jq ".summary.error_count = $errors | 
        .summary.warning_count = $warnings | 
        .summary.info_count = $info | 
        .summary.passed = $(if [[ $errors -eq 0 ]]; then echo "true"; else echo "false"; fi)" "$temp_file" > "$OUTPUT_FILE"
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to update summary in JSON file: $OUTPUT_FILE"
        return 1
    fi

    mv "$temp_file" "$OUTPUT_FILE"

    log "DEBUG" "Results and summary updated successfully"
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
                log "INFO" "done Add rule"
            fi
        done <<< "$patterns"
    done <<< "$changed_files"
    log "INFO" "done Add rule - out"
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
    local file_patterns=$(echo "$rule_json" | jq -r '.file_patterns[]?' 2>/dev/null || echo "")
    local exclude_patterns=$(echo "$rule_json" | jq -r '.exclude_patterns[]?' 2>/dev/null || echo "")
   
    log "INFO" "Checking code pattern rule: $rule_name"
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
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
        
        # Get the full diff with line numbers for both staged and unstaged changes
        local diff_output_staged=$(git diff --cached -- "$file" 2>/dev/null || true)
        local diff_output_unstaged=$(git diff -- "$file" 2>/dev/null || true)
        
        # Combine staged and unstaged diffs
        local diff_output="$diff_output_staged$diff_output_unstaged"
        
        
        if [[ -z "$diff_output" ]]; then
            continue
        fi
        
        # Parse diff to get added lines with their line numbers
        local current_line=0
        local in_hunk=false
        
        while IFS= read -r line; do


            if [[ "$line" =~ ^@@\ -[0-9]+,[0-9]+\ \+([0-9]+),[0-9]+\ @@ ]]; then
                # Extract starting line number for new file
                current_line=${BASH_REMATCH[1]}
                in_hunk=true
                continue
            fi
            
            if [[ "$in_hunk" == "true" ]]; then
                if [[ "$line" =~ ^[+] ]]; then
                    # This is an added line
                    local content="${line:1}"  # Remove the + prefix

                    # Check exclude patterns first
                    local excluded=false
                    if [[ -n "$exclude_patterns" ]]; then
                        while IFS= read -r exclude_pattern; do
                            [[ -z "$exclude_pattern" ]] && continue
                            if [[ "$content" == *"$exclude_pattern"* ]]; then
                                excluded=true
                                break
                            fi
                        done <<< "$exclude_patterns"
                    fi
                    
                    if [[ "$excluded" == "false" ]]; then
                        # Check each pattern against the content
                        while IFS= read -r pattern; do
                            [[ -z "$pattern" ]] && continue
                            
                            # Use grep for regex matching
                            if echo "$content" | grep -qE "$pattern" 2>/dev/null; then
                                log "MATCH" "Pattern '$pattern' found in $file at line $current_line"
                                local detail="Pattern found in added line: $(echo "$content" | head -c 100)..."
                                add_result "$severity" "$rule_id" "$rule_name" "$message" "$detail" "$file" "$current_line"
                            fi
                        done <<< "$patterns"
                    fi
                    
                    ((current_line++))
                elif [[ "$line" =~ ^[^-] ]]; then
                    # Context line or unchanged line
                    ((current_line++))
                fi
                # Lines starting with - are deletions, don't increment line number
            fi
        done <<< "$diff_output"
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

# Get list of changed files (staged, unstaged, and newly added)
get_changed_files() {
    # Determine if running in a GitHub CI environment
    if [ -n "${GITHUB_BASE_REF:-}" ]; then
        # Fetch the base branch (GitHub CI)
        git fetch origin $GITHUB_BASE_REF
        local base_branch="origin/$GITHUB_BASE_REF"
    else
        # Assume local development and compare against 'main' branch
        git fetch origin main
        local base_branch="origin/main"
    fi

    # Get the current branch name
    local current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Fetch the base branch to ensure we have the latest changes
    git fetch origin $base_branch

    # Get changes between the current commit and the base branch
    local all_changes=$(git diff --name-only $base_branch..$current_branch)

    log "INFO" "All Changed $all_changes"

    # Print the list of changed files
    echo "$all_changes"
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
                if [[ $? -ne 0 ]]; then
                    log "ERROR" "Error processing file_pattern rule for: $rule"
                fi
                ;;
            code_pattern)
                check_code_pattern "$rule" "$filtered_files"
                if [[ $? -ne 0 ]]; then
                    log "ERROR" "Error processing code_pattern rule for: $rule"
                fi
                ;;
            file_size)
                check_file_size "$rule" "$filtered_files"
                if [[ $? -ne 0 ]]; then
                    log "ERROR" "Error processing file_size rule for: $rule"
                fi
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
        .summary.info_count = $info | 
        .summary.passed = $passed" "$OUTPUT_FILE" > "$temp_file"
    mv "$temp_file" "$OUTPUT_FILE"
}

# Print summary to stdout
print_summary() {
    echo ""
    echo "========================================="
    echo "         Danger Analysis Summary         "
    echo "========================================="
    
    if (( errors == 0 && warnings == 0 && info == 0 )); then
        echo -e "${GREEN}✅ All checks passed!${NC}"
    else
        if (( errors > 0 )); then
            echo -e "${RED}❌ Errors: $errors${NC}"
        fi
        if (( warnings > 0 )); then
            echo -e "${YELLOW}⚠️  Warnings: $warnings${NC}"
        fi
        if (( info > 0 )); then
            echo -e "${BLUE}ℹ️  Info: $info${NC}"
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
    
    # Save results to JSON file
    update_results

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
