import 'dart:math';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game_engine.dart';
import 'models.dart';
import 'providers.dart';

class HanabiApp extends StatelessWidget {
  const HanabiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B998B),
        background: const Color(0xFFF7F3EE),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(baseTheme.textTheme),
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);

    if (mode == AppMode.online) {
      final roomState = ref.watch(onlineRoomControllerProvider);
      final room = roomState.room;
      if (room == null) {
        return HomeScreen(onlineState: roomState);
      }
      if (room.status == 'lobby') {
        return OnlineLobbyScreen(roomState: roomState);
      }
      if (room.status == 'playing') {
        if (room.gameState == null) {
          return const HomeScreen();
        }
        return GameScreen(
          gameState: room.gameState!,
          mode: AppMode.online,
        );
      }
      return GameOverScreen(result: room.gameState?.result);
    }

    final screen = ref.watch(appScreenProvider);
    switch (screen) {
      case AppScreen.home:
        return HomeScreen();
      case AppScreen.lobby:
        return const LocalLobbyScreen();
      case AppScreen.game:
        final game = ref.watch(localGameControllerProvider);
        if (game == null) {
          return HomeScreen();
        }
        return GameScreen(
          gameState: game,
          mode: AppMode.local,
        );
      case AppScreen.gameOver:
        final game = ref.watch(localGameControllerProvider);
        return GameOverScreen(result: game?.result);
    }
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onlineState});

  final OnlineRoomState? onlineState;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appModeProvider);
    final playerCount = ref.watch(playerCountProvider);
    final roomState = widget.onlineState;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Hanabi',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Co-op fireworks. Limited clues. Perfect score awaits.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 32),
                SegmentedButton<AppMode>(
                  segments: const [
                    ButtonSegment(
                      value: AppMode.local,
                      label: Text('Local'),
                    ),
                    ButtonSegment(
                      value: AppMode.online,
                      label: Text('Online'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) {
                    ref.read(appModeProvider.notifier).state = value.first;
                  },
                ),
                const SizedBox(height: 24),
                if (mode == AppMode.local)
                  _buildLocalSetup(context, playerCount)
                else
                  _buildOnlineSetup(context, roomState),
                const Spacer(),
                Text(
                  'Basic Hanabi rules, multiplayer sync via Supabase.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalSetup(BuildContext context, int playerCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Player count',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: List.generate(4, (index) {
            final count = index + 2;
            return ChoiceChip(
              label: Text('$count players'),
              selected: playerCount == count,
              onSelected: (_) {
                ref.read(playerCountProvider.notifier).state = count;
              },
            );
          }),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 260,
          child: ElevatedButton(
            onPressed: () {
              final players = List.generate(
                playerCount,
                (index) => PlayerSetup(
                  id: 'p${index + 1}',
                  name: 'Player ${index + 1}',
                ),
              );
              ref.read(localPlayersProvider.notifier).state = players;
              ref.read(appScreenProvider.notifier).state = AppScreen.lobby;
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: const Text('New Local Game'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Pass-and-play on one device.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildOnlineSetup(BuildContext context, OnlineRoomState? roomState) {
    final loading = roomState?.loading ?? false;
    final error = roomState?.error;
    final maxPlayers = ref.watch(playerCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your name',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          onChanged: (value) {
            ref.read(selfNameProvider.notifier).state = value;
          },
          decoration: const InputDecoration(hintText: 'Enter a nickname'),
        ),
        const SizedBox(height: 24),
        Text(
          'Max players',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: List.generate(4, (index) {
            final count = index + 2;
            return ChoiceChip(
              label: Text('$count players'),
              selected: maxPlayers == count,
              onSelected: (_) {
                ref.read(playerCountProvider.notifier).state = count;
              },
            );
          }),
        ),
        const SizedBox(height: 24),
        Text(
          'Room code',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _roomController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 4,
          decoration: const InputDecoration(
            hintText: 'ABCD',
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final count = ref.read(playerCountProvider);
                        await ref
                            .read(onlineRoomControllerProvider.notifier)
                            .createRoom(maxPlayers: count);
                      },
                child: const Text('Create Room'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final code = _roomController.text.trim().toUpperCase();
                        if (code.isEmpty) {
                          return;
                        }
                        await ref
                            .read(onlineRoomControllerProvider.notifier)
                            .joinRoom(code);
                      },
                child: const Text('Join Room'),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              error,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }
}

class LocalLobbyScreen extends ConsumerWidget {
  const LocalLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(localPlayersProvider);
    final allReady = players.isNotEmpty && players.every((player) => player.ready);

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        ref.read(appScreenProvider.notifier).state =
                            AppScreen.home;
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Lobby',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.separated(
                    itemCount: players.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return _LobbyPlayerCard(
                        index: index,
                        player: player,
                        onChanged: (updated) {
                          final next = List<PlayerSetup>.from(players);
                          next[index] = updated;
                          ref.read(localPlayersProvider.notifier).state = next;
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: allReady
                            ? () {
                                ref
                                    .read(localGameControllerProvider.notifier)
                                    .startGame(players);
                                ref.read(appScreenProvider.notifier).state =
                                    AppScreen.game;
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text('Start Game'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnlineLobbyScreen extends ConsumerWidget {
  const OnlineLobbyScreen({super.key, required this.roomState});

  final OnlineRoomState roomState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = roomState.room!;
    final selfId = ref.watch(selfIdProvider);
    final isHost = room.hostId == selfId;
    final selfIndex =
        room.players.indexWhere((player) => player.id == selfId);
    final selfPlayer = selfIndex == -1
        ? PlayerSetup(id: selfId, name: 'You')
        : room.players[selfIndex];
    final allReady = room.players.length >= 2 &&
        room.players.every((player) => player.ready);

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        ref
                            .read(onlineRoomControllerProvider.notifier)
                            .leaveRoom();
                      },
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Room ${room.code}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    if (isHost) const _PillLabel(label: 'Host'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Players (${room.players.length}/${room.maxPlayers})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: room.players.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final player = room.players[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF1B998B),
                              child: Text('${index + 1}'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(player.name),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              player.ready ? 'Ready' : 'Not ready',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            if (player.id == selfId)
                              Switch(
                                value: player.ready,
                                onChanged: (value) {
                                  ref
                                      .read(onlineRoomControllerProvider
                                          .notifier)
                                      .toggleReady(value);
                                },
                              )
                            else
                              Icon(
                                player.ready
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: player.ready
                                    ? const Color(0xFF2A9D8F)
                                    : Colors.grey,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (roomState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      roomState.error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.redAccent),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (isHost && allReady && !roomState.loading)
                            ? () {
                                ref
                                    .read(onlineRoomControllerProvider
                                        .notifier)
                                    .startGame();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(isHost
                            ? 'Start Game'
                            : 'Waiting for host'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: roomState.loading
                            ? null
                            : () {
                                final ready = !selfPlayer.ready;
                                ref
                                    .read(onlineRoomControllerProvider
                                        .notifier)
                                    .toggleReady(ready);
                              },
                        child: Text(
                          selfPlayer.ready ? 'Set Not Ready' : 'Set Ready',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LobbyPlayerCard extends StatelessWidget {
  const _LobbyPlayerCard({
    required this.index,
    required this.player,
    required this.onChanged,
  });

  final int index;
  final PlayerSetup player;
  final ValueChanged<PlayerSetup> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1B998B),
            child: Text('${index + 1}'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              initialValue: player.name,
              onChanged: (value) {
                onChanged(player.copy(name: value));
              },
              decoration: const InputDecoration(
                labelText: 'Player name',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                player.ready ? 'Ready' : 'Not ready',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Switch(
                value: player.ready,
                onChanged: (value) {
                  onChanged(player.copy(ready: value));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    required this.gameState,
    required this.mode,
  });

  final GameState gameState;
  final AppMode mode;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  Widget build(BuildContext context) {
    final state = widget.gameState;
    final currentPlayer = state.players[state.currentPlayerIndex];
    final isOnline = widget.mode == AppMode.online;
    final selfId = ref.watch(selfIdProvider);
    final isMyTurn = !isOnline || currentPlayer.id == selfId;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        if (isOnline) {
                          await ref
                              .read(onlineRoomControllerProvider.notifier)
                              .leaveRoom();
                          return;
                        }
                        ref.read(appScreenProvider.notifier).state =
                            AppScreen.home;
                      },
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Game Table',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    if (!isMyTurn)
                      const _PillLabel(label: 'Waiting for turn'),
                    const SizedBox(width: 8),
                    _TokenChip(
                      label: 'Clues',
                      value: state.clueTokens,
                      maxValue: 8,
                      color: const Color(0xFF1B998B),
                    ),
                    const SizedBox(width: 8),
                    _TokenChip(
                      label: 'Fuses',
                      value: state.fuseTokens,
                      maxValue: 3,
                      color: const Color(0xFFE76F51),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      final mainArea =
                          _buildMainArea(context, state, currentPlayer, isMyTurn);
                      final sidePanel = _buildSidePanel(context, state);

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: mainArea),
                            const SizedBox(width: 16),
                            SizedBox(width: 320, child: sidePanel),
                          ],
                        );
                      }

                      return ListView(
                        children: [
                          mainArea,
                          const SizedBox(height: 16),
                          sidePanel,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainArea(
    BuildContext context,
    GameState state,
    PlayerState currentPlayer,
    bool isMyTurn,
  ) {
    final isOnline = widget.mode == AppMode.online;
    final selfId = ref.watch(selfIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFireworks(state),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _InfoCard(
              title: 'Deck',
              value: '${state.deck.length} cards',
              subtitle: state.finalRound
                  ? 'Final turns: ${state.finalTurnsRemaining}'
                  : 'Round in progress',
            ),
            _InfoCard(
              title: 'Current Turn',
              value: currentPlayer.name,
              subtitle: isMyTurn ? 'Your turn' : 'Waiting',
            ),
            _InfoCard(
              title: 'Score',
              value: '${state.currentScore()} / 25',
              subtitle: 'Keep the fireworks rising',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (state.clueTokens > 0 && isMyTurn)
                    ? () async {
                        final clue = await showClueDialog(
                          context,
                          state: state,
                        );
                        if (clue == null) {
                          return;
                        }
                        await _sendClue(clue);
                        await _afterAction(isOnline: isOnline);
                      }
                    : null,
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Give Clue'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showDiscardDialog(context, state),
                icon: const Icon(Icons.delete_outline),
                label: const Text('View Discards'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Players',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Column(
          children: List.generate(state.players.length, (index) {
            final player = state.players[index];
            final isCurrent = index == state.currentPlayerIndex;
            final hideHand = isOnline ? player.id == selfId : isCurrent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PlayerHandRow(
                player: player,
                isCurrent: isCurrent,
                highlight: isCurrent,
                hideHand: hideHand,
                onCardTapped: (hideHand && isMyTurn)
                    ? (cardIndex) async {
                        final action = await showCardActionDialog(context);
                        if (action == null) {
                          return;
                        }
                        if (action == CardAction.play) {
                          await _sendPlay(cardIndex);
                        } else {
                          await _sendDiscard(cardIndex);
                        }
                        await _afterAction(isOnline: isOnline);
                      }
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSidePanel(BuildContext context, GameState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SideSection(
          title: 'Action Log',
          child: SizedBox(
            height: 220,
            child: ListView.builder(
              itemCount: min(state.actionLog.length, 12),
              itemBuilder: (context, index) {
                final logIndex = state.actionLog.length - 1 - index;
                final entry = state.actionLog[logIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    entry,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _SideSection(
            title: 'Discard Pile',
            child: DiscardSummary(discard: state.discard),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _SideSection(
            title: 'Hint Overview',
            child: _HintSummary(players: state.players),
          ),
        ),
      ],
    );
  }

  Widget _buildFireworks(GameState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fireworks',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ColorSuit.values.map((color) {
              final pile = state.piles[color] ?? [];
              final topValue = pile.isEmpty ? 0 : pile.last.number;
              return _PileColumn(
                color: color,
                value: topValue,
                count: pile.length,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _sendClue(ClueAction clue) async {
    if (widget.mode == AppMode.online) {
      await ref.read(onlineRoomControllerProvider.notifier).sendClue(clue);
    } else {
      ref.read(localGameControllerProvider.notifier).giveClue(clue);
    }
  }

  Future<void> _sendPlay(int index) async {
    if (widget.mode == AppMode.online) {
      await ref.read(onlineRoomControllerProvider.notifier).playCard(index);
    } else {
      ref.read(localGameControllerProvider.notifier).playCard(index);
    }
  }

  Future<void> _sendDiscard(int index) async {
    if (widget.mode == AppMode.online) {
      await ref.read(onlineRoomControllerProvider.notifier).discardCard(index);
    } else {
      ref.read(localGameControllerProvider.notifier).discardCard(index);
    }
  }

  Future<void> _afterAction({required bool isOnline}) async {
    if (!mounted) {
      return;
    }

    if (!isOnline) {
      final game = ref.read(localGameControllerProvider);
      if (game?.result != null) {
        ref.read(appScreenProvider.notifier).state = AppScreen.gameOver;
        return;
      }
      await _showPassDialog();
    }
  }

  Future<void> _showPassDialog() async {
    final state = ref.read(localGameControllerProvider);
    if (state == null) {
      return;
    }
    final nextPlayer = state.players[state.currentPlayerIndex];
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pass the device'),
          content: Text('Next turn: ${nextPlayer.name}'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Start Turn'),
            ),
          ],
        );
      },
    );
  }

  void _showDiscardDialog(BuildContext context, GameState state) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard Pile'),
          content: SizedBox(
            width: 360,
            child: DiscardSummary(discard: state.discard),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class GameOverScreen extends ConsumerWidget {
  const GameOverScreen({super.key, required this.result});

  final GameResult? result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = result;
    if (resolved == null) {
      return const HomeScreen();
    }
    final headline = resolved.win ? 'Victory!' : 'Game Over';
    final subtext = resolved.win
        ? 'The fireworks blaze in perfect harmony.'
        : 'The team ran out of fuses.';

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(subtext),
                const SizedBox(height: 24),
                _InfoCard(
                  title: 'Final Score',
                  value: '${resolved.score} / 25',
                  subtitle: resolved.reason,
                ),
                const SizedBox(height: 16),
                Text(
                  'Pile Breakdown',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ColorSuit.values.map((color) {
                    final value = resolved.pileHeights[color] ?? 0;
                    return _InfoCard(
                      title: colorName(color),
                      value: value.toString(),
                      subtitle: 'Top card',
                      accent: suitColor(color),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 240,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(appScreenProvider.notifier).state = AppScreen.home;
                      ref.read(localGameControllerProvider.notifier).reset();
                      ref
                          .read(onlineRoomControllerProvider.notifier)
                          .leaveRoom();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Play Again'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Action Log',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: resolved.actionLog.length,
                    itemBuilder: (context, index) {
                      final entry = resolved.actionLog[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(entry),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerHandRow extends StatelessWidget {
  const PlayerHandRow({
    super.key,
    required this.player,
    required this.isCurrent,
    required this.highlight,
    required this.hideHand,
    this.onCardTapped,
  });

  final PlayerState player;
  final bool isCurrent;
  final bool highlight;
  final bool hideHand;
  final ValueChanged<int>? onCardTapped;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: const Color(0xFF1B998B), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                player.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              if (isCurrent) const _PillLabel(label: 'Current'),
              if (!isCurrent && hideHand)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: _PillLabel(label: 'You'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(player.hand.length, (index) {
              final card = player.hand[index];
              final knowledge = player.knowledge[index];
              return GestureDetector(
                onTap: onCardTapped == null
                    ? null
                    : () => onCardTapped!(index),
                child: hideHand
                    ? CardBack(knowledge: knowledge)
                    : CardFace(card: card),
              );
            }),
          ),
          if (hideHand) ...[
            const SizedBox(height: 12),
            _KnowledgePanel(knowledge: player.knowledge),
          ],
        ],
      ),
    );
  }
}

class _KnowledgePanel extends StatelessWidget {
  const _KnowledgePanel({required this.knowledge});

  final List<CardKnowledge> knowledge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101828).withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(knowledge.length, (index) {
          final info = knowledge[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index == knowledge.length - 1 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    'Card ${index + 1}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ColorSuit.values.map((color) {
                          final active = info.possibleColors.contains(color);
                          return _KnowledgeChip(
                            label: colorShort(color),
                            active: active,
                            color: suitColor(color),
                            forceBlackForWhite: color == ColorSuit.white,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(5, (value) {
                          final number = value + 1;
                          final active = info.possibleNumbers.contains(number);
                          return _KnowledgeChip(
                            label: number.toString(),
                            active: active,
                            color: Colors.white,
                            isNumberChip: true,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _KnowledgeChip extends StatelessWidget {
  const _KnowledgeChip({
    required this.label,
    required this.active,
    required this.color,
    this.forceBlackForWhite = false,
    this.isNumberChip = false,
  });

  final String label;
  final bool active;
  final Color color;
  final bool forceBlackForWhite;
  final bool isNumberChip;

  @override
  Widget build(BuildContext context) {
    final isWhite = forceBlackForWhite || color == Colors.white;
    if (forceBlackForWhite && isWhite && !active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.black45,
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.lineThrough,
              ),
        ),
      );
    }
    if (isNumberChip || (forceBlackForWhite && isWhite)) {
      final textColor = const Color(0xFF6B7280);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFC5CF)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: textColor,
                decoration: active ? null : TextDecoration.lineThrough,
              ),
        ),
      );
    }

    final useBlackForWhite = forceBlackForWhite && isWhite;
    final whiteTone = const Color(0xFF374151); // dark gray
    final borderColor = useBlackForWhite
        ? whiteTone
        : (isWhite ? Colors.black : color);
    final activeText =
        useBlackForWhite ? whiteTone : (isWhite ? Colors.white : color);
    final inactiveText = useBlackForWhite
        ? whiteTone
        : (isWhite ? const Color(0xFF374151) : Colors.black45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: useBlackForWhite
            ? const Color(0xFFF3F4F6)
            : (active
                ? (isWhite
                    ? const Color(0xFF111827)
                    : color.withOpacity(0.18))
                : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: useBlackForWhite
              ? borderColor
              : (active
                  ? (isWhite ? borderColor : color.withOpacity(0.6))
                  : (isWhite ? const Color(0xFF9CA3AF) : Colors.black12)),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? activeText : inactiveText,
              fontWeight: isWhite ? FontWeight.w700 : null,
              decoration: active ? null : TextDecoration.lineThrough,
            ),
      ),
    );
  }
}

class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.card});

  final Card card;

  @override
  Widget build(BuildContext context) {
    final color = suitColor(card.color);
    final borderColor =
        card.color == ColorSuit.white ? const Color(0xFFADB5BD) : color;
    final textColor =
        card.color == ColorSuit.white ? const Color(0xFF495057) : color;
    return Container(
      width: 74,
      height: 104,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(
        child: Text(
          '${card.number}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}

class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.knowledge});

  final CardKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 104,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2D42), Color(0xFF1D3557)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF7F3EE), width: 1),
      ),
      child: Center(
        child: Text(
          knowledge.badge,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
        ),
      ),
    );
  }
}

class DiscardSummary extends StatelessWidget {
  const DiscardSummary({super.key, required this.discard});

  final List<Card> discard;

  @override
  Widget build(BuildContext context) {
    final List<Card> recent = discard.reversed.take(8).toList();
    final summary = buildDiscardSummary(discard);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (recent.isNotEmpty)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: recent
                .map<Widget>((card) => _DiscardBadge(card: card))
                .toList(),
          )
        else
          Text(
            'No discards yet.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: _DiscardGrid(summary: summary),
        ),
      ],
    );
  }
}

class _DiscardBadge extends StatelessWidget {
  const _DiscardBadge({required this.card});

  final Card card;

  @override
  Widget build(BuildContext context) {
    final color = suitColor(card.color);
    final textColor =
        card.color == ColorSuit.white ? const Color(0xFF6B7280) : color;
    final borderColor =
        card.color == ColorSuit.white ? const Color(0xFFE5E7EB) : color;
    final backgroundColor = card.color == ColorSuit.white
        ? Colors.white
        : color.withOpacity(0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        '${colorShort(card.color)}${card.number}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _DiscardGrid extends StatelessWidget {
  const _DiscardGrid({required this.summary});

  final Map<ColorSuit, Map<int, int>> summary;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelSmall;
    final cellStyle = Theme.of(context).textTheme.labelSmall;

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(60),
        1: FixedColumnWidth(32),
        2: FixedColumnWidth(32),
        3: FixedColumnWidth(32),
        4: FixedColumnWidth(32),
        5: FixedColumnWidth(32),
      },
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            ...List.generate(5, (index) {
              final number = index + 1;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('$number', style: headerStyle),
                ),
              );
            }),
          ],
        ),
        ...ColorSuit.values.map((color) {
          final counts = summary[color] ?? {};
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: suitColor(color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      colorShort(color),
                      style: headerStyle,
                    ),
                  ],
                ),
              ),
              ...List.generate(5, (index) {
                final number = index + 1;
                final count = counts[number] ?? 0;
                return Center(
                  child: Container(
                    width: 24,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: count == 0
                          ? Colors.transparent
                          : suitColor(color).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: count == 0
                            ? Colors.grey.withOpacity(0.2)
                            : suitColor(color).withOpacity(0.6),
                      ),
                    ),
                    child: Text(
                      count.toString(),
                      style: cellStyle?.copyWith(
                        fontWeight:
                            count == 0 ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text('$label: $value/$maxValue'),
    );
  }
}

class _SideSection extends StatelessWidget {
  const _SideSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HintSummary extends StatelessWidget {
  const _HintSummary({required this.players});

  final List<PlayerState> players;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: players.map((player) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  player.name,
                  style: Theme.of(context).textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(player.knowledge.length, (index) {
                    final info = player.knowledge[index];
                    return _HintBadge(knowledge: info);
                  }),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _HintBadge extends StatelessWidget {
  const _HintBadge({required this.knowledge});

  final CardKnowledge knowledge;

  @override
  Widget build(BuildContext context) {
    final knownColor = knowledge.knownColor;
    final badgeColor = knownColor == null
        ? const Color(0xFF94A3B8)
        : suitColor(knownColor);
    final textColor =
        knownColor == ColorSuit.white ? const Color(0xFF111827) : badgeColor;
    final isUnknown = knowledge.badge == '??';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.7)),
      ),
      child: Text(
        knowledge.badge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isUnknown ? Colors.black54 : textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: accent != null ? Border.all(color: accent!, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PileColumn extends StatelessWidget {
  const _PileColumn({
    required this.color,
    required this.value,
    required this.count,
  });

  final ColorSuit color;
  final int value;
  final int count;

  @override
  Widget build(BuildContext context) {
    final suit = suitColor(color);
    final textColor =
        color == ColorSuit.white ? const Color(0xFF495057) : suit;
    return Column(
      children: [
        Text(
          colorName(color),
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: textColor),
        ),
        const SizedBox(height: 6),
        Container(
          width: 56,
          height: 72,
          decoration: BoxDecoration(
            color: suit.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  color == ColorSuit.white ? const Color(0xFFADB5BD) : suit,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              value == 0 ? '-' : value.toString(),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: textColor, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count cards',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B998B).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7F3EE), Color(0xFFE8F1F2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -40,
          child: _GlowOrb(color: Color(0xFF1B998B), size: 220),
        ),
        Positioned(
          bottom: -140,
          left: -60,
          child: _GlowOrb(color: Color(0xFFF4A261), size: 260),
        ),
        Positioned(
          top: 140,
          left: -80,
          child: _GlowOrb(color: Color(0xFF264653), size: 180),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.25), Colors.transparent],
        ),
      ),
    );
  }
}

Future<CardAction?> showCardActionDialog(BuildContext context) {
  return showDialog<CardAction>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Choose action'),
        content: const Text('Play or discard this card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(CardAction.discard),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(CardAction.play),
            child: const Text('Play'),
          ),
        ],
      );
    },
  );
}

Future<ClueAction?> showClueDialog(
  BuildContext context, {
  required GameState state,
}) {
  int? targetIndex;
  ClueType? type;
  ColorSuit? color;
  int? number;

  return showDialog<ClueAction>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final canChooseValue = targetIndex != null && type != null;
          final target =
              targetIndex == null ? null : state.players[targetIndex!];
          List<int> matches = [];
          if (target != null && canChooseValue) {
            for (var i = 0; i < target.hand.length; i++) {
              final card = target.hand[i];
              if (type == ClueType.color && color != null) {
                if (card.color == color) {
                  matches.add(i);
                }
              }
              if (type == ClueType.number && number != null) {
                if (card.number == number) {
                  matches.add(i);
                }
              }
            }
          }

          final isValid = matches.isNotEmpty && targetIndex != null;

          return AlertDialog(
            title: const Text('Give a clue'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a player',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(state.players.length, (index) {
                      if (index == state.currentPlayerIndex) {
                        return const SizedBox.shrink();
                      }
                      final player = state.players[index];
                      return ChoiceChip(
                        label: Text(player.name),
                        selected: targetIndex == index,
                        onSelected: (_) {
                          setState(() {
                            targetIndex = index;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Clue type',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Color'),
                        selected: type == ClueType.color,
                        onSelected: targetIndex == null
                            ? null
                            : (_) {
                                setState(() {
                                  type = ClueType.color;
                                  number = null;
                                });
                              },
                      ),
                      ChoiceChip(
                        label: const Text('Number'),
                        selected: type == ClueType.number,
                        onSelected: targetIndex == null
                            ? null
                            : (_) {
                                setState(() {
                                  type = ClueType.number;
                                  color = null;
                                });
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (type == ClueType.color)
                    Wrap(
                      spacing: 8,
                      children: ColorSuit.values.map((suit) {
                        return ChoiceChip(
                          label: Text(colorName(suit)),
                          selected: color == suit,
                          onSelected: !canChooseValue
                              ? null
                              : (_) {
                                  setState(() {
                                    color = suit;
                                  });
                                },
                        );
                      }).toList(),
                    ),
                  if (type == ClueType.number)
                    Wrap(
                      spacing: 8,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return ChoiceChip(
                          label: Text(value.toString()),
                          selected: number == value,
                          onSelected: !canChooseValue
                              ? null
                              : (_) {
                                  setState(() {
                                    number = value;
                                  });
                                },
                        );
                      }),
                    ),
                  const SizedBox(height: 12),
                  if (target != null && matches.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Matching cards: ${matches.length}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: List.generate(target.hand.length, (index) {
                            final card = target.hand[index];
                            final isMatch = matches.contains(index);
                            return Opacity(
                              opacity: isMatch ? 1 : 0.4,
                              child: CardFace(card: card),
                            );
                          }),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isValid
                    ? () {
                        Navigator.of(context).pop(
                          ClueAction(
                            targetIndex: targetIndex!,
                            type: type!,
                            color: color,
                            number: number,
                          ),
                        );
                      }
                    : null,
                child: const Text('Confirm Clue'),
              ),
            ],
          );
        },
      );
    },
  );
}
