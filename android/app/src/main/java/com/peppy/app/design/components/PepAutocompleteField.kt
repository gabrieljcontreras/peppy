package com.peppy.app.design.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuAnchorType
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.peppy.app.core.data.peptideNames
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Cream50
import com.peppy.app.ui.theme.Danger
import com.peppy.app.ui.theme.Ink100
import com.peppy.app.ui.theme.Ink300
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Ink900
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Rust500
import com.peppy.app.ui.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PepAutocompleteField(
    value: String,
    onValueChange: (String) -> Unit,
    suggestions: List<String>,
    modifier: Modifier = Modifier,
    label: String? = null,
    placeholder: String? = null,
    error: String? = null,
    imeAction: ImeAction = ImeAction.Next,
    onImeAction: () -> Unit = {}
) {
    var expanded by remember { mutableStateOf(false) }

    val filteredSuggestions = remember(value, suggestions) {
        if (value.isBlank()) {
            suggestions.take(10)
        } else {
            suggestions.filter {
                it.contains(value, ignoreCase = true)
            }.take(10)
        }
    }

    Column(modifier = modifier) {
        ExposedDropdownMenuBox(
            expanded = expanded && filteredSuggestions.isNotEmpty(),
            onExpandedChange = { expanded = it }
        ) {
            OutlinedTextField(
                value = value,
                onValueChange = {
                    onValueChange(it)
                    expanded = true
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(ExposedDropdownMenuAnchorType.PrimaryEditable),
                label = label?.let { { Text(it) } },
                placeholder = placeholder?.let { { Text(it, color = Ink300) } },
                isError = error != null,
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = imeAction),
                keyboardActions = KeyboardActions(onAny = { onImeAction() }),
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
                    errorLabelColor = Danger
                )
            )

            if (filteredSuggestions.isNotEmpty()) {
                ExposedDropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false },
                    modifier = Modifier.heightIn(max = 200.dp)
                ) {
                    filteredSuggestions.forEach { suggestion ->
                        DropdownMenuItem(
                            text = {
                                Text(
                                    text = suggestion,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            },
                            onClick = {
                                onValueChange(suggestion)
                                expanded = false
                            }
                        )
                    }
                }
            }
        }

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
private fun PepAutocompleteFieldPreview() {
    PeppyTheme {
        var value by remember { mutableStateOf("") }
        Column(modifier = Modifier.padding(16.dp)) {
            PepAutocompleteField(
                value = value,
                onValueChange = { value = it },
                suggestions = peptideNames,
                label = "Compound Name",
                placeholder = "Search or type custom..."
            )
        }
    }
}
