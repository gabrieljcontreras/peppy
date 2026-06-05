package com.peppy.app.features.onboarding.ui.steps

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.peppy.app.ui.theme.Cream100
import com.peppy.app.ui.theme.Cream50
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Ink900
import com.peppy.app.ui.theme.Rust500
import com.peppy.app.ui.theme.Spacing

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun WorkoutStep(
    workoutDays: Int?,
    onDaysChange: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "How often do you work out?",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Spacer(modifier = Modifier.height(Spacing.sm))
        Text(
            text = "This helps peppy understand your activity level and tailor recovery insights.",
            style = MaterialTheme.typography.bodyLarge,
            color = Ink500
        )
        Spacer(modifier = Modifier.height(Spacing.xxl))
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm)
        ) {
            (0..7).forEach { day ->
                val isSelected = workoutDays == day
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .then(
                            if (isSelected) Modifier.background(Rust500)
                            else Modifier.background(Cream50).border(1.dp, Ink500.copy(alpha = 0.3f), CircleShape)
                        )
                        .clickable { onDaysChange(day) },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = day.toString(),
                        style = MaterialTheme.typography.labelLarge,
                        color = if (isSelected) Cream100 else Ink900
                    )
                }
            }
        }
        Spacer(modifier = Modifier.height(Spacing.sm))
        Text(
            text = "days per week",
            style = MaterialTheme.typography.bodySmall,
            color = Ink500
        )
    }
}
