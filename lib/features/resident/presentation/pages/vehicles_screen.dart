import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/enterprise_ui.dart';
import '../../../../theme/context_extensions.dart';
import '../../data/models/vehicle_model.dart';
import '../../data/providers/vehicle_provider.dart';
import 'add_vehicle_screen.dart';

/// Vehicles Screen
class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesState = ref.watch(vehicleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicles')),
      body: vehiclesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: EdgeInsets.all(context.spacing.s16),
          child: EnterpriseInfoBanner(
            icon: Icons.directions_car_filled_outlined,
            title: 'Could not load vehicles',
            message: error.toString(),
            tone: EnterpriseTone.danger,
            actionLabel: 'Retry',
            onAction: () => ref.read(vehicleProvider.notifier).fetchVehicles(),
          ),
        ),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles added yet',
              subtitle:
                  'Add your household vehicles so gate and security workflows stay accurate.',
            );
          }

          return ListView(
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
      ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: Text('Remove ${vehicle.vehicleNumber} from your vehicles?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (vehicle.id == null || vehicle.id!.isEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to remove this vehicle'),
                    backgroundColor: DesignColors.error,
                  ),
                );
                return;
              }
              final ok = await ref
                  .read(vehicleProvider.notifier)
                  .deleteVehicle(vehicle.id!);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '${vehicle.vehicleNumber} removed'
                        : 'Failed to remove vehicle',
                  ),
                  backgroundColor: ok
                      ? DesignColors.success
                      : DesignColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
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
