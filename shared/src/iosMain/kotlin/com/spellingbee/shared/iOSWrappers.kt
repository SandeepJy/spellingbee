package com.spellingbee.shared

import com.spellingbee.shared.managers.GameManager
import com.spellingbee.shared.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach

class IOSGameManager {
    private val gameManager = GameManager()
    private val scope = MainScope()

    var onUsersChanged: ((List<SpellGameUser>) -> Unit)? = null
    var onGamesChanged: ((List<MultiUserGame>) -> Unit)? = null
    var onCurrentUserChanged: ((SpellGameUser?) -> Unit)? = null

    init {
        gameManager.users.onEach { users -> onUsersChanged?.invoke(users) }.launchIn(scope)

        gameManager.games.onEach { games -> onGamesChanged?.invoke(games) }.launchIn(scope)

        gameManager
                .currentUser
                .onEach { user -> onCurrentUserChanged?.invoke(user) }
                .launchIn(scope)
    }

    fun loadUsers(completion: () -> Unit) {
        scope.launch {
            gameManager.loadUsers()
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

    fun dispose() {
        scope.cancel()
    }
}
