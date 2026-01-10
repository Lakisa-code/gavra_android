package com.gavra013.gavra_android

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val VIBRATION_CHANNEL = "com.gavra013.gavra_android/vibration"
    private val TAG = "GavraMainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
}
