import 'package:flatch/common/services/library_order_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure-logic tests for the My Fart Library drag-to-reorder. The Firestore
/// read/write needs a live project; the arrangement rules do not, and they are
/// where this feature would silently go wrong.
String _id(String s) => s;

void main() {
  group('LibraryOrderService.apply', () {
    test('no saved order leaves the list untouched', () {
      final items = ['a', 'b', 'c'];
      expect(LibraryOrderService.apply(items, const [], _id), items);
    });

    test('arranges items into the saved order', () {
      final items = ['a', 'b', 'c'];
      expect(
        LibraryOrderService.apply(items, ['c', 'a', 'b'], _id),
        ['c', 'a', 'b'],
      );
    });

    test('ignores saved ids that are no longer in the library', () {
      // "deleted" was ordered once but the sound has since been removed.
      final items = ['a', 'b'];
      expect(
        LibraryOrderService.apply(items, ['deleted', 'b', 'a'], _id),
        ['b', 'a'],
      );
    });

    test('new arrivals go to the top, ordered items keep their arrangement', () {
      // "new" was uploaded after the last drag, so it is not in the order.
      final items = ['new', 'a', 'b'];
      expect(
        LibraryOrderService.apply(items, ['b', 'a'], _id),
        ['new', 'b', 'a'],
      );
    });

    test('multiple new arrivals keep their incoming relative order', () {
      final items = ['n1', 'n2', 'a'];
      expect(
        LibraryOrderService.apply(items, ['a'], _id),
        ['n1', 'n2', 'a'],
      );
    });
  });

  group('LibraryOrderService.merge', () {
    test('keeps ordered-but-unloaded ids instead of dropping them', () {
      // Only page 1 (a, b) is on screen; c/d are further down and must survive.
      final merged = LibraryOrderService.merge(
        ['b', 'a'],
        ['a', 'b', 'c', 'd'],
      );
      expect(merged, ['b', 'a', 'c', 'd']);
    });

    test('does not duplicate an id that appears in both lists', () {
      final merged = LibraryOrderService.merge(['x', 'y'], ['y', 'z']);
      expect(merged, ['x', 'y', 'z']);
      expect(merged.toSet().length, merged.length);
    });

    test('first save (nothing previously stored) is just the visible order', () {
      expect(LibraryOrderService.merge(['c', 'a'], const []), ['c', 'a']);
    });
  });

  group('reorder index math', () {
    // Mirrors _onReorder: ReorderableListView reports the target index BEFORE
    // the dragged row is removed, so a downward move is off by one.
    List<String> move(List<String> list, int oldIndex, int newIndex) {
      if (newIndex > oldIndex) newIndex -= 1;
      final out = [...list];
      out.insert(newIndex, out.removeAt(oldIndex));
      return out;
    }

    test('dragging downward lands where the user dropped it', () {
      expect(move(['a', 'b', 'c'], 0, 3), ['b', 'c', 'a']);
      expect(move(['a', 'b', 'c'], 0, 2), ['b', 'a', 'c']);
    });

    test('dragging upward lands where the user dropped it', () {
      expect(move(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    });

    test('dropping in place is a no-op', () {
      expect(move(['a', 'b', 'c'], 1, 2), ['a', 'b', 'c']);
    });
  });
}
