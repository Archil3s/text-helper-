package com.example.text_helper

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.media.RingtoneManager
import android.media.AudioAttributes
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.Notification
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.BatteryManager
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
    private val deviceDiagnosticsChannelName = "text_helper/device_diagnostics"
    private val notificationChannelName = "text_helper/notification_channel"
    private val whatsAppChannelName = "text_helper/whatsapp_handoff"
    private val reminderNotificationChannelId = "text_helper_reminders"
    private val reminderNotificationId = 23001
    private val postNotificationsPermission = "android.permission.POST_NOTIFICATIONS"

    private var pendingSmsResult: MethodChannel.Result? = null
    private var pendingPhoneNumber: String? = null
    private var pendingMessage: String? = null
    private var pendingReminderId: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

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
                    val reminderId =
                        call.argument<String>("reminderId") ?: "manual-${System.nanoTime()}"

                    if (phoneNumber.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENTS", "Phone number and message are required.", null)
                        return@setMethodCallHandler
                    }

                    sendSmsWithPermission(phoneNumber, message, reminderId, result)
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
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNotificationDiagnostics" -> {
                    result.success(getNotificationDiagnostics())
                }
                "createReminderNotificationChannel" -> {
                    createReminderNotificationChannel()
                    result.success(getNotificationDiagnostics())
                }
                "requestPostNotificationsPermission" -> {
                    requestPostNotificationsPermission(result)
                }
                "sendTestReminderNotification" -> {
                    result.success(sendTestReminderNotification())
                }
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                "openReminderNotificationChannelSettings" -> {
                    openReminderNotificationChannelSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            whatsAppChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                
                "isWhatsAppInstalled" -> {
                    result.success(isWhatsAppInstalled())
                }
                "launchWhatsAppHandoff" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")

                    if (phoneNumber.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENTS", "Phone number and message are required.", null)
                        return@setMethodCallHandler
                    }

                    result.success(launchWhatsAppHandoff(phoneNumber, message))
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceDiagnosticsChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceDiagnostics" -> result.success(getDeviceDiagnostics())
                else -> result.notImplemented()
            }
        }
    }


    private fun isWhatsAppInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo("com.whatsapp", 0)
            true
        } catch (error: Exception) {
            false
        }
    }

    private fun launchWhatsAppHandoff(phoneNumber: String, message: String): Boolean {
        val number = normalizeWhatsAppNumber(phoneNumber)

        if (number.isBlank()) {
            return false
        }

        val uri = Uri.parse("https://wa.me/$number?text=${Uri.encode(message)}")

        val whatsappIntent = Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage("com.whatsapp")
        }

        return try {
            startActivity(whatsappIntent)
            true
        } catch (firstError: Exception) {
            try {
                val fallbackIntent = Intent(Intent.ACTION_VIEW, uri)
                startActivity(fallbackIntent)
                true
            } catch (secondError: Exception) {
                false
            }
        }
    }

    private fun normalizeWhatsAppNumber(phoneNumber: String): String {
        val cleaned = phoneNumber.trim().replace(Regex("[^0-9+]"), "")

        return if (cleaned.startsWith("+")) {
            cleaned.substring(1)
        } else {
            cleaned
        }
    }
    private fun getDeviceDiagnostics(): Map<String, Any?> {
        val batteryIntent = registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )

        val batteryLevel = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val batteryScale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val batteryStatus = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val batteryPercent = if (batteryLevel >= 0 && batteryScale > 0) {
            ((batteryLevel * 100.0f) / batteryScale).toInt()
        } else {
            -1
        }

        val isCharging =
            batteryStatus == BatteryManager.BATTERY_STATUS_CHARGING ||
                batteryStatus == BatteryManager.BATTERY_STATUS_FULL

        val smsPermissionGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        val notificationsPermissionGranted = if (Build.VERSION.SDK_INT >= 33) {
            checkSelfPermission("android.permission.POST_NOTIFICATIONS") ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        return mapOf(
            "androidRelease" to Build.VERSION.RELEASE,
            "apiLevel" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "device" to Build.DEVICE,
            "batteryPercent" to batteryPercent,
            "batteryCharging" to isCharging,
            "smsPermissionGranted" to smsPermissionGranted,
            "notificationsPermissionGranted" to notificationsPermissionGranted
        )
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
        reminderId: String,
        result: MethodChannel.Result
    ) {
        if (hasSendSmsPermission()) {
            sendSmsNow(phoneNumber, message, reminderId, result)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingSmsResult = result
            pendingPhoneNumber = phoneNumber
            pendingMessage = message
            pendingReminderId = reminderId
            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), 9001)
        } else {
            result.error("PERMISSION_DENIED", "SMS permission denied.", null)
        }
    }

    private fun sendSmsNow(
        phoneNumber: String,
        message: String,
        reminderId: String,
        result: MethodChannel.Result
    ) {
        try {
            sendSmsWithReceipts(phoneNumber, message, reminderId)
            result.success(true)
        } catch (error: Exception) {
            result.error("SEND_FAILED", error.message, null)
        }
    }

    private fun sendSmsWithReceipts(
        phoneNumber: String,
        message: String,
        reminderId: String
    ) {
        val smsManager = SmsManager.getDefault()
        val parts = smsManager.divideMessage(message)
        val sentIntents = ArrayList<PendingIntent>()
        val deliveredIntents = ArrayList<PendingIntent>()

        for (index in parts.indices) {
            sentIntents.add(
                createSmsStatusPendingIntent(
                    receiverClass = SmsSentReceiver::class.java,
                    reminderId = reminderId,
                    phoneNumber = phoneNumber,
                    message = message,
                    partIndex = index,
                    event = "sent"
                )
            )

            deliveredIntents.add(
                createSmsStatusPendingIntent(
                    receiverClass = SmsDeliveredReceiver::class.java,
                    reminderId = reminderId,
                    phoneNumber = phoneNumber,
                    message = message,
                    partIndex = index,
                    event = "delivered"
                )
            )
        }

        if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(
                phoneNumber,
                null,
                parts,
                sentIntents,
                deliveredIntents
            )
        } else {
            smsManager.sendTextMessage(
                phoneNumber,
                null,
                message,
                sentIntents.firstOrNull(),
                deliveredIntents.firstOrNull()
            )
        }
    }

    private fun createSmsStatusPendingIntent(
        receiverClass: Class<*>,
        reminderId: String,
        phoneNumber: String,
        message: String,
        partIndex: Int,
        event: String
    ): PendingIntent {
        val intent = Intent(this, receiverClass).apply {
            action = "text_helper.sms.$event.$reminderId.$partIndex.${System.nanoTime()}"
            putExtra("reminderId", reminderId)
            putExtra("phoneNumber", phoneNumber)
            putExtra("message", message)
            putExtra("partIndex", partIndex)
        }

        return PendingIntent.getBroadcast(
            this,
            intent.action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
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
                Uri.parse("package:$packageName")
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

    private fun createReminderNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        val existingChannel =
            notificationManager.getNotificationChannel(reminderNotificationChannelId)

        if (existingChannel != null) {
            return
        }

        val defaultSoundUri =
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            reminderNotificationChannelId,
            "Reminder tests",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description =
                "Test reminder notification sound and vibration for Text Helper."
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 250, 120, 250)
            setSound(defaultSoundUri, audioAttributes)
        }

        notificationManager.createNotificationChannel(channel)
    }

    private fun hasPostNotificationsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 33) {
            return true
        }

        return checkSelfPermission(postNotificationsPermission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestPostNotificationsPermission(result: MethodChannel.Result) {
        if (hasPostNotificationsPermission()) {
            result.success(true)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingNotificationPermissionResult = result
            requestPermissions(arrayOf(postNotificationsPermission), 9003)
        } else {
            result.success(true)
        }
    }

    private fun areAppNotificationsEnabled(
        notificationManager: NotificationManager
    ): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return notificationManager.areNotificationsEnabled()
        }

        return true
    }

    private fun isReminderChannelEnabled(
        notificationManager: NotificationManager
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return true
        }

        val channel =
            notificationManager.getNotificationChannel(reminderNotificationChannelId)
                ?: return false

        return channel.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun describeNotificationImportance(importance: Int): String {
        return when (importance) {
            NotificationManager.IMPORTANCE_NONE -> "blocked"
            NotificationManager.IMPORTANCE_MIN -> "silent"
            NotificationManager.IMPORTANCE_LOW -> "low"
            NotificationManager.IMPORTANCE_DEFAULT -> "default"
            NotificationManager.IMPORTANCE_HIGH -> "high"
            NotificationManager.IMPORTANCE_MAX -> "urgent"
            else -> "unknown"
        }
    }

    private fun getNotificationDiagnostics(): Map<String, Any> {
        createReminderNotificationChannel()

        val notificationManager = getSystemService(NotificationManager::class.java)
        val notificationsEnabled = areAppNotificationsEnabled(notificationManager)
        val permissionGranted = hasPostNotificationsPermission()

        val channelCreated: Boolean
        val channelEnabled: Boolean
        val channelImportance: String

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                notificationManager.getNotificationChannel(reminderNotificationChannelId)
            channelCreated = channel != null
            channelEnabled =
                channel != null && channel.importance != NotificationManager.IMPORTANCE_NONE
            channelImportance = if (channel == null) {
                "missing"
            } else {
                describeNotificationImportance(channel.importance)
            }
        } else {
            channelCreated = true
            channelEnabled = true
            channelImportance = "not_required"
        }

        return mapOf(
            "apiLevel" to Build.VERSION.SDK_INT,
            "permissionGranted" to permissionGranted,
            "notificationsEnabled" to notificationsEnabled,
            "channelCreated" to channelCreated,
            "channelEnabled" to channelEnabled,
            "channelImportance" to channelImportance
        )
    }

    private fun sendTestReminderNotification(): Boolean {
        createReminderNotificationChannel()

        val notificationManager = getSystemService(NotificationManager::class.java)

        if (!hasPostNotificationsPermission()) {
            return false
        }

        if (!areAppNotificationsEnabled(notificationManager)) {
            return false
        }

        if (!isReminderChannelEnabled(notificationManager)) {
            return false
        }

        val notificationBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, reminderNotificationChannelId)
        } else {
            Notification.Builder(this)
        }

        val notification = notificationBuilder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Text Helper reminder test")
            .setContentText("If you heard a sound or felt vibration, reminder alerts are working.")
            .setStyle(
                Notification.BigTextStyle().bigText(
                    "If you heard a sound or felt vibration, reminder alerts are working. If not, open notification settings and check sound, vibration, and channel status."
                )
            )
            .setAutoCancel(true)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setPriority(Notification.PRIORITY_HIGH)
            .setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
            .build()

        notificationManager.notify(reminderNotificationId, notification)
        return true
    }

    private fun openNotificationSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
            }

            startActivity(intent)
        } catch (error: Exception) {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(fallback)
        }
    }

    private fun openReminderNotificationChannelSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            openNotificationSettings()
            return
        }

        try {
            val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                putExtra(Settings.EXTRA_CHANNEL_ID, reminderNotificationChannelId)
            }
            startActivity(intent)
        } catch (error: Exception) {
            openNotificationSettings()
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
            val strictExact = alarm["strictExact"] as? Boolean ?: false

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

            if (strictExact) {
                scheduleAlarmClock(alarmManager, triggerAt, pendingIntent, alarmId)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
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

    private fun scheduleAlarmClock(
        alarmManager: AlarmManager,
        triggerAt: Long,
        operation: PendingIntent,
        alarmId: String
    ) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)

        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

        val showIntent = PendingIntent.getActivity(
            this,
            alarmId.hashCode() xor 0x51ed,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(triggerAt, showIntent),
            operation
        )
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

        if (requestCode == 9003) {
            pendingNotificationPermissionResult?.success(granted)
            pendingNotificationPermissionResult = null
            return
        }

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
        val reminderId = pendingReminderId

        pendingSmsResult = null
        pendingPhoneNumber = null
        pendingMessage = null
        pendingReminderId = null

        if (result == null || phoneNumber == null || message == null || reminderId == null) {
            return
        }

        if (granted) {
            sendSmsNow(phoneNumber, message, reminderId, result)
        } else {
            result.error("PERMISSION_DENIED", "SMS permission denied.", null)
        }
    }
}


