package com.sabtrack.ai

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.Manifest

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            // Check permission first to prevent crashing on boot if user hasn't granted permission yet
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val hasPermission = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACTIVITY_RECOGNITION
                ) == PackageManager.PERMISSION_GRANTED
                if (!hasPermission) {
                    return
                }
            }

            val serviceIntent = Intent(context, StepCounterService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
