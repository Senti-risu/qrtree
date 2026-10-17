import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/admin/plant_service.dart';
import 'app_session.dart';
import 'inspection_service.dart';
import 'plant_location_service.dart';

class PlantDetailsDraft {
  const PlantDetailsDraft({
    required this.classificationId,
    required this.variety,
    required this.treePlanter,
    required this.datePlanted,
    required this.photoUrl,
    required this.locationChoice,
    required this.townId,
    required this.barangayId,
  });
  final int classificationId, townId, barangayId;
  final String variety, treePlanter, photoUrl, locationChoice;
  final DateTime? datePlanted;

  Map<String, dynamic> toParams(int plantId) => {
    'p_plant_id': plantId,
    'p_classification_id': classificationId,
    'p_variety': variety.trim(),
    'p_tree_planter': treePlanter.trim(),
    'p_date_planted': datePlanted == null
        ? null
        : '${datePlanted!.year.toString().padLeft(4, '0')}-${datePlanted!.month.toString().padLeft(2, '0')}-${datePlanted!.day.toString().padLeft(2, '0')}',
    'p_photo_url': photoUrl,
    'p_location_type': locationChoice == 'outside' ? 'outside' : 'inside',
    'p_location_campus_id': locationChoice == 'outside'
        ? null
        : int.parse(locationChoice),
    'p_town_id': townId,
    'p_barangay_id': barangayId,
  };
}

abstract class PlantDetailsEditorRepository {
  Future<Map<String, dynamic>> load(int plantId);
  Future<void> save(int plantId, PlantDetailsDraft draft);
  Future<String> uploadPhoto(int userId, Uint8List bytes, String extension);
}

class PlantDetailsEditorService implements PlantDetailsEditorRepository {
  @override
  Future<Map<String, dynamic>> load(int plantId) async {
    final lookups = PlantService();
    final data = await Future.wait<dynamic>([
      InspectionService().getPlant(plantId),
      PlantLocationService().get(plantId),
      lookups.getClassifications(),
      lookups.getCampuses(),
      lookups.getTowns(),
      lookups.getBarangays(),
    ]);
    return {
      'plant': data[0],
      'location': data[1],
      'classifications': data[2],
      'campuses': data[3],
      'towns': data[4],
      'barangays': data[5],
    };
  }

  @override
  Future<void> save(int plantId, PlantDetailsDraft draft) async {
    await Supabase.instance.client.rpc(
      'update_plant_details',
      params: {
        ...draft.toParams(plantId),
        'p_session_token': AppSession.requiredToken,
      },
    );
  }

  @override
  Future<String> uploadPhoto(
    int userId,
    Uint8List bytes,
    String extension,
  ) async => (await PlantService().uploadPlantPhoto(
    registeredBy: userId,
    bytes: bytes,
    extension: extension,
  )).publicUrl;
}
