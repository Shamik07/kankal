import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kankal_ui/kankal_ui.dart';

void main() {
  testWidgets('busy button disables its action and exposes progress', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppButton(
            label: 'Save changes',
            isBusy: true,
            onPressed: () => called = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save changes'));
    expect(called, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('text field uses caller validator and obscures sensitive input', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Form(
            key: formKey,
            child: const AppTextField(
              label: 'Passphrase',
              obscureText: true,
              validator: _required,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Enter a value.'), findsOneWidget);
  });

  testWidgets('confirmation dialog reports confirm and cancel actions', (
    tester,
  ) async {
    var confirmed = false;
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppConfirmationDialog(
            title: 'Delete this item?',
            message: 'This item will be removed.',
            cancelLabel: 'Keep item',
            confirmLabel: 'Delete',
            onCancel: () => cancelled = true,
            onConfirm: () => confirmed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Keep item'));
    expect(cancelled, isTrue);
    expect(confirmed, isFalse);

    await tester.tap(find.text('Delete'));
    expect(confirmed, isTrue);
  });
}

String? _required(String? value) =>
    value == null || value.isEmpty ? 'Enter a value.' : null;
