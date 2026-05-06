import 'package:flutter/material.dart';

/// Shared root [NavigatorState] for [GoRouter] (full-screen overlays that must
/// cover shells). Used by `/guard/*` overlays and [MaterialApp.router].
final GlobalKey<NavigatorState> appRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'appRootNavigator');
