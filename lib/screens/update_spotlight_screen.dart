import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contact_groups_screen.dart';
import 'home_screen.dart';
import 'whatsapp_handoff_screen.dart';

class UpdateSpotlightGate extends StatefulWidget {
  const UpdateSpotlightGate({super.key});

  @override
  State<UpdateSpotlightGate> createState() => _UpdateSpotlightGateState();
}

class _UpdateSpotlightGateState extends State<UpdateSpotlightGate> {
<<<<<<< HEAD
  static const String _updateId = '20260510-whatsapp-final';
=======
  static const String _updateId = '20260510-whatsapp-final';
>>>>>>> 7e3f768acfe4688c841349833193cf5b0589f332
  static const String _seenKey = 'text_helper_last_seen_update_spotlight';

  bool _loading = true;
  bool _showSpotlight = false;

  @override
  void initState() {
    super.initState();
    _loadSpotlightState();
  }

  Future<void> _loadSpotlightState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getString(_seenKey);

    if (!mounted) {
      return;
    }

    setState(() {
      _showSpotlight = lastSeen != _updateId;
      _loading = false;
    });
  }

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenKey, _updateId);
  }

  Future<void> _openUpdatedSection() async {
    await _markSeen();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const WhatsAppHandoffScreen(),
      ),
    );
  }

  Future<void> _continueHome() async {
    await _markSeen();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const WhatsAppHandoffScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F2F7),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_showSpotlight) {
      return const HomeScreen();
    }

    return UpdateSpotlightScreen(
      onOpenUpdatedSection: _openUpdatedSection,
      onContinueHome: _continueHome,
    );
  }
}

class UpdateSpotlightScreen extends StatelessWidget {
  const UpdateSpotlightScreen({
    super.key,
    required this.onOpenUpdatedSection,
    required this.onContinueHome,
  });

  final VoidCallback onOpenUpdatedSection;
  final VoidCallback onContinueHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _HeroCard(),
            const SizedBox(height: 20),
            const _SurfaceCard(
              borderColor: Color(0xFF16A34A),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    color: Color(0xFF16A34A),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Updated section',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'WhatsApp Handoff',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'This update opens the WhatsApp Handoff section so you can test the latest changed area after installing.',
                          style: TextStyle(
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
            ),
            const SizedBox(height: 12),
            const _SurfaceCard(
              child: Text(
                'This spotlight appears once per update id. Future releases can change the update id and target section.',
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpenUpdatedSection,
              icon: const Icon(CupertinoIcons.arrow_right_circle_fill),
              label: const Text('Open Updated Section'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(62),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onContinueHome,
              icon: const Icon(CupertinoIcons.house_fill),
              label: const Text('Continue to Home'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.bell_fill,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 16),
          Text(
            'What changed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Text Helper can now show the latest edited section after an update.',
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








