import 'dart:math';

import 'models.dart';

class GameEngine {
  const GameEngine();

  GameState startGame(List<PlayerSetup> players, Random random) {
    final deck = buildDeck(random);
    final playerCount = players.length;
    final handSize = playerCount <= 3 ? 5 : 4;

    final playerStates = <PlayerState>[];
    for (var index = 0; index < playerCount; index++) {
      final hand = <Card>[];
      final knowledge = <CardKnowledge>[];
      for (var i = 0; i < handSize; i++) {
        final card = deck.removeLast();
        hand.add(card);
        knowledge.add(CardKnowledge.fresh());
      }
      playerStates.add(PlayerState(
        id: players[index].id,
        name: players[index].name,
        hand: hand,
        knowledge: knowledge,
      ));
    }

    final piles = {
      for (final color in ColorSuit.values) color: <Card>[],
    };

    return GameState(
      clueTokens: 8,
      fuseTokens: 3,
      deck: deck,
      discard: [],
      piles: piles,
      players: playerStates,
      currentPlayerIndex: 0,
      finalRound: false,
      finalTurnsRemaining: 0,
      actionLog: ['Game started with $playerCount players.'],
      result: null,
    );
  }

  GameState giveClue(GameState state, ClueAction clue) {
    if (state.clueTokens == 0) {
      return state;
    }

    final target = state.players[clue.targetIndex];
    final matches = <int>[];
    for (var i = 0; i < target.hand.length; i++) {
      final card = target.hand[i];
      if (clue.type == ClueType.color && card.color == clue.color) {
        matches.add(i);
      } else if (clue.type == ClueType.number && card.number == clue.number) {
        matches.add(i);
      }
    }

    if (matches.isEmpty) {
      return state;
    }

    final updatedPlayers = List<PlayerState>.from(state.players);
    final updatedKnowledge = <CardKnowledge>[];
    for (var i = 0; i < target.hand.length; i++) {
      final card = target.hand[i];
      final knowledge = target.knowledge[i];
      if (clue.type == ClueType.color) {
        updatedKnowledge.add(
          knowledge.applyColorClue(clue.color!, card.color == clue.color),
        );
      } else {
        updatedKnowledge.add(
          knowledge.applyNumberClue(clue.number!, card.number == clue.number),
        );
      }
    }
    updatedPlayers[clue.targetIndex] = target.copy(knowledge: updatedKnowledge);

    final giver = state.players[state.currentPlayerIndex];
    final clueText = clue.type == ClueType.color
        ? 'color ${colorName(clue.color!)}'
        : 'number ${clue.number}';

    final updatedState = state.copyWith(
      clueTokens: state.clueTokens - 1,
      players: updatedPlayers,
      actionLog: List.of(state.actionLog)
        ..add(
          '${giver.name} gave a clue to ${target.name}: $clueText (${matches.length} card(s)).',
        ),
    );

    return _endTurn(updatedState, lastCardDrawn: false);
  }

  GameState discardCard(GameState state, int index) {
    final players = List<PlayerState>.from(state.players);
    final player = players[state.currentPlayerIndex];
    final updatedHand = List<Card>.from(player.hand)..removeAt(index);
    final updatedKnowledge = List<CardKnowledge>.from(player.knowledge)
      ..removeAt(index);
    final card = player.hand[index];

    final discard = List<Card>.from(state.discard)..add(card);
    final updatedPlayer = player.copy(
      hand: updatedHand,
      knowledge: updatedKnowledge,
    );
    players[state.currentPlayerIndex] = updatedPlayer;

    var updatedState = state.copyWith(
      players: players,
      discard: discard,
      clueTokens: min(8, state.clueTokens + 1),
      actionLog: List.of(state.actionLog)
        ..add('${player.name} discarded ${cardDisplay(card)}. (+1 clue)'),
    );

    final drawResult = _drawReplacement(updatedState, index);
    updatedState = drawResult.state;

    return _endTurn(updatedState, lastCardDrawn: drawResult.lastCardDrawn);
  }

  GameState playCard(GameState state, int index) {
    final players = List<PlayerState>.from(state.players);
    final player = players[state.currentPlayerIndex];
    final updatedHand = List<Card>.from(player.hand)..removeAt(index);
    final updatedKnowledge = List<CardKnowledge>.from(player.knowledge)
      ..removeAt(index);
    final card = player.hand[index];

    final piles = _clonePiles(state.piles);
    final pile = List<Card>.from(piles[card.color] ?? []);
    final expected = pile.isEmpty ? 1 : pile.last.number + 1;
    final success = card.number == expected;

    final discard = List<Card>.from(state.discard);
    var clueTokens = state.clueTokens;
    var fuseTokens = state.fuseTokens;
    final actionLog = List<String>.from(state.actionLog);

    if (success) {
      pile.add(card);
      piles[card.color] = pile;
      actionLog.add('${player.name} played ${cardDisplay(card)}. Success!');
      if (card.number == 5) {
        clueTokens = min(8, clueTokens + 1);
        actionLog.add('Firework completed. +1 clue token.');
      }
    } else {
      discard.add(card);
      fuseTokens = max(0, fuseTokens - 1);
      actionLog.add(
        '${player.name} misplayed ${cardDisplay(card)}. Fuse lost.',
      );
    }

    final updatedPlayer = player.copy(
      hand: updatedHand,
      knowledge: updatedKnowledge,
    );
    players[state.currentPlayerIndex] = updatedPlayer;

    var updatedState = state.copyWith(
      players: players,
      discard: discard,
      piles: piles,
      clueTokens: clueTokens,
      fuseTokens: fuseTokens,
      actionLog: actionLog,
    );

    final drawResult = _drawReplacement(updatedState, index);
    updatedState = drawResult.state;

    return _endTurn(updatedState, lastCardDrawn: drawResult.lastCardDrawn);
  }

  _DrawResult _drawReplacement(GameState state, int index) {
    if (state.deck.isEmpty) {
      return _DrawResult(state: state, lastCardDrawn: false);
    }

    final deck = List<Card>.from(state.deck);
    final card = deck.removeLast();

    final players = List<PlayerState>.from(state.players);
    final player = players[state.currentPlayerIndex];
    final hand = List<Card>.from(player.hand)..insert(index, card);
    final knowledge = List<CardKnowledge>.from(player.knowledge)
      ..insert(index, CardKnowledge.fresh());
    players[state.currentPlayerIndex] = player.copy(
      hand: hand,
      knowledge: knowledge,
    );

    final updatedState = state.copyWith(
      deck: deck,
      players: players,
    );

    return _DrawResult(
      state: updatedState,
      lastCardDrawn: deck.isEmpty,
    );
  }

  GameState _endTurn(GameState state, {required bool lastCardDrawn}) {
    var updatedState = state;
    if (lastCardDrawn && !state.finalRound) {
      updatedState = updatedState.copyWith(
        finalRound: true,
        finalTurnsRemaining: state.players.length + 1,
        actionLog: List.of(updatedState.actionLog)
          ..add('Final round begins.'),
      );
    }

    final immediateResult = _checkImmediateEnd(updatedState);
    if (immediateResult != null) {
      return updatedState.copyWith(result: immediateResult);
    }

    if (updatedState.finalRound) {
      final remaining = updatedState.finalTurnsRemaining - 1;
      if (remaining <= 0) {
        final result = _buildResult(
          updatedState,
          win: updatedState.fuseTokens > 0,
          reason: 'Final round completed.',
        );
        return updatedState.copyWith(result: result);
      }
      updatedState = updatedState.copyWith(finalTurnsRemaining: remaining);
    }

    final nextPlayer =
        (updatedState.currentPlayerIndex + 1) % updatedState.players.length;
    return updatedState.copyWith(currentPlayerIndex: nextPlayer);
  }

  GameResult? _checkImmediateEnd(GameState state) {
    if (state.fuseTokens <= 0) {
      return _buildResult(
        state,
        win: false,
        reason: 'Explosion: all fuses used.',
      );
    }

    if (state.allPilesCompleted()) {
      return _buildResult(
        state,
        win: true,
        reason: 'All fireworks completed.',
      );
    }

    return null;
  }

  GameResult _buildResult(GameState state,
      {required bool win, required String reason}) {
    return GameResult(
      win: win,
      score: state.currentScore(),
      reason: reason,
      pileHeights: {
        for (final color in ColorSuit.values)
          color: state.piles[color]!.isEmpty
              ? 0
              : state.piles[color]!.last.number,
      },
      actionLog: List.of(state.actionLog),
    );
  }
}

class _DrawResult {
  _DrawResult({required this.state, required this.lastCardDrawn});

  final GameState state;
  final bool lastCardDrawn;
}

class ClueAction {
  ClueAction({
    required this.targetIndex,
    required this.type,
    this.color,
    this.number,
  });

  final int targetIndex;
  final ClueType type;
  final ColorSuit? color;
  final int? number;
}

List<Card> buildDeck(Random random) {
  final deck = <Card>[];
  for (final color in ColorSuit.values) {
    deck.addAll(List.generate(3, (_) => Card(color: color, number: 1)));
    deck.addAll(List.generate(2, (_) => Card(color: color, number: 2)));
    deck.addAll(List.generate(2, (_) => Card(color: color, number: 3)));
    deck.addAll(List.generate(2, (_) => Card(color: color, number: 4)));
    deck.add(Card(color: color, number: 5));
  }
  deck.shuffle(random);
  return deck;
}

Map<ColorSuit, Map<int, int>> buildDiscardSummary(List<Card> discard) {
  final summary = {
    for (final color in ColorSuit.values) color: <int, int>{},
  };

  for (final card in discard) {
    final map = summary[card.color]!;
    map[card.number] = (map[card.number] ?? 0) + 1;
  }

  return summary;
}

Map<ColorSuit, List<Card>> _clonePiles(Map<ColorSuit, List<Card>> piles) {
  return {
    for (final entry in piles.entries) entry.key: List.of(entry.value),
  };
}
