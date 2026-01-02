package com.gavra013.gavra_android

import android.app.PictureInPictureParams
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VIBRATION_CHANNEL = "com.gavra013.gavra_android/vibration"
    private val PIP_CHANNEL = "com.gavra013.gavra_android/pip"
    private val TAG = "GavraMainActivity"
    
    private var pipMethodChannel: MethodChannel? = null
    private var isInPipMode = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // PiP Channel
        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
        pipMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> {
                    val success = enterPipMode()
                    result.success(success)
                }
                "isPipSupported" -> {
                    result.success(isPipSupported())
                }
                "isPipActive" -> {
                    result.success(isInPipMode)
                }
                else -> result.notImplemented()
            }
        }
        
        // Vibration Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIBRATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    val duration = call.argument<Int>("duration") ?: 200
                    val success = vibrate(duration.toLong())
                    android.util.Log.d(TAG, "vibrate($duration) called, success=$success")
                    result.success(success)
                }
                "checkVibrator" -> {
                    val vibrator = getVibrator()
                    val hasVibrator = vibrator?.hasVibrator() ?: false
                    val hasAmplitudeControl = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator?.hasAmplitudeControl() ?: false
                    } else false
                    val info = mapOf(
                        "hasVibrator" to hasVibrator,
                        "hasAmplitudeControl" to hasAmplitudeControl,
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "sdkInt" to Build.VERSION.SDK_INT
                    )
                    android.util.Log.d(TAG, "checkVibrator: $info")
                    result.success(info)
                }
                "vibratePattern" -> {
                    @Suppress("UNCHECKED_CAST")
                    val pattern = call.argument<List<Int>>("pattern") ?: listOf(0, 100, 50, 100)
                    val success = vibratePattern(pattern.map { it.toLong() }.toLongArray())
                    android.util.Log.d(TAG, "vibratePattern called, success=$success")
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrate(duration: Long): Boolean {
        return try {
            val vibrator = getVibrator()
            android.util.Log.d(TAG, "vibrate: vibrator=$vibrator, hasVibrator=${vibrator?.hasVibrator()}")
            if (vibrator?.hasVibrator() == true) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(duration)
                }
                true
            } else {
                android.util.Log.w(TAG, "vibrate: No vibrator available!")
                false
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "vibrate error: ${e.message}")
            false
        }
    }

    private fun vibratePattern(pattern: LongArray): Boolean {
        return try {
            val vibrator = getVibrator()
            if (vibrator?.hasVibrator() == true) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(pattern, -1)
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "vibratePattern error: ${e.message}")
            false
        }
    }

    private fun getVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }
    
    // ==================== PiP (Picture-in-Picture) ====================
    
    private fun isPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
    }
    
    private fun enterPipMode(): Boolean {
        if (!isPipSupported()) {
            android.util.Log.w(TAG, "PiP not supported on this device (requires Android 8.0+)")
            return false
        }
        
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // 16:9 aspect ratio za PiP prozor
                val aspectRatio = Rational(16, 9)
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio)
                    .build()
                
                enterPictureInPictureMode(params)
                android.util.Log.d(TAG, "Entered PiP mode")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to enter PiP mode: ${e.message}")
            false
        }
    }
    
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isInPipMode = isInPictureInPictureMode
        
        // Notify Flutter about PiP state change
        pipMethodChannel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
        android.util.Log.d(TAG, "PiP mode changed: $isInPictureInPictureMode")
    }
    
    // UKLONJENO: Auto PiP kada izađeš iz aplikacije (slika 2)
    // Ručni PiP iz background servisa i dalje radi (slika 1)
}
