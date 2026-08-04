package com.sabtrack.ai

import android.app.*
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.*
import android.content.pm.ServiceInfo

class StepCounterService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private lateinit var powerManager: PowerManager
    private var wakeLock: PowerManager.WakeLock? = null

    companion object {
        const val CHANNEL_ID = "step_counter_channel"
        const val NOTIFICATION_ID = 1001
        const val PREFS_NAME = "step_counter_prefs"
        const val KEY_BASELINE = "sensor_baseline"
        const val KEY_TODAY_STEPS = "today_steps"
        const val KEY_LAST_SENSOR_VALUE = "last_sensor_value"
        const val KEY_LAST_DATE = "last_active_date"
    }

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        
        // Keep cpu awake lightly on steps delivery
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SABTRACK::StepCounterWakeLock")
        wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes timeout, refreshed on step updates

        createNotificationChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                getNotification(getTodayStepsFromPrefs()),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
            )
        } else {
            startForeground(NOTIFICATION_ID, getNotification(getTodayStepsFromPrefs()))
        }

        registerSensor()
    }

    private fun registerSensor() {
        stepSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        
        // Refresh wake lock
        if (wakeLock?.isHeld == false) {
            wakeLock?.acquire(10 * 60 * 1000L)
        }

        val sensorValue = event.values[0].toInt()
        processSensorValue(sensorValue)
    }

    private fun processSensorValue(sensorValue: Int) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val todayStr = getTodayDateString()

        val lastDate = prefs.getString(KEY_LAST_DATE, "") ?: ""
        var baseline = prefs.getInt(KEY_BASELINE, -1)
        var todaySteps = prefs.getInt(KEY_TODAY_STEPS, 0)
        val lastSensorValue = prefs.getInt(KEY_LAST_SENSOR_VALUE, -1)

        // 1. Date Change — Midnight Reset
        if (lastDate != todayStr) {
            if (lastDate.isNotEmpty()) {
                // Archive yesterday's steps before resetting
                prefs.edit().putInt("yesterday_steps_$lastDate", todaySteps).apply()
            }
            baseline = sensorValue
            todaySteps = 0
            prefs.edit()
                .putString(KEY_LAST_DATE, todayStr)
                .putInt(KEY_BASELINE, baseline)
                .putInt(KEY_TODAY_STEPS, 0)
                .apply()
        }
        // 2. Service Restart on Same Day — Re-anchor baseline from last known sensor value.
        //    When Android kills and restarts the service via START_STICKY, the prefs still
        //    have the correct todaySteps but baseline may be stale.
        //    Fix: re-derive baseline so that (sensorValue - baseline) == todaySteps exactly.
        else if (lastDate == todayStr && lastSensorValue > 0 && baseline != -1) {
            val expectedBaseline = lastSensorValue - todaySteps
            // Only re-anchor if baseline has drifted (service was restarted or sensor restarted)
            if (sensorValue != lastSensorValue && baseline != expectedBaseline) {
                baseline = sensorValue - todaySteps
                if (baseline < 0) baseline = 0
                prefs.edit().putInt(KEY_BASELINE, baseline).apply()
            }
        }

        // 3. Device Reboot — Hardware sensor resets to zero after reboot
        if (baseline != -1 && sensorValue < baseline) {
            baseline = sensorValue - todaySteps
            if (baseline < 0) baseline = 0
            prefs.edit().putInt(KEY_BASELINE, baseline).apply()
        }

        // 4. First Run Init — No baseline ever set
        if (baseline == -1) {
            baseline = sensorValue
            todaySteps = 0
            prefs.edit()
                .putInt(KEY_BASELINE, baseline)
                .putString(KEY_LAST_DATE, todayStr)
                .apply()
        }

        // 5. Calculate Steps
        val calculatedSteps = sensorValue - baseline

        if (calculatedSteps in 0..todaySteps + 10000) {
            todaySteps = calculatedSteps
        } else {
            // Drift guard — re-align baseline if calculated steps are wildly off
            baseline = sensorValue - todaySteps
            prefs.edit().putInt(KEY_BASELINE, baseline).apply()
        }

        // 6. Persist values
        prefs.edit()
            .putInt(KEY_TODAY_STEPS, todaySteps)
            .putInt(KEY_LAST_SENSOR_VALUE, sensorValue)
            .apply()

        // 7. Refresh persistent notification
        updateNotification(todaySteps)
    }

    private fun getTodayStepsFromPrefs(): Int {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getInt(KEY_TODAY_STEPS, 0)
    }

    private fun getTodayDateString(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        return sdf.format(Date())
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        super.onDestroy()
    }

    private fun updateNotification(steps: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, getNotification(steps))
    }

    private fun getNotification(steps: Int): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SABTRACK AI")
            .setContentText("Daily progress: $steps steps logged today")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "SABTRACK Background Step Counter",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }
}
