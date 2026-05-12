import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'documents_list_screen.dart';
import 'events_list_screen.dart';
import 'notices_list_screen.dart';
import 'notifications_center_screen.dart';
import 'polls_list_screen.dart';

const Color _kPageBg = DesignColors.background;
const Color _kTextSecondary = Color(0xFF64748B);
const double _kPadH = 20;

List<BoxShadow> _softShadow([double a = 0.06]) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: a),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];

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
      backgroundColor: _kPageBg,
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
              backgroundColor: DesignColors.primary,
              elevation: 3,
              child: const Icon(Icons.edit_rounded, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChromeHeader(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: const [
                  NoticesListScreen(),
                  PollsListScreen(),
                  EventsListScreen(),
                  DocumentsListScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChromeHeader(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: _softShadow(0.05),
            ),
            padding: const EdgeInsets.fromLTRB(_kPadH, 10, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circleIconButton(
                  context,
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: DesignColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.groups_rounded, color: DesignColors.primary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Community',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: DesignColors.textPrimary,
                                    letterSpacing: -0.35,
                                    height: 1.15,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Stay connected with your society',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _kTextSecondary,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _circleIconButton(
                  context,
                  icon: Icons.notifications_none_rounded,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => residentNotificationsEntry,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelColor: DesignColors.primary,
              unselectedLabelColor: _kTextSecondary,
              indicatorColor: DesignColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: const Color(0xFFF0F3F6),
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Notices'),
                Tab(icon: Icon(Icons.poll_outlined, size: 18), text: 'Polls'),
                Tab(icon: Icon(Icons.event_rounded, size: 18), text: 'Events'),
                Tab(icon: Icon(Icons.folder_open_rounded, size: 18), text: 'Docs'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: Icon(icon, color: const Color(0xFF1E293B), size: 22),
          ),
        ),
      ),
    );
  }
}
