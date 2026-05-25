package com.peppy.app.ui.theme

import android.app.Activity
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val PeppyColorScheme = lightColorScheme(
    primary = Primary,
    onPrimary = OnPrimary,
    primaryContainer = PrimaryLight,
    onPrimaryContainer = TextPrimary,
    secondary = PrimaryLight,
    onSecondary = TextPrimary,
    secondaryContainer = SurfaceElevated,
    onSecondaryContainer = TextPrimary,
    tertiary = Success,
    onTertiary = OnPrimary,
    tertiaryContainer = Success,
    onTertiaryContainer = TextPrimary,
    error = Error,
    onError = OnPrimary,
    errorContainer = Error,
    onErrorContainer = OnPrimary,
    background = Background,
    onBackground = OnBackground,
    surface = Surface,
    onSurface = OnSurface,
    surfaceVariant = SurfaceElevated,
    onSurfaceVariant = TextSecondary,
    outline = Border,
    outlineVariant = Border,
    scrim = TextPrimary
)

@Composable
fun PeppyTheme(
    content: @Composable () -> Unit
) {
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = Background.toArgb()
            window.navigationBarColor = Background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = true
            WindowCompat.getInsetsController(window, view).isAppearanceLightNavigationBars = true
        }
    }

    MaterialTheme(
        colorScheme = PeppyColorScheme,
        typography = Typography,
        content = content
    )
}