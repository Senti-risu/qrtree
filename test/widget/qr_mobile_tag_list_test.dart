import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/qr_mobile_tag_list.dart';

void main() {
  for (final size in const [Size(320, 600), Size(390, 844), Size(844, 390)]) {
    testWidgets('all 18 tags are reachable by scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: QrMobileTagList(
                toolbar: const SizedBox(
                  height: 210,
                  child: Text('Generate QR'),
                ),
                header: const SizedBox(height: 180, child: Text('QR tags')),
                itemCount: 18,
                itemBuilder: (_, index) => ListTile(
                  title: Text('ECOTAG-202610-${index + 1}'),
                  subtitle: const Text('Available'),
                ),
                loading: false,
                loadingMore: false,
                hasMore: false,
                onLoadMore: () {},
                emptyMessage: 'No QR tags found.',
              ),
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('ECOTAG-202610-18'),
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      expect(find.text('ECOTAG-202610-18').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('scrolling near the end requests more tags', (tester) async {
    var loadRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrMobileTagList(
            toolbar: const Text('Generate QR'),
            header: const Text('QR tags'),
            itemCount: 20,
            itemBuilder: (_, index) =>
                SizedBox(height: 100, child: Text('$index')),
            loading: false,
            loadingMore: false,
            hasMore: true,
            onLoadMore: () => loadRequests++,
            emptyMessage: 'No QR tags found.',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Load more QR tags'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(loadRequests, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
