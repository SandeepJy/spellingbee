import { danger, fail, warn, message } from 'danger';
import { fs } from 'fs';
import path from 'path';
import { minimatch } from 'minimatch';

// Load rules configuration
const rulesPath = path.join(__dirname, 'rules.json');
const rulesConfig = JSON.parse(fs.readFileSync(rulesPath, 'utf8'));

// Helper function to check if file matches patterns
function matchesPatterns(filePath, patterns, excludePatterns = []) {
    // Check exclude patterns first
    if (excludePatterns.some(pattern => minimatch(filePath, pattern))) {
        return false;
    }

    return patterns.some(pattern => minimatch(filePath, pattern));
}

// Helper function to read file content safely
function getFileContent(filePath) {
    try {
        return fs.readFileSync(filePath, 'utf8');
    } catch (error) {
        console.log(`Could not read file: ${filePath}`);
        return null;
    }
}

// Get modified and added files
const modifiedFiles = danger.git.modified_files;
const addedFiles = danger.git.created_files;
const allChangedFiles = [...modifiedFiles, ...addedFiles];

console.log(`Checking ${allChangedFiles.length} changed files against ${rulesConfig.rules.length} rules`);

// Process each rule
rulesConfig.rules.forEach(rule => {
    console.log(`Processing rule: ${rule.name}`);

    switch (rule.type) {
        case 'file_modified':
            checkFileModifiedRule(rule);
            break;
        case 'api_usage':
            checkApiUsageRule(rule);
            break;
        case 'api_usage_in_file':
            checkApiUsageInFileRule(rule);
            break;
        default:
            console.log(`Unknown rule type: ${rule.type}`);
    }
});

function checkFileModifiedRule(rule) {
    const matchingFiles = allChangedFiles.filter(file =>
        matchesPatterns(file, rule.patterns, rule.exclude_patterns)
    );

    if (matchingFiles.length > 0) {
        const fileList = matchingFiles.map(f => `- ${f}`).join('\n');
        const fullMessage = `${rule.message}\n\nAffected files:\n${fileList}`;

        if (rule.severity === 'error') {
            fail(`❌ ${rule.name}: ${fullMessage}`);
        } else if (rule.severity === 'warning') {
            warn(`⚠️ ${rule.name}: ${fullMessage}`);
        } else {
            message(`ℹ️ ${rule.name}: ${fullMessage}`);
        }
    }
}

function checkApiUsageRule(rule) {
    const relevantFiles = allChangedFiles.filter(file =>
        matchesPatterns(file, rule.patterns, rule.exclude_patterns)
    );

    const violations = [];

    relevantFiles.forEach(file => {
        const content = getFileContent(file);
        if (!content) return;

        // Check forbidden APIs
        if (rule.forbidden_apis) {
            rule.forbidden_apis.forEach(api => {
                if (content.includes(api)) {
                    violations.push({
                        file,
                        api,
                        type: 'forbidden_api'
                    });
                }
            });
        }

        // Check regex patterns
        if (rule.regex_patterns) {
            rule.regex_patterns.forEach(pattern => {
                const regex = new RegExp(pattern, 'g');
                const matches = content.match(regex);
                if (matches) {
                    violations.push({
                        file,
                        matches: matches.length,
                        pattern,
                        type: 'regex_pattern'
                    });
                }
            });
        }
    });

    if (violations.length > 0) {
        violations.forEach(violation => {
            let violationMessage = rule.message;

            if (violation.type === 'forbidden_api') {
                violationMessage = violationMessage.replace('{api}', violation.api);
                violationMessage = violationMessage.replace('{file}', violation.file);
                violationMessage = `${violationMessage}\n\nFile: ${violation.file}`;
            } else if (violation.type === 'regex_pattern') {
                violationMessage = `${violationMessage}\n\nFile: ${violation.file} (${violation.matches} occurrences)`;
            }

            if (rule.severity === 'error') {
                fail(`❌ ${rule.name}: ${violationMessage}`);
            } else if (rule.severity === 'warning') {
                warn(`⚠️ ${rule.name}: ${violationMessage}`);
            } else {
                message(`ℹ️ ${rule.name}: ${violationMessage}`);
            }
        });
    }
}

function checkApiUsageInFileRule(rule) {
    const relevantFiles = allChangedFiles.filter(file =>
        matchesPatterns(file, rule.file_patterns, rule.exclude_patterns)
    );

    const violations = [];

    relevantFiles.forEach(file => {
        const content = getFileContent(file);
        if (!content) return;

        if (rule.forbidden_apis) {
            rule.forbidden_apis.forEach(api => {
                if (content.includes(api)) {
                    violations.push({
                        file,
                        api
                    });
                }
            });
        }
    });

    if (violations.length > 0) {
        violations.forEach(violation => {
            let violationMessage = rule.message;
            violationMessage = violationMessage.replace('{api}', violation.api);
            violationMessage = violationMessage.replace('{file}', violation.file);

            if (rule.severity === 'error') {
                fail(`❌ ${rule.name}: ${violationMessage}`);
            } else if (rule.severity === 'warning') {
                warn(`⚠️ ${rule.name}: ${violationMessage}`);
            } else {
                message(`ℹ️ ${rule.name}: ${violationMessage}`);
            }
        });
    }
}

// Additional summary
const prDescription = danger.github.pr.body;
if (prDescription && prDescription.length < 10) {
    warn('⚠️ Please add a more detailed description to your PR');
}

console.log('Danger rules check completed');