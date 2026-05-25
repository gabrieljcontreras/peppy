package com.peppy.app.features.auth.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.tooling.preview.Preview
import com.peppy.app.design.components.PepButton
import com.peppy.app.design.components.PepTextField
import com.peppy.app.features.auth.viewmodel.AuthUiState
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RegisterScreen(
    uiState: AuthUiState,
    onNameChange: (String) -> Unit,
    onEmailChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onRegisterClick: () -> Unit,
    onBackClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .imePadding()
    ) {
        TopAppBar(
            title = {},
            navigationIcon = {
                IconButton(onClick = onBackClick) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = MaterialTheme.colorScheme.onBackground
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.background
            )
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            Text(
                text = "Create account",
                style = MaterialTheme.typography.headlineLarge,
                color = MaterialTheme.colorScheme.onBackground
            )

            Text(
                text = "Start tracking your peptide protocols today",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(Spacing.lg))

            PepTextField(
                value = uiState.name,
                onValueChange = onNameChange,
                label = "Name (optional)",
                placeholder = "Your name",
                error = uiState.nameError,
                imeAction = ImeAction.Next,
                enabled = !uiState.isLoading
            )

            PepTextField(
                value = uiState.email,
                onValueChange = onEmailChange,
                label = "Email",
                placeholder = "you@example.com",
                error = uiState.emailError,
                keyboardType = KeyboardType.Email,
                imeAction = ImeAction.Next,
                enabled = !uiState.isLoading
            )

            PepTextField(
                value = uiState.password,
                onValueChange = onPasswordChange,
                label = "Password",
                placeholder = "At least 8 characters",
                error = uiState.passwordError,
                isPassword = true,
                imeAction = ImeAction.Done,
                onImeAction = onRegisterClick,
                enabled = !uiState.isLoading
            )

            if (uiState.generalError != null) {
                Text(
                    text = uiState.generalError,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error
                )
            }

            Spacer(modifier = Modifier.height(Spacing.md))

            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                if (uiState.isLoading) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                } else {
                    PepButton(
                        text = "Create Account",
                        onClick = onRegisterClick,
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !uiState.isLoading
                    )
                }
            }

            Spacer(modifier = Modifier.height(Spacing.xl))
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun RegisterScreenPreview() {
    PeppyTheme {
        RegisterScreen(
            uiState = AuthUiState(),
            onNameChange = {},
            onEmailChange = {},
            onPasswordChange = {},
            onRegisterClick = {},
            onBackClick = {}
        )
    }
}
