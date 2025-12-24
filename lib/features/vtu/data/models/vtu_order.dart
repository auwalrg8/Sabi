/// Types of VTU services
enum VtuServiceType {
  airtime,
  data,
  electricity,
}

extension VtuServiceTypeExtension on VtuServiceType {
  String get name {
    switch (this) {
      case VtuServiceType.airtime:
        return 'Airtime';
      case VtuServiceType.data:
        return 'Data';
      case VtuServiceType.electricity:
        return 'Electricity';
    }
  }
}

/// Status of a VTU order
enum VtuOrderStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
}

extension VtuOrderStatusExtension on VtuOrderStatus {
  String get name {
    switch (this) {
      case VtuOrderStatus.pending:
        return 'Pending';
      case VtuOrderStatus.processing:
        return 'Processing';
      case VtuOrderStatus.completed:
        return 'Completed';
      case VtuOrderStatus.failed:
        return 'Failed';
      case VtuOrderStatus.refunded:
        return 'Refunded';
    }
  }

  int get color {
    switch (this) {
      case VtuOrderStatus.pending:
        return 0xFFFFA726; // Orange
      case VtuOrderStatus.processing:
        return 0xFF42A5F5; // Blue
      case VtuOrderStatus.completed:
        return 0xFF66BB6A; // Green
      case VtuOrderStatus.failed:
        return 0xFFEF5350; // Red
      case VtuOrderStatus.refunded:
        return 0xFFAB47BC; // Purple
    }
  }
}

/// VTU Order model for tracking purchases
class VtuOrder {
  final String id;
  final VtuServiceType serviceType;
  final String recipient; // Phone number or meter number
  final double amountNaira;
  final int amountSats;
  final VtuOrderStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? networkCode; // For airtime/data
  final String? dataPlanId; // For data
  final String? electricityProvider; // For electricity
  final String? meterType; // For electricity
  final String? token; // Electricity token if received
  final String? errorMessage;

  const VtuOrder({
    required this.id,
    required this.serviceType,
    required this.recipient,
    required this.amountNaira,
    required this.amountSats,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.networkCode,
    this.dataPlanId,
    this.electricityProvider,
    this.meterType,
    this.token,
    this.errorMessage,
  });

  VtuOrder copyWith({
    String? id,
    VtuServiceType? serviceType,
    String? recipient,
    double? amountNaira,
    int? amountSats,
    VtuOrderStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? networkCode,
    String? dataPlanId,
    String? electricityProvider,
    String? meterType,
    String? token,
    String? errorMessage,
  }) {
    return VtuOrder(
      id: id ?? this.id,
      serviceType: serviceType ?? this.serviceType,
      recipient: recipient ?? this.recipient,
      amountNaira: amountNaira ?? this.amountNaira,
      amountSats: amountSats ?? this.amountSats,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      networkCode: networkCode ?? this.networkCode,
      dataPlanId: dataPlanId ?? this.dataPlanId,
      electricityProvider: electricityProvider ?? this.electricityProvider,
      meterType: meterType ?? this.meterType,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceType': serviceType.name,
      'recipient': recipient,
      'amountNaira': amountNaira,
      'amountSats': amountSats,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'networkCode': networkCode,
      'dataPlanId': dataPlanId,
      'electricityProvider': electricityProvider,
      'meterType': meterType,
      'token': token,
      'errorMessage': errorMessage,
    };
  }

  factory VtuOrder.fromJson(Map<String, dynamic> json) {
    return VtuOrder(
      id: json['id'] as String,
      serviceType: VtuServiceType.values.firstWhere(
        (e) => e.name == json['serviceType'],
      ),
      recipient: json['recipient'] as String,
      amountNaira: (json['amountNaira'] as num).toDouble(),
      amountSats: json['amountSats'] as int,
      status: VtuOrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      networkCode: json['networkCode'] as String?,
      dataPlanId: json['dataPlanId'] as String?,
      electricityProvider: json['electricityProvider'] as String?,
      meterType: json['meterType'] as String?,
      token: json['token'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Get display name for the service
  String get serviceName {
    switch (serviceType) {
      case VtuServiceType.airtime:
        return '${networkCode?.toUpperCase() ?? ''} Airtime';
      case VtuServiceType.data:
        return '${networkCode?.toUpperCase() ?? ''} Data';
      case VtuServiceType.electricity:
        return '${electricityProvider ?? ''} Electricity';
    }
  }
}
