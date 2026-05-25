package com.peppy.app.core.di

import android.content.Context
import com.peppy.app.core.network.ApiClient
import com.peppy.app.core.state.AppState
import com.peppy.app.core.storage.SecureStorage
import com.peppy.app.core.storage.SecureStorageImpl

class Dependencies private constructor(context: Context) {

    val secureStorage: SecureStorage = SecureStorageImpl(context.applicationContext)

    val apiClient: ApiClient = ApiClient(secureStorage)

    val appState: AppState = AppState()

    companion object {
        @Volatile
        private var instance: Dependencies? = null

        fun init(context: Context) {
            if (instance == null) {
                synchronized(this) {
                    if (instance == null) {
                        instance = Dependencies(context)
                    }
                }
            }
        }

        fun get(): Dependencies {
            return instance ?: throw IllegalStateException(
                "Dependencies not initialized. Call Dependencies.init(context) first."
            )
        }
    }
}
