package com.peppy.app.features.onboarding.ui.steps

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import com.peppy.app.core.storage.HeightUnit
import com.peppy.app.design.components.PepTextField
import com.peppy.app.features.onboarding.ui.components.UnitToggle
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Spacing

@Composable
fun HeightStep(
    heightUnit: HeightUnit,
    heightFeet: String,
    heightInches: String,
    heightCm: String,
    onUnitChange: (HeightUnit) -> Unit,
    onFeetChange: (String) -> Unit,
    onInchesChange: (String) -> Unit,
    onCmChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "What's your height?",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Spacer(modifier = Modifier.height(Spacing.sm))
        Text(
            text = "Used to calculate BMI and track body composition changes.",
            style = MaterialTheme.typography.bodyLarge,
            color = Ink500
        )
        Spacer(modifier = Modifier.height(Spacing.lg))
        UnitToggle(
            options = listOf("ft / in", "cm"),
            selectedIndex = if (heightUnit == HeightUnit.FT_IN) 0 else 1,
            onSelect = { onUnitChange(if (it == 0) HeightUnit.FT_IN else HeightUnit.CM) }
        )
        Spacer(modifier = Modifier.height(Spacing.lg))
        when (heightUnit) {
            HeightUnit.FT_IN -> {
                Row {
                    PepTextField(
                        value = heightFeet,
                        onValueChange = onFeetChange,
                        label = "Feet",
                        placeholder = "5",
                        keyboardType = KeyboardType.Number,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(modifier = Modifier.width(Spacing.md))
                    PepTextField(
                        value = heightInches,
                        onValueChange = onInchesChange,
                        label = "Inches",
                        placeholder = "10",
                        keyboardType = KeyboardType.Number,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
            HeightUnit.CM -> {
                PepTextField(
                    value = heightCm,
                    onValueChange = onCmChange,
                    label = "Centimeters",
                    placeholder = "178",
                    keyboardType = KeyboardType.Number,
                    modifier = Modifier.fillMaxWidth(0.5f)
                )
            }
        }
    }
}
