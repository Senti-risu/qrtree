import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/app_role.dart';
import 'package:flutter_application_1/services/persistent_session.dart';
import 'package:flutter_application_1/widgets/protected_staff_route.dart';

void main() {
  const identity = SessionIdentity(
    userId: 4,
    username: 'Staff',
    role: AppRole.collegeAdmin,
    campusId: 1,
    collegeId: 2,
  );

  testWidgets('returning from image picker preserves the hidden form state', (
    tester,
  ) async {
    final validation = Completer<SessionIdentity?>();
    var checks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ProtectedStaffRoute(
          arguments: identity.arguments,
          validateSession: () =>
              checks++ == 0 ? Future.value(identity) : validation.future,
          builder: (_) => const Scaffold(body: TextField()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mango registration draft');
    final originalState = tester.state(find.byType(TextField));
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.state(find.byType(TextField, skipOffstage: false)),
      same(originalState),
    );
    validation.complete(identity);
    await tester.pumpAndSettle();
    expect(find.text('Mango registration draft'), findsOneWidget);
    expect(tester.state(find.byType(TextField)), same(originalState));
    expect(tester.takeException(), isNull);
  });

  Widget app(
    Future<SessionIdentity?> Function() validate, {
    Map<String, dynamic>? arguments,
    bool requiresScope = true,
  }) => MaterialApp(
    home: ProtectedStaffRoute(
      arguments: arguments ?? identity.arguments,
      validateSession: validate,
      requiresScope: requiresScope,
      builder: (_) => const Text('Private page'),
    ),
    routes: {'/staff-login': (_) => const Scaffold(body: Text('Staff login'))},
  );

  testWidgets('verified account opens staff page', (tester) async {
    await tester.pumpWidget(app(() async => identity));
    await tester.pumpAndSettle();
    expect(find.text('Private page'), findsOneWidget);
  });

  testWidgets('signed-out visitor cannot open staff page', (tester) async {
    await tester.pumpWidget(app(() async => null));
    await tester.pumpAndSettle();
    expect(find.text('Private page'), findsNothing);
    expect(find.text('Staff login'), findsOneWidget);
  });

  testWidgets('detail links may omit unused scope fields', (tester) async {
    await tester.pumpWidget(
      app(
        () async => identity,
        requiresScope: false,
        arguments: {
          'user_id': identity.userId,
          'username': identity.username,
          'role': identity.role.value,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private page'), findsOneWidget);
  });

  testWidgets('resuming revalidates access before showing private content', (
    tester,
  ) async {
    var signedIn = true;
    await tester.pumpWidget(app(() async => signedIn ? identity : null));
    await tester.pumpAndSettle();
    signedIn = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Private page'), findsNothing);
    expect(find.text('Staff login'), findsOneWidget);
  });

  for (final field in ['user_id', 'role', 'campus_id', 'college_id']) {
    testWidgets('forged $field cannot open staff page', (tester) async {
      await tester.pumpWidget(
        app(
          () async => identity,
          arguments: {...identity.arguments, field: 'forged'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private page'), findsNothing);
      expect(find.textContaining('does not match'), findsOneWidget);
    });
  }

  testWidgets('network failure hides page and allows retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      app(() async {
        if (attempts++ == 0) throw Exception('offline');
        return identity;
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private page'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Private page'), findsOneWidget);
  });

  testWidgets('rejected session redirects to login', (tester) async {
    await tester.pumpWidget(app(() async => throw const SessionRejected()));
    await tester.pumpAndSettle();
    expect(find.text('Staff login'), findsOneWidget);
  });
}
