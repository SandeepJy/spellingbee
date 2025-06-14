'use strict';

const { danger, fail, warn, message } = require('danger');
const { readFileSync } = require('fs');
const minimatch = require('minimatch');

// Load rules from JSON file
const rules = JSON.parse(readFileSync('danger-rules.json', 'utf8')).rules;

// Process each rule
rules.forEach(rule => {
    const { severity, condition, message: ruleMessage } = rule;

    if (condition.type === 'file-modified') {
        // Check for modified files matching the glob
        const matchingFiles = danger.git.modified_files.filter(file => minimatch(file, condition.glob));
        if (matchingFiles.length > 0) {
            handleViolation(severity, `${ruleMessage} Affected files: ${matchingFiles.join(', ')}`);
        }
    } else if (condition.type === 'diff-pattern') {
        // Check diffs in matching files for the regex pattern
        const regex = new RegExp(condition.regex);
        danger.git.modified_files
            .filter(file => minimatch(file, condition.fileGlob))
            .forEach(async file => {
                const diff = await danger.git.diffForFile(file);
                if (diff && diff.added && diff.added.split('\n').some(line => regex.test(line))) {
                    handleViolation(severity, `${ruleMessage} Detected in ${file}`);
                }
            });
    }
});

// Helper to handle severity levels
function handleViolation(severity, msg) {
    if (severity === 'error') {
        fail(msg);  // Fails the Danger job, blocking merge
    } else if (severity === 'warning') {
        warn(msg);  // Posts a warning in PR
    } else if (severity === 'info') {
        message(msg);  // Posts an info message in PR
    }
}