package com.spellingbee.shared.managers

import com.spellingbee.shared.models.SpellGameUser
import dev.gitlive.firebase.Firebase
import dev.gitlive.firebase.auth.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class AuthManager {
    private val auth = Firebase.auth
    
    private val _currentUser = MutableStateFlow<SpellGameUser?>(null)
    val currentUser: StateFlow<SpellGameUser?> = _currentUser.asStateFlow()
    
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()
    
    init {
        // Initialize current user if already signed in
        val user = auth.currentUser
        _currentUser.value = user?.let { 
            SpellGameUser(
                id = it.uid,
                username = it.displayName ?: "",
                email = it.email ?: ""
            )
        }
    }
    
    suspend fun register(username: String, email: String, password: String): Result<SpellGameUser> {
        return try {
            _isLoading.value = true
            _error.value = null
            
            val result = auth.createUserWithEmailAndPassword(email, password)
            val user = result.user
            
            if (user != null) {
                // Update display name
                user.updateProfile(displayName = username)
                
                val newUser = SpellGameUser(
                    id = user.uid,
                    username = username,
                    email = email
                )
                _currentUser.value = newUser
                Result.success(newUser)
            } else {
                Result.failure(Exception("Failed to create user"))
            }
        } catch (e: Exception) {
            _error.value = e.message
            Result.failure(e)
        } finally {
            _isLoading.value = false
        }
    }
    
    suspend fun login(email: String, password: String): Result<SpellGameUser> {
        return try {
            _isLoading.value = true
            _error.value = null
            
            val result = auth.signInWithEmailAndPassword(email, password)
            val user = result.user
            
            if (user != null) {
                val loggedInUser = SpellGameUser(
                    id = user.uid,
                    username = user.displayName ?: "",
                    email = email
                )
                _currentUser.value = loggedInUser
                Result.success(loggedInUser)
            } else {
                Result.failure(Exception("Failed to sign in"))
            }
        } catch (e: Exception) {
            _error.value = e.message
            Result.failure(e)
        } finally {
            _isLoading.value = false
        }
    }
    
    suspend fun signOut(): Result<Unit> {
        return try {
            auth.signOut()
            _currentUser.value = null
            Result.success(Unit)
        } catch (e: Exception) {
            _error.value = e.message
            Result.failure(e)
        }
    }
    
    fun clearError() {
        _error.value = null
    }
}
