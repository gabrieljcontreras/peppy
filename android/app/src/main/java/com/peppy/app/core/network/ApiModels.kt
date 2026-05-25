package com.peppy.app.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LoginRequest(
    val email: String,
    val password: String
)

@Serializable
data class RegisterRequest(
    val email: String,
    val password: String,
    val name: String? = null
)

@Serializable
data class TokenResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("token_type") val tokenType: String = "bearer"
)

@Serializable
data class RefreshRequest(
    @SerialName("refresh_token") val refreshToken: String
)

@Serializable
data class UserResponse(
    val id: String,
    val email: String,
    val name: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)

@Serializable
data class ApiError(
    val detail: String? = null,
    val message: String? = null
)
