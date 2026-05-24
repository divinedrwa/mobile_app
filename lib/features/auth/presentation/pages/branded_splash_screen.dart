import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/storage_service.dart';

/// Premium GatePass+ splash screen built from the brand asset kit.
///
/// Layered composition:
/// 1. [splash_background.png] fills the screen (apartment scene + bottom
///    tagline ribbon are baked into the artwork).
/// 2. The brand mark, wordmark and feature row are positioned over the
///    upper half of the artwork.
class BrandedSplashScreen extends StatefulWidget {
  const BrandedSplashScreen({super.key});

  @override
  State<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends State<BrandedSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 2200);

  late final AnimationController _controller;
  late final Animation<double> _backgroundFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _featuresOpacity;
  late final Animation<Offset> _featuresSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Background washes in first (0–35%).
    _backgroundFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );

    // Logo: scale-in (5–45%).
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // Wordmark: fade + slight slide-up (25–60%).
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Feature row: fade + slide-up (45–80%).
    _featuresOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.8, curve: Curves.easeOut),
    );
    _featuresSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
    _navigateToNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToNext() async {
    await Future<void>.delayed(_holdDuration);

    final token = await StorageService.getToken();
    final hasSession = token != null && token.isNotEmpty;

    // Default to login if user already picked a society; otherwise society-select.
    final preferredSid = StorageService.getPreferredLoginSocietyId()?.trim() ?? '';
    String target = preferredSid.isNotEmpty ? '/login' : '/society-select';
    if (hasSession) {
      final rawRole = StorageService.getUserRole();
      if (rawRole != null && rawRole.isNotEmpty) {
        switch (UserRole.fromString(rawRole)) {
          case UserRole.superAdmin:
            await StorageService.clearAuthUserSession();
            DioClient.reset();
            break;
          case UserRole.resident:
            target = '/resident';
            break;
          case UserRole.guard:
            target = '/guard/dashboard';
            break;
          case UserRole.admin:
            target = '/resident';
            break;
        }
      } else {
        target = '/resident';
      }
    }

    if (mounted) {
      context.go(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              // Layer 1 — Brand background artwork (apartment scene + bottom
              // tagline ribbon are part of the image itself).
              Positioned.fill(
                child: FadeTransition(
                  opacity: _backgroundFade,
                  child: Image.asset(
                    'assets/splash/splash_background.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Layer 2 — Brand mark + wordmark + feature row.
              //
              // Top-aligned layout with fixed gaps. The Spacer at the
              // bottom lets the background artwork show through.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // GP brand mark.
                      FadeTransition(
                        opacity: _logoOpacity,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Image.asset(
                            'assets/splash/gp_logo.png',
                            width: 110,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Wordmark (includes "GatePass+" + tagline).
                      FadeTransition(
                        opacity: _wordmarkOpacity,
                        child: SlideTransition(
                          position: _wordmarkSlide,
                          child: Image.asset(
                            'assets/splash/gp_wordmark.png',
                            width: 240,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Feature icon row — sits in the clean white area
                      // above the apartment buildings in the background.
                      FadeTransition(
                        opacity: _featuresOpacity,
                        child: SlideTransition(
                          position: _featuresSlide,
                          child: const _FeatureRow(),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Initiative credit line.
                      FadeTransition(
                        opacity: _featuresOpacity,
                        child: SlideTransition(
                          position: _featuresSlide,
                          child: const Text(
                            'An initiative of Divine Residency Welfare Association',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.2,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),

                      // Rest of screen: background artwork shows through.
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontal row of four feature cards.
///
/// Each card uses an `Expanded` slot so the row stays balanced across phone
/// widths without overflow.
/// Horizontal row of four feature cards.
///
/// Each card uses an `Expanded` slot so the row stays balanced across phone
/// widths without overflow.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _FeatureTile(
              asset: 'assets/splash/icon_visitor.png',
              label: 'Visitor\nManagement',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _FeatureTile(
              asset: 'assets/splash/icon_maintenance.png',
              label: 'Maintenance\nPayments',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _FeatureTile(
              asset: 'assets/splash/icon_secure.png',
              label: 'Secure\nAccess',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _FeatureTile(
              asset: 'assets/splash/icon_community.png',
              label: 'Community\nCommunication',
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            asset,
            width: 46,
            height: 46,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
              height: 1.25,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
