import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/society_theme_cache.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../theme/theme_controller.dart';
import '../../../../theme/app_colors.dart';
import '../widgets/auth_brand_logo.dart';

/// GatePass+ brand colors on the default splash (from [AppColorPalette] anchors).
const _splashNavy = AppColorPalette.brandNavy;
const _splashGreen = AppColorPalette.brandAccentGreen;

/// Splash screen — society-uploaded image when cached, otherwise the bundled
/// GatePass+ layout (background + logo + wordmark + loading footer).
class BrandedSplashScreen extends ConsumerStatefulWidget {
  const BrandedSplashScreen({super.key});

  @override
  ConsumerState<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends ConsumerState<BrandedSplashScreen>
    with TickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 2200);

  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  late final AnimationController _loadingController;
  late final Future<void> _splashReady;

  String? _localSplashPath;
  bool _useBundledFallback = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _splashReady = _prepareSplash();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sid = SocietyThemeCache.activeSocietyId();
      if (sid != null) syncSocietyThemeScope(ref, societyId: sid);
    });

    _navigateToNext();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _prepareSplash() async {
    final sid = SocietyThemeCache.activeSocietyId();
    if (sid == null) {
      if (mounted) setState(() => _useBundledFallback = true);
      return;
    }

    final existing = SocietyThemeCache.readSplashFilePath(sid);
    if (existing != null) {
      if (mounted) setState(() => _localSplashPath = existing);
      return;
    }

    final url = SocietyThemeCache.readSplashUrl(sid);
    if (url != null && url.isNotEmpty) {
      await SocietyThemeCache.ensureSplashFile(sid, url);
      final path = SocietyThemeCache.readSplashFilePath(sid);
      if (mounted) {
        setState(() {
          _localSplashPath = path;
          _useBundledFallback = path == null;
        });
      }
      return;
    }

    if (mounted) setState(() => _useBundledFallback = true);
  }

  Future<void> _prefetchSocietyAppearance() async {
    final sid = SocietyThemeCache.activeSocietyId();
    if (sid == null) return;

    if (SocietyThemeCache.readPalette(sid) != null) {
      syncSocietyThemeScope(ref, societyId: sid);
      refreshSocietyThemeFromServer(ref, societyId: sid);
      return;
    }

    await prefetchSocietyAppearance(ref, sid);
    final path = SocietyThemeCache.readSplashFilePath(sid);
    if (path != null && mounted && path != _localSplashPath) {
      setState(() => _localSplashPath = path);
    }
  }

  Future<void> _navigateToNext() async {
    // Hard-capped waits: the splash must ALWAYS navigate on, even when the
    // network stalls (backend cold start, dead connection). Theme/splash
    // fetches keep running in the background and apply whenever they finish.
    try {
      await _splashReady.timeout(const Duration(seconds: 10));
    } catch (_) {}
    await Future<void>.delayed(_holdDuration);
    try {
      await _prefetchSocietyAppearance().timeout(const Duration(seconds: 8));
    } catch (_) {}

    final token = await StorageService.getToken();
    final hasSession = token != null && token.isNotEmpty;

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
          case UserRole.residentCumAdmin:
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

  bool get _showCustomSplash =>
      _localSplashPath != null && _localSplashPath!.isNotEmpty;

  Widget _buildCustomSplashImage() {
    return Image.file(
      File(_localSplashPath!),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      gaplessPlayback: true,
    );
  }

  Widget _buildDefaultSplash() {
    final height = MediaQuery.sizeOf(context).height;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/splash/splash_background.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          gaplessPlayback: true,
        ),
        SafeArea(
          child: Column(
            children: [
              SizedBox(height: height * 0.10),
              const AuthBrandLogo(markWidth: 120),
              const Spacer(),
              const _SplashSlogan(),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _loadingController,
                builder: (context, _) => _SplashLoadingBar(
                  progress: _loadingController.value,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Loading your community...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.1,
                ),
              ),
              SizedBox(height: height * 0.055),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSplashBody() {
    if (_showCustomSplash) {
      return _buildCustomSplashImage();
    }
    if (_useBundledFallback) {
      return _buildDefaultSplash();
    }
    return const ColoredBox(color: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: _buildSplashBody(),
      ),
    );
  }
}

class _SplashSlogan extends StatelessWidget {
  const _SplashSlogan();

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      height: 1.2,
    );
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: base,
        children: [
          TextSpan(text: 'Reside. ', style: TextStyle(color: _splashNavy)),
          TextSpan(text: 'Approve. ', style: TextStyle(color: _splashGreen)),
          TextSpan(text: 'Manage.', style: TextStyle(color: _splashNavy)),
        ],
      ),
    );
  }
}

class _SplashLoadingBar extends StatelessWidget {
  const _SplashLoadingBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    const barWidth = 220.0;
    const barHeight = 3.0;
    const dotSize = 10.0;

    return SizedBox(
      width: barWidth,
      height: dotSize + 4,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barHeight),
              gradient: const LinearGradient(
                colors: [_splashNavy, _splashGreen],
              ),
            ),
          ),
          Positioned(
            left: (barWidth - dotSize) * progress,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: _splashGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _splashGreen.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
