import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_animations.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../widgets/list_skeleton.dart';
import '../../data/models/daily_help_model.dart';
import '../../data/models/vendor_model.dart';
import '../../data/providers/daily_help_provider.dart';
import '../../data/providers/vendor_provider.dart';
import 'add_daily_help_screen.dart';

class VendorsStaffScreen extends ConsumerStatefulWidget {
  const VendorsStaffScreen({super.key});

  @override
  ConsumerState<VendorsStaffScreen> createState() => _VendorsStaffScreenState();
}

class _VendorsStaffScreenState extends ConsumerState<VendorsStaffScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _vendorCategoryLabel(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return 'Other';
    return normalized
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  IconData _vendorCategoryIcon(String raw) {
    final key = raw.trim().toUpperCase();
    switch (key) {
      case 'PLUMBER':
        return Icons.plumbing_rounded;
      case 'ELECTRICIAN':
        return Icons.electrical_services_rounded;
      case 'CARPENTER':
        return Icons.handyman_rounded;
      case 'PAINTER':
        return Icons.format_paint_rounded;
      case 'SECURITY':
        return Icons.shield_outlined;
      case 'CLEANING':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.store_mall_directory_outlined;
    }
  }

  Color _vendorCategoryColor(String raw) {
    final key = raw.trim().toUpperCase();
    switch (key) {
      case 'PLUMBER':
        return DesignColors.info;
      case 'ELECTRICIAN':
        return DesignColors.warning;
      case 'CARPENTER':
        return const Color(0xFF92400E);
      case 'PAINTER':
        return DesignColors.primary;
      case 'SECURITY':
        return DesignColors.error;
      case 'CLEANING':
        return const Color(0xFF0891B2);
      default:
        return DesignColors.primary;
    }
  }

  Future<void> _refresh() async {
    if (_tabController.index == 0) {
      await ref.read(vendorProvider.notifier).fetchVendors();
    } else {
      await ref.read(dailyHelpProvider.notifier).fetchDailyHelp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorsState = ref.watch(vendorProvider);
    final staffState = ref.watch(dailyHelpProvider);

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vendors & Staff',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.text.primary,
              ),
            ),
            Text(
              'Society vendors and daily help',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.text.secondary,
                height: 1.2,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: DesignColors.primary,
          unselectedLabelColor: DesignColors.textSecondary,
          indicatorColor: DesignColors.primary,
          dividerColor: context.surface.border.withValues(alpha: 0.5),
          tabs: const [
            Tab(text: 'Vendors'),
            Tab(text: 'Staff'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tabController,
          children: [
            _vendorsTab(vendorsState),
            _staffTab(staffState),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index != 1) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddDailyHelpScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Staff'),
          );
        },
      ),
    );
  }

  Widget _vendorsTab(AsyncValue<List<VendorModel>> state) {
    return state.when(
      loading: () => const ListSkeleton(),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.spacing.s16),
        children: [
          EnterpriseInfoBanner(
            icon: Icons.storefront_outlined,
            title: 'Could not load vendors',
            message: userFacingMessage(error),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.read(vendorProvider.notifier).fetchVendors(),
          ),
        ],
      ),
      data: (vendors) {
        if (vendors.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 48),
              EmptyStateWidget(
                icon: Icons.storefront_outlined,
                title: 'No vendors available',
                subtitle: 'Society-registered vendors will appear here.',
              ),
            ],
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            context.spacing.s16,
            context.spacing.s12,
            context.spacing.s16,
            context.spacing.s32,
          ),
          itemCount: vendors.length,
          itemBuilder: (context, index) {
            final vendor = vendors[index];
            final category = _vendorCategoryLabel(vendor.category);
            final categoryColor = _vendorCategoryColor(vendor.category);
            final categoryIcon = _vendorCategoryIcon(vendor.category);
            return Padding(
              padding: EdgeInsets.only(bottom: context.spacing.s12),
              child: EnterprisePanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.radius.md),
                      ),
                      alignment: Alignment.center,
                      child: Icon(categoryIcon, color: categoryColor, size: 22),
                    ),
                    SizedBox(width: context.spacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendor.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: context.text.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          SizedBox(height: context.spacing.s4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                color: categoryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (vendor.phone.isNotEmpty) ...[
                            SizedBox(height: context.spacing.s4),
                            Text(
                              vendor.phone,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: context.text.secondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (vendor.phone.trim().isNotEmpty)
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: DesignColors.success.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: IconButton(
                          tooltip: 'Call vendor',
                          padding: EdgeInsets.zero,
                          onPressed: () => _makeCall(vendor.phone.trim()),
                          icon: Icon(Icons.call_rounded, color: DesignColors.success, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 280.ms, delay: DesignAnimations.staggerFor(index));
          },
        );
      },
    );
  }

  Widget _staffTab(AsyncValue<List<DailyHelpModel>> state) {
    return state.when(
      loading: () => const ListSkeleton(),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(context.spacing.s16),
        children: [
          EnterpriseInfoBanner(
            icon: Icons.badge_outlined,
            title: 'Could not load staff',
            message: userFacingMessage(error),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.read(dailyHelpProvider.notifier).fetchDailyHelp(),
          ),
        ],
      ),
      data: (helpers) {
        if (helpers.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 48),
              EmptyStateWidget(
                icon: Icons.badge_outlined,
                title: 'No staff added yet',
                subtitle: 'Add daily help and domestic staff for your household.',
                actionLabel: 'Add staff',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddDailyHelpScreen()),
                  );
                },
              ),
            ],
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            context.spacing.s16,
            context.spacing.s12,
            context.spacing.s16,
            context.spacing.s32,
          ),
          itemCount: helpers.length,
          itemBuilder: (context, index) {
            final helper = helpers[index];
            return Padding(
              padding: EdgeInsets.only(bottom: context.spacing.s12),
              child: EnterprisePanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: DesignColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(context.radius.md),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.badge_outlined, color: DesignColors.primary, size: 22),
                    ),
                    SizedBox(width: context.spacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            helper.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: context.text.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          SizedBox(height: context.spacing.s4),
                          Text(
                            helper.type,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.text.secondary,
                                ),
                          ),
                          if (helper.phone.trim().isNotEmpty) ...[
                            SizedBox(height: context.spacing.s4),
                            Text(
                              helper.phone,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: context.text.secondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (helper.phone.trim().isNotEmpty)
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: DesignColors.success.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: IconButton(
                          tooltip: 'Call',
                          padding: EdgeInsets.zero,
                          onPressed: () => _makeCall(helper.phone.trim()),
                          icon: Icon(Icons.call_rounded, color: DesignColors.success, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 280.ms, delay: DesignAnimations.staggerFor(index));
          },
        );
      },
    );
  }
}
