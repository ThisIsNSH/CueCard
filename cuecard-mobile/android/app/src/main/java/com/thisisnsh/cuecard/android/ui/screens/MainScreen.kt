package com.thisisnsh.cuecard.android.ui.screens

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.thisisnsh.cuecard.android.services.AuthenticationService

@Composable
fun MainScreen() {
    val context = LocalContext.current
    val authService = remember { AuthenticationService(context) }
    val currentUser by authService.currentUser.collectAsState()

    if (currentUser != null) {
        HomeScreen(
            authService = authService
        )
    } else {
        LoginScreen(
            authService = authService
        )
    }
}
