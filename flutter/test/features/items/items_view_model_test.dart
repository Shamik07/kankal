import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_kankal/core/auth/mock_auth_api.dart';
import 'package:flutter_kankal/core/diagnostics/diagnostics.dart';
import 'package:flutter_kankal/core/items/item.dart';
import 'package:flutter_kankal/core/items/items_api.dart';
import 'package:flutter_kankal/features/items/items_view_model.dart';

void main() {
  test('only the newest overlapping list load updates state', () async {
    final api = _ControlledItemsApi();
    final model = ItemsViewModel(MockAuthApi(), api, const NoopDiagnostics());
    const stale = Item(id: 'old', title: 'Old result', description: '');
    const current = Item(id: 'new', title: 'New result', description: '');

    final olderLoad = model.load();
    final newerLoad = model.load();
    api.requests[0].complete([stale]);
    await olderLoad;

    expect(model.isBusy, isTrue);
    expect(model.items, isEmpty);

    api.requests[1].complete([current]);
    await newerLoad;
    expect(model.items, [current]);
    expect(model.isBusy, isFalse);

    final thirdLoad = model.load();
    final latestLoad = model.load();
    api.requests[3].complete([current]);
    await latestLoad;
    api.requests[2].complete([stale]);
    await thirdLoad;

    expect(model.items, [current]);
    expect(model.isBusy, isFalse);
  });
}

class _ControlledItemsApi implements ItemsApi {
  final requests = <Completer<List<Item>>>[];

  @override
  Future<List<Item>> getAll() {
    final request = Completer<List<Item>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<Item?> getById(String id) => throw UnimplementedError();

  @override
  Future<Item> create({required String title, required String description}) =>
      throw UnimplementedError();

  @override
  Future<Item?> update(Item item) => throw UnimplementedError();

  @override
  Future<bool> delete(String id) => throw UnimplementedError();
}
