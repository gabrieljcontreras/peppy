package com.peppy.app.features.onboarding.viewmodel

import androidx.lifecycle.ViewModel
import com.peppy.app.core.di.Dependencies
import com.peppy.app.core.storage.HeightUnit
import com.peppy.app.core.storage.WeightUnit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

data class OnboardingUiState(
    val currentStep: Int = 0,
    val totalSteps: Int = 7,
    val age: String = "",
    val heightFeet: String = "",
    val heightInches: String = "",
    val heightCm: String = "",
    val heightUnit: HeightUnit = HeightUnit.FT_IN,
    val weight: String = "",
    val weightUnit: WeightUnit = WeightUnit.LBS,
    val selectedPeptides: List<String> = emptyList(),
    val peptideSearchQuery: String = "",
    val otherMedications: String = "",
    val workoutDays: Int? = null,
    val selectedGoals: List<String> = emptyList(),
    val goalsOther: String = ""
)

class OnboardingViewModel : ViewModel() {

    private val storage = Dependencies.get().onboardingStorage

    private val _uiState = MutableStateFlow(OnboardingUiState())
    val uiState: StateFlow<OnboardingUiState> = _uiState.asStateFlow()

    fun nextStep() {
        _uiState.update { it.copy(currentStep = (it.currentStep + 1).coerceAtMost(it.totalSteps - 1)) }
    }

    fun previousStep() {
        _uiState.update { it.copy(currentStep = (it.currentStep - 1).coerceAtLeast(0)) }
    }

    fun skipStep() {
        nextStep()
    }

    fun updateAge(value: String) {
        if (value.length <= 3 && value.all { it.isDigit() }) {
            _uiState.update { it.copy(age = value) }
        }
    }

    fun updateHeightUnit(unit: HeightUnit) {
        _uiState.update { it.copy(heightUnit = unit) }
    }

    fun updateHeightFeet(value: String) {
        if (value.length <= 1 && value.all { it.isDigit() }) {
            _uiState.update { it.copy(heightFeet = value) }
        }
    }

    fun updateHeightInches(value: String) {
        if (value.length <= 2 && value.all { it.isDigit() }) {
            val inches = value.toIntOrNull()
            if (inches == null || inches < 12) {
                _uiState.update { it.copy(heightInches = value) }
            }
        }
    }

    fun updateHeightCm(value: String) {
        if (value.length <= 3 && value.all { it.isDigit() }) {
            _uiState.update { it.copy(heightCm = value) }
        }
    }

    fun updateWeightUnit(unit: WeightUnit) {
        _uiState.update { it.copy(weightUnit = unit) }
    }

    fun updateWeight(value: String) {
        if (value.length <= 5 && value.all { it.isDigit() || it == '.' } && value.count { it == '.' } <= 1) {
            _uiState.update { it.copy(weight = value) }
        }
    }

    fun updatePeptideSearch(query: String) {
        _uiState.update { it.copy(peptideSearchQuery = query) }
    }

    fun addPeptide(name: String) {
        _uiState.update {
            if (name.isNotBlank() && name !in it.selectedPeptides) {
                it.copy(
                    selectedPeptides = it.selectedPeptides + name,
                    peptideSearchQuery = ""
                )
            } else it
        }
    }

    fun removePeptide(name: String) {
        _uiState.update { it.copy(selectedPeptides = it.selectedPeptides - name) }
    }

    fun updateMedications(value: String) {
        _uiState.update { it.copy(otherMedications = value) }
    }

    fun updateWorkoutDays(days: Int) {
        _uiState.update { it.copy(workoutDays = days) }
    }

    fun toggleGoal(goal: String) {
        _uiState.update {
            val updated = if (goal in it.selectedGoals) it.selectedGoals - goal else it.selectedGoals + goal
            it.copy(selectedGoals = updated)
        }
    }

    fun updateGoalsOther(value: String) {
        _uiState.update { it.copy(goalsOther = value) }
    }

    fun completeOnboarding() {
        val state = _uiState.value

        state.age.toIntOrNull()?.let { storage.age = it }

        storage.heightUnit = state.heightUnit
        when (state.heightUnit) {
            HeightUnit.FT_IN -> {
                val feet = state.heightFeet.toIntOrNull() ?: 0
                val inches = state.heightInches.toIntOrNull() ?: 0
                if (feet > 0 || inches > 0) {
                    storage.heightCm = (feet * 30.48) + (inches * 2.54)
                }
            }
            HeightUnit.CM -> {
                state.heightCm.toDoubleOrNull()?.let { storage.heightCm = it }
            }
        }

        storage.weightUnit = state.weightUnit
        state.weight.toDoubleOrNull()?.let { raw ->
            storage.weightKg = when (state.weightUnit) {
                WeightUnit.LBS -> raw * 0.453592
                WeightUnit.KG -> raw
            }
        }

        storage.selectedPeptides = state.selectedPeptides
        if (state.otherMedications.isNotBlank()) storage.otherMedications = state.otherMedications
        state.workoutDays?.let { storage.workoutDaysPerWeek = it }
        storage.goals = state.selectedGoals
        if (state.goalsOther.isNotBlank()) storage.goalsOther = state.goalsOther

        storage.isOnboardingComplete = true
    }

    val isLastStep: Boolean
        get() = _uiState.value.currentStep == _uiState.value.totalSteps - 1

    val isFirstStep: Boolean
        get() = _uiState.value.currentStep == 0
}
