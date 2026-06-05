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
import com.peppy.app.core.storage.WeightUnit
import com.peppy.app.design.components.PepTextField
import com.peppy.app.features.onboarding.ui.components.UnitToggle
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Spacing

@Composable
fun WeightStep(
    weight: String,
    weightUnit: WeightUnit,
    onWeightChange: (String) -> Unit,
    onUnitChange: (WeightUnit) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "What's your current weight?",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Spacer(modifier = Modifier.height(Spacing.sm))
        Text(
            text = "We'll use this as your starting point to track trends over time.",
            style = MaterialTheme.typography.bodyLarge,
            color = Ink500
        )
        Spacer(modifier = Modifier.height(Spacing.lg))
        UnitToggle(
            options = listOf("lbs", "kg"),
            selectedIndex = if (weightUnit == WeightUnit.LBS) 0 else 1,
            onSelect = { onUnitChange(if (it == 0) WeightUnit.LBS else WeightUnit.KG) }
        )
        Spacer(modifier = Modifier.height(Spacing.lg))
        PepTextField(
            value = weight,
            onValueChange = onWeightChange,
            label = if (weightUnit == WeightUnit.LBS) "Pounds" else "Kilograms",
            placeholder = if (weightUnit == WeightUnit.LBS) "165" else "75",
            keyboardType = KeyboardType.Decimal,
            modifier = Modifier.fillMaxWidth(0.5f)
        )
    }
}
