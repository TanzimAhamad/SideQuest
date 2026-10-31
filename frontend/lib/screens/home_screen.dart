
import 'package:flutter/material.dart';
import 'auth_screen.dart';
import '../services/api_service.dart';
import 'group_chat_screen.dart';
import 'private_chat_screen.dart';

const purple = Color(0xFF8B5CF6);
const darkCard = Color(0xFF1D1E35);

class ChatInfo {
  final String name;
  final String message;
  final bool isGroup;
  final Color color;
  final IconData icon;

  const ChatInfo({
    required this.name,
    required this.message,
    required this.isGroup,
    required this.color,
    required this.icon,
  });
}

const chats = [
  ChatInfo(
    name: 'Sarah',
    message: 'Are we meeting tomorrow?',
    isGroup: false,
    color: Colors.pink,
    icon: Icons.face_3,
  ),
  ChatInfo(
    name: 'Weekend Crew',
    message: 'Ryan: Let us plan Friday!',
    isGroup: true,
    color: purple,
    icon: Icons.groups,
  ),
  ChatInfo(
    name: 'Ryan',
    message: 'Sounds good!',
    isGroup: false,
    color: Colors.blue,
    icon: Icons.face,
  ),
  ChatInfo(
    name: 'The Inner Circle',
    message: 'Maya: Movie night?',
    isGroup: true,
    color: Colors.orange,
    icon: Icons.groups,
  ),
];


class HomeScreen extends StatefulWidget {
  final String displayName;
  final int currentUserId;

  const HomeScreen({
    super.key,
    this.displayName = 'Alex',
    required this.currentUserId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 1;

  List<Map<String, dynamic>> groups = [];

  bool isLoading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadGroups();
  }

  // Fetch groups belonging to the logged-in user.
  Future<void> loadGroups() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await ApiService.getMyGroups();

      if (!mounted) return;

      setState(() {
        groups = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadError = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SideQuest',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F1020),
        actions: [
          if (selectedTab == 1)
            IconButton(
              onPressed: _createGroup,
              icon: const Icon(Icons.add),
              tooltip: 'Create a new group',
            ),
          if (selectedTab == 1)
            IconButton(
              onPressed: loadGroups,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh groups',
            ),
        ],
      ),

      body: selectedTab == 2
          ? buildProfile()
          : selectedTab == 0
              ? PrivateChatsTab(currentUserId: widget.currentUserId)
              : buildGroupList(true),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        backgroundColor: darkCard,
        indicatorColor: purple.withValues(alpha: 0.25),
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Create a new group for the currently logged-in user.
  Future<void> _createGroup() async {
    final controller = TextEditingController();

    final enteredName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Enter group name',
              prefixIcon: Icon(Icons.groups),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(dialogContext, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext, name);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (enteredName == null || enteredName.trim().isEmpty) {
      return;
    }

    try {
      final result = await ApiService.createGroup(
        name: enteredName.trim(),
      );

      if (!mounted) return;

      final newGroupId = (result['id'] as num).toInt();
      final newGroupName =
          result['name']?.toString() ?? enteredName.trim();

      // Refresh the group list so the new group appears immediately.
      await loadGroups();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group created successfully!'),
        ),
      );

      // Open the newly created group chat.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: newGroupId,
            groupName: newGroupName,
            currentUserId: widget.currentUserId,
            canAddMembers: true,
            onStartSideQuest: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SideQuestScreen(
                    groupName: newGroupName,
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Refresh again when the user returns from the chat.
      if (mounted) {
        await loadGroups();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Widget buildGroupList(bool groupsOnly) {
    final heading = groupsOnly
        ? 'Your Groups'
        : 'Group Conversations';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            heading,
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : loadError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(loadError!),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: loadGroups,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  : groups.isEmpty
                      ? const Center(
                          child: Text(
                            'You have not joined any groups yet.',
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: loadGroups,
                          child: ListView.builder(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final group = groups[index];

                              final groupId =
                                  (group['id'] as num).toInt();

                              final groupName =
                                  group['name'].toString();

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 5,
                                ),
                                color: darkCard,
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.all(12),

                                  leading: const CircleAvatar(
                                    radius: 27,
                                    backgroundColor: purple,
                                    child: Icon(
                                      Icons.groups,
                                      color: Colors.white,
                                    ),
                                  ),

                                  title: Text(
                                    groupName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  subtitle: Text(
                                    'Group ID: $groupId • Tap to chat',
                                  ),

                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white54,
                                  ),

                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            GroupChatScreen(
                                          groupId: groupId,
                                          groupName: groupName,
                                          currentUserId:
                                              widget.currentUserId,
                                          canAddMembers: (group['created_by'] as num).toInt() == widget.currentUserId,
                                           onStartSideQuest: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    SideQuestScreen(
                                                  groupName: groupName,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );

                                    if (mounted) {
                                      await loadGroups();
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget buildProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 48,
            backgroundColor: purple,
            child: Icon(Icons.person, size: 48),
          ),

          const SizedBox(height: 18),

          Text(
            widget.displayName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 22),

          ElevatedButton(
            onPressed: () {
              ApiService.accessToken = null;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const AuthScreen(),
                ),
                (_) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}



// ------------------------------
// INDIVIDUAL CHAT SCREEN
// ------------------------------

class ChatScreen extends StatefulWidget {
  final ChatInfo chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();
  final List<String> sentMessages = [];

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  void sendMessage() {
    final message = messageController.text.trim();

    if (message.isEmpty) return;

    setState(() {
      sentMessages.add(message);
      messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat.name),
        backgroundColor: const Color(0xFF17182B),
      ),
      body: Column(
        children: [
          // SideQuest only appears in GROUP chats.
          if (widget.chat.isGroup)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.rocket_launch,
                        color: purple,
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
                        backgroundColor: purple,
                      ),
                      icon: const Icon(Icons.rocket_launch),
                      label: const Text('Start a SideQuest'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SideQuestScreen(
                              groupName: widget.chat.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: darkCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(widget.chat.message),
                  ),
                ),
                const SizedBox(height: 12),
                for (final message in sentMessages)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: purple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(message),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sendMessage,
                  icon: const Icon(
                    Icons.send,
                    color: purple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------
// SIDEQUEST PLANNING SCREEN
// ------------------------------

class SideQuestScreen extends StatefulWidget {
  final String groupName;

  const SideQuestScreen({
    super.key,
    required this.groupName,
  });

  @override
  State<SideQuestScreen> createState() =>
      _SideQuestScreenState();
}

class _SideQuestScreenState extends State<SideQuestScreen> {
  final List<String> activities = [
    'Eating Out',
    'Movies',
    'Shopping',
    'Bowling & Games',
    'Outdoor Activities',
    'Multiple Activities',
  ];

  final Set<String> selectedActivities = {};
  final budgetController = TextEditingController();
  DateTime? selectedDate;

  @override
  void dispose() {
    budgetController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  void createQuest() {
    final budget = budgetController.text.trim();

    if (selectedActivities.isEmpty ||
        selectedDate == null ||
        budget.isEmpty ||
        double.tryParse(budget) == null ||
        double.parse(budget) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose activities, a date, and a valid budget.',
          ),
        ),
      );
      return;
    }

    final date =
        '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SideQuest Created! 🚀'),
        content: Text(
          'Group: ${widget.groupName}\n'
          'Activities: ${selectedActivities.join(", ")}\n'
          'Date: $date\n'
          'Budget: ৳$budget\n\n'
          'This is a frontend-only preview.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Back to Chat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start a SideQuest'),
        backgroundColor: const Color(0xFF17182B),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Icon(
            Icons.rocket_launch,
            color: purple,
            size: 55,
          ),
          const SizedBox(height: 14),
          Text(
            'Plan with ${widget.groupName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'What would you like to do together?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 30),

          const Text(
            'Choose Activities',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: activities.map((activity) {
              return FilterChip(
                label: Text(activity),
                selected: selectedActivities.contains(activity),
                selectedColor: purple,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedActivities.add(activity);
                    } else {
                      selectedActivities.remove(activity);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 30),
          const Text(
            'Choose Date',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              selectedDate == null
                  ? 'Select a date'
                  : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
            ),
          ),

          const SizedBox(height: 30),
          const Text(
            'Estimated Budget (৳)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: budgetController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              hintText: 'e.g. 1500 per person',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),

          const SizedBox(height: 36),

          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
              ),
              onPressed: createQuest,
              child: const Text(
                'Create SideQuest',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
