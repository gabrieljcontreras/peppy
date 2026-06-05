package com.peppy.app.features.onboarding.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.peppy.app.design.components.PepButton
import com.peppy.app.design.components.PepButtonVariant
import com.peppy.app.features.onboarding.ui.components.OnboardingProgressBar
import com.peppy.app.features.onboarding.ui.steps.AgeStep
import com.peppy.app.features.onboarding.ui.steps.GoalsStep
import com.peppy.app.features.onboarding.ui.steps.HeightStep
import com.peppy.app.features.onboarding.ui.steps.MedicationsStep
import com.peppy.app.features.onboarding.ui.steps.PeptidesStep
import com.peppy.app.features.onboarding.ui.steps.WeightStep
import com.peppy.app.features.onboarding.ui.steps.WorkoutStep
import com.peppy.app.features.onboarding.viewmodel.OnboardingViewModel
import com.peppy.app.ui.motion.PeppyMotion
import com.peppy.app.ui.theme.Spacing

@Composable
fun OnboardingScreen(
    viewModel: OnboardingViewModel,
    onComplete: () -> Unit
) {
    val state by viewModel.uiState.collectAsState()
    var previousStep by remember { mutableIntStateOf(0) }
    val isForward = state.currentStep >= previousStep

    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = Spacing.space5)
    ) {
        Spacer(modifier = Modifier.height(Spacing.md))

        OnboardingProgressBar(
            currentStep = state.currentStep,
            totalSteps = state.totalSteps
        )

        Spacer(modifier = Modifier.height(Spacing.xl))

        AnimatedContent(
            targetState = state.currentStep,
            transitionSpec = {
                if (isForward) {
                    slideInHorizontally(
                        initialOffsetX = { it },
                        animationSpec = PeppyMotion.normalTween()
                    ) togetherWith slideOutHorizontally(
                        targetOffsetX = { -it },
                        animationSpec = PeppyMotion.normalTween()
                    )
                } else {
                    slideInHorizontally(
                        initialOffsetX = { -it },
                        animationSpec = PeppyMotion.normalTween()
                    ) togetherWith slideOutHorizontally(
                        targetOffsetX = { it },
                        animationSpec = PeppyMotion.normalTween()
                    )
                }
            },
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            label = "OnboardingStep"
        ) { step ->
            val scrollState = rememberScrollState()
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(scrollState)
            ) {
                when (step) {
                    0 -> AgeStep(
                        age = state.age,
                        onAgeChange = viewModel::updateAge
                    )
                    1 -> HeightStep(
                        heightUnit = state.heightUnit,
                        heightFeet = state.heightFeet,
                        heightInches = state.heightInches,
                        heightCm = state.heightCm,
                        onUnitChange = viewModel::updateHeightUnit,
                        onFeetChange = viewModel::updateHeightFeet,
                        onInchesChange = viewModel::updateHeightInches,
                        onCmChange = viewModel::updateHeightCm
                    )
                    2 -> WeightStep(
                        weight = state.weight,
                        weightUnit = state.weightUnit,
                        onWeightChange = viewModel::updateWeight,
                        onUnitChange = viewModel::updateWeightUnit
                    )
                    3 -> PeptidesStep(
                        selectedPeptides = state.selectedPeptides,
                        searchQuery = state.peptideSearchQuery,
                        onSearchChange = viewModel::updatePeptideSearch,
                        onAddPeptide = viewModel::addPeptide,
                        onRemovePeptide = viewModel::removePeptide
                    )
                    4 -> MedicationsStep(
                        medications = state.otherMedications,
                        onMedicationsChange = viewModel::updateMedications
                    )
                    5 -> WorkoutStep(
                        workoutDays = state.workoutDays,
                        onDaysChange = viewModel::updateWorkoutDays
                    )
                    6 -> GoalsStep(
                        selectedGoals = state.selectedGoals,
                        goalsOther = state.goalsOther,
                        onToggleGoal = viewModel::toggleGoal,
                        onOtherChange = viewModel::updateGoalsOther
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(Spacing.md))

        Row(modifier = Modifier.fillMaxWidth()) {
            if (!viewModel.isFirstStep) {
                PepButton(
                    text = "Back",
                    onClick = {
                        previousStep = state.currentStep
                        viewModel.previousStep()
                    },
                    variant = PepButtonVariant.Secondary,
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.width(Spacing.sm))
            }

            PepButton(
                text = if (viewModel.isLastStep) "Get started" else "Continue",
                onClick = {
                    previousStep = state.currentStep
                    if (viewModel.isLastStep) {
                        viewModel.completeOnboarding()
                        onComplete()
                    } else {
                        viewModel.nextStep()
                    }
                },
                modifier = Modifier.weight(1f)
            )
        }

        Spacer(modifier = Modifier.height(Spacing.xs))

        PepButton(
            text = "Skip this step",
            onClick = {
                previousStep = state.currentStep
                if (viewModel.isLastStep) {
                    viewModel.completeOnboarding()
                    onComplete()
                } else {
                    viewModel.skipStep()
                }
            },
            variant = PepButtonVariant.Tertiary,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(Spacing.md))
    }
}
