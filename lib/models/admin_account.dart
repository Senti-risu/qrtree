class AdminAccount {
  const AdminAccount({
    required this.userId,
    required this.username,
    required this.role,
    required this.isActive,
    this.campusId,
    this.campusName,
    this.collegeId,
    this.collegeName,
    this.archivedAt,
    this.archiveReason,
  });

  final int userId;
  final String username;
  final String role;
  final bool isActive;
  final int? campusId;
  final String? campusName;
  final int? collegeId;
  final String? collegeName;
  final DateTime? archivedAt;
  final String? archiveReason;

  bool get isArchived => archivedAt != null;

  String get roleLabel => switch (role) {
    'university_admin' => 'University Admin',
    'campus_admin' => 'Campus Admin',
    'college_admin' => 'College Admin',
    _ => role,
  };

  String get scopeLabel => collegeName ?? campusName ?? 'University-wide';

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
    userId: json['user_id'] as int,
    username: json['username']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    isActive: json['is_active'] as bool? ?? false,
    campusId: json['campus_id'] as int?,
    campusName: json['campus_name']?.toString(),
    collegeId: json['college_id'] as int?,
    collegeName: json['college_name']?.toString(),
    archivedAt: DateTime.tryParse(json['archived_at']?.toString() ?? ''),
    archiveReason: json['archive_reason']?.toString(),
  );
}

class AdminScopeOption {
  const AdminScopeOption({required this.id, required this.name, this.campusId});

  final int id;
  final String name;
  final int? campusId;
}
