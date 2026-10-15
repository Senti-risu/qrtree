class PlantRecordLock {
  static bool isDeadStatus(Object? value) => const {
    'dead',
    'deceased',
  }.contains(value?.toString().trim().toLowerCase());

  static bool isDead(Map<String, dynamic> plant) {
    final health = plant['health_status'];
    return isDeadStatus(health is Map ? health['status_name'] : health);
  }

  static bool canEdit(Map<String, dynamic> plant) =>
      plant['archived_at'] == null && !isDead(plant);
}
