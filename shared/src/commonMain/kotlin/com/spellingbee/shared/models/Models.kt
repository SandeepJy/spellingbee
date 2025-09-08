package com.spellingbee.shared.models

import kotlinx.serialization.Serializable

@Serializable data class SpellGameUser(val id: String, val username: String, val email: String)

@Serializable
data class Word(
        var id: String,
        val word: String,
        val soundUrl: String? = null,
        val level: Int,
        var createdByID: String,
        var gameID: String? = null
)

@Serializable
data class MultiUserGame(
        val id: String,
        val creatorId: String,
        val participantIds: Set<String>,
        val words: List<Word>,
        val creationDate: Long,
        val isStarted: Boolean = false
)
