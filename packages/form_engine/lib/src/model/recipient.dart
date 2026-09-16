/// A role a field can be assigned to.
///
/// Single-device filling ignores these entirely. They exist in the schema from the start so
/// that sending a form to other people later is an additive change rather than a migration of
/// every stored document.
class Recipient {
  final String id;
  final String name;

  /// Order in a signing sequence, if one is used. Null means order does not matter.
  final int? order;

  const Recipient({required this.id, this.name = '', this.order});

  Map<String, Object?> toJson() =>
      {'id': id, if (name.isNotEmpty) 'name': name, if (order != null) 'order': order};

  static Recipient fromJson(Map<String, Object?> json) => Recipient(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        order: (json['order'] as num?)?.toInt(),
      );
}
