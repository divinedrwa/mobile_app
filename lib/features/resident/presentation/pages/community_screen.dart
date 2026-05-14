import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/context_extensions.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'documents_list_screen.dart';
import 'events_list_screen.dart';
import 'notifications_center_screen.dart';
import 'notices_list_screen.dart';
import 'polls_list_screen.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).user?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: context.surface.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: context.spacing.s16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.text.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              'Notices, polls, events, and documents',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.text.secondary,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.spacing.s8),
            child: IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => residentNotificationsEntry,
                  ),
                );
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    color: context.text.primary,
                  ),
                  if (isAdmin)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.brand.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.symmetric(horizontal: context.spacing.s8),
              labelColor: context.brand.accent,
              unselectedLabelColor: context.text.secondary,
              indicatorColor: context.brand.accent,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: context.surface.border,
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              unselectedLabelStyle:
                  Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
              tabs: const [
                _CommunityTab(icon: Icons.campaign_outlined, label: 'Notices'),
                _CommunityTab(icon: Icons.poll_outlined, label: 'Polls'),
                _CommunityTab(icon: Icons.event_rounded, label: 'Events'),
                _CommunityTab(icon: Icons.folder_open_rounded, label: 'Docs'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: isAdmin && _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Create notice action is pending backend flow.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              backgroundColor: context.brand.accent,
              elevation: 3,
              child: const Icon(Icons.edit_rounded, color: Colors.white),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: const [
          NoticesListScreen(),
          PollsListScreen(),
          EventsListScreen(),
          DocumentsListScreen(),
        ],
      ),
    );
  }
}

/// Single-row tab label (icon + text on one line) so longer words like
/// "Notices" / "Events" never get clipped by the default vertical stack.
class _CommunityTab extends StatelessWidget {
  const _CommunityTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
