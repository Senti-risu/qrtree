import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/services/qr_problem_service.dart';
import 'package:flutter_application_1/screens/qr/qr_problem_reports_screen.dart';

class ReportsFixture extends QrProblemService {
  ReportsFixture(this.rows)
    : super(
        client: SupabaseClient(
          'https://example.com',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final List<Map<String, dynamic>> rows;
  @override
  Future<List<Map<String, dynamic>>> list() async => rows;
}

Map<String, dynamic> report({
  String problem = 'damaged',
  String status = 'confirmed',
}) => {
  'report_id': 1,
  'common_name': 'Mango',
  'qr_code_string': 'ECOTAG-202610-000022',
  'problem': problem,
  'status': status,
  'description': 'The QR label is broken.',
  'reported_by': 'Inspection Team',
  'created_at': '2026-10-20T01:00:00Z',
  'review_note': 'Automatically marked damaged; no approval required.',
};

void main() {
  for (final width in [320.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'damage history has no approval controls at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: QrProblemReportsScreen(
                canReview: true,
                service: ReportsFixture([report()]),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('QR Report History'), findsOneWidget);
          expect(find.text('Mango · Damage Reported'), findsOneWidget);
          expect(find.text('Confirm Problem'), findsNothing);
          expect(find.text('Dismiss'), findsNothing);
          expect(find.textContaining('No approval required'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'old pending damage reports ask for database update, not approval',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: QrProblemReportsScreen(
            canReview: true,
            service: ReportsFixture([report(status: 'pending')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirm Problem'), findsNothing);
      expect(find.textContaining('latest database update'), findsOneWidget);
    },
  );
  testWidgets('other QR issues retain their existing review flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QrProblemReportsScreen(
          canReview: true,
          service: ReportsFixture([
            report(problem: 'incorrect', status: 'pending'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm Problem'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });
  test(
    'automatic damage SQL preserves assignment, scope, history and final QR states',
    () {
      final sql = File(
        'supabase/migrations/202610200002_automatic_qr_damage.sql',
      ).readAsStringSync();
      expect(sql, contains('require_app_session(p_session_token)'));
      expect(
        sql,
        contains(
          'p.campus_id = actor.campus_id and p.college_id = actor.college_id',
        ),
      );
      expect(sql, contains("lifecycle_status = 'damaged'"));
      expect(
        sql,
        contains("q.lifecycle_status not in ('assigned', 'damaged')"),
      );
      expect(sql, contains("p.qr_tag_id is distinct from r.qr_tag_id"));
      expect(
        sql,
        contains(
          'revoke all on function public.apply_reported_qr_damage(bigint) from public, anon, authenticated',
        ),
      );
      expect(sql, contains('report_qr_damage('));
      expect(sql, contains('perform public.apply_reported_qr_damage(new_id)'));
      expect(sql, contains("problem = 'damaged' and status = 'pending'"));
      expect(sql, isNot(contains('delete from')));
      expect(sql, isNot(contains('set qr_code_string')));
      expect(sql, isNot(contains('college_admin_confirm_qr_reprinted')));
    },
  );
  test(
    'damage client requires the new endpoint before claiming damage is effective',
    () {
      final source = File(
        'lib/services/qr_problem_service.dart',
      ).readAsStringSync();
      expect(
        source,
        contains(
          "problem == 'damaged' ? 'report_qr_damage' : 'report_qr_problem'",
        ),
      );
    },
  );
}
