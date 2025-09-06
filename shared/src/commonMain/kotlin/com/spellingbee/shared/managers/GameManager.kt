package com.spellingbee.shared.managers

import com.spellingbee.shared.models.*
import com.spellingbee.shared.generateUUID
import com.spellingbee.shared.getCurrentTimestamp
import dev.gitlive.firebase.Firebase
import dev.gitlive.firebase.firestore.firestore
import dev.gitlive.firebase.storage.storage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class GameManager {
    private val db = Firebase.firestore
    private val storage = Firebase.storage

    private val _users = MutableStateFlow<List<SpellGameUser>>(emptyList())
    val users: StateFlow<List<SpellGameUser>> = _users.asStateFlow()

    private val _currentUser = MutableStateFlow<SpellGameUser?>(null)
    val currentUser: StateFlow<SpellGameUser?> = _currentUser.asStateFlow()

    private val _games = MutableStateFlow<List<MultiUserGame>>(emptyList())
    val games: StateFlow<List<MultiUserGame>> = _games.asStateFlow()

    suspend fun loadUsers() {
        try {
            val snapshot = db.collection("users").get()
            _users.value =
                    snapshot.documents.mapNotNull {
                        try {
                            SpellGameUser(
                                    id = it.get("id") as? String ?: "",
                                    username = it.get("username") as? String ?: "",
                                    email = it.get("email") as? String ?: ""
                            )
                        } catch (e: Exception) {
                            null
                        }
                    }
        } catch (e: Exception) {
            println("Error loading users: ${e.message}")
        }
    }

    suspend fun setCurrentUser(user: SpellGameUser) {
        if (!_users.value.contains(user)) {
            addUser(user.id, user.username, user.email)
        }
        _currentUser.value = _users.value.firstOrNull { it.id == user.id }
    }

    suspend fun addUser(id: String, username: String, email: String) {
        val newUser = SpellGameUser(id, username, email)
        _users.value = _users.value + newUser
        saveUser(newUser)
    }

    private suspend fun saveUser(user: SpellGameUser) {
        try {
            db.collection("users")
                    .document(user.id)
                    .set(mapOf("id" to user.id, "username" to user.username, "email" to user.email))
        } catch (e: Exception) {
            println("Error saving user: ${e.message}")
        }
    }

    suspend fun createGame(creatorId: String, participantIds: Set<String>): String {
        val gameId = generateUUID()
        val newGame =
                MultiUserGame(
                        id = gameId,
                        creatorId = creatorId,
                        participantIds = participantIds,
                        words = emptyList(),
                        creationDate = getCurrentTimestamp()
                )
        _games.value = _games.value + newGame
        saveGame(newGame)
        return gameId
    }

    suspend fun addWords(gameId: String, words: List<Word>): Boolean {
        val game = _games.value.firstOrNull { it.id == gameId } ?: return false
        val updatedGame = game.copy(words = game.words + words)
        _games.value = _games.value.map { if (it.id == gameId) updatedGame else it }
        saveGame(updatedGame)
        return true
    }

    private suspend fun saveGame(game: MultiUserGame) {
        try {
            db.collection("games")
                    .document(game.id)
                    .set(
                            mapOf(
                                    "id" to game.id,
                                    "creatorId" to game.creatorId,
                                    "participantIds" to game.participantIds.toList(),
                                    "words" to
                                            game.words.map {
                                                mapOf(
                                                        "text" to it.text,
                                                        "audioUrl" to it.audioUrl,
                                                        "recordedBy" to it.recordedBy
                                                )
                                            },
                                    "creationDate" to game.creationDate,
                                    "isStarted" to game.isStarted
                            )
                    )
        } catch (e: Exception) {
            println("Error saving game: ${e.message}")
        }
    }

    fun getUser(id: String): SpellGameUser? {
        return _users.value.firstOrNull { it.id == id }
    }
}

// Platform-specific functions are defined in Platform.kt
