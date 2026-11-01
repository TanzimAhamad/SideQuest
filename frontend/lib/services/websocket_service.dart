
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  Stream<dynamic>? get messages => _channel?.stream;

  // Connect to a particular group.
  Future<void> connect({
    required int groupId,
    required String token,
  }) async {
    await disconnect();

    final apiUri = Uri.parse(ApiService.baseUrl);

    final wsUri = apiUri.replace(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/groups/$groupId',
      queryParameters: {
        'token': token,
      },
    );

    final newChannel = WebSocketChannel.connect(wsUri);

    try {
      await newChannel.ready;
      _channel = newChannel;
    } catch (_) {
      await newChannel.sink.close();
      rethrow;
    }
  }

  // Send a plain-text message to FastAPI.
  void sendMessage(String message) {
    if (_channel == null) {
      throw StateError('WebSocket is not connected.');
    }

    if (message.trim().isEmpty) return;

    _channel!.sink.add(message);
  }

  // Close the connection.
  Future<void> disconnect() async {
    final oldChannel = _channel;
    _channel = null;

    if (oldChannel != null) {
      await oldChannel.sink.close();
    }
  }
}
