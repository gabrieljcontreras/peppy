package com.peppy.app.features.auth.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.peppy.app.core.di.Dependencies
import com.peppy.app.core.network.ApiResult
import com.peppy.app.core.network.LoginRequest
import com.peppy.app.core.network.RegisterRequest
import com.peppy.app.core.state.AppState
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AuthUiState(
    val email: String = "",
    val password: String = "",
    val name: String = "",
    val emailError: String? = null,
    val passwordError: String? = null,
    val nameError: String? = null,
    val isLoading: Boolean = false,
    val generalError: String? = null
)

sealed class AuthEvent {
    data object NavigateToMain : AuthEvent()
    data object NavigateBack : AuthEvent()
}

class AuthViewModel(
    private val appState: AppState
) : ViewModel() {

    private val deps = Dependencies.get()
    private val apiClient = deps.apiClient
    private val secureStorage = deps.secureStorage

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<AuthEvent>()
    val events: SharedFlow<AuthEvent> = _events.asSharedFlow()

    fun updateEmail(email: String) {
        _uiState.value = _uiState.value.copy(email = email, emailError = null, generalError = null)
    }

    fun updatePassword(password: String) {
        _uiState.value = _uiState.value.copy(password = password, passwordError = null, generalError = null)
    }

    fun updateName(name: String) {
        _uiState.value = _uiState.value.copy(name = name, nameError = null, generalError = null)
    }

    fun login() {
        val state = _uiState.value
        if (!validateLoginFields(state)) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, generalError = null)

            when (val result = apiClient.execute { apiClient.service.login(LoginRequest(state.email, state.password)) }) {
                is ApiResult.Success -> {
                    secureStorage.accessToken = result.data.accessToken
                    secureStorage.refreshToken = result.data.refreshToken
                    fetchUserAndNavigate()
                }
                is ApiResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        generalError = result.message
                    )
                }
                is ApiResult.Exception -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        generalError = "Connection failed. Please check your network."
                    )
                }
            }
        }
    }

    fun register() {
        val state = _uiState.value
        if (!validateRegisterFields(state)) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, generalError = null)

            val request = RegisterRequest(
                email = state.email,
                password = state.password,
                name = state.name.ifBlank { null }
            )

            when (val result = apiClient.execute { apiClient.service.register(request) }) {
                is ApiResult.Success -> {
                    secureStorage.accessToken = result.data.accessToken
                    secureStorage.refreshToken = result.data.refreshToken
                    fetchUserAndNavigate()
                }
                is ApiResult.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        generalError = result.message
                    )
                }
                is ApiResult.Exception -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        generalError = "Connection failed. Please check your network."
                    )
                }
            }
        }
    }

    private suspend fun fetchUserAndNavigate() {
        when (val result = apiClient.execute { apiClient.service.me() }) {
            is ApiResult.Success -> {
                appState.setAuthenticated(result.data)
                _uiState.value = _uiState.value.copy(isLoading = false)
                _events.emit(AuthEvent.NavigateToMain)
            }
            is ApiResult.Error, is ApiResult.Exception -> {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    generalError = "Failed to load user profile."
                )
            }
        }
    }

    fun clearState() {
        _uiState.value = AuthUiState()
    }

    private fun validateLoginFields(state: AuthUiState): Boolean {
        var isValid = true
        var newState = state

        if (state.email.isBlank()) {
            newState = newState.copy(emailError = "Email is required")
            isValid = false
        } else if (!isValidEmail(state.email)) {
            newState = newState.copy(emailError = "Please enter a valid email")
            isValid = false
        }

        if (state.password.isBlank()) {
            newState = newState.copy(passwordError = "Password is required")
            isValid = false
        }

        _uiState.value = newState
        return isValid
    }

    private fun validateRegisterFields(state: AuthUiState): Boolean {
        var isValid = true
        var newState = state

        if (state.email.isBlank()) {
            newState = newState.copy(emailError = "Email is required")
            isValid = false
        } else if (!isValidEmail(state.email)) {
            newState = newState.copy(emailError = "Please enter a valid email")
            isValid = false
        }

        if (state.password.isBlank()) {
            newState = newState.copy(passwordError = "Password is required")
            isValid = false
        } else if (state.password.length < 8) {
            newState = newState.copy(passwordError = "Password must be at least 8 characters")
            isValid = false
        }

        _uiState.value = newState
        return isValid
    }

    private fun isValidEmail(email: String): Boolean {
        return android.util.Patterns.EMAIL_ADDRESS.matcher(email).matches()
    }
}
