import 'package:flutter/material.dart';
import 'package:kankal_ui/kankal_ui.dart';

void main() => runApp(const ShowcaseApp());

class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key});

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> {
  bool _dark = false;
  bool _busy = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kankal UI',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Kankal UI'),
        actions: [
          IconButton(
            tooltip: _dark ? 'Use light theme' : 'Use dark theme',
            onPressed: () => setState(() => _dark = !_dark),
            icon: Icon(
              _dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 48),
            children: [
              const _HeroIntro(),
              const SizedBox(height: 30),
              _Section(
                title: 'Buttons',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward,
                      onPressed: () {},
                    ),
                    AppButton(
                      label: 'Secondary action',
                      variant: AppButtonVariant.outlined,
                      onPressed: () {},
                    ),
                    AppButton(
                      label: _busy ? 'Saving' : 'Show busy state',
                      isBusy: _busy,
                      onPressed: () {
                        setState(() => _busy = true);
                        Future<void>.delayed(const Duration(seconds: 2), () {
                          if (mounted) setState(() => _busy = false);
                        });
                      },
                    ),
                    const AppButton(label: 'Disabled', onPressed: null),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Form fields',
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Your name',
                      controller: _nameController,
                      hintText: 'e.g. Sam Rivera',
                      textInputAction: TextInputAction.next,
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter your name to continue.'
                                  : null,
                    ),
                    const SizedBox(height: 14),
                    const AppTextField(
                      label: 'Email address',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icon(Icons.mail_outline),
                      hintText: 'you@example.com',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Confirmation dialog',
                child: AppButton(
                  label: 'Show destructive confirmation',
                  onPressed:
                      () => showDialog<void>(
                        context: context,
                        builder:
                            (dialogContext) => AppConfirmationDialog(
                              title: 'Delete this item?',
                              message: 'This example item will be removed.',
                              cancelLabel: 'Keep item',
                              confirmLabel: 'Delete',
                              isDestructive: true,
                              onCancel: () => Navigator.of(dialogContext).pop(),
                              onConfirm:
                                  () => Navigator.of(dialogContext).pop(),
                            ),
                      ),
                ),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Content states',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 560 ? 2 : 1;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: columns == 2 ? 1.35 : 1.55,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: const [
                        _StatePanel(child: AppLoadingIndicator()),
                        _StatePanel(
                          child: AppEmptyState(
                            title: 'Nothing here yet',
                            message:
                                'New items will show up here when they are ready.',
                          ),
                        ),
                        _StatePanel(
                          child: AppErrorState(
                            title: 'Could not load items',
                            message: 'Check your connection, then try again.',
                            onRetry: _noop,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static void _noop() {}
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'A steady starting point',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Reusable controls and clear states, built on familiar Material patterns.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: const EdgeInsets.all(8), child: child));
}
