import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_application_1/widgets/app_version_info.dart';

void main() {
  testWidgets('shows installed version and build number', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'EcoTag',
      packageName: 'test.ecotag',
      version: '1.4.2',
      buildNumber: '1018',
      buildSignature: '',
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppVersionInfo())),
    );
    await tester.pumpAndSettle();
    expect(find.text('EcoTag 1.4.2 (build 1018)'), findsOneWidget);
  });
}
