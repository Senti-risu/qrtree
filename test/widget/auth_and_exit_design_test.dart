import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/auth/access_choice_screen.dart';
import 'package:flutter_application_1/screens/auth/login_screen.dart';
import 'package:flutter_application_1/screens/public/guest_entry_screen.dart';
import 'package:flutter_application_1/services/guest_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/registration_exit_dialog.dart';

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(Widget home, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(
      key: const Key('auth-dialog-preview'),
      child: child!,
    ),
  ),
  home: home,
);

Widget dialogHost(ValueChanged<String?> result) => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: FilledButton(
        onPressed: () async => result(
          await showDialog<String>(
            context: context,
            builder: (_) => const RegistrationExitDialog(),
          ),
        ),
        child: const Text('Open exit dialog'),
      ),
    ),
  ),
);

void main() {
  for (final guest in [false, true]) {
    testWidgets(
      '${guest ? 'guest' : 'staff'} entry works with phone keyboard',
      (tester) async {
        viewport(tester, const Size(320, 700));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          app(
            guest
                ? GuestEntryScreen(service: _GuestPreviewService())
                : const LoginScreen(),
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        final submit = find.text(guest ? 'Continue As Guest' : 'Sign In');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(
          find.text(guest ? 'Enter your age.' : 'Enter your password.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('${guest ? 'guest' : 'staff'} can change access type', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: guest
              ? GuestEntryScreen(service: _GuestPreviewService())
              : const LoginScreen(),
          routes: {
            '/login': (_) => const AccessChoiceScreen(),
            '/access': (_) => const AccessChoiceScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change Access Type'));
      await tester.pumpAndSettle();
      expect(find.byType(AccessChoiceScreen), findsOneWidget);
    });
  }

  testWidgets('staff can reveal and hide password without losing input', (
    tester,
  ) async {
    await tester.pumpWidget(app(const LoginScreen()));
    await tester.enterText(find.byType(TextField).last, 'Example password');
    await tester.tap(find.byTooltip('Show Password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Hide Password'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.obscureText, isTrue);
    expect(field.controller!.text, 'Example password');
  });
  for (final wide in [false, true]) {
    testWidgets(
      'access tiles use ${wide ? 'desktop columns' : 'phone stack'}',
      (tester) async {
        viewport(tester, wide ? const Size(1440, 900) : const Size(390, 844));
        await tester.pumpWidget(app(const AccessChoiceScreen()));
        await tester.pumpAndSettle();
        final staff = tester.getRect(find.text('Admin & Inspection Team'));
        final guest = tester.getRect(find.text('Guest'));
        if (wide) {
          expect(staff.top, closeTo(guest.top, 1));
          expect(guest.left, greaterThan(staff.right));
        } else {
          expect(staff.left, closeTo(guest.left, 1));
          expect(guest.top, greaterThan(staff.bottom));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('guest entry retains age validation and guest navigation', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    final service = _GuestPreviewService();
    Object? arguments;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GuestEntryScreen(service: service),
        routes: {
          '/guest-dashboard': (context) {
            arguments = ModalRoute.of(context)!.settings.arguments;
            return const Scaffold(body: Text('Guest dashboard'));
          },
        },
      ),
    );
    await tester.pumpAndSettle();
    final submit = find.text('Continue As Guest');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter your age.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '121');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter an age from 1 to 120.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Visitor');
    await tester.enterText(find.byType(TextFormField).last, '22');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(service.age, 22);
    expect(arguments, {'visit_id': 42, 'guest_name': 'Visitor'});
    expect(find.text('Guest dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 600),
    const Size(844, 390),
    const Size(1440, 900),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final page in [
        const AccessChoiceScreen(),
        const LoginScreen(),
        Builder(
          builder: (_) => GuestEntryScreen(service: _GuestPreviewService()),
        ),
      ]) {
        testWidgets('${page.runtimeType} forest layout $size / $scale', (
          tester,
        ) async {
          viewport(tester, size);
          await tester.pumpWidget(app(page, scale: scale));
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsOneWidget);
          expect(tester.takeException(), isNull);
          final action = find.text(
            page is LoginScreen ? 'Sign In' : 'Continue As Guest',
          );
          await tester.ensureVisible(action);
          expect(action.hitTestable(), findsOneWidget);
        });
      }
    }
  }

  for (final entry in {
    'Staff Sign In': '/staff-login',
    'Continue As Guest': '/guest-entry',
    'Back To EcoTag Home': '/',
  }.entries) {
    testWidgets('access action routes to ${entry.value}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          initialRoute: '/choice',
          routes: {
            '/choice': (_) => const AccessChoiceScreen(),
            entry.value: (_) => const Scaffold(body: Text('Destination')),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text('Destination'), findsOneWidget);
    });
  }

  for (final size in [
    const Size(320, 600),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1200, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'exit dialog uses aligned full-width buttons at $size / $scale',
        (tester) async {
          viewport(tester, size);
          await tester.pumpWidget(app(dialogHost((_) {}), scale: scale));
          await tester.tap(find.text('Open exit dialog'));
          await tester.pumpAndSettle();
          final save = tester.getRect(
            find.widgetWithText(FilledButton, 'Save Draft'),
          );
          final discard = tester.getRect(
            find.widgetWithText(OutlinedButton, 'Discard'),
          );
          final stay = tester.getRect(find.widgetWithText(TextButton, 'Stay'));
          expect(save.width, closeTo(discard.width, 1));
          expect(save.width, closeTo(stay.width, 1));
          expect(save.left, closeTo(stay.left, 1));
          expect(discard.top - save.bottom, greaterThanOrEqualTo(8));
          expect(stay.top - discard.bottom, greaterThanOrEqualTo(8));
          await tester.ensureVisible(find.text('Stay'));
          await tester.tap(find.text('Stay'));
          await tester.pumpAndSettle();
          expect(find.byType(RegistrationExitDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final action in ['Save Draft', 'Discard', 'Stay']) {
    testWidgets('exit dialog returns the correct $action decision', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(app(dialogHost((value) => result = value)));
      await tester.tap(find.text('Open exit dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(
        result,
        {'Save Draft': 'save', 'Discard': 'discard', 'Stay': 'stay'}[action],
      );
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'staff login removes explanations but retains field validation / $scale',
      (tester) async {
        viewport(tester, const Size(320, 700));
        await tester.pumpWidget(app(const LoginScreen(), scale: scale));
        await tester.pumpAndSettle();
        expect(
          find.text('Use the account issued to you by EcoTag.'),
          findsNothing,
        );
        expect(find.textContaining('This device remembers'), findsNothing);
        final signIn = find.widgetWithText(FilledButton, 'Sign In');
        await tester.ensureVisible(signIn);
        await tester.tap(signIn);
        await tester.pumpAndSettle();
        expect(find.text('Enter your username.'), findsOneWidget);
        expect(find.text('Enter your password.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'access choices keep their actions without explanatory paragraphs',
    (tester) async {
      await tester.pumpWidget(app(const AccessChoiceScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Staff Sign In'), findsOneWidget);
      expect(find.text('Continue As Guest'), findsOneWidget);
      expect(find.textContaining('visitor statistics'), findsNothing);
      expect(find.textContaining('verified securely'), findsNothing);
      expect(find.textContaining('Use your assigned'), findsNothing);
      expect(find.textContaining('Choose the option'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('render compact exit and authentication previews', (
    tester,
  ) async {
    await (FontLoader(
      AppTheme.fontFamily,
    )..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final item in <String, Widget>{
      'login': const LoginScreen(),
      'access': const AccessChoiceScreen(),
      'guest': GuestEntryScreen(service: _GuestPreviewService()),
      'exit': dialogHost((_) {}),
    }.entries) {
      viewport(tester, const Size(390, 844));
      await tester.pumpWidget(app(item.value));
      await tester.pumpAndSettle();
      if (item.key == 'exit') {
        await tester.tap(find.text('Open exit dialog'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('auth-dialog-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/layout_previews').createSync(recursive: true);
        File(
          'build/layout_previews/compact-${item.key}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
    for (final item in <String, Widget>{
      'login': const LoginScreen(),
      'access': const AccessChoiceScreen(),
      'guest': GuestEntryScreen(service: _GuestPreviewService()),
    }.entries) {
      viewport(tester, const Size(1440, 900));
      await tester.pumpWidget(app(item.value));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('auth-dialog-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'build/layout_previews/desktop-${item.key}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}

class _GuestPreviewService extends GuestService {
  _GuestPreviewService()
    : super(
        supabase: SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int? age;

  @override
  Future<int> startGuestVisit({required int age}) async {
    this.age = age;
    return 42;
  }
}
