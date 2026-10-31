import 'package:flutter/material.dart';
import 'package:kankal_ui/kankal_ui.dart';
import 'package:widgetbook/widgetbook.dart';

void main() => runApp(const KankalWidgetbook());

class KankalWidgetbook extends StatelessWidget {
  const KankalWidgetbook({super.key});

  @override
  Widget build(BuildContext context) => Widgetbook.material(
    home: const Center(child: Text('Select a component state to preview.')),
    addons: [
      MaterialThemeAddon(
        themes: [
          WidgetbookTheme(name: 'Light', data: AppTheme.light),
          WidgetbookTheme(name: 'Dark', data: AppTheme.dark),
        ],
      ),
      ViewportAddon([
        Viewports.none,
        IosViewports.iPhoneSE,
        AndroidViewports.samsungGalaxyA50,
        AndroidViewports.mediumTablet,
      ]),
      TextScaleAddon(),
    ],
    directories: [
      WidgetbookComponent(
        name: 'Button',
        useCases: [
          WidgetbookUseCase.child(
            name: 'Filled',
            child: const _Frame(
              child: AppButton(label: 'Continue', onPressed: _noop),
            ),
          ),
          WidgetbookUseCase.child(
            name: 'Outlined',
            child: const _Frame(
              child: AppButton(
                label: 'Secondary action',
                variant: AppButtonVariant.outlined,
                onPressed: _noop,
              ),
            ),
          ),
          WidgetbookUseCase.child(
            name: 'Busy',
            child: const _Frame(
              child: AppButton(label: 'Saving', isBusy: true, onPressed: _noop),
            ),
          ),
          WidgetbookUseCase.child(
            name: 'Disabled',
            child: const _Frame(
              child: AppButton(label: 'Continue', onPressed: null),
            ),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Text field',
        useCases: [
          WidgetbookUseCase.child(
            name: 'Default',
            child: _Frame(
              child: AppTextField(
                label: 'Workspace name',
                hintText: 'Northstar Studio',
              ),
            ),
          ),
          WidgetbookUseCase.child(
            name: 'Validation error',
            child: _Frame(
              child: Form(
                autovalidateMode: AutovalidateMode.always,
                child: AppTextField(
                  label: 'Workspace name',
                  validator: _requiredName,
                ),
              ),
            ),
          ),
          WidgetbookUseCase.child(
            name: 'Disabled',
            child: _Frame(
              child: AppTextField(label: 'Workspace name', enabled: false),
            ),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Content states',
        useCases: [
          WidgetbookUseCase.child(
            name: 'Loading',
            child: const _Frame(
              child: AppLoadingIndicator(label: 'Loading items'),
            ),
          ),
          WidgetbookUseCase.child(
            name: 'Empty',
            child: _Frame(
              child: AppEmptyState(
                title: 'Nothing here yet',
                message: 'Create your first item to get started.',
                action: AppButton(label: 'Create item', onPressed: _noop),
              ),
            ),
          ),
          WidgetbookUseCase.child(
            name: 'Error',
            child: _Frame(
              child: AppErrorState(
                title: 'Could not load items',
                message: 'Check your connection, then try again.',
                onRetry: _noop,
              ),
            ),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Confirmation dialog',
        useCases: [
          WidgetbookUseCase(
            name: 'Destructive',
            builder:
                (context) => _Frame(
                  child: AppButton(
                    label: 'Open confirmation',
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (dialogContext) => AppConfirmationDialog(
                                title: 'Delete this item?',
                                message:
                                    'This is a preview. No item will be deleted.',
                                cancelLabel: 'Keep item',
                                confirmLabel: 'Delete',
                                isDestructive: true,
                                onCancel:
                                    () => Navigator.of(dialogContext).pop(),
                                onConfirm:
                                    () => Navigator.of(dialogContext).pop(),
                              ),
                        ),
                  ),
                ),
          ),
        ],
      ),
    ],
  );
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void _noop() {}

String? _requiredName(String? value) =>
    value == null || value.trim().isEmpty ? 'Enter a workspace name.' : null;
