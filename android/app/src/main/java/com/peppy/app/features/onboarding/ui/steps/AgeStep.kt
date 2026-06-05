package com.peppy.app.features.onboarding.ui.steps

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import com.peppy.app.design.components.PepTextField
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Spacing

@Composable
fun AgeStep(
    age: String,
    onAgeChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "How old are you?",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Spacer(modifier = Modifier.height(Spacing.sm))
        Text(
            text = "This helps peppy personalize your experience and provide age-appropriate insights.",
            style = MaterialTheme.typography.bodyLarge,
            color = Ink500
        )
        Spacer(modifier = Modifier.height(Spacing.xxl))
        PepTextField(
            value = age,
            onValueChange = onAgeChange,
            label = "Age",
            placeholder = "e.g. 32",
            keyboardType = KeyboardType.Number,
            modifier = Modifier.fillMaxWidth(0.4f)
        )
    }
}
