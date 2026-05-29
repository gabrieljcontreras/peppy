package com.peppy.app.features.checkin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
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

private data class CheckinRange(
    val label: String,
    val days: Int?
)

private val historyRanges = listOf(
    CheckinRange("7 days", 7),
    CheckinRange("30 days", 30),
    CheckinRange("90 days", 90),
    CheckinRange("All", null)
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CheckinScreen(
    viewModel: CheckinViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    var selectedCheckin by remember { mutableStateOf<CheckinResponse?>(null) }

    LaunchedEffect(Unit) {
        viewModel.loadCheckins()
    }

    if (selectedCheckin != null) {
        CheckinDetailScreen(
            checkin = selectedCheckin!!,
            onBackClick = { selectedCheckin = null }
        )
        return
    }

    CheckinListAndFormScreen(
        viewModel = viewModel,
        selectedRangeDays = state.rangeDays,
        isLoading = state.isLoading,
        isSaving = state.isSaving,
        error = state.error,
        today = state.today,
        recent = state.recent,
        onRangeChange = { viewModel.loadCheckins(it) },
        onCheckinClick = { selectedCheckin = it }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CheckinListAndFormScreen(
    viewModel: CheckinViewModel,
    selectedRangeDays: Int?,
    isLoading: Boolean,
    isSaving: Boolean,
    error: String?,
    today: CheckinResponse?,
    recent: List<CheckinResponse>,
    onRangeChange: (Int?) -> Unit,
    onCheckinClick: (CheckinResponse) -> Unit
) {
    var weight by remember { mutableStateOf("") }
    var energy by remember { mutableIntStateOf(7) }
    var sleep by remember { mutableIntStateOf(7) }
    var appetite by remember { mutableIntStateOf(5) }
    var mood by remember { mutableIntStateOf(7) }
    var nausea by remember { mutableIntStateOf(0) }
    var injectionSiteReaction by remember { mutableIntStateOf(0) }
    var fatigue by remember { mutableIntStateOf(0) }
    var headache by remember { mutableIntStateOf(0) }
    var giIssues by remember { mutableIntStateOf(0) }
    var notes by remember { mutableStateOf("") }
    var weightError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(today?.id) {
        today?.let { checkin ->
            weight = checkin.weightKg?.let { String.format("%.1f", it) } ?: ""
            energy = checkin.energyLevel ?: energy
            sleep = checkin.sleepQuality ?: sleep
            appetite = checkin.appetiteLevel ?: appetite
            mood = checkin.mood ?: mood
            nausea = checkin.nausea ?: 0
            injectionSiteReaction = checkin.injectionSiteReaction ?: 0
            fatigue = checkin.fatigue ?: 0
            headache = checkin.headache ?: 0
            giIssues = checkin.giIssues ?: 0
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
                    IconButton(onClick = { viewModel.loadCheckins(selectedRangeDays) }) {
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
            isRefreshing = isLoading,
            onRefresh = { viewModel.loadCheckins(selectedRangeDays) },
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
                        CheckinHeader(today = today)

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

                        Spacer(modifier = Modifier.height(Spacing.space4))
                        SymptomPicker(
                            nausea = nausea,
                            injectionSiteReaction = injectionSiteReaction,
                            fatigue = fatigue,
                            headache = headache,
                            giIssues = giIssues,
                            onNauseaChange = { nausea = it },
                            onInjectionSiteReactionChange = { injectionSiteReaction = it },
                            onFatigueChange = { fatigue = it },
                            onHeadacheChange = { headache = it },
                            onGiIssuesChange = { giIssues = it }
                        )

                        Spacer(modifier = Modifier.height(Spacing.space4))
                        PepTextField(
                            value = notes,
                            onValueChange = { notes = it },
                            label = "Notes",
                            placeholder = "Anything worth remembering?",
                            singleLine = false
                        )

                        if (error != null) {
                            Spacer(modifier = Modifier.height(Spacing.space3))
                            Text(
                                text = error,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.error
                            )
                        }

                        Spacer(modifier = Modifier.height(Spacing.space5))
                        PepButton(
                            text = if (today == null) "Save check-in" else "Update check-in",
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
                                        injectionSiteReaction = injectionSiteReaction,
                                        fatigue = fatigue,
                                        headache = headache,
                                        giIssues = giIssues,
                                        notes = notes.ifBlank { null }
                                    )
                                )
                            },
                            enabled = !isSaving,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }

                item {
                    HistoryHeader(
                        selectedRangeDays = selectedRangeDays,
                        onRangeChange = onRangeChange
                    )
                }

                when {
                    isLoading && recent.isEmpty() -> {
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
                    recent.isEmpty() -> {
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
                            items = recent,
                            key = { it.id }
                        ) { checkin ->
                            CheckinListItem(
                                checkin = checkin,
                                onClick = { onCheckinClick(checkin) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CheckinHeader(today: CheckinResponse?) {
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
                text = if (today == null) "Log how you are feeling" else "Update today's entry",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (today != null) {
            Icon(
                imageVector = Icons.Default.CheckCircle,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun SymptomPicker(
    nausea: Int,
    injectionSiteReaction: Int,
    fatigue: Int,
    headache: Int,
    giIssues: Int,
    onNauseaChange: (Int) -> Unit,
    onInjectionSiteReactionChange: (Int) -> Unit,
    onFatigueChange: (Int) -> Unit,
    onHeadacheChange: (Int) -> Unit,
    onGiIssuesChange: (Int) -> Unit
) {
    Text(
        text = "Symptoms",
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
    Spacer(modifier = Modifier.height(Spacing.space2))
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(Spacing.space2)
    ) {
        SymptomChip("Nausea", nausea, onNauseaChange)
        SymptomChip("Injection site", injectionSiteReaction, onInjectionSiteReactionChange)
        SymptomChip("Fatigue", fatigue, onFatigueChange)
        SymptomChip("Headache", headache, onHeadacheChange)
        SymptomChip("GI issues", giIssues, onGiIssuesChange)
    }

    if (listOf(nausea, injectionSiteReaction, fatigue, headache, giIssues).all { it == 0 }) {
        Spacer(modifier = Modifier.height(Spacing.space2))
        Text(
            text = "Tap a symptom to track severity.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }

    if (nausea > 0) RatingSlider(label = "Nausea severity", value = nausea, rangeStart = 0, onValueChange = onNauseaChange)
    if (injectionSiteReaction > 0) {
        RatingSlider(
            label = "Injection site reaction",
            value = injectionSiteReaction,
            rangeStart = 0,
            onValueChange = onInjectionSiteReactionChange
        )
    }
    if (fatigue > 0) RatingSlider(label = "Fatigue severity", value = fatigue, rangeStart = 0, onValueChange = onFatigueChange)
    if (headache > 0) RatingSlider(label = "Headache severity", value = headache, rangeStart = 0, onValueChange = onHeadacheChange)
    if (giIssues > 0) RatingSlider(label = "GI issues severity", value = giIssues, rangeStart = 0, onValueChange = onGiIssuesChange)
}

@Composable
private fun SymptomChip(
    label: String,
    value: Int,
    onValueChange: (Int) -> Unit
) {
    FilterChip(
        selected = value > 0,
        onClick = { onValueChange(if (value > 0) 0 else 3) },
        label = { Text(label) }
    )
}

@Composable
private fun HistoryHeader(
    selectedRangeDays: Int?,
    onRangeChange: (Int?) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.space2)) {
        Text(
            text = "History",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(Spacing.space2)
        ) {
            historyRanges.forEach { range ->
                FilterChip(
                    selected = selectedRangeDays == range.days,
                    onClick = { onRangeChange(range.days) },
                    label = { Text(range.label) }
                )
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
private fun CheckinListItem(
    checkin: CheckinResponse,
    onClick: () -> Unit
) {
    PepCard(onClick = onClick) {
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CheckinDetailScreen(
    checkin: CheckinResponse,
    onBackClick: () -> Unit
) {
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(formatDate(checkin.date)) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground,
                    navigationIconContentColor = MaterialTheme.colorScheme.onBackground
                )
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(Spacing.space5),
            verticalArrangement = Arrangement.spacedBy(Spacing.space4)
        ) {
            item {
                PepCard {
                    DetailRow("Weight", checkin.weightKg?.let { "${String.format("%.1f", it)} kg" } ?: "Not logged")
                    DetailRow("Energy", checkin.energyLevel?.toString() ?: "Not logged")
                    DetailRow("Sleep", checkin.sleepQuality?.toString() ?: "Not logged")
                    DetailRow("Appetite", checkin.appetiteLevel?.toString() ?: "Not logged")
                    DetailRow("Mood", checkin.mood?.toString() ?: "Not logged")
                }
            }

            item {
                PepCard {
                    Text(
                        text = "Symptoms",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(Spacing.space3))
                    DetailRow("Nausea", symptomValue(checkin.nausea))
                    DetailRow("Injection site", symptomValue(checkin.injectionSiteReaction))
                    DetailRow("Fatigue", symptomValue(checkin.fatigue))
                    DetailRow("Headache", symptomValue(checkin.headache))
                    DetailRow("GI issues", symptomValue(checkin.giIssues))
                }
            }

            item {
                PepCard {
                    Text(
                        text = "Notes",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(Spacing.space2))
                    Text(
                        text = checkin.notes ?: "No notes added.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = Spacing.space1),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.SemiBold
        )
    }
}

private fun symptomValue(value: Int?): String {
    return value?.takeIf { it > 0 }?.toString() ?: "None"
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
        checkin.injectionSiteReaction?.takeIf { it > 0 }?.let { "Injection site $it" },
        checkin.fatigue?.takeIf { it > 0 }?.let { "Fatigue $it" },
        checkin.headache?.takeIf { it > 0 }?.let { "Headache $it" },
        checkin.giIssues?.takeIf { it > 0 }?.let { "GI $it" }
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
