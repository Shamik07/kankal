import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_kankal/core/items/item.dart';
import 'package:flutter_kankal/core/items/item_failure.dart';
import 'package:flutter_kankal/core/items/mock_items_api.dart';

void main() {
  group('MockItemsApi', () {
    test('creates, reads, updates, and deletes an item', () async {
      final api = MockItemsApi(initialItems: []);
      final created = await api.create(
        title: '  First  ',
        description: ' note ',
      );

      expect(created.title, 'First');
      expect(created.description, 'note');
      expect(await api.getById(created.id), created);
      expect(await api.getAll(), [created]);

      final updated = await api.update(
        created.copyWith(title: 'Renamed', description: 'updated note'),
      );
      expect(updated?.title, 'Renamed');
      expect(await api.delete(created.id), isTrue);
      expect(await api.getById(created.id), isNull);
      expect(await api.delete(created.id), isFalse);
    });

    test('rejects blank titles without changing stored items', () async {
      final original = const Item(id: 'seed', title: 'Kept', description: '');
      final api = MockItemsApi(initialItems: [original]);

      await expectLater(
        api.create(title: '  ', description: ''),
        throwsA(isA<ItemFailure>()),
      );
      expect(await api.getAll(), [original]);
    });

    test('each API instance owns its in-memory items', () async {
      final first = MockItemsApi();
      final second = MockItemsApi();
      final created = await first.create(title: 'Private', description: '');

      expect(await second.getById(created.id), isNull);
    });
  });
}
