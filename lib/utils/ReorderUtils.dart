/// Moving one item within a list, for drag-to-reorder.
///
/// Five screens each held their own copy of this, all written against
/// [ReorderableListView]'s old `onReorder` callback and so all carrying the
/// `if (newIndex > oldIndex) newIndex--` correction that callback required. Its replacement,
/// `onReorderItem`, hands over an index that already accounts for the dragged item being lifted
/// out, so that correction now overshoots by one. Keeping the move in one place means the
/// convention is stated once and can be tested.
class ReorderUtils {
  ReorderUtils._();

  /// Moves the item at [from] to [to], in place.
  ///
  /// [to] is the destination index in the list **with the item already removed**, which is what
  /// `onReorderItem` provides. Out-of-range indices are ignored rather than throwing: a drag
  /// that lands during a rebuild should not take the screen down.
  static void moveInPlace<T>(List<T> list, int from, int to) {
    if (from < 0 || from >= list.length) return;
    final item = list.removeAt(from);
    list.insert(to.clamp(0, list.length), item);
  }
}
