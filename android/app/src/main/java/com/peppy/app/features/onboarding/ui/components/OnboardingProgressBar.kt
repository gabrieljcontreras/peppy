package com.peppy.app.features.onboarding.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.peppy.app.ui.motion.PeppyMotion
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Rust500

@Composable
fun OnboardingProgressBar(currentStep: Int, totalSteps: Int, modifier: Modifier = Modifier) {
    val progress by animateFloatAsState(
        targetValue = (currentStep + 1).toFloat() / totalSteps,
        animationSpec = PeppyMotion.normalTween(),
        label = "progress"
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(4.dp)
            .clip(RoundedCornerShape(CornerRadius.pill))
            .background(MaterialTheme.colorScheme.outline)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(progress)
                .height(4.dp)
                .clip(RoundedCornerShape(CornerRadius.pill))
                .background(Rust500)
        )
    }
}
