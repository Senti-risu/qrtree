import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/app_card.dart';
import 'package:flutter_application_1/widgets/compact_filter_panel.dart';

void main() {
  for (final report in [false, true]) {
    for (final width in [640.0, 1000.0, 1400.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${report ? 'report' : 'plants'} filter at $width / text $scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var filterOpened = false;
            var reset = false;
            var status = 'All';
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 900),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: SingleChildScrollView(
                      child: AppCard(
                        key: const Key('filter-panel'),
                        padding: const EdgeInsets.all(12),
                        child: CompactFilterPanel(
                          search: const TextField(
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search plants',
                            ),
                          ),
                          controls: [
                            if (report)
                              OutlinedButton.icon(
                                onPressed: () => filterOpened = true,
                                icon: const Icon(Icons.tune),
                                label: const Text('Filters'),
                              )
                            else
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'active',
                                    label: Text('Active'),
                                  ),
                                  ButtonSegment(
                                    value: 'archived',
                                    label: Text('Archived'),
                                  ),
                                ],
                                selected: const {'active'},
                                onSelectionChanged: (_) {},
                              ),
                            TextButton(
                              onPressed: () => reset = true,
                              child: const Text('Reset'),
                            ),
                          ],
                          choices: ['All', 'Healthy', 'Needs Attention', 'Dead']
                              .map(
                                (label) => ChoiceChip(
                                  label: Text(label),
                                  selected: label == status,
                                  onSelected: (_) => status = label,
                                ),
                              )
                              .toList(),
                          resultSummary: '4 of 4 plants shown',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            if (width >= 1000 && scale == 1) {
              expect(
                tester.getSize(find.byKey(const Key('filter-panel'))).height,
                lessThanOrEqualTo(160),
              );
              expect(
                tester.getTopLeft(find.text('Reset')).dy,
                lessThan(tester.getBottomLeft(find.byType(TextField)).dy),
              );
            }
            await tester.tap(find.text('Needs Attention'));
            expect(status, 'Needs Attention');
            await tester.tap(find.text('Reset'));
            expect(reset, isTrue);
            if (report) {
              await tester.tap(find.text('Filters'));
              expect(filterOpened, isTrue);
            }
            expect(find.text('Unknown'), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
