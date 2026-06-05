package com.peppy.app.features.onboarding.ui.steps

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.peppy.app.design.components.PepTextField
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Cream100
import com.peppy.app.ui.theme.Cream50
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Ink900
import com.peppy.app.ui.theme.Rust100
import com.peppy.app.ui.theme.Rust500
import com.peppy.app.ui.theme.Rust700
import com.peppy.app.ui.theme.Spacing

val defaultGoals = listOf(
    "Track my protocols",
    "Understand my body better",
    "Build consistent habits",
    "See what's actually working",
    "Optimize recovery",
    "Feel more in control"
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GoalsStep(
    selectedGoals: List<String>,
    goalsOther: String,
    onToggleGoal: (String) -> Unit,
    onOtherChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "What do you hope to get out of peppy?",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Spacer(modifier = Modifier.height(Spacing.sm))
        Text(
            text = "Pick as many as you'd like. This helps us shape your experience.",
            style = MaterialTheme.typography.bodyLarge,
            color = Ink500
        )
        Spacer(modifier = Modifier.height(Spacing.lg))

        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm)
        ) {
            defaultGoals.forEach { goal ->
                val isSelected = goal in selectedGoals
                val shape = RoundedCornerShape(CornerRadius.pill)
                Text(
                    text = goal,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (isSelected) Rust700 else Ink900,
                    modifier = Modifier
                        .clip(shape)
                        .then(
                            if (isSelected) Modifier.background(Rust100).border(1.dp, Rust500, shape)
                            else Modifier.background(Cream50).border(1.dp, Ink500.copy(alpha = 0.2f), shape)
                        )
                        .clickable { onToggleGoal(goal) }
                        .padding(horizontal = Spacing.md, vertical = Spacing.sm)
                )
            }
        }

        Spacer(modifier = Modifier.height(Spacing.lg))
        PepTextField(
            value = goalsOther,
            onValueChange = onOtherChange,
            label = "Anything else? (optional)",
            placeholder = "Tell us what matters to you",
            singleLine = false,
            modifier = Modifier.fillMaxWidth()
        )
    }
}
