import 'item.dart';
import 'item_failure.dart';
import 'items_api.dart';

/// Per-instance, in-memory item storage for the local demo experience.
final class MockItemsApi implements ItemsApi {
  MockItemsApi({
    List<Item> initialItems = const [
      Item(
        id: 'sample-1',
        title: 'Sample item',
        description: 'An item stored in this mock service.',
      ),
    ],
  }) : _items = {for (final item in initialItems) item.id: item};

  final Map<String, Item> _items;
  int _nextId = 1;

  @override
  Future<List<Item>> getAll() async => List.unmodifiable(_items.values);

  @override
  Future<Item?> getById(String id) async => _items[id];

  @override
  Future<Item> create({
    required String title,
    required String description,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ItemFailure(ItemFailureReason.titleRequired);
    }
    var id = 'item-${_nextId++}';
    while (_items.containsKey(id)) {
      id = 'item-${_nextId++}';
    }
    final item = Item(
      id: id,
      title: cleanTitle,
      description: description.trim(),
    );
    _items[item.id] = item;
    return item;
  }

  @override
  Future<Item?> update(Item item) async {
    if (!_items.containsKey(item.id)) return null;
    final cleanTitle = item.title.trim();
    if (cleanTitle.isEmpty) {
      throw const ItemFailure(ItemFailureReason.titleRequired);
    }
    final updated = item.copyWith(
      title: cleanTitle,
      description: item.description.trim(),
    );
    _items[item.id] = updated;
    return updated;
  }

  @override
  Future<bool> delete(String id) async => _items.remove(id) != null;
}
