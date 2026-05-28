package com.peppy.app.features.protocols.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.peppy.app.core.network.CompoundResponse
import com.peppy.app.core.network.ProtocolResponse
import com.peppy.app.design.components.PepBadge
import com.peppy.app.design.components.PepBadgeStyle
import com.peppy.app.design.components.PepButton
import com.peppy.app.design.components.PepButtonVariant
import com.peppy.app.design.components.PepCard
import com.peppy.app.design.components.PepEmptyState
import com.peppy.app.features.protocols.viewmodel.ProtocolEvent
import com.peppy.app.features.protocols.viewmodel.ProtocolViewModel
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProtocolDetailScreen(
    protocolId: String,
    viewModel: ProtocolViewModel = viewModel(),
    onBackClick: () -> Unit = {},
    onEditClick: (String) -> Unit = {},
    onDeleted: () -> Unit = {}
) {
    val state by viewModel.detailState.collectAsState()
    var showDeleteDialog by remember { mutableStateOf(false) }

    LaunchedEffect(protocolId) {
        viewModel.loadProtocol(protocolId)
    }

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is ProtocolEvent.ProtocolDeleted -> onDeleted()
                else -> {}
            }
        }
    }

    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete Protocol") },
            text = { Text("Are you sure you want to delete this protocol? This action cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteDialog = false
                        viewModel.deleteProtocol(protocolId)
                    }
                ) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        state.protocol?.name ?: "Protocol",
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                actions = {
                    if (state.protocol != null) {
                        IconButton(onClick = { onEditClick(protocolId) }) {
                            Icon(Icons.Default.Edit, contentDescription = "Edit")
                        }
                        IconButton(onClick = { showDeleteDialog = true }) {
                            Icon(
                                Icons.Default.Delete,
                                contentDescription = "Delete",
                                tint = MaterialTheme.colorScheme.error
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground
                )
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                state.isLoading -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
                state.error != null -> {
                    PepEmptyState(
                        icon = Icons.Default.Science,
                        title = "Unable to load protocol",
                        message = state.error ?: "An error occurred",
                        modifier = Modifier.fillMaxSize()
                    )
                }
                state.protocol != null -> {
                    ProtocolDetailContent(
                        protocol = state.protocol!!,
                        onActivate = { viewModel.activateProtocol(protocolId) },
                        onDeactivate = { viewModel.deactivateProtocol(protocolId) }
                    )
                }
            }
        }
    }
}

@Composable
private fun ProtocolDetailContent(
    protocol: ProtocolResponse,
    onActivate: () -> Unit,
    onDeactivate: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.space4)
    ) {
        // Status Card
        PepCard(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(Spacing.space4)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Status",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    PepBadge(
                        text = if (protocol.isActive) "Active" else "Inactive",
                        style = if (protocol.isActive) PepBadgeStyle.Success else PepBadgeStyle.Default
                    )
                }

                Spacer(modifier = Modifier.height(Spacing.space4))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.space2)
                ) {
                    if (protocol.isActive) {
                        PepButton(
                            text = "Deactivate",
                            onClick = onDeactivate,
                            variant = PepButtonVariant.Secondary,
                            modifier = Modifier.weight(1f),
                            leadingIcon = Icons.Default.Stop
                        )
                    } else {
                        PepButton(
                            text = "Activate",
                            onClick = onActivate,
                            modifier = Modifier.weight(1f),
                            leadingIcon = Icons.Default.PlayArrow
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.space4))

        // Date Info Card
        PepCard(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(Spacing.space4)
            ) {
                Text(
                    text = "Schedule",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(Spacing.space3))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text(
                            text = "Start Date",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = formatDate(protocol.startDate),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            text = "End Date",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = protocol.endDate?.let { formatDate(it) } ?: "Ongoing",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.space4))

        // Compounds Card
        PepCard(
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(Spacing.space4)
            ) {
                Text(
                    text = "Compounds",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Spacer(modifier = Modifier.height(Spacing.space3))

                protocol.compounds.forEachIndexed { index, compound ->
                    CompoundItem(compound = compound)
                    if (index < protocol.compounds.lastIndex) {
                        HorizontalDivider(
                            modifier = Modifier.padding(vertical = Spacing.space3),
                            color = MaterialTheme.colorScheme.outlineVariant
                        )
                    }
                }
            }
        }

        // Notes Card (if present)
        if (!protocol.notes.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(Spacing.space4))

            PepCard(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(Spacing.space4)
                ) {
                    Text(
                        text = "Notes",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(Spacing.space2))

                    Text(
                        text = protocol.notes!!,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.space8))
    }
}

@Composable
private fun CompoundItem(
    compound: CompoundResponse,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Science,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(Spacing.space2))
            Text(
                text = compound.name,
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurface
            )
        }

        Spacer(modifier = Modifier.height(Spacing.space2))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(
                    text = "Dose",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = "${compound.doseMg} ${compound.doseUnit}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "Frequency",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = formatFrequency(compound.frequency),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "Route",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = formatRoute(compound.administrationRoute),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        }

        if (!compound.notes.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(Spacing.space2))
            Text(
                text = compound.notes!!,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun formatDate(dateString: String): String {
    return try {
        val formatter = DateTimeFormatter.ISO_DATE
        val displayFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy")
        val date = LocalDate.parse(dateString, formatter)
        date.format(displayFormatter)
    } catch (e: Exception) {
        dateString
    }
}

private fun formatFrequency(frequency: String): String {
    return when (frequency.lowercase()) {
        "daily" -> "Daily"
        "every_other_day" -> "Every other day"
        "twice_weekly" -> "Twice weekly"
        "weekly" -> "Weekly"
        "every_10_days" -> "Every 10 days"
        "biweekly" -> "Biweekly"
        "monthly" -> "Monthly"
        "custom" -> "Custom"
        else -> frequency.replace("_", " ").replaceFirstChar { it.uppercase() }
    }
}

private fun formatRoute(route: String): String {
    return when (route.lowercase()) {
        "subcutaneous" -> "SubQ"
        "intramuscular" -> "IM"
        "oral" -> "Oral"
        "nasal" -> "Nasal"
        "other" -> "Other"
        else -> route.replaceFirstChar { it.uppercase() }
    }
}

@Preview(showBackground = true)
@Composable
private fun ProtocolDetailContentPreview() {
    PeppyTheme {
        Box(
            modifier = Modifier
                .background(MaterialTheme.colorScheme.background)
        ) {
            ProtocolDetailContent(
                protocol = ProtocolResponse(
                    id = "1",
                    name = "Retatrutide Titration",
                    startDate = "2026-05-01",
                    endDate = "2026-08-01",
                    isActive = true,
                    notes = "Starting low and titrating up over 12 weeks",
                    compounds = listOf(
                        CompoundResponse(
                            id = "c1",
                            name = "Retatrutide",
                            doseMg = 2.5,
                            doseUnit = "mg",
                            frequency = "weekly",
                            administrationRoute = "subcutaneous",
                            notes = "Inject in abdomen",
                            createdAt = "",
                            updatedAt = ""
                        ),
                        CompoundResponse(
                            id = "c2",
                            name = "BPC-157",
                            doseMg = 250.0,
                            doseUnit = "mcg",
                            frequency = "daily",
                            administrationRoute = "subcutaneous",
                            notes = null,
                            createdAt = "",
                            updatedAt = ""
                        )
                    ),
                    createdAt = "",
                    updatedAt = ""
                ),
                onActivate = {},
                onDeactivate = {}
            )
        }
    }
}
