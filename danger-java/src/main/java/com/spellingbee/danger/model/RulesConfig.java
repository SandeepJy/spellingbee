package com.spellingbee.danger.model;

import java.util.List;

public class RulesConfig {
    private List<Rule> rules;
    private Settings settings;
    
    public List<Rule> getRules() {
        return rules;
    }
    
    public void setRules(List<Rule> rules) {
        this.rules = rules;
    }
    
    public Settings getSettings() {
        return settings;
    }
    
    public void setSettings(Settings settings) {
        this.settings = settings;
    }
    
    public static class Settings {
        private boolean failOnErrors;
        private int maxWarnings;
        private List<String> excludeFiles;
        
        public boolean isFailOnErrors() {
            return failOnErrors;
        }
        
        public void setFailOnErrors(boolean failOnErrors) {
            this.failOnErrors = failOnErrors;
        }
        
        public int getMaxWarnings() {
            return maxWarnings;
        }
        
        public void setMaxWarnings(int maxWarnings) {
            this.maxWarnings = maxWarnings;
        }
        
        public List<String> getExcludeFiles() {
            return excludeFiles;
        }
        
        public void setExcludeFiles(List<String> excludeFiles) {
            this.excludeFiles = excludeFiles;
        }
    }
}
