class TextChangeHistory {
  TextChangeHistory({String initialValue = ''}) : _current = initialValue;

  final List<String> _undoStack = <String>[];
  final List<String> _redoStack = <String>[];
  String _current;

  String get current => _current;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void reset(String value) {
    _undoStack.clear();
    _redoStack.clear();
    _current = value;
  }

  void commit(String nextValue) {
    if (nextValue == _current) {
      return;
    }
    _undoStack.add(_current);
    _current = nextValue;
    _redoStack.clear();
  }

  String undo() {
    if (!canUndo) {
      return _current;
    }
    _redoStack.add(_current);
    _current = _undoStack.removeLast();
    return _current;
  }

  String redo() {
    if (!canRedo) {
      return _current;
    }
    _undoStack.add(_current);
    _current = _redoStack.removeLast();
    return _current;
  }
}
