import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only information that is safe to show to a public EcoTag visitor.
class GuestDashboardSummary {
  const GuestDashboardSummary({
    required this.totalPlants,
    required this.healthyPlants,
    required this.atRiskPlants,
    required this.deadPlants,
    required this.campusCount,
  });

  final int totalPlants;
  final int healthyPlants;
  final int atRiskPlants;
  final int deadPlants;
  final int campusCount;

  factory GuestDashboardSummary.fromJson(Map<String, dynamic> json) {
    return GuestDashboardSummary(
      totalPlants: _integer(json, const ['total_plants', 'plant_count']),
      healthyPlants: _integer(json, const ['healthy_plants', 'healthy_count']),
      atRiskPlants: _integer(json, const [
        'at_risk_plants',
        'at_risk_count',
        'dying_plants',
        'dying_count',
      ]),
      deadPlants: _integer(json, const ['dead_plants', 'dead_count']),
      campusCount: _integer(json, const ['campus_count', 'total_campuses']),
    );
  }

  static int _integer(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }
}

/// Public plant information returned after a guest scans an assigned EcoTag.
/// Internal account, inspection, schedule, and lifecycle fields are excluded.
class GuestPlantProfile {
  const GuestPlantProfile({
    required this.plantId,
    required this.qrCode,
    required this.commonName,
    required this.scientificName,
    required this.plantType,
    this.variety,
    this.photoUrl,
    this.datePlanted,
    this.treePlanter,
    this.campusName,
    this.collegeName,
    this.plantingLocationType,
    this.plantingCampusName,
    this.townName,
    this.barangayName,
    this.growthStage,
    this.healthStatus,
  });

  final int plantId;
  final String qrCode;
  final String commonName;
  final String scientificName;
  final String plantType;
  final String? variety;
  final String? photoUrl;
  final String? datePlanted;
  final String? treePlanter;
  final String? campusName;
  final String? collegeName;
  final String? plantingLocationType;
  final String? plantingCampusName;

  String get plantingLocationLabel => plantingLocationType == 'outside'
      ? 'Outside campus'
      : plantingLocationType == 'inside'
      ? plantingCampusName ?? 'Campus not available'
      : 'Not recorded yet';
  final String? townName;
  final String? barangayName;
  final String? growthStage;
  final String? healthStatus;

  factory GuestPlantProfile.fromJson(Map<String, dynamic> json) {
    final plantId = _readInt(json['plant_id']);
    if (plantId == null || plantId <= 0) {
      throw const FormatException('Guest plant profile has no valid plant ID.');
    }
    return GuestPlantProfile(
      plantId: plantId,
      qrCode: _text(json['qr_code'], fallback: 'Not provided'),
      commonName: _text(json['common_name'], fallback: 'Unnamed plant'),
      scientificName: _text(
        json['scientific_name'],
        fallback: 'Scientific name not provided',
      ),
      plantType: _text(json['plant_type'], fallback: 'Not provided'),
      variety: _optionalText(json['variety']),
      photoUrl: _optionalText(json['photo_url']),
      datePlanted: _optionalText(json['date_planted']),
      treePlanter: _optionalText(json['tree_planter']),
      campusName: _optionalText(json['campus_name']),
      collegeName: _optionalText(json['college_name']),
      plantingLocationType: _optionalText(json['planting_location_type']),
      plantingCampusName: _optionalText(json['planting_campus_name']),
      townName: _optionalText(json['town_name']),
      barangayName: _optionalText(json['barangay_name']),
      growthStage: _optionalText(json['growth_stage']),
      healthStatus: _optionalText(json['health_status']),
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _text(Object? value, {required String fallback}) =>
      _optionalText(value) ?? fallback;

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class GuestQrScanResult {
  const GuestQrScanResult({
    required this.status,
    required this.message,
    this.plant,
  });

  final String status;
  final String message;
  final GuestPlantProfile? plant;

  bool get canView => status == 'assigned' && plant != null;

  factory GuestQrScanResult.fromJson(Map<String, dynamic> json) {
    final status = json['result_status']?.toString().trim().toLowerCase() ?? '';
    final rawPlant = json['plant'];
    return GuestQrScanResult(
      status: status.isEmpty ? 'unknown' : status,
      message: json['message']?.toString().trim().isNotEmpty == true
          ? json['message'].toString().trim()
          : 'This EcoTag could not be opened.',
      plant: rawPlant is Map
          ? GuestPlantProfile.fromJson(Map<String, dynamic>.from(rawPlant))
          : null,
    );
  }
}

/// Public guest access is intentionally separate from administrator sessions.
///
/// A visitor's optional display name is never accepted here, which prevents it
/// from being accidentally sent to or stored in Supabase.
class GuestService {
  GuestService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<int> startGuestVisit({required int age}) async {
    if (age < 1 || age > 120) {
      throw ArgumentError.value(age, 'age', 'Age must be from 1 to 120.');
    }

    final result = await _supabase.rpc(
      'start_guest_visit',
      params: {'p_age': age},
    );
    final visitId = _readVisitId(result);
    if (visitId == null || visitId <= 0) {
      throw StateError('EcoTag could not start the guest visit.');
    }
    return visitId;
  }

  Future<GuestDashboardSummary> loadDashboardSummary({
    required int visitId,
  }) async {
    if (visitId <= 0) {
      throw ArgumentError.value(visitId, 'visitId', 'Invalid guest visit.');
    }
    final result = await _supabase.rpc(
      'guest_dashboard_summary',
      params: {'p_visit_id': visitId},
    );
    final row = _firstRow(result);
    if (row == null) {
      throw StateError('EcoTag guest information is unavailable.');
    }
    return GuestDashboardSummary.fromJson(row);
  }

  Future<GuestQrScanResult> scanPlantByQr({
    required int visitId,
    required String code,
  }) async {
    if (visitId <= 0) {
      throw ArgumentError.value(visitId, 'visitId', 'Invalid guest visit.');
    }

    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty || normalizedCode.length > 160) {
      throw ArgumentError.value(code, 'code', 'Enter a valid EcoTag code.');
    }

    final result = await _supabase.rpc(
      'guest_view_plant_by_qr',
      params: {'p_visit_id': visitId, 'p_qr_code': normalizedCode},
    );
    final row = _firstRow(result);
    if (row == null) {
      throw StateError('EcoTag returned an invalid guest scan result.');
    }
    return GuestQrScanResult.fromJson(row);
  }

  int? _readVisitId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);

    final row = _firstRow(value);
    if (row == null) return null;
    for (final key in const ['visit_id', 'guest_visit_id', 'id']) {
      final raw = row[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  Map<String, dynamic>? _firstRow(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }
}
