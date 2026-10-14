import 'package:supabase_flutter/supabase_flutter.dart';

class AccountScopeNames {
  final String? campusName;
  final String? collegeName;

  const AccountScopeNames({this.campusName, this.collegeName});
}

class AccountProfileService {
  AccountProfileService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AccountScopeNames> loadScopeNames({
    required int? campusId,
    required int? collegeId,
  }) async {
    Map<String, dynamic>? college;

    if (collegeId != null) {
      college = await _client
          .from('college')
          .select('college_name,campus_id')
          .eq('college_id', collegeId)
          .maybeSingle();
    }

    final resolvedCampusId = campusId ?? college?['campus_id'] as int?;
    Map<String, dynamic>? campus;

    if (resolvedCampusId != null) {
      campus = await _client
          .from('campus')
          .select('campus_name')
          .eq('campus_id', resolvedCampusId)
          .maybeSingle();
    }

    return AccountScopeNames(
      campusName: _cleanName(campus?['campus_name']),
      collegeName: _cleanName(college?['college_name']),
    );
  }

  String? _cleanName(dynamic value) {
    final name = value?.toString().trim() ?? '';
    return name.isEmpty ? null : name;
  }
}
