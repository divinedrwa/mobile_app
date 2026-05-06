import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/storage_service.dart';

/// Bootstrap route: short branded moment, then [GoRouter] sends user onward.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _holdDuration = Duration(milliseconds: 950);

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future<void>.delayed(_holdDuration);

    final token = StorageService.getToken();
    final hasSession = token != null && token.isNotEmpty;

    String target = '/society-select';
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
            target = '/admin';
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SplashBackdrop(),
          // Soft top light — depth without clutter
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            height: 280,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 24, 28, 12 + bottomInset),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _SplashMark()
                      .animate()
                      .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
                      .scale(
                        begin: const Offset(0.92, 0.92),
                        duration: 550.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 30),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 34,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.9,
                      color: Colors.white,
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: 120.ms,
                        duration: 550.ms,
                        curve: Curves.easeOut,
                      )
                      .slideY(
                        begin: 0.12,
                        end: 0,
                        delay: 120.ms,
                        duration: 550.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 8),
                  Text(
                    'Society Management Platform',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ).animate().fadeIn(delay: 240.ms, duration: 550.ms),
                  const SizedBox(height: 18),
                  _SplashCapabilityRow()
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 500.ms),
                  const Spacer(flex: 2),
                  _SplashProgressBar()
                      .animate()
                      .fadeIn(delay: 320.ms, duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Secure · Resident · Gate',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.6,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignColors.primaryDark,
            DesignColors.primary,
            DesignColors.primaryLight,
          ],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.apartment_rounded,
            size: 62,
            color: DesignColors.primary.withValues(alpha: 0.24),
          ),
          const Icon(
            Icons.shield_rounded,
            size: 40,
            color: DesignColors.primary,
          ),
          const Positioned(
            bottom: 26,
            child: Icon(
              Icons.check_rounded,
              size: 15,
              color: DesignColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashCapabilityRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: Colors.white.withValues(alpha: 0.88),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _CapabilityChip(icon: Icons.vpn_key_rounded, label: 'Visitor Access', style: style),
        _CapabilityChip(icon: Icons.payments_rounded, label: 'Billing', style: style),
        _CapabilityChip(icon: Icons.campaign_rounded, label: 'Notices', style: style),
      ],
    );
  }
}

class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip({
    required this.icon,
    required this.label,
    required this.style,
  });

  final IconData icon;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 5),
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}

class _SplashProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 3,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.08, end: 0.92),
          duration: const Duration(milliseconds: 820),
          curve: Curves.easeInOutCubic,
          builder: (context, value, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
