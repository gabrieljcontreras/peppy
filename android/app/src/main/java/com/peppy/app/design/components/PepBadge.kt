package com.peppy.app.design.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Cream100
import com.peppy.app.ui.theme.Cream200
import com.peppy.app.ui.theme.Danger
import com.peppy.app.ui.theme.Ink900
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Rust500
import com.peppy.app.ui.theme.Spacing
import com.peppy.app.ui.theme.Success
import com.peppy.app.ui.theme.Warning

enum class PepBadgeStyle {
    Default,
    Primary,
    Success,
    Warning,
    Error
}

@Composable
fun PepBadge(
    text: String,
    modifier: Modifier = Modifier,
    style: PepBadgeStyle = PepBadgeStyle.Default
) {
    val (backgroundColor, textColor) = when (style) {
        PepBadgeStyle.Default -> Cream200 to Ink900
        PepBadgeStyle.Primary -> Rust500.copy(alpha = 0.15f) to Rust500
        PepBadgeStyle.Success -> Success.copy(alpha = 0.15f) to Success
        PepBadgeStyle.Warning -> Warning.copy(alpha = 0.15f) to Warning
        PepBadgeStyle.Error -> Danger.copy(alpha = 0.15f) to Danger
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(CornerRadius.sm))
            .background(backgroundColor)
            .padding(horizontal = Spacing.sm, vertical = Spacing.xs)
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = textColor
        )
    }
}

@Composable
fun PepNotificationDot(
    modifier: Modifier = Modifier,
    color: Color = Rust500
) {
    Box(
        modifier = modifier
            .size(8.dp)
            .clip(CircleShape)
            .background(color)
    )
}

@Composable
fun PepCountBadge(
    count: Int,
    modifier: Modifier = Modifier
) {
    if (count > 0) {
        Box(
            modifier = modifier
                .clip(CircleShape)
                .background(Rust500)
                .padding(horizontal = 6.dp, vertical = 2.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = if (count > 99) "99+" else count.toString(),
                style = MaterialTheme.typography.labelSmall,
                color = Cream100
            )
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFFAF7F0)
@Composable
private fun PepBadgePreview() {
    PeppyTheme {
        Row(
            modifier = Modifier.padding(Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
        ) {
            PepBadge(text = "Active", style = PepBadgeStyle.Success)
            PepBadge(text = "Pending", style = PepBadgeStyle.Warning)
            PepBadge(text = "Alert", style = PepBadgeStyle.Error)
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFFAF7F0)
@Composable
private fun PepCountBadgePreview() {
    PeppyTheme {
        Row(
            modifier = Modifier.padding(Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            PepCountBadge(count = 3)
            PepCountBadge(count = 99)
            PepCountBadge(count = 150)
        }
    }
}
