part of '../maintenance_payment_screen.dart';

extension _MaintenanceDashboardOverviewResidentsListPart
    on _MaintenancePaymentScreenState {
  List<Widget> _buildOverviewResidentsSlivers({
    required List<Map<String, dynamic>> sortedResidents,
    required List<Map<String, dynamic>> visibleResidents,
    required String? myVilla,
    required int paidCount,
    required int totalResidents,
    required NumberFormat inr,
  }) {
    final slivers = <Widget>[];
    if (sortedResidents.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'All residents',
                        style: DesignTypography.label.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.text.primary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DesignColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$paidCount / $totalResidents paid',
                        style: DesignTypography.labelSmall.copyWith(
                          color: DesignColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _residentsFilterBar(),
            ],
          ),
        ),
      );
    }
    if (visibleResidents.isNotEmpty) {
      slivers.add(
        SliverList.builder(
          itemCount: visibleResidents.length,
          itemBuilder: (ctx, i) {
            final r = visibleResidents[i];
            final unit = '${r['villaNumber'] ?? r['flatNumber'] ?? ''}'
                .trim()
                .toLowerCase();
            final isMe =
                myVilla != null && myVilla.isNotEmpty && unit == myVilla;
            return _residentPaymentTile(r, inr, isMe: isMe);
          },
        ),
      );
    } else if (sortedResidents.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(child: _residentsNoMatch()));
    }
    return slivers;
  }
}
