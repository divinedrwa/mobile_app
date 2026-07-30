import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../data/guard_public_pass_qr.dart';
import '../../ui/guard_tokens.dart';
import '../providers/guard_providers.dart';

/// After scanning a public visitor-pass QR, confirm and admit in one tap.
Future<bool> showPublicPassAdmitSheet(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> resolveResponse,
) async {
  final admitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PublicPassAdmitSheet(resolveResponse: resolveResponse),
  );
  return admitted ?? false;
}

class _PublicPassAdmitSheet extends ConsumerStatefulWidget {
  const _PublicPassAdmitSheet({required this.resolveResponse});

  final Map<String, dynamic> resolveResponse;

  @override
  ConsumerState<_PublicPassAdmitSheet> createState() =>
      _PublicPassAdmitSheetState();
}

class _PublicPassAdmitSheetState extends ConsumerState<_PublicPassAdmitSheet> {
  bool _admitting = false;
  String? _error;

  Map<String, dynamic>? get _preApproved {
    final raw = widget.resolveResponse['preApproved'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  String get _name => _preApproved?['name']?.toString().trim() ?? 'Visitor';

  String? get _flatLabel {
    final villa = _preApproved?['villa'];
    if (villa is Map) {
      final block = villa['block']?.toString().trim();
      final number = villa['villaNumber']?.toString().trim();
      final parts = [block, number].where((p) => p != null && p.isNotEmpty);
      final joined = parts.join(' · ');
      if (joined.isNotEmpty) return joined;
    }
    return _preApproved?['flatLabel']?.toString().trim();
  }

  String? get _preApprovedId => _preApproved?['id']?.toString().trim();

  String? get _otp {
    final fromRoot = widget.resolveResponse['otp']?.toString().trim();
    if (fromRoot != null && fromRoot.isNotEmpty) return fromRoot;
    return _preApproved?['otp']?.toString().trim();
  }

  Future<void> _admit() async {
    if (_admitting) return;
    setState(() {
      _admitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(guardRepositoryProvider);
      final preApprovedId = _preApprovedId;
      final Map<String, dynamic> result;
      if (preApprovedId != null && preApprovedId.isNotEmpty) {
        result = await repo.admitPreApprovedEntry(preApprovedId);
      } else {
        final otp = _otp;
        if (otp == null || otp.length < 4) {
          throw Exception('Pass details are incomplete');
        }
        final payload = guardPayloadFromResolvedPublicPass(widget.resolveResponse);
        result = await repo.approveVisitorEntry(
          otp: otp,
          villaId: payload?['villaId'],
          visitorName: payload?['name'] ?? _name,
          visitorPhone: payload?['phone'],
        );
      }
      final ok = result['admitted'] == true || result['verified'] == true;
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _admitting = false;
        _error = result['message']?.toString() ?? 'Could not admit visitor';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _admitting = false;
        _error = userFacingMessage(e, 'Could not admit visitor');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Pre-approved visitor',
              style: GuardTokens.headingStyle(context).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'QR verified — tap once to allow gate entry.',
              style: GuardTokens.captionStyle(context).copyWith(
                color: GuardTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GuardTokens.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(GuardTokens.radiusButton),
                border: Border.all(
                  color: GuardTokens.success.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: GuardTokens.success.withValues(alpha: 0.15),
                    foregroundColor: GuardTokens.success,
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: GuardTokens.headingStyle(context).copyWith(
                            fontSize: 16,
                          ),
                        ),
                        if (_flatLabel != null && _flatLabel!.isNotEmpty)
                          Text(
                            _flatLabel!,
                            style: GuardTokens.captionStyle(context),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.verified_rounded, color: GuardTokens.success),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: GuardTokens.dangerBrand, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _admitting ? null : _admit,
              icon: _admitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.door_front_door_rounded),
              label: Text(_admitting ? 'Admitting…' : 'Admit now'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: GuardTokens.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
