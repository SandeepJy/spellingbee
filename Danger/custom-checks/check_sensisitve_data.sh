#!/bin/bash
# custom-checks/check-sensitive-data.sh
# Example custom check that uses the improved helper functions

# Check for potential sensitive data in added lines
check_sensitive_data() {
    local sensitive_patterns=(
        "api_key\s*=\s*[\"']"
        "secret\s*=\s*[\"']"
    )
    
    # Get only modified and added files (not deleted)
    local files=$(get_changed_files)
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue  # Skip if file doesn't exist
        
        # Only check certain file types
        if [[ "$file" == *.swift ]] || [[ "$file" == *.json ]] || [[ "$file" == *.plist ]]; then
            # Get added lines with line numbers
            local added_lines=$(get_added_lines_with_numbers "$file")

            while IFS= read -r line_info; do
                [[ -z "$line_info" ]] && continue
                
                local line_number="${line_info%%:*}"
                local content="${line_info#*:}"
                
                # Check each sensitive pattern
                for pattern in "${sensitive_patterns[@]}"; do
                    if echo "$content" | grep -qiE "$pattern" 2>/dev/null; then
                        add_result "error" "sensitive_data" "Potential Sensitive Data" \
                            "Possible sensitive data detected in code" \
                            "Found pattern matching '$pattern' in added line" \
                            "$file" "$line_number"
                    fi
                done
            done <<< "$added_lines"
        fi
    done <<< "$files"
}

# Run the check
check_sensitive_data