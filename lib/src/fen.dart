import 'enums.dart';
import 'piece.dart';

/// FEN compatible with draughts.js:
/// Examples:
///   W:W31-50:B1-20
///   B:W31,32,33:BK1,2
///   W:WK32,33:B1,2,3
class DraughtsFen {
  static const int boardSize = 50;

  /// Parse FEN => (turn, Map`<square,Piece>`)
  static (PieceColor turn, Map<int, Piece> pieces) load(String fen) {
    fen = fen.trim();
    if (!fen.contains(':')) {
      throw ArgumentError('Invalid FEN: missing ":"');
    }

    final parts = fen.split(':');
    final turnPart = parts[0].toUpperCase();
    final boardPart = parts.sublist(1).join(':');

    final turn = switch (turnPart) {
      'W' => PieceColor.white,
      'B' => PieceColor.black,
      _ => throw ArgumentError('Invalid turn: $turnPart'),
    };

    final Map<int, Piece> pieces = {};

    final groups = boardPart.split(':');
    for (var group in groups) {
      group = group.trim();
      if (group.isEmpty) continue;

      PieceColor color;
      PieceType type;

      if (group.startsWith('W')) {
        color = PieceColor.white;
      } else if (group.startsWith('B')) {
        color = PieceColor.black;
      } else {
        throw ArgumentError('Invalid color in group: $group');
      }

      var idx = 1;

      if (idx < group.length && group[idx] == 'K') {
        type = PieceType.king;
        idx++;
      } else {
        type = PieceType.man;
      }

      final posStr = group.substring(idx);
      final segments = posStr.split(',');

      for (var seg in segments) {
        seg = seg.trim();
        if (seg.isEmpty) continue;

        if (seg.contains('-')) {
          final range = seg.split('-');
          final a = int.parse(range[0]);
          final b = int.parse(range[1]);
          for (var sq = a; sq <= b; sq++) {
            pieces[sq] = Piece(color: color, type: type);
          }
        } else {
          final sq = int.parse(seg);
          pieces[sq] = Piece(color: color, type: type);
        }
      }
    }

    return (turn, pieces);
  }

  /// Generate FEN from (turn, pieces)
  static String write(PieceColor turn, Map<int, Piece> pieces) {
    final whiteMen = <int>[];
    final whiteKings = <int>[];
    final blackMen = <int>[];
    final blackKings = <int>[];

    pieces.forEach((sq, piece) {
      if (piece.color == PieceColor.white) {
        if (piece.type == PieceType.man) {
          whiteMen.add(sq);
        } else {
          whiteKings.add(sq);
        }
      } else {
        if (piece.type == PieceType.man) {
          blackMen.add(sq);
        } else {
          blackKings.add(sq);
        }
      }
    });

    whiteMen.sort();
    whiteKings.sort();
    blackMen.sort();
    blackKings.sort();

    String buildSection(String colorLetter, List<int> men, List<int> kings) {
      final parts = <String>[];
      if (men.isNotEmpty) {
        parts.add('$colorLetter${_formatList(men)}');
      }
      if (kings.isNotEmpty) {
        parts.add('${colorLetter}K${_formatList(kings)}');
      }
      return parts.join(':');
    }

    final wPart = buildSection('W', whiteMen, whiteKings);
    final bPart = buildSection('B', blackMen, blackKings);
    final turnStr = turn == PieceColor.white ? 'W' : 'B';

    if (wPart.isEmpty && bPart.isEmpty) return '$turnStr:';
    if (wPart.isEmpty) return '$turnStr:$bPart';
    if (bPart.isEmpty) return '$turnStr:$wPart';
    return '$turnStr:$wPart:$bPart';
  }

  /// Compress sorted list -> ranges "31-33,40-43"
  static String _formatList(List<int> list) {
    if (list.length == 1) return list.first.toString();
    final result = <String>[];

    var start = list.first;
    var prev = list.first;

    for (var i = 1; i < list.length; i++) {
      final current = list[i];
      if (current == prev + 1) {
        prev = current;
      } else {
        if (start == prev) {
          result.add('$start');
        } else {
          result.add('$start-$prev');
        }
        start = current;
        prev = current;
      }
    }

    if (start == prev) {
      result.add('$start');
    } else {
      result.add('$start-$prev');
    }

    return result.join(',');
  }
}
