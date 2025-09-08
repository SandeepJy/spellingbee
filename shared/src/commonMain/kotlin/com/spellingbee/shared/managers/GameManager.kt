package com.spellingbee.shared.managers

import com.spellingbee.shared.generateUUID
import com.spellingbee.shared.getCurrentTimestamp
import com.spellingbee.shared.models.*
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
            _games.value =
                    snapshot.documents.mapNotNull { doc ->
                        try {
                            MultiUserGame(
                                    id = doc.get("id") as? String ?: "",
                                    creatorId = doc.get("creatorId") as? String ?: "",
                                    participantIds =
                                            (doc.get("participantIds") as? List<*>)
                                                    ?.mapNotNull { it as? String }
                                                    ?.toSet()
                                                    ?: emptySet(),
                                    words =
                                            (doc.get("words") as? List<*>)?.mapNotNull { wordData ->
                                                val wordMap = wordData as? Map<*, *>
                                                if (wordMap != null) {
                                                    Word(
                                                            id = wordMap["id"] as? String ?: "",
                                                            level = wordMap["level"] as? Int ?: 0,
                                                            word = wordMap["word"] as? String ?: "",
                                                            soundUrl =
                                                                    wordMap["soundUrl"] as? String,
                                                            createdByID =
                                                                    wordMap["createdByID"] as?
                                                                            String
                                                                            ?: "",
                                                            gameID = wordMap["gameID"] as? String
                                                                            ?: "",
                                                    )
                                                } else null
                                            }
                                                    ?: emptyList(),
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
                                                        "id" to it.id,
                                                        "word" to it.word,
                                                        "soundUrl" to it.soundUrl,
                                                        "createdByID" to it.createdByID,
                                                        "level" to it.level,
                                                        "gameID" to it.gameID
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
        return game.participantIds.mapNotNull { participantId -> getUser(participantId)?.username }
    }

    fun getCreatorName(game: MultiUserGame): String? {
        return getUser(game.creatorId)?.username
    }

    fun clearError() {
        _error.value = null
        authManager.clearError()
        storageManager.clearError()
    }

    private val _userProgress = MutableStateFlow<Map<String, UserGameProgress>>(emptyMap())
    val userProgress: StateFlow<Map<String, UserGameProgress>> = _userProgress.asStateFlow()

    suspend fun loadUserProgress() {
        try {
            val snapshot = db.collection("userProgress").get()
            val progressMap =
                    snapshot.documents
                            .mapNotNull { doc ->
                                try {
                                    val progress =
                                            UserGameProgress(
                                                    id = doc.get("id") as? String ?: "",
                                                    userId = doc.get("userId") as? String ?: "",
                                                    gameId = doc.get("gameId") as? String ?: "",
                                                    completedWordIndices =
                                                            (doc.get("completedWordIndices") as?
                                                                            List<*>)
                                                                    ?.mapNotNull {
                                                                        (it as? Number)?.toInt()
                                                                    }
                                                                    ?: emptyList(),
                                                    currentWordIndex =
                                                            (doc.get("currentWordIndex") as? Number)
                                                                    ?.toInt()
                                                                    ?: 0,
                                                    score = (doc.get("score") as? Number)?.toInt()
                                                                    ?: 0,
                                                    lastUpdated = (doc.get("lastUpdated") as? Long)
                                                                    ?: 0L
                                            )
                                    progress.id to progress
                                } catch (e: Exception) {
                                    null
                                }
                            }
                            .toMap()
            _userProgress.value = progressMap
        } catch (e: Exception) {
            println("Error loading user progress: ${e.message}")
        }
    }

    suspend fun updateUserProgress(
            gameId: String,
            userId: String,
            wordIndex: Int,
            completedWordIndices: List<Int>,
            score: Int
    ): Boolean {
        try {
            val progressId = UserGameProgress.generateId(userId, gameId)
            val progress =
                    UserGameProgress(
                            id = progressId,
                            userId = userId,
                            gameId = gameId,
                            completedWordIndices = completedWordIndices,
                            currentWordIndex = wordIndex,
                            score = score,
                            lastUpdated = getCurrentTimestamp()
                    )

            _userProgress.value = _userProgress.value + (progressId to progress)
            saveUserProgress(progress)
            return true
        } catch (e: Exception) {
            println("Error updating user progress: ${e.message}")
            return false
        }
    }

    private suspend fun saveUserProgress(progress: UserGameProgress) {
        try {
            db.collection("userProgress")
                    .document(progress.id)
                    .set(
                            mapOf(
                                    "id" to progress.id,
                                    "userId" to progress.userId,
                                    "gameId" to progress.gameId,
                                    "completedWordIndices" to progress.completedWordIndices,
                                    "currentWordIndex" to progress.currentWordIndex,
                                    "score" to progress.score,
                                    "lastUpdated" to progress.lastUpdated
                            )
                    )
        } catch (e: Exception) {
            println("Error saving user progress: ${e.message}")
        }
    }

    fun getUserProgress(userId: String, gameId: String): UserGameProgress? {
        val progressId = UserGameProgress.generateId(userId, gameId)
        return _userProgress.value[progressId]
    }
}

// Platform-specific functions are defined in Platform.kt
