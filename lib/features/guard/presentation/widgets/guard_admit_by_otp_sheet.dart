import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';

/// Admit an OTP-only arrival WITHOUT searching the pre-approved list or picking
/// a flat: the guard types the OTP, the backend resolves the visitor + flat by
/// the OTP alone, then the guard confirms entry. Returns `true` if admitted.
Future<bool> showAdmitByOtpSheet(BuildContext context) async {
  final admitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AdmitByOtpSheet(),
  );
  return admitted ?? false;
}

class _AdmitByOtpSheet extends ConsumerStatefulWidget {
  const _AdmitByOtpSheet();

  @override
  ConsumerState<_AdmitByOtpSheet> createState() => _AdmitByOtpSheetState();
}

class _AdmitByOtpSheetState extends ConsumerState<_AdmitByOtpSheet> {
  final _otpController = TextEditingController();
  bool _verifying = false;
  bool _admitting = false;
  String? _error;
  Map<String, dynamic>? _resolved; // the verified `preApproved` payload

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String get _otp => _otpController.text.trim();

  Future<void> _verify() async {
    if (_otp.length < 4) {
      setState(() => _error = 'Enter the OTP shown by the visitor.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
      _resolved = null;
    });
    try {
      final res =
          await ref.read(guardRepositoryProvider).verifyVisitorOtp(otp: _otp);
      if (!mounted) return;
      if (res['verified'] == true) {
        final pre = res['preApproved'];
        setState(() {
          _resolved = pre is Map ? Map<String, dynamic>.from(pre) : {};
        });
      } else {
        setState(() =>
            _error = res['message']?.toString() ?? 'OTP not found or invalid.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = userFacingMessage(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _admit() async {
    setState(() {
      _admitting = true;
      _error = null;
    });
    try {
      final res =
          await ref.read(guardRepositoryProvider).approveVisitorEntry(otp: _otp);
      if (!mounted) return;
      // Backend returns `{ admitted: true }` on success, or a 409/400 body with
      // `admitted: false` for an already-used/expired pass.
      if (res['admitted'] == false) {
        setState(() {
          _admitting = false;
          _error = res['message']?.toString() ?? 'Could not admit this visitor.';
          _resolved = null; // force re-verify
        });
        return;
      }
      // Refresh the gate lists so the admitted visitor appears as checked-in.
      ref.invalidate(guardActiveVisitorsTabProvider);
      ref.invalidate(guardPendingVisitorsProvider);
      ref.invalidate(guardTodayVisitorsProvider);
      ref.invalidate(guardPreApprovedEntriesProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _admitting = false;
          _error = userFacingMessage(e);
          _resolved = null;
        });
      }
    }
  }

  String _flatLabel(Map<String, dynamic> pre) {
    final villa = pre['villa'];
    final block = villa is Map ? villa['block']?.toString() : null;
    final number = villa is Map ? villa['villaNumber']?.toString() : null;
    final parts = [
      if (block != null && block.trim().isNotEmpty) block.trim(),
      if (number != null && number.trim().isNotEmpty) number.trim(),
    ];
    return parts.isEmpty ? 'Flat' : 'Flat ${parts.join('-')}';
  }

  String? _validUntilLabel(Map<String, dynamic> pre) {
    final raw = pre['validUntil']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return null;
    return 'Valid till ${DateFormat('d MMM, h:mm a').format(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: GuardTokens.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Admit by OTP',
              style: GuardTokens.headingStyle(context)
                  .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter the OTP the visitor received — no need to find their flat.',
              style: GuardTokens.captionStyle(context)
                  .copyWith(color: GuardTokens.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              autofocus: true,
              enabled: !_admitting,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••••',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                if (_resolved != null || _error != null) {
                  setState(() {
                    _resolved = null;
                    _error = null;
                  });
                }
              },
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _Banner(
                icon: Icons.error_outline_rounded,
                color: GuardTokens.dangerBrand,
                text: _error!,
              ),
            ],
            if (resolved != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GuardTokens.guardAccentDeep.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: GuardTokens.guardAccentDeep.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: GuardTokens.guardAccentDeep),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (resolved['name']?.toString().trim().isNotEmpty ??
                                    false)
                                ? resolved['name'].toString()
                                : 'Pre-approved visitor',
                            style: GuardTokens.headingStyle(context).copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _flatLabel(resolved),
                      style: GuardTokens.captionStyle(context).copyWith(
                        color: GuardTokens.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_validUntilLabel(resolved) != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _validUntilLabel(resolved)!,
                        style: GuardTokens.captionStyle(context)
                            .copyWith(color: GuardTokens.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: resolved == null
                  ? FilledButton(
                      onPressed: _verifying ? null : _verify,
                      child: _verifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verify OTP'),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: GuardTokens.guardAccentDeep,
                      ),
                      onPressed: _admitting ? null : _admit,
                      icon: _admitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.login_rounded, size: 18),
                      label: Text(_admitting ? 'Admitting…' : 'Allow entry'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GuardTokens.captionStyle(context)
                  .copyWith(color: GuardTokens.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
