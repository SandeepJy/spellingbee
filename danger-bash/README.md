# Danger Bash - Git Diff Static Analysis System

A lightweight, bash-based alternative to Danger JS that performs static analysis on git diffs and integrates with GitHub pull requests.

## Features

- ✅ **Pure Bash Implementation** - No Node.js or additional toolchains required
- 🔍 **Git Diff Analysis** - Analyzes only changed/added code in PRs
- 📋 **JSON-Driven Rules** - Easily configurable rules system
- 🚦 **Severity Levels** - Error, Warning, and Info classifications
- 💬 **GitHub Integration** - Automatic PR comments with analysis results
- 🚫 **PR Blocking** - Fails CI on error-level violations
- 📊 **Detailed Reporting** - JSON output for further processing

## Requirements

- Bash 4.0+
- Git
- jq (JSON processor)
- curl (for GitHub API integration)

## Installation

1. Copy the `danger-bash` directory to your repository:

```bash
cp -r danger-bash /path/to/your/repo/
```

2. Make scripts executable:

```bash
chmod +x danger-bash/*.sh
```

3. Install jq if not already installed:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

## Usage

### Local Testing

Test your changes before creating a pull request:

```bash
./danger-bash/test-locally.sh [base-branch]

# Examples:
./danger-bash/test-locally.sh main
./danger-bash/test-locally.sh develop
```

### Manual Analysis

Run the analyzer directly:

```bash
./danger-bash/danger-analyze.sh \
  --rules ./danger-bash/rules.json \
  --output danger-results.json \
  --base main \
  --verbose
```

Options:
- `-r, --rules FILE` - Path to rules.json file (default: ./rules.json)
- `-o, --output FILE` - Output file for results (default: danger-results.json)
- `-b, --base BRANCH` - Base branch to compare against (default: main)
- `-v, --verbose` - Enable verbose logging
- `-h, --help` - Show help message

### GitHub Actions Integration

Add the workflow to your repository:

```bash
cp danger-bash/.github/workflows/danger-check.yml .github/workflows/
```

The workflow will:
1. Run on all pull requests
2. Analyze changed files against configured rules
3. Post/update a comment with results
4. Block the PR if error-level issues are found

## Configuration

### Rules Configuration (rules.json)

The system uses a JSON configuration file to define analysis rules:

```json
{
  "rules": [
    {
      "id": "unique-rule-id",
      "name": "Human Readable Name",
      "description": "Detailed description",
      "severity": "error|warning|info",
      "type": "file_pattern|code_pattern|file_size",
      "patterns": ["pattern1", "pattern2"],
      "message": "Message shown when rule is violated"
    }
  ],
  "settings": {
    "fail_on_errors": true,
    "max_warnings": 10,
    "exclude_files": ["**/Pods/**", "**/.build/**"]
  }
}
```

### Rule Types

#### 1. File Pattern Rules
Check if modified files match certain patterns:

```json
{
  "type": "file_pattern",
  "patterns": ["**/*.entitlements", "**/Info.plist"]
}
```

#### 2. Code Pattern Rules
Search for patterns in added code lines only:

```json
{
  "type": "code_pattern",
  "patterns": ["print\\s*\\(", "NSLog\\s*\\("],
  "file_patterns": ["**/*.swift"],
  "exclude_patterns": ["// DEBUG:", "#if DEBUG"]
}
```

#### 3. File Size Rules
Check for files exceeding size limits:

```json
{
  "type": "file_size",
  "max_size_kb": 1024,
  "file_patterns": ["**/*"],
  "exclude_patterns": ["**/*.xcassets/**"]
}
```

### Severity Levels

- **error** - Must be fixed before merging (blocks PR)
- **warning** - Should be reviewed but doesn't block
- **info** - Informational only

## Output Format

The analyzer produces a JSON file with the following structure:

```json
{
  "timestamp": "2024-01-20T10:30:00Z",
  "branch": "feature/new-feature",
  "base_branch": "main",
  "commit": "abc123def456",
  "results": {
    "errors": [
      {
        "rule_id": "force-unwrap-usage",
        "rule_name": "Force Unwrapping Detected",
        "severity": "error",
        "message": "Force unwrapping detected...",
        "details": "Pattern found in added line...",
        "file": "App/ViewController.swift",
        "line": 42
      }
    ],
    "warnings": [],
    "info": []
  },
  "summary": {
    "error_count": 1,
    "warning_count": 0,
    "info_count": 0,
    "passed": false
  }
}
```

## GitHub PR Comment

The system automatically posts/updates a formatted comment on pull requests:

```markdown
## 🔍 Danger Analysis Report

### ❌ Issues found that require attention

**Summary** (commit abc123d)
- 🔴 **Errors:** 1
- 🟡 **Warnings:** 2
- 🔵 **Info:** 1

### ❌ Errors
...

### ⚠️ Warnings
...
```

## Migrating from Danger JS

1. **Replace dangerfile.js** with the bash scripts
2. **Convert rules** from JS logic to JSON configuration
3. **Update CI workflow** to use the new GitHub Action
4. **Remove Node dependencies** (package.json, node_modules)

### Key Differences

| Feature | Danger JS | Danger Bash |
|---------|-----------|-------------|
| Runtime | Node.js | Bash |
| Configuration | JavaScript | JSON |
| Dependencies | npm packages | jq, git, curl |
| PR Comments | Via Danger API | Direct GitHub API |
| Extensibility | JS plugins | Bash scripts |

## Examples

### Example 1: Detect Force Unwrapping in Swift

```json
{
  "id": "force-unwrap",
  "name": "Force Unwrapping",
  "severity": "error",
  "type": "code_pattern",
  "patterns": ["!\\s*(?!//|/\\*)"],
  "file_patterns": ["**/*.swift"],
  "exclude_patterns": ["// swiftlint:disable"],
  "message": "Avoid force unwrapping"
}
```

### Example 2: Check for Debug Code

```json
{
  "id": "debug-code",
  "name": "Debug Code",
  "severity": "warning",
  "type": "code_pattern",
  "patterns": ["debugPrint", "print\\(", "NSLog"],
  "file_patterns": ["**/*.swift", "**/*.m"],
  "exclude_patterns": ["#if DEBUG", "// DEBUG"],
  "message": "Remove debug code before merging"
}
```

### Example 3: Large File Detection

```json
{
  "id": "large-files",
  "name": "Large Files",
  "severity": "warning",
  "type": "file_size",
  "max_size_kb": 500,
  "file_patterns": ["**/*"],
  "exclude_patterns": ["**/*.png", "**/*.jpg"],
  "message": "Large file detected - consider optimization"
}
```

## Troubleshooting

### Issue: "jq: command not found"
Install jq using your package manager (see Installation section)

### Issue: "Permission denied"
Make scripts executable: `chmod +x danger-bash/*.sh`

### Issue: "Base branch not found"
Fetch the base branch: `git fetch origin main:main`

### Issue: No PR comment appears
Check GitHub token permissions and environment variables:
- `GITHUB_TOKEN` must have write access to issues/PRs
- `GITHUB_REPOSITORY` must be in format "owner/repo"
- `GITHUB_PR_NUMBER` must be a valid PR number

## Contributing

To add new rule types:

1. Add the type handler in `danger-analyze.sh`
2. Update the documentation
3. Add example rules to `rules.json`
4. Test locally before submitting

## License

This project is provided as-is for use in your repositories. Modify as needed for your specific requirements.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review the example configurations
3. Test locally with verbose mode enabled
4. Check GitHub Actions logs for CI issues
