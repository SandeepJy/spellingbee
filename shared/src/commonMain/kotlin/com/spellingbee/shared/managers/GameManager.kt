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
    
    // Managers for different concerns
    val authManager = AuthManager()
    val storageManager = StorageManager()

    private val _users = MutableStateFlow<List<SpellGameUser>>(emptyList())
    val users: StateFlow<List<SpellGameUser>> = _users.asStateFlow()

    private val _currentUser = MutableStateFlow<SpellGameUser?>(null)
    val currentUser: StateFlow<SpellGameUser?> = _currentUser.asStateFlow()

    private val _games = MutableStateFlow<List<MultiUserGame>>(emptyList())
    val games: StateFlow<List<MultiUserGame>> = _games.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    
    init {
        // Note: loadUsers and loadGames are called from iOS wrappers
        // to avoid suspend functions in init
    }

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
    
    suspend fun loadGames() {
        try {
            val snapshot = db.collection("games").get()
            _games.value = snapshot.documents.mapNotNull { doc ->
                try {
                    MultiUserGame(
                        id = doc.get("id") as? String ?: "",
                        creatorId = doc.get("creatorId") as? String ?: "",
                        participantIds = (doc.get("participantIds") as? List<*>)?.mapNotNull { it as? String }?.toSet() ?: emptySet(),
                        words = (doc.get("words") as? List<*>)?.mapNotNull { wordData ->
                            val wordMap = wordData as? Map<*, *>
                            if (wordMap != null) {
                                Word(
                                    text = wordMap["text"] as? String ?: "",
                                    audioUrl = wordMap["audioUrl"] as? String,
                                    recordedBy = wordMap["recordedBy"] as? String
                                )
                            } else null
                        } ?: emptyList(),
                        creationDate = (doc.get("creationDate") as? Long) ?: 0L,
                        isStarted = (doc.get("isStarted") as? Boolean) ?: false
                    )
                } catch (e: Exception) {
                    null
                }
            }
        } catch (e: Exception) {
            println("Error loading games: ${e.message}")
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
    
    // Audio storage methods
    suspend fun uploadAudio(gameId: String, word: String, audioData: ByteArray): Result<String> {
        return storageManager.uploadAudio(gameId, word, audioData)
    }
    
    suspend fun downloadAudio(gameId: String, word: String): Result<ByteArray> {
        return storageManager.downloadAudio(gameId, word)
    }
    
    suspend fun deleteAudio(gameId: String, word: String): Result<Unit> {
        return storageManager.deleteAudio(gameId, word)
    }
    
    // Game management methods
    suspend fun startGame(gameId: String): Boolean {
        val game = _games.value.firstOrNull { it.id == gameId } ?: return false
        val updatedGame = game.copy(isStarted = true)
        _games.value = _games.value.map { if (it.id == gameId) updatedGame else it }
        saveGame(updatedGame)
        return true
    }
    
    // Utility methods
    fun getParticipantNames(game: MultiUserGame): List<String> {
        return game.participantIds.mapNotNull { participantId ->
            getUser(participantId)?.username
        }
    }
    
    fun getCreatorName(game: MultiUserGame): String? {
        return getUser(game.creatorId)?.username
    }
    
    fun clearError() {
        _error.value = null
        authManager.clearError()
        storageManager.clearError()
    }
}

// Platform-specific functions are defined in Platform.kt
