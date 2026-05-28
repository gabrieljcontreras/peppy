package com.peppy.app.features.protocols.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.peppy.app.core.di.Dependencies
import com.peppy.app.core.network.ApiClient
import com.peppy.app.core.network.ApiResult
import com.peppy.app.core.network.CompoundRequest
import com.peppy.app.core.network.ProtocolCreateRequest
import com.peppy.app.core.network.ProtocolResponse
import com.peppy.app.core.network.CompoundsReplaceRequest
import com.peppy.app.core.network.ProtocolUpdateRequest
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ProtocolListState(
    val protocols: List<ProtocolResponse> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

data class ProtocolDetailState(
    val protocol: ProtocolResponse? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

data class CreateProtocolState(
    val isLoading: Boolean = false,
    val error: String? = null
)

sealed class ProtocolEvent {
    data object ProtocolCreated : ProtocolEvent()
    data object ProtocolUpdated : ProtocolEvent()
    data object ProtocolDeleted : ProtocolEvent()
    data class Error(val message: String) : ProtocolEvent()
}

class ProtocolViewModel(
    private val apiClient: ApiClient = Dependencies.get().apiClient
) : ViewModel() {

    private val _listState = MutableStateFlow(ProtocolListState())
    val listState: StateFlow<ProtocolListState> = _listState.asStateFlow()

    private val _detailState = MutableStateFlow(ProtocolDetailState())
    val detailState: StateFlow<ProtocolDetailState> = _detailState.asStateFlow()

    private val _createState = MutableStateFlow(CreateProtocolState())
    val createState: StateFlow<CreateProtocolState> = _createState.asStateFlow()

    private val _events = MutableSharedFlow<ProtocolEvent>()
    val events: SharedFlow<ProtocolEvent> = _events.asSharedFlow()

    fun loadProtocols(includeInactive: Boolean = true) {
        viewModelScope.launch {
            _listState.value = _listState.value.copy(isLoading = true, error = null)

            when (val result = apiClient.execute {
                apiClient.service.getProtocols(includeInactive = includeInactive)
            }) {
                is ApiResult.Success -> {
                    _listState.value = _listState.value.copy(
                        protocols = result.data,
                        isLoading = false
                    )
                }
                is ApiResult.Error -> {
                    _listState.value = _listState.value.copy(
                        isLoading = false,
                        error = result.message
                    )
                }
                is ApiResult.Exception -> {
                    _listState.value = _listState.value.copy(
                        isLoading = false,
                        error = result.throwable.message ?: "Unknown error"
                    )
                }
            }
        }
    }

    fun loadProtocol(id: String) {
        viewModelScope.launch {
            _detailState.value = _detailState.value.copy(isLoading = true, error = null)

            when (val result = apiClient.execute {
                apiClient.service.getProtocol(id)
            }) {
                is ApiResult.Success -> {
                    _detailState.value = _detailState.value.copy(
                        protocol = result.data,
                        isLoading = false
                    )
                }
                is ApiResult.Error -> {
                    _detailState.value = _detailState.value.copy(
                        isLoading = false,
                        error = result.message
                    )
                }
                is ApiResult.Exception -> {
                    _detailState.value = _detailState.value.copy(
                        isLoading = false,
                        error = result.throwable.message ?: "Unknown error"
                    )
                }
            }
        }
    }

    fun createProtocol(
        name: String,
        startDate: String,
        endDate: String? = null,
        compounds: List<CompoundRequest>,
        notes: String? = null
    ) {
        viewModelScope.launch {
            _createState.value = _createState.value.copy(isLoading = true, error = null)

            val request = ProtocolCreateRequest(
                name = name,
                startDate = startDate,
                endDate = endDate,
                compounds = compounds,
                notes = notes
            )

            when (val result = apiClient.execute {
                apiClient.service.createProtocol(request)
            }) {
                is ApiResult.Success -> {
                    _createState.value = _createState.value.copy(isLoading = false)
                    _events.emit(ProtocolEvent.ProtocolCreated)
                }
                is ApiResult.Error -> {
                    _createState.value = _createState.value.copy(
                        isLoading = false,
                        error = result.message
                    )
                    _events.emit(ProtocolEvent.Error(result.message))
                }
                is ApiResult.Exception -> {
                    val message = result.throwable.message ?: "Unknown error"
                    _createState.value = _createState.value.copy(
                        isLoading = false,
                        error = message
                    )
                    _events.emit(ProtocolEvent.Error(message))
                }
            }
        }
    }

    fun updateProtocol(
        id: String,
        name: String? = null,
        startDate: String? = null,
        endDate: String? = null,
        notes: String? = null,
        isActive: Boolean? = null
    ) {
        viewModelScope.launch {
            _createState.value = _createState.value.copy(isLoading = true, error = null)

            val request = ProtocolUpdateRequest(
                name = name,
                startDate = startDate,
                endDate = endDate,
                notes = notes,
                isActive = isActive
            )

            when (val result = apiClient.execute {
                apiClient.service.updateProtocol(id, request)
            }) {
                is ApiResult.Success -> {
                    _createState.value = _createState.value.copy(isLoading = false)
                    _detailState.value = _detailState.value.copy(protocol = result.data)
                    _events.emit(ProtocolEvent.ProtocolUpdated)
                }
                is ApiResult.Error -> {
                    _createState.value = _createState.value.copy(
                        isLoading = false,
                        error = result.message
                    )
                    _events.emit(ProtocolEvent.Error(result.message))
                }
                is ApiResult.Exception -> {
                    val message = result.throwable.message ?: "Unknown error"
                    _createState.value = _createState.value.copy(
                        isLoading = false,
                        error = message
                    )
                    _events.emit(ProtocolEvent.Error(message))
                }
            }
        }
    }

    fun updateProtocolFull(
        id: String,
        name: String,
        startDate: String,
        endDate: String?,
        compounds: List<CompoundRequest>,
        notes: String?
    ) {
        viewModelScope.launch {
            _createState.value = _createState.value.copy(isLoading = true, error = null)

            // First update the metadata
            val metadataRequest = ProtocolUpdateRequest(
                name = name,
                startDate = startDate,
                endDate = endDate,
                notes = notes
            )

            when (val metadataResult = apiClient.execute {
                apiClient.service.updateProtocol(id, metadataRequest)
            }) {
                is ApiResult.Success -> {
                    // Then replace compounds
                    val compoundsRequest = CompoundsReplaceRequest(compounds = compounds)
                    when (val compoundsResult = apiClient.execute {
                        apiClient.service.replaceCompounds(id, compoundsRequest)
                    }) {
                        is ApiResult.Success -> {
                            _createState.value = _createState.value.copy(isLoading = false)
                            _detailState.value = _detailState.value.copy(protocol = compoundsResult.data)
                            _events.emit(ProtocolEvent.ProtocolUpdated)
                        }
                        is ApiResult.Error -> {
                            _createState.value = _createState.value.copy(
                                isLoading = false,
                                error = compoundsResult.message
                            )
                            _events.emit(ProtocolEvent.Error(compoundsResult.message))
                        }
                        is ApiResult.Exception -> {
                            val message = compoundsResult.throwable.message ?: "Unknown error"
                            _createState.value = _createState.value.copy(
                                isLoading = false,
                                error = message
                            )
                            _events.emit(ProtocolEvent.Error(message))
                        }
                    }
                }
                is ApiResult.Error -> {
                    _createState.value = _createState.value.copy(
                        isLoading = false,
                        error = metadataResult.message
                    )
                    _events.emit(ProtocolEvent.Error(metadataResult.message))
                }
                is ApiResult.Exception -> {
                    val message = metadataResult.throwable.message ?: "Unknown error"
                    _createState.value = _createState.value.copy(
                        isLoading = false,
                        error = message
                    )
                    _events.emit(ProtocolEvent.Error(message))
                }
            }
        }
    }

    fun deleteProtocol(id: String) {
        viewModelScope.launch {
            _createState.value = _createState.value.copy(isLoading = true, error = null)

            when (val result = apiClient.execute {
                apiClient.service.deleteProtocol(id)
            }) {
                is ApiResult.Success -> {
                    _createState.value = _createState.value.copy(isLoading = false)
                    _events.emit(ProtocolEvent.ProtocolDeleted)
                }
                is ApiResult.Error -> {
                    _createState.value = _createState.value.copy(
                        isLoading = false,
                        error = result.message
                    )
                    _events.emit(ProtocolEvent.Error(result.message))
                }
                is ApiResult.Exception -> {
                    val message = result.throwable.message ?: "Unknown error"
                    _createState.value = _createState.value.copy(
                        isLoading = false,
                        error = message
                    )
                    _events.emit(ProtocolEvent.Error(message))
                }
            }
        }
    }

    fun activateProtocol(id: String) {
        viewModelScope.launch {
            val request = ProtocolUpdateRequest(isActive = true)
            when (val result = apiClient.execute {
                apiClient.service.updateProtocol(id, request)
            }) {
                is ApiResult.Success -> {
                    _detailState.value = _detailState.value.copy(protocol = result.data)
                    loadProtocols()
                }
                is ApiResult.Error -> {
                    _events.emit(ProtocolEvent.Error(result.message))
                }
                is ApiResult.Exception -> {
                    _events.emit(ProtocolEvent.Error(result.throwable.message ?: "Unknown error"))
                }
            }
        }
    }

    fun deactivateProtocol(id: String) {
        viewModelScope.launch {
            when (val result = apiClient.execute {
                apiClient.service.deactivateProtocol(id)
            }) {
                is ApiResult.Success -> {
                    _detailState.value = _detailState.value.copy(protocol = result.data)
                    loadProtocols()
                }
                is ApiResult.Error -> {
                    _events.emit(ProtocolEvent.Error(result.message))
                }
                is ApiResult.Exception -> {
                    _events.emit(ProtocolEvent.Error(result.throwable.message ?: "Unknown error"))
                }
            }
        }
    }

    fun clearDetailState() {
        _detailState.value = ProtocolDetailState()
    }

    fun clearCreateState() {
        _createState.value = CreateProtocolState()
    }
}
