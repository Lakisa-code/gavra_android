package com.gavra013.gavra_android

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.gavra013.gavra_android/gbox"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "registerWithGBox" -> {
                        val success = registerWithGBox(
                            call.argument<String>("packageName") ?: "",
                            call.argument<String>("appName") ?: ""
                        )
                        result.success(success)
                    }
                    "openGBox" -> {
                        val success = openGBox()
                        result.success(success)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun registerWithGBox(packageName: String, appName: String): Boolean {
        return try {
            // Pokušaj da otvori G-Box sa intent-om za dodavanje aplikacije
            val gboxIntent = Intent().apply {
                component = ComponentName("com.gbox.android", "com.gbox.android.MainActivity")
                action = "com.gbox.android.ADD_APP"
                putExtra("package_name", packageName)
                putExtra("app_name", appName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            // Provjeri da li G-Box postoji
            val packageManager = packageManager
            val gboxExists = try {
                packageManager.getPackageInfo("com.gbox.android", 0)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
            
            if (gboxExists) {
                startActivity(gboxIntent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
    
    private fun openGBox(): Boolean {
        return try {
            val gboxIntent = Intent().apply {
                component = ComponentName("com.gbox.android", "com.gbox.android.MainActivity") 
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            // Provjeri da li G-Box postoji
            val packageManager = packageManager
            val gboxExists = try {
                packageManager.getPackageInfo("com.gbox.android", 0)
                true
            } catch (e: PackageManager.NameNotFoundException) {
                false
            }
            
            if (gboxExists) {
                startActivity(gboxIntent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
