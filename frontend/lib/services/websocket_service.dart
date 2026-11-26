
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

//this is the main class responsible for the websocket communication
class WebSocketService {
  WebSocketChannel? _channel;

  Stream<dynamic>? get messages => _channel?.stream;  //provides a stream thru which incoming messages can be received


  //the connect method firstly closes any prevv websocket connection, gets a backend url, creates that url using the group ID, checks for jwt authentication 
  //establishes websocket connection for a particular group and waits until it is ready
  Future<void> connect({
    required int groupId,
    required String token,
  }) async {
    await disconnect();

    final apiUri = Uri.parse(ApiService.baseUrl);

    final wsUri = apiUri.replace(
      scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',   //ws-websocket connection & wss- secure ewebsocket connection
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

  //checks if the websocket is coonnected, prevents empty message from being sent
  void sendMessage(String message) {
    if (_channel == null) {
      throw StateError('WebSocket is not connected.');
    }

    if (message.trim().isEmpty) return;
//sends message to fastapi backend
    _channel!.sink.add(message);
  }

  // Close the connection when the user leaves the chat 
  Future<void> disconnect() async {
    final oldChannel = _channel;
    _channel = null;

    if (oldChannel != null) {
      await oldChannel.sink.close();
    }
  }
}
