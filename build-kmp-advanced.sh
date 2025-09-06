#!/bin/bash

# Advanced build script for Kotlin Multiplatform integration
# This script builds the shared KMP module and creates XCFrameworks

set -e

echo "🔨 Building Kotlin Multiplatform shared module..."

# Navigate to the project root (where gradlew is located)
cd "$(dirname "$0")"

# Check if we're in a clean build or incremental
if [ "$CONFIGURATION" = "Debug" ]; then
    echo "📦 Building Debug XCFramework..."
    ./gradlew :shared:podPublishDebugXCFramework
    XCFRAMEWORK_PATH="shared/build/cocoapods/publish/debug/shared.xcframework"
elif [ "$CONFIGURATION" = "Release" ]; then
    echo "📦 Building Release XCFramework..."
    ./gradlew :shared:podPublishReleaseXCFramework
    XCFRAMEWORK_PATH="shared/build/cocoapods/publish/release/shared.xcframework"
else
    echo "📦 Building both Debug and Release XCFrameworks..."
    ./gradlew :shared:podPublishXCFramework
    XCFRAMEWORK_PATH="shared/build/cocoapods/publish/debug/shared.xcframework"
fi

echo "✅ KMP build completed successfully!"
echo "📁 XCFramework location: $XCFRAMEWORK_PATH"

# Optional: Copy the appropriate XCFramework to a consistent location
if [ -d "$XCFRAMEWORK_PATH" ]; then
    echo "📋 XCFramework is ready for integration"
else
    echo "❌ Error: XCFramework not found at expected location"
    exit 1
fi
