class AmenityModel {
  final String id;
  final String name;
  final String type;
  final String? description;
  final String? location;
  final int? capacity;
  final double pricePerHour;
  final String? openTime;
  final String? closeTime;

  AmenityModel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.location,
    this.capacity,
    required this.pricePerHour,
    this.openTime,
    this.closeTime,
  });

  factory AmenityModel.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['pricePerHour'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

    return AmenityModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Amenity',
      type: json['type']?.toString() ?? 'OTHER',
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      capacity: json['capacity'] is num ? (json['capacity'] as num).toInt() : null,
      pricePerHour: price,
      openTime: json['openTime']?.toString(),
      closeTime: json['closeTime']?.toString(),
    );
  }
}
