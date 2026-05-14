import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final featureGroups = <_FeatureGroup>[
      const _FeatureGroup(
        icon: CupertinoIcons.person_2_fill,
        title: 'Contact book upgrades',
        description:
            'The contact book now supports richer contact records and faster follow-up actions.',
        features: [
          'Name, phone, email, company or group, notes, and tags.',
          'Favorite contacts for quick access.',
          'Search across names, phone numbers, email, company, notes, and tags.',
          'Duplicate phone-number protection.',
          'Last-contacted tracking.',
          'Quick actions for text, schedule, call, email, and mark contacted.',
        ],
      ),
      const _FeatureGroup(
        icon: CupertinoIcons.calendar,
        title: 'Visual scheduling center',
        description:
            'Scheduling is now easier to scan, filter, and action from one queue.',
        features: [
          'Due, upcoming, sent, cancelled, and all filters.',
          'Visual stat cards for queue health.',
          'Priority levels: low, normal, high, and urgent.',
          'Due and overdue status chips.',
          'Relative time labels such as in 30 minutes or 2 days overdue.',
          'Edit, cancel, duplicate, open SMS, and mark sent actions.',
        ],
      ),
      const _FeatureGroup(
        icon: CupertinoIcons.chat_bubble_text_fill,
        title: 'Message workflow',
        description:
            'Scheduled text handling now has clearer draft and send states.',
        features: [
          'Message templates for faster scheduling.',
          'SMS opens with the message prefilled.',
          'Manual mark-sent flow after the SMS app opens.',
          'Safer schedule editing and rescheduling.',
        ],
      ),
      const _FeatureGroup(
        icon: CupertinoIcons.shield_fill,
        title: 'Reliability fixes',
        description:
            'The app now handles local data and analyzer-sensitive code more safely.',
        features: [
          'Safer local JSON loading.',
          'Corrupt saved records are skipped instead of crashing the screen.',
          'Fixed invalid Cupertino icon references.',
          'Fixed WhatsApp analyzer errors.',
          'Reduced deprecated Flutter API usage where practical.',
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('What\'s New'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          const _HeroCard(),
          const SizedBox(height: 16),
          ...featureGroups.map((group) => _FeatureGroupCard(group: group)),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.star_fill,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'New build highlights',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'A quick overview of the new contact book, scheduling, message workflow, and reliability improvements.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGroup {
  const _FeatureGroup({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
}

class _FeatureGroupCard extends StatelessWidget {
  const _FeatureGroupCard({required this.group});

  final _FeatureGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  group.icon,
                  color: const Color(0xFF0A84FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.description,
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
          const SizedBox(height: 14),
          ...group.features.map((feature) => _FeatureBullet(feature)),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.check_mark_circled_solid,
            size: 18,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
