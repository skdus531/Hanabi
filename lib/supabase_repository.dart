import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'game_engine.dart';
import 'models.dart';

class SupabaseRoomRepository {
  SupabaseRoomRepository(this.client, this.engine);

  final SupabaseClient client;
  final GameEngine engine;

  Future<RoomData> createRoom({
    required String playerId,
    required String playerName,
    required int maxPlayers,
  }) async {
    final random = Random();
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = _generateCode(random);
      try {
        final response = await client.from('rooms').insert({
          'code': code,
          'host_id': playerId,
          'status': 'lobby',
          'max_players': maxPlayers,
          'players': [
            PlayerSetup(id: playerId, name: playerName, ready: false).toJson(),
          ],
          'game_state': null,
          'version': 0,
        }).select().single();
        return RoomData.fromJson(response);
      } on PostgrestException {
        continue;
      }
    }
    throw Exception('Unable to create a unique room code.');
  }

  Future<RoomData> joinRoom({
    required String code,
    required String playerId,
    required String playerName,
  }) async {
    final room = await fetchRoomByCode(code);
    if (room.status != 'lobby') {
      throw Exception('Room is already in progress.');
    }
    if (room.players.length >= room.maxPlayers) {
      throw Exception('Room is full.');
    }

    final players = List<PlayerSetup>.from(room.players);
    final existingIndex = players.indexWhere((player) => player.id == playerId);
    if (existingIndex >= 0) {
      players[existingIndex] =
          players[existingIndex].copy(name: playerName);
    } else {
      players.add(PlayerSetup(id: playerId, name: playerName));
    }

    final response = await client.from('rooms').update({
      'players': players.map((player) => player.toJson()).toList(),
    }).eq('id', room.id).select().single();

    return RoomData.fromJson(response);
  }

  Future<RoomData> setReady({
    required RoomData room,
    required String playerId,
    required bool ready,
  }) async {
    final players = room.players
        .map((player) => player.id == playerId
            ? player.copy(ready: ready)
            : player)
        .toList();

    final response = await client.from('rooms').update({
      'players': players.map((player) => player.toJson()).toList(),
    }).eq('id', room.id).select().single();

    return RoomData.fromJson(response);
  }

  Future<RoomData> startGame({required RoomData room}) async {
    final random = Random();
    final gameState = engine.startGame(room.players, random);

    final response = await client.from('rooms').update({
      'status': 'playing',
      'game_state': gameState.toJson(),
      'version': room.version + 1,
    }).eq('id', room.id).select().single();

    return RoomData.fromJson(response);
  }

  Future<RoomData> updateGameState({
    required RoomData room,
    required GameState gameState,
  }) async {
    final status = gameState.result == null ? 'playing' : 'ended';

    final response = await client.from('rooms').update({
      'status': status,
      'game_state': gameState.toJson(),
      'version': room.version + 1,
    }).eq('id', room.id).eq('version', room.version).select().maybeSingle();

    if (response == null) {
      return fetchRoom(room.id);
    }

    return RoomData.fromJson(response);
  }

  Stream<RoomData> watchRoom(String roomId) {
    return client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) {
      if (rows.isEmpty) {
        throw Exception('Room not found.');
      }
      return RoomData.fromJson(rows.first);
    });
  }

  Future<RoomData> fetchRoomByCode(String code) async {
    final response =
        await client.from('rooms').select().eq('code', code).single();
    return RoomData.fromJson(response);
  }

  Future<RoomData> fetchRoom(String id) async {
    final response = await client.from('rooms').select().eq('id', id).single();
    return RoomData.fromJson(response);
  }

  String _generateCode(Random random) {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    return List.generate(4, (_) => letters[random.nextInt(letters.length)])
        .join();
  }
}
