package com.example.text_helper

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SmsDeliveredReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getStringExtra("reminderId") ?: ""
        val phoneNumber = intent.getStringExtra("phoneNumber") ?: ""
        val message = intent.getStringExtra("message") ?: ""

        val delivered = resultCode == Activity.RESULT_OK
        val status = if (delivered) "delivered" else "delivery_failed"
        val title = if (delivered) "Delivered" else "Delivery failed"
        val detail = if (delivered) {
            "Carrier/device delivery callback received."
        } else {
            "Delivery callback failed or was rejected. Result code: $resultCode"
        }

        SmsStatusStore.writeDeliveryReceipt(
            context = context,
            reminderId = reminderId,
            phoneNumber = phoneNumber,
            message = message,
            event = "delivered",
            status = status,
            resultCode = resultCode,
            errorMessage = if (delivered) null else detail
        )

        SmsStatusStore.writeTimelineEvent(
            context = context,
            reminderId = reminderId,
            phoneNumber = phoneNumber,
            message = message,
            status = if (delivered) "delivered" else "failed",
            title = title,
            detail = detail
        )
    }
}
