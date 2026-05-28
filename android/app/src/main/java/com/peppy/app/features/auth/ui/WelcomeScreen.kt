package com.peppy.app.features.auth.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.sp
import com.peppy.app.design.components.PepButton
import com.peppy.app.design.components.PepButtonVariant
import com.peppy.app.ui.theme.NunitoFontFamily
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing

@Composable
fun WelcomeScreen(
    onSignUpClick: () -> Unit,
    onSignInClick: () -> Unit,
    onDevModeClick: (() -> Unit)? = null
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(Spacing.lg)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // peppy wordmark — Nunito font only (per design system)
            Text(
                text = "peppy",
                style = TextStyle(
                    fontFamily = NunitoFontFamily,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 48.sp,
                    letterSpacing = (-0.5).sp
                ),
                color = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.height(Spacing.sm))

            Text(
                text = "Your personal peptide protocol engine",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(Spacing.xxl))

            Text(
                text = "Track protocols, log check-ins, get AI-powered insights — all in one place.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = Spacing.lg)
            )
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(bottom = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md)
        ) {
            PepButton(
                text = "Create Account",
                onClick = onSignUpClick,
                modifier = Modifier.fillMaxWidth()
            )

            PepButton(
                text = "Sign In",
                onClick = onSignInClick,
                modifier = Modifier.fillMaxWidth(),
                variant = PepButtonVariant.Secondary
            )

            if (onDevModeClick != null) {
                Spacer(modifier = Modifier.height(Spacing.lg))
                PepButton(
                    text = "Dev Mode (skip login)",
                    onClick = onDevModeClick,
                    modifier = Modifier.fillMaxWidth(),
                    variant = PepButtonVariant.Tertiary
                )
            }
        }
    }
}

@Preview(showBackground = true, name = "Light Mode")
@Composable
private fun WelcomeScreenPreview() {
    PeppyTheme(darkTheme = false) {
        WelcomeScreen(
            onSignUpClick = {},
            onSignInClick = {}
        )
    }
}

@Preview(showBackground = true, name = "Dark Mode")
@Composable
private fun WelcomeScreenDarkPreview() {
    PeppyTheme(darkTheme = true) {
        WelcomeScreen(
            onSignUpClick = {},
            onSignInClick = {}
        )
    }
}
