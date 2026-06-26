package com.sabtrack.ai

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.sabtrack.ai/steps"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Start StepCounterService automatically when the app is launched
        startStepCounterService()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTodaySteps" -> {
                    val prefs = getSharedPreferences(StepCounterService.PREFS_NAME, Context.MODE_PRIVATE)
                    val steps = prefs.getInt(StepCounterService.KEY_TODAY_STEPS, 0)
                    result.success(steps)
                }
                "getSensorValue" -> {
                    val prefs = getSharedPreferences(StepCounterService.PREFS_NAME, Context.MODE_PRIVATE)
                    val sensorValue = prefs.getInt(StepCounterService.KEY_LAST_SENSOR_VALUE, -1)
                    result.success(sensorValue)
                }
                "getBaseline" -> {
                    val prefs = getSharedPreferences(StepCounterService.PREFS_NAME, Context.MODE_PRIVATE)
                    val baseline = prefs.getInt(StepCounterService.KEY_BASELINE, -1)
                    result.success(baseline)
                }
                "resetBaseline" -> {
                    val sensorValue = call.argument<Int>("sensorValue") ?: -1
                    val steps = call.argument<Int>("steps") ?: 0
                    val prefs = getSharedPreferences(StepCounterService.PREFS_NAME, Context.MODE_PRIVATE)
                    if (sensorValue != -1) {
                        val newBaseline = sensorValue - steps
                        prefs.edit()
                            .putInt(StepCounterService.KEY_BASELINE, if (newBaseline > 0) newBaseline else 0)
                            .putInt(StepCounterService.KEY_TODAY_STEPS, steps)
                            .apply()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "sensorValue is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startStepCounterService() {
        val serviceIntent = Intent(this, StepCounterService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

