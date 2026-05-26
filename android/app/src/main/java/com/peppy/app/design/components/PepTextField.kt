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
import com.peppy.app.ui.theme.Cream50
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Danger
import com.peppy.app.ui.theme.Ink100
import com.peppy.app.ui.theme.Ink300
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Ink900
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Rust500
import com.peppy.app.ui.theme.Spacing

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
            placeholder = placeholder?.let { { Text(it, color = Ink300) } },
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
                focusedTextColor = Ink900,
                unfocusedTextColor = Ink900,
                disabledTextColor = Ink500,
                focusedContainerColor = Cream50,
                unfocusedContainerColor = Cream50,
                disabledContainerColor = Cream50,
                errorContainerColor = Cream50,
                cursorColor = Rust500,
                focusedBorderColor = Rust500,
                unfocusedBorderColor = Ink100,
                disabledBorderColor = Ink100.copy(alpha = 0.5f),
                errorBorderColor = Danger,
                focusedLabelColor = Rust500,
                unfocusedLabelColor = Ink500,
                disabledLabelColor = Ink300,
                errorLabelColor = Danger,
                focusedPlaceholderColor = Ink300,
                unfocusedPlaceholderColor = Ink300
            )
        )
        if (error != null) {
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = Danger,
                modifier = Modifier.padding(start = Spacing.xs, top = Spacing.xs)
            )
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFFAF7F0)
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

@Preview(showBackground = true, backgroundColor = 0xFFFAF7F0)
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
