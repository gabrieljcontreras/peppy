package com.peppy.app.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

// peppy Design System v2 — Theme
// Three roles: Rust (brand), Ink (foreground), Cream (background)
// Honors system dark mode preference

private val PeppyLightColorScheme = lightColorScheme(
    // Primary: Rust (brand accent)
    primary = LightPrimary,
    onPrimary = LightOnPrimary,
    primaryContainer = LightPrimaryContainer,
    onPrimaryContainer = LightOnPrimaryContainer,

    // Secondary: Use ink for secondary actions
    secondary = Ink900,
    onSecondary = Cream100,
    secondaryContainer = Ink100,
    onSecondaryContainer = Ink900,

    // Tertiary: Success color
    tertiary = Success,
    onTertiary = Cream100,
    tertiaryContainer = Success,
    onTertiaryContainer = Cream100,

    // Error/Danger
    error = LightError,
    onError = LightOnError,
    errorContainer = Danger,
    onErrorContainer = Cream100,

    // Backgrounds
    background = LightBackground,
    onBackground = LightOnBackground,
    surface = LightSurface,
    onSurface = LightOnSurface,
    surfaceVariant = LightSurfaceVariant,
    onSurfaceVariant = LightOnSurfaceVariant,

    // Outlines
    outline = LightOutline,
    outlineVariant = LightOutlineVariant,

    // Scrim
    scrim = Ink900
)

private val PeppyDarkColorScheme = darkColorScheme(
    // Primary: Rust (slightly desaturated for dark mode)
    primary = DarkPrimary,
    onPrimary = DarkOnPrimary,
    primaryContainer = DarkPrimaryContainer,
    onPrimaryContainer = DarkOnPrimaryContainer,

    // Secondary: Lighter ink for dark mode
    secondary = Ink300,
    onSecondary = Ink900,
    secondaryContainer = DarkSurfaceVariant,
    onSecondaryContainer = DarkOnSurface,

    // Tertiary: Success color
    tertiary = Success,
    onTertiary = DarkBackground,
    tertiaryContainer = Success,
    onTertiaryContainer = DarkBackground,

    // Error/Danger
    error = DarkError,
    onError = DarkOnError,
    errorContainer = Danger,
    onErrorContainer = DarkOnSurface,

    // Backgrounds
    background = DarkBackground,
    onBackground = DarkOnBackground,
    surface = DarkSurface,
    onSurface = DarkOnSurface,
    surfaceVariant = DarkSurfaceVariant,
    onSurfaceVariant = DarkOnSurfaceVariant,

    // Outlines
    outline = DarkOutline,
    outlineVariant = DarkOutlineVariant,

    // Scrim
    scrim = Ink900
)

@Composable
fun PeppyTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) PeppyDarkColorScheme else PeppyLightColorScheme

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            window.navigationBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
            WindowCompat.getInsetsController(window, view).isAppearanceLightNavigationBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}