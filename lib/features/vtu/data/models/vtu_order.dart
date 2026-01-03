/// Types of VTU services
enum VtuServiceType {
  airtime,
  data,
  electricity,
  cableTv,
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
      case VtuServiceType.cableTv:
        return 'Cable TV';
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

/// Status of a refund request
enum RefundStatus {
  none,
  requested,
  completed,
}

extension RefundStatusExtension on RefundStatus {
  String get name {
    switch (this) {
      case RefundStatus.none:
        return 'None';
      case RefundStatus.requested:
        return 'Requested';
      case RefundStatus.completed:
        return 'Completed';
    }
  }

  int get color {
    switch (this) {
      case RefundStatus.none:
        return 0xFF6B7280; // Gray
      case RefundStatus.requested:
        return 0xFFFFA726; // Orange
      case RefundStatus.completed:
        return 0xFF66BB6A; // Green
    }
  }
}

/// VTU Order model for tracking purchases
class VtuOrder {
  final String id;
  final VtuServiceType serviceType;
  final String recipient; // Phone number or meter number or smartcard number
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
  final String? cableTvProvider; // For cable TV (dstv, gotv, startimes)
  final String? cableTvPlanId; // For cable TV
  final String? errorMessage;
  final RefundStatus refundStatus;
  final String? refundInvoice; // Lightning invoice for refund
  final DateTime? refundRequestedAt;
  final DateTime? refundCompletedAt;

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
    this.cableTvProvider,
    this.cableTvPlanId,
    this.errorMessage,
    this.refundStatus = RefundStatus.none,
    this.refundInvoice,
    this.refundRequestedAt,
    this.refundCompletedAt,
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
    String? cableTvProvider,
    String? cableTvPlanId,
    String? errorMessage,
    RefundStatus? refundStatus,
    String? refundInvoice,
    DateTime? refundRequestedAt,
    DateTime? refundCompletedAt,
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
      cableTvProvider: cableTvProvider ?? this.cableTvProvider,
      cableTvPlanId: cableTvPlanId ?? this.cableTvPlanId,
      errorMessage: errorMessage ?? this.errorMessage,
      refundStatus: refundStatus ?? this.refundStatus,
      refundInvoice: refundInvoice ?? this.refundInvoice,
      refundRequestedAt: refundRequestedAt ?? this.refundRequestedAt,
      refundCompletedAt: refundCompletedAt ?? this.refundCompletedAt,
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
      'cableTvProvider': cableTvProvider,
      'cableTvPlanId': cableTvPlanId,
      'errorMessage': errorMessage,
      'refundStatus': refundStatus.name,
      'refundInvoice': refundInvoice,
      'refundRequestedAt': refundRequestedAt?.toIso8601String(),
      'refundCompletedAt': refundCompletedAt?.toIso8601String(),
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
      cableTvProvider: json['cableTvProvider'] as String?,
      cableTvPlanId: json['cableTvPlanId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      refundStatus: json['refundStatus'] != null
          ? RefundStatus.values.firstWhere(
              (e) => e.name == json['refundStatus'],
              orElse: () => RefundStatus.none,
            )
          : RefundStatus.none,
      refundInvoice: json['refundInvoice'] as String?,
      refundRequestedAt: json['refundRequestedAt'] != null
          ? DateTime.parse(json['refundRequestedAt'] as String)
          : null,
      refundCompletedAt: json['refundCompletedAt'] != null
          ? DateTime.parse(json['refundCompletedAt'] as String)
          : null,
    );
  }

  /// Check if this order is eligible for refund
  bool get canRequestRefund =>
      status == VtuOrderStatus.failed && refundStatus == RefundStatus.none;

  /// Check if refund was requested but not yet completed
  bool get hasRefundPending => refundStatus == RefundStatus.requested;

  /// Get display name for the service
  String get serviceName {
    switch (serviceType) {
      case VtuServiceType.airtime:
        return '${networkCode?.toUpperCase() ?? ''} Airtime';
      case VtuServiceType.data:
        return '${networkCode?.toUpperCase() ?? ''} Data';
      case VtuServiceType.electricity:
        return '${electricityProvider ?? ''} Electricity';
      case VtuServiceType.cableTv:
        return '${cableTvProvider?.toUpperCase() ?? ''} Cable TV';
    }
  }
}
