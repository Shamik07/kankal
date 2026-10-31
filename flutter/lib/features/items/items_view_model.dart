import 'package:stacked/stacked.dart';

import '../../core/auth/auth_api.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/items/item.dart';
import '../../core/items/items_api.dart';

class ItemsViewModel extends BaseViewModel {
  ItemsViewModel(this._authApi, this._itemsApi, this._diagnostics);

  final AuthApi _authApi;
  final ItemsApi _itemsApi;
  final Diagnostics _diagnostics;
  List<Item> items = const [];
  bool hasLoaded = false;
  String? errorMessage;
  int _latestLoadId = 0;

  Future<void> load() async {
    final loadId = ++_latestLoadId;
    errorMessage = null;
    setBusy(true);
    try {
      final loadedItems = await _itemsApi.getAll();
      if (loadId != _latestLoadId) return;
      items = loadedItems;
      hasLoaded = true;
      _diagnostics.record(DiagnosticEvent.itemReadSucceeded);
    } catch (error, stackTrace) {
      if (loadId != _latestLoadId) return;
      errorMessage =
          'Your items could not be loaded. Check your connection and try again.';
      _diagnostics.recordError(
        DiagnosticEvent.itemReadFailed,
        error,
        stackTrace,
      );
    } finally {
      if (loadId == _latestLoadId) setBusy(false);
    }
  }

  Future<void> signOut() async {
    errorMessage = null;
    setBusy(true);
    try {
      await _authApi.signOut();
      _diagnostics.record(DiagnosticEvent.authSignOutSucceeded);
    } catch (error, stackTrace) {
      errorMessage = 'You could not be signed out. Please try again.';
      _diagnostics.recordError(
        DiagnosticEvent.authSignOutFailed,
        error,
        stackTrace,
      );
    } finally {
      setBusy(false);
    }
  }
}
