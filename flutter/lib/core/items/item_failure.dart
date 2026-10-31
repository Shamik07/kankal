enum ItemFailureReason { titleRequired }

final class ItemFailure implements Exception {
  const ItemFailure(this.reason);

  final ItemFailureReason reason;

  @override
  String toString() => 'ItemFailure: $reason';
}
