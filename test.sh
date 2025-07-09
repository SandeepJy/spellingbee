#!/bin/bash

# Function to log messages with timestamps
log() {
    local level="$1"
    shift
    echo "[$(date '+%H:%M:%S')] $level: $*"
}

# Example content
content="        let j = SomeOptionalVar!" 

# Corrected pattern
pattern='\b\w+!\s'

# Debugging statements
log "DEBUG" "Content: '$content'"
log "DEBUG" "Pattern: '$pattern'"

if echo "$content" | grep -qE "$pattern"; then
    echo "found"
else
    echo "not found"
fi
