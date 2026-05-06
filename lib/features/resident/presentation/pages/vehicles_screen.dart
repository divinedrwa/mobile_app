import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/design_tokens.dart';
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
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: DesignColors.error,
              ),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(vehicleProvider.notifier).fetchVehicles(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (vehicles) => ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _getVehicleColor(
                      vehicle.type,
                    ).withValues(alpha: 0.1),
                    borderRadius: DesignRadius.borderMD,
                  ),
                  child: Icon(
                    _getVehicleIcon(vehicle.type),
                    color: _getVehicleColor(vehicle.type),
                  ),
                ),
                title: Text(
                  vehicle.vehicleNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(vehicle.type),
                    if (vehicle.brand != null && vehicle.model != null)
                      Text(
                        '${vehicle.brand} ${vehicle.model}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: DesignColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteDialog(context, ref, vehicle);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddVehicleScreen(vehicle: vehicle),
                        ),
                      );
                    }
                  },
                ),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
          },
        ),
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

  Color _getVehicleColor(String type) {
    switch (type.toLowerCase()) {
      case 'car':
        return Colors.blue;
      case 'bike':
        return Colors.orange;
      default:
        return Colors.green;
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
