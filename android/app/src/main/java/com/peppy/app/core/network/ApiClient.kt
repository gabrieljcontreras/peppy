package com.peppy.app.core.network

import com.peppy.app.BuildConfig
import com.peppy.app.core.storage.SecureStorage
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.util.concurrent.TimeUnit

sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val code: Int, val message: String) : ApiResult<Nothing>()
    data class Exception(val throwable: Throwable) : ApiResult<Nothing>()
}

class ApiClient(
    private val secureStorage: SecureStorage,
    baseUrl: String = "http://10.0.2.2:8001/api/v1/"
) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    private val refreshService: ApiService by lazy {
        Retrofit.Builder()
            .baseUrl(baseUrl)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .client(
                OkHttpClient.Builder()
                    .connectTimeout(30, TimeUnit.SECONDS)
                    .readTimeout(30, TimeUnit.SECONDS)
                    .writeTimeout(30, TimeUnit.SECONDS)
                    .build()
            )
            .build()
            .create(ApiService::class.java)
    }

    private val authInterceptor = AuthInterceptor(secureStorage) {
        val refreshToken = secureStorage.refreshToken ?: return@AuthInterceptor null
        val response = refreshService.refresh(RefreshRequest(refreshToken))
        if (response.isSuccessful) response.body() else null
    }

    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = if (BuildConfig.DEBUG) {
            HttpLoggingInterceptor.Level.BASIC
        } else {
            HttpLoggingInterceptor.Level.NONE
        }
    }

    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor(authInterceptor)
        .addInterceptor(loggingInterceptor)
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val retrofit = Retrofit.Builder()
        .baseUrl(baseUrl)
        .client(okHttpClient)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()

    val service: ApiService = retrofit.create(ApiService::class.java)

    suspend fun <T> execute(call: suspend () -> Response<T>): ApiResult<T> {
        return try {
            val response = call()
            if (response.isSuccessful) {
                val body = response.body()
                if (body != null) {
                    ApiResult.Success(body)
                } else {
                    @Suppress("UNCHECKED_CAST")
                    ApiResult.Success(Unit as T)
                }
            } else {
                val errorBody = response.errorBody()?.string()
                val message = try {
                    errorBody?.let { json.decodeFromString<ApiError>(it) }?.detail
                        ?: errorBody?.let { json.decodeFromString<ApiError>(it) }?.message
                        ?: "Unknown error"
                } catch (e: Exception) {
                    errorBody ?: "Unknown error"
                }
                ApiResult.Error(response.code(), message)
            }
        } catch (e: Exception) {
            ApiResult.Exception(e)
        }
    }
}
