import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// API methods for the independent SideQuest Games area.
/// Invitations are submitted by username; database IDs remain internal.
class GamesService {
  static Map<String, String> _headers({bool json = false}) {
    final token = ApiService.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Return a readable fallback below.
    }

    return {
      'detail': response.body.isEmpty
          ? 'The server returned an empty response.'
          : response.body,
    };
  }

  static List<Map<String, dynamic>> _decodeList(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    throw Exception('Unexpected games response.');
  }

  static Never _throwResponseError(http.Response response) {
    final data = _decodeObject(response);
    throw Exception(
      data['detail']?.toString() ??
          'Games request failed (${response.statusCode}).',
    );
  }

  static Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/games/users/search').replace(
      queryParameters: {'q': query.trim()},
    );

    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) return _decodeList(response);
    _throwResponseError(response);
  }

  static Future<Map<String, dynamic>> createRoom({
    required String gameType,
    required String title,
    required List<String> invitedUsernames,
    int maxPlayers = 8,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/games/rooms'),
      headers: _headers(json: true),
      body: jsonEncode({
        'game_type': gameType,
        'title': title.trim(),
        'invited_usernames': invitedUsernames,
        'max_players': maxPlayers,
      }),
    );

    final data = _decodeObject(response);
    if (response.statusCode == 201) return data;
    throw Exception(
      data['detail']?.toString() ??
          'Could not create game room (${response.statusCode}).',
    );
  }

  static Future<List<Map<String, dynamic>>> getMyRooms() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/games/rooms'),
      headers: _headers(),
    );
    if (response.statusCode == 200) return _decodeList(response);
    _throwResponseError(response);
  }

  static Future<List<Map<String, dynamic>>> getInvitations() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/games/invitations'),
      headers: _headers(),
    );
    if (response.statusCode == 200) return _decodeList(response);
    _throwResponseError(response);
  }

  static Future<Map<String, dynamic>> getRoom(int roomId) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/games/rooms/$roomId'),
      headers: _headers(),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(
      data['detail']?.toString() ?? 'Could not load game room.',
    );
  }

  static Future<Map<String, dynamic>> acceptInvitation(int roomId) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/games/rooms/$roomId/accept'),
      headers: _headers(),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(
      data['detail']?.toString() ?? 'Could not accept invitation.',
    );
  }

  static Future<void> declineInvitation(int roomId) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/games/rooms/$roomId/decline'),
      headers: _headers(),
    );
    if (response.statusCode == 200) return;
    _throwResponseError(response);
  }

  // Would You Rather gameplay endpoints.
  static Future<Map<String, dynamic>> getWouldYouRatherState(int roomId) async {
    final response = await http.get(
      Uri.parse(
        '${ApiService.baseUrl}/games/rooms/$roomId/would-you-rather',
      ),
      headers: _headers(),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(
      data['detail']?.toString() ?? 'Could not load the game state.',
    );
  }

  static Future<Map<String, dynamic>> startWouldYouRather(int roomId) async {
    final response = await http.post(
      Uri.parse(
        '${ApiService.baseUrl}/games/rooms/$roomId/would-you-rather/start',
      ),
      headers: _headers(),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(
      data['detail']?.toString() ?? 'Could not start the game.',
    );
  }

  static Future<Map<String, dynamic>> submitWouldYouRatherVote({
    required int roomId,
    required String choice,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiService.baseUrl}/games/rooms/$roomId/would-you-rather/vote',
      ),
      headers: _headers(json: true),
      body: jsonEncode({'choice': choice}),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(
      data['detail']?.toString() ?? 'Could not submit your vote.',
    );
  }

  static Future<Map<String, dynamic>> nextWouldYouRatherRound(
    int roomId,
  ) async {
    final response = await http.post(
      Uri.parse(
        '${ApiService.baseUrl}/games/rooms/$roomId/would-you-rather/next',
      ),
      headers: _headers(),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(
      data['detail']?.toString() ?? 'Could not move to the next question.',
    );
  }

  // Friend Trivia gameplay endpoints.
  static Future<Map<String, dynamic>> getFriendTriviaState(int roomId) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/games/rooms/$roomId/friend-trivia'),
      headers: _headers(),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail']?.toString() ?? 'Could not load Friend Trivia.');
  }

  static Future<Map<String, dynamic>> startFriendTrivia(int roomId) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/games/rooms/$roomId/friend-trivia/start'),
      headers: _headers(),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail']?.toString() ?? 'Could not start Friend Trivia.');
  }

  static Future<Map<String, dynamic>> submitFriendTriviaAnswer({
    required int roomId,
    required String choice,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/games/rooms/$roomId/friend-trivia/answer'),
      headers: _headers(json: true),
      body: jsonEncode({'choice': choice}),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail']?.toString() ?? 'Could not submit your answer.');
  }

  static Future<Map<String, dynamic>> submitFriendTriviaGuess({
    required int roomId,
    required String choice,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/games/rooms/$roomId/friend-trivia/guess'),
      headers: _headers(json: true),
      body: jsonEncode({'choice': choice}),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail']?.toString() ?? 'Could not submit your guess.');
  }

  static Future<Map<String, dynamic>> nextFriendTriviaRound(int roomId) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/games/rooms/$roomId/friend-trivia/next'),
      headers: _headers(),
    );
    final data = _decodeObject(response);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail']?.toString() ?? 'Could not move to the next question.');
  }

}
