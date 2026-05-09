import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DeliveryStatusMapper {
  const DeliveryStatusMapper._();

  static String normalize(String status) {
    final value = status.trim().toLowerCase();

    return switch (value) {
      'sent' => 'sent_to_android',
      'sent_to_android_sms' => 'sent_to_android',
      'sent_to_android' => 'sent_to_android',
      'send_failed' => 'failed',
      'delivery_failed' => 'delivery_failed',
      'failed' => 'failed',
      'delivered' => 'delivered',
      'blocked_duplicate' => 'blocked',
      'blocked' => 'blocked',
      'retrying' => 'retrying',
      'attempting' => 'attempting',
      'queued' => 'queued',
      'pending' => 'queued',
      'skipped' => 'skipped',
      'cancelled' => 'cancelled',
      'background_synced' => 'background_synced',
      'triggered' => 'triggered',
      _ => value.isEmpty ? 'unknown' : value,
    };
  }

  static bool isSentToAndroid(String status) {
    return normalize(status) == 'sent_to_android';
  }

  static bool isDelivered(String status) {
    return normalize(status) == 'delivered';
  }

  static bool isFailed(String status) {
    final value = normalize(status);
    return value == 'failed' || value == 'delivery_failed';
  }

  static bool isBlocked(String status) {
    return normalize(status) == 'blocked';
  }

  static String label(String status) {
    return switch (normalize(status)) {
      'queued' => 'Queued',
      'attempting' => 'Attempting',
      'sent_to_android' => 'Sent to Android SMS service',
      'delivered' => 'Delivered',
      'failed' => 'Failed',
      'delivery_failed' => 'Delivery failed',
      'blocked' => 'Blocked',
      'skipped' => 'Skipped',
      'retrying' => 'Retrying',
      'cancelled' => 'Cancelled',
      'background_synced' => 'Background alarm synced',
      'triggered' => 'Triggered',
      _ => 'Unknown',
    };
  }

  static Color color(String status) {
    return switch (normalize(status)) {
      'delivered' => const Color(0xFF16A34A),
      'sent_to_android' => const Color(0xFF0A84FF),
      'queued' => const Color(0xFF0A84FF),
      'attempting' => const Color(0xFF0A84FF),
      'retrying' => const Color(0xFF0A84FF),
      'background_synced' => const Color(0xFF6366F1),
      'triggered' => const Color(0xFFF97316),
      'blocked' => const Color(0xFFF97316),
      'skipped' => const Color(0xFF6B7280),
      'cancelled' => const Color(0xFF6B7280),
      'failed' => const Color(0xFFEF4444),
      'delivery_failed' => const Color(0xFFEF4444),
      _ => const Color(0xFF6B7280),
    };
  }

  static IconData icon(String status) {
    return switch (normalize(status)) {
      'delivered' => CupertinoIcons.check_mark_circled_solid,
      'sent_to_android' => CupertinoIcons.paperplane_fill,
      'queued' => CupertinoIcons.tray_fill,
      'attempting' => CupertinoIcons.paperplane_fill,
      'retrying' => CupertinoIcons.arrow_clockwise,
      'background_synced' => CupertinoIcons.cloud_upload_fill,
      'triggered' => CupertinoIcons.bell_fill,
      'blocked' => CupertinoIcons.shield_fill,
      'skipped' => CupertinoIcons.forward_end_fill,
      'cancelled' => CupertinoIcons.minus_circle_fill,
      'failed' => CupertinoIcons.xmark_circle_fill,
      'delivery_failed' => CupertinoIcons.xmark_circle_fill,
      _ => CupertinoIcons.info_circle_fill,
    };
  }
}
