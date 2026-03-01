import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'game_engine.dart';
import 'models.dart';
import 'supabase_repository.dart';

final appModeProvider = StateProvider<AppMode>((ref) => AppMode.local);
final appScreenProvider = StateProvider<AppScreen>((ref) => AppScreen.home);
final playerCountProvider = StateProvider<int>((ref) => 4);
final selfNameProvider = StateProvider<String>((ref) => '');
final selfIdProvider = StateProvider<String>((ref) => Uuid().v4());

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final gameEngineProvider = Provider<GameEngine>((ref) => const GameEngine());

final roomRepositoryProvider = Provider<SupabaseRoomRepository>((ref) {
  return SupabaseRoomRepository(
    ref.read(supabaseClientProvider),
    ref.read(gameEngineProvider),
  );
});

final localPlayersProvider = StateProvider<List<PlayerSetup>>((ref) => []);

final localGameControllerProvider =
    StateNotifierProvider<LocalGameController, GameState?>((ref) {
  return LocalGameController(ref.read(gameEngineProvider));
});

class LocalGameController extends StateNotifier<GameState?> {
  LocalGameController(this.engine) : super(null);

  final GameEngine engine;

  void startGame(List<PlayerSetup> players) {
    state = engine.startGame(players, Random());
  }

  void giveClue(ClueAction clue) {
    if (state == null) {
      return;
    }
    state = engine.giveClue(state!, clue);
  }

  void discardCard(int index) {
    if (state == null) {
      return;
    }
    state = engine.discardCard(state!, index);
  }

  void playCard(int index) {
    if (state == null) {
      return;
    }
    state = engine.playCard(state!, index);
  }

  void reset() {
    state = null;
  }
}

final onlineRoomControllerProvider =
    StateNotifierProvider<OnlineRoomController, OnlineRoomState>((ref) {
  return OnlineRoomController(ref, ref.read(roomRepositoryProvider));
});

class OnlineRoomState {
  OnlineRoomState({
    required this.room,
    required this.loading,
    required this.error,
  });

  final RoomData? room;
  final bool loading;
  final String? error;

  OnlineRoomState copyWith({
    RoomData? room,
    bool? loading,
    String? error,
  }) {
    return OnlineRoomState(
      room: room ?? this.room,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  factory OnlineRoomState.initial() {
    return OnlineRoomState(room: null, loading: false, error: null);
  }
}

class OnlineRoomController extends StateNotifier<OnlineRoomState> {
  OnlineRoomController(this.ref, this.repository)
      : super(OnlineRoomState.initial());

  final Ref ref;
  final SupabaseRoomRepository repository;
  StreamSubscription<RoomData>? _subscription;

  Future<void> createRoom({required int maxPlayers}) async {
    final name = _readName();
    _setLoading();
    try {
      final room = await repository.createRoom(
        playerId: ref.read(selfIdProvider),
        playerName: name,
        maxPlayers: maxPlayers,
      );
      _subscribe(room);
      state = state.copyWith(room: room, loading: false, error: null);
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> joinRoom(String code) async {
    final name = _readName();
    _setLoading();
    try {
      final room = await repository.joinRoom(
        code: code,
        playerId: ref.read(selfIdProvider),
        playerName: name,
      );
      _subscribe(room);
      state = state.copyWith(room: room, loading: false, error: null);
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> toggleReady(bool ready) async {
    final room = state.room;
    if (room == null) {
      return;
    }
    _setLoading();
    try {
      final updated = await repository.setReady(
        room: room,
        playerId: ref.read(selfIdProvider),
        ready: ready,
      );
      state = state.copyWith(room: updated, loading: false, error: null);
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> startGame() async {
    final room = state.room;
    if (room == null) {
      return;
    }
    _setLoading();
    try {
      final updated = await repository.startGame(room: room);
      state = state.copyWith(room: updated, loading: false, error: null);
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> sendClue(ClueAction clue) async {
    final room = state.room;
    if (room == null || room.gameState == null) {
      return;
    }
    if (!_isMyTurn(room.gameState!)) {
      return;
    }
    final engine = ref.read(gameEngineProvider);
    final updatedState = engine.giveClue(room.gameState!, clue);
    await _updateGame(room, updatedState);
  }

  Future<void> playCard(int index) async {
    final room = state.room;
    if (room == null || room.gameState == null) {
      return;
    }
    if (!_isMyTurn(room.gameState!)) {
      return;
    }
    final engine = ref.read(gameEngineProvider);
    final updatedState = engine.playCard(room.gameState!, index);
    await _updateGame(room, updatedState);
  }

  Future<void> discardCard(int index) async {
    final room = state.room;
    if (room == null || room.gameState == null) {
      return;
    }
    if (!_isMyTurn(room.gameState!)) {
      return;
    }
    final engine = ref.read(gameEngineProvider);
    final updatedState = engine.discardCard(room.gameState!, index);
    await _updateGame(room, updatedState);
  }

  Future<void> _updateGame(RoomData room, GameState updatedState) async {
    _setLoading();
    try {
      final updated = await repository.updateGameState(
        room: room,
        gameState: updatedState,
      );
      state = state.copyWith(room: updated, loading: false, error: null);
    } catch (error) {
      _setError(error.toString());
    }
  }

  Future<void> leaveRoom() async {
    await _subscription?.cancel();
    _subscription = null;
    state = OnlineRoomState.initial();
  }

  void _subscribe(RoomData room) {
    _subscription?.cancel();
    _subscription = repository.watchRoom(room.id).listen(
      (updatedRoom) {
        state = state.copyWith(room: updatedRoom, loading: false, error: null);
      },
      onError: (error) {
        _setError(error.toString());
      },
    );
  }

  void _setLoading() {
    state = state.copyWith(loading: true, error: null);
  }

  void _setError(String message) {
    state = state.copyWith(loading: false, error: message);
  }

  String _readName() {
    final name = ref.read(selfNameProvider);
    if (name.trim().isEmpty) {
      return 'Player';
    }
    return name.trim();
  }

  bool _isMyTurn(GameState gameState) {
    final selfId = ref.read(selfIdProvider);
    return gameState.players[gameState.currentPlayerIndex].id == selfId;
  }
}
