import 'enums.dart';

class GameResult {
  final GameResultType type;
  final PieceColor? winner;
  final String? reason;

  const GameResult._(this.type, this.winner, this.reason);

  factory GameResult.ongoing() =>
      const GameResult._(GameResultType.ongoing, null, null);

  factory GameResult.win(PieceColor winner, String reason) =>
      GameResult._(GameResultType.win, winner, reason);

  factory GameResult.draw(String reason) =>
      GameResult._(GameResultType.draw, null, reason);

  bool get isOngoing => type == GameResultType.ongoing;

  @override
  String toString() {
    return switch (type) {
      GameResultType.ongoing => 'Ongoing',
      GameResultType.win => 'Win for $winner ($reason)',
      GameResultType.draw => 'Draw ($reason)',
    };
  }
}
