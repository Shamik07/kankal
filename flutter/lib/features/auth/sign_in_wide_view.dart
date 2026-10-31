import 'package:flutter/material.dart';

class SignInWideView extends StatelessWidget {
  const SignInWideView({super.key, required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KANKAL / WORKSPACE',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'A calmer place\nfor the work ahead.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 18),
            Text(
              'Try both sign-in methods, then create and edit a sample list.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
      const SizedBox(width: 56),
      Expanded(child: form),
    ],
  );
}
