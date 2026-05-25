package com.peppy.app

import android.app.Application
import com.peppy.app.core.di.Dependencies

class PeppyApp : Application() {

    override fun onCreate() {
        super.onCreate()
        Dependencies.init(this)
    }
}
