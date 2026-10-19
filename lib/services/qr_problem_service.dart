import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';

class QrProblemService {
  QrProblemService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  static const problems = {
    'damaged': 'Damaged Or Broken',
    'faded': 'Faded / cannot scan',
    'missing': 'Missing QR',
    'incorrect': 'Wrong QR On Plant',
    'other': 'Other Problem',
  };

  Future<void> report(int plantId, String problem, String description) async {
    await _client.rpc(
      problem == 'damaged' ? 'report_qr_damage' : 'report_qr_problem',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
        if (problem != 'damaged') 'p_problem': problem,
        'p_description': description.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> list() async {
    final rows = await _client.rpc(
      'list_qr_problem_reports',
      params: {'p_session_token': AppSession.requiredToken},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> review(int reportId, bool confirm, String note) async {
    await _client.rpc(
      'review_qr_problem_report',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_report_id': reportId,
        'p_confirm': confirm,
        'p_note': note.trim(),
      },
    );
  }
}
