import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
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
        return const Color(0xFF0284C7);
      case 'ELECTRICIAN':
        return const Color(0xFFF59E0B);
      case 'CARPENTER':
        return const Color(0xFF92400E);
      case 'PAINTER':
        return const Color(0xFF7C3AED);
      case 'SECURITY':
        return const Color(0xFFDC2626);
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
      appBar: AppBar(
        title: const Text('Vendors'),
        bottom: TabBar(
          controller: _tabController,
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Icon(Icons.error_outline, size: 56, color: DesignColors.error),
          const SizedBox(height: 10),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () => ref.read(vendorProvider.notifier).fetchVendors(),
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
      data: (vendors) {
        if (vendors.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              SizedBox(height: 100),
              Icon(Icons.storefront_outlined, size: 54, color: DesignColors.textTertiary),
              SizedBox(height: 10),
              Text(
                'No vendors available',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: vendors.length,
          itemBuilder: (context, index) {
            final vendor = vendors[index];
            final category = _vendorCategoryLabel(vendor.category);
            final categoryColor = _vendorCategoryColor(vendor.category);
            final categoryIcon = _vendorCategoryIcon(vendor.category);
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                leading: CircleAvatar(
                  backgroundColor: categoryColor.withValues(alpha: 0.14),
                  child: Icon(categoryIcon, color: categoryColor),
                ),
                title: Text(vendor.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: categoryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (vendor.phone.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(vendor.phone, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ],
                ),
                trailing: IconButton(
                  tooltip: 'Call',
                  onPressed: vendor.phone.trim().isEmpty ? null : () => _makeCall(vendor.phone.trim()),
                  icon: const Icon(Icons.call, color: Colors.green),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _staffTab(AsyncValue<List<DailyHelpModel>> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Icon(Icons.error_outline, size: 56, color: DesignColors.error),
          const SizedBox(height: 10),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () => ref.read(dailyHelpProvider.notifier).fetchDailyHelp(),
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
      data: (helpers) {
        if (helpers.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              SizedBox(height: 100),
              Icon(Icons.people_outline_rounded, size: 54, color: DesignColors.textTertiary),
              SizedBox(height: 10),
              Text(
                'No staff added yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: helpers.length,
          itemBuilder: (context, index) {
            final helper = helpers[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                leading: CircleAvatar(
                  backgroundColor: DesignColors.primary.withValues(alpha: 0.12),
                  child: const Icon(Icons.badge_outlined, color: DesignColors.primary),
                ),
                title: Text(helper.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(helper.type),
                    const SizedBox(height: 2),
                    Text(helper.phone, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
                trailing: IconButton(
                  tooltip: 'Call',
                  onPressed: helper.phone.trim().isEmpty ? null : () => _makeCall(helper.phone.trim()),
                  icon: const Icon(Icons.call, color: Colors.green),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
