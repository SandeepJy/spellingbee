package com.spellingbee.danger.model;

public class RuleResult {
    private String ruleName;
    private String message;
    private String details;
    private String severity;
    
    public RuleResult(String ruleName, String message, String details, String severity) {
        this.ruleName = ruleName;
        this.message = message;
        this.details = details;
        this.severity = severity;
    }
    
    public String getRuleName() {
        return ruleName;
    }
    
    public String getMessage() {
        return message;
    }
    
    public String getDetails() {
        return details;
    }
    
    public String getSeverity() {
        return severity;
    }
    
    @Override
    public String toString() {
        return String.format("**%s**: %s%n%n%s", ruleName, message, details);
    }
}
