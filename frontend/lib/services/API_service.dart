/*this dart file handles communication between flutter and FastAPI. This keeps the existing 
UI codes organized and avoids putting all the API logic inside the login screens*/


import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  //this URL works when Flutter runs in Chrome on the same computer as FastAPI.
  static const String baseUrl = 'http://127.0.0.1:8000';
  static String? accessToken;

  static Map<String, dynamic> _decodeBody(
    http.Response response,
  ) {
    try {
      final decoded = jsonDecode(response.body);   //converts json string to dart

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // The response was not valid JSON.
    }

    return {
      'detail': response.body.isEmpty
          ? 'The server returned an empty response.'
          : response.body,
    };
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(     //await makes the frontend wait for the http response before deciding whether registration succeeded
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({               //converts dart data into a json string
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 201) {
      return data;
    }

    throw Exception(
      data['detail'] ?? 'Registration failed (${response.statusCode}).',
    );
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['detail'] ?? 'Login failed (${response.statusCode}).',
    );
  }

  static Future<Map<String, dynamic>> getMe({
    required String accessToken,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['detail'] ?? 'Profile request failed (${response.statusCode}).',
    );
  }


  
  static Future<List<Map<String, dynamic>>> getMyGroups() async {
    final token = accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/groups/mine'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      throw Exception('Unexpected groups response.');
    }

    final data = _decodeBody(response);

    throw Exception(
      data['detail'] ?? 'Could not load groups.',
    );
  }



 
static Future<List<Map<String, dynamic>>> getGroupMessages(
    int groupId,
) async {
  final token = accessToken;

  if (token == null || token.isEmpty) {
    throw Exception('You are not logged in.');
  }

  final response = await http.get(
    Uri.parse('$baseUrl/groups/$groupId/messages'),
    headers: {
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);

    if (decoded is List) {
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    throw Exception('Unexpected messages response.');
  }

  final data = _decodeBody(response);

  throw Exception(
    data['detail']?.toString() ??
        'Could not load messages.',
  );
}


  // Search users who can be added to this group.
  // The backend excludes the current user and existing group members.
  static Future<List<Map<String, dynamic>>> searchAvailableGroupMembers({
    required int groupId,
    required String query,
  }) async {
    final token = accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final uri = Uri.parse(
      '$baseUrl/groups/$groupId/available-members',
    ).replace(
      queryParameters: {'q': query.trim()},
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      throw Exception('Unexpected user-search response.');
    }

    final data = _decodeBody(response);

    throw Exception(
      data['detail']?.toString() ??
          'Could not search users (${response.statusCode}).',
    );
  }

  // Add one selected user to a group.
  static Future<Map<String, dynamic>> addGroupMember({
    required int groupId,
    required int userId,
  }) async {
    final token = accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/groups/$groupId/members'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'user_id': userId,
      }),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['detail']?.toString() ??
          'Could not add member (${response.statusCode}).',
    );
  }


  // Get usernames for all members of a group.
  static Future<List<Map<String, dynamic>>> getGroupMembers(
    int groupId,
  ) async {
    final token = accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/groups/$groupId/members'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      throw Exception('Unexpected group-members response.');
    }

    final data = _decodeBody(response);

    throw Exception(
      data['detail']?.toString() ??
          'Could not load group members (${response.statusCode}).',
    );
  }




static Future<Map<String, dynamic>> createGroup({
  required String name,
}) async {
  final token = accessToken;

  if (token == null || token.isEmpty) {
    throw Exception('You are not logged in.');
  }

  final response = await http.post(
    Uri.parse('$baseUrl/groups'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'name': name.trim(),
    }),
  );

  final data = _decodeBody(response);

  if (response.statusCode == 201) {
    return data;
  }

  throw Exception(
    data['detail']?.toString() ??
        'Could not create group.',
  );
}


  // Retrieve group details, including the current creator ID.
  static Future<Map<String, dynamic>> getGroupDetails(int groupId) async {
    final token = accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/groups/$groupId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['detail']?.toString() ??
          'Could not load group details (${response.statusCode}).',
    );
  }

  // Creator removes a member from the group.
  static Future<Map<String, dynamic>> removeGroupMember({
    required int groupId,
    required int userId,
  }) async {
    final token = accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/groups/$groupId/members/$userId'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['detail']?.toString() ??
          'Could not remove member (${response.statusCode}).',
    );
  }

  // Current user leaves the group. If they are the creator,
  // the backend transfers ownership to the oldest remaining member.
  static Future<Map<String, dynamic>> leaveGroup(int groupId) async {
    final token = accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/groups/$groupId/leave'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['detail']?.toString() ??
          'Could not leave group (${response.statusCode}).',
    );
  }


  // Search active users by username to start a private conversation.
  static Future<List<Map<String, dynamic>>> searchUsersForPrivateChat(
    String query,
  ) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final uri = Uri.parse('$baseUrl/direct/users/search').replace(
      queryParameters: {'q': query.trim()},
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      throw Exception('Unexpected user-search response.');
    }

    final data = _decodeBody(response);
    throw Exception(
      data['detail']?.toString() ??
          'Could not search users (${response.statusCode}).',
    );
  }

  // Fetch all one-to-one conversations for the logged-in user.
  static Future<List<Map<String, dynamic>>> getDirectConversations() async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/direct/conversations'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      throw Exception('Unexpected private-conversations response.');
    }

    final data = _decodeBody(response);
    throw Exception(
      data['detail']?.toString() ??
          'Could not load private conversations (${response.statusCode}).',
    );
  }

  // Create a conversation if this pair has never chatted; otherwise reuse it.
  static Future<Map<String, dynamic>> getOrCreateDirectConversation(
    int otherUserId,
  ) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/direct/conversations').replace(
        queryParameters: {'other_user_id': otherUserId.toString()},
      ),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = _decodeBody(response);
    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(
      data['detail']?.toString() ??
          'Could not open private conversation (${response.statusCode}).',
    );
  }

  // Load the persistent message history of a private conversation.
  static Future<List<Map<String, dynamic>>> getDirectMessages(
    int conversationId,
  ) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/direct/conversations/$conversationId/messages'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      throw Exception('Unexpected private-message response.');
    }

    final data = _decodeBody(response);
    throw Exception(
      data['detail']?.toString() ??
          'Could not load private messages (${response.statusCode}).',
    );
  }

}
