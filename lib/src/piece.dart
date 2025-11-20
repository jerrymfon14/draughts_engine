import 'enums.dart';

class Piece {
  final PieceColor color;
  final PieceType type;

  const Piece({
    required this.color,
    this.type = PieceType.man,
  });

  Piece promote() => Piece(color: color, type: PieceType.king);

  @override
  String toString() {
    final c = color == PieceColor.white ? 'W' : 'B';
    final t = type == PieceType.king ? 'K' : 'M';
    return '$c$t';
  }
}
