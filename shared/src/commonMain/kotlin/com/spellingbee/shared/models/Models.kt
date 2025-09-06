package com.spellingbee.shared.models

import kotlinx.serialization.Serializable

@Serializable data class SpellGameUser(val id: String, val username: String, val email: String)

@Serializable
data class Word(val text: String, val audioUrl: String? = null, val recordedBy: String? = null)

@Serializable
data class MultiUserGame(
        val id: String,
        val creatorId: String,
        val participantIds: Set<String>,
        val words: List<Word>,
        val creationDate: Long,
        val isStarted: Boolean = false
)
