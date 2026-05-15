package com.example.text_helper

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

class BackgroundSmsReceiver : BroadcastReceiver() {
    companion object {
        private const val tag = "BackgroundSmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val phoneNumber = intent.getStringExtra("phoneNumber") ?: ""
        val message = intent.getStringExtra("message") ?: ""
        val reminderId = intent.getStringExtra("reminderId") ?: intent.getStringExtra("alarmId") ?: "unknown"
        val contactId = intent.getStringExtra("contactId") ?: ""

        Log.i(tag, "Triggered reminderId=$reminderId phone=$phoneNumber messageLength=${message.length}")
        SmsStatusStore.writeTimelineEvent(context, reminderId, phoneNumber, message, "triggered", "Triggered", "Background alarm fired.")

        if (phoneNumber.isBlank() || message.isBlank()) {
            val reason = "Missing phone number or message"
            Log.w(tag, "Blocked reminderId=$reminderId reason=$reason")
            writeSendLog(context, reminderId, phoneNumber, message, "blocked", reason)
            SmsStatusStore.writeTimelineEvent(context, reminderId, phoneNumber, message, "blocked", "Blocked", reason)
            return
        }

        if (!hasSendSmsPermission(context)) {
            val reason = "SMS permission missing"
            Log.w(tag, "Failed reminderId=$reminderId reason=$reason")
            writeSendLog(context, reminderId, phoneNumber, message, "failed", reason)
            SmsStatusStore.writeTimelineEvent(context, reminderId, phoneNumber, message, "failed", "Failed", reason)
            return
        }

        val doNotSendReason = doNotSendBlockReason(context, contactId)
        if (doNotSendReason != null) {
            Log.w(tag, "Blocked reminderId=$reminderId reason=$doNotSendReason")
            writeSendLog(context, reminderId, phoneNumber, message, "blocked", doNotSendReason)
            SmsStatusStore.writeTimelineEvent(context, reminderId, phoneNumber, message, "blocked", "Blocked", doNotSendReason)
            return
        }

        val rateLimitReason = rateLimitBlockReason(context)
        if (rateLimitReason != null) {
            Log.w(tag, "Blocked reminderId=$reminderId reason=$rateLimitReason")
            writeSendLog(context, reminderId, phoneNumber, message, "blocked", rateLimitReason)
            SmsStatusStore.writeTimelineEvent(context, reminderId, phoneNumber, message, "blocked", "Blocked", rateLimitReason)
            return
        }

        val duplicateReason = duplicateReminderBlockReason(context, reminderId)
        if (duplicateReason != null) {
            Log.w(tag, "Blocked reminderId=$reminderId reason=$duplicateReason")
            writeSendLog(context, reminderId, phoneNumber, message, "blocked", duplicateReason)
            SmsStatusStore.writeTimelineEvent(context, reminderId, phoneNumber, message, "blocked", "Blocked", duplicateReason)
            return
        }

        try {
            sendSms(context, reminderId, phoneNumber, message)
            writeSendLog(context, reminderId, phoneNumber, message, "sent", null)
            SmsStatusStore.writeTimelineEvent(context, reminderId, phoneNumber, message, "sent", "Sent", "SMS handed to Android SmsManager.")
            Log.i(tag, "Sent reminderId=$reminderId phone=$phoneNumber")
        } catch (error: Exception) {
            val reason = error.message ?: "Unknown send error"
            Log.e(tag, "Failed reminderId=$reminderId reason=$reason", error)
            writeSendLog(context, reminderId, phoneNumber, message, "failed", reason)
            SmsStatusStore.writeTimelineEvent(context, reminderId, phoneNumber, message, "failed", "Failed", reason)
        }
    }

    private fun hasSendSmsPermission(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun sendSms(context: Context, reminderId: String, phoneNumber: String, message: String) {
        val smsManager = SmsManager.getDefault()
        val parts = smsManager.divideMessage(message)
        val sentIntents = ArrayList<PendingIntent>()
        val deliveredIntents = ArrayList<PendingIntent>()

        for (index in parts.indices) {
            sentIntents.add(createSmsStatusPendingIntent(context, SmsSentReceiver::class.java, reminderId, phoneNumber, message, index, "sent"))
            deliveredIntents.add(createSmsStatusPendingIntent(context, SmsDeliveredReceiver::class.java, reminderId, phoneNumber, message, index, "delivered"))
        }

        if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(phoneNumber, null, parts, sentIntents, deliveredIntents)
        } else {
            smsManager.sendTextMessage(phoneNumber, null, message, sentIntents.firstOrNull(), deliveredIntents.firstOrNull())
        }
    }

    private fun createSmsStatusPendingIntent(
        context: Context,
        receiverClass: Class<*>,
        reminderId: String,
        phoneNumber: String,
        message: String,
        partIndex: Int,
        event: String
    ): PendingIntent {
        val intent = Intent(context, receiverClass).apply {
            action = "text_helper.sms.$event.$reminderId.$partIndex.${System.nanoTime()}"
            putExtra("reminderId", reminderId)
            putExtra("phoneNumber", phoneNumber)
            putExtra("message", message)
            putExtra("partIndex", partIndex)
        }

        return PendingIntent.getBroadcast(
            context,
            intent.action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun flutterPrefs(context: Context) = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun nowIso(): String = Instant.now().toString()

    private fun doNotSendBlockReason(context: Context, contactId: String): String? {
        if (contactId.isBlank()) return null

        val raw = flutterPrefs(context).getString("flutter.text_helper_contact_groups", "[]") ?: "[]"
        val groups = JSONArray(raw)

        for (index in 0 until groups.length()) {
            val group = groups.optJSONObject(index) ?: continue
            if (!group.optBoolean("isBlockedGroup", false)) continue
            val contactIds = group.optJSONArray("contactIds") ?: continue
            for (contactIndex in 0 until contactIds.length()) {
                if (contactIds.optString(contactIndex) == contactId) {
                    return "Blocked: contact is in Do Not Send group \"${group.optString("name", "Do Not Send")}\"."
                }
            }
        }

        return null
    }

    private fun rateLimitBlockReason(context: Context): String? {
        val raw = flutterPrefs(context).getString("flutter.text_helper_send_log", "[]") ?: "[]"
        val array = JSONArray(raw)
        val now = System.currentTimeMillis()
        var sentMinute = 0
        var sentHour = 0
        var sentDay = 0

        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            if (item.optString("status") != "sent") continue
            val createdMillis = try {
                Instant.parse(item.optString("createdAt")).toEpochMilli()
            } catch (_: Exception) {
                0L
            }
            if (createdMillis >= now - 60_000L) sentMinute += 1
            if (createdMillis >= now - 3_600_000L) sentHour += 1
            if (createdMillis >= now - 86_400_000L) sentDay += 1
        }

        if (sentMinute >= 5) return "Rate limit hit: 5 sends already happened in the last minute. Wait 60 seconds or use 60-second spacing for testing."
        if (sentHour >= 30) return "Rate limit hit: too many sends in the last hour."
        if (sentDay >= 100) return "Rate limit hit: too many sends in the last day."
        return null
    }

    private fun duplicateReminderBlockReason(context: Context, reminderId: String): String? {
        val raw = flutterPrefs(context).getString("flutter.text_helper_send_log", "[]") ?: "[]"
        val array = JSONArray(raw)

        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            if (item.optString("status") != "sent") continue
            if (item.optString("reminderId") == reminderId) {
                return "This reminder ID has already been sent."
            }
        }

        return null
    }

    private fun writeSendLog(context: Context, reminderId: String, phoneNumber: String, message: String, status: String, error: String?) {
        val prefs = flutterPrefs(context)
        val key = "flutter.text_helper_send_log"
        val oldArray = JSONArray(prefs.getString(key, "[]") ?: "[]")
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
}
