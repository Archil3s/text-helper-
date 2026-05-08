import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/delivery_receipt_event.dart';
import '../services/delivery_receipt_store.dart';

class DeliveryReceiptsScreen extends StatefulWidget {
  const DeliveryReceiptsScreen({super.key});

  @override
  State<DeliveryReceiptsScreen> createState() => _DeliveryReceiptsScreenState();
}

class _DeliveryReceiptsScreenState extends State<DeliveryReceiptsScreen> {
  final DeliveryReceiptStore _store = DeliveryReceiptStore();

  List<DeliveryReceiptEvent> _receipts = <DeliveryReceiptEvent>[];

  bool _loading = true;

  String _status = 'Delivery receipts loaded.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final receipts = await _store.loadReceipts();

    if (!mounted) {
      return;
    }

    setState(() {
      _receipts = receipts;
      _loading = false;
      _status = 'Showing ${receipts.length} receipt event(s).';
    });
  }

  Future<void> _clear() async {
    await _store.clearReceipts();
    await _load();

    if (!mounted) {
      return;
    }

    setState(() => _status = 'Delivery receipt events cleared.');
  }

  int get _sentCount {
    return _receipts.where((item) => item.isSentToAndroid).length;
  }

  int get _deliveredCount {
    return _receipts.where((item) => item.isDelivered).length;
  }

  int get _failedCount {
    return _receipts.where((item) => item.isFailed).length;
  }

  String _format(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Color _color(DeliveryReceiptEvent event) {
    if (event.isDelivered) {
      return const Color(0xFF16A34A);
    }

    if (event.isSentToAndroid) {
      return const Color(0xFF0A84FF);
    }

    if (event.isFailed) {
      return const Color(0xFFEF4444);
    }

    return const Color(0xFF6B7280);
  }

  IconData _icon(DeliveryReceiptEvent event) {
    if (event.isDelivered) {
      return CupertinoIcons.check_mark_circled_solid;
    }

    if (event.isSentToAndroid) {
      return CupertinoIcons.paperplane_fill;
    }

    if (event.isFailed) {
      return CupertinoIcons.xmark_circle_fill;
    }

    return CupertinoIcons.info_circle_fill;
  }

  String _label(DeliveryReceiptEvent event) {
    return switch (event.status) {
      'sent_to_android_sms' => 'Sent to Android SMS service',
      'delivered' => 'Delivered',
      'send_failed' => 'Send failed',
      'delivery_failed' => 'Delivery failed',
      _ => event.status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Delivery Receipts'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(CupertinoIcons.refresh),
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(CupertinoIcons.trash),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ReceiptsHero(
                  total: _receipts.length,
                  sent: _sentCount,
                  delivered: _deliveredCount,
                  failed: _failedCount,
                ),
                const SizedBox(height: 20),
                _StatusCard(status: _status),
                const SizedBox(height: 12),
                const _SurfaceCard(
                  child: Text(
                    'Delivery receipts depend on Android, the SIM/carrier, and the recipient network. The app only shows “Delivered” when Android receives a real delivery callback. Otherwise, use “Sent to Android SMS service.”',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Receipt events',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (_receipts.isEmpty)
                  const _SurfaceCard(
                    child: Text(
                      'No delivery receipt events yet.',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ..._receipts.map(
                    (event) => _ReceiptCard(
                      event: event,
                      color: _color(event),
                      icon: _icon(event),
                      label: _label(event),
                      dateTime: _format(event.createdAt),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ReceiptsHero extends StatelessWidget {
  const _ReceiptsHero({
    required this.total,
    required this.sent,
    required this.delivered,
    required this.failed,
  });

  final int total;
  final int sent;
  final int delivered;
  final int failed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1D4ED8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Delivery receipts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track Android sent callbacks and carrier delivery callbacks when available.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$total', label: 'total'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$sent', label: 'sent'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$delivered', label: 'delivered'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$failed', label: 'failed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.event,
    required this.color,
    required this.icon,
    required this.label,
    required this.dateTime,
  });

  final DeliveryReceiptEvent event;
  final Color color;
  final IconData icon;
  final String label;
  final String dateTime;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      borderColor: event.isFailed ? color : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateTime,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.phoneNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  event.message,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.errorMessage != null &&
                    event.errorMessage!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event.errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            event.event.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.info_circle_fill,
            color: Color(0xFF0A84FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.borderColor,
  });

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
