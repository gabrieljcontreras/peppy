package com.peppy.app.core.storage

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

interface SecureStorage {
    var accessToken: String?
    var refreshToken: String?
    var biometricEnabled: Boolean
    fun clear()
}

class SecureStorageImpl(context: Context) : SecureStorage {

    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        PREFS_FILE_NAME,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    override var accessToken: String?
        get() = prefs.getString(KEY_ACCESS_TOKEN, null)
        set(value) {
            prefs.edit().apply {
                if (value != null) putString(KEY_ACCESS_TOKEN, value)
                else remove(KEY_ACCESS_TOKEN)
            }.apply()
        }

    override var refreshToken: String?
        get() = prefs.getString(KEY_REFRESH_TOKEN, null)
        set(value) {
            prefs.edit().apply {
                if (value != null) putString(KEY_REFRESH_TOKEN, value)
                else remove(KEY_REFRESH_TOKEN)
            }.apply()
        }

    override var biometricEnabled: Boolean
        get() = prefs.getBoolean(KEY_BIOMETRIC_ENABLED, true)
        set(value) {
            prefs.edit().putBoolean(KEY_BIOMETRIC_ENABLED, value).apply()
        }

    override fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val PREFS_FILE_NAME = "peppy_secure_prefs"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_BIOMETRIC_ENABLED = "biometric_enabled"
    }
}
