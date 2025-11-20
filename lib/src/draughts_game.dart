import 'package:meta/meta.dart';

import '../draughts_engine.dart';

class DraughtsGame {
  static const int boardSize = 50;

  PieceColor _turn = PieceColor.white;
  final Map<int, Piece> _board = {}; // square -> piece
  GameResult _result = GameResult.ongoing();

  // For repetition & 25-move rule
  final List<String> _historyFen = [];
  final Map<String, int> _positionCounts = {};
  int _halfMovesSinceCaptureOrPromotion = 0;

  PieceColor get turn => _turn;
  GameResult get result => _result;
  Map<int, Piece> get board => Map.unmodifiable(_board);

  DraughtsGame({String? fen}) {
    if (fen != null) {
      loadFen(fen);
    } else {
      setInitialPosition();
    }
  }

  /// Default FMJD starting position
  void setInitialPosition() {
    _board.clear();
    for (var sq = 1; sq <= 20; sq++) {
      _board[sq] = const Piece(color: PieceColor.black);
    }
    for (var sq = 31; sq <= 50; sq++) {
      _board[sq] = const Piece(color: PieceColor.white);
    }
    _turn = PieceColor.white;
    _result = GameResult.ongoing();
    _halfMovesSinceCaptureOrPromotion = 0;
    _historyFen.clear();
    _positionCounts.clear();
    _recordPosition();
  }

  /// FEN I/O
  void loadFen(String fen) {
    final (turn, pieces) = DraughtsFen.load(fen);
    _board
      ..clear()
      ..addAll(pieces);
    _turn = turn;
    _result = GameResult.ongoing();
    _halfMovesSinceCaptureOrPromotion = 0;
    _historyFen.clear();
    _positionCounts.clear();
    _recordPosition();
  }

  String get fen => DraughtsFen.write(_turn, _board);

  Piece? getPiece(int square) => _board[square];

  bool putPiece(Piece piece, int square) {
    if (square < 1 || square > boardSize) return false;
    _board[square] = piece;
    _recordPosition();
    return true;
  }

  Piece? removePiece(int square) {
    final removed = _board.remove(square);
    _recordPosition();
    return removed;
  }

  /// All legal moves for current player (taking tournament rules into account)
  List<DraughtsMove> legalMoves({int? fromSquare}) {
    if (!_result.isOngoing) return const [];

    final allCaptures = <DraughtsMove>[];
    final allSimple = <DraughtsMove>[];

    final squares = fromSquare != null
        ? [fromSquare]
        : _board.keys.where((sq) => _board[sq]!.color == _turn);

    for (final sq in squares) {
      final piece = _board[sq];
      if (piece == null || piece.color != _turn) continue;

      _generateCaptureSequences(sq, piece, allCaptures);

      if (allCaptures.isEmpty) {
        _generateSimpleMoves(sq, piece, allSimple);
      }
    }

    if (allCaptures.isNotEmpty) {
      final maxCapt = allCaptures.fold<int>(
          0, (max, m) => m.captured.length > max ? m.captured.length : max);
      return allCaptures
          .where((m) => m.captured.length == maxCapt)
          .toList(growable: false);
    }

    return allSimple;
  }

  /// Apply a move if it’s legal (tournament-valid). Returns true if success.
  bool makeMove(DraughtsMove move) {
    if (!_result.isOngoing) return false;

    final legal = legalMoves(fromSquare: move.from);
    if (legal.isEmpty) return false;

    final matched = legal.firstWhere(
          (m) => _samePath(m.path, move.path),
      orElse: () => null as DraughtsMove,
    );

    if (matched == null) return false;

    final beforeFen = fen;

    final piece = _board[matched.from];
    if (piece == null) return false;

    bool isCapture = matched.isCapture;
    bool promoted = false;

    // remove from origin
    _board.remove(matched.from);

    // remove captured after full path
    for (final c in matched.captured) {
      _board.remove(c);
    }

    // final piece (with possible promotion)
    Piece finalPiece = piece;
    final lastSquare = matched.to;
    final row = BoardCoords.indexToRow(lastSquare);

    if (piece.type == PieceType.man) {
      final isWhitePromo = piece.color == PieceColor.white && row == 0;
      final isBlackPromo = piece.color == PieceColor.black && row == 9;
      if (isWhitePromo || isBlackPromo) {
        finalPiece = piece.promote();
        promoted = true;
      }
    }

    _board[lastSquare] = finalPiece;

    // draw counters
    if (isCapture || promoted) {
      _halfMovesSinceCaptureOrPromotion = 0;
    } else {
      _halfMovesSinceCaptureOrPromotion++;
    }

    _switchTurn();
    _recordPosition();
    _updateGameResult(beforeFen);

    return true;
  }

  /// Undo last move (if any)
  bool undo() {
    if (_historyFen.length <= 1) return false;
    // remove current
    _historyFen.removeLast();
    // load previous
    final prevFen = _historyFen.last;
    loadFen(prevFen);
    // adjust position counts conservatively: recompute them
    _positionCounts
      ..clear()
      ..addAll(_rebuildPositionCounts());
    return true;
  }

  // ---------- INTERNAL MOVE GENERATION (TOURNAMENT RULES) ---------- //

  void _generateSimpleMoves(int sq, Piece piece, List<DraughtsMove> out) {
    if (piece.type == PieceType.man) {
      final row = BoardCoords.indexToRow(sq);
      final col = BoardCoords.indexToCol(sq);
      final dir = piece.color == PieceColor.white ? -1 : 1;

      for (final dc in [-1, 1]) {
        final nr = row + dir;
        final nc = col + dc;
        final nsq = BoardCoords.rowColToIndex(nr, nc);
        if (nsq != null && _board[nsq] == null) {
          out.add(DraughtsMove(path: [sq, nsq]));
        }
      }
    } else {
      // king: slide any distance diagonally
      final row = BoardCoords.indexToRow(sq);
      final col = BoardCoords.indexToCol(sq);

      const dirs = [
        (-1, -1),
        (-1, 1),
        (1, -1),
        (1, 1),
      ];

      for (final (dr, dc) in dirs) {
        var nr = row + dr;
        var nc = col + dc;
        while (true) {
          final nsq = BoardCoords.rowColToIndex(nr, nc);
          if (nsq == null) break;
          if (_board[nsq] != null) break;
          out.add(DraughtsMove(path: [sq, nsq]));
          nr += dr;
          nc += dc;
        }
      }
    }
  }

  void _generateCaptureSequences(
      int sq, Piece piece, List<DraughtsMove> out) {
    _dfsCapture(
      from: sq,
      piece: piece,
      path: [sq],
      captured: const [],
      capturedSet: <int>{},
      out: out,
    );
  }

  /// DFS capture with mid-move promotion & king continuation.
  void _dfsCapture({
    required int from,
    required Piece piece,
    required List<int> path,
    required List<int> captured,
    required Set<int> capturedSet,
    required List<DraughtsMove> out,
  }) {
    final row = BoardCoords.indexToRow(from);
    final col = BoardCoords.indexToCol(from);

    bool foundChild = false;

    const dirs = [
      (-1, -1),
      (-1, 1),
      (1, -1),
      (1, 1),
    ];

    if (piece.type == PieceType.man) {
      // Men capture 1 enemy over adjacent, land one beyond (but in all directions)
      for (final (dr, dc) in dirs) {
        final mr = row + dr;
        final mc = col + dc;
        final landingR = row + 2 * dr;
        final landingC = col + 2 * dc;

        final midSq = BoardCoords.rowColToIndex(mr, mc);
        final landingSq = BoardCoords.rowColToIndex(landingR, landingC);
        if (midSq == null || landingSq == null) continue;

        final midPiece = _board[midSq];

        if (midPiece == null ||
            midPiece.color == piece.color ||
            capturedSet.contains(midSq)) {
          continue;
        }
        if (_board[landingSq] != null) continue;

        // candidate capture
        foundChild = true;

        final newPath = List<int>.from(path)..add(landingSq);
        final newCaptured = List<int>.from(captured)..add(midSq);
        final newCapturedSet = Set<int>.from(capturedSet)..add(midSq);

        // mid-move promotion?
        Piece nextPiece = piece;
        final landingRow = BoardCoords.indexToRow(landingSq);
        final isWhitePromo =
            piece.color == PieceColor.white && landingRow == 0;
        final isBlackPromo =
            piece.color == PieceColor.black && landingRow == 9;
        if (isWhitePromo || isBlackPromo) {
          nextPiece = piece.promote();
        }

        _dfsCapture(
          from: landingSq,
          piece: nextPiece,
          path: newPath,
          captured: newCaptured,
          capturedSet: newCapturedSet,
          out: out,
        );
      }
    } else {
      // King: flying capture — can traverse any number of empty squares before enemy
      for (final (dr, dc) in dirs) {
        var nr = row + dr;
        var nc = col + dc;
        int? enemySq;
        int? enemyRow;
        int? enemyCol;

        // fly until first enemy or blocked
        while (true) {
          final sqMid = BoardCoords.rowColToIndex(nr, nc);
          if (sqMid == null) break;

          final midPiece = _board[sqMid];

          if (midPiece == null) {
            nr += dr;
            nc += dc;
            continue;
          }

          if (midPiece.color == piece.color ||
              capturedSet.contains(sqMid)) {
            enemySq = null;
            break;
          }

          // first enemy piece in that direction
          enemySq = sqMid;
          enemyRow = nr;
          enemyCol = nc;
          nr += dr;
          nc += dc;
          break;
        }

        if (enemySq == null) continue;

        // from enemy+1 step, any empty square is landing
        while (true) {
          final landingSq = BoardCoords.rowColToIndex(nr, nc);
          if (landingSq == null) break;
          if (_board[landingSq] != null) break;

          foundChild = true;

          final newPath = List<int>.from(path)..add(landingSq);
          final newCaptured = List<int>.from(captured)..add(enemySq);
          final newCapturedSet = Set<int>.from(capturedSet)..add(enemySq);

          _dfsCapture(
            from: landingSq,
            piece: piece, // already king
            path: newPath,
            captured: newCaptured,
            capturedSet: newCapturedSet,
            out: out,
          );

          nr += dr;
          nc += dc;
        }
      }
    }

    if (!foundChild && captured.isNotEmpty) {
      out.add(DraughtsMove(path: path, captured: captured));
    }
  }

  // ---------- GAME STATE / DRAW LOGIC ---------- //

  void _switchTurn() {
    _turn = _turn == PieceColor.white ? PieceColor.black : PieceColor.white;
  }

  void _recordPosition() {
    final f = fen; // includes turn
    _historyFen.add(f);
    _positionCounts[f] = (_positionCounts[f] ?? 0) + 1;
  }

  Map<String, int> _rebuildPositionCounts() {
    final map = <String, int>{};
    for (final f in _historyFen) {
      map[f] = (map[f] ?? 0) + 1;
    }
    return map;
  }

  void _updateGameResult(String beforeFen) {
    // already decided?
    if (!_result.isOngoing) return;

    // Check 3-fold repetition
    final currentFen = fen;
    final occurrences = _positionCounts[currentFen] ?? 1;
    if (occurrences >= 3) {
      _result = GameResult.draw('Threefold repetition');
      return;
    }

    // 25-move rule (approx): 25 moves = 50 half-moves
    if (_halfMovesSinceCaptureOrPromotion >= 50) {
      _result = GameResult.draw('No capture or promotion in 25 moves');
      return;
    }

    // No pieces or no legal moves: win for opponent
    final hasPieces = _board.values.any((p) => p.color == _turn);
    if (!hasPieces) {
      _result = GameResult.win(
          _opponent(_turn), 'No pieces remaining for ${_turn.name}');
      return;
    }

    final moves = legalMoves();
    if (moves.isEmpty) {
      _result = GameResult.win(
          _opponent(_turn), 'No legal moves for ${_turn.name}');
      return;
    }

    // Basic insufficient material: if only kings and total <= 3 => draw
    if (_isBasicInsufficientMaterial()) {
      _result = GameResult.draw('Insufficient material');
      return;
    }

    _result = GameResult.ongoing();
  }

  bool _isBasicInsufficientMaterial() {
    // very simple heuristic:
    final pieces = _board.values.toList();
    if (pieces.isEmpty) return true;
    final allKings = pieces.every((p) => p.type == PieceType.king);
    if (!allKings) return false;
    if (pieces.length <= 3) return true; // K vs K, K vs KK etc.
    return false;
  }

  PieceColor _opponent(PieceColor c) =>
      c == PieceColor.white ? PieceColor.black : PieceColor.white;

  bool _samePath(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
