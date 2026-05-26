package com.peppy.app.design.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.peppy.app.ui.theme.Cream50
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing

@Composable
fun PepCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(CornerRadius.md)
    val colors = CardDefaults.cardColors(
        containerColor = Cream50
    )

    if (onClick != null) {
        Card(
            onClick = onClick,
            modifier = modifier.fillMaxWidth(),
            shape = shape,
            colors = colors
        ) {
            Column(
                modifier = Modifier.padding(Spacing.md),
                content = content
            )
        }
    } else {
        Card(
            modifier = modifier.fillMaxWidth(),
            shape = shape,
            colors = colors
        ) {
            Column(
                modifier = Modifier.padding(Spacing.md),
                content = content
            )
        }
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFFAF7F0)
@Composable
private fun PepCardPreview() {
    PeppyTheme {
        PepCard(modifier = Modifier.padding(Spacing.md)) {
            Text(
                text = "Active Protocol",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "Retatrutide 5mg • Week 3",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
