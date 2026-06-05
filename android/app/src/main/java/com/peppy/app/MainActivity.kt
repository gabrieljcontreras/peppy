package com.peppy.app

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.fragment.app.FragmentActivity
import com.peppy.app.core.auth.BiometricAvailability
import com.peppy.app.core.auth.BiometricResult
import com.peppy.app.core.di.Dependencies
import com.peppy.app.core.state.AuthState
import com.peppy.app.design.components.PepButton
import com.peppy.app.navigation.AppNavigation
import com.peppy.app.ui.theme.PeppyTheme
import kotlinx.coroutines.launch

sealed class AppLaunchState {
    data object Loading : AppLaunchState()
    data object BiometricRequired : AppLaunchState()
    data class BiometricFailed(val message: String) : AppLaunchState()
    data object Ready : AppLaunchState()
}

class MainActivity : FragmentActivity() {
    private var isReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        splashScreen.setKeepOnScreenCondition { !isReady }

        val deps = Dependencies.get()
        val appState = deps.appState
        val biometricManager = deps.biometricManager
        val secureStorage = deps.secureStorage
        val onboardingStorage = deps.onboardingStorage

        setContent {
            var launchState by remember { mutableStateOf<AppLaunchState>(AppLaunchState.Loading) }
            val authState by appState.authState.collectAsState()
            val scope = rememberCoroutineScope()

            fun attemptBiometric() {
                scope.launch {
                    launchState = AppLaunchState.BiometricRequired
                    when (val result = biometricManager.authenticate(this@MainActivity)) {
                        is BiometricResult.Success -> {
                            appState.setAuthenticated(
                                com.peppy.app.core.network.UserResponse(
                                    id = "cached",
                                    email = "",
                                    displayName = null
                                )
                            )
                            launchState = AppLaunchState.Ready
                            isReady = true
                        }
                        is BiometricResult.Failed -> {
                            launchState = AppLaunchState.BiometricFailed(result.message)
                            isReady = true
                        }
                        is BiometricResult.Cancelled -> {
                            launchState = AppLaunchState.BiometricFailed("Authentication cancelled")
                            isReady = true
                        }
                    }
                }
            }

            LaunchedEffect(Unit) {
                if (!onboardingStorage.isOnboardingComplete) {
                    appState.setUnauthenticated()
                    launchState = AppLaunchState.Ready
                    isReady = true
                    return@LaunchedEffect
                }

                val hasTokens = secureStorage.accessToken != null
                val biometricEnabled = secureStorage.biometricEnabled
                val biometricAvailable = biometricManager.canAuthenticate() == BiometricAvailability.AVAILABLE

                when {
                    !hasTokens -> {
                        appState.setUnauthenticated()
                        launchState = AppLaunchState.Ready
                        isReady = true
                    }
                    hasTokens && biometricEnabled && biometricAvailable -> {
                        attemptBiometric()
                    }
                    else -> {
                        appState.setAuthenticated(
                            com.peppy.app.core.network.UserResponse(
                                id = "cached",
                                email = "",
                                displayName = null
                            )
                        )
                        launchState = AppLaunchState.Ready
                        isReady = true
                    }
                }
            }

            PeppyTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    when (launchState) {
                        is AppLaunchState.Loading,
                        is AppLaunchState.BiometricRequired -> {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(MaterialTheme.colorScheme.background),
                                contentAlignment = Alignment.Center
                            ) {
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.Center
                                ) {
                                    CircularProgressIndicator(
                                        color = MaterialTheme.colorScheme.primary
                                    )
                                    if (launchState is AppLaunchState.BiometricRequired) {
                                        Spacer(modifier = Modifier.height(16.dp))
                                        Text(
                                            text = "Authenticating...",
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.onBackground
                                        )
                                    }
                                }
                            }
                        }
                        is AppLaunchState.BiometricFailed -> {
                            val failedState = launchState as AppLaunchState.BiometricFailed
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(MaterialTheme.colorScheme.background)
                                    .padding(24.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Column(
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.Center
                                ) {
                                    Text(
                                        text = "Authentication failed",
                                        style = MaterialTheme.typography.headlineSmall,
                                        color = MaterialTheme.colorScheme.onBackground
                                    )
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(
                                        text = failedState.message,
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        textAlign = TextAlign.Center
                                    )
                                    Spacer(modifier = Modifier.height(24.dp))
                                    PepButton(
                                        text = "Try again",
                                        onClick = { attemptBiometric() }
                                    )
                                }
                            }
                        }
                        is AppLaunchState.Ready -> {
                            when (authState) {
                                is AuthState.Loading -> {
                                    Box(
                                        modifier = Modifier
                                            .fillMaxSize()
                                            .background(MaterialTheme.colorScheme.background),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        CircularProgressIndicator(
                                            color = MaterialTheme.colorScheme.primary
                                        )
                                    }
                                }
                                else -> {
                                    AppNavigation(appState = appState)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
