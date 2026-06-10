import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/theme/design_haptics.dart';
import '../../../../../core/theme/design_tokens.dart';
import '../../../../../theme/context_extensions.dart';
import '../../../data/models/security_contact_model.dart';
import 'home_shared.dart';

class HomeSupportStrip extends StatelessWidget {
  const HomeSupportStrip({
    super.key,
    required this.securityContactsAsync,
  });

  final AsyncValue<List<SecurityContactModel>> securityContactsAsync;

  @override
  Widget build(BuildContext context) {
    final contacts = securityContactsAsync.maybeWhen(
      data: (list) =>
          list.where((c) => c.phone.trim().isNotEmpty).toList(),
      orElse: () => const <SecurityContactModel>[],
    );
    final primaryPhone =
        contacts.isNotEmpty ? contacts.first.phone.trim() : '100';
    final hasGuardContact = contacts.isNotEmpty;
    final securityLine = hasGuardContact
        ? 'Security: $primaryPhone'
        : 'Emergency: 100';

    Future<void> callSecurity() async {
      DesignHaptics.impact();
      final uri = Uri.parse('tel:$primaryPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    return Material(
      color: context.state.info.bg.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(kHomeRadiusLg),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(kHomeRadiusLg),
        onTap: callSecurity,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.brand.primary
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_outlined,
                    color: context.brand.primary, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Need help? Contact security',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.brand.primary,
                        height: 1.2,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      securityLine,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.text.secondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: callSecurity,
                icon: const Icon(Icons.phone, size: 13),
                label: const Text('Call security',
                    style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                    color: context.brand.primary
                        .withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: DesignRadius.borderMD,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
