enum HealthStatus { healthy, dying, dead }

enum GrowthStage { seedling, sapling, growing, mature }

enum UserRole {
  superAdmin,
  universityAdmin,
  campusAdmin,
  collegeAdmin,
  inspectionTeam,
  guest,
}

extension HealthStatusExt on HealthStatus {
  String get label => switch (this) {
        HealthStatus.healthy => 'Healthy',
        HealthStatus.dying => 'Dying',
        HealthStatus.dead => 'Dead',
      };

  String get dbValue => switch (this) {
        HealthStatus.healthy => 'alive',
        HealthStatus.dying => 'dying',
        HealthStatus.dead => 'dead',
      };

  static HealthStatus fromDb(String? value) => switch (value?.toLowerCase()) {
        'alive' => HealthStatus.healthy,
        'dying' => HealthStatus.dying,
        'dead' => HealthStatus.dead,
        _ => HealthStatus.healthy,
      };
}

extension UserRoleExt on UserRole {
  String get label => switch (this) {
        UserRole.superAdmin => 'Super Admin',
        UserRole.universityAdmin => 'University Admin',
        UserRole.campusAdmin => 'Campus Admin',
        UserRole.collegeAdmin => 'College Admin',
        UserRole.inspectionTeam => 'Inspection Team',
        UserRole.guest => 'Guest',
      };

  bool get canRegisterPlant => this != UserRole.guest && this != UserRole.inspectionTeam;
  bool get canViewReports => this != UserRole.guest;
  bool get canManageUsers => this == UserRole.superAdmin || this == UserRole.universityAdmin;
}

class AppUser {
  final String id;
  final String username;
  final String email;
  final UserRole role;
  final String? campus;
  final String? college;

  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.campus,
    this.college,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        username: map['username'] as String? ?? 'Unknown',
        email: map['email'] as String? ?? '',
        role: _parseRole(map['role'] as String?),
        campus: map['campus'] as String?,
        college: map['college'] as String?,
      );

  static UserRole _parseRole(String? role) => switch (role?.toLowerCase()) {
        'super admin' => UserRole.superAdmin,
        'university admin' => UserRole.universityAdmin,
        'campus admin' => UserRole.campusAdmin,
        'college admin' => UserRole.collegeAdmin,
        'inspection team' => UserRole.inspectionTeam,
        _ => UserRole.guest,
      };
}

class DashboardStats {
  final int totalPlants;
  final int healthyPlants;
  final int atRiskPlants;
  final int deadPlants;

  const DashboardStats({
    required this.totalPlants,
    required this.healthyPlants,
    required this.atRiskPlants,
    required this.deadPlants,
  });

  double get healthyPercent =>
      totalPlants == 0 ? 0 : healthyPlants / totalPlants * 100;
  double get deadPercent =>
      totalPlants == 0 ? 0 : deadPlants / totalPlants * 100;
}

class RecentPlant {
  final String id;
  final String name;
  final String type;
  final String variety;
  final String campus;
  final String growthStage;
  final HealthStatus health;
  final String datePlanted;

  const RecentPlant({
    required this.id,
    required this.name,
    required this.type,
    required this.variety,
    required this.campus,
    required this.growthStage,
    required this.health,
    required this.datePlanted,
  });

  factory RecentPlant.fromMap(Map<String, dynamic> m) => RecentPlant(
        id: m['id'].toString(),
        name: m['plant_classification']?['common_name'] as String? ?? 'Unknown',
        type: m['plant_classification']?['type'] as String? ?? 'Unknown',
        variety: m['plant_classification']?['variety'] as String? ?? 'Unknown',
        campus: m['campus']?['name'] as String? ?? 'Unknown',
        growthStage: m['growth_status']?['name'] as String? ?? 'Unknown',
        health: HealthStatusExt.fromDb(m['health_status']?['name'] as String?),
        datePlanted: m['date_planted'] as String? ?? 'Unknown',
      );
}

class RecentInspection {
  final String id;
  final String plantName;
  final String inspector;
  final HealthStatus health;
  final String growthStage;
  final String date;
  final String status;

  const RecentInspection({
    required this.id,
    required this.plantName,
    required this.inspector,
    required this.health,
    required this.growthStage,
    required this.date,
    required this.status,
  });

  factory RecentInspection.fromMap(Map<String, dynamic> m) => RecentInspection(
        id: m['id'].toString(),
        plantName: m['plant']?['plant_classification']?['common_name'] as String? ?? 'Unknown',
        inspector: m['inspector_name'] as String? ?? 'Unknown',
        health: HealthStatusExt.fromDb(m['health_status']?['name'] as String?),
        growthStage: m['growth_status']?['name'] as String? ?? 'Unknown',
        date: m['inspection_date'] as String? ?? 'Unknown',
        status: m['status'] as String? ?? 'Completed',
      );
}

class CampusData {
  final String campus;
  final int count;

  const CampusData({required this.campus, required this.count});
}

class DashboardData {
  final DashboardStats stats;
  final List<RecentPlant> recentPlants;
  final List<RecentInspection> recentInspections;
  final List<CampusData> campusDistribution;

  const DashboardData({
    required this.stats,
    required this.recentPlants,
    required this.recentInspections,
    required this.campusDistribution,
  });
}
