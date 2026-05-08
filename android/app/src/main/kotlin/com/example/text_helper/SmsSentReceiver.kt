package com.example.text_helper

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager

class SmsSentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getStringExtra("reminderId") ?: ""
        val phoneNumber = intent.getStringExtra("phoneNumber") ?: ""
        val message = intent.getStringExtra("message") ?: ""

        val error = if (resultCode == Activity.RESULT_OK) {
            null
        } else {
            sendErrorLabel(resultCode)
        }

        val status = if (resultCode == Activity.RESULT_OK) {
            "sent_to_android_sms"
        } else {
            "send_failed"
        }

        val title = if (resultCode == Activity.RESULT_OK) {
            "Sent to Android SMS service"
        } else {
            "Send failed"
        }

        SmsStatusStore.writeDeliveryReceipt(
            context = context,
            reminderId = reminderId,
            phoneNumber = phoneNumber,
            message = message,
            event = "sent",
            status = status,
            resultCode = resultCode,
            errorMessage = error
        )

        SmsStatusStore.writeTimelineEvent(
            context = context,
            reminderId = reminderId,
            phoneNumber = phoneNumber,
            message = message,
            status = if (resultCode == Activity.RESULT_OK) "sent" else "failed",
            title = title,
            detail = error ?: "Android SMS service accepted the send request."
        )
    }

    private fun sendErrorLabel(code: Int): String {
        return when (code) {
            SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "Generic SMS failure."
            SmsManager.RESULT_ERROR_NO_SERVICE -> "No cellular service."
            SmsManager.RESULT_ERROR_NULL_PDU -> "Null PDU."
            SmsManager.RESULT_ERROR_RADIO_OFF -> "Cellular radio is off."
            else -> "SMS send failed. Result code: $code"
        }
    }
}
