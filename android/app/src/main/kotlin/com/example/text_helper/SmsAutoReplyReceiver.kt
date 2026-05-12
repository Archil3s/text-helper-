package com.example.text_helper

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import org.json.JSONArray

class SmsAutoReplyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Receiver invoked with action=${intent.action}")

        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d(TAG, "Ignored non-SMS action")
            return
        }

        if (!hasSmsPermissions(context)) {
            Log.w(TAG, "Missing SEND_SMS or RECEIVE_SMS permission")
            return
        }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val masterEnabled = prefs.getBoolean(
            "flutter.text_helper_auto_reply_master_enabled",
            true
        )

        if (!masterEnabled) {
            Log.d(TAG, "Auto Reply master switch is off")
            return
        }

        val rulesRaw = prefs.getString("flutter.text_helper_auto_reply_rules", "[]") ?: "[]"
        val allowedRaw = prefs.getString("flutter.text_helper_auto_reply_allowed_numbers", "[]") ?: "[]"

        val allowedNumbers = parseAllowedNumbers(allowedRaw)

        if (allowedNumbers.isEmpty()) {
            Log.d(TAG, "No approved sender numbers configured")
            return
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

        if (messages.isEmpty()) {
            Log.d(TAG, "No SMS messages found in intent")
            return
        }

        val sender = messages.firstOrNull()?.originatingAddress ?: run {
            Log.d(TAG, "SMS sender was empty")
            return
        }
        val senderDigits = normalizeNumber(sender)

        if (!isAllowedSender(senderDigits, allowedNumbers)) {
            Log.d(TAG, "Sender not approved: $senderDigits")
            return
        }

        val body = messages.joinToString(separator = "") { message ->
            message.messageBody ?: ""
        }.lowercase()

        if (body.isBlank()) {
            Log.d(TAG, "Incoming SMS body was blank")
            return
        }

        val rules = try {
            JSONArray(rulesRaw)
        } catch (error: Exception) {
            Log.e(TAG, "Could not parse auto-reply rules", error)
            return
        }

        val cooldownStore = context.getSharedPreferences(
            "text_helper_auto_reply_native",
            Context.MODE_PRIVATE
        )

        for (index in 0 until rules.length()) {
            val rule = rules.optJSONObject(index) ?: continue
            val enabled = rule.optBoolean("enabled", false)
            val keyword = rule.optString("keyword", "").lowercase().trim()
            val reply = rule.optString("reply", "").trim()
            val cooldownMinutes = rule.optInt("cooldownMinutes", 30)

            if (!enabled || keyword.isBlank() || reply.isBlank()) {
                continue
            }

            if (!body.contains(keyword)) {
                continue
            }

            val cooldownKey = "last_${senderDigits}_$keyword"
            val now = System.currentTimeMillis()
            val lastSent = cooldownStore.getLong(cooldownKey, 0L)
            val cooldownMillis = cooldownMinutes * 60L * 1000L

            if (now - lastSent < cooldownMillis) {
                Log.d(TAG, "Cooldown active for sender=$senderDigits keyword=$keyword")
                return
            }

            try {
                val smsManager = SmsManager.getDefault()
                val parts = smsManager.divideMessage(reply)

                if (parts.size > 1) {
                    smsManager.sendMultipartTextMessage(
                        sender,
                        null,
                        parts,
                        null,
                        null
                    )
                } else {
                    smsManager.sendTextMessage(
                        sender,
                        null,
                        reply,
                        null,
                        null
                    )
                }

                cooldownStore
                    .edit()
                    .putLong(cooldownKey, now)
                    .apply()

                Log.d(TAG, "Auto reply sent to sender=$senderDigits keyword=$keyword")
            } catch (error: Exception) {
                Log.e(TAG, "Auto reply failed", error)
                return
            }

            return
        }

        Log.d(TAG, "No enabled keyword rule matched incoming SMS")
    }

    private fun hasSmsPermissions(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED &&
                context.checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun parseAllowedNumbers(raw: String): List<String> {
        val numbers = mutableListOf<String>()

        try {
            val array = JSONArray(raw)

            for (index in 0 until array.length()) {
                val value = normalizeNumber(array.optString(index, ""))
                if (value.isNotBlank()) {
                    numbers.add(value)
                }
            }
        } catch (error: Exception) {
            Log.e(TAG, "Could not parse approved sender numbers", error)
        }

        return numbers
    }

    private fun normalizeNumber(value: String): String {
        return value.filter { character -> character.isDigit() }
    }

    private fun isAllowedSender(senderDigits: String, allowedNumbers: List<String>): Boolean {
        if (senderDigits.isBlank()) {
            return false
        }

        return allowedNumbers.any { allowed ->
            senderDigits.endsWith(allowed.takeLast(8)) ||
                allowed.endsWith(senderDigits.takeLast(8))
        }
    }

    companion object {
        private const val TAG = "TextHelperAutoReply"
    }
}
