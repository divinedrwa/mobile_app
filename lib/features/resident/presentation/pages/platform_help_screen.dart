import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/enterprise_ui.dart';

/// D3 — In-app platform capability matrix (web vs mobile).
class PlatformHelpScreen extends StatelessWidget {
  const PlatformHelpScreen({super.key});

  static const _rows = [
    ('Pay maintenance (Razorpay)', true, true, false),
    ('Pay maintenance (PhonePe / UPI)', true, false, false),
    ('Admin cash payment', false, false, true),
    ('Visitor approval', true, false, true),
    ('Guard walk-in check-in', true, false, true),
    ('Reconciliation', true, false, true),
    ('Push notifications', true, false, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        title: const Text('What works where'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EnterpriseInfoBanner(
            icon: Icons.info_outline,
            tone: EnterpriseTone.info,
            title: 'Platform guide',
            message:
                'Use the mobile app for PhonePe and UPI. '
                'Firebase web supports Razorpay and bank transfer. '
                'Full admin operations are on the admin web dashboard.',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FixedColumnWidth(56),
                  2: FixedColumnWidth(56),
                  3: FixedColumnWidth(56),
                },
                children: [
                  const TableRow(
                    children: [
                      Text('Feature', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('App', textAlign: TextAlign.center),
                      Text('Web', textAlign: TextAlign.center),
                      Text('Admin', textAlign: TextAlign.center),
                    ],
                  ),
                  ..._rows.map(
                    (r) => TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(r.$1),
                        ),
                        _check(r.$2),
                        _check(r.$3),
                        _check(r.$4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            Text(
              'You are on web — install the mobile app for PhonePe and UPI payments.',
              style: TextStyle(color: DesignColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _check(bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Icon(
        ok ? Icons.check_circle : Icons.remove_circle_outline,
        color: ok ? DesignColors.success : DesignColors.textSecondary,
        size: 20,
      ),
    );
  }
}
