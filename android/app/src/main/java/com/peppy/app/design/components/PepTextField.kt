package com.peppy.app.design.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import com.peppy.app.ui.theme.Border
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Error
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Primary
import com.peppy.app.ui.theme.Spacing
import com.peppy.app.ui.theme.Surface
import com.peppy.app.ui.theme.SurfaceElevated
import com.peppy.app.ui.theme.TextPrimary
import com.peppy.app.ui.theme.TextSecondary
import com.peppy.app.ui.theme.TextTertiary

@Composable
fun PepTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    error: String? = null,
    isPassword: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    imeAction: ImeAction = ImeAction.Default,
    onImeAction: () -> Unit = {},
    enabled: Boolean = true,
    singleLine: Boolean = true
) {
    Column(modifier = modifier) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            enabled = enabled,
            singleLine = singleLine,
            label = label?.let { { Text(it) } },
            placeholder = placeholder?.let { { Text(it, color = TextTertiary) } },
            isError = error != null,
            visualTransformation = if (isPassword) PasswordVisualTransformation() else VisualTransformation.None,
            keyboardOptions = KeyboardOptions(
                keyboardType = keyboardType,
                imeAction = imeAction
            ),
            keyboardActions = KeyboardActions(
                onAny = { onImeAction() }
            ),
            shape = RoundedCornerShape(CornerRadius.sm),
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = TextPrimary,
                unfocusedTextColor = TextPrimary,
                disabledTextColor = TextSecondary,
                focusedContainerColor = Surface,
                unfocusedContainerColor = Surface,
                disabledContainerColor = Surface,
                errorContainerColor = Surface,
                cursorColor = Primary,
                focusedBorderColor = Primary,
                unfocusedBorderColor = Border,
                disabledBorderColor = Border.copy(alpha = 0.5f),
                errorBorderColor = Error,
                focusedLabelColor = Primary,
                unfocusedLabelColor = TextSecondary,
                disabledLabelColor = TextTertiary,
                errorLabelColor = Error,
                focusedPlaceholderColor = TextTertiary,
                unfocusedPlaceholderColor = TextTertiary
            )
        )
        if (error != null) {
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = Error,
                modifier = Modifier.padding(start = Spacing.xs, top = Spacing.xs)
            )
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF1C1917)
@Composable
private fun PepTextFieldPreview() {
    PeppyTheme {
        Column(modifier = Modifier.padding(Spacing.md)) {
            PepTextField(
                value = "",
                onValueChange = {},
                label = "Email",
                placeholder = "Enter your email"
            )
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF1C1917)
@Composable
private fun PepTextFieldErrorPreview() {
    PeppyTheme {
        Column(modifier = Modifier.padding(Spacing.md)) {
            PepTextField(
                value = "invalid",
                onValueChange = {},
                label = "Email",
                error = "Please enter a valid email"
            )
        }
    }
}
