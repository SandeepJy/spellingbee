package com.spellingbee.danger.model;

import java.util.List;

import com.google.gson.annotations.SerializedName;

public class Rule {
    private String id;
    private String name;
    private String description;
    private String severity; // error, warning, info
    private String type; // file_pattern, code_pattern, file_size
    private List<String> patterns;

    @SerializedName("file_patterns")
    private List<String> filePatterns;

    @SerializedName("exclude_patterns")
    private List<String> excludePatterns;
    private String message;
    private int maxSizeKb;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getSeverity() {
        return severity;
    }

    public void setSeverity(String severity) {
        this.severity = severity;
    }

    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
    }

    public List<String> getPatterns() {
        return patterns;
    }

    public void setPatterns(List<String> patterns) {
        this.patterns = patterns;
    }

    public List<String> getFilePatterns() {
        return filePatterns;
    }

    public void setFilePatterns(List<String> filePatterns) {
        this.filePatterns = filePatterns;
    }

    public List<String> getExcludePatterns() {
        return excludePatterns;
    }

    public void setExcludePatterns(List<String> excludePatterns) {
        this.excludePatterns = excludePatterns;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public int getMaxSizeKb() {
        return maxSizeKb;
    }

    public void setMaxSizeKb(int maxSizeKb) {
        this.maxSizeKb = maxSizeKb;
    }

    @Override
    public String toString() {
        return "Rule{" +
                "id='" + id + '\'' +
                ", name='" + name + '\'' +
                ", description='" + description + '\'' +
                ", severity='" + severity + '\'' +
                ", type='" + type + '\'' +
                ", patterns=" + patterns +
                ", filePatterns=" + filePatterns +
                ", excludePatterns=" + excludePatterns +
                ", message='" + message + '\'' +
                ", maxSizeKb=" + maxSizeKb +
                '}';
    }
}
