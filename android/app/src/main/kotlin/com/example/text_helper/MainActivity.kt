package com.example.text_helper

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val nativeSmsChannelName = "text_helper/native_sms"
    private val backgroundAlarmChannelName = "text_helper/background_alarm"

    private var pendingSmsResult: MethodChannel.Result? = null
    private var pendingPhoneNumber: String? = null
    private var pendingMessage: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeSmsChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")

                    if (phoneNumber.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENTS", "Phone number and message are required.", null)
                        return@setMethodCallHandler
                    }

                    sendSmsWithPermission(phoneNumber, message, result)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            backgroundAlarmChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermission" -> requestSmsPermissionOnly(result)
                "canScheduleExactAlarms" -> result.success(canScheduleExactAlarms())
                "openExactAlarmSettings" -> {
                    openExactAlarmSettings()
                    result.success(null)
                }
                "syncBackgroundAlarms" -> {
                    val alarms = call.argument<List<Map<String, Any?>>>("alarms") ?: emptyList()
                    val count = syncBackgroundAlarms(alarms)
                    result.success(count)
                }
                "cancelAllBackgroundAlarms" -> {
                    cancelAllBackgroundAlarms()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasSendSmsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun requestSmsPermissionOnly(result: MethodChannel.Result) {
        if (hasSendSmsPermission()) {
            result.success(true)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingPermissionResult = result
            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), 9002)
        } else {
            result.success(false)
        }
    }

    private fun sendSmsWithPermission(
        phoneNumber: String,
        message: String,
        result: MethodChannel.Result
    ) {
        if (hasSendSmsPermission()) {
            sendSmsNow(phoneNumber, message, result)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingSmsResult = result
            pendingPhoneNumber = phoneNumber
            pendingMessage = message
            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), 9001)
        } else {
            result.error("PERMISSION_DENIED", "SMS permission denied.", null)
        }
    }

    private fun sendSmsNow(
        phoneNumber: String,
        message: String,
        result: MethodChannel.Result
    ) {
        try {
            val smsManager = SmsManager.getDefault()
            val parts = smsManager.divideMessage(message)

            if (parts.size > 1) {
                smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
            } else {
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
            }

            result.success(true)
        } catch (error: Exception) {
            result.error("SEND_FAILED", error.message, null)
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }

        val alarmManager = getSystemService(AlarmManager::class.java)
        return alarmManager.canScheduleExactAlarms()
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(
                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse("package:com.example.text_helper")
            )
            startActivity(intent)
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        val powerManager = getSystemService(PowerManager::class.java)
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return
        }

        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (error: Exception) {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
        }
    }
    private fun syncBackgroundAlarms(alarms: List<Map<String, Any?>>): Int {
        cancelAllBackgroundAlarms()

        val scheduledIds = mutableSetOf<String>()
        var count = 0

        for (alarm in alarms) {
            val alarmId = alarm["alarmId"] as? String ?: continue
            val phoneNumber = alarm["phoneNumber"] as? String ?: continue
            val message = alarm["message"] as? String ?: continue
            val scheduledAtMillis = (alarm["scheduledAtMillis"] as? Number)?.toLong() ?: continue

            val intent = Intent(this, BackgroundSmsReceiver::class.java).apply {
                putExtra("alarmId", alarmId)
                putExtra("reminderId", alarm["reminderId"] as? String ?: alarmId)
                putExtra("contactId", alarm["contactId"] as? String ?: "")
                putExtra("phoneNumber", phoneNumber)
                putExtra("appointmentTitle", alarm["appointmentTitle"] as? String ?: "Appointment")
                putExtra("location", alarm["location"] as? String ?: "")
                putExtra("message", message)
                putExtra("scheduledAtMillis", scheduledAtMillis)
                putExtra("recurrenceRule", alarm["recurrenceRule"] as? String ?: "once")
                putExtra("templateName", alarm["templateName"] as? String ?: "Custom")
                putExtra("notes", alarm["notes"] as? String ?: "")
            }

            val pendingIntent = PendingIntent.getBroadcast(
                this,
                alarmId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = getSystemService(AlarmManager::class.java)
            val triggerAt = if (scheduledAtMillis < System.currentTimeMillis()) {
                System.currentTimeMillis() + 1000L
            } else {
                scheduledAtMillis
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent
                    )
                } else {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
            }

            scheduledIds.add(alarmId)
            count += 1
        }

        getSharedPreferences("text_helper_native_alarm_store", MODE_PRIVATE)
            .edit()
            .putStringSet("scheduled_alarm_ids", scheduledIds)
            .apply()

        return count
    }

    private fun cancelAllBackgroundAlarms() {
        val prefs = getSharedPreferences("text_helper_native_alarm_store", MODE_PRIVATE)
        val ids = prefs.getStringSet("scheduled_alarm_ids", emptySet()) ?: emptySet()
        val alarmManager = getSystemService(AlarmManager::class.java)

        for (id in ids) {
            val intent = Intent(this, BackgroundSmsReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                id.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }

        prefs.edit().remove("scheduled_alarm_ids").apply()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED

        if (requestCode == 9002) {
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
            return
        }

        if (requestCode != 9001) {
            return
        }

        val result = pendingSmsResult
        val phoneNumber = pendingPhoneNumber
        val message = pendingMessage

        pendingSmsResult = null
        pendingPhoneNumber = null
        pendingMessage = null

        if (result == null || phoneNumber == null || message == null) {
            return
        }

        if (granted) {
            sendSmsNow(phoneNumber, message, result)
        } else {
            result.error("PERMISSION_DENIED", "SMS permission denied.", null)
        }
    }
}

