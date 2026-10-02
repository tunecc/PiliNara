package com.example.pilinara.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.example.pilinara.ui.screens.HomeScreen
import com.example.pilinara.ui.screens.SearchScreen
import com.example.pilinara.ui.screens.ProfileScreen
import com.example.pilinara.ui.screens.VideoPlayerScreen
import com.example.pilinara.ui.screens.DanmakuSettingsScreen

@Composable
fun AppNavigation() {
    val navController = rememberNavController()
    
    NavHost(
        navController = navController,
        startDestination = NavigationRoute.Home.route
    ) {
        composable(NavigationRoute.Home.route) {
            HomeScreen(
                onVideoClick = { videoId ->
                    navController.navigate("${NavigationRoute.VideoPlayer.route}/$videoId")
                },
                onSearchClick = {
                    navController.navigate(NavigationRoute.Search.route)
                }
            )
        }
        
        composable(NavigationRoute.Search.route) {
            SearchScreen(
                onBack = { navController.popBackStack() },
                onVideoClick = { videoId ->
                    navController.navigate("${NavigationRoute.VideoPlayer.route}/$videoId")
                }
            )
        }
        
        composable("${NavigationRoute.VideoPlayer.route}/{videoId}") { backStackEntry ->
            val videoId = backStackEntry.arguments?.getString("videoId") ?: ""
            VideoPlayerScreen(
                videoId = videoId,
                onBack = { navController.popBackStack() },
                onDanmakuSettings = {
                    navController.navigate(NavigationRoute.DanmakuSettings.route)
                }
            )
        }
        
        composable(NavigationRoute.Profile.route) {
            ProfileScreen(onBack = { navController.popBackStack() })
        }
        
        composable(NavigationRoute.DanmakuSettings.route) {
            DanmakuSettingsScreen(onBack = { navController.popBackStack() })
        }
    }
}

sealed class NavigationRoute(val route: String) {
    object Home : NavigationRoute("home")
    object Search : NavigationRoute("search")
    object VideoPlayer : NavigationRoute("video_player")
    object Profile : NavigationRoute("profile")
    object DanmakuSettings : NavigationRoute("danmaku_settings")
    object Settings : NavigationRoute("settings")
    object Dynamics : NavigationRoute("dynamics")
    object Message : NavigationRoute("message")
}
