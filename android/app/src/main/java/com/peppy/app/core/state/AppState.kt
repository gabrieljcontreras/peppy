package com.peppy.app.core.state

import com.peppy.app.core.network.UserResponse
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

sealed class AuthState {
    data object Loading : AuthState()
    data object Unauthenticated : AuthState()
    data class Authenticated(val user: UserResponse) : AuthState()
}

class AppState {
    private val _authState = MutableStateFlow<AuthState>(AuthState.Loading)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    fun setAuthenticated(user: UserResponse) {
        _authState.value = AuthState.Authenticated(user)
    }

    fun setUnauthenticated() {
        _authState.value = AuthState.Unauthenticated
    }

    fun setLoading() {
        _authState.value = AuthState.Loading
    }
}
