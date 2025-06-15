


const { danger, fail, warn, message, markdown } = require('danger');
const fs = require('fs');
const path = require('path');
const minimatch = require('minimatch');

// Load rules configuration
const rulesConfig = JSON.parse(fs.readFileSync(path.join(__dirname, 'rules.json'), 'utf8'));

class DangerRuleEngine {
    constructor(config) {
        this.rules = config.rules;
        this.settings = config.settings;
        this.results = {
            errors: [],
            warnings: [],
            info: []
        };
    }

    async executeRules() {
        const pr = danger.github.pr;
        const git = danger.git;

        // Get modified files
        const modifiedFiles = git.modified_files;
        const createdFiles = git.created_files;
        const allChangedFiles = [...modifiedFiles, ...createdFiles];

        // Get diff content
        const diff = await this.getDiffContent();

        for (const rule of this.rules) {
            try {
                await this.executeRule(rule, allChangedFiles, diff);
            } catch (error) {
                console.error(`Error executing rule ${rule.id}:`, error);
            }
        }

        this.reportResults();
    }

    async executeRule(rule, changedFiles, diff) {
        switch (rule.type) {
            case 'file_pattern':
                this.checkFilePattern(rule, changedFiles);
                break;
            case 'code_pattern':
                await this.checkCodePattern(rule, changedFiles, diff);
                break;
            case 'file_size':
                await this.checkFileSize(rule, changedFiles);
                break;
            default:
                console.warn(`Unknown rule type: ${rule.type}`);
        }
    }

    checkFilePattern(rule, changedFiles) {
        const matchedFiles = changedFiles.filter(file => {
            // Skip excluded files
            if (this.isFileExcluded(file)) return false;

            // Check if file matches any pattern
            return rule.patterns.some(pattern => minimatch(file, pattern));
        });

        if (matchedFiles.length > 0) {
            this.addResult(rule, `Files matched: ${matchedFiles.join(', ')}`);
        }
    }

    async checkCodePattern(rule, changedFiles, diff) {
        const relevantFiles = changedFiles.filter(file => {
            if (this.isFileExcluded(file)) return false;

            // Check file patterns if specified
            if (rule.file_patterns) {
                return rule.file_patterns.some(pattern => minimatch(file, pattern));
            }
            return true;
        });

        for (const file of relevantFiles) {
            const fileDiff = diff[file];
            if (!fileDiff) continue;

            const addedLines = this.getAddedLines(fileDiff);

            for (const pattern of rule.patterns) {
                const regex = new RegExp(pattern, 'g');
                const matches = [];

                addedLines.forEach((line, index) => {
                    // Skip if line matches exclude patterns
                    if (rule.exclude_patterns &&
                        rule.exclude_patterns.some(excludePattern =>
                            line.includes(excludePattern))) {
                        return;
                    }

                    if (regex.test(line)) {
                        matches.push(`Line ${index + 1}: ${line.trim()}`);
                    }
                });

                if (matches.length > 0) {
                    this.addResult(rule, `In ${file}:\n${matches.join('\n')}`);
                }
            }
        }
    }

    async checkFileSize(rule, changedFiles) {
        const relevantFiles = changedFiles.filter(file => {
            if (this.isFileExcluded(file)) return false;

            // Check file patterns
            const matchesPattern = rule.file_patterns.some(pattern =>
                minimatch(file, pattern));

            // Check exclude patterns
            const matchesExclude = rule.exclude_patterns &&
                rule.exclude_patterns.some(pattern => minimatch(file, pattern));

            return matchesPattern && !matchesExclude;
        });

        for (const file of relevantFiles) {
            try {
                const stats = fs.statSync(file);
                const sizeKB = stats.size / 1024;

                if (sizeKB > rule.max_size_kb) {
                    this.addResult(rule, `${file} is ${sizeKB.toFixed(2)}KB (limit: ${rule.max_size_kb}KB)`);
                }
            } catch (error) {
                // File might not exist locally in CI environment
                console.warn(`Could not check size of ${file}:`, error.message);
            }
        }
    }

    addResult(rule, details) {
        const result = {
            rule: rule.name,
            message: rule.message,
            details: details,
            severity: rule.severity
        };

        this.results[rule.severity === 'error' ? 'errors' :
            rule.severity === 'warning' ? 'warnings' : 'info'].push(result);
    }

    isFileExcluded(file) {
        return this.settings.exclude_files.some(pattern =>
            minimatch(file, pattern)
        );
    }

    async getDiffContent() {
        const diff = {};
        const git = danger.git;

        for (const file of [...git.modified_files, ...git.created_files]) {
            try {
                const fileDiff = await danger.git.diffForFile(file);
                diff[file] = fileDiff;
            } catch (error) {
                console.warn(`Could not get diff for ${file}:`, error.message);
            }
        }

        return diff;
    }

    getAddedLines(fileDiff) {
        if (!fileDiff || !fileDiff.diff) return [];

        const lines = fileDiff.diff.split('\n');
        return lines
            .filter(line => line.startsWith('+') && !line.startsWith('+++'))
            .map(line => line.substring(1)); // Remove the '+' prefix
    }

    reportResults() {
        let hasErrors = false;

        // Report errors
        if (this.results.errors.length > 0) {
            hasErrors = true;
            this.results.errors.forEach(result => {
                fail(`**${result.rule}**: ${result.message}\n\n${result.details}`);
            });
        }

        // Report warnings
        if (this.results.warnings.length > 0) {
            this.results.warnings.forEach(result => {
                warn(`**${result.rule}**: ${result.message}\n\n${result.details}`);
            });

            // Check if too many warnings
            if (this.settings.max_warnings &&
                this.results.warnings.length > this.settings.max_warnings) {
                fail(`Too many warnings (${this.results.warnings.length}). Maximum allowed: ${this.settings.max_warnings}`);
                hasErrors = true;
            }
        }

        // Report info
        if (this.results.info.length > 0) {
            this.results.info.forEach(result => {
                message(`**${result.rule}**: ${result.message}\n\n${result.details}`);
            });
        }

        // Summary
        const summary = this.generateSummary();
        markdown(summary);

        // Fail if configured to do so
        if (hasErrors && this.settings.fail_on_errors) {
            fail("PR blocked due to rule violations. Please fix the errors above.");
        }
    }

    generateSummary() {
        const totalIssues = this.results.errors.length +
            this.results.warnings.length +
            this.results.info.length;

        if (totalIssues === 0) {
            return "## ✅ Danger Check Passed\n\nNo rule violations found!";
        }

        let summary = "## 📋 Danger Check Summary\n\n";

        if (this.results.errors.length > 0) {
            summary += `❌ **${this.results.errors.length} Error(s)**\n`;
        }

        if (this.results.warnings.length > 0) {
            summary += `⚠️ **${this.results.warnings.length} Warning(s)**\n`;
        }

        if (this.results.info.length > 0) {
            summary += `ℹ️ **${this.results.info.length} Info**\n`;
        }

        summary += "\n---\n\n";
        summary += "*This check is powered by a JSON-driven rule system. ";
        summary += "Rules can be modified in `danger-system/rules.json`.*";

        return summary;
    }
}

// Execute the danger rules
async function main() {
    const ruleEngine = new DangerRuleEngine(rulesConfig);
    const files = ['app.js', 'style.css', 'index.html', 'lib.js'];
    const jsFiles = files.filter((file) => minimatch(file, '*.js'));
    console.log(jsFiles); // ["app.js", "lib.js"]
    await ruleEngine.executeRules();
}

main().catch(console.error);