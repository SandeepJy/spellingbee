package com.spellingbee.danger.github;

import com.spellingbee.danger.model.RuleResult;
import org.kohsuke.github.GHCommitStatus;
import org.kohsuke.github.GHCommitState;
import org.kohsuke.github.GHIssueComment;
import org.kohsuke.github.GHPullRequest;
import org.kohsuke.github.GHRepository;
import org.kohsuke.github.GitHub;

import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public class GitHubFacade {
    private GitHub github;
    private GHRepository repository;
    private GHPullRequest pullRequest;

    public GitHubFacade() throws IOException {
        // Initialize GitHub connection from environment variables
        String token = System.getenv("GITHUB_TOKEN");
        if (token == null || token.isEmpty()) {
            throw new IllegalStateException("GITHUB_TOKEN environment variable is required in CI mode");
        }

        github = GitHub.connectUsingOAuth(token);

        String repoName = System.getenv("GITHUB_REPOSITORY");
        if (repoName == null || repoName.isEmpty()) {
            throw new IllegalStateException("GITHUB_REPOSITORY environment variable is required in CI mode");
        }

        repository = github.getRepository(repoName);

        String prNumberStr = System.getenv("GITHUB_PR_NUMBER");
        if (prNumberStr == null || prNumberStr.isEmpty()) {
            throw new IllegalStateException("GITHUB_PR_NUMBER environment variable is required in CI mode");
        }

        int prNumber = Integer.parseInt(prNumberStr);
        pullRequest = repository.getPullRequest(prNumber);
    }

    public void postComment(String comment) throws IOException {
        // Check if a danger comment already exists and update it
        Optional<GHIssueComment> existingComment = pullRequest.getComments().stream()
                .filter(c -> {
                    return c.getBody().startsWith("## 📋 Danger Check");
                })
                .findFirst();

        if (existingComment.isPresent()) {
            existingComment.get().update(comment);
        } else {
            pullRequest.comment(comment);
        }
    }

    public void setStatus(boolean success) throws IOException {
        String context = "Danger Java";
        String description = success ? "All checks passed!" : "Rules violations found";
        GHCommitState state = success ? GHCommitState.SUCCESS : GHCommitState.FAILURE;

        repository.createCommitStatus(pullRequest.getHead().getSha(), state, null, description,
                context);
    }

    public String getPRTargetBranch() throws IOException {
        return pullRequest.getBase().getRef();
    }

    public String getPRSourceBranch() throws IOException {
        return pullRequest.getHead().getRef();
    }
}
