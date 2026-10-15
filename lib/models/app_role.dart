enum AppRole {
  superAdmin('super_admin', 'Super Admin'),
  universityAdmin('university_admin', 'University Admin'),
  campusAdmin('campus_admin', 'Campus Admin'),
  collegeAdmin('college_admin', 'College Admin'),
  inspectionTeam('inspection_team', 'Inspection Team'),
  unknown('', 'Unknown role');

  const AppRole(this.value, this.label);

  final String value;
  final String label;

  static AppRole fromValue(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    return AppRole.values.firstWhere(
      (role) => role.value == normalized,
      orElse: () => AppRole.unknown,
    );
  }
}

/// Centralized UI capabilities for EcoTag roles.
///
/// These checks improve consistency in the app, but database RPCs must continue
/// to enforce authorization because client-side controls are not a security
/// boundary.
class RoleCapabilities {
  const RoleCapabilities(this.role);

  factory RoleCapabilities.fromValue(String? value) =>
      RoleCapabilities(AppRole.fromValue(value));

  final AppRole role;

  bool get canViewPlantRecords => role != AppRole.unknown;

  bool get canViewReports => role != AppRole.unknown;

  bool get canRegisterPlants => role == AppRole.collegeAdmin;

  bool get canArchivePlants => role == AppRole.collegeAdmin;

  bool get canRestorePlants => role == AppRole.collegeAdmin;

  bool get canInspectPlants => role == AppRole.inspectionTeam;

  /// Every recognized EcoTag staff role can scan a label.
  ///
  /// What happens after a scan remains role-aware. For example, only a
  /// College Admin can assign an available label while the other roles get a
  /// read-only result.
  bool get canScanQr => role != AppRole.unknown;

  bool get hasAssignedCampusScope =>
      role == AppRole.campusAdmin ||
      role == AppRole.collegeAdmin ||
      role == AppRole.inspectionTeam;

  bool get hasAssignedCollegeScope =>
      role == AppRole.collegeAdmin || role == AppRole.inspectionTeam;

  /// A College Admin can register only inside the account's assigned scope.
  bool get locksRegistrationScope => role == AppRole.collegeAdmin;
}
