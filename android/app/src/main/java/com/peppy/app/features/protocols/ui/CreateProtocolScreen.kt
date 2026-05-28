package com.peppy.app.features.protocols.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Science
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.peppy.app.core.network.CompoundRequest
import com.peppy.app.design.components.PepButton
import com.peppy.app.design.components.PepButtonVariant
import com.peppy.app.design.components.PepCard
import com.peppy.app.design.components.PepTextField
import com.peppy.app.features.protocols.viewmodel.ProtocolEvent
import com.peppy.app.features.protocols.viewmodel.ProtocolViewModel
import com.peppy.app.ui.theme.CornerRadius
import com.peppy.app.ui.theme.PeppyTheme
import com.peppy.app.ui.theme.Spacing
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

data class CompoundFormState(
    val name: String = "",
    val doseMg: String = "",
    val doseUnit: String = "mg",
    val frequency: String = "weekly",
    val administrationRoute: String = "subcutaneous",
    val notes: String = ""
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateProtocolScreen(
    viewModel: ProtocolViewModel = viewModel(),
    onBackClick: () -> Unit = {},
    onSuccess: () -> Unit = {}
) {
    val createState by viewModel.createState.collectAsState()

    var name by remember { mutableStateOf("") }
    var startDate by remember { mutableStateOf(LocalDate.now()) }
    var endDate by remember { mutableStateOf<LocalDate?>(null) }
    var notes by remember { mutableStateOf("") }
    val compounds = remember { mutableStateListOf<CompoundFormState>() }

    var showStartDatePicker by remember { mutableStateOf(false) }
    var showEndDatePicker by remember { mutableStateOf(false) }
    var showAddCompound by remember { mutableStateOf(false) }
    var nameError by remember { mutableStateOf<String?>(null) }

    val keyboardController = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current

    LaunchedEffect(Unit) {
        viewModel.clearCreateState()
        viewModel.events.collect { event ->
            when (event) {
                is ProtocolEvent.ProtocolCreated -> onSuccess()
                else -> {}
            }
        }
    }

    if (showStartDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showStartDatePicker = false },
            confirmButton = {
                TextButton(onClick = { showStartDatePicker = false }) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showStartDatePicker = false }) {
                    Text("Cancel")
                }
            }
        ) {
            val datePickerState = rememberDatePickerState(
                initialSelectedDateMillis = startDate.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
            )
            DatePicker(state = datePickerState)
            LaunchedEffect(datePickerState.selectedDateMillis) {
                datePickerState.selectedDateMillis?.let { millis ->
                    startDate = Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate()
                }
            }
        }
    }

    if (showEndDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showEndDatePicker = false },
            confirmButton = {
                TextButton(onClick = { showEndDatePicker = false }) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    endDate = null
                    showEndDatePicker = false
                }) {
                    Text("Clear")
                }
            }
        ) {
            val datePickerState = rememberDatePickerState(
                initialSelectedDateMillis = (endDate ?: startDate.plusMonths(3))
                    .atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
            )
            DatePicker(state = datePickerState)
            LaunchedEffect(datePickerState.selectedDateMillis) {
                datePickerState.selectedDateMillis?.let { millis ->
                    endDate = Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate()
                }
            }
        }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        "Create Protocol",
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
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .imePadding()
                .pointerInput(Unit) {
                    detectTapGestures(onTap = {
                        focusManager.clearFocus()
                        keyboardController?.hide()
                    })
                }
                .verticalScroll(rememberScrollState())
                .padding(Spacing.space4)
        ) {
            // Protocol Details Card
            PepCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(Spacing.space4)) {
                    Text(
                        text = "Protocol Details",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Spacer(modifier = Modifier.height(Spacing.space3))

                    PepTextField(
                        value = name,
                        onValueChange = {
                            name = it
                            nameError = null
                        },
                        label = "Protocol Name",
                        placeholder = "e.g., Retatrutide Titration",
                        error = nameError,
                        imeAction = ImeAction.Done,
                        onImeAction = { focusManager.clearFocus() },
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(modifier = Modifier.height(Spacing.space3))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(Spacing.space3)
                    ) {
                        DateField(
                            label = "Start Date",
                            value = startDate,
                            onClick = { showStartDatePicker = true },
                            modifier = Modifier.weight(1f)
                        )
                        DateField(
                            label = "End Date",
                            value = endDate,
                            placeholder = "Optional",
                            onClick = { showEndDatePicker = true },
                            modifier = Modifier.weight(1f)
                        )
                    }

                    Spacer(modifier = Modifier.height(Spacing.space3))

                    PepTextField(
                        value = notes,
                        onValueChange = { notes = it },
                        label = "Notes",
                        placeholder = "Optional notes about this protocol",
                        singleLine = false,
                        imeAction = ImeAction.Done,
                        onImeAction = { focusManager.clearFocus() },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            Spacer(modifier = Modifier.height(Spacing.space4))

            // Compounds Card
            PepCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(Spacing.space4)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Compounds",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        if (!showAddCompound && compounds.isEmpty()) {
                            TextButton(onClick = { showAddCompound = true }) {
                                Icon(
                                    Icons.Default.Add,
                                    contentDescription = null,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Add")
                            }
                        }
                    }

                    if (compounds.isEmpty() && !showAddCompound) {
                        Spacer(modifier = Modifier.height(Spacing.space3))
                        Text(
                            text = "Add at least one compound to your protocol",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    compounds.forEachIndexed { index, compound ->
                        Spacer(modifier = Modifier.height(Spacing.space3))
                        CompoundListItem(
                            compound = compound,
                            onRemove = { compounds.removeAt(index) }
                        )
                        if (index < compounds.lastIndex) {
                            HorizontalDivider(
                                modifier = Modifier.padding(vertical = Spacing.space2),
                                color = MaterialTheme.colorScheme.outlineVariant
                            )
                        }
                    }

                    if (showAddCompound) {
                        Spacer(modifier = Modifier.height(Spacing.space3))
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        Spacer(modifier = Modifier.height(Spacing.space3))
                        AddCompoundForm(
                            onAdd = { compound ->
                                compounds.add(compound)
                                showAddCompound = false
                            },
                            onCancel = { showAddCompound = false }
                        )
                    } else if (compounds.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(Spacing.space3))
                        PepButton(
                            text = "Add Another Compound",
                            onClick = { showAddCompound = true },
                            variant = PepButtonVariant.Secondary,
                            modifier = Modifier.fillMaxWidth(),
                            leadingIcon = Icons.Default.Add
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(Spacing.space6))

            // Error message
            if (createState.error != null) {
                Text(
                    text = createState.error!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(bottom = Spacing.space2)
                )
            }

            // Create Button
            PepButton(
                text = if (createState.isLoading) "Creating..." else "Create Protocol",
                onClick = {
                    if (name.isBlank()) {
                        nameError = "Protocol name is required"
                        return@PepButton
                    }
                    if (compounds.isEmpty()) {
                        return@PepButton
                    }

                    val compoundRequests = compounds.map { c ->
                        CompoundRequest(
                            name = c.name,
                            doseMg = c.doseMg.toDoubleOrNull() ?: 0.0,
                            doseUnit = c.doseUnit,
                            frequency = c.frequency,
                            administrationRoute = c.administrationRoute,
                            notes = c.notes.ifBlank { null }
                        )
                    }

                    viewModel.createProtocol(
                        name = name,
                        startDate = startDate.format(DateTimeFormatter.ISO_DATE),
                        endDate = endDate?.format(DateTimeFormatter.ISO_DATE),
                        compounds = compoundRequests,
                        notes = notes.ifBlank { null }
                    )
                },
                enabled = !createState.isLoading && name.isNotBlank() && compounds.isNotEmpty(),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(Spacing.space8))
        }
    }
}

@Composable
private fun DateField(
    label: String,
    value: LocalDate?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = ""
) {
    val displayFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy")

    Column(modifier = modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 4.dp)
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .clip(RoundedCornerShape(CornerRadius.sm))
                .background(MaterialTheme.colorScheme.surface)
                .clickable(onClick = onClick)
                .padding(horizontal = Spacing.space3),
            contentAlignment = Alignment.CenterStart
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = value?.format(displayFormatter) ?: placeholder,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (value != null)
                        MaterialTheme.colorScheme.onSurface
                    else
                        MaterialTheme.colorScheme.onSurfaceVariant
                )
                Icon(
                    Icons.Default.CalendarMonth,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}

@Composable
private fun CompoundListItem(
    compound: CompoundFormState,
    onRemove: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Science,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(Spacing.space2))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = compound.name,
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "${compound.doseMg} ${compound.doseUnit} · ${formatFrequencyShort(compound.frequency)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        IconButton(onClick = onRemove) {
            Icon(
                Icons.Default.Close,
                contentDescription = "Remove",
                tint = MaterialTheme.colorScheme.error
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddCompoundForm(
    onAdd: (CompoundFormState) -> Unit,
    onCancel: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    var doseMg by remember { mutableStateOf("") }
    var doseUnit by remember { mutableStateOf("mg") }
    var frequency by remember { mutableStateOf("weekly") }
    var route by remember { mutableStateOf("subcutaneous") }
    var notes by remember { mutableStateOf("") }

    var frequencyExpanded by remember { mutableStateOf(false) }
    var routeExpanded by remember { mutableStateOf(false) }
    var unitExpanded by remember { mutableStateOf(false) }

    val frequencies = listOf(
        "daily" to "Daily",
        "every_other_day" to "Every other day",
        "twice_weekly" to "Twice weekly",
        "weekly" to "Weekly",
        "every_10_days" to "Every 10 days",
        "biweekly" to "Biweekly",
        "monthly" to "Monthly"
    )

    val routes = listOf(
        "subcutaneous" to "Subcutaneous (SubQ)",
        "intramuscular" to "Intramuscular (IM)",
        "oral" to "Oral",
        "nasal" to "Nasal"
    )

    val units = listOf("mg", "mcg", "IU")

    Column {
        Text(
            text = "Add Compound",
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(modifier = Modifier.height(Spacing.space3))

        PepTextField(
            value = name,
            onValueChange = { name = it },
            label = "Compound Name",
            placeholder = "e.g., Retatrutide",
            imeAction = ImeAction.Next,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(Spacing.space3))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.space3)
        ) {
            PepTextField(
                value = doseMg,
                onValueChange = { doseMg = it.filter { c -> c.isDigit() || c == '.' } },
                label = "Dose",
                placeholder = "2.5",
                keyboardType = KeyboardType.Decimal,
                imeAction = ImeAction.Done,
                modifier = Modifier.weight(1f)
            )

            ExposedDropdownMenuBox(
                expanded = unitExpanded,
                onExpandedChange = { unitExpanded = it },
                modifier = Modifier.weight(0.7f)
            ) {
                OutlinedTextField(
                    value = doseUnit,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Unit") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = unitExpanded) },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outline
                    ),
                    modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable)
                )
                ExposedDropdownMenu(
                    expanded = unitExpanded,
                    onDismissRequest = { unitExpanded = false }
                ) {
                    units.forEach { unit ->
                        DropdownMenuItem(
                            text = { Text(unit) },
                            onClick = {
                                doseUnit = unit
                                unitExpanded = false
                            }
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.space3))

        ExposedDropdownMenuBox(
            expanded = frequencyExpanded,
            onExpandedChange = { frequencyExpanded = it },
            modifier = Modifier.fillMaxWidth()
        ) {
            OutlinedTextField(
                value = frequencies.find { it.first == frequency }?.second ?: frequency,
                onValueChange = {},
                readOnly = true,
                label = { Text("Frequency") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = frequencyExpanded) },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
            )
            ExposedDropdownMenu(
                expanded = frequencyExpanded,
                onDismissRequest = { frequencyExpanded = false }
            ) {
                frequencies.forEach { (value, label) ->
                    DropdownMenuItem(
                        text = { Text(label) },
                        onClick = {
                            frequency = value
                            frequencyExpanded = false
                        }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.space3))

        ExposedDropdownMenuBox(
            expanded = routeExpanded,
            onExpandedChange = { routeExpanded = it },
            modifier = Modifier.fillMaxWidth()
        ) {
            OutlinedTextField(
                value = routes.find { it.first == route }?.second ?: route,
                onValueChange = {},
                readOnly = true,
                label = { Text("Administration Route") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = routeExpanded) },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.primary,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
            )
            ExposedDropdownMenu(
                expanded = routeExpanded,
                onDismissRequest = { routeExpanded = false }
            ) {
                routes.forEach { (value, label) ->
                    DropdownMenuItem(
                        text = { Text(label) },
                        onClick = {
                            route = value
                            routeExpanded = false
                        }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.space3))

        PepTextField(
            value = notes,
            onValueChange = { notes = it },
            label = "Notes",
            placeholder = "Optional notes",
            imeAction = ImeAction.Done,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(Spacing.space4))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.space3)
        ) {
            PepButton(
                text = "Cancel",
                onClick = onCancel,
                variant = PepButtonVariant.Secondary,
                modifier = Modifier.weight(1f)
            )
            PepButton(
                text = "Add",
                onClick = {
                    if (name.isNotBlank() && doseMg.isNotBlank()) {
                        onAdd(
                            CompoundFormState(
                                name = name,
                                doseMg = doseMg,
                                doseUnit = doseUnit,
                                frequency = frequency,
                                administrationRoute = route,
                                notes = notes
                            )
                        )
                    }
                },
                enabled = name.isNotBlank() && doseMg.isNotBlank(),
                modifier = Modifier.weight(1f)
            )
        }
    }
}

private fun formatFrequencyShort(frequency: String): String {
    return when (frequency.lowercase()) {
        "daily" -> "Daily"
        "every_other_day" -> "EOD"
        "twice_weekly" -> "2x/week"
        "weekly" -> "Weekly"
        "every_10_days" -> "Every 10d"
        "biweekly" -> "Biweekly"
        "monthly" -> "Monthly"
        else -> frequency
    }
}

@Preview(showBackground = true)
@Composable
private fun CreateProtocolScreenPreview() {
    PeppyTheme {
        Box(
            modifier = Modifier.background(MaterialTheme.colorScheme.background)
        ) {
            CreateProtocolScreen()
        }
    }
}
