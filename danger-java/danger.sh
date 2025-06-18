#!/bin/bash

# Simple wrapper script to run Danger Java locally

# Default values
MODE="local"
RULES_PATH="./rules.json"
REPO_PATH="."

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --ci)
      MODE="ci"
      shift
      ;;
    --rules)
      RULES_PATH="$2"
      shift
      shift
      ;;
    --repo)
      REPO_PATH="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Run with Gradle
./gradlew runDanger --args="$MODE,$RULES_PATH,$REPO_PATH"
