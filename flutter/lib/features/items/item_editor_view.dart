import 'package:flutter/material.dart';
import 'package:kankal_ui/kankal_ui.dart';
import 'package:stacked/stacked.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/items/items_api.dart';
import 'item_editor_view_model.dart';

class ItemEditorView extends StatelessWidget {
  const ItemEditorView({
    super.key,
    required this.itemsApi,
    required this.itemId,
    this.diagnostics = const NoopDiagnostics(),
  });
  final ItemsApi itemsApi;
  final String? itemId;
  final Diagnostics diagnostics;

  @override
  Widget build(BuildContext context) =>
      ViewModelBuilder<ItemEditorViewModel>.reactive(
        viewModelBuilder:
            () => ItemEditorViewModel(itemsApi, diagnostics, itemId: itemId),
        onViewModelReady: (model) => model.load(),
        builder: (context, model, _) => _EditorContent(model: model),
      );
}

class _EditorContent extends StatefulWidget {
  const _EditorContent({required this.model});
  final ItemEditorViewModel model;

  @override
  State<_EditorContent> createState() => _EditorContentState();
}

class _EditorContentState extends State<_EditorContent> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _initialized = false;

  @override
  void didUpdateWidget(covariant _EditorContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _populate();
  }

  void _populate() {
    final item = widget.model.item;
    if (!_initialized && item != null) {
      _title.text = item.title;
      _description.text = item.description;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (await widget.model.save(_title.text, _description.text) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.model.isEditing ? 'Changes saved' : 'Item created',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    _populate();
    final model = widget.model;
    return Scaffold(
      appBar: AppBar(title: Text(model.isEditing ? 'Edit item' : 'New item')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child:
                model.isBusy && model.isEditing && model.item == null
                    ? const AppLoadingIndicator(label: 'Loading item')
                    : model.errorMessage != null &&
                        model.itemId != null &&
                        model.item == null
                    ? AppErrorState(
                      title: 'Item unavailable',
                      message: model.errorMessage!,
                      onRetry: model.load,
                    )
                    : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                model.isEditing
                                    ? 'Make it yours'
                                    : 'Add to your list',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 20),
                              AppTextField(
                                label: 'Title',
                                controller: _title,
                                textInputAction: TextInputAction.next,
                                validator:
                                    (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'A title is required.'
                                            : null,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Description',
                                controller: _description,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                hintText: 'Add a little context',
                              ),
                              if (model.errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    model.errorMessage!,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              AppButton(
                                label:
                                    model.isEditing
                                        ? 'Save changes'
                                        : 'Create item',
                                icon: Icons.check,
                                onPressed: model.isBusy ? null : _save,
                                isBusy: model.isBusy,
                                expand: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}
