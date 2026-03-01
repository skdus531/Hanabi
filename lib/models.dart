import 'package:flutter/material.dart';

enum AppMode { local, online }

enum AppScreen { home, lobby, game, gameOver }

enum ColorSuit { red, yellow, green, blue, white }

enum ClueType { color, number }

enum CardAction { play, discard }

class PlayerSetup {
  PlayerSetup({required this.id, required this.name, this.ready = false});

  final String id;
  final String name;
  final bool ready;

  PlayerSetup copy({String? id, String? name, bool? ready}) {
    return PlayerSetup(
      id: id ?? this.id,
      name: name ?? this.name,
      ready: ready ?? this.ready,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ready': ready,
    };
  }

  factory PlayerSetup.fromJson(Map<String, dynamic> json) {
    return PlayerSetup(
      id: json['id'] as String,
      name: json['name'] as String,
      ready: json['ready'] as bool? ?? false,
    );
  }
}

class Card {
  Card({required this.color, required this.number});

  final ColorSuit color;
  final int number;

  Map<String, dynamic> toJson() {
    return {
      'color': color.name,
      'number': number,
    };
  }

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      color: parseColorSuit(json['color'] as String),
      number: json['number'] as int,
    );
  }
}

class CardKnowledge {
  CardKnowledge({
    required this.knownColor,
    required this.knownNumber,
    required this.possibleColors,
    required this.possibleNumbers,
  });

  final ColorSuit? knownColor;
  final int? knownNumber;
  final Set<ColorSuit> possibleColors;
  final Set<int> possibleNumbers;

  factory CardKnowledge.fresh() {
    return CardKnowledge(
      knownColor: null,
      knownNumber: null,
      possibleColors: Set.of(ColorSuit.values),
      possibleNumbers: {1, 2, 3, 4, 5},
    );
  }

  CardKnowledge applyColorClue(ColorSuit color, bool matches) {
    final colors = Set<ColorSuit>.from(possibleColors);
    if (matches) {
      colors
        ..clear()
        ..add(color);
    } else {
      colors.remove(color);
    }
    return _normalize(colors, possibleNumbers);
  }

  CardKnowledge applyNumberClue(int number, bool matches) {
    final numbers = Set<int>.from(possibleNumbers);
    if (matches) {
      numbers
        ..clear()
        ..add(number);
    } else {
      numbers.remove(number);
    }
    return _normalize(possibleColors, numbers);
  }

  String get badge {
    final colorBadge = knownColor == null ? '?' : colorShort(knownColor!);
    final numberBadge = knownNumber?.toString() ?? '?';
    return '$colorBadge$numberBadge';
  }

  Map<String, dynamic> toJson() {
    return {
      'known_color': knownColor?.name,
      'known_number': knownNumber,
      'possible_colors': possibleColors.map((c) => c.name).toList(),
      'possible_numbers': possibleNumbers.toList(),
    };
  }

  factory CardKnowledge.fromJson(Map<String, dynamic> json) {
    return CardKnowledge(
      knownColor: json['known_color'] == null
          ? null
          : parseColorSuit(json['known_color'] as String),
      knownNumber: json['known_number'] as int?,
      possibleColors: (json['possible_colors'] as List<dynamic>)
          .map((value) => parseColorSuit(value as String))
          .toSet(),
      possibleNumbers: (json['possible_numbers'] as List<dynamic>)
          .map((value) => value as int)
          .toSet(),
    );
  }

  CardKnowledge _normalize(Set<ColorSuit> colors, Set<int> numbers) {
    final normalizedColor = colors.length == 1 ? colors.first : null;
    final normalizedNumber = numbers.length == 1 ? numbers.first : null;
    return CardKnowledge(
      knownColor: normalizedColor,
      knownNumber: normalizedNumber,
      possibleColors: colors,
      possibleNumbers: numbers,
    );
  }
}

class PlayerState {
  PlayerState({
    required this.id,
    required this.name,
    required this.hand,
    required this.knowledge,
  });

  final String id;
  final String name;
  final List<Card> hand;
  final List<CardKnowledge> knowledge;

  PlayerState copy({
    String? id,
    String? name,
    List<Card>? hand,
    List<CardKnowledge>? knowledge,
  }) {
    return PlayerState(
      id: id ?? this.id,
      name: name ?? this.name,
      hand: hand ?? List.of(this.hand),
      knowledge: knowledge ?? List.of(this.knowledge),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hand': hand.map((card) => card.toJson()).toList(),
      'knowledge': knowledge.map((info) => info.toJson()).toList(),
    };
  }

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    return PlayerState(
      id: json['id'] as String,
      name: json['name'] as String,
      hand: (json['hand'] as List<dynamic>)
          .map((card) => Card.fromJson(card as Map<String, dynamic>))
          .toList(),
      knowledge: (json['knowledge'] as List<dynamic>)
          .map((info) => CardKnowledge.fromJson(info as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GameResult {
  GameResult({
    required this.win,
    required this.score,
    required this.reason,
    required this.pileHeights,
    required this.actionLog,
  });

  final bool win;
  final int score;
  final String reason;
  final Map<ColorSuit, int> pileHeights;
  final List<String> actionLog;

  Map<String, dynamic> toJson() {
    return {
      'win': win,
      'score': score,
      'reason': reason,
      'pile_heights': pileHeights.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'action_log': actionLog,
    };
  }

  factory GameResult.fromJson(Map<String, dynamic> json) {
    final pileHeightsRaw = json['pile_heights'] as Map<String, dynamic>;
    return GameResult(
      win: json['win'] as bool,
      score: json['score'] as int,
      reason: json['reason'] as String,
      pileHeights: pileHeightsRaw.map(
        (key, value) => MapEntry(parseColorSuit(key), value as int),
      ),
      actionLog: (json['action_log'] as List<dynamic>)
          .map((entry) => entry as String)
          .toList(),
    );
  }
}

class GameState {
  GameState({
    required this.clueTokens,
    required this.fuseTokens,
    required this.deck,
    required this.discard,
    required this.piles,
    required this.players,
    required this.currentPlayerIndex,
    required this.finalRound,
    required this.finalTurnsRemaining,
    required this.actionLog,
    required this.result,
  });

  final int clueTokens;
  final int fuseTokens;
  final List<Card> deck;
  final List<Card> discard;
  final Map<ColorSuit, List<Card>> piles;
  final List<PlayerState> players;
  final int currentPlayerIndex;
  final bool finalRound;
  final int finalTurnsRemaining;
  final List<String> actionLog;
  final GameResult? result;

  GameState copyWith({
    int? clueTokens,
    int? fuseTokens,
    List<Card>? deck,
    List<Card>? discard,
    Map<ColorSuit, List<Card>>? piles,
    List<PlayerState>? players,
    int? currentPlayerIndex,
    bool? finalRound,
    int? finalTurnsRemaining,
    List<String>? actionLog,
    GameResult? result,
  }) {
    return GameState(
      clueTokens: clueTokens ?? this.clueTokens,
      fuseTokens: fuseTokens ?? this.fuseTokens,
      deck: deck ?? List.of(this.deck),
      discard: discard ?? List.of(this.discard),
      piles: piles ?? _clonePiles(this.piles),
      players: players ?? List.of(this.players),
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      finalRound: finalRound ?? this.finalRound,
      finalTurnsRemaining: finalTurnsRemaining ?? this.finalTurnsRemaining,
      actionLog: actionLog ?? List.of(this.actionLog),
      result: result ?? this.result,
    );
  }

  int currentScore() {
    var score = 0;
    for (final color in ColorSuit.values) {
      final pile = piles[color] ?? [];
      if (pile.isNotEmpty) {
        score += pile.last.number;
      }
    }
    return score;
  }

  bool allPilesCompleted() {
    return piles.values.every((pile) => pile.length >= 5);
  }

  Map<String, dynamic> toJson() {
    return {
      'clue_tokens': clueTokens,
      'fuse_tokens': fuseTokens,
      'deck': deck.map((card) => card.toJson()).toList(),
      'discard': discard.map((card) => card.toJson()).toList(),
      'piles': piles.map(
        (key, value) =>
            MapEntry(key.name, value.map((card) => card.toJson()).toList()),
      ),
      'players': players.map((player) => player.toJson()).toList(),
      'current_player_index': currentPlayerIndex,
      'final_round': finalRound,
      'final_turns_remaining': finalTurnsRemaining,
      'action_log': actionLog,
      'result': result?.toJson(),
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    final pilesRaw = json['piles'] as Map<String, dynamic>;
    return GameState(
      clueTokens: json['clue_tokens'] as int,
      fuseTokens: json['fuse_tokens'] as int,
      deck: (json['deck'] as List<dynamic>)
          .map((card) => Card.fromJson(card as Map<String, dynamic>))
          .toList(),
      discard: (json['discard'] as List<dynamic>)
          .map((card) => Card.fromJson(card as Map<String, dynamic>))
          .toList(),
      piles: pilesRaw.map(
        (key, value) => MapEntry(
          parseColorSuit(key),
          (value as List<dynamic>)
              .map((card) => Card.fromJson(card as Map<String, dynamic>))
              .toList(),
        ),
      ),
      players: (json['players'] as List<dynamic>)
          .map((player) => PlayerState.fromJson(player as Map<String, dynamic>))
          .toList(),
      currentPlayerIndex: json['current_player_index'] as int,
      finalRound: json['final_round'] as bool,
      finalTurnsRemaining: json['final_turns_remaining'] as int,
      actionLog: (json['action_log'] as List<dynamic>)
          .map((entry) => entry as String)
          .toList(),
      result: json['result'] == null
          ? null
          : GameResult.fromJson(json['result'] as Map<String, dynamic>),
    );
  }
}

class RoomData {
  RoomData({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    required this.maxPlayers,
    required this.players,
    required this.gameState,
    required this.version,
  });

  final String id;
  final String code;
  final String hostId;
  final String status;
  final int maxPlayers;
  final List<PlayerSetup> players;
  final GameState? gameState;
  final int version;

  RoomData copyWith({
    String? id,
    String? code,
    String? hostId,
    String? status,
    int? maxPlayers,
    List<PlayerSetup>? players,
    GameState? gameState,
    int? version,
  }) {
    return RoomData(
      id: id ?? this.id,
      code: code ?? this.code,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      players: players ?? List.of(this.players),
      gameState: gameState ?? this.gameState,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'host_id': hostId,
      'status': status,
      'max_players': maxPlayers,
      'players': players.map((player) => player.toJson()).toList(),
      'game_state': gameState?.toJson(),
      'version': version,
    };
  }

  factory RoomData.fromJson(Map<String, dynamic> json) {
    return RoomData(
      id: json['id'] as String,
      code: json['code'] as String,
      hostId: json['host_id'] as String,
      status: json['status'] as String,
      maxPlayers: json['max_players'] as int? ?? 4,
      players: (json['players'] as List<dynamic>)
          .map((player) => PlayerSetup.fromJson(player as Map<String, dynamic>))
          .toList(),
      gameState: json['game_state'] == null
          ? null
          : GameState.fromJson(json['game_state'] as Map<String, dynamic>),
      version: json['version'] as int? ?? 0,
    );
  }
}

ColorSuit parseColorSuit(String raw) {
  return ColorSuit.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => ColorSuit.red,
  );
}

String colorName(ColorSuit suit) {
  switch (suit) {
    case ColorSuit.red:
      return 'Red';
    case ColorSuit.yellow:
      return 'Yellow';
    case ColorSuit.green:
      return 'Green';
    case ColorSuit.blue:
      return 'Blue';
    case ColorSuit.white:
      return 'White';
  }
}

String colorShort(ColorSuit suit) {
  switch (suit) {
    case ColorSuit.red:
      return 'R';
    case ColorSuit.yellow:
      return 'Y';
    case ColorSuit.green:
      return 'G';
    case ColorSuit.blue:
      return 'B';
    case ColorSuit.white:
      return 'W';
  }
}

Color suitColor(ColorSuit suit) {
  switch (suit) {
    case ColorSuit.red:
      return const Color(0xFFE63946);
    case ColorSuit.yellow:
      return const Color(0xFFF4A261);
    case ColorSuit.green:
      return const Color(0xFF2A9D8F);
    case ColorSuit.blue:
      return const Color(0xFF457B9D);
    case ColorSuit.white:
      return const Color(0xFFE9ECEF);
  }
}

String cardDisplay(Card card) {
  return '${colorName(card.color)} ${card.number}';
}

Map<ColorSuit, List<Card>> _clonePiles(Map<ColorSuit, List<Card>> piles) {
  return {
    for (final entry in piles.entries) entry.key: List.of(entry.value),
  };
}
