#!/bin/bash

# Check if the script is run inside a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: This script needs to be run inside a Git repository."
    exit 1
fi

# Directory pattern to check for modified files (e.g., "path/to/directory/*")
CHECK_DIR_PATTERN="SpellingBee/*"

# File extension to monitor (e.g., ".swift")
FILE_EXTENSION=".swift"

# Get the name of the current branch
current_branch=$(git branch --show-current)

# Output the diff to a file named 'diff_output.txt'
git diff > diff_output.txt

# Check if there are any changes in the working directory or staging area
if [ -z "$(git status --porcelain)" ]; then
    echo "No changes to diff for branch: $current_branch"
    exit 0
fi

# Read the diff output and check for modified files with the specified extension
while IFS= read -r line; do
    # Extract the file name from the diff line
    if [[ $line =~ ^\+\+.*$ ]]; then
        file_path="${line:3}"
        
        # Check if the file path matches the CHECK_DIR_PATTERN and has the FILE_EXTENSION
        if [[ "$file_path" =~ ^"$CHECK_DIR_PATTERN/" && "$file_path" == *"$FILE_EXTENSION" ]]; then
            echo "Error: The file '$file_path' has been modified."
            exit 1
        fi
    fi
done < diff_output.txt

echo "No monitored files with extension '$FILE_EXTENSION' have been modified in the directory pattern: $CHECK_DIR_PATTERN"
