import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_kankal/app/app.dart';
import 'package:flutter_kankal/app/routes.dart';
import 'package:flutter_kankal/core/auth/auth_api.dart';
import 'package:flutter_kankal/core/auth/session.dart';

class _ExternalAuthApi implements AuthApi {
  @override
  Session? get currentSession => null;

  @override
  Future<Session> signInWithPassword({
    required String email,
    required String password,
  }) async => Session(userId: 'user-1', email: email);

  @override
  Future<void> requestEmailOtp({required String email}) async {}

  @override
  Future<Session> signInWithEmailOtp({
    required String email,
    required String code,
  }) async => Session(userId: 'user-1', email: email);

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('external auth has no mock demo credentials or disclosure', (
    tester,
  ) async {
    await tester.pumpWidget(
      KankalApp(services: AppServices(authApi: _ExternalAuthApi())),
    );
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields, hasLength(2));
    expect(fields.map((field) => field.controller!.text), everyElement(''));
    expect(find.textContaining('LOCAL DEMO'), findsNothing);
    expect(find.textContaining('person@example.com'), findsNothing);
    expect(find.textContaining('demo'), findsNothing);
  });

  testWidgets('protected item route returns a signed-out visitor to sign-in', (
    tester,
  ) async {
    await tester.pumpWidget(const KankalApp());
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(AppRoutes.items);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Your items'), findsNothing);
  });

  testWidgets('sign-in form shows validation before calling authentication', (
    tester,
  ) async {
    await tester.pumpWidget(const KankalApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('sign-in choices and email survive a width change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const KankalApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'person@example.com',
    );
    await tester.tap(find.text('Email code'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1200, 844);
    await tester.pumpAndSettle();

    expect(find.text('Send demo code'), findsOneWidget);
    expect(find.text('Email code'), findsOneWidget);
    expect(find.text('person@example.com'), findsOneWidget);
  });
}
