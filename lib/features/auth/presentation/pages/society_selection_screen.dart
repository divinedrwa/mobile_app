import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/utils/storage_service.dart';
import '../../../../core/widgets/polished_button.dart';
import '../providers/auth_provider.dart';

/// First step of login: pick a society; id/name are persisted for the login screen and API context.
class SocietySelectionScreen extends ConsumerStatefulWidget {
  const SocietySelectionScreen({super.key});

  @override
  ConsumerState<SocietySelectionScreen> createState() =>
      _SocietySelectionScreenState();
}

typedef _SocietyRow = ({String id, String name, bool isSelectable});

class _SocietySelectionScreenState extends ConsumerState<SocietySelectionScreen> {
  List<_SocietyRow> _societies = [];
  String? _selectedId;
  bool _loading = true;
  String? _error;

  bool get _canContinue {
    final id = _selectedId;
    if (id == null || id.isEmpty) return false;
    for (final s in _societies) {
      if (s.id == id) return s.isSelectable;
    }
    return false;
  }

  int get _selectableCount =>
      _societies.where((s) => s.isSelectable).length;

  String? get _selectedSocietyName {
    final id = _selectedId;
    if (id == null) return null;
    for (final s in _societies) {
      if (s.id == id) return s.name;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final list = await repo.fetchPublicSocieties();
      if (!mounted) return;
      final saved = StorageService.getPreferredLoginSocietyId();
      String? pick;
      if (saved != null) {
        for (final e in list) {
          if (e.id == saved && e.isSelectable) {
            pick = saved;
            break;
          }
        }
      }
      if (pick == null && list.length == 1 && list.first.isSelectable) {
        pick = list.first.id;
      }
      if (pick == null && list.where((e) => e.isSelectable).length == 1) {
        pick = list.firstWhere((e) => e.isSelectable).id;
      }
      setState(() {
        _societies = List<_SocietyRow>.from(list);
        _selectedId = pick;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppException ? e.message : 'Could not load societies';
      });
    }
  }

  Future<void> _continue() async {
    final id = _selectedId?.trim();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a society')),
      );
      return;
    }
    _SocietyRow? row;
    for (final s in _societies) {
      if (s.id == id) {
        row = s;
        break;
      }
    }
    if (row == null || !row.isSelectable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This society is not available for sign-in.'),
        ),
      );
      return;
    }
    final name = row.name;
    await StorageService.savePreferredLoginSociety(id: id, name: name);
    if (!mounted) return;
    context.go('/login');
  }

  void _onSocietyTap(_SocietyRow s) {
    if (!s.isSelectable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            '${s.name} is not active. Contact your administrator.',
          ),
        ),
      );
      return;
    }
    setState(() => _selectedId = s.id);
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: DesignColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.apartment_rounded,
            color: DesignColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your society',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: DesignColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Your account and data are scoped to one society. You can change this before you sign in.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: DesignColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: DesignAnimations.slideNormal, end: 0);
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: DesignColors.error.withValues(alpha: 0.85)),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Could not load societies',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: DesignColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: DesignColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: DesignColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final noTenants = _societies.isEmpty;
    final title = noTenants
        ? 'No societies yet'
        : 'No active societies';
    final detail = noTenants
        ? 'There are no societies on this server. Ask an administrator to create one, or check your API server in Settings.'
        : 'All listed societies are inactive. An administrator must activate a society before you can sign in.';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      noTenants
                          ? Icons.domain_disabled_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 56,
                      color: DesignColors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: DesignColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: DesignColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemCount: _societies.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = _societies[i];
        final sel = _selectedId == s.id && s.isSelectable;
        final enabled = s.isSelectable;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onSocietyTap(s),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: enabled ? 1 : 0.55,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: sel
                      ? DesignColors.primary.withValues(alpha: 0.1)
                      : DesignColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sel
                        ? DesignColors.primary
                        : DesignColors.borderLight,
                    width: sel ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      enabled
                          ? (sel
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off_rounded)
                          : Icons.block_rounded,
                      color: enabled
                          ? (sel
                              ? DesignColors.primary
                              : DesignColors.textSecondary)
                          : DesignColors.textTertiary,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: enabled
                                        ? DesignColors.textPrimary
                                        : DesignColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (!enabled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DesignColors.surfaceSoft,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: DesignColors.borderLight,
                                    ),
                                  ),
                                  child: const Text(
                                    'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: DesignColors.textTertiary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: DesignColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: DesignColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                _buildHeader(),
                if (!_loading && _error == null && _societies.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _selectableCount == _societies.length
                        ? '${_societies.length} ${_societies.length == 1 ? 'society' : 'societies'}'
                        : '$_selectableCount of ${_societies.length} available for sign-in',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DesignColors.textTertiary,
                    ),
                  ).animate().fadeIn(delay: DesignAnimations.sectionStaggerFor(1), duration: 350.ms),
                ],
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: DesignColors.primary,
                              ),
                              SizedBox(height: AppSpacing.lg),
                              Text(
                                'Loading societies…',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: DesignColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _error != null
                          ? _buildError()
                          : RefreshIndicator(
                              color: DesignColors.primary,
                              onRefresh: _load,
                              child: _societies.isEmpty || _selectableCount == 0
                                  ? _buildEmpty()
                                  : _buildList(),
                            ),
                ),
                PolishedButton(
                  text: _selectedSocietyName != null
                      ? 'Sign in to $_selectedSocietyName'
                      : 'Continue to sign in',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _loading || !_canContinue ? null : _continue,
                  isFullWidth: true,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
      ),
    );
  }
}
