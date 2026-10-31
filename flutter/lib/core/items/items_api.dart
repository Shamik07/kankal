import 'item.dart';

abstract interface class ItemsApi {
  Future<List<Item>> getAll();

  Future<Item?> getById(String id);

  Future<Item> create({required String title, required String description});

  Future<Item?> update(Item item);

  Future<bool> delete(String id);
}
