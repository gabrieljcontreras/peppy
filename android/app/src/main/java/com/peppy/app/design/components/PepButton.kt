package com.peppy.app.design.components

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonColors
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing
import com.peppy.app.ui.theme.Error
import com.peppy.app.ui.theme.OnPrimary
import com.peppy.app.ui.theme.Primary
import com.peppy.app.ui.theme.PrimaryDark
import com.peppy.app.ui.theme.Surface
import com.peppy.app.ui.theme.TextPrimary
import com.peppy.app.ui.theme.TextSecondary

enum class PepButtonStyle {
    Primary,
    Secondary,
    Ghost,
    Destructive
}

@Composable
fun PepButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: PepButtonStyle = PepButtonStyle.Primary,
    enabled: Boolean = true
) {
    val shape = RoundedCornerShape(CornerRadius.sm)
    val height = 48.dp
    val contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.sm)

    when (style) {
        PepButtonStyle.Primary -> {
            Button(
                onClick = onClick,
                modifier = modifier.height(height),
                enabled = enabled,
                shape = shape,
                contentPadding = contentPadding,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Primary,
                    contentColor = OnPrimary,
                    disabledContainerColor = Primary.copy(alpha = 0.5f),
                    disabledContentColor = OnPrimary.copy(alpha = 0.5f)
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
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = Primary,
                    disabledContentColor = Primary.copy(alpha = 0.5f)
                )
            ) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
        PepButtonStyle.Ghost -> {
            TextButton(
                onClick = onClick,
                modifier = modifier.height(height),
                enabled = enabled,
                shape = shape,
                contentPadding = contentPadding,
                colors = ButtonDefaults.textButtonColors(
                    contentColor = TextSecondary,
                    disabledContentColor = TextSecondary.copy(alpha = 0.5f)
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
                    containerColor = Error,
                    contentColor = OnPrimary,
                    disabledContainerColor = Error.copy(alpha = 0.5f),
                    disabledContentColor = OnPrimary.copy(alpha = 0.5f)
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

@Preview(showBackground = true, backgroundColor = 0xFF1C1917)
@Composable
private fun PepButtonPreview() {
    PeppyTheme {
        PepButton(text = "Get Started", onClick = {})
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF1C1917)
@Composable
private fun PepButtonSecondaryPreview() {
    PeppyTheme {
        PepButton(text = "Cancel", onClick = {}, style = PepButtonStyle.Secondary)
    }
}
