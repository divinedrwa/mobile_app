import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/telemetry/guard_flow_telemetry.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import 'guard_providers.dart';

/// Command-style helpers (MVVM “use case” layer) for heavy guard screens.
final guardCheckInSubmitProvider =
    Provider<Future<Map<String, dynamic>> Function(GuardCheckInSubmitParams)>((ref) {
      return (params) async {
        final span = GuardFlowTelemetry.start('guard_check_in');
        try {
          final result = await ref
              .read(guardRepositoryProvider)
              .checkInVisitor(
                name: params.name,
                phone: params.phone,
                villaIds: params.villaIds,
                visitorTypeApi: params.visitorTypeApi,
                purpose: params.purpose,
                vehicleNumber: params.vehicleNumber,
                photo: params.photo,
                awaitResidentApproval: params.awaitResidentApproval,
              );
          span.complete();
          return result;
        } catch (e) {
          span.complete(success: false);
          rethrow;
        }
      };
    });

class GuardCheckInSubmitParams {
  GuardCheckInSubmitParams({
    required this.name,
    required this.phone,
    required this.villaIds,
    required this.visitorTypeApi,
    this.purpose,
    this.vehicleNumber,
    this.photo,
    this.awaitResidentApproval = true,
  });

  final String name;
  final String phone;
  final List<String> villaIds;
  final String visitorTypeApi;
  final String? purpose;
  final String? vehicleNumber;
  final String? photo;
  final bool awaitResidentApproval;
}

final guardDeliverySubmitProvider =
    Provider<Future<void> Function(GuardDeliverySubmitParams)>((ref) {
      return (params) async {
        final span = GuardFlowTelemetry.start('guard_delivery_entry');
        try {
          await ref
              .read(guardRepositoryProvider)
              .logParcelReceived(
                villaId: params.villaId,
                deliveryService: params.deliveryService,
                trackingNumber: params.trackingNumber,
                senderName: params.senderName,
                description: params.description,
              );
          span.complete();
        } catch (e) {
          span.complete(success: false);
          rethrow;
        }
      };
    });

class GuardDeliverySubmitParams {
  GuardDeliverySubmitParams({
    required this.villaId,
    required this.deliveryService,
    this.trackingNumber,
    this.senderName,
    this.description,
  });

  final String villaId;
  final String deliveryService;
  final String? trackingNumber;
  final String? senderName;
  final String? description;
}

/// Maps errors for UI without importing Dio in widgets.
String guardCommandErrorMessage(Object e) => userFacingMessage(e);
