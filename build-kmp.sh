#!/bin/bash

# Build script for Kotlin Multiplatform integration
# This script builds the shared KMP module and creates XCFrameworks

set -e

echo "🔨 Building Kotlin Multiplatform shared module..."

# Navigate to the project root (where gradlew is located)
cd "$(dirname "$0")"

# Build the XCFramework
echo "📦 Building XCFramework..."
./gradlew :shared:podPublishXCFramework

echo "✅ KMP build completed successfully!"
echo "📁 XCFramework location: shared/build/cocoapods/publish/debug/shared.xcframework"
