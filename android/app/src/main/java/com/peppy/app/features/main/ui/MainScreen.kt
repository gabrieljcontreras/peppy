package com.peppy.app.features.main.ui

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Science
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.AddCircleOutline
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.Science
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.lifecycle.viewmodel.compose.viewModel
import com.peppy.app.design.components.PepTabBar
import com.peppy.app.design.components.PepTabItem
import com.peppy.app.features.checkin.ui.CheckinScreen
import com.peppy.app.features.checkin.viewmodel.CheckinViewModel
import com.peppy.app.features.protocols.ui.ProtocolListScreen
import com.peppy.app.features.protocols.viewmodel.ProtocolViewModel
import com.peppy.app.features.settings.ui.SettingsScreen
import com.peppy.app.ui.motion.PeppyMotion
import com.peppy.app.ui.theme.PeppyTheme

val tabs = listOf(
    PepTabItem("Home", Icons.Filled.Home, Icons.Outlined.Home),
    PepTabItem("Check-in", Icons.Filled.AddCircle, Icons.Outlined.AddCircleOutline),
    PepTabItem("Protocols", Icons.Filled.Science, Icons.Outlined.Science),
    PepTabItem("Insights", Icons.Filled.Lightbulb, Icons.Outlined.Lightbulb),
    PepTabItem("Settings", Icons.Filled.Settings, Icons.Outlined.Settings)
)

@Composable
fun MainScreen(
    onLogoutClick: () -> Unit = {},
    onProtocolClick: (String) -> Unit = {},
    onCreateProtocolClick: () -> Unit = {}
) {
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }
    val protocolViewModel: ProtocolViewModel = viewModel()
    val checkinViewModel: CheckinViewModel = viewModel()

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            PepTabBar(
                tabs = tabs,
                selectedIndex = selectedTab,
                onTabSelected = { selectedTab = it }
            )
        }
    ) { paddingValues ->
        Crossfade(
            targetState = selectedTab,
            animationSpec = tween(PeppyMotion.NORMAL, easing = PeppyMotion.EaseOut),
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .background(MaterialTheme.colorScheme.background),
            label = "TabContent"
        ) { tab ->
            when (tab) {
                1 -> CheckinScreen(viewModel = checkinViewModel)
                2 -> ProtocolListScreen(
                    viewModel = protocolViewModel,
                    onProtocolClick = onProtocolClick,
                    onCreateClick = onCreateProtocolClick
                )
                4 -> SettingsScreen(onLogoutClick = onLogoutClick)
                else -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = tabs[tab].label,
                            style = MaterialTheme.typography.headlineMedium,
                            color = MaterialTheme.colorScheme.onBackground
                        )
                    }
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun MainScreenPreview() {
    PeppyTheme {
        MainScreen()
    }
}
