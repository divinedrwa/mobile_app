import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/image_url.dart';
import '../../../../core/utils/storage_service.dart';

/// Splash screen — a brand-gradient backdrop (driven by the active society theme
/// via the cached palette) with the logo, then navigates to the next route.
class BrandedSplashScreen extends StatefulWidget {
  const BrandedSplashScreen({super.key});

  @override
  State<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends State<BrandedSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 2200);

  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

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

  static const _spinner = SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(
      strokeWidth: 2.4,
      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Over-the-air splash logo: served from the API origin (/brand/app-logo.png).
    // cached_network_image caches it to disk, so after the first launch it shows
    // instantly from cache; the bundled asset is the first-launch / offline fallback.
    final logoUrl =
        '${AppConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '')}/brand/app-logo.png';
    Widget bundledLogo() => Image.asset(
          'assets/branding/gp_logo.png',
          fit: BoxFit.contain,
        );

    // Brand gradient — stops follow the active society theme (the cached palette
    // is applied synchronously at startup, so this reflects the selected template).
    final brandGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        DesignColors.primaryDark,
        DesignColors.primary,
        DesignColors.secondary,
      ],
    );

    // Admin-uploaded splash image, cached from a prior fetch. Shown full-screen
    // under a brand-gradient tint so it always matches the theme.
    final cachedSplash =
        StorageService.getString(AppConstants.keyCachedSplashUrl) ?? '';
    final hasSplash = cachedSplash.isNotEmpty;

    if (hasSplash) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: optimizedCloudinaryUrl(cachedSplash),
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, _) =>
                  DecoratedBox(decoration: BoxDecoration(gradient: brandGradient)),
              errorWidget: (_, _, _) =>
                  DecoratedBox(decoration: BoxDecoration(gradient: brandGradient)),
            ),
            // Brand-color tint overlay so the uploaded image matches the theme.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DesignColors.primaryDark.withValues(alpha: 0.62),
                    DesignColors.primary.withValues(alpha: 0.50),
                    DesignColors.secondary.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
            FadeTransition(
              opacity: _fade,
              child: const Align(
                alignment: Alignment(0, 0.78),
                child: _spinner,
              ),
            ),
          ],
        ),
      );
    }

    // No uploaded splash — themed gradient + logo + name + tagline.
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: brandGradient),
        child: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: logoUrl,
                    fit: BoxFit.contain,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, _) => bundledLogo(),
                    errorWidget: (_, _, _) => bundledLogo(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 28),
                _spinner,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
