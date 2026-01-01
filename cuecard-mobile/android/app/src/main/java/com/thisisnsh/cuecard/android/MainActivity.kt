package com.thisisnsh.cuecard.android

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.thisisnsh.cuecard.android.services.TeleprompterPiPManager
import com.thisisnsh.cuecard.android.ui.screens.MainScreen
import com.thisisnsh.cuecard.android.ui.theme.CueCardTheme

class MainActivity : ComponentActivity() {

    private val pipManager = TeleprompterPiPManager.shared

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Check PiP support
        pipManager.checkPiPSupport(this)

        setContent {
            CueCardTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MainScreen()
                }
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Enter PiP when user presses home button (if PiP is possible and playing)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            pipManager.isPiPPossible &&
            pipManager.isPlaying) {
            pipManager.enterPiP(this)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)

        if (isInPictureInPictureMode) {
            pipManager.onPiPModeEntered()
        } else {
            pipManager.onPiPModeExited()
        }
    }
}
