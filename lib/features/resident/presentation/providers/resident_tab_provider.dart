import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab index for [ResidentShell] (home / community / profile).
final currentTabProvider = StateProvider<int>((ref) => 0);

/// Sub-tab inside [CommunityScreen]: 0 Notices, 1 Polls, 2 Events, 3 Docs.
final communitySubTabIndexProvider = StateProvider<int>((ref) => 0);

/// Switch to Community tab and open a specific sub-tab.
void openCommunityTab(WidgetRef ref, {int subTab = 0}) {
  ref.read(communitySubTabIndexProvider.notifier).state =
      subTab.clamp(0, 3);
  ref.read(currentTabProvider.notifier).state = 1;
}
