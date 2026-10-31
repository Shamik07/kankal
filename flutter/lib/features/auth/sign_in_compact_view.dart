import 'package:flutter/material.dart';

class SignInCompactView extends StatelessWidget {
  const SignInCompactView({super.key, required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: form,
    ),
  );
}
