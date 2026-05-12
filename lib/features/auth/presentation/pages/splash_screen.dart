import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/storage_service.dart';

/// Bootstrap route: short branded moment, then [GoRouter] sends user onward.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 1400);

  late final AnimationController _controller;

  // Icon: fade-in + scale (0–500ms)
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;

  // Logo: fade-in + slide-up (200–700ms)
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoSlide;

  // Progress bar: fade-in + fill (400–1000ms)
  late final Animation<double> _progressOpacity;
  late final Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Icon: 0ms–500ms
    _iconOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 500 / 1200, curve: Curves.easeOutCubic),
      ),
    );
    _iconScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 500 / 1200, curve: Curves.easeOutCubic),
      ),
    );

    // Logo: 200ms–700ms
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(200 / 1200, 700 / 1200, curve: Curves.easeOutCubic),
      ),
    );
    _logoSlide = Tween(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(200 / 1200, 700 / 1200, curve: Curves.easeOutCubic),
      ),
    );

    // Progress: 400ms–1000ms
    _progressOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(400 / 1200, 600 / 1200, curve: Curves.easeOut),
      ),
    );
    _progressValue = Tween(begin: 0.05, end: 0.92).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(400 / 1200, 1.0, curve: Curves.easeInOutCubic),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                // App icon
                Opacity(
                  opacity: _iconOpacity.value,
                  child: Transform.scale(
                    scale: _iconScale.value,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/branding/app_icon.png',
                        width: 120,
                        height: 120,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Logo
                SlideTransition(
                  position: _logoSlide,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: Image.asset(
                      'assets/branding/logo_full.png',
                      width: 280,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: Opacity(
                    opacity: _progressOpacity.value,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 3,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(
                              color: Color(0xFFE5E7EB), // gray-200
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _progressValue.value.clamp(0.0, 1.0),
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0xFF0F766E), // teal-700
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }
}
