import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/providers/notification_provider.dart';
import '../providers/resident_tab_provider.dart';
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

  static const _tabs = [
    (icon: Icons.campaign_outlined, label: 'Notices'),
    (icon: Icons.poll_outlined, label: 'Polls'),
    (icon: Icons.event_rounded, label: 'Events'),
    (icon: Icons.folder_open_rounded, label: 'Docs'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = ref.read(communitySubTabIndexProvider);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initial.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(_syncProviderFromTab);
  }

  void _syncProviderFromTab() {
    if (!_tabController.indexIsChanging && mounted) {
      final idx = _tabController.index;
      if (ref.read(communitySubTabIndexProvider) != idx) {
        ref.read(communitySubTabIndexProvider.notifier).state = idx;
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncProviderFromTab);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(communitySubTabIndexProvider, (prev, next) {
      if (next != _tabController.index && mounted) {
        _tabController.animateTo(next.clamp(0, _tabs.length - 1));
      }
    });

    final unreadCount = ref.watch(unreadCountProvider);

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
            padding: EdgeInsets.only(right: context.spacing.s4),
            child: TextButton.icon(
              onPressed: () => context.push('/resident/directory'),
              icon: Icon(Icons.people_outline_rounded, size: 18, color: context.brand.primary),
              label: Text(
                'Directory',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.brand.primary,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: context.spacing.s8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => residentNotificationsEntry,
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: context.text.primary,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: context.state.denied.solid,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.surface.defaultSurface, width: 1.5),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.spacing.s12,
              0,
              context.spacing.s12,
              context.spacing.s8,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final selected = _tabController.index == i;
                  final tab = _tabs[i];
                  return Padding(
                    padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _tabController.animateTo(i),
                        borderRadius: DesignRadius.borderXL,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected
                                ? context.brand.primary
                                : context.surface.defaultSurface,
                            borderRadius: DesignRadius.borderXL,
                            border: Border.all(
                              color: selected
                                  ? context.brand.primary
                                  : context.surface.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab.icon,
                                size: 16,
                                color: selected ? Colors.white : context.text.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                  color: selected ? Colors.white : context.text.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
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
