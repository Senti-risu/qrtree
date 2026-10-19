import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/theme/app_colors.dart';
import 'package:flutter_application_1/widgets/app_shell.dart';
import 'package:flutter_application_1/widgets/app_sidebar.dart';
import 'package:flutter_application_1/widgets/app_top_navbar.dart';
import 'package:flutter_application_1/widgets/app_page_header.dart';
import 'package:flutter_application_1/widgets/app_workspace_page.dart';
import 'package:flutter_application_1/widgets/full_width_data_table.dart';
import 'package:flutter_application_1/widgets/account_access_controls.dart';

void main() {
  testWidgets('reference workspace keeps navigation and account actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final font in {
      AppTheme.fontFamily: 'assets/fonts/DMSans-Variable.ttf',
      AppTheme.headingFontFamily: 'assets/fonts/Manrope-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: const Key('reference-preview'),
          child: AppShell(
            activeRoute: '/inspection-accounts',
            mobileTitle: 'Inspection Accounts',
            userId: 1,
            username: 'College Admin',
            role: 'college_admin',
            child: AppWorkspacePage(
              header: AppPageHeader(
                title: 'Inspection Team Accounts',
                subtitle:
                    'Create, archive, and restore inspection accounts for your college.',
                trailing: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Create Account'),
                ),
              ),
              tools: AppToolbarCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by username...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final text in [
                          'All (1)',
                          'Active (1)',
                          'Inactive (0)',
                        ])
                          OutlinedButton(onPressed: () {}, child: Text(text)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1 of 1 accounts',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              body: AppTablePanel(
                child: FullWidthDataTable(
                  columns: [
                    for (final text in [
                      'ACCOUNT',
                      'ROLE',
                      'STATUS / ACCESS',
                      'ACTIONS',
                    ])
                      DataColumn(label: Text(text)),
                  ],
                  rows: [
                    DataRow(
                      cells: [
                        const DataCell(Text('Inspectacc_1')),
                        const DataCell(Text('Inspection Team')),
                        DataCell(
                          AccountStatusButton(active: true, onPressed: () {}),
                        ),
                        DataCell(
                          AccountRowActions(
                            onEdit: () => edits++,
                            onArchive: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sidebar = tester.getRect(find.byType(AppSidebar));
    final navbar = tester.getRect(find.byType(AppTopNavbar));
    expect(sidebar.top, 0);
    expect(navbar.left, sidebar.right);
    expect(
      AppTheme.light.textTheme.bodyMedium?.fontFamily,
      AppTheme.fontFamily,
    );
    expect(
      AppTheme.light.textTheme.headlineSmall?.fontFamily,
      AppTheme.headingFontFamily,
    );
    await tester.tap(find.text('Edit'));
    expect(edits, 1);
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('reference-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/layout_previews').createSync(recursive: true);
      File(
        'build/layout_previews/reference-workspace.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
