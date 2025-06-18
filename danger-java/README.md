# Danger Java System

This is a Java-based refactor of the original Danger.js system for enforcing code quality rules. The system uses JGit for Git integration and Gradle for dependency management.

## Requirements

- Java 11 or later
- Gradle 7.x or later (wrapper included)

## Setup

1. Clone the repository
2. Make sure the `gradlew` script is executable:
   ```
   chmod +x gradlew
   ```

## Usage

### Running Locally

```bash
# Simple usage with default options
./danger.sh

# Specify rules file
./danger.sh --rules ./custom-rules.json

# Specify repository path
./danger.sh --repo /path/to/repo
```

### Running in CI

The system integrates with GitHub Actions. The workflow file is already configured in `.github/workflows/danger-java.yml`. It will automatically run on pull requests to the `main` and `develop` branches.

Required GitHub secrets:
- `GITHUB_TOKEN` (automatically provided by GitHub Actions)

## Configuring Rules

Rules are configured in the `rules.json` file. Each rule has the following structure:

```json
{
  "id": "unique-id",
  "name": "Human-readable name",
  "description": "Description of the rule",
  "severity": "error|warning|info",
  "type": "file_pattern|code_pattern|file_size",
  "patterns": ["pattern1", "pattern2"],
  "file_patterns": ["**/*.swift"],  // Optional, for filtering files
  "exclude_patterns": ["**/test/**"],  // Optional, for excluding matches
  "message": "Message to display when the rule is triggered",
  "max_size_kb": 1024  // For file_size rules only
}
```

## Rule Types

1. **file_pattern**: Checks if modified files match specific glob patterns
2. **code_pattern**: Checks for regex patterns in the added code
3. **file_size**: Checks if modified files exceed a size limit

## Settings

The `settings` object in `rules.json` controls the behavior of the rule engine:

```json
"settings": {
  "fail_on_errors": true,  // Fail the CI if any error-level rules are triggered
  "max_warnings": 10,      // Maximum allowed warnings before failing the CI
  "exclude_files": [...]   // Files to always exclude from checks
}
```

## Extending the System

To add new rule types:
1. Update the `Rule` class with new properties as needed
2. Add a new case in the `executeRule` method in `DangerRuleEngine`
3. Implement the logic for the new rule type as a private method
