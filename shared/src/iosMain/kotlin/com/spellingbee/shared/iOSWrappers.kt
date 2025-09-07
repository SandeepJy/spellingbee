package com.spellingbee.shared

import com.spellingbee.shared.managers.GameManager
import com.spellingbee.shared.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

class IOSGameManager {
    private val gameManager = GameManager()
    private val scope = MainScope()

    // Game state callbacks
    var onUsersChanged: ((List<SpellGameUser>) -> Unit)? = null
    var onGamesChanged: ((List<MultiUserGame>) -> Unit)? = null
    var onCurrentUserChanged: ((SpellGameUser?) -> Unit)? = null
    var onIsLoadingChanged: ((Boolean) -> Unit)? = null
    var onErrorChanged: ((String?) -> Unit)? = null
    
    // Auth state callbacks
    var onAuthUserChanged: ((SpellGameUser?) -> Unit)? = null
    var onAuthLoadingChanged: ((Boolean) -> Unit)? = null
    var onAuthErrorChanged: ((String?) -> Unit)? = null
    
    // Storage state callbacks
    var onStorageLoadingChanged: ((Boolean) -> Unit)? = null
    var onStorageErrorChanged: ((String?) -> Unit)? = null

    init {
        // Game state callbacks
        gameManager.users.onEach { users -> onUsersChanged?.invoke(users) }.launchIn(scope)
        gameManager.games.onEach { games -> onGamesChanged?.invoke(games) }.launchIn(scope)
        gameManager.currentUser.onEach { user -> onCurrentUserChanged?.invoke(user) }.launchIn(scope)
        gameManager.isLoading.onEach { loading -> onIsLoadingChanged?.invoke(loading) }.launchIn(scope)
        gameManager.error.onEach { error -> onErrorChanged?.invoke(error) }.launchIn(scope)
        
        // Auth state callbacks
        gameManager.authManager.currentUser.onEach { user -> onAuthUserChanged?.invoke(user) }.launchIn(scope)
        gameManager.authManager.isLoading.onEach { loading -> onAuthLoadingChanged?.invoke(loading) }.launchIn(scope)
        gameManager.authManager.error.onEach { error -> onAuthErrorChanged?.invoke(error) }.launchIn(scope)
        
        // Storage state callbacks
        gameManager.storageManager.isUploading.onEach { uploading -> onStorageLoadingChanged?.invoke(uploading) }.launchIn(scope)
        gameManager.storageManager.error.onEach { error -> onStorageErrorChanged?.invoke(error) }.launchIn(scope)
    }

    fun loadUsers(completion: () -> Unit) {
        scope.launch {
            gameManager.loadUsers()
            withContext(Dispatchers.Main) { completion() }
        }
    }
    
    fun loadGames(completion: () -> Unit) {
        scope.launch {
            gameManager.loadGames()
            withContext(Dispatchers.Main) { completion() }
        }
    }

    fun setCurrentUser(user: SpellGameUser, completion: () -> Unit) {
        scope.launch {
            gameManager.setCurrentUser(user)
            withContext(Dispatchers.Main) { completion() }
        }
    }

    fun addUser(id: String, username: String, email: String, completion: () -> Unit) {
        scope.launch {
            gameManager.addUser(id, username, email)
            withContext(Dispatchers.Main) { completion() }
        }
    }

    fun createGame(creatorId: String, participantIds: Set<String>, completion: (String) -> Unit) {
        scope.launch {
            val gameId = gameManager.createGame(creatorId, participantIds)
            withContext(Dispatchers.Main) { completion(gameId) }
        }
    }

    // Authentication methods
    fun register(username: String, email: String, password: String, completion: (SpellGameUser?, String?) -> Unit) {
        scope.launch {
            val result = gameManager.authManager.register(username, email, password)
            withContext(Dispatchers.Main) {
                if (result.isSuccess) {
                    completion(result.getOrNull(), null)
                } else {
                    completion(null, result.exceptionOrNull()?.message)
                }
            }
        }
    }
    
    fun login(email: String, password: String, completion: (SpellGameUser?, String?) -> Unit) {
        scope.launch {
            val result = gameManager.authManager.login(email, password)
            withContext(Dispatchers.Main) {
                if (result.isSuccess) {
                    completion(result.getOrNull(), null)
                } else {
                    completion(null, result.exceptionOrNull()?.message)
                }
            }
        }
    }
    
    fun signOut(completion: (Boolean, String?) -> Unit) {
        scope.launch {
            val result = gameManager.authManager.signOut()
            withContext(Dispatchers.Main) {
                if (result.isSuccess) {
                    completion(true, null)
                } else {
                    completion(false, result.exceptionOrNull()?.message)
                }
            }
        }
    }
    
    // Storage methods
    fun uploadAudio(gameId: String, word: String, audioData: ByteArray, completion: (String?, String?) -> Unit) {
        scope.launch {
            val result = gameManager.uploadAudio(gameId, word, audioData)
            withContext(Dispatchers.Main) {
                if (result.isSuccess) {
                    completion(result.getOrNull(), null)
                } else {
                    completion(null, result.exceptionOrNull()?.message)
                }
            }
        }
    }
    
    fun downloadAudio(gameId: String, word: String, completion: (ByteArray?, String?) -> Unit) {
        scope.launch {
            val result = gameManager.downloadAudio(gameId, word)
            withContext(Dispatchers.Main) {
                if (result.isSuccess) {
                    completion(result.getOrNull(), null)
                } else {
                    completion(null, result.exceptionOrNull()?.message)
                }
            }
        }
    }
    
    fun deleteAudio(gameId: String, word: String, completion: (Boolean, String?) -> Unit) {
        scope.launch {
            val result = gameManager.deleteAudio(gameId, word)
            withContext(Dispatchers.Main) {
                if (result.isSuccess) {
                    completion(true, null)
                } else {
                    completion(false, result.exceptionOrNull()?.message)
                }
            }
        }
    }
    
    // Game management methods
    fun startGame(gameId: String, completion: (Boolean) -> Unit) {
        scope.launch {
            val result = gameManager.startGame(gameId)
            withContext(Dispatchers.Main) { completion(result) }
        }
    }
    
    // Utility methods
    fun getParticipantNames(game: MultiUserGame): List<String> {
        return gameManager.getParticipantNames(game)
    }
    
    fun getCreatorName(game: MultiUserGame): String? {
        return gameManager.getCreatorName(game)
    }
    
    fun addWords(gameId: String, words: List<Word>, completion: (Boolean) -> Unit) {
        scope.launch {
            val result = gameManager.addWords(gameId, words)
            withContext(Dispatchers.Main) { completion(result) }
        }
    }
    
    fun clearAllErrors() {
        gameManager.clearError()
    }
    
    fun dispose() {
        scope.cancel()
    }
}
