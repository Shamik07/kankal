final class Item {
  const Item({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;

  Item copyWith({String? title, String? description}) => Item(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
  );

  @override
  bool operator ==(Object other) =>
      other is Item &&
      other.id == id &&
      other.title == title &&
      other.description == description;

  @override
  int get hashCode => Object.hash(id, title, description);
}
