#!/bin/bash

# Xcode-compatible build script for Kotlin Multiplatform integration
# This script is designed to work within Xcode's sandboxed environment

set -e

echo "🔨 Building Kotlin Multiplatform shared module..."

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if gradlew exists and is executable
if [ ! -f "./gradlew" ]; then
    echo "❌ Error: gradlew not found in $SCRIPT_DIR"
    exit 1
fi

if [ ! -x "./gradlew" ]; then
    echo "❌ Error: gradlew is not executable"
    exit 1
fi

# Build the XCFramework
echo "📦 Building XCFramework..."
./gradlew :shared:podPublishXCFramework

echo "✅ KMP build completed successfully!"
echo "📁 XCFramework location: $SCRIPT_DIR/shared/build/cocoapods/publish/debug/shared.xcframework"
