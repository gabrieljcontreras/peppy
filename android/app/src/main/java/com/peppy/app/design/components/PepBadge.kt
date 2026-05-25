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
import com.peppy.app.ui.theme.Error
import com.peppy.app.ui.theme.OnPrimary
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Primary
import com.peppy.app.ui.theme.PrimaryLight
import com.peppy.app.ui.theme.Spacing
import com.peppy.app.ui.theme.Success
import com.peppy.app.ui.theme.Surface
import com.peppy.app.ui.theme.SurfaceElevated
import com.peppy.app.ui.theme.TextPrimary
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
        PepBadgeStyle.Default -> SurfaceElevated to TextPrimary
        PepBadgeStyle.Primary -> Primary.copy(alpha = 0.2f) to Primary
        PepBadgeStyle.Success -> Success.copy(alpha = 0.2f) to Success
        PepBadgeStyle.Warning -> Warning.copy(alpha = 0.2f) to Warning
        PepBadgeStyle.Error -> Error.copy(alpha = 0.2f) to Error
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
    color: Color = Primary
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
                .background(Primary)
                .padding(horizontal = 6.dp, vertical = 2.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = if (count > 99) "99+" else count.toString(),
                style = MaterialTheme.typography.labelSmall,
                color = OnPrimary
            )
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF1C1917)
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

@Preview(showBackground = true, backgroundColor = 0xFF1C1917)
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
