part of '../admin_maintenance_hub_screen.dart';

extension _AdminMaintenanceHubLifecyclePart on _AdminMaintenanceHubScreenState {
  // ── FY / cycle auto-select helpers ────────────────────────────────

  String? _pickDefaultFinancialYearId(List<Map<String, dynamic>> fys) {
    if (fys.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final fy in fys) {
      final s = DateTime.tryParse(fy['startDate']?.toString() ?? '');
      final e = DateTime.tryParse(fy['endDate']?.toString() ?? '');
      if (s == null || e == null) continue;
      final ds = DateTime(s.year, s.month, s.day);
      final de = DateTime(e.year, e.month, e.day);
      if (!today.isBefore(ds) && !today.isAfter(de)) {
        return fy['id']?.toString();
      }
    }
    return fys.first['id']?.toString();
  }

  Map<String, dynamic>? _pickDefaultCycle(List<Map<String, dynamic>> cycles) {
    if (cycles.isEmpty) return null;
    final now = DateTime.now();
    for (final c in cycles) {
      final pm = (c['periodMonth'] as num?)?.toInt();
      final py = (c['periodYear'] as num?)?.toInt();
      if (pm == now.month && py == now.year) return c;
    }
    for (final c in cycles) {
      if ((c['status']?.toString() ?? '').toUpperCase() == 'OPEN') return c;
    }
    return cycles.last;
  }

  // ── Selection helpers ─────────────────────────────────────────────

  /// All residents that have pending dues and are not excluded from billing.
  List<Map<String, dynamic>> _pendingResidents(Map<String, dynamic> data) {
    return ((data['residents'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((r) => r['isExcluded'] != true)
        .where((r) {
          final s = (r['status']?.toString() ?? '').toUpperCase();
          return s == 'PENDING' || s == 'OVERDUE' || s == 'PARTIAL';
        })
        .toList();
  }

  void _initSelection(List<Map<String, dynamic>> residents) {
    if (_selectionInitialised) return;
    _selectionInitialised = true;
    _selectedVillaIds
      ..clear()
      ..addAll(
        residents
            .where((r) => r['villaId'] != null)
            .map((r) => r['villaId'].toString()),
      );
  }

  bool _allSelected(List<Map<String, dynamic>> residents) {
    if (residents.isEmpty) return false;
    final allIds = residents
        .where((r) => r['villaId'] != null)
        .map((r) => r['villaId'].toString())
        .toSet();
    return _selectedVillaIds.length == allIds.length;
  }

  void _toggleAll(List<Map<String, dynamic>> residents) {
    setState(() {
      if (_allSelected(residents)) {
        _selectedVillaIds.clear();
      } else {
        _selectedVillaIds
          ..clear()
          ..addAll(
            residents
                .where((r) => r['villaId'] != null)
                .map((r) => r['villaId'].toString()),
          );
      }
    });
  }

  void _toggleVilla(String villaId) {
    setState(() {
      if (_selectedVillaIds.contains(villaId)) {
        _selectedVillaIds.remove(villaId);
      } else {
        _selectedVillaIds.add(villaId);
      }
    });
  }
  Future<void> _onSendReminders() async {
    if (_sendingReminders || _selectedVillaIds.isEmpty) return;

    final filter = ref.read(adminMaintenanceFilterProvider);
    final periodLabel =
        DateFormat('MMMM y').format(DateTime(filter.year, filter.month));

    final data = ref.read(adminMaintenanceDashboardProvider).valueOrNull;
    final pendingList = data != null ? _pendingResidents(data) : <Map<String, dynamic>>[];
    final isBulk = _allSelected(pendingList);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: DesignColors.borderLight, borderRadius: BorderRadius.circular(2))),
              Container(width: 56, height: 56,
                  decoration: BoxDecoration(color: DesignColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.notifications_active_outlined, color: DesignColors.primary, size: 28)),
              SizedBox(height: 16),
              Text('Send Reminders?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: DesignColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                isBulk
                    ? 'Send payment reminders to all ${_selectedVillaIds.length} residents with pending dues for $periodLabel?'
                    : 'Send payment reminders to ${_selectedVillaIds.length} selected resident${_selectedVillaIds.length == 1 ? "" : "s"} for $periodLabel?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: DesignColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetCtx, false),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () => Navigator.pop(sheetCtx, true),
                  style: FilledButton.styleFrom(backgroundColor: DesignColors.primary, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderMD)),
                  child: const Text('Send', style: TextStyle(fontWeight: FontWeight.w600)))),
              ]),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _sendingReminders = true);

    final repo = ref.read(adminMaintenanceRepositoryProvider);
    try {
      int totalSent = 0;
      int failed = 0;

      if (isBulk) {
        final result = await repo.sendDuesReminders(
          month: filter.month,
          year: filter.year,
        );
        totalSent = (result['sent'] as num?)?.toInt() ??
            (result['notified'] as num?)?.toInt() ??
            0;
      } else {
        for (final villaId in _selectedVillaIds) {
          try {
            final result = await repo.sendVillaReminder(villaId: villaId);
            totalSent += (result['sent'] as num?)?.toInt() ?? 0;
          } catch (e) {
            failed++;
            debugPrint('Failed to send reminder for villa $villaId: $e');
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              failed > 0 ? DesignColors.warning : DesignColors.primary,
          content: Text(
            failed > 0
                ? 'Reminded $totalSent · $failed failed — please retry'
                : totalSent > 0
                    ? 'Reminded $totalSent resident${totalSent == 1 ? "" : "s"}'
                    : 'No residents to remind for this period',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(adminMaintenanceDashboardProvider);
      _selectionInitialised = false;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: DesignColors.error,
          content: Text('Couldn\'t send reminders. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingReminders = false);
    }
  }

  // ---- residents list ----
}
