/// Vehicle model
class VehicleModel {
  final String? id;
  final String vehicleNumber;
  final String type;
  final String? brand;
  final String? model;
  final String? color;

  VehicleModel({
    this.id,
    required this.vehicleNumber,
    required this.type,
    this.brand,
    this.model,
    this.color,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String?,
      vehicleNumber:
          json['vehicleNumber'] as String? ??
          json['registrationNumber'] as String? ??
          '',
      type: json['type'] as String? ?? '',
      brand: json['brand'] as String? ?? json['make'] as String?,
      model: json['model'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vehicleNumber': vehicleNumber,
      'type': type,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
      if (color != null) 'color': color,
    };
  }
}
