import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/private_chat_service.dart';

const Color privateChatPurple = Color(0xFF8B5CF6);
const Color privateChatDarkCard = Color(0xFF1D1E35);

/// Main content for the Chats tab: recent private conversations and user search.
class PrivateChatsTab extends StatefulWidget {
  final int currentUserId;

  const PrivateChatsTab({
    super.key,
    required this.currentUserId,
  });

  @override
  State<PrivateChatsTab> createState() => _PrivateChatsTabState();
}

class _PrivateChatsTabState extends State<PrivateChatsTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _searchResults = [];

  bool _isLoadingConversations = true;
  bool _isSearching = false;
  int? _openingUserId;
  String? _conversationError;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (mounted) {
      setState(() {
        _isLoadingConversations = true;
        _conversationError = null;
      });
    }

    try {
      final result = await ApiService.getDirectConversations();
      if (!mounted) return;
      setState(() {
        _conversations = result;
        _isLoadingConversations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conversationError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingConversations = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _searchTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final result = await ApiService.searchUsersForPrivateChat(query);
        if (!mounted || _searchController.text.trim() != query) return;
        setState(() {
          _searchResults = result;
          _isSearching = false;
        });
      } catch (e) {
        if (!mounted || _searchController.text.trim() != query) return;
        setState(() {
          _searchError = e.toString().replaceFirst('Exception: ', '');
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _openUser(Map<String, dynamic> user) async {
    final otherUserId = (user['user_id'] as num).toInt();
    final username = user['username']?.toString() ?? 'User';

    setState(() => _openingUserId = otherUserId);
    try {
      final conversation =
          await ApiService.getOrCreateDirectConversation(otherUserId);

      if (!mounted) return;

      _searchController.clear();
      setState(() {
        _searchResults = [];
        _searchError = null;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrivateChatScreen(
            conversationId: (conversation['id'] as num).toInt(),
            currentUserId: widget.currentUserId,
            otherUsername:
                conversation['other_username']?.toString() ?? username,
          ),
        ),
      );

      if (mounted) await _loadConversations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingUserId = null);
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          conversationId: (conversation['id'] as num).toInt(),
          currentUserId: widget.currentUserId,
          otherUsername: conversation['other_username']?.toString() ?? 'User',
        ),
      ),
    );

    if (mounted) await _loadConversations();
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return '';

    final now = DateTime.now();
    final sameDay = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (sameDay) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildUserSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return Center(child: Text(_searchError!));
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No matching users found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final userId = (user['user_id'] as num).toInt();
        final username = user['username']?.toString() ?? 'User';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: privateChatPurple.withValues(alpha: 0.25),
            child: Text(
              username.isEmpty ? '?' : username[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(username),
          subtitle: const Text('Start a private conversation'),
          trailing: _openingUserId == userId
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _openingUserId == null ? () => _openUser(user) : null,
        );
      },
    );
  }

  Widget _buildConversationList() {
    if (_isLoadingConversations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversationError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(child: Text(_conversationError!)),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _loadConversations,
              child: const Text('Try Again'),
            ),
          ),
        ],
      );
    }
    if (_conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white38),
          SizedBox(height: 12),
          Center(
            child: Text(
              'No private conversations yet.\nSearch for someone above to start chatting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final username =
            conversation['other_username']?.toString() ?? 'User';
        final lastMessage = conversation['last_message']?.toString() ?? '';
        final lastSenderId = conversation['last_sender_id'];
        final preview = lastMessage.isEmpty
            ? 'Start a conversation'
            : (lastSenderId != null &&
                    (lastSenderId as num).toInt() == widget.currentUserId
                ? 'You: $lastMessage'
                : lastMessage);

        return Card(
          color: privateChatDarkCard,
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 5,
            ),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: privateChatPurple.withValues(alpha: 0.25),
              child: Text(
                username.isEmpty ? '?' : username[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              username,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Text(
              _formatTime(conversation['last_message_at']),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: () => _openConversation(conversation),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Text(
            'Chats',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              hintText: 'Search people by username...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
              filled: true,
              fillColor: privateChatDarkCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: hasSearch
              ? _buildUserSearchResults()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: _buildConversationList(),
                ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

/// Real-time one-to-one conversation screen.
class PrivateChatScreen extends StatefulWidget {
  final int conversationId;
  final int currentUserId;
  final String otherUsername;

  const PrivateChatScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.otherUsername,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PrivateChatService _socket = PrivateChatService();

  StreamSubscription<dynamic>? _messageSubscription;
  final Map<int, Map<String, dynamic>> _messagesById = {};

  List<Map<String, dynamic>> get _messages {
    final result = _messagesById.values.toList();
    result.sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final compare = aTime.compareTo(bTime);
      if (compare != 0) return compare;
      return ((a['id'] as num?)?.toInt() ?? 0)
          .compareTo((b['id'] as num?)?.toInt() ?? 0);
    });
    return result;
  }

  bool _isLoadingHistory = true;
  bool _isConnecting = true;
  bool _isConnected = false;
  String? _historyError;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _connectWebSocket();
    await _loadMessages();
  }

  Future<void> _connectWebSocket() async {
    if (!mounted) return;
    setState(() {
      _isConnecting = true;
      _connectionError = null;
    });

    await _messageSubscription?.cancel();
    try {
      await _socket.connect(conversationId: widget.conversationId);
      if (!mounted) {
        await _socket.disconnect();
        return;
      }
      final stream = _socket.messages;
      if (stream == null) {
        throw Exception('Private chat stream is unavailable.');
      }

      _messageSubscription = stream.listen(
        _handleIncomingMessage,
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _isConnected = false;
            _connectionError = error.toString();
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isConnected = false;
            _connectionError = 'The private chat connection was closed.';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isConnected = true;
        _isConnecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _connectionError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMessages() async {
    if (mounted) setState(() => _isLoadingHistory = true);
    try {
      final history = await ApiService.getDirectMessages(
        widget.conversationId,
      );
      if (!mounted) return;

      setState(() {
        for (final message in history) {
          final id = (message['id'] as num).toInt();
          _messagesById[id] = message;
        }
        _historyError = null;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingHistory = false;
      });
    }
  }

  void _handleIncomingMessage(dynamic event) {
    try {
      final decoded = jsonDecode(event.toString());
      if (decoded is! Map) return;

      if (decoded['error'] != null) {
        if (!mounted) return;
        setState(() => _connectionError = decoded['error'].toString());
        return;
      }

      final message = Map<String, dynamic>.from(decoded);
      if (message['id'] == null) return;

      if (!mounted) return;
      setState(() {
        final id = (message['id'] as num).toInt();
        _messagesById[id] = message;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Could not parse private chat message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to private chat.')),
      );
      return;
    }

    try {
      _socket.sendMessage(text);
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String _formatMessageTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final senderId = (message['sender_id'] as num).toInt();
    final isMine = senderId == widget.currentUserId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? privateChatPurple : privateChatDarkCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['message']?.toString() ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message['created_at']),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: privateChatPurple.withValues(alpha: 0.25),
              child: Text(
                widget.otherUsername.isEmpty
                    ? '?'
                    : widget.otherUsername[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUsername,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isConnected && !_isConnecting)
            IconButton(
              onPressed: _connectWebSocket,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_connectionError != null)
            Container(
              width: double.infinity,
              color: Colors.orange.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                _connectionError!,
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ),
          Expanded(
            child: _isLoadingHistory && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _historyError != null && messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_historyError!),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _loadMessages,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : messages.isEmpty
                        ? const Center(
                            child: Text(
                              'Say hello to start the conversation.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            itemCount: messages.length,
                            itemBuilder: (context, index) =>
                                _buildMessageBubble(messages[index]),
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: privateChatDarkCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    onPressed: _isConnected ? _sendMessage : null,
                    icon: const Icon(Icons.send, color: privateChatPurple),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    unawaited(_socket.disconnect());
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
