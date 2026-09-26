enum DriverDocumentType {
  nationalId,
  drivingLicense,
  vehicleRegistration,
  insurance,
}

extension DriverDocumentTypeX on DriverDocumentType {
  String get apiValue => switch (this) {
        DriverDocumentType.nationalId => 'national_id',
        DriverDocumentType.drivingLicense => 'driving_license',
        DriverDocumentType.vehicleRegistration => 'vehicle_registration',
        DriverDocumentType.insurance => 'insurance',
      };

  String get label => switch (this) {
        DriverDocumentType.nationalId => 'National ID',
        DriverDocumentType.drivingLicense => 'Driving license',
        DriverDocumentType.vehicleRegistration => 'Vehicle registration',
        DriverDocumentType.insurance => 'Insurance',
      };
}

enum DriverDocumentStatus { pending, approved, rejected }

class DriverDocument {
  const DriverDocument({
    required this.id,
    required this.type,
    required this.status,
    required this.originalName,
    this.rejectReason,
    this.uploadedAt,
  });

  final String id;
  final DriverDocumentType type;
  final DriverDocumentStatus status;
  final String originalName;
  final String? rejectReason;
  final DateTime? uploadedAt;

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    final rawType = '${json['type'] ?? ''}';
    final type = DriverDocumentType.values.firstWhere(
      (value) => value.apiValue == rawType,
      orElse: () => DriverDocumentType.nationalId,
    );
    final rawStatus = '${json['status'] ?? 'pending'}';
    final status = DriverDocumentStatus.values.firstWhere(
      (value) => value.name == rawStatus,
      orElse: () => DriverDocumentStatus.pending,
    );
    return DriverDocument(
      id: '${json['id'] ?? ''}',
      type: type,
      status: status,
      originalName: '${json['originalName'] ?? ''}',
      rejectReason: json['rejectReason']?.toString(),
      uploadedAt: DateTime.tryParse('${json['uploadedAt'] ?? ''}'),
    );
  }
}
