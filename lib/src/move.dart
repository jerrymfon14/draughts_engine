class DraughtsMove {
  final List<int> path;      // sequence of squares (1..50)
  final List<int> captured;  // captured squares

  DraughtsMove({
    required List<int> path,
    List<int>? captured,
  })  : path = List.unmodifiable(path),
        captured = List.unmodifiable(captured ?? []) {
    assert(path.length >= 2, 'Move must have at least from & to squares.');
  }

  int get from => path.first;
  int get to => path.last;
  bool get isCapture => captured.isNotEmpty;

  @override
  String toString() {
    final sep = isCapture ? 'x' : '-';
    return path.join(sep);
  }

  DraughtsMove copyWith({
    List<int>? path,
    List<int>? captured,
  }) {
    return DraughtsMove(
      path: path ?? this.path,
      captured: captured ?? this.captured,
    );
  }
}
