package com.notemarket.app

import com.notemarket.app.plugins.AndroidPackageManagerPlugin
import com.notemarket.app.plugins.AppRestartPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register plugins
        flutterEngine.plugins.add(AndroidPackageManagerPlugin())
        flutterEngine.plugins.add(AppRestartPlugin())
    }
}