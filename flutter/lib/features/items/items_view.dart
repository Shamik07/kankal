import 'package:flutter/material.dart';
import 'package:kankal_ui/kankal_ui.dart';
import 'package:stacked/stacked.dart';

import '../../app/routes.dart';
import '../../core/auth/auth_api.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/items/item.dart';
import '../../core/items/items_api.dart';
import 'items_view_model.dart';

class ItemsView extends StatelessWidget {
  const ItemsView({
    super.key,
    required this.authApi,
    required this.itemsApi,
    this.diagnostics = const NoopDiagnostics(),
  });

  final AuthApi authApi;
  final ItemsApi itemsApi;
  final Diagnostics diagnostics;

  @override
  Widget build(
    BuildContext context,
  ) => ViewModelBuilder<ItemsViewModel>.reactive(
    viewModelBuilder: () => ItemsViewModel(authApi, itemsApi, diagnostics),
    onViewModelReady: (model) => model.load(),
    builder:
        (context, model, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Your items'),
            actions: [
              TextButton.icon(
                onPressed: model.isBusy ? null : () => _signOut(context, model),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final heading = Text(
                          'A small list, ready to grow.',
                          style: Theme.of(context).textTheme.headlineSmall,
                        );
                        final action = AppButton(
                          label: 'New item',
                          icon: Icons.add,
                          onPressed: () => _openEditor(context, model),
                          expand: constraints.maxWidth < 560,
                        );
                        if (constraints.maxWidth < 560) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              heading,
                              const SizedBox(height: 16),
                              action,
                            ],
                          );
                        }
                        return Row(
                          children: [Expanded(child: heading), action],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    if (model.errorMessage != null) ...[
                      AppErrorState(
                        title: 'Something went wrong',
                        message: model.errorMessage!,
                        onRetry: model.load,
                      ),
                    ] else if (model.isBusy && !model.hasLoaded)
                      const Expanded(
                        child: AppLoadingIndicator(label: 'Loading your items'),
                      )
                    else if (model.items.isEmpty)
                      Expanded(
                        child: AppEmptyState(
                          title: 'Nothing here yet',
                          message: 'Create an item to start your list.',
                          icon: Icons.checklist,
                          action: AppButton(
                            label: 'Create first item',
                            icon: Icons.add,
                            onPressed: () => _openEditor(context, model),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: model.items.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 10),
                          itemBuilder:
                              (context, index) => _ItemCard(
                                item: model.items[index],
                                onEdit:
                                    () => _edit(
                                      context,
                                      model,
                                      model.items[index],
                                    ),
                                onDelete:
                                    () => _delete(
                                      context,
                                      model,
                                      model.items[index],
                                    ),
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
  );

  Future<void> _signOut(BuildContext context, ItemsViewModel model) async {
    await model.signOut();
    if (context.mounted && model.errorMessage == null) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.signIn, (_) => false);
    }
  }

  void _openEditor(
    BuildContext context,
    ItemsViewModel model, {
    String? itemId,
  }) => Navigator.of(
    context,
  ).pushNamed(AppRoutes.editItem, arguments: itemId).then((_) {
    if (context.mounted) model.load();
  });

  void _edit(BuildContext context, ItemsViewModel model, Item item) =>
      _openEditor(context, model, itemId: item.id);

  Future<void> _delete(
    BuildContext context,
    ItemsViewModel model,
    Item item,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AppConfirmationDialog(
            title: 'Delete this item?',
            message: '“${item.title}” will be removed from this demo list.',
            cancelLabel: 'Keep item',
            confirmLabel: 'Delete',
            isDestructive: true,
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
    );
    if (confirm != true) return;
    try {
      final deleted = await itemsApi.delete(item.id);
      if (deleted) {
        diagnostics.record(DiagnosticEvent.itemDeleteSucceeded);
      } else {
        diagnostics.record(DiagnosticEvent.itemDeleteFailed);
      }
      await model.load();
      if (context.mounted && deleted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Item deleted')));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This item could not be deleted.')),
        );
      }
    } catch (error, stackTrace) {
      diagnostics.recordError(
        DiagnosticEvent.itemDeleteFailed,
        error,
        stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete this item. Please try again.'),
          ),
        );
      }
    }
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final Item item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(child: Icon(Icons.check)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description.isEmpty
                                ? 'No description'
                                : item.description,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _actions(),
                ),
              ],
            ),
          );
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: const CircleAvatar(child: Icon(Icons.check)),
          title: Text(item.title),
          subtitle: Text(
            item.description.isEmpty ? 'No description' : item.description,
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: _actions()),
        );
      },
    ),
  );

  List<Widget> _actions() => [
    IconButton(
      tooltip: 'Edit ${item.title}',
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined),
    ),
    IconButton(
      tooltip: 'Delete ${item.title}',
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline),
    ),
  ];
}
