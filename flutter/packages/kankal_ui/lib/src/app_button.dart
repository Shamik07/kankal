import 'package:flutter/material.dart';

enum AppButtonVariant { filled, outlined }

/// A consistent Material button with an optional leading icon and busy state.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.isBusy = false,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isBusy;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final callback = isBusy ? null : onPressed;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isBusy)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (isBusy || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    final button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
        onPressed: callback,
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: callback,
        child: child,
      ),
    };

    return Semantics(
      label: label,
      liveRegion: isBusy,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
