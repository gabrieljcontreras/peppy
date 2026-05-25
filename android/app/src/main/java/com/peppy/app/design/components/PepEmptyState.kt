package com.peppy.app.design.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing
import com.peppy.app.ui.theme.TextSecondary
import com.peppy.app.ui.theme.TextTertiary

@Composable
fun PepEmptyState(
    title: String,
    modifier: Modifier = Modifier,
    message: String? = null,
    icon: ImageVector = Icons.Outlined.Inbox,
    action: @Composable (() -> Unit)? = null
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(Spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = TextTertiary
        )

        Spacer(modifier = Modifier.height(Spacing.lg))

        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            color = TextSecondary,
            textAlign = TextAlign.Center
        )

        if (message != null) {
            Spacer(modifier = Modifier.height(Spacing.sm))
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = TextTertiary,
                textAlign = TextAlign.Center
            )
        }

        if (action != null) {
            Spacer(modifier = Modifier.height(Spacing.lg))
            action()
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF1C1917)
@Composable
private fun PepEmptyStatePreview() {
    PeppyTheme {
        PepEmptyState(
            title = "No protocols yet",
            message = "Create your first protocol to start tracking your journey.",
            action = {
                PepButton(
                    text = "Create Protocol",
                    onClick = {}
                )
            }
        )
    }
}
