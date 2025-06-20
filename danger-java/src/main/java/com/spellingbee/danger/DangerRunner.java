package com.spellingbee.danger;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.spellingbee.danger.engine.DangerRuleEngine;
import com.spellingbee.danger.git.GitFacade;
import com.spellingbee.danger.github.GitHubFacade;
import com.spellingbee.danger.model.RulesConfig;

import java.io.FileReader;
import java.nio.file.Paths;

/**
 * Main entry point for the Danger Java system
 */
public class DangerRunner {

    public static void main(String[] args) {
        try {
            String mode = args.length > 0 ? args[0] : "ci";
            String rulesPath = args.length > 1 ? args[1] : "./rules.json";
            String repoPath = args.length > 2 ? args[2] : "..";

            System.out.println("Starting Danger Java in " + mode + " mode");
            System.out.println("Using rules from: " + rulesPath);
            System.out.println("Repository path: " + repoPath);

            // Load rules configuration
            RulesConfig rulesConfig = loadRulesConfig(rulesPath);

            // Initialize Git facade
            GitFacade gitFacade = new GitFacade(repoPath);

            // Initialize GitHub facade for CI mode
            GitHubFacade gitHubFacade = null;
            if ("ci".equals(mode)) {
                gitHubFacade = new GitHubFacade();
            }

            // Create and run the rule engine
            DangerRuleEngine ruleEngine = new DangerRuleEngine(rulesConfig, gitFacade, gitHubFacade);
            boolean success = ruleEngine.executeRules();

            // Exit with appropriate code
            if (!success&& "ci".equals(mode)) {
                System.out.println("Exiting with status 1");
                System.exit(1);
            }
        } catch (Exception e) {
            System.err.println("Error running Danger: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    private static RulesConfig loadRulesConfig(String path) throws Exception {
        try (FileReader reader = new FileReader(path)) {
            Gson gson = new Gson();
            return gson.fromJson(reader, RulesConfig.class);
        }
    }
}
