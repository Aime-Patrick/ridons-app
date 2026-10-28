class CancellationReason {
  const CancellationReason({
    required this.code,
    required this.audience,
    required this.labelEn,
    this.labelRw = '',
    this.sortOrder = 0,
    this.requiresNote = false,
    this.enabled = true,
  });

  final String code;
  final String audience;
  final String labelEn;
  final String labelRw;
  final int sortOrder;
  final bool requiresNote;
  final bool enabled;

  factory CancellationReason.fromJson(Map<String, dynamic> json) {
    return CancellationReason(
      code: '${json['code'] ?? ''}',
      audience: '${json['audience'] ?? 'both'}',
      labelEn: '${json['labelEn'] ?? json['label'] ?? ''}',
      labelRw: '${json['labelRw'] ?? ''}',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      requiresNote: json['requiresNote'] == true,
      enabled: json['enabled'] != false,
    );
  }

  String labelFor(String languageCode) =>
      languageCode.toLowerCase().startsWith('rw') && labelRw.trim().isNotEmpty
      ? labelRw
      : labelEn;
}

class CancellationSelection {
  const CancellationSelection({
    required this.code,
    required this.label,
    this.note = '',
  });

  final String code;
  final String label;
  final String note;
}

List<CancellationReason> defaultCancellationReasons(String actor) {
  if (actor == 'driver') {
    return const [
      CancellationReason(
        code: 'passenger_no_show',
        audience: 'driver',
        labelEn: 'Passenger did not show up',
        labelRw: 'Umugenzi ntiyaje',
        sortOrder: 10,
      ),
      CancellationReason(
        code: 'passenger_requested_cancel',
        audience: 'driver',
        labelEn: 'Passenger asked me to cancel',
        labelRw: 'Umugenzi yansabye guhagarika urugendo',
        sortOrder: 20,
      ),
      CancellationReason(
        code: 'unsafe_pickup',
        audience: 'driver',
        labelEn: 'Pickup location is unsafe',
        labelRw: 'Ahantu ho gufatira si heza ku mutekano',
        sortOrder: 30,
      ),
      CancellationReason(
        code: 'vehicle_problem',
        audience: 'driver',
        labelEn: 'Vehicle problem',
        labelRw: 'Ikibazo cy’ikinyabiziga',
        sortOrder: 40,
      ),
      CancellationReason(
        code: 'too_far_from_passenger',
        audience: 'driver',
        labelEn: 'Passenger is too far away',
        labelRw: 'Umugenzi ari kure cyane',
        sortOrder: 50,
      ),
      CancellationReason(
        code: 'emergency',
        audience: 'driver',
        labelEn: 'Emergency',
        labelRw: 'Ibihe byihutirwa',
        sortOrder: 60,
      ),
      CancellationReason(
        code: 'other',
        audience: 'both',
        labelEn: 'Other',
        labelRw: 'Ikindi',
        sortOrder: 100,
        requiresNote: true,
      ),
    ];
  }
  return const [
    CancellationReason(
      code: 'long_pickup_time',
      audience: 'passenger',
      labelEn: 'Long pickup time',
      labelRw: 'Igihe kirekire cyo gutegereza',
      sortOrder: 10,
    ),
    CancellationReason(
      code: 'found_better_alternative',
      audience: 'passenger',
      labelEn: 'Found a better alternative',
      labelRw: 'Nabonye ubundi buryo bwiza',
      sortOrder: 20,
    ),
    CancellationReason(
      code: 'driver_not_getting_closer',
      audience: 'passenger',
      labelEn: 'Driver is not getting closer',
      labelRw: 'Umushoferi ntiyegera',
      sortOrder: 30,
    ),
    CancellationReason(
      code: 'price_dispute',
      audience: 'passenger',
      labelEn: 'Price dispute with driver',
      labelRw: 'Kutumvikana ku giciro',
      sortOrder: 40,
    ),
    CancellationReason(
      code: 'driver_requested_off_app_payment',
      audience: 'passenger',
      labelEn: 'Driver asked to pay outside the app',
      labelRw: 'Umushoferi yasabye kwishyura hanze ya porogaramu',
      sortOrder: 50,
    ),
    CancellationReason(
      code: 'driver_requested_cancel',
      audience: 'passenger',
      labelEn: 'Driver asked me to cancel',
      labelRw: 'Umushoferi yansabye guhagarika urugendo',
      sortOrder: 60,
    ),
    CancellationReason(
      code: 'other',
      audience: 'both',
      labelEn: 'Other',
      labelRw: 'Ikindi',
      sortOrder: 100,
      requiresNote: true,
    ),
  ];
}
