import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/image_url.dart';
import '../../../../core/utils/storage_service.dart';

/// Splash screen — shows the admin-uploaded splash image (cached) when present,
/// otherwise the bundled default splash asset, then navigates to the next route.
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

  @override
  Widget build(BuildContext context) {
    // Admin-uploaded splash (cached from a prior fetch) takes priority; otherwise
    // the bundled default splash asset. Both shown full-screen.
    final cachedSplash =
        StorageService.getString(AppConstants.keyCachedSplashUrl) ?? '';
    final hasUploaded = cachedSplash.isNotEmpty;

    Widget defaultSplash() => Image.asset(
          'assets/splash/splash_default.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );

    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: SizedBox.expand(
          child: hasUploaded
              ? CachedNetworkImage(
                  imageUrl: optimizedCloudinaryUrl(cachedSplash),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, _) => defaultSplash(),
                  errorWidget: (_, _, _) => defaultSplash(),
                )
              : defaultSplash(),
        ),
      ),
    );
  }
}
