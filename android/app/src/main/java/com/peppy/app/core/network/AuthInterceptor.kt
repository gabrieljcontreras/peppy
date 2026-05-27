package com.peppy.app.core.network

import com.peppy.app.core.storage.SecureStorage
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.Interceptor
import okhttp3.Request
import okhttp3.Response

class AuthInterceptor(
    private val secureStorage: SecureStorage,
    private val tokenRefresher: suspend () -> TokenResponse?
) : Interceptor {

    private val refreshMutex = Mutex()

    override fun intercept(chain: Interceptor.Chain): Response {
        val originalRequest = chain.request()

        val path = originalRequest.url.encodedPath
        val isPublicAuthEndpoint = path.endsWith("/auth/login") ||
                                   path.endsWith("/auth/register") ||
                                   path.endsWith("/auth/refresh")
        if (isPublicAuthEndpoint) {
            return chain.proceed(originalRequest)
        }

        val accessToken = secureStorage.accessToken
        if (accessToken == null) {
            return chain.proceed(originalRequest)
        }

        val authenticatedRequest = originalRequest.withBearerToken(accessToken)
        val response = chain.proceed(authenticatedRequest)

        if (response.code == 401) {
            response.close()

            val newToken = runBlocking {
                refreshMutex.withLock {
                    if (secureStorage.accessToken != accessToken) {
                        secureStorage.accessToken
                    } else {
                        try {
                            val refreshed = tokenRefresher()
                            if (refreshed != null) {
                                secureStorage.accessToken = refreshed.accessToken
                                secureStorage.refreshToken = refreshed.refreshToken
                                refreshed.accessToken
                            } else {
                                secureStorage.clear()
                                null
                            }
                        } catch (e: Exception) {
                            secureStorage.clear()
                            null
                        }
                    }
                }
            }

            return if (newToken != null) {
                chain.proceed(originalRequest.withBearerToken(newToken))
            } else {
                chain.proceed(originalRequest)
            }
        }

        return response
    }

    private fun Request.withBearerToken(token: String): Request {
        return newBuilder()
            .header("Authorization", "Bearer $token")
            .build()
    }
}
