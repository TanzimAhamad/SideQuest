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
      final decoded = jsonDecode(response.body);

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
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
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
}
