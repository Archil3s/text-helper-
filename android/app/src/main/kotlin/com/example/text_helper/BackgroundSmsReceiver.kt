package com.example.text_helper

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

class BackgroundSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val phoneNumber = intent.getStringExtra("phoneNumber") ?: return
        val message = intent.getStringExtra("message") ?: return
        val reminderId = intent.getStringExtra("reminderId") ?: return
        val contactName = intent.getStringExtra("contactName") ?: "Unknown"
        val scheduledAtMillis = intent.getLongExtra("scheduledAtMillis", System.currentTimeMillis())
        val recurrenceRule = intent.getStringExtra("recurrenceRule") ?: "once"

        if (!hasSendSmsPermission(context)) {
            writeSendLog(
                context = context,
                reminderId = reminderId,
                contactName = contactName,
                phoneNumber = phoneNumber,
                message = message,
                status = "failed",
                error = "SMS permission missing"
            )
            return
        }

        val duplicateReason = duplicateBlockReason(
            context = context,
            reminderId = reminderId,
            phoneNumber = phoneNumber,
            message = message
        )

        if (duplicateReason != null) {
            writeSendLog(
                context = context,
                reminderId = reminderId,
                contactName = contactName,
                phoneNumber = phoneNumber,
                message = message,
                status = "blocked",
                error = duplicateReason
            )
            return
        }

        try {
            sendSms(phoneNumber, message)
            markReminderSent(context, reminderId)
            writeSendLog(
                context = context,
                reminderId = reminderId,
                contactName = contactName,
                phoneNumber = phoneNumber,
                message = message,
                status = "sent",
                error = null
            )

            if (recurrenceRule != "once") {
                createNextRecurringReminderAndAlarm(
                    context = context,
                    originalIntent = intent,
                    currentScheduledAtMillis = scheduledAtMillis,
                    recurrenceRule = recurrenceRule
                )
            }
        } catch (error: Exception) {
            writeSendLog(
                context = context,
                reminderId = reminderId,
                contactName = contactName,
                phoneNumber = phoneNumber,
                message = message,
                status = "failed",
                error = error.message ?: "Unknown send error"
            )
        }
    }


    private fun duplicateBlockReason(
        context: Context,
        reminderId: String,
        phoneNumber: String,
        message: String
    ): String? {
        val prefs = flutterPrefs(context)
        val raw = prefs.getString("flutter.text_helper_send_log", "[]") ?: "[]"
        val array = JSONArray(raw)
        val cutoff = System.currentTimeMillis() - 86_400_000L

        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            if (item.optString("status") != "sent") {
                continue
            }

            if (item.optString("reminderId") == reminderId) {
                return "This reminder ID has already been sent."
            }
        }

        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            if (item.optString("status") != "sent") {
                continue
            }

            val sameNumber = item.optString("phoneNumber") == phoneNumber
            val sameMessage = item.optString("message").trim() == message.trim()
            val createdAt = item.optString("createdAt")
            val createdMillis = try {
                Instant.parse(createdAt).toEpochMilli()
            } catch (_: Exception) {
                0L
            }

            if (sameNumber && sameMessage && createdMillis >= cutoff) {
                return "Same number and message already sent in the last 24 hours."
            }
        }

        return null
    }
    private fun hasSendSmsPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun sendSms(phoneNumber: String, message: String) {
        val smsManager = SmsManager.getDefault()
        val parts = smsManager.divideMessage(message)

        if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
        } else {
            smsManager.sendTextMessage(phoneNumber, null, message, null, null)
        }
    }

    private fun flutterPrefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun nowIso(): String = Instant.now().toString()

    private fun markReminderSent(context: Context, reminderId: String) {
        val prefs = flutterPrefs(context)
        val key = "flutter.text_helper_appointment_reminders"
        val raw = prefs.getString(key, "[]") ?: "[]"
        val array = JSONArray(raw)

        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            if (item.optString("id") == reminderId) {
                item.put("isSent", true)
                item.put("sentAt", nowIso())
                array.put(index, item)
                break
            }
        }

        prefs.edit().putString(key, array.toString()).apply()
    }

    private fun writeSendLog(
        context: Context,
        reminderId: String,
        contactName: String,
        phoneNumber: String,
        message: String,
        status: String,
        error: String?
    ) {
        val prefs = flutterPrefs(context)
        val key = "flutter.text_helper_send_log"
        val raw = prefs.getString(key, "[]") ?: "[]"
        val oldArray = JSONArray(raw)
        val newArray = JSONArray()

        val log = JSONObject()
        log.put("id", System.nanoTime().toString())
        log.put("phoneNumber", phoneNumber)
        log.put("message", message)
        log.put("createdAt", nowIso())
        log.put("status", status)
        log.put("errorMessage", error)
        log.put("reminderId", reminderId)

        newArray.put(log)

        val max = minOf(oldArray.length(), 499)
        for (index in 0 until max) {
            newArray.put(oldArray.get(index))
        }

        prefs.edit().putString(key, newArray.toString()).apply()
    }

    private fun createNextRecurringReminderAndAlarm(
        context: Context,
        originalIntent: Intent,
        currentScheduledAtMillis: Long,
        recurrenceRule: String
    ) {
        var nextMillis = nextSchedule(currentScheduledAtMillis, recurrenceRule)
        val now = System.currentTimeMillis()

        while (nextMillis <= now) {
            nextMillis = nextSchedule(nextMillis, recurrenceRule)
        }

        val oldReminderId = originalIntent.getStringExtra("reminderId") ?: return
        val newReminderId = "-"

        val prefs = flutterPrefs(context)
        val key = "flutter.text_helper_appointment_reminders"
        val raw = prefs.getString(key, "[]") ?: "[]"
        val array = JSONArray(raw)

        val next = JSONObject()
        next.put("id", newReminderId)
        next.put("contactId", originalIntent.getStringExtra("contactId") ?: "")
        next.put("phoneNumber", originalIntent.getStringExtra("phoneNumber") ?: "")
        next.put("appointmentTitle", originalIntent.getStringExtra("appointmentTitle") ?: "Appointment")
        next.put("location", originalIntent.getStringExtra("location") ?: "")
        next.put("message", originalIntent.getStringExtra("message") ?: "")
        next.put("scheduledAt", Instant.ofEpochMilli(nextMillis).toString())
        next.put("isSent", false)
        next.put("recurrenceRule", recurrenceRule)
        next.put("templateName", originalIntent.getStringExtra("templateName") ?: "Custom")
        next.put("sentAt", JSONObject.NULL)
        next.put("notes", originalIntent.getStringExtra("notes") ?: "")

        array.put(next)
        prefs.edit().putString(key, array.toString()).apply()

        val alarmIntent = Intent(context, BackgroundSmsReceiver::class.java).apply {
            putExtra("alarmId", newReminderId)
            putExtra("reminderId", newReminderId)
            putExtra("contactId", originalIntent.getStringExtra("contactId") ?: "")
            putExtra("phoneNumber", originalIntent.getStringExtra("phoneNumber") ?: "")
            putExtra("appointmentTitle", originalIntent.getStringExtra("appointmentTitle") ?: "Appointment")
            putExtra("location", originalIntent.getStringExtra("location") ?: "")
            putExtra("message", originalIntent.getStringExtra("message") ?: "")
            putExtra("scheduledAtMillis", nextMillis)
            putExtra("recurrenceRule", recurrenceRule)
            putExtra("templateName", originalIntent.getStringExtra("templateName") ?: "Custom")
            putExtra("notes", originalIntent.getStringExtra("notes") ?: "")
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            newReminderId.hashCode(),
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(AlarmManager::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextMillis,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                nextMillis,
                pendingIntent
            )
        }
    }

    private fun nextSchedule(currentMillis: Long, rule: String): Long {
        return when (rule) {
            "everyMinute" -> currentMillis + 60_000L
            "daily" -> currentMillis + 86_400_000L
            "weekly" -> currentMillis + 604_800_000L
            "monthly" -> currentMillis + 2_592_000_000L
            else -> currentMillis
        }
    }
}

