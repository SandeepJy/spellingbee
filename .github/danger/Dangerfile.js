// const fs = require('fs');
// const path = require('path');
// const { danger, warn, fail, message } = require('danger');
// const minimatch = require('minimatch');

// // Load rules configuration
// const rulesConfig = JSON.parse(fs.readFileSync('danger-rules.json', 'utf8'));

// class DangerRuleEngine {
//     constructor(config) {
//         this.rules = config.rules;
//     }

//     async executeRules() {
//         for (const rule of this.rules) {
//             try {
//                 await this.executeRule(rule);
//             } catch (error) {
//                 console.error(`Error executing rule ${rule.id}:`, error);
//             }
//         }
//     }

//     async executeRule(rule) {
//         switch (rule.type) {
//             case 'file_modified':
//                 this.checkFileModified(rule);
//                 break;
//             case 'api_usage':
//                 await this.checkApiUsage(rule);
//                 break;
//             case 'api_usage_in_file':
//                 await this.checkApiUsageInFile(rule);
//                 break;
//             case 'file_size':
//                 await this.checkFileSize(rule);
//                 break;
//             case 'missing_tests':
//                 this.checkMissingTests(rule);
//                 break;
//             default:
//                 console.warn(`Unknown rule type: ${rule.type}`);
//         }
//     }

//     checkFileModified(rule) {
//         const modifiedFiles = danger.git.modified_files.concat(danger.git.created_files);
//         const matchingFiles = modifiedFiles.filter(file =>
//             rule.config.patterns.some(pattern => minimatch(file, pattern))
//         );

//         if (matchingFiles.length > 0) {
//             const fileList = matchingFiles.map(f => `- ${f}`).join('\n');
//             const fullMessage = `${rule.config.message}\n\nAffected files:\n${fileList}`;
//             this.reportIssue(rule.severity, fullMessage);
//         }
//     }

//     async checkApiUsage(rule) {
//         const filesToCheck = danger.git.modified_files
//             .concat(danger.git.created_files)
//             .filter(file => rule.config.patterns.some(pattern => minimatch(file, pattern)));

//         for (const file of filesToCheck) {
//             try {
//                 const content = fs.readFileSync(file, 'utf8');
//                 const violations = this.findPatternViolations(content, rule.config.forbidden_patterns);

//                 if (violations.length > 0) {
//                     const violationDetails = violations.map(v => `Line ${v.line}: ${v.match}`).join('\n');
//                     const fullMessage = `${rule.config.message}\n\nIn file: ${file}\n${violationDetails}`;
//                     this.reportIssue(rule.severity, fullMessage);
//                 }
//             } catch (error) {
//                 console.warn(`Could not read file ${file}:`, error.message);
//             }
//         }
//     }

//     async checkApiUsageInFile(rule) {
//         const filesToCheck = danger.git.modified_files
//             .concat(danger.git.created_files)
//             .filter(file => rule.config.file_patterns.some(pattern => minimatch(file, pattern)));

//         for (const file of filesToCheck) {
//             try {
//                 const content = fs.readFileSync(file, 'utf8');
//                 const violations = this.findPatternViolations(content, rule.config.forbidden_patterns);

//                 if (violations.length > 0) {
//                     const violationDetails = violations.map(v => `Line ${v.line}: ${v.match}`).join('\n');
//                     const fullMessage = `${rule.config.message}\n\nIn file: ${file}\n${violationDetails}`;
//                     this.reportIssue(rule.severity, fullMessage);
//                 }
//             } catch (error) {
//                 console.warn(`Could not read file ${file}:`, error.message);
//             }
//         }
//     }

//     async checkFileSize(rule) {
//         const filesToCheck = danger.git.modified_files
//             .concat(danger.git.created_files)
//             .filter(file => rule.config.patterns.some(pattern => minimatch(file, pattern)));

//         for (const file of filesToCheck) {
//             try {
//                 const content = fs.readFileSync(file, 'utf8');
//                 const lines = content.split('\n').length;

//                 if (lines > rule.config.max_lines) {
//                     const fullMessage = `${rule.config.message}\n\nFile: ${file} (${lines} lines)`;
//                     this.reportIssue(rule.severity, fullMessage);
//                 }
//             } catch (error) {
//                 console.warn(`Could not read file ${file}:`, error.message);
//             }
//         }
//     }

//     checkMissingTests(rule) {
//         const sourceFiles = danger.git.created_files
//             .filter(file => rule.config.source_patterns.some(pattern => minimatch(file, pattern)))
//             .filter(file => !rule.config.exclude_patterns.some(pattern => minimatch(file, pattern)));

//         const testFiles = danger.git.created_files
//             .concat(danger.git.modified_files)
//             .filter(file => rule.config.test_patterns.some(pattern => minimatch(file, pattern)));

//         const filesWithoutTests = sourceFiles.filter(sourceFile => {
//             const baseName = path.basename(sourceFile, '.swift');
//             return !testFiles.some(testFile => testFile.includes(baseName));
//         });

//         if (filesWithoutTests.length > 0) {
//             const fileList = filesWithoutTests.map(f => `- ${f}`).join('\n');
//             const fullMessage = `${rule.config.message}\n\nFiles without tests:\n${fileList}`;
//             this.reportIssue(rule.severity, fullMessage);
//         }
//     }

//     findPatternViolations(content, patterns) {
//         const violations = [];
//         const lines = content.split('\n');

//         patterns.forEach(pattern => {
//             const regex = new RegExp(pattern, 'g');
//             lines.forEach((line, index) => {
//                 const matches = line.match(regex);
//                 if (matches) {
//                     matches.forEach(match => {
//                         violations.push({
//                             line: index + 1,
//                             match: match.trim(),
//                             pattern
//                         });
//                     });
//                 }
//             });
//         });

//         return violations;
//     }

//     reportIssue(severity, message) {
//         switch (severity) {
//             case 'error':
//                 fail(message);
//                 break;
//             case 'warning':
//                 warn(message);
//                 break;
//             case 'info':
//                 message(message);
//                 break;
//             default:
//                 warn(message);
//         }
//     }
// }

// // Execute the rule engine
// const ruleEngine = new DangerRuleEngine(rulesConfig);
// ruleEngine.executeRules();

import { danger, fail, warn, message } from 'danger';
import fs from 'fs';
import path from 'path';
import minimatch from 'minimatch';

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