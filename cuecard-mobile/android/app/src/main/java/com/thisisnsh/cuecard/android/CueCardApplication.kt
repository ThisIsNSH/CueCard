package com.thisisnsh.cuecard.android

import android.app.Application
import android.os.Bundle
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.ktx.analytics
import com.google.firebase.analytics.logEvent
import com.google.firebase.crashlytics.ktx.crashlytics
import com.google.firebase.ktx.Firebase

class CueCardApplication : Application() {

    lateinit var analytics: FirebaseAnalytics
        private set

    override fun onCreate() {
        super.onCreate()
        FirebaseApp.initializeApp(this)
        analytics = Firebase.analytics

        // Configure Crashlytics
        Firebase.crashlytics.setCrashlyticsCollectionEnabled(true)

        // Log app open event
        analytics.logEvent(FirebaseAnalytics.Event.APP_OPEN, null)
    }
}

/**
 * Analytics helper for consistent event logging across the app.
 * Mirrors iOS AnalyticsEvents structure.
 */
object AnalyticsEvents {
    private val analytics = Firebase.analytics
    private val crashlytics = Firebase.crashlytics

    fun logButtonClick(buttonName: String, screen: String, parameters: Map<String, Any>? = null) {
        val params = Bundle().apply {
            putString("button_name", buttonName)
            putString("screen_name", screen)
            parameters?.forEach { (key, value) ->
                when (value) {
                    is String -> putString(key, value)
                    is Int -> putInt(key, value)
                    is Long -> putLong(key, value)
                    is Double -> putDouble(key, value)
                    is Boolean -> putBoolean(key, value)
                }
            }
        }
        analytics.logEvent("button_click", params)
        crashlytics.log("Button clicked: $buttonName on $screen")
    }

    fun logScreenView(screenName: String) {
        analytics.logEvent(FirebaseAnalytics.Event.SCREEN_VIEW) {
            param(FirebaseAnalytics.Param.SCREEN_NAME, screenName)
        }
        crashlytics.log("Screen viewed: $screenName")
    }

    fun log(message: String) {
        crashlytics.log(message)
    }
}
