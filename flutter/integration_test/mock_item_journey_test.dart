import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_kankal/app/app.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('password sign-in can create, edit, delete, and sign out', (
    tester,
  ) async {
    // Prevent Android's real IME from replaying stale text after enterText.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);

    await tester.pumpWidget(const KankalApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Your items'), findsOneWidget);
    expect(find.text('Sample item'), findsOneWidget);

    await tester.tap(find.text('New item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Title'), 'Journey item');
    await tester.enterText(
      find.bySemanticsLabel('Description'),
      'Created in the app journey.',
    );
    await tester.tap(find.text('Create item'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Journey item'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Journey item'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Journey item'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.bySemanticsLabel('Title'),
      'Updated journey item',
    );
    final saveChanges = find.text('Save changes');
    await tester.ensureVisible(saveChanges);
    await tester.pumpAndSettle();
    await tester.tap(saveChanges);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Updated journey item'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Updated journey item'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete Updated journey item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Updated journey item'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Email code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send demo code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Email code'), '123456');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Your items'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
