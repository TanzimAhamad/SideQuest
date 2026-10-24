
import 'package:flutter/material.dart';
import 'auth_screen.dart';

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

  const HomeScreen({
    super.key,
    this.displayName = 'Alex',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SideQuest',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F1020),
      ),
      body: selectedTab == 2
          ? buildProfile()
          : buildChatList(selectedTab == 1),
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

  Widget buildChatList(bool groupsOnly) {
    final visibleChats = chats
        .where((chat) => !groupsOnly || chat.isGroup)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(22),
          child: Text(
            groupsOnly ? 'Your Groups' : 'Messages',
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: visibleChats.length,
            itemBuilder: (context, index) {
              final chat = visibleChats[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                color: darkCard,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    radius: 27,
                    backgroundColor: chat.color,
                    child: Icon(chat.icon, color: Colors.white),
                  ),
                  title: Text(
                    chat.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    chat.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white54,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(chat: chat),
                      ),
                    );
                  },
                ),
              );
            },
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
