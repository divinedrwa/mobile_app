import 'package:flutter/material.dart';

/// Keeps off-screen [TabBarView] children alive (avoids blank tabs under go_router shells).
class GuardKeepAliveTab extends StatefulWidget {
  const GuardKeepAliveTab({super.key, required this.child});

  final Widget child;

  @override
  State<GuardKeepAliveTab> createState() => _GuardKeepAliveTabState();
}

class _GuardKeepAliveTabState extends State<GuardKeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
