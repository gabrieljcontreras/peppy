package com.peppy.app.core.storage

import android.content.Context
import android.content.SharedPreferences

enum class HeightUnit { CM, FT_IN }
enum class WeightUnit { KG, LBS }

interface OnboardingStorage {
    var isOnboardingComplete: Boolean
    var age: Int?
    var heightCm: Double?
    var heightUnit: HeightUnit
    var weightKg: Double?
    var weightUnit: WeightUnit
    var selectedPeptides: List<String>
    var customPeptides: List<String>
    var otherMedications: String?
    var workoutDaysPerWeek: Int?
    var goals: List<String>
    var goalsOther: String?
    fun clear()
}

class OnboardingStorageImpl(context: Context) : OnboardingStorage {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override var isOnboardingComplete: Boolean
        get() = prefs.getBoolean(KEY_COMPLETE, false)
        set(value) = prefs.edit().putBoolean(KEY_COMPLETE, value).apply()

    override var age: Int?
        get() = if (prefs.contains(KEY_AGE)) prefs.getInt(KEY_AGE, 0) else null
        set(value) {
            if (value != null) prefs.edit().putInt(KEY_AGE, value).apply()
            else prefs.edit().remove(KEY_AGE).apply()
        }

    override var heightCm: Double?
        get() = if (prefs.contains(KEY_HEIGHT_CM)) prefs.getFloat(KEY_HEIGHT_CM, 0f).toDouble() else null
        set(value) {
            if (value != null) prefs.edit().putFloat(KEY_HEIGHT_CM, value.toFloat()).apply()
            else prefs.edit().remove(KEY_HEIGHT_CM).apply()
        }

    override var heightUnit: HeightUnit
        get() = HeightUnit.entries.firstOrNull { it.name == prefs.getString(KEY_HEIGHT_UNIT, null) } ?: HeightUnit.FT_IN
        set(value) = prefs.edit().putString(KEY_HEIGHT_UNIT, value.name).apply()

    override var weightKg: Double?
        get() = if (prefs.contains(KEY_WEIGHT_KG)) prefs.getFloat(KEY_WEIGHT_KG, 0f).toDouble() else null
        set(value) {
            if (value != null) prefs.edit().putFloat(KEY_WEIGHT_KG, value.toFloat()).apply()
            else prefs.edit().remove(KEY_WEIGHT_KG).apply()
        }

    override var weightUnit: WeightUnit
        get() = WeightUnit.entries.firstOrNull { it.name == prefs.getString(KEY_WEIGHT_UNIT, null) } ?: WeightUnit.LBS
        set(value) = prefs.edit().putString(KEY_WEIGHT_UNIT, value.name).apply()

    override var selectedPeptides: List<String>
        get() = prefs.getString(KEY_PEPTIDES, null)?.split(DELIMITER)?.filter { it.isNotBlank() } ?: emptyList()
        set(value) = prefs.edit().putString(KEY_PEPTIDES, value.joinToString(DELIMITER)).apply()

    override var customPeptides: List<String>
        get() = prefs.getString(KEY_CUSTOM_PEPTIDES, null)?.split(DELIMITER)?.filter { it.isNotBlank() } ?: emptyList()
        set(value) = prefs.edit().putString(KEY_CUSTOM_PEPTIDES, value.joinToString(DELIMITER)).apply()

    override var otherMedications: String?
        get() = prefs.getString(KEY_MEDICATIONS, null)
        set(value) {
            if (value != null) prefs.edit().putString(KEY_MEDICATIONS, value).apply()
            else prefs.edit().remove(KEY_MEDICATIONS).apply()
        }

    override var workoutDaysPerWeek: Int?
        get() = if (prefs.contains(KEY_WORKOUT_DAYS)) prefs.getInt(KEY_WORKOUT_DAYS, 0) else null
        set(value) {
            if (value != null) prefs.edit().putInt(KEY_WORKOUT_DAYS, value).apply()
            else prefs.edit().remove(KEY_WORKOUT_DAYS).apply()
        }

    override var goals: List<String>
        get() = prefs.getString(KEY_GOALS, null)?.split(DELIMITER)?.filter { it.isNotBlank() } ?: emptyList()
        set(value) = prefs.edit().putString(KEY_GOALS, value.joinToString(DELIMITER)).apply()

    override var goalsOther: String?
        get() = prefs.getString(KEY_GOALS_OTHER, null)
        set(value) {
            if (value != null) prefs.edit().putString(KEY_GOALS_OTHER, value).apply()
            else prefs.edit().remove(KEY_GOALS_OTHER).apply()
        }

    override fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val PREFS_NAME = "peppy_onboarding"
        private const val DELIMITER = "|||"
        private const val KEY_COMPLETE = "onboarding_complete"
        private const val KEY_AGE = "age"
        private const val KEY_HEIGHT_CM = "height_cm"
        private const val KEY_HEIGHT_UNIT = "height_unit"
        private const val KEY_WEIGHT_KG = "weight_kg"
        private const val KEY_WEIGHT_UNIT = "weight_unit"
        private const val KEY_PEPTIDES = "selected_peptides"
        private const val KEY_CUSTOM_PEPTIDES = "custom_peptides"
        private const val KEY_MEDICATIONS = "other_medications"
        private const val KEY_WORKOUT_DAYS = "workout_days_per_week"
        private const val KEY_GOALS = "goals"
        private const val KEY_GOALS_OTHER = "goals_other"
    }
}
