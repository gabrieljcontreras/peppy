package com.peppy.app.features.onboarding.ui.steps

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.peppy.app.design.components.PepTextField
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Spacing

@Composable
fun MedicationsStep(
    medications: String,
    onMedicationsChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "Any other medications?",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Spacer(modifier = Modifier.height(Spacing.sm))
        Text(
            text = "This is optional. It helps peppy flag potential interactions and provide safer insights.",
            style = MaterialTheme.typography.bodyLarge,
            color = Ink500
        )
        Spacer(modifier = Modifier.height(Spacing.xxl))
        PepTextField(
            value = medications,
            onValueChange = onMedicationsChange,
            label = "Medications (optional)",
            placeholder = "e.g. Metformin, Levothyroxine",
            singleLine = false,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
