enum FuelLogType { bill, payment, usage, calibration }

class FuelLog {
  final String? id;
  final DateTime createdAt;
  final FuelLogType type;
  final double? liters;
  final double? price;
  final double? amount;
  final String? vehicleId;
  final double? km;
  final double? pumpMeter;

  FuelLog({
    this.id,
    required this.createdAt,
    required this.type,
    this.liters,
    this.price,
    this.amount,
    this.vehicleId,
    this.km,
    this.pumpMeter,
  });

  factory FuelLog.fromJson(Map<String, dynamic> json) {
    return FuelLog(
      id: json['id']?.toString(),
      createdAt: DateTime.parse(json['created_at']),
      type: _parseType(json['type']),
      liters: (json['liters'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble(),
      vehicleId: json['vehicle_id'],
      km: (json['km'] as num?)?.toDouble(),
      pumpMeter: (json['pump_meter'] as num?)?.toDouble(),
    );
  }

  static FuelLogType _parseType(String? type) {
    switch (type) {
      case 'BILL':
        return FuelLogType.bill;
      case 'PAYMENT':
        return FuelLogType.payment;
      case 'USAGE':
        return FuelLogType.usage;
      case 'CALIBRATION':
        return FuelLogType.calibration;
      default:
        return FuelLogType.usage;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name.toUpperCase(),
      if (liters != null) 'liters': liters,
      if (price != null) 'price': price,
      if (amount != null) 'amount': amount,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (km != null) 'km': km,
      if (pumpMeter != null) 'pump_meter': pumpMeter,
    };
  }
}
