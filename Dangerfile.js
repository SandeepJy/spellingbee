const { fs } = require('fs');
const path = require('path');
const { danger, warn, fail, message } = require('danger');
const minimatch = require('minimatch');

// Load rules configuration
const rulesConfig = JSON.parse(fs.readFileSync('danger-rules.json', 'utf8'));

class DangerRuleEngine {
    constructor(config) {
        this.rules = config.rules;
    }

    async executeRules() {
        for (const rule of this.rules) {
            try {
                await this.executeRule(rule);
            } catch (error) {
                console.error(`Error executing rule ${rule.id}:`, error);
            }
        }
    }

    async executeRule(rule) {
        switch (rule.type) {
            case 'file_modified':
                this.checkFileModified(rule);
                break;
            case 'api_usage':
                await this.checkApiUsage(rule);
                break;
            case 'api_usage_in_file':
                await this.checkApiUsageInFile(rule);
                break;
            case 'file_size':
                await this.checkFileSize(rule);
                break;
            case 'missing_tests':
                this.checkMissingTests(rule);
                break;
            default:
                console.warn(`Unknown rule type: ${rule.type}`);
        }
    }

    checkFileModified(rule) {
        const modifiedFiles = danger.git.modified_files.concat(danger.git.created_files);
        const matchingFiles = modifiedFiles.filter(file =>
            rule.config.patterns.some(pattern => minimatch(file, pattern))
        );

        if (matchingFiles.length > 0) {
            const fileList = matchingFiles.map(f => `- ${f}`).join('\n');
            const fullMessage = `${rule.config.message}\n\nAffected files:\n${fileList}`;
            this.reportIssue(rule.severity, fullMessage);
        }
    }

    async checkApiUsage(rule) {
        const filesToCheck = danger.git.modified_files
            .concat(danger.git.created_files)
            .filter(file => rule.config.patterns.some(pattern => minimatch(file, pattern)));

        for (const file of filesToCheck) {
            try {
                const content = fs.readFileSync(file, 'utf8');
                const violations = this.findPatternViolations(content, rule.config.forbidden_patterns);

                if (violations.length > 0) {
                    const violationDetails = violations.map(v => `Line ${v.line}: ${v.match}`).join('\n');
                    const fullMessage = `${rule.config.message}\n\nIn file: ${file}\n${violationDetails}`;
                    this.reportIssue(rule.severity, fullMessage);
                }
            } catch (error) {
                console.warn(`Could not read file ${file}:`, error.message);
            }
        }
    }

    async checkApiUsageInFile(rule) {
        const filesToCheck = danger.git.modified_files
            .concat(danger.git.created_files)
            .filter(file => rule.config.file_patterns.some(pattern => minimatch(file, pattern)));

        for (const file of filesToCheck) {
            try {
                const content = fs.readFileSync(file, 'utf8');
                const violations = this.findPatternViolations(content, rule.config.forbidden_patterns);

                if (violations.length > 0) {
                    const violationDetails = violations.map(v => `Line ${v.line}: ${v.match}`).join('\n');
                    const fullMessage = `${rule.config.message}\n\nIn file: ${file}\n${violationDetails}`;
                    this.reportIssue(rule.severity, fullMessage);
                }
            } catch (error) {
                console.warn(`Could not read file ${file}:`, error.message);
            }
        }
    }

    async checkFileSize(rule) {
        const filesToCheck = danger.git.modified_files
            .concat(danger.git.created_files)
            .filter(file => rule.config.patterns.some(pattern => minimatch(file, pattern)));

        for (const file of filesToCheck) {
            try {
                const content = fs.readFileSync(file, 'utf8');
                const lines = content.split('\n').length;

                if (lines > rule.config.max_lines) {
                    const fullMessage = `${rule.config.message}\n\nFile: ${file} (${lines} lines)`;
                    this.reportIssue(rule.severity, fullMessage);
                }
            } catch (error) {
                console.warn(`Could not read file ${file}:`, error.message);
            }
        }
    }

    checkMissingTests(rule) {
        const sourceFiles = danger.git.created_files
            .filter(file => rule.config.source_patterns.some(pattern => minimatch(file, pattern)))
            .filter(file => !rule.config.exclude_patterns.some(pattern => minimatch(file, pattern)));

        const testFiles = danger.git.created_files
            .concat(danger.git.modified_files)
            .filter(file => rule.config.test_patterns.some(pattern => minimatch(file, pattern)));

        const filesWithoutTests = sourceFiles.filter(sourceFile => {
            const baseName = path.basename(sourceFile, '.swift');
            return !testFiles.some(testFile => testFile.includes(baseName));
        });

        if (filesWithoutTests.length > 0) {
            const fileList = filesWithoutTests.map(f => `- ${f}`).join('\n');
            const fullMessage = `${rule.config.message}\n\nFiles without tests:\n${fileList}`;
            this.reportIssue(rule.severity, fullMessage);
        }
    }

    findPatternViolations(content, patterns) {
        const violations = [];
        const lines = content.split('\n');

        patterns.forEach(pattern => {
            const regex = new RegExp(pattern, 'g');
            lines.forEach((line, index) => {
                const matches = line.match(regex);
                if (matches) {
                    matches.forEach(match => {
                        violations.push({
                            line: index + 1,
                            match: match.trim(),
                            pattern
                        });
                    });
                }
            });
        });

        return violations;
    }

    reportIssue(severity, message) {
        switch (severity) {
            case 'error':
                fail(message);
                break;
            case 'warning':
                warn(message);
                break;
            case 'info':
                message(message);
                break;
            default:
                warn(message);
        }
    }
}

// Execute the rule engine
const ruleEngine = new DangerRuleEngine(rulesConfig);
ruleEngine.executeRules();