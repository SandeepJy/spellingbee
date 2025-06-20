package com.spellingbee.danger.git;

import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.api.errors.GitAPIException;
import org.eclipse.jgit.diff.DiffEntry;
import org.eclipse.jgit.diff.DiffFormatter;
import org.eclipse.jgit.lib.ObjectId;
import org.eclipse.jgit.lib.ObjectReader;
import org.eclipse.jgit.lib.Repository;
import org.eclipse.jgit.revwalk.RevWalk;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
import org.eclipse.jgit.treewalk.CanonicalTreeParser;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class GitFacade {
    private final Repository repository;
    private final Git git;
    private String targetBranch;

    public GitFacade(String repoPath) throws IOException {
        FileRepositoryBuilder builder = new FileRepositoryBuilder();
        Path gitDir = Paths.get(repoPath, ".git");

        this.repository = builder
                .setGitDir(gitDir.toFile())
                .readEnvironment()
                .findGitDir()
                .build();

        this.git = new Git(repository);
        this.targetBranch = "origin/main"; // default target branch
    }

    public void setTargetBranch(String targetBranch) {
        this.targetBranch = targetBranch;
    }

    public List<String> getModifiedFiles() throws IOException, GitAPIException {
        ObjectId headId = repository.resolve("HEAD");
        ObjectId targetId = repository.resolve(targetBranch);

        if (headId == null) {
            throw new IOException("Could not resolve HEAD commit");
        }

        if (targetId == null) {
            throw new IOException("Could not resolve target branch: " + targetBranch);
        }

        try (ObjectReader reader = repository.newObjectReader();
                RevWalk walk = new RevWalk(repository)) {

            CanonicalTreeParser oldTreeParser = new CanonicalTreeParser();
            oldTreeParser.reset(reader, walk.parseCommit(targetId).getTree());

            CanonicalTreeParser newTreeParser = new CanonicalTreeParser();
            newTreeParser.reset(reader, walk.parseCommit(headId).getTree());

            List<DiffEntry> diffs = git.diff()
                    .setOldTree(oldTreeParser)
                    .setNewTree(newTreeParser)
                    .call();

            List<String> modifiedFiles = new ArrayList<>();

            for (DiffEntry diff : diffs) {
                if (diff.getChangeType() == DiffEntry.ChangeType.MODIFY ||
                        diff.getChangeType() == DiffEntry.ChangeType.ADD) {
                    modifiedFiles.add(diff.getNewPath());
                }
            }

            return modifiedFiles;
        }
    }

    public Map<String, String> getDiffContent() throws IOException, GitAPIException {
        ObjectId headId = repository.resolve("HEAD");
        ObjectId targetId = repository.resolve(targetBranch);

        Map<String, String> fileDiffs = new HashMap<>();

        if (headId == null || targetId == null) {
            return fileDiffs;
        }

        try (ObjectReader reader = repository.newObjectReader();
                RevWalk walk = new RevWalk(repository)) {

            CanonicalTreeParser oldTreeParser = new CanonicalTreeParser();
            oldTreeParser.reset(reader, walk.parseCommit(targetId).getTree());

            CanonicalTreeParser newTreeParser = new CanonicalTreeParser();
            newTreeParser.reset(reader, walk.parseCommit(headId).getTree());

            List<DiffEntry> diffs = git.diff()
                    .setOldTree(oldTreeParser)
                    .setNewTree(newTreeParser)
                    .call();

            for (DiffEntry diff : diffs) {
                if (diff.getChangeType() == DiffEntry.ChangeType.MODIFY ||
                        diff.getChangeType() == DiffEntry.ChangeType.ADD) {

                    ByteArrayOutputStream out = new ByteArrayOutputStream();
                    try (DiffFormatter formatter = new DiffFormatter(out)) {
                        formatter.setRepository(repository);
                        formatter.format(diff);
                    }

                    fileDiffs.put(diff.getNewPath(), out.toString());
                }
            }
        }

        return fileDiffs;
    }

    public List<String> getAddedLines(String diffContent) {
        List<String> addedLines = new ArrayList<>();

        if (diffContent != null) {
            String[] lines = diffContent.split("\\n");
            for (String line : lines) {
                if (line.startsWith("+") && !line.startsWith("+++")) {
                    addedLines.add(line.substring(1));
                }
            }
        }

        return addedLines;
    }

    public long getFileSize(String filePath) {
        File file = new File(repository.getWorkTree(), filePath);
        return file.exists() ? file.length() : -1;
    }

    public void close() {
        git.close();
        repository.close();
    }
}
