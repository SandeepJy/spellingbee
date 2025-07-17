#!/bin/bash
# Danger/custom-checks/filename-validator.sh

# Check filenames against naming conventions
validate_filenames() {
    log "INFO" "Validating filenames against naming conventions..."
    
    # Get added files
    local added_files=$(get_added_files)
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        
        echo "Sandeep check file $file"
        # Check if filename contains spaces
        if [[ "$file" == *-* ]]; then
            add_result "error" "filename_spaces" "Filename Contains Spaces" \
                "Filenames should not contain spaces" \
                "File: $file" "$file" "0"
        fi
    done <<< "$added_files"
    
    log "INFO" "Filename validation completed"
}

# Run the validation
validate_filenames