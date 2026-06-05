package com.peppy.app.features.onboarding.ui.steps

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.peppy.app.core.data.commonPeptides
import com.peppy.app.design.components.PepAutocompleteField
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.Ink500
import com.peppy.app.ui.theme.Rust100
import com.peppy.app.ui.theme.Rust700
import com.peppy.app.ui.theme.Spacing

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PeptidesStep(
    selectedPeptides: List<String>,
    searchQuery: String,
    onSearchChange: (String) -> Unit,
    onAddPeptide: (String) -> Unit,
    onRemovePeptide: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val peptideNames = commonPeptides.map { it.name }

    Column(modifier = modifier) {
        Text(
            text = "What peptides are you taking?",
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Spacer(modifier = Modifier.height(Spacing.sm))
        Text(
            text = "Select any you're currently using or planning to start. You can always update this later.",
            style = MaterialTheme.typography.bodyLarge,
            color = Ink500
        )
        Spacer(modifier = Modifier.height(Spacing.lg))

        PepAutocompleteField(
            value = searchQuery,
            onValueChange = onSearchChange,
            suggestions = peptideNames,
            onSuggestionSelected = onAddPeptide,
            label = "Search peptides",
            placeholder = "e.g. BPC-157, Semaglutide",
            modifier = Modifier.fillMaxWidth()
        )

        if (selectedPeptides.isNotEmpty()) {
            Spacer(modifier = Modifier.height(Spacing.md))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm)
            ) {
                selectedPeptides.forEach { peptide ->
                    PeptideChip(
                        name = peptide,
                        onRemove = { onRemovePeptide(peptide) }
                    )
                }
            }
        }
    }
}

@Composable
private fun PeptideChip(name: String, onRemove: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(CornerRadius.pill))
            .background(Rust100)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = name,
            style = MaterialTheme.typography.bodySmall,
            color = Rust700
        )
        Spacer(modifier = Modifier.width(Spacing.xs))
        Icon(
            imageVector = Icons.Default.Close,
            contentDescription = "Remove $name",
            tint = Rust700,
            modifier = Modifier
                .size(16.dp)
                .clickable(onClick = onRemove)
        )
    }
}
