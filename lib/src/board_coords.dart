class BoardCoords {
  /// 1..50 -> 0..9 row
  static int indexToRow(int index) => (index - 1) ~/ 5;

  /// 1..50 -> 0..9 col (only dark squares)
  static int indexToCol(int index) {
    final row = indexToRow(index);
    final posInRow = (index - 1) % 5; // 0..4
    return row.isEven ? 1 + posInRow * 2 : posInRow * 2;
  }

  /// row,col -> index (1..50) or null if off-board / light square
  static int? rowColToIndex(int row, int col) {
    if (row < 0 || row > 9 || col < 0 || col > 9) return null;
    if ((row + col).isEven) return null; // light square
    final posInRow = row.isEven ? (col - 1) ~/ 2 : col ~/ 2;
    if (posInRow < 0 || posInRow > 4) return null;
    return row * 5 + posInRow + 1;
  }
}
