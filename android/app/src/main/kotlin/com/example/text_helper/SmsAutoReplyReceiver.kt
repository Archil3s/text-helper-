package com.example.text_helper

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsManager
import org.json.JSONArray

class SmsAutoReplyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val masterEnabled = prefs.getBoolean(
            "flutter.text_helper_auto_reply_master_enabled",
            true
        )

        if (!masterEnabled) {
            return
        }

        val rulesRaw = prefs.getString("flutter.text_helper_auto_reply_rules", "[]") ?: "[]"
        val allowedRaw = prefs.getString("flutter.text_helper_auto_reply_allowed_numbers", "[]") ?: "[]"

        val allowedNumbers = parseAllowedNumbers(allowedRaw)

        if (allowedNumbers.isEmpty()) {
            return
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)

        if (messages.isEmpty()) {
            return
        }

        val sender = messages.firstOrNull()?.originatingAddress ?: return
        val senderDigits = normalizeNumber(sender)

        if (!isAllowedSender(senderDigits, allowedNumbers)) {
            return
        }

        val body = messages.joinToString(separator = "") { message ->
            message.messageBody ?: ""
        }.lowercase()

        if (body.isBlank()) {
            return
        }

        val rules = JSONArray(rulesRaw)
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
            } catch (_: Exception) {
                return
            }

            return
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
        } catch (_: Exception) {}

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
}