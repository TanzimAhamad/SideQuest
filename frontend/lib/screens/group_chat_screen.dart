
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/websocket_service.dart';

const Color chatPurple = Color(0xFF8B5CF6);
const Color chatDarkCard = Color(0xFF1D1E35);

class GroupChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final int currentUserId;
  final VoidCallback onStartSideQuest;
  final bool canAddMembers;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
    required this.onStartSideQuest,
    this.canAddMembers = false,
  });

  @override
  State<GroupChatScreen> createState() =>
      _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final WebSocketService webSocketService =
      WebSocketService();

  StreamSubscription<dynamic>? messageSubscription;

  List<Map<String, dynamic>> messages = [];

  // Maps each sender's database ID to their username.
  Map<int, String> memberNames = {};
  List<Map<String, dynamic>> groupMembers = [];
  int? groupCreatorId;
  bool isGroupCreator = false;
  bool isLeavingGroup = false;

  bool isLoadingHistory = true;
  bool isConnecting = true;
  bool isConnected = false;

  String? historyError;
  String? connectionError;

  @override
  void initState() {
    super.initState();
    isGroupCreator = widget.canAddMembers;
    initializeChat();
  }

  // Load group permissions, members, old messages, then connect WebSocket.
  Future<void> initializeChat() async {
    await loadGroupDetails();
    await loadGroupMembers();
    await loadMessages();
    await connectWebSocket();
  }

  Future<void> loadGroupDetails() async {
    try {
      final details = await ApiService.getGroupDetails(widget.groupId);
      if (!mounted) return;

      final creatorId = (details['created_by'] as num).toInt();
      setState(() {
        groupCreatorId = creatorId;
        isGroupCreator = creatorId == widget.currentUserId;
      });
    } catch (e) {
      debugPrint('Could not load group details: $e');
    }
  }

  // Load group members and the usernames used in message bubbles.
  Future<void> loadGroupMembers() async {
    try {
      final members = await ApiService.getGroupMembers(widget.groupId);
      if (!mounted) return;

      setState(() {
        groupMembers = members;
        memberNames = {
          for (final member in members)
            (member['user_id'] as num).toInt():
                member['username']?.toString() ?? 'Unknown user',
        };
      });
    } catch (e) {
      debugPrint('Could not load group members: $e');
    }
  }

  // Retrieve previous messages from PostgreSQL.
  Future<void> loadMessages() async {
    try {
      final result = await ApiService.getGroupMessages(
        widget.groupId,
      );

      if (!mounted) return;

      setState(() {
        messages = result;
        historyError = null;
      });

      scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        historyError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingHistory = false;
        });
      }
    }
  }

  // Establish the authenticated WebSocket connection.
  Future<void> connectWebSocket() async {
    if (mounted) {
      setState(() {
        isConnecting = true;
        connectionError = null;
      });
    }

    try {
      final token = ApiService.accessToken;

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found.');
      }

      await webSocketService.connect(
        groupId: widget.groupId,
        token: token,
      );

      if (!mounted) {
        await webSocketService.disconnect();
        return;
      }

      final stream = webSocketService.messages;

      if (stream == null) {
        throw Exception('WebSocket stream unavailable.');
      }

      messageSubscription = stream.listen(
        handleIncomingMessage,
        onError: (error) {
          if (!mounted) return;

          setState(() {
            isConnected = false;
            connectionError = error.toString();
          });
        },
        onDone: () {
          if (!mounted) return;

          setState(() {
            isConnected = false;
          });
        },
      );

      setState(() {
        isConnected = true;
        isConnecting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isConnected = false;
        isConnecting = false;
        connectionError = e.toString();
      });
    }
  }

  // Receive and decode messages broadcast by FastAPI.
  void handleIncomingMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data.toString());

      if (decoded is! Map) return;

      final incomingMessage =
          Map<String, dynamic>.from(decoded);

      if (incomingMessage['error'] != null) {
        showError(incomingMessage['error'].toString());
        return;
      }

      final eventType = incomingMessage['type']?.toString();

      if (eventType == 'group_deleted') {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          const SnackBar(content: Text('This group was deleted.')),
        );
        return;
      }

      if (eventType == 'group_ownership_changed') {
        final newCreatorId = incomingMessage['new_creator_id'];
        if (newCreatorId is num && mounted) {
          final becameCreator =
              newCreatorId.toInt() == widget.currentUserId;
          setState(() {
            groupCreatorId = newCreatorId.toInt();
            isGroupCreator = becameCreator;
          });
          unawaited(loadGroupMembers());
          if (becameCreator) {
            showError('You are now the group creator.');
          }
        }
        return;
      }

      if (eventType == 'group_member_removed' ||
          eventType == 'group_member_left') {
        final affectedUserId = incomingMessage['user_id'];
        if (affectedUserId is num &&
            affectedUserId.toInt() != widget.currentUserId) {
          unawaited(loadGroupMembers());
        }
        if (eventType == 'group_member_removed' &&
            affectedUserId is num &&
            affectedUserId.toInt() == widget.currentUserId) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop(true);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('You were removed from this group.'),
            ),
          );
        }
        return;
      }

      // Avoid displaying the same message twice.
      final incomingId = incomingMessage['id'];

      if (incomingId != null &&
          messages.any((m) => m['id'] == incomingId)) {
        return;
      }

      setState(() {
        messages.add(incomingMessage);
      });

      scrollToBottom();
    } catch (e) {
      debugPrint('Message decoding error: $e');
    }
  }

  // Send a message through WebSocket.
  void sendMessage() {
    final message = messageController.text.trim();

    if (message.isEmpty) return;

    if (!isConnected) {
      showError('You are not connected to the chat.');
      return;
    }

    try {
      webSocketService.sendMessage(message);
      messageController.clear();
    } catch (e) {
      showError('Message could not be sent: $e');
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String formatTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return '';

    final local = date.toLocal();

    final hour = local.hour % 12 == 0
        ? 12
        : local.hour % 12;

    final minute =
        local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  // Build an individual message bubble.
  Widget buildMessageBubble(
    Map<String, dynamic> message,
  ) {
    final senderId = message['sender_id'] is num
        ? (message['sender_id'] as num).toInt()
        : -1;

    final isMine = senderId == widget.currentUserId;

    final content = message['message']?.toString() ?? '';

    final time = formatTime(message['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMine
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width * 0.72,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isMine ? chatPurple : chatDarkCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      memberNames[senderId] ?? 'Unknown user',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),

                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSideQuestBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: chatDarkCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.rocket_launch,
                color: chatPurple,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plan something together?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Stop debating and start planning '
            'your next adventure!',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: chatPurple,
              ),
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Start a SideQuest'),
              onPressed: widget.onStartSideQuest,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildConnectionStatus() {
    if (isConnected) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      color: chatDarkCard,
      child: Row(
        children: [
          Expanded(
            child: Text(
              isConnecting
                  ? 'Connecting to group...'
                  : 'Connection unavailable',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          if (!isConnecting)
            TextButton(
              onPressed: connectWebSocket,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }


  Future<void> openAddMembersDialog() async {
    final result = await showDialog<_AddMembersResult>(
      context: context,
      builder: (dialogContext) {
        return _AddMembersDialog(
          groupId: widget.groupId,
        );
      },
    );

    if (!mounted || result == null) return;

    if (result.addedCount > 0) {
      await loadGroupMembers();

      var message =
          '${result.addedCount} member(s) added successfully.';

      if (result.failedUsernames.isNotEmpty) {
        message +=
            ' Could not add: ${result.failedUsernames.join(", ")}';
      }

      showError(message);
    } else if (result.failedUsernames.isNotEmpty) {
      showError(
        'Could not add: ${result.failedUsernames.join(", ")}',
      );
    }
  }

  Future<void> openGroupMembersDialog({bool allowRemoval = false}) async {
    await loadGroupMembers();
    if (!mounted) return;

    final dialogMembers = List<Map<String, dynamic>>.from(groupMembers);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(allowRemoval ? 'Manage Members' : 'Group Members'),
              content: SizedBox(
                width: 420,
                height: 420,
                child: dialogMembers.isEmpty
                    ? const Center(child: Text('No members found.'))
                    : ListView.separated(
                        itemCount: dialogMembers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final member = dialogMembers[index];
                          final memberId =
                              (member['user_id'] as num).toInt();
                          final username =
                              member['username']?.toString() ?? 'Unknown user';
                          final email = member['email']?.toString() ?? '';
                          final isCreator = memberId == groupCreatorId;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: chatPurple,
                              child: Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(username),
                            subtitle: Text(
                              isCreator ? 'Group creator' : email,
                            ),
                            trailing: allowRemoval &&
                                    isGroupCreator &&
                                    memberId != widget.currentUserId
                                ? IconButton(
                                    tooltip: 'Remove $username',
                                    icon: const Icon(
                                      Icons.person_remove_alt_1,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      final confirmed =
                                          await showDialog<bool>(
                                        context: dialogContext,
                                        builder: (confirmContext) =>
                                            AlertDialog(
                                          title: const Text('Remove member?'),
                                          content: Text(
                                            'Remove $username from this group?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(confirmContext, false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(confirmContext, true),
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed != true) return;

                                      try {
                                        await ApiService.removeGroupMember(
                                          groupId: widget.groupId,
                                          userId: memberId,
                                        );

                                        if (!dialogContext.mounted) return;
                                        setDialogState(() {
                                          dialogMembers.removeWhere(
                                            (item) =>
                                                (item['user_id'] as num)
                                                    .toInt() == memberId,
                                          );
                                        });
                                        await loadGroupMembers();
                                        showError('$username was removed.');
                                      } catch (e) {
                                        showError(
                                          e.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                        );
                                      }
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> confirmLeaveGroup() async {
    if (isLeavingGroup) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave group?'),
        content: Text(
          isGroupCreator
              ? 'You are the group creator. Ownership will transfer to the oldest remaining member. If you are the only member, the group and its messages will be deleted.'
              : 'You will no longer receive messages from this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave group'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => isLeavingGroup = true);

    try {
      final result = await ApiService.leaveGroup(widget.groupId);
      await messageSubscription?.cancel();
      messageSubscription = null;
      await webSocketService.disconnect();

      if (!mounted) return;

      final wasDeleted = result['deleted'] == true;
      final newCreatorName = result['new_creator_username']?.toString();
      final message = wasDeleted
          ? 'Group deleted because you were the last member.'
          : newCreatorName != null
              ? 'You left the group. Ownership transferred to $newCreatorName.'
              : 'You left the group successfully.';

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => isLeavingGroup = false);
      showError(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: const Color(0xFF17182B),
        actions: [
          if (isGroupCreator)
            IconButton(
              tooltip: 'Add members',
              icon: const Icon(
                Icons.add,
                color: Colors.white,
                size: 28,
              ),
              onPressed: openAddMembersDialog,
            ),
          PopupMenuButton<String>(
            tooltip: 'Group options',
            onSelected: (value) {
              if (value == 'view_members') {
                unawaited(openGroupMembersDialog());
              } else if (value == 'manage_members') {
                unawaited(openGroupMembersDialog(allowRemoval: true));
              } else if (value == 'leave_group') {
                unawaited(confirmLeaveGroup());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'view_members',
                child: Row(
                  children: [
                    Icon(Icons.people_outline),
                    SizedBox(width: 10),
                    Text('View members'),
                  ],
                ),
              ),
              if (isGroupCreator)
                const PopupMenuItem<String>(
                  value: 'manage_members',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_alt_1),
                      SizedBox(width: 10),
                      Text('Remove members'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'leave_group',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text(
                      'Leave group',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          buildConnectionStatus(),

          buildSideQuestBanner(),

          if (historyError != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Could not load previous messages: $historyError',
                style: const TextStyle(color: Colors.orange),
              ),
            ),

          Expanded(
            child: isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return buildMessageBubble(
                            messages[index],
                          );
                        },
                      ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    enabled: isConnected && !isLeavingGroup,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isConnected && !isLeavingGroup ? sendMessage : null,
                  icon: const Icon(
                    Icons.send,
                    color: chatPurple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    final subscription = messageSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    unawaited(webSocketService.disconnect());

    messageController.dispose();
    scrollController.dispose();

    super.dispose();
  }
}


class _AddMembersResult {
  final int addedCount;
  final List<String> failedUsernames;

  const _AddMembersResult({
    required this.addedCount,
    required this.failedUsernames,
  });
}

class _AddMembersDialog extends StatefulWidget {
  final int groupId;

  const _AddMembersDialog({
    super.key,
    required this.groupId,
  });

  @override
  State<_AddMembersDialog> createState() =>
      _AddMembersDialogState();
}

class _AddMembersDialogState extends State<_AddMembersDialog> {
  final TextEditingController _searchController =
      TextEditingController();

  final Map<int, Map<String, dynamic>> _selectedUsers = {};

  List<Map<String, dynamic>> _results = [];

  Timer? _debounce;

  bool _isSearching = false;
  bool _isAdding = false;
  bool _hasSearched = false;

  String? _error;

  // Wait briefly after typing before sending the search request.
  void _handleSearchChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();

    setState(() {
      _error = null;
      _hasSearched = query.isNotEmpty;
      _results = [];
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) return;

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchUsers(query),
    );
  }

  // Retrieve matching users from FastAPI.
  Future<void> _searchUsers(String query) async {
    try {
      final users =
          await ApiService.searchAvailableGroupMembers(
        groupId: widget.groupId,
        query: query,
      );

      if (!mounted || _searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _results = users;
      });
    } catch (e) {
      if (!mounted || _searchController.text.trim() != query) {
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _results = [];
      });
    } finally {
      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // Select or unselect a user.
  void _toggleUser(Map<String, dynamic> user) {
    if (_isAdding) return;

    final userId = (user['user_id'] as num).toInt();

    setState(() {
      if (_selectedUsers.containsKey(userId)) {
        _selectedUsers.remove(userId);
      } else {
        _selectedUsers[userId] = user;
      }
    });
  }

  // Submit all selected users. Each request uses the existing backend endpoint.
  Future<void> _addSelectedUsers() async {
    if (_selectedUsers.isEmpty || _isAdding) return;

    setState(() {
      _isAdding = true;
    });

    var addedCount = 0;
    final failedUsernames = <String>[];
    final selectedUsers = _selectedUsers.values.toList();

    for (final user in selectedUsers) {
      final userId = (user['user_id'] as num).toInt();
      final username =
          user['username']?.toString() ?? 'Unknown user';

      try {
        await ApiService.addGroupMember(
          groupId: widget.groupId,
          userId: userId,
        );
        addedCount++;
      } catch (_) {
        failedUsernames.add(username);
      }
    }

    if (!mounted) return;

    Navigator.of(context).pop(
      _AddMembersResult(
        addedCount: addedCount,
        failedUsernames: failedUsernames,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Start typing a name to find users.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No matching users found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _results[index];
        final userId = (user['user_id'] as num).toInt();
        final username =
            user['username']?.toString() ?? 'Unknown';
        final email = user['email']?.toString() ?? '';
        final isSelected = _selectedUsers.containsKey(userId);

        return ListTile(
          enabled: !_isAdding,
          leading: CircleAvatar(
            backgroundColor: chatPurple,
            child: Text(
              username.isNotEmpty
                  ? username[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(username),
          subtitle: email.isEmpty ? null : Text(email),
          trailing: Icon(
            isSelected
                ? Icons.check_circle
                : Icons.add_circle_outline,
            color: isSelected ? Colors.greenAccent : chatPurple,
          ),
          onTap: () => _toggleUser(user),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Group Members'),
      content: SizedBox(
        width: 420,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              enabled: !_isAdding,
              onChanged: _handleSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _handleSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 15),
            if (_selectedUsers.isNotEmpty) ...[
              Text(
                'Selected (${_selectedUsers.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedUsers.entries.map((entry) {
                  final username =
                      entry.value['username'].toString();

                  return InputChip(
                    label: Text(username),
                    onDeleted: _isAdding
                        ? null
                        : () {
                            setState(() {
                              _selectedUsers.remove(entry.key);
                            });
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            const Divider(),
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isAdding ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedUsers.isEmpty || _isAdding
              ? null
              : _addSelectedUsers,
          child: _isAdding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Add ${_selectedUsers.length}'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

