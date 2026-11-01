import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

/// WebSocket client for one-to-one private conversations.
/// Group chat continues using the existing WebSocketService.
class PrivateChatService {
  WebSocketChannel? _channel;

  Stream<dynamic>? get messages => _channel?.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({required int conversationId}) async {
    final token = ApiService.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('You are not logged in.');
    }

    final baseUri = Uri.parse(ApiService.baseUrl);
    final socketUri = baseUri.replace(
      scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/private/$conversationId',
      queryParameters: {'token': token},
    );

    final channel = WebSocketChannel.connect(socketUri);
    _channel = channel;
    await channel.ready;
  }

  void sendMessage(String message) {
    final channel = _channel;
    if (channel == null) {
      throw Exception('Private chat is not connected.');
    }
    channel.sink.add(message);
  }

  Future<void> disconnect() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await channel.sink.close();
    }
  }
}
