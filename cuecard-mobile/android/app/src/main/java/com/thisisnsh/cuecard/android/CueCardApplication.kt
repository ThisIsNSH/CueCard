package com.thisisnsh.cuecard.android

import android.app.Application
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.analytics.ktx.analytics
import com.google.firebase.ktx.Firebase

class CueCardApplication : Application() {

    lateinit var analytics: FirebaseAnalytics
        private set

    override fun onCreate() {
        super.onCreate()
        FirebaseApp.initializeApp(this)
        analytics = Firebase.analytics
    }
}
