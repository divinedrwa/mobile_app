/// Virtual screen paths for tab shells that do not push GoRouter routes.
abstract class AppAnalyticsTabPaths {
  AppAnalyticsTabPaths._();

  static const residentAdminOnly = '/resident/admin-only';

  static String residentTab(int index, {required bool isAdmin}) {
    if (isAdmin) {
      return switch (index) {
        0 => '/resident/tab/home',
        1 => '/resident/tab/community',
        2 => '/resident/tab/admin',
        3 => '/resident/tab/profile',
        _ => '/resident/tab/home',
      };
    }
    return switch (index) {
      0 => '/resident/tab/home',
      1 => '/resident/tab/community',
      2 => '/resident/tab/profile',
      _ => '/resident/tab/home',
    };
  }

  static const _communitySubTabs = ['notices', 'polls', 'events', 'docs'];

  static String communitySubTab(int index) {
    final name = _communitySubTabs[index.clamp(0, _communitySubTabs.length - 1)];
    return '/resident/tab/community/$name';
  }
}
