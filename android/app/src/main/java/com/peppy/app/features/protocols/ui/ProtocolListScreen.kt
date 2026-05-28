package com.peppy.app.features.protocols.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Science
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.peppy.app.core.network.CompoundResponse
import com.peppy.app.core.network.ProtocolResponse
import com.peppy.app.design.components.PepBadge
import com.peppy.app.design.components.PepBadgeStyle
import com.peppy.app.design.components.PepCard
import com.peppy.app.design.components.PepEmptyState
import com.peppy.app.features.protocols.viewmodel.ProtocolViewModel
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProtocolListScreen(
    viewModel: ProtocolViewModel = viewModel(),
    onProtocolClick: (String) -> Unit = {},
    onCreateClick: () -> Unit = {}
) {
    val state by viewModel.listState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadProtocols()
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "Protocols",
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onCreateClick,
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
                shape = RoundedCornerShape(CornerRadius.pill)
            ) {
                Icon(Icons.Default.Add, contentDescription = "Create protocol")
            }
        }
    ) { paddingValues ->
        PullToRefreshBox(
            isRefreshing = state.isLoading,
            onRefresh = { viewModel.loadProtocols() },
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                state.isLoading && state.protocols.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
                state.error != null && state.protocols.isEmpty() -> {
                    PepEmptyState(
                        icon = Icons.Default.Science,
                        title = "Unable to load protocols",
                        message = state.error ?: "An error occurred",
                        modifier = Modifier.fillMaxSize()
                    )
                }
                state.protocols.isEmpty() -> {
                    PepEmptyState(
                        icon = Icons.Default.Science,
                        title = "No protocols yet",
                        message = "Create your first protocol to start tracking your peptide regimen",
                        modifier = Modifier.fillMaxSize()
                    )
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(Spacing.space4),
                        verticalArrangement = Arrangement.spacedBy(Spacing.space3)
                    ) {
                        items(
                            items = state.protocols,
                            key = { it.id }
                        ) { protocol ->
                            ProtocolListItem(
                                protocol = protocol,
                                onClick = { onProtocolClick(protocol.id) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProtocolListItem(
    protocol: ProtocolResponse,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    PepCard(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(CornerRadius.md))
            .clickable(onClick = onClick)
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
                    text = protocol.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.width(Spacing.space2))
                PepBadge(
                    text = if (protocol.isActive) "Active" else "Inactive",
                    style = if (protocol.isActive) PepBadgeStyle.Success else PepBadgeStyle.Default
                )
            }

            Spacer(modifier = Modifier.height(Spacing.space2))

            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Science,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(Spacing.space1))
                Text(
                    text = "${protocol.compounds.size} compound${if (protocol.compounds.size != 1) "s" else ""}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (protocol.compounds.isNotEmpty()) {
                Spacer(modifier = Modifier.height(Spacing.space2))
                Text(
                    text = protocol.compounds.joinToString(", ") { it.name },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            Spacer(modifier = Modifier.height(Spacing.space2))

            Text(
                text = formatDateRange(protocol.startDate, protocol.endDate),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun formatDateRange(startDate: String, endDate: String?): String {
    return try {
        val formatter = DateTimeFormatter.ISO_DATE
        val displayFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy")
        val start = LocalDate.parse(startDate, formatter)
        val startFormatted = start.format(displayFormatter)

        if (endDate != null) {
            val end = LocalDate.parse(endDate, formatter)
            val endFormatted = end.format(displayFormatter)
            "Started $startFormatted · Ends $endFormatted"
        } else {
            "Started $startFormatted · Ongoing"
        }
    } catch (e: Exception) {
        "Started $startDate"
    }
}

@Preview(showBackground = true)
@Composable
private fun ProtocolListItemPreview() {
    PeppyTheme {
        Box(
            modifier = Modifier
                .background(MaterialTheme.colorScheme.background)
                .padding(16.dp)
        ) {
            ProtocolListItem(
                protocol = ProtocolResponse(
                    id = "1",
                    name = "Retatrutide Titration",
                    startDate = "2026-05-01",
                    endDate = null,
                    isActive = true,
                    notes = null,
                    compounds = listOf(
                        CompoundResponse(
                            id = "c1",
                            name = "Retatrutide",
                            doseMg = 2.5,
                            doseUnit = "mg",
                            frequency = "weekly",
                            administrationRoute = "subcutaneous",
                            notes = null,
                            createdAt = "",
                            updatedAt = ""
                        )
                    ),
                    createdAt = "",
                    updatedAt = ""
                ),
                onClick = {}
            )
        }
    }
}
