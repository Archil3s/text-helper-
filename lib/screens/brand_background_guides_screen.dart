import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BrandBackgroundGuidesScreen extends StatelessWidget {
  const BrandBackgroundGuidesScreen({super.key});

  static const List<_BrandGuide> _guides = [
    _BrandGuide(
      brand: 'Samsung / Galaxy',
      subtitle: 'Sleeping apps, battery usage, and notifications',
      steps: [
        _GuideStep(
          title: 'Set battery to unrestricted',
          body:
              'Open Settings > Apps > Text Helper > Battery. Choose Unrestricted or allow background battery usage where available.',
        ),
        _GuideStep(
          title: 'Remove from Sleeping apps',
          body:
              'Open Settings > Battery and device care > Battery > Background usage limits. Remove Text Helper from Sleeping apps and Deep sleeping apps.',
        ),
        _GuideStep(
          title: 'Allow notifications',
          body:
              'Open Settings > Apps > Text Helper > Notifications. Allow notifications and make sure reminder channels are enabled.',
        ),
        _GuideStep(
          title: 'Avoid force stop',
          body:
              'If the app is force-stopped from Android settings, Android may block alarms until Text Helper is opened again.',
        ),
      ],
    ),
    _BrandGuide(
      brand: 'Xiaomi / Redmi / POCO',
      subtitle: 'Auto-start, battery saver, app lock, and permissions',
      steps: [
        _GuideStep(
          title: 'Enable Auto-start',
          body:
              'Open Settings > Apps > Permissions > Autostart. Allow Text Helper to start automatically.',
        ),
        _GuideStep(
          title: 'Disable battery restrictions',
          body:
              'Open Settings > Battery > Battery saver > App battery saver. Set Text Helper to No restrictions.',
        ),
        _GuideStep(
          title: 'Lock the app in Recents',
          body:
              'Open Text Helper, open the recent apps screen, long-press the app card if your device supports it, and lock it to reduce background killing.',
        ),
        _GuideStep(
          title: 'Allow lock-screen activity',
          body:
              'If available, allow Text Helper to show notifications and background activity while the screen is locked.',
        ),
      ],
    ),
    _BrandGuide(
      brand: 'Oppo / Realme / OnePlus',
      subtitle: 'Auto launch, battery optimization, and background activity',
      steps: [
        _GuideStep(
          title: 'Allow Auto launch',
          body:
              'Open Settings > Apps > App management > Text Helper. Allow Auto launch or Auto start if your phone shows that option.',
        ),
        _GuideStep(
          title: 'Allow background activity',
          body:
              'Open Settings > Battery > More battery settings or App battery management. Allow background activity for Text Helper.',
        ),
        _GuideStep(
          title: 'Disable app quick freeze',
          body:
              'If your phone has App Quick Freeze or Sleep standby optimization, exclude Text Helper.',
        ),
        _GuideStep(
          title: 'Check exact alarm settings',
          body:
              'Open Text Helper Background Wizard and verify exact alarm permission after changing system battery settings.',
        ),
      ],
    ),
    _BrandGuide(
      brand: 'Vivo / iQOO',
      subtitle: 'Background power consumption and auto-start',
      steps: [
        _GuideStep(
          title: 'Enable auto-start',
          body:
              'Open Settings > Apps > Permission management > Autostart. Allow Text Helper.',
        ),
        _GuideStep(
          title: 'Allow background power usage',
          body:
              'Open Settings > Battery > Background power consumption management. Allow Text Helper to run in the background.',
        ),
        _GuideStep(
          title: 'Disable high background restriction',
          body:
              'If the phone warns about high background power, choose allow or do not restrict for Text Helper.',
        ),
        _GuideStep(
          title: 'Test with the screen locked',
          body:
              'Queue a test text two minutes ahead, lock the phone, and verify whether the Background Wizard and Timeline show the trigger.',
        ),
      ],
    ),
    _BrandGuide(
      brand: 'Huawei / Honor',
      subtitle: 'App launch management and battery optimization',
      steps: [
        _GuideStep(
          title: 'Use manual App launch',
          body:
              'Open Settings > Battery > App launch. Turn off Manage automatically for Text Helper, then allow Auto-launch, Secondary launch, and Run in background.',
        ),
        _GuideStep(
          title: 'Disable battery optimization',
          body:
              'Open Settings > Apps > Apps > Text Helper > Battery. Allow background activity where available.',
        ),
        _GuideStep(
          title: 'Allow notifications',
          body:
              'Open Settings > Notifications > Text Helper. Allow notifications and lock-screen notifications.',
        ),
        _GuideStep(
          title: 'Re-test after reboot',
          body:
              'Some Huawei/Honor devices reset background behavior after reboot. Open Text Helper and re-run the Background Wizard after system updates.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final totalSteps = _guides.fold<int>(
      0,
      (sum, guide) => sum + guide.steps.length,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Device Setup Guides'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _GuidesHero(
            brands: _guides.length,
            steps: totalSteps,
          ),
          const SizedBox(height: 20),
          const _SurfaceCard(
            child: Text(
              'Android manufacturers often add their own battery and background restrictions. These guides help users find the settings most likely to affect closed-app scheduled SMS sending.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const _SurfaceCard(
            child: Text(
              'After changing device settings, run Background Wizard again, queue a test text, lock the phone, and check Message Timeline / Delivery Receipts.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Brand guides',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ..._guides.map(
            (guide) => _BrandGuideCard(guide: guide),
          ),
          const SizedBox(height: 12),
          const _SurfaceCard(
            child: Text(
              'Menu names can vary by Android version, carrier, and region. If a setting name is slightly different, look for equivalent battery, auto-start, app launch, sleeping app, or background activity controls.',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandGuide {
  const _BrandGuide({
    required this.brand,
    required this.subtitle,
    required this.steps,
  });

  final String brand;
  final String subtitle;
  final List<_GuideStep> steps;
}

class _GuideStep {
  const _GuideStep({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _GuidesHero extends StatelessWidget {
  const _GuidesHero({
    required this.brands,
    required this.steps,
  });

  final int brands;
  final int steps;

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
            Icons.phone_android_outlined,
            color: Colors.white,
            size: 34,
          ),
          const SizedBox(height: 16),
          const Text(
            'Device setup guides',
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
            'Brand-specific settings for battery, auto-start, app launch, and lock-screen behavior.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '$brands', label: 'brands'),
              const SizedBox(width: 10),
              _HeroMetric(value: '$steps', label: 'steps'),
              const SizedBox(width: 10),
              const _HeroMetric(value: 'TEST', label: 'after setup'),
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

class _BrandGuideCard extends StatelessWidget {
  const _BrandGuideCard({required this.guide});

  final _BrandGuide guide;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        leading: const Icon(
          Icons.phone_android_outlined,
          color: Color(0xFF0A84FF),
        ),
        title: Text(
          guide.brand,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          guide.subtitle,
          style: const TextStyle(
            color: CupertinoColors.secondaryLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          ...guide.steps.asMap().entries.map(
                (entry) => _GuideStepTile(
                  number: entry.key + 1,
                  step: entry.value,
                ),
              ),
        ],
      ),
    );
  }
}

class _GuideStepTile extends StatelessWidget {
  const _GuideStepTile({
    required this.number,
    required this.step,
  });

  final int number;
  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFF0A84FF).withValues(alpha: 0.12),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF0A84FF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.body,
                  style: const TextStyle(
                    color: CupertinoColors.secondaryLabel,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
