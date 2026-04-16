import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_book_writer/core/services/change_history.dart';

void main() {
  group('TextChangeHistory', () {
    test('commit, undo and redo works', () {
      final history = TextChangeHistory(initialValue: 'A');

      history.commit('AB');
      history.commit('ABC');

      expect(history.current, 'ABC');
      expect(history.canUndo, isTrue);
      expect(history.undo(), 'AB');
      expect(history.undo(), 'A');
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);
      expect(history.redo(), 'AB');
    });

    test('commit with same value does not create history item', () {
      final history = TextChangeHistory(initialValue: 'Draft');
      history.commit('Draft');

      expect(history.canUndo, isFalse);
      expect(history.current, 'Draft');
    });
  });
}
