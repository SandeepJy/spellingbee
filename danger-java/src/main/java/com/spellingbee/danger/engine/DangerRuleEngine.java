package com.spellingbee.danger.engine;

import com.spellingbee.danger.git.GitFacade;
import com.spellingbee.danger.github.GitHubFacade;
import com.spellingbee.danger.model.Rule;
import com.spellingbee.danger.model.RuleResult;
import com.spellingbee.danger.model.RulesConfig;

import java.io.IOException;
import java.nio.file.FileSystems;
import java.nio.file.PathMatcher;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

public class DangerRuleEngine {
    private final RulesConfig rulesConfig;
    private final GitFacade gitFacade;
    private final GitHubFacade gitHubFacade;
    
    private final List<RuleResult> errors = new ArrayList<>();
    private final List<RuleResult> warnings = new ArrayList<>();
    private final List<RuleResult> info = new ArrayList<>();
    
    public DangerRuleEngine(RulesConfig rulesConfig, GitFacade gitFacade, GitHubFacade gitHubFacade) {
        this.rulesConfig = rulesConfig;
        this.gitFacade = gitFacade;
        this.gitHubFacade = gitHubFacade;
    }
    
    public boolean executeRules() throws Exception {
        // Setup target branch from GitHub if available
        if (gitHubFacade != null) {
            gitFacade.setTargetBranch("origin/" + gitHubFacade.getPRTargetBranch());
        }
        
        // Get modified files
        List<String> modifiedFiles = gitFacade.getModifiedFiles();
        System.out.println("Modified files: " + modifiedFiles);
        
        // Get diff content
        Map<String, String> diffContent = gitFacade.getDiffContent();
        
        // Execute each rule
        for (Rule rule : rulesConfig.getRules()) {
            try {
                switch (rule.getType()) {
                    case "file_pattern":
                        checkFilePattern(rule, modifiedFiles);
                        break;
                    case "code_pattern":
                        checkCodePattern(rule, modifiedFiles, diffContent);
                        break;
                    case "file_size":
                        checkFileSize(rule, modifiedFiles);
                        break;
                    default:
                        System.out.println("Unknown rule type: " + rule.getType());
                }
            } catch (Exception e) {
                System.err.println("Error executing rule " + rule.getId() + ": " + e.getMessage());
                e.printStackTrace();
            }
        }
        
        // Report results
        boolean success = reportResults();
        
        return success;
    }
    
    private void checkFilePattern(Rule rule, List<String> modifiedFiles) {
        List<String> matchedFiles = new ArrayList<>();
        
        for (String file : modifiedFiles) {
            if (isFileExcluded(file)) {
                continue;
            }
            
            for (String pattern : rule.getPatterns()) {
                PathMatcher matcher = FileSystems.getDefault().getPathMatcher("glob:" + pattern);
                if (matcher.matches(FileSystems.getDefault().getPath(file))) {
                    matchedFiles.add(file);
                    break;
                }
            }
        }
        
        if (!matchedFiles.isEmpty()) {
            addResult(rule, "Files matched: " + String.join(", ", matchedFiles));
        }
    }
    
    private void checkCodePattern(Rule rule, List<String> modifiedFiles, Map<String, String> diffContent) {
        for (String file : modifiedFiles) {
            if (isFileExcluded(file) || !fileMatchesPatterns(file, rule.getFilePatterns())) {
                continue;
            }
            
            String diff = diffContent.get(file);
            if (diff == null) {
                continue;
            }
            
            List<String> addedLines = gitFacade.getAddedLines(diff);
            List<String> matches = new ArrayList<>();
            
            for (int i = 0; i < addedLines.size(); i++) {
                String line = addedLines.get(i);
                
                // Skip if line matches exclude patterns
                boolean shouldExclude = false;
                if (rule.getExcludePatterns() != null) {
                    for (String excludePattern : rule.getExcludePatterns()) {
                        if (line.contains(excludePattern)) {
                            shouldExclude = true;
                            break;
                        }
                    }
                }
                
                if (shouldExclude) {
                    continue;
                }
                
                // Check if line matches pattern
                for (String patternStr : rule.getPatterns()) {
                    Pattern pattern = Pattern.compile(patternStr);
                    if (pattern.matcher(line).find()) {
                        matches.add("Line " + (i + 1) + ": " + line.trim());
                        break;
                    }
                }
            }
            
            if (!matches.isEmpty()) {
                addResult(rule, "In " + file + ":\n" + String.join("\n", matches));
            }
        }
    }
    
    private void checkFileSize(Rule rule, List<String> modifiedFiles) {
        for (String file : modifiedFiles) {
            if (isFileExcluded(file) || 
                !fileMatchesPatterns(file, rule.getFilePatterns()) ||
                fileMatchesPatterns(file, rule.getExcludePatterns())) {
                continue;
            }
            
            long sizeBytes = gitFacade.getFileSize(file);
            if (sizeBytes == -1) {
                System.out.println("Could not get size for file: " + file);
                continue;
            }
            
            double sizeKb = sizeBytes / 1024.0;
            if (sizeKb > rule.getMaxSizeKb()) {
                addResult(rule, file + " is " + String.format("%.2f", sizeKb) + "KB (limit: " + rule.getMaxSizeKb() + "KB)");
            }
        }
    }
    
    private boolean fileMatchesPatterns(String file, List<String> patterns) {
        if (patterns == null || patterns.isEmpty()) {
            return true;  // No patterns means match all
        }
        
        for (String pattern : patterns) {
            PathMatcher matcher = FileSystems.getDefault().getPathMatcher("glob:" + pattern);
            if (matcher.matches(FileSystems.getDefault().getPath(file))) {
                return true;
            }
        }
        
        return false;
    }
    
    private boolean isFileExcluded(String file) {
        if (rulesConfig.getSettings().getExcludeFiles() == null) {
            return false;
        }
        
        return fileMatchesPatterns(file, rulesConfig.getSettings().getExcludeFiles());
    }
    
    private void addResult(Rule rule, String details) {
        RuleResult result = new RuleResult(rule.getName(), rule.getMessage(), details, rule.getSeverity());
        
        switch (rule.getSeverity()) {
            case "error":
                errors.add(result);
                break;
            case "warning":
                warnings.add(result);
                break;
            case "info":
            default:
                info.add(result);
                break;
        }
    }
    
    private boolean reportResults() throws IOException {
        boolean hasErrors = !errors.isEmpty();
        boolean tooManyWarnings = rulesConfig.getSettings().getMaxWarnings() > 0 && 
                                  warnings.size() > rulesConfig.getSettings().getMaxWarnings();
        
        // Print errors
        for (RuleResult result : errors) {
            System.err.println("❌ ERROR: " + result);
            System.err.println();
        }
        
        // Print warnings
        for (RuleResult result : warnings) {
            System.out.println("⚠️ WARNING: " + result);
            System.out.println();
        }
        
        // Print info
        for (RuleResult result : info) {
            System.out.println("ℹ️ INFO: " + result);
            System.out.println();
        }
        
        // Generate summary
        String summary = generateSummary();
        System.out.println("\n" + summary);
        
        // Post to GitHub if in CI mode
        if (gitHubFacade != null) {
            gitHubFacade.postComment(summary);
            gitHubFacade.setStatus(!hasErrors && !tooManyWarnings);
        }
        
        // Determine success
        boolean success = !hasErrors && !tooManyWarnings;
        if (rulesConfig.getSettings().isFailOnErrors() && !success) {
            System.err.println("\n❌ PR blocked due to rule violations. Please fix the errors above.");
        }
        
        return success;
    }
    
    private String generateSummary() {
        int totalIssues = errors.size() + warnings.size() + info.size();
        
        if (totalIssues == 0) {
            return "## ✅ Danger Check Passed\n\nNo rule violations found!";
        }
        
        StringBuilder summary = new StringBuilder("## 📋 Danger Check Summary\n\n");
        
        if (!errors.isEmpty()) {
            summary.append("❌ **").append(errors.size()).append(" Error(s)**\n");
        }
        
        if (!warnings.isEmpty()) {
            summary.append("⚠️ **").append(warnings.size()).append(" Warning(s)**\n");
        }
        
        if (!info.isEmpty()) {
            summary.append("ℹ️ **").append(info.size()).append(" Info**\n");
        }
        
        summary.append("\n---\n\n");
        summary.append("*This check is powered by a Java-based rule system. ");
        summary.append("Rules can be modified in `rules.json`.*");
        
        return summary.toString();
    }
}
