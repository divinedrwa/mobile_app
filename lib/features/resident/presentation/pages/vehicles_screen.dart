import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/network/dio_exception_mapper.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/vehicle_model.dart';
import '../../data/providers/vehicle_provider.dart';
import '../widgets/list_skeleton.dart';
import 'add_vehicle_screen.dart';

/// Vehicles Screen
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesState = ref.watch(vehicleProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.surface.defaultSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.text.primary),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My Vehicles',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.text.primary,
              ),
            ),
            Text(
              'Registered household vehicles',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.text.secondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(vehicleProvider.notifier).fetchVehicles(),
        child: vehiclesState.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
          Padding(
          padding: EdgeInsets.all(context.spacing.s16),
          child: EnterpriseInfoBanner(
            icon: Icons.directions_car_filled_outlined,
            title: 'Could not load vehicles',
            message: userFacingMessage(error),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.read(vehicleProvider.notifier).fetchVehicles(),
          ),
        )]),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [EmptyStateWidget(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles added yet',
              subtitle:
                  'Add your household vehicles so gate and security workflows stay accurate.',
            )]);
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              context.spacing.s16,
              context.spacing.s12,
              context.spacing.s16,
              context.spacing.s32,
            ),
            children: [
              EnterprisePanel(
                tone: EnterpriseTone.info,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep gate access records clean',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.text.primary,
                          ),
                    ),
                    SizedBox(height: context.spacing.s8),
                    Text(
                      'Store registered household vehicles so entries, approvals, and resident identity checks stay fast and accurate.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.text.secondary,
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.spacing.s24),
              EnterpriseSectionHeader(
                title: 'Registered vehicles',
                subtitle:
                    '${vehicles.length} ${vehicles.length == 1 ? 'vehicle' : 'vehicles'} saved',
              ),
              SizedBox(height: context.spacing.s12),
              for (int index = 0; index < vehicles.length; index++)
                _VehicleCard(
                  vehicle: vehicles[index],
                  color: _getVehicleColor(context, vehicles[index].type),
                  icon: _getVehicleIcon(vehicles[index].type),
                  onDelete: () =>
                      _showDeleteDialog(context, ref, vehicles[index]),
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddVehicleScreen(vehicle: vehicles[index]),
                      ),
                    );
                  },
                ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms),
            ],
          );
        },
      )),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
    );
  }

  IconData _getVehicleIcon(String type) {
    switch (type.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.two_wheeler;
      default:
        return Icons.local_shipping;
    }
  }

  Color _getVehicleColor(BuildContext context, String type) {
    switch (type.toLowerCase()) {
      case 'car':
        return context.state.info.solid;
      case 'bike':
        return context.brand.accent;
      default:
        return context.state.approved.solid;
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    VehicleModel vehicle,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: DesignColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: DesignColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_car_outlined, color: DesignColors.error, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Remove vehicle?',
                  style: DesignTypography.headingM.copyWith(letterSpacing: -0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Remove ${vehicle.vehicleNumber} from your registered vehicles?',
                  textAlign: TextAlign.center,
                  style: DesignTypography.bodySmall.copyWith(
                    color: DesignColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderLG),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.pop(sheetCtx);
                          if (vehicle.id == null || vehicle.id!.isEmpty) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('Unable to remove this vehicle'),
                                backgroundColor: DesignColors.error,
                              ),
                            );
                            return;
                          }
                          final error = await ref.read(vehicleProvider.notifier).deleteVehicle(vehicle.id!);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              content: Text(error ?? '${vehicle.vehicleNumber} removed'),
                              backgroundColor: error == null ? DesignColors.success : DesignColors.error,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: DesignColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: DesignRadius.borderLG),
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.color,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
  });

  final VehicleModel vehicle;
  final Color color;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brandModel = [vehicle.brand, vehicle.model]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.s12),
      child: EnterprisePanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.radius.md),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: context.spacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.vehicleNumber,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.text.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: context.spacing.s4),
                  Text(
                    vehicle.type,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.text.secondary,
                        ),
                  ),
                  if (brandModel.isNotEmpty) ...[
                    SizedBox(height: context.spacing.s4),
                    Text(
                      brandModel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.text.secondary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Vehicle actions',
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                } else {
                  onEdit();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
