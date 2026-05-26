package com.peppy.app.design.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Cream100
import com.peppy.app.ui.theme.Danger
import com.peppy.app.ui.theme.Ink900
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Rust500
import com.peppy.app.ui.theme.Spacing

// peppy Design System v2 — Buttons
// All buttons are pill-shaped (999dp radius)
// Primary: Ink900 background, Cream text — one per screen
// Secondary: transparent, 1.5px ink border
// Tertiary: transparent, rust text

enum class PepButtonStyle {
    Primary,
    Secondary,
    Tertiary,
    Destructive
}

enum class PepButtonSize {
    Small,   // 40dp height, 16dp padding
    Default, // 48dp height, 24dp padding
    Large    // 56dp height, 32dp padding
}

@Composable
fun PepButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: PepButtonStyle = PepButtonStyle.Primary,
    size: PepButtonSize = PepButtonSize.Default,
    enabled: Boolean = true
) {
    val shape = RoundedCornerShape(CornerRadius.pill)

    val (height, horizontalPadding) = when (size) {
        PepButtonSize.Small -> 40.dp to 16.dp
        PepButtonSize.Default -> 48.dp to 24.dp
        PepButtonSize.Large -> 56.dp to 32.dp
    }

    val contentPadding = PaddingValues(horizontal = horizontalPadding, vertical = Spacing.sm)

    when (style) {
        PepButtonStyle.Primary -> {
            Button(
                onClick = onClick,
                modifier = modifier.height(height),
                enabled = enabled,
                shape = shape,
                contentPadding = contentPadding,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Ink900,
                    contentColor = Cream100,
                    disabledContainerColor = Ink900.copy(alpha = 0.4f),
                    disabledContentColor = Cream100.copy(alpha = 0.4f)
                )
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
        PepButtonStyle.Secondary -> {
            OutlinedButton(
                onClick = onClick,
                modifier = modifier.height(height),
                enabled = enabled,
                shape = shape,
                contentPadding = contentPadding,
                border = BorderStroke(1.5.dp, if (enabled) Ink900 else Ink900.copy(alpha = 0.4f)),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = Ink900,
                    disabledContentColor = Ink900.copy(alpha = 0.4f)
                )
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
        PepButtonStyle.Tertiary -> {
            TextButton(
                onClick = onClick,
                modifier = modifier.height(height),
                enabled = enabled,
                shape = shape,
                contentPadding = contentPadding,
                colors = ButtonDefaults.textButtonColors(
                    contentColor = Rust500,
                    disabledContentColor = Rust500.copy(alpha = 0.4f)
                )
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
        PepButtonStyle.Destructive -> {
            Button(
                onClick = onClick,
                modifier = modifier.height(height),
                enabled = enabled,
                shape = shape,
                contentPadding = contentPadding,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Danger,
                    contentColor = Cream100,
                    disabledContainerColor = Danger.copy(alpha = 0.4f),
                    disabledContentColor = Cream100.copy(alpha = 0.4f)
                )
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFFAF7F0)
@Composable
private fun PepButtonPreview() {
    PeppyTheme {
        PepButton(text = "Get started", onClick = {})
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFFAF7F0)
@Composable
private fun PepButtonSecondaryPreview() {
    PeppyTheme {
        PepButton(text = "Cancel", onClick = {}, style = PepButtonStyle.Secondary)
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFFAF7F0)
@Composable
private fun PepButtonTertiaryPreview() {
    PeppyTheme {
        PepButton(text = "Learn more", onClick = {}, style = PepButtonStyle.Tertiary)
    }
}
