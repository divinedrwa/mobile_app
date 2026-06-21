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
import '../../../../core/widgets/shimmer_box.dart';
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

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/splash/gp_logo.png',
          width: 80,
          height: 80,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        const Text(
          'GatePass+',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: -0.06, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildTitleBlock() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Choose your society',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: DesignColors.textPrimary,
            letterSpacing: -0.6,
            height: 1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Your account and data are scoped to one society.\nYou can change this before you sign in.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: DesignColors.textSecondary,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 80.ms)
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

  Widget _buildLoadingSkeleton() {
    return ShimmerWrap(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        itemCount: 4,
        separatorBuilder: (context, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              ShimmerBox(width: 24, height: 24, borderRadius: 12),
              SizedBox(width: 14),
              ShimmerBox(width: 44, height: 44, borderRadius: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 16, borderRadius: 6),
                    SizedBox(height: 8),
                    ShimmerBox(height: 12, borderRadius: 6, width: 120),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: enabled
                            ? DesignColors.primary.withValues(alpha: 0.10)
                            : DesignColors.surfaceSoft,
                      ),
                      child: Icon(
                        Icons.apartment_rounded,
                        color: enabled
                            ? DesignColors.primary
                            : DesignColors.textTertiary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
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
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: DesignColors.textTertiary.withValues(alpha: 0.85),
                      size: 22,
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
                _buildBrandHeader(),
                const SizedBox(height: AppSpacing.lg),
                _buildTitleBlock(),
                if (!_loading && _error == null && _societies.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _selectableCount == _societies.length
                          ? '${_societies.length} ${_societies.length == 1 ? 'society' : 'societies'}'
                          : '$_selectableCount of ${_societies.length} available for sign-in',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DesignColors.textTertiary,
                      ),
                    ).animate().fadeIn(delay: DesignAnimations.sectionStaggerFor(1), duration: 350.ms),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: _loading
                      ? _buildLoadingSkeleton()
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
                  color: DesignColors.primary,
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
