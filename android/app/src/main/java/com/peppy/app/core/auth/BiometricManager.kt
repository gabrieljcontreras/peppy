package com.peppy.app.core.auth

import androidx.biometric.BiometricManager as AndroidBiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

enum class BiometricAvailability {
    AVAILABLE,
    NOT_ENROLLED,
    NOT_AVAILABLE
}

sealed class BiometricResult {
    data object Success : BiometricResult()
    data class Failed(val message: String) : BiometricResult()
    data object Cancelled : BiometricResult()
}

interface BiometricManager {
    fun canAuthenticate(): BiometricAvailability
    suspend fun authenticate(activity: FragmentActivity): BiometricResult
}

class BiometricManagerImpl(
    private val androidBiometricManager: AndroidBiometricManager
) : BiometricManager {

    override fun canAuthenticate(): BiometricAvailability {
        return when (androidBiometricManager.canAuthenticate(
            AndroidBiometricManager.Authenticators.BIOMETRIC_STRONG or
            AndroidBiometricManager.Authenticators.BIOMETRIC_WEAK
        )) {
            AndroidBiometricManager.BIOMETRIC_SUCCESS -> BiometricAvailability.AVAILABLE
            AndroidBiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> BiometricAvailability.NOT_ENROLLED
            else -> BiometricAvailability.NOT_AVAILABLE
        }
    }

    override suspend fun authenticate(activity: FragmentActivity): BiometricResult {
        return suspendCancellableCoroutine { continuation ->
            val executor = ContextCompat.getMainExecutor(activity)

            val callback = object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    if (continuation.isActive) {
                        continuation.resume(BiometricResult.Success)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (continuation.isActive) {
                        when (errorCode) {
                            BiometricPrompt.ERROR_USER_CANCELED,
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON,
                            BiometricPrompt.ERROR_CANCELED -> {
                                continuation.resume(BiometricResult.Cancelled)
                            }
                            else -> {
                                continuation.resume(BiometricResult.Failed(errString.toString()))
                            }
                        }
                    }
                }

                override fun onAuthenticationFailed() {
                    // Called when biometric is valid but not recognized
                    // Don't resume here - let user retry, or wait for error/success
                }
            }

            val prompt = BiometricPrompt(activity, executor, callback)

            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Unlock peppy")
                .setSubtitle("Use your fingerprint or face to unlock")
                .setNegativeButtonText("Cancel")
                .setAllowedAuthenticators(
                    AndroidBiometricManager.Authenticators.BIOMETRIC_STRONG or
                    AndroidBiometricManager.Authenticators.BIOMETRIC_WEAK
                )
                .build()

            prompt.authenticate(promptInfo)

            continuation.invokeOnCancellation {
                prompt.cancelAuthentication()
            }
        }
    }
}
