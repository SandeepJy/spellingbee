#!/bin/bash

# Manual build script for Kotlin Multiplatform framework
# Run this script manually before building in Xcode

set -e

echo "🔨 Building Kotlin Multiplatform shared module..."

# Navigate to the project root
cd "$(dirname "$0")"

# Build the XCFramework
echo "📦 Building XCFramework..."
./gradlew :shared:podPublishXCFramework

echo "✅ KMP build completed successfully!"
echo "📁 XCFramework location: $(pwd)/shared/build/cocoapods/publish/debug/shared.xcframework"
echo ""
echo "Now you can build your iOS project in Xcode!"
