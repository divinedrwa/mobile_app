import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tab index for [ResidentShell] (home / community / profile).
final currentTabProvider = StateProvider<int>((ref) => 0);
