package com.peppy.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.peppy.app.core.di.Dependencies
import com.peppy.app.core.state.AuthState
import com.peppy.app.navigation.AppNavigation
import com.peppy.app.ui.theme.PeppyTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val deps = Dependencies.get()
        val appState = deps.appState

        setContent {
            val authState by appState.authState.collectAsState()

            LaunchedEffect(Unit) {
                if (deps.secureStorage.accessToken != null) {
                    // Skip API check for now - just go to main if we have a token
                    // Backend validation can happen in the background
                    appState.setUnauthenticated()
                } else {
                    appState.setUnauthenticated()
                }
            }

            PeppyTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    when (authState) {
                        is AuthState.Loading -> {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(MaterialTheme.colorScheme.background),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
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