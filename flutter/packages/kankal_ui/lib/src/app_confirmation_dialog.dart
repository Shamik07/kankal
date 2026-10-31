import 'package:flutter/material.dart';

/// A reusable confirmation dialog whose actions are handled by its caller.
class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: onConfirm,
          style:
              isDestructive
                  ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    minimumSize: const Size(48, 48),
                  )
                  : FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
