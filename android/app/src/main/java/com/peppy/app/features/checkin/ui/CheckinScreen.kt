package com.peppy.app.features.checkin.ui

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.viewmodel.compose.viewModel
import com.peppy.app.core.network.CheckinCreateRequest
import com.peppy.app.core.network.CheckinResponse
import com.peppy.app.design.components.PepButton
import com.peppy.app.design.components.PepCard
import com.peppy.app.design.components.PepEmptyState
import com.peppy.app.design.components.PepTextField
import com.peppy.app.features.checkin.viewmodel.CheckinViewModel
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CheckinScreen(
    viewModel: CheckinViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()

    var weight by remember { mutableStateOf("") }
    var energy by remember { mutableIntStateOf(7) }
    var sleep by remember { mutableIntStateOf(7) }
    var appetite by remember { mutableIntStateOf(5) }
    var mood by remember { mutableIntStateOf(7) }
    var nausea by remember { mutableIntStateOf(0) }
    var fatigue by remember { mutableIntStateOf(0) }
    var headache by remember { mutableIntStateOf(0) }
    var notes by remember { mutableStateOf("") }
    var weightError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        viewModel.loadCheckins()
    }

    LaunchedEffect(state.today?.id) {
        state.today?.let { checkin ->
            weight = checkin.weightKg?.let { String.format("%.1f", it) } ?: ""
            energy = checkin.energyLevel ?: energy
            sleep = checkin.sleepQuality ?: sleep
            appetite = checkin.appetiteLevel ?: appetite
            mood = checkin.mood ?: mood
            nausea = checkin.nausea ?: nausea
            fatigue = checkin.fatigue ?: fatigue
            headache = checkin.headache ?: headache
            notes = checkin.notes.orEmpty()
        }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Check-in",
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                actions = {
                    IconButton(onClick = { viewModel.loadCheckins() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground,
                    actionIconContentColor = MaterialTheme.colorScheme.onBackground
                )
            )
        }
    ) { paddingValues ->
        PullToRefreshBox(
            isRefreshing = state.isLoading,
            onRefresh = { viewModel.loadCheckins() },
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(Spacing.space5),
                verticalArrangement = Arrangement.spacedBy(Spacing.space4)
            ) {
                item {
                    PepCard {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = "Today",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = if (state.today == null) {
                                        "Log how you are feeling"
                                    } else {
                                        "Update today's entry"
                                    },
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            if (state.today != null) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(Spacing.space4))

                        PepTextField(
                            value = weight,
                            onValueChange = {
                                weight = it
                                weightError = null
                            },
                            label = "Weight (kg)",
                            placeholder = "Optional",
                            keyboardType = KeyboardType.Decimal,
                            error = weightError
                        )

                        Spacer(modifier = Modifier.height(Spacing.space4))
                        RatingSlider(label = "Energy", value = energy, rangeStart = 1, onValueChange = { energy = it })
                        RatingSlider(label = "Sleep", value = sleep, rangeStart = 1, onValueChange = { sleep = it })
                        RatingSlider(label = "Appetite", value = appetite, rangeStart = 1, onValueChange = { appetite = it })
                        RatingSlider(label = "Mood", value = mood, rangeStart = 1, onValueChange = { mood = it })

                        Spacer(modifier = Modifier.height(Spacing.space3))
                        Text(
                            text = "Symptoms",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        RatingSlider(label = "Nausea", value = nausea, rangeStart = 0, onValueChange = { nausea = it })
                        RatingSlider(label = "Fatigue", value = fatigue, rangeStart = 0, onValueChange = { fatigue = it })
                        RatingSlider(label = "Headache", value = headache, rangeStart = 0, onValueChange = { headache = it })

                        Spacer(modifier = Modifier.height(Spacing.space4))
                        PepTextField(
                            value = notes,
                            onValueChange = { notes = it },
                            label = "Notes",
                            placeholder = "Anything worth remembering?",
                            singleLine = false
                        )

                        if (state.error != null) {
                            Spacer(modifier = Modifier.height(Spacing.space3))
                            Text(
                                text = state.error ?: "",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.error
                            )
                        }

                        Spacer(modifier = Modifier.height(Spacing.space5))
                        PepButton(
                            text = if (state.today == null) "Save check-in" else "Update check-in",
                            onClick = {
                                val parsedWeight = weight.trim().takeIf { it.isNotEmpty() }?.toDoubleOrNull()
                                if (weight.isNotBlank() && parsedWeight == null) {
                                    weightError = "Enter a valid weight"
                                    return@PepButton
                                }

                                viewModel.saveCheckin(
                                    CheckinCreateRequest(
                                        date = LocalDate.now().toString(),
                                        weightKg = parsedWeight,
                                        energyLevel = energy,
                                        sleepQuality = sleep,
                                        appetiteLevel = appetite,
                                        mood = mood,
                                        nausea = nausea,
                                        fatigue = fatigue,
                                        headache = headache,
                                        notes = notes.ifBlank { null }
                                    )
                                )
                            },
                            enabled = !state.isSaving,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                item {
                    Text(
                        text = "Recent check-ins",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onBackground
                    )
                }

                when {
                    state.isLoading && state.recent.isEmpty() -> {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(Spacing.space8),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                            }
                        }
                    }
                    state.recent.isEmpty() -> {
                        item {
                            PepEmptyState(
                                icon = Icons.Default.Favorite,
                                title = "No check-ins yet",
                                message = "Your daily notes will appear here after you save them"
                            )
                        }
                    }
                    else -> {
                        items(
                            items = state.recent,
                            key = { it.id }
                        ) { checkin ->
                            CheckinListItem(checkin = checkin)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RatingSlider(
    label: String,
    value: Int,
    rangeStart: Int,
    onValueChange: (Int) -> Unit
) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = value.toString(),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.SemiBold
            )
        }
        Slider(
            value = value.toFloat(),
            onValueChange = { onValueChange(it.toInt()) },
            valueRange = rangeStart.toFloat()..10f,
            steps = 10 - rangeStart - 1
        )
    }
}

@Composable
private fun CheckinListItem(checkin: CheckinResponse) {
    PepCard {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = formatDate(checkin.date),
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = buildSummary(checkin),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            checkin.weightKg?.let {
                Text(
                    text = "${String.format("%.1f", it)} kg",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

private fun formatDate(date: String): String {
    return try {
        LocalDate.parse(date).format(DateTimeFormatter.ofPattern("MMM d, yyyy"))
    } catch (e: Exception) {
        date
    }
}

private fun buildSummary(checkin: CheckinResponse): String {
    val pieces = listOfNotNull(
        checkin.energyLevel?.let { "Energy $it" },
        checkin.sleepQuality?.let { "Sleep $it" },
        checkin.mood?.let { "Mood $it" },
        checkin.nausea?.takeIf { it > 0 }?.let { "Nausea $it" },
        checkin.fatigue?.takeIf { it > 0 }?.let { "Fatigue $it" },
        checkin.headache?.takeIf { it > 0 }?.let { "Headache $it" }
    )
    return pieces.ifEmpty { listOf("No ratings logged") }.joinToString(" - ")
}

@Preview(showBackground = true)
@Composable
private fun CheckinScreenPreview() {
    PeppyTheme {
        Box(modifier = Modifier.background(MaterialTheme.colorScheme.background)) {
            CheckinScreen()
        }
    }
}
