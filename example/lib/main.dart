import 'package:draughts_engine/draughts_engine.dart';

void main() {
  // Standard start position (W:W31-50:B1-20)
  final game = DraughtsGame();

  print('Turn: ${game.turn}');
  print('FEN: ${game.fen}');
  print('Result: ${game.result}');

  final moves = game.legalMoves();
  print('Legal moves: ${moves.length}');
  for (final m in moves.take(10)) {
    print('  $m');
  }

  if (moves.isNotEmpty) {
    final m = moves.first;
    print('Playing: $m');
    game.makeMove(m);
    print('Turn: ${game.turn}');
    print('FEN: ${game.fen}');
    print('Result: ${game.result}');
  }
}
