package com.peppy.app.features.checkin.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.peppy.app.core.di.Dependencies
import com.peppy.app.core.network.ApiClient
import com.peppy.app.core.network.ApiResult
import com.peppy.app.core.network.CheckinCreateRequest
import com.peppy.app.core.network.CheckinResponse
import com.peppy.app.core.network.CheckinUpdateRequest
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate

data class CheckinState(
    val today: CheckinResponse? = null,
    val recent: List<CheckinResponse> = emptyList(),
    val rangeDays: Int? = 30,
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null
)

sealed class CheckinEvent {
    data object Saved : CheckinEvent()
    data class Error(val message: String) : CheckinEvent()
}

class CheckinViewModel(
    private val apiClient: ApiClient = Dependencies.get().apiClient
) : ViewModel() {

    private val _state = MutableStateFlow(CheckinState())
    val state: StateFlow<CheckinState> = _state.asStateFlow()

    private val _events = MutableSharedFlow<CheckinEvent>()
    val events: SharedFlow<CheckinEvent> = _events.asSharedFlow()

    fun loadCheckins(rangeDays: Int? = _state.value.rangeDays) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isLoading = true, rangeDays = rangeDays, error = null)

            val todayDate = LocalDate.now()
            val startDate = rangeDays?.let { todayDate.minusDays((it - 1).toLong()).toString() }
            val endDate = rangeDays?.let { todayDate.toString() }
            val recentResult = apiClient.execute {
                apiClient.service.getCheckins(
                    startDate = startDate,
                    endDate = endDate,
                    limit = if (rangeDays == null) 100 else rangeDays.coerceAtLeast(14)
                )
            }

            when (recentResult) {
                is ApiResult.Success -> {
                    val today = recentResult.data.firstOrNull { it.date == todayDate.toString() }
                    _state.value = _state.value.copy(
                        today = today,
                        recent = recentResult.data,
                        isLoading = false,
                        error = null
                    )
                }
                is ApiResult.Error -> {
                    _state.value = _state.value.copy(
                        isLoading = false,
                        error = recentResult.message
                    )
                }
                is ApiResult.Exception -> {
                    _state.value = _state.value.copy(
                        isLoading = false,
                        error = recentResult.throwable.message ?: "Unable to load check-ins"
                    )
                }
            }
        }
    }

    fun saveCheckin(request: CheckinCreateRequest) {
        viewModelScope.launch {
            _state.value = _state.value.copy(isSaving = true, error = null)

            val existing = _state.value.today
            val result = if (existing == null) {
                apiClient.execute { apiClient.service.createCheckin(request) }
            } else {
                apiClient.execute {
                    apiClient.service.updateCheckin(
                        existing.id,
                        CheckinUpdateRequest(
                            date = request.date,
                            weightKg = request.weightKg,
                            energyLevel = request.energyLevel,
                            sleepQuality = request.sleepQuality,
                            appetiteLevel = request.appetiteLevel,
                            mood = request.mood,
                            nausea = request.nausea,
                            injectionSiteReaction = request.injectionSiteReaction,
                            fatigue = request.fatigue,
                            headache = request.headache,
                            giIssues = request.giIssues,
                            notes = request.notes
                        )
                    )
                }
            }

            when (result) {
                is ApiResult.Success -> {
                    _state.value = _state.value.copy(isSaving = false, today = result.data)
                    loadCheckins()
                    _events.emit(CheckinEvent.Saved)
                }
                is ApiResult.Error -> {
                    _state.value = _state.value.copy(isSaving = false, error = result.message)
                    _events.emit(CheckinEvent.Error(result.message))
                }
                is ApiResult.Exception -> {
                    val message = result.throwable.message ?: "Unable to save check-in"
                    _state.value = _state.value.copy(isSaving = false, error = message)
                    _events.emit(CheckinEvent.Error(message))
                }
            }
        }
    }
}
