/// Amenity Booking model
class AmenityBookingModel {
  final String? id;
  final String amenityId;
  final String amenityName;
  final DateTime bookingDate;
  final String timeSlot;
  final BookingStatus status;
  final DateTime? createdAt;
  final String? cancelReason;

  AmenityBookingModel({
    this.id,
    required this.amenityId,
    required this.amenityName,
    required this.bookingDate,
    required this.timeSlot,
    required this.status,
    this.createdAt,
    this.cancelReason,
  });

  factory AmenityBookingModel.fromJson(Map<String, dynamic> json) {
    // Handle nested amenity object
    final amenityData = json['amenity'] as Map<String, dynamic>?;
    
    return AmenityBookingModel(
      id: json['id'] as String?,
      amenityId: json['amenityId'] as String? ?? '',
      amenityName: amenityData?['name'] as String? ?? json['amenityName'] as String? ?? '',
      bookingDate: json['bookingDate'] != null
          ? DateTime.tryParse(json['bookingDate'] as String) ?? 
            (json['startTime'] != null 
                ? DateTime.tryParse(json['startTime'] as String) ?? DateTime.now()
                : DateTime.now())
          : DateTime.now(),
      timeSlot: json['timeSlot'] as String? ?? 
          _formatTimeSlot(json['startTime'], json['endTime']),
      status: BookingStatus.fromString(json['status'] as String? ?? 'confirmed'),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      cancelReason: json['cancelReason'] as String?,
    );
  }

  static String _formatTimeSlot(dynamic startTime, dynamic endTime) {
    if (startTime != null && endTime != null) {
      try {
        final start = DateTime.parse(startTime.toString());
        final end = DateTime.parse(endTime.toString());
        return '${_formatTime(start)} - ${_formatTime(end)}';
      } catch (e) {
        return 'N/A';
      }
    }
    return 'N/A';
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'amenityId': amenityId,
      'amenityName': amenityName,
      'bookingDate': bookingDate.toIso8601String(),
      'timeSlot': timeSlot,
      'status': status.value,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (cancelReason != null) 'cancelReason': cancelReason,
    };
  }
}

/// Booking status enum
enum BookingStatus {
  confirmed('confirmed', 'Confirmed'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  pending('pending', 'Pending');

  final String value;
  final String label;

  const BookingStatus(this.value, this.label);

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => BookingStatus.confirmed,
    );
  }
}
