import 'package:stacked/stacked.dart';

import '../../core/diagnostics/diagnostics.dart';
import '../../core/items/item.dart';
import '../../core/items/items_api.dart';

class ItemEditorViewModel extends BaseViewModel {
  ItemEditorViewModel(this._itemsApi, this._diagnostics, {this.itemId});

  final ItemsApi _itemsApi;
  final Diagnostics _diagnostics;
  final String? itemId;
  Item? item;
  String? errorMessage;
  bool get isEditing => itemId != null;

  Future<void> load() async {
    if (itemId == null) return;
    setBusy(true);
    try {
      item = await _itemsApi.getById(itemId!);
      if (item == null) errorMessage = 'This item may have been removed.';
    } catch (error, stackTrace) {
      errorMessage =
          'This item could not be opened. Please go back and try again.';
      _diagnostics.recordError(
        DiagnosticEvent.itemReadFailed,
        error,
        stackTrace,
      );
    } finally {
      setBusy(false);
    }
  }

  Future<bool> save(String title, String description) async {
    errorMessage = null;
    setBusy(true);
    try {
      if (item == null) {
        await _itemsApi.create(title: title, description: description);
        _diagnostics.record(DiagnosticEvent.itemCreateSucceeded);
      } else {
        final result = await _itemsApi.update(
          item!.copyWith(title: title, description: description),
        );
        if (result == null) {
          errorMessage =
              'This item may have been removed. Go back to refresh the list.';
          _diagnostics.record(DiagnosticEvent.itemUpdateFailed);
          return false;
        }
        _diagnostics.record(DiagnosticEvent.itemUpdateSucceeded);
      }
      return true;
    } catch (error, stackTrace) {
      errorMessage = 'Your changes could not be saved. Please try again.';
      _diagnostics.recordError(
        item == null
            ? DiagnosticEvent.itemCreateFailed
            : DiagnosticEvent.itemUpdateFailed,
        error,
        stackTrace,
      );
      return false;
    } finally {
      setBusy(false);
    }
  }
}
