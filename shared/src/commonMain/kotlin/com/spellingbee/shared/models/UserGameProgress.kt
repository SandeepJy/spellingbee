package com.spellingbee.shared.models

import kotlinx.serialization.Serializable

@Serializable
data class UserGameProgress(
        val id: String, // Format: "userID-gameID"
        val userId: String,
        val gameId: String,
        val completedWordIndices: List<Int> = emptyList(),
        val currentWordIndex: Int = 0,
        val score: Int = 0,
        val lastUpdated: Long = 0L
) {
    companion object {
        fun generateId(userId: String, gameId: String): String {
            return "$userId-$gameId"
        }
    }
}
