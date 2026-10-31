import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_kankal/core/diagnostics/diagnostics.dart';
import 'package:flutter_kankal/core/items/item.dart';
import 'package:flutter_kankal/core/items/items_api.dart';
import 'package:flutter_kankal/features/items/item_editor_view_model.dart';

void main() {
  test(
    'failed item load records item-read failure and shows the load error',
    () async {
      final error = StateError('read failed');
      final diagnostics = _RecordingDiagnostics();
      final viewModel = ItemEditorViewModel(
        _ThrowingItemsApi(error),
        diagnostics,
        itemId: 'item-1',
      );

      await viewModel.load();

      expect(diagnostics.errorEvents, [DiagnosticEvent.itemReadFailed]);
      expect(
        viewModel.errorMessage,
        'This item could not be opened. Please go back and try again.',
      );
      expect(viewModel.isBusy, isFalse);
    },
  );
}

class _RecordingDiagnostics implements Diagnostics {
  final errorEvents = <DiagnosticEvent>[];

  @override
  void record(DiagnosticEvent event) {}

  @override
  void recordError(DiagnosticEvent event, Object error, StackTrace stackTrace) {
    errorEvents.add(event);
  }
}

class _ThrowingItemsApi implements ItemsApi {
  _ThrowingItemsApi(this.error);

  final Object error;

  @override
  Future<Item?> getById(String id) async => throw error;

  @override
  Future<List<Item>> getAll() => throw UnimplementedError();

  @override
  Future<Item> create({required String title, required String description}) =>
      throw UnimplementedError();

  @override
  Future<Item?> update(Item item) => throw UnimplementedError();

  @override
  Future<bool> delete(String id) => throw UnimplementedError();
}
