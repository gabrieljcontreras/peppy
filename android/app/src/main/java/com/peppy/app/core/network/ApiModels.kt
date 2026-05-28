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
    @SerialName("display_name") val displayName: String? = null
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
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("is_verified") val isVerified: Boolean = false
)

@Serializable
data class ApiError(
    val detail: String? = null,
    val message: String? = null
)

// Protocol Models

@Serializable
data class CompoundRequest(
    val name: String,
    @SerialName("dose_mg") val doseMg: Double,
    @SerialName("dose_unit") val doseUnit: String = "mg",
    val frequency: String,
    @SerialName("administration_route") val administrationRoute: String = "subcutaneous",
    val notes: String? = null
)

@Serializable
data class CompoundResponse(
    val id: String,
    val name: String,
    @SerialName("dose_mg") val doseMg: Double,
    @SerialName("dose_unit") val doseUnit: String,
    val frequency: String,
    @SerialName("administration_route") val administrationRoute: String,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
data class ProtocolCreateRequest(
    val name: String,
    @SerialName("start_date") val startDate: String,
    @SerialName("end_date") val endDate: String? = null,
    val compounds: List<CompoundRequest>,
    val notes: String? = null
)

@Serializable
data class ProtocolUpdateRequest(
    val name: String? = null,
    @SerialName("start_date") val startDate: String? = null,
    @SerialName("end_date") val endDate: String? = null,
    val notes: String? = null,
    @SerialName("is_active") val isActive: Boolean? = null
)

@Serializable
data class CompoundsReplaceRequest(
    val compounds: List<CompoundRequest>
)

@Serializable
data class ProtocolResponse(
    val id: String,
    val name: String,
    @SerialName("start_date") val startDate: String,
    @SerialName("end_date") val endDate: String? = null,
    @SerialName("is_active") val isActive: Boolean,
    val notes: String? = null,
    val compounds: List<CompoundResponse>,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String
)

@Serializable
data class ProtocolListResponse(
    val protocols: List<ProtocolResponse>,
    val total: Int,
    val limit: Int,
    val offset: Int
)

@Serializable
data class MessageResponse(
    val message: String
)
