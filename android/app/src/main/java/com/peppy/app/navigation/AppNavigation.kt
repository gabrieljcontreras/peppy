package com.peppy.app.navigation

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.ui.unit.IntOffset
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.peppy.app.core.di.Dependencies
import com.peppy.app.core.state.AppState
import com.peppy.app.core.state.AuthState
import com.peppy.app.features.auth.ui.LoginScreen
import com.peppy.app.features.auth.ui.RegisterScreen
import com.peppy.app.features.auth.ui.WelcomeScreen
import com.peppy.app.features.auth.viewmodel.AuthEvent
import com.peppy.app.features.auth.viewmodel.AuthViewModel
import com.peppy.app.features.main.ui.MainScreen
import com.peppy.app.features.onboarding.ui.OnboardingScreen
import com.peppy.app.features.onboarding.viewmodel.OnboardingViewModel
import com.peppy.app.features.protocols.ui.CreateProtocolScreen
import com.peppy.app.features.protocols.ui.ProtocolDetailScreen
import com.peppy.app.features.protocols.viewmodel.ProtocolViewModel
import com.peppy.app.ui.motion.PeppyMotion
import kotlinx.coroutines.flow.collectLatest

@Composable
fun AppNavigation(appState: AppState) {
    val navController = rememberNavController()
    val authState by appState.authState.collectAsState()

    val authViewModel = remember { AuthViewModel(appState) }
    val authUiState by authViewModel.uiState.collectAsState()

    val onboardingStorage = remember { Dependencies.get().onboardingStorage }

    LaunchedEffect(Unit) {
        authViewModel.events.collectLatest { event ->
            when (event) {
                is AuthEvent.NavigateToMain -> {
                    navController.navigate(Routes.MAIN) {
                        popUpTo(Routes.WELCOME) { inclusive = true }
                    }
                }
                is AuthEvent.NavigateBack -> {
                    navController.popBackStack()
                }
                is AuthEvent.NavigateToWelcome -> {
                    navController.navigate(Routes.WELCOME) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            }
        }
    }

    val startDestination = when {
        !onboardingStorage.isOnboardingComplete -> Routes.ONBOARDING
        authState is AuthState.Authenticated -> Routes.MAIN
        else -> Routes.WELCOME
    }

    val slideSpec = tween<IntOffset>(PeppyMotion.NORMAL, easing = PeppyMotion.EaseOut)
    val fadeSpec = tween<Float>(PeppyMotion.NORMAL, easing = PeppyMotion.EaseOut)

    NavHost(
        navController = navController,
        startDestination = startDestination
    ) {
        composable(
            route = Routes.ONBOARDING,
            exitTransition = { fadeOut(fadeSpec) }
        ) {
            val onboardingViewModel: OnboardingViewModel = viewModel()
            OnboardingScreen(
                viewModel = onboardingViewModel,
                onComplete = {
                    navController.navigate(Routes.WELCOME) {
                        popUpTo(Routes.ONBOARDING) { inclusive = true }
                    }
                }
            )
        }

        composable(
            route = Routes.WELCOME,
            enterTransition = { fadeIn(fadeSpec) },
            exitTransition = {
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.Start, slideSpec)
            },
            popEnterTransition = {
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.End, slideSpec)
            }
        ) {
            WelcomeScreen(
                onSignUpClick = {
                    authViewModel.clearState()
                    navController.navigate(Routes.REGISTER)
                },
                onSignInClick = {
                    authViewModel.clearState()
                    navController.navigate(Routes.LOGIN)
                }
            )
        }

        composable(
            route = Routes.LOGIN,
            enterTransition = {
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Start, slideSpec)
            },
            exitTransition = { fadeOut(fadeSpec) },
            popExitTransition = {
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.End, slideSpec)
            }
        ) {
            LoginScreen(
                uiState = authUiState,
                onEmailChange = authViewModel::updateEmail,
                onPasswordChange = authViewModel::updatePassword,
                onLoginClick = authViewModel::login,
                onBackClick = { navController.popBackStack() }
            )
        }

        composable(
            route = Routes.REGISTER,
            enterTransition = {
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Start, slideSpec)
            },
            exitTransition = { fadeOut(fadeSpec) },
            popExitTransition = {
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.End, slideSpec)
            }
        ) {
            RegisterScreen(
                uiState = authUiState,
                onNameChange = authViewModel::updateName,
                onEmailChange = authViewModel::updateEmail,
                onPasswordChange = authViewModel::updatePassword,
                onRegisterClick = authViewModel::register,
                onBackClick = { navController.popBackStack() }
            )
        }

        composable(
            route = Routes.MAIN,
            enterTransition = { fadeIn(fadeSpec) },
            exitTransition = {
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.Start, slideSpec)
            },
            popEnterTransition = {
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.End, slideSpec)
            }
        ) {
            MainScreen(
                onLogoutClick = authViewModel::logout,
                onProtocolClick = { protocolId ->
                    navController.navigate(Routes.protocolDetail(protocolId))
                },
                onCreateProtocolClick = {
                    navController.navigate(Routes.PROTOCOL_CREATE)
                }
            )
        }

        composable(
            route = Routes.PROTOCOL_DETAIL,
            arguments = listOf(navArgument("protocolId") { type = NavType.StringType }),
            enterTransition = {
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Start, slideSpec)
            },
            exitTransition = {
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.Start, slideSpec)
            },
            popEnterTransition = {
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.End, slideSpec)
            },
            popExitTransition = {
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.End, slideSpec)
            }
        ) { backStackEntry ->
            val protocolId = backStackEntry.arguments?.getString("protocolId") ?: return@composable
            val protocolViewModel: ProtocolViewModel = viewModel()

            ProtocolDetailScreen(
                protocolId = protocolId,
                viewModel = protocolViewModel,
                onBackClick = { navController.popBackStack() },
                onEditClick = { id -> navController.navigate(Routes.protocolEdit(id)) },
                onDeleted = { navController.popBackStack() }
            )
        }

        composable(
            route = Routes.PROTOCOL_CREATE,
            enterTransition = {
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Start, slideSpec)
            },
            popExitTransition = {
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.End, slideSpec)
            }
        ) {
            val protocolViewModel: ProtocolViewModel = viewModel()

            CreateProtocolScreen(
                viewModel = protocolViewModel,
                onBackClick = { navController.popBackStack() },
                onSuccess = { navController.popBackStack() }
            )
        }

        composable(
            route = Routes.PROTOCOL_EDIT,
            arguments = listOf(navArgument("protocolId") { type = NavType.StringType }),
            enterTransition = {
                slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Start, slideSpec)
            },
            popExitTransition = {
                slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.End, slideSpec)
            }
        ) { backStackEntry ->
            val protocolId = backStackEntry.arguments?.getString("protocolId") ?: return@composable
            val protocolViewModel: ProtocolViewModel = viewModel()

            CreateProtocolScreen(
                protocolId = protocolId,
                viewModel = protocolViewModel,
                onBackClick = { navController.popBackStack() },
                onSuccess = { navController.popBackStack() }
            )
        }
    }
}
