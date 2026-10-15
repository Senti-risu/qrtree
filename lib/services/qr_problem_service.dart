import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_session.dart';

class QrProblemService {
  final _client = Supabase.instance.client;

  static const problems = {
    'damaged': 'Damaged or broken',
    'faded': 'Faded / cannot scan',
    'missing': 'Missing label',
    'incorrect': 'Wrong label on plant',
    'other': 'Other problem',
  };

  Future<void> report(int plantId, String problem, String description) async {
    await _client.rpc(
      'report_qr_problem',
      params: {
        'p_session_token': AppSession.requiredToken,
        'p_plant_id': plantId,
        'p_problem': problem,
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
