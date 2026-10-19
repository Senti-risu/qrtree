import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';
import '../utils/word_capitalization.dart';

class UploadedPlantPhoto {
  const UploadedPlantPhoto({required this.path, required this.publicUrl});

  final String path;
  final String publicUrl;
}

class PlantPhotoRules {
  static const int maxBytes = 6 * 1024 * 1024;
  static const Set<String> allowedExtensions = {'jpg', 'png', 'webp'};

  static String normalizeExtension(String extension) {
    final normalized = extension.trim().toLowerCase().replaceFirst('.', '');
    return normalized == 'jpeg' ? 'jpg' : normalized;
  }

  static String validate({
    required Uint8List bytes,
    required String extension,
  }) {
    final normalized = normalizeExtension(extension);
    if (!allowedExtensions.contains(normalized)) {
      throw const FormatException(
        'Use a JPG, PNG, or WebP image for the plant photo.',
      );
    }
    if (bytes.isEmpty) {
      throw const FormatException('The selected photo is empty.');
    }
    if (bytes.lengthInBytes > maxBytes) {
      throw const FormatException('The plant photo must be smaller than 6 MB.');
    }
    return normalized;
  }

  static String contentType(String normalizedExtension) =>
      switch (normalizedExtension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}

class PlantService {
  PlantService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<UploadedPlantPhoto> uploadPlantPhoto({
    required int registeredBy,
    required Uint8List bytes,
    required String extension,
  }) async {
    final safeExtension = PlantPhotoRules.validate(
      bytes: bytes,
      extension: extension,
    );
    final path =
        'registrations/user-$registeredBy-${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    await _supabase.storage
        .from('plant-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: PlantPhotoRules.contentType(safeExtension),
          ),
        );
    return UploadedPlantPhoto(
      path: path,
      publicUrl: _supabase.storage.from('plant-images').getPublicUrl(path),
    );
  }

  Future<void> deletePlantPhoto(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty || !normalized.startsWith('registrations/')) {
      throw ArgumentError.value(
        path,
        'path',
        'Invalid registration photo path.',
      );
    }
    await _supabase.storage.from('plant-images').remove([normalized]);
  }

  // ============================================================
  // PLANT CLASSIFICATIONS
  // ============================================================

  Future<List<Map<String, dynamic>>> getClassifications() async {
    final data = await _supabase
        .from('plant_classification')
        .select('classification_id, plant_type, common_name, scientific_name')
        .order('common_name');

    return List<Map<String, dynamic>>.from(
      data,
    ).map(capitalizeLookupNames).toList();
  }

  Future<String> saveMissingScientificName(
    int classificationId,
    String name,
  ) async {
    return (await _supabase.rpc(
      'app_save_missing_scientific_name',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_classification_id': classificationId,
        'p_scientific_name': name.trim(),
      },
    )).toString();
  }

  // ============================================================
  // CAMPUSES
  // Campus is selected FIRST.
  // ============================================================

  Future<List<Map<String, dynamic>>> getCampuses() async {
    final data = await _supabase
        .from('campus')
        .select('campus_id, campus_name')
        .order('campus_name');

    return List<Map<String, dynamic>>.from(
      data,
    ).map(capitalizeLookupNames).toList();
  }

  // ============================================================
  // COLLEGES
  // Each college belongs to one campus using college.campus_id.
  // ============================================================

  Future<List<Map<String, dynamic>>> getColleges() async {
    final data = await _supabase
        .from('college')
        .select('college_id, college_name, campus_id')
        .order('college_name');

    return List<Map<String, dynamic>>.from(
      data,
    ).map(capitalizeLookupNames).toList();
  }

  // ============================================================
  // TOWNS
  // Town is selected FIRST before Barangay.
  // ============================================================

  Future<List<Map<String, dynamic>>> getTowns() async {
    final data = await _supabase
        .from('town')
        .select('town_id, town_name, zip_code')
        .order('town_name');

    return List<Map<String, dynamic>>.from(
      data,
    ).map(capitalizeLookupNames).toList();
  }

  // ============================================================
  // BARANGAYS
  // Each barangay belongs to a town using barangay.town_id.
  // ============================================================

  Future<List<Map<String, dynamic>>> getBarangays() async {
    final data = await _supabase
        .from('barangay')
        .select('barangay_id, barangay_name, town_id')
        .order('barangay_name');

    return List<Map<String, dynamic>>.from(
      data,
    ).map(capitalizeLookupNames).toList();
  }

  // ============================================================
  // GROWTH STATUS
  // ============================================================

  Future<List<Map<String, dynamic>>> getGrowthStatuses() async {
    final data = await _supabase
        .from('growth_status')
        .select('growth_status_id, growth_stage')
        .order('growth_status_id');

    return List<Map<String, dynamic>>.from(
      data,
    ).map(capitalizeLookupNames).toList();
  }

  // ============================================================
  // HEALTH STATUS
  // ============================================================

  Future<List<Map<String, dynamic>>> getHealthStatuses() async {
    final data = await _supabase
        .from('health_status')
        .select('health_status_id, status_name, is_locked')
        .order('health_status_id');

    return List<Map<String, dynamic>>.from(
      data,
    ).map(capitalizeLookupNames).toList();
  }

  // ============================================================
  // REGISTER PLANT + QR
  // Supports:
  // 1. scanned existing QR
  // 2. generate new QR after registration
  // ============================================================

  Future<Map<String, dynamic>> registerPlantWithQr({
    required String locationType,
    int? locationCampusId,
    required int classificationId,
    required int campusId,
    required int collegeId,
    required int townId,
    required int barangayId,
    required int growthStatusId,
    required int healthStatusId,
    required int registeredBy,
    int? existingQrTagId,
    String? variety,
    String? datePlanted,
    String? treePlanter,
    String? photoUrl,
    String? scientificName,
  }) async {
    final normalizedScientificName = scientificName?.trim();
    if (normalizedScientificName != null &&
        (normalizedScientificName.runes.length > 200 ||
            RegExp(r'[\x00-\x1F\x7F]').hasMatch(normalizedScientificName))) {
      throw const FormatException(
        'Scientific name must contain at most 200 printable characters.',
      );
    }
    final addScientificName = normalizedScientificName?.isNotEmpty ?? false;
    final result = await _supabase.rpc(
      addScientificName
          ? 'register_plant_with_scientific_name'
          : 'register_plant_at_location',
      params: {
        if (addScientificName) 'p_scientific_name': normalizedScientificName,
        'p_location_type': locationType,
        'p_location_campus_id': locationCampusId,
        'p_classification_id': classificationId,
        'p_campus_id': campusId,
        'p_college_id': collegeId,
        'p_town_id': townId,
        'p_barangay_id': barangayId,
        'p_growth_status_id': growthStatusId,
        'p_health_status_id': healthStatusId,
        'p_registered_by': registeredBy,
        'p_variety': variety,
        'p_date_planted': datePlanted,
        'p_tree_planter': treePlanter,
        'p_photo_url': photoUrl,
        'p_existing_qr_tag_id': existingQrTagId,
        'p_session_token': AppSession.requiredToken,
      },
    );

    final rows = List<Map<String, dynamic>>.from(result as List);

    if (rows.isEmpty) {
      throw Exception('Registration did not return a result.');
    }

    return rows.first;
  }

  Future<List<Map<String, dynamic>>> findPossibleDuplicatePlants({
    required int classificationId,
    required int campusId,
    required int collegeId,
    required int townId,
    required int barangayId,
    String? variety,
    String? datePlanted,
    int limit = 10,
  }) async {
    if (limit < 1 || limit > 25) {
      throw ArgumentError.value(limit, 'limit', 'Limit must be from 1 to 25.');
    }

    try {
      final result = await _supabase.rpc(
        'find_possible_duplicate_plants',
        params: {
          'p_session_token': AppSession.requiredToken,
          'p_classification_id': classificationId,
          'p_campus_id': campusId,
          'p_college_id': collegeId,
          'p_town_id': townId,
          'p_barangay_id': barangayId,
          'p_variety': variety,
          'p_date_planted': datePlanted,
          'p_limit': limit,
        },
      );
      if (result is! List) return const [];
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (error) {
      // Keep registration compatible while the optional data-quality RPC is
      // being rolled out. Other failures still stop the save operation.
      final missingFunction =
          error.code == '42883' ||
          error.code == 'PGRST202' ||
          error.message.toLowerCase().contains('could not find the function');
      if (missingFunction) return const [];
      rethrow;
    }
  }

  Future<void> archivePlant({
    required int plantId,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.length < 3 || normalizedReason.length > 250) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Provide an archive reason from 3 to 250 characters.',
      );
    }
    await _supabase.rpc(
      'college_admin_archive_plant',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
        'p_reason': normalizedReason,
      },
    );
  }

  Future<void> reopenDeadPlant({
    required int plantId,
    required int healthStatusId,
    required String reason,
  }) async {
    if (reason.trim().length < 3 || reason.trim().length > 250) {
      throw ArgumentError('Provide a reason from 3 to 250 characters.');
    }
    await _supabase.rpc(
      'college_admin_reopen_dead_plant',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
        'p_health_status_id': healthStatusId,
        'p_reason': reason.trim(),
      },
    );
  }

  Future<void> restorePlant({required int plantId}) async {
    await _supabase.rpc(
      'college_admin_restore_plant',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
      },
    );
  }
}
