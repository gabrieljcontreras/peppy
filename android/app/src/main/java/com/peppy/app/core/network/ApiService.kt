package com.peppy.app.core.network

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

interface ApiService {

    // Auth
    @POST("auth/register")
    suspend fun register(@Body request: RegisterRequest): Response<TokenResponse>

    @POST("auth/login")
    suspend fun login(@Body request: LoginRequest): Response<TokenResponse>

    @POST("auth/refresh")
    suspend fun refresh(@Body request: RefreshRequest): Response<TokenResponse>

    @POST("auth/logout")
    suspend fun logout(): Response<Unit>

    @GET("auth/me")
    suspend fun me(): Response<UserResponse>

    // Protocols
    @GET("protocols")
    suspend fun getProtocols(
        @Query("limit") limit: Int = 50,
        @Query("offset") offset: Int = 0,
        @Query("include_inactive") includeInactive: Boolean = true
    ): Response<List<ProtocolResponse>>

    @GET("protocols/{id}")
    suspend fun getProtocol(@Path("id") id: String): Response<ProtocolResponse>

    @POST("protocols")
    suspend fun createProtocol(@Body request: ProtocolCreateRequest): Response<ProtocolResponse>

    @PATCH("protocols/{id}")
    suspend fun updateProtocol(
        @Path("id") id: String,
        @Body request: ProtocolUpdateRequest
    ): Response<ProtocolResponse>

    @DELETE("protocols/{id}")
    suspend fun deleteProtocol(@Path("id") id: String): Response<Unit>

    @retrofit2.http.PUT("protocols/{id}/compounds")
    suspend fun replaceCompounds(
        @Path("id") id: String,
        @Body request: CompoundsReplaceRequest
    ): Response<ProtocolResponse>

    @POST("protocols/{id}/deactivate")
    suspend fun deactivateProtocol(@Path("id") id: String): Response<ProtocolResponse>

    // Check-ins
    @GET("checkins")
    suspend fun getCheckins(
        @Query("limit") limit: Int = 30,
        @Query("offset") offset: Int = 0
    ): Response<List<CheckinResponse>>

    @GET("checkins/today")
    suspend fun getTodayCheckin(): Response<CheckinResponse?>

    @GET("checkins/weight-trend")
    suspend fun getWeightTrend(
        @Query("days") days: Int = 30
    ): Response<List<WeightTrendPoint>>

    @POST("checkins")
    suspend fun createCheckin(@Body request: CheckinCreateRequest): Response<CheckinResponse>

    @PATCH("checkins/{id}")
    suspend fun updateCheckin(
        @Path("id") id: String,
        @Body request: CheckinUpdateRequest
    ): Response<CheckinResponse>
}
