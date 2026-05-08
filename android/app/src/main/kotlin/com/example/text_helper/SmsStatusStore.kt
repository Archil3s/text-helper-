package com.example.text_helper

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

object SmsStatusStore {
    private const val deliveryKey = "flutter.text_helper_delivery_receipts"
    private const val timelineKey = "flutter.text_helper_message_timeline_events"

    private fun flutterPrefs(context: Context) =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun nowIso(): String = Instant.now().toString()

    fun writeDeliveryReceipt(
        context: Context,
        reminderId: String,
        phoneNumber: String,
        message: String,
        event: String,
        status: String,
        resultCode: Int,
        errorMessage: String?
    ) {
        val json = JSONObject()
        json.put("id", "${System.nanoTime()}-$event")
        json.put("reminderId", reminderId)
        json.put("phoneNumber", phoneNumber)
        json.put("message", message)
        json.put("event", event)
        json.put("status", status)
        json.put("resultCode", resultCode)
        json.put("errorMessage", errorMessage)
        json.put("createdAt", nowIso())

        prependJson(context, deliveryKey, json, 1000)
    }

    fun writeTimelineEvent(
        context: Context,
        reminderId: String,
        phoneNumber: String,
        message: String,
        status: String,
        title: String,
        detail: String
    ) {
        val json = JSONObject()
        json.put("id", "${System.nanoTime()}-$status")
        json.put("reminderId", reminderId)
        json.put("phoneNumber", phoneNumber)
        json.put("message", message)
        json.put("status", status)
        json.put("title", title)
        json.put("detail", detail)
        json.put("createdAt", nowIso())

        prependJson(context, timelineKey, json, 1000)
    }

    private fun prependJson(context: Context, key: String, json: JSONObject, maxItems: Int) {
        val prefs = flutterPrefs(context)
        val raw = prefs.getString(key, "[]") ?: "[]"
        val oldArray = JSONArray(raw)
        val newArray = JSONArray()

        newArray.put(json)

        val max = minOf(oldArray.length(), maxItems - 1)
        for (index in 0 until max) {
            newArray.put(oldArray.get(index))
        }

        prefs.edit().putString(key, newArray.toString()).apply()
    }
}
