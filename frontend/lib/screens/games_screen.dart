import 'package:flutter/material.dart';

import '../services/games_service.dart';
import 'would_you_rather_screen.dart';
import 'friend_trivia_screen.dart';

const _gamesPurple = Color(0xFF8B5CF6);
const _gamesCard = Color(0xFF1D1E35);

class GamesScreen extends StatefulWidget {
  final int currentUserId;

  const GamesScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> invitations = [];
  bool isLoading = true;
  String? loadError;
  final Set<int> busyInvitationIds = {};

  @override
  void initState() {
    super.initState();
    loadGames();
  }

  Future<void> loadGames() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final results = await Future.wait([
        GamesService.getMyRooms(),
        GamesService.getInvitations(),
      ]);

      if (!mounted) return;
      setState(() {
        rooms = results[0];
        invitations = results[1];
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = error.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> openCreateRoom({String initialGameType = 'would_you_rather'}) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGameRoomScreen(initialGameType: initialGameType),
      ),
    );
    if (created == true && mounted) await loadGames();
  }

  Future<void> respondToInvitation(int roomId, {required bool accept}) async {
    setState(() => busyInvitationIds.add(roomId));
    try {
      if (accept) {
        await GamesService.acceptInvitation(roomId);
      } else {
        await GamesService.declineInvitation(roomId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Invitation accepted.' : 'Invitation declined.'),
        ),
      );
      await loadGames();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => busyInvitationIds.remove(roomId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadGames,
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Center(child: Text(loadError!)),
                    const SizedBox(height: 12),
                    Center(
                      child: FilledButton(
                        onPressed: loadGames,
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                  children: [
                    const Text(
                      'Games',
                      style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Play with friends, even when they are not in your groups.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    _GameFeatureCard(
                      title: 'Friend Trivia',
                      subtitle: 'Find out who knows you best.',
                      icon: Icons.quiz_outlined,
                      color: const Color(0xFF6D5CE8),
                      onTap: () => openCreateRoom(initialGameType: 'friend_trivia'),
                    ),
                    const SizedBox(height: 12),
                    _GameFeatureCard(
                      title: 'Would You Rather',
                      subtitle: 'Choose between two impossible options.',
                      icon: Icons.compare_arrows,
                      color: const Color(0xFF0E9F9A),
                      onTap: () => openCreateRoom(initialGameType: 'would_you_rather'),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Game invitations',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('${invitations.length}', style: const TextStyle(color: Colors.white60)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (invitations.isEmpty)
                      const _EmptyMessage(message: 'No pending invitations.')
                    else
                      ...invitations.map(_buildInvitationCard),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your game rooms',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: loadGames,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh game rooms',
                        ),
                      ],
                    ),
                    if (rooms.isEmpty)
                      const _EmptyMessage(message: 'You have not joined any game rooms yet.')
                    else
                      ...rooms.map(_buildRoomCard),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => openCreateRoom(),
                      icon: const Icon(Icons.add),
                      label: const Text('Create a game room'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gamesPurple,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invitation) {
    final roomId = (invitation['id'] as num).toInt();
    final isBusy = busyInvitationIds.contains(roomId);
    return Card(
      color: _gamesCard,
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invitation['title']?.toString() ?? 'Game room',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              '${_gameName(invitation['game_type'])} • invited by ${invitation['host_username']}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : () => respondToInvitation(roomId, accept: false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isBusy ? null : () => respondToInvitation(roomId, accept: true),
                    style: FilledButton.styleFrom(backgroundColor: _gamesPurple),
                    child: isBusy
                        ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final roomId = (room['id'] as num).toInt();
    final participants = (room['participant_count'] as num?)?.toInt() ?? 1;
    return Card(
      color: _gamesCard,
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _gamesPurple.withValues(alpha: 0.2),
          child: Icon(_gameIcon(room['game_type']), color: _gamesPurple),
        ),
        title: Text(room['title']?.toString() ?? 'Game room'),
        subtitle: Text(
          '${_gameName(room['game_type'])} • $participants joined • ${room['status']}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final gameType = room['game_type']?.toString();
          final Widget destination = gameType == 'would_you_rather'
              ? WouldYouRatherGameScreen(roomId: roomId)
              : gameType == 'friend_trivia'
                  ? FriendTriviaGameScreen(roomId: roomId)
                  : GameRoomDetailsScreen(roomId: roomId);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          ).then((_) => loadGames());
        },
      ),
    );
  }
}

class CreateGameRoomScreen extends StatefulWidget {
  final String initialGameType;

  const CreateGameRoomScreen({
    super.key,
    this.initialGameType = 'would_you_rather',
  });

  @override
  State<CreateGameRoomScreen> createState() => _CreateGameRoomScreenState();
}

class _CreateGameRoomScreenState extends State<CreateGameRoomScreen> {
  final titleController = TextEditingController();
  final searchController = TextEditingController();
  late String gameType = widget.initialGameType;
  int maxPlayers = 8;
  List<Map<String, dynamic>> searchResults = [];
  final List<String> selectedUsernames = [];
  bool isSearching = false;
  bool isCreating = false;
  String? errorMessage;

  @override
  void dispose() {
    titleController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchUsers() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      isSearching = true;
      errorMessage = null;
    });
    try {
      final results = await GamesService.searchUsers(query: query);
      if (!mounted) return;
      setState(() {
        searchResults = results;
        isSearching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
        isSearching = false;
      });
    }
  }

  void toggleUsername(String username) {
    setState(() {
      if (selectedUsernames.contains(username)) {
        selectedUsernames.remove(username);
      } else if (selectedUsernames.length < maxPlayers - 1) {
        selectedUsernames.add(username);
      } else {
        errorMessage = 'Your room can invite at most ${maxPlayers - 1} players.';
      }
    });
  }

  Future<void> createRoom() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() => errorMessage = 'Enter a room name.');
      return;
    }
    if (selectedUsernames.isEmpty) {
      setState(() => errorMessage = 'Search and select at least one player by username.');
      return;
    }

    setState(() {
      isCreating = true;
      errorMessage = null;
    });
    try {
      await GamesService.createRoom(
        gameType: gameType,
        title: title,
        invitedUsernames: selectedUsernames,
        maxPlayers: maxPlayers,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
        isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create game room')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Choose a game', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: gameType,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.sports_esports)),
            items: const [
              DropdownMenuItem(value: 'would_you_rather', child: Text('Would You Rather')),
              DropdownMenuItem(value: 'friend_trivia', child: Text('Friend Trivia')),
            ],
            onChanged: isCreating ? null : (value) => setState(() => gameType = value ?? gameType),
          ),
          const SizedBox(height: 18),
          const Text('Room name', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: titleController,
            maxLength: 100,
            decoration: const InputDecoration(hintText: 'e.g. Friday Game Night'),
          ),
          const SizedBox(height: 10),
          const Text('Maximum players', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: maxPlayers,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.people_outline)),
            items: [2, 3, 4, 5, 6, 8, 10, 12, 16, 20]
                .map((count) => DropdownMenuItem(value: count, child: Text('$count players')))
                .toList(),
            onChanged: isCreating
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      maxPlayers = value;
                      if (selectedUsernames.length > maxPlayers - 1) {
                        selectedUsernames.removeRange(maxPlayers - 1, selectedUsernames.length);
                      }
                    });
                  },
          ),
          const SizedBox(height: 20),
          const Text('Invite players by username', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onSubmitted: (_) => searchUsers(),
                  decoration: const InputDecoration(
                    hintText: 'Search registered users',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: isSearching ? null : searchUsers,
                icon: isSearching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
              ),
            ],
          ),
          if (selectedUsernames.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Selected players'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 5,
              children: selectedUsernames
                  .map((username) => InputChip(
                        label: Text(username),
                        onDeleted: isCreating ? null : () => toggleUsername(username),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          if (searchResults.isNotEmpty)
            ...searchResults.map((user) {
              final username = user['username'].toString();
              final selected = selectedUsernames.contains(username);
              return Card(
                color: _gamesCard,
                child: ListTile(
                  leading: CircleAvatar(child: Text(username.substring(0, 1).toUpperCase())),
                  title: Text(username),
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.add_circle_outline,
                    color: selected ? Colors.greenAccent : Colors.white70,
                  ),
                  onTap: isCreating ? null : () => toggleUsername(username),
                ),
              );
            }),
          if (searchResults.isEmpty && searchController.text.trim().isNotEmpty && !isSearching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No matching active users found.', style: TextStyle(color: Colors.white60)),
            ),
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isCreating ? null : createRoom,
            icon: isCreating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(isCreating ? 'Creating...' : 'Create room and send invitations'),
            style: FilledButton.styleFrom(
              backgroundColor: _gamesPurple,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class GameRoomDetailsScreen extends StatefulWidget {
  final int roomId;

  const GameRoomDetailsScreen({super.key, required this.roomId});

  @override
  State<GameRoomDetailsScreen> createState() => _GameRoomDetailsScreenState();
}

class _GameRoomDetailsScreenState extends State<GameRoomDetailsScreen> {
  Map<String, dynamic>? room;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRoom();
  }

  Future<void> loadRoom() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await GamesService.getRoom(widget.roomId);
      if (!mounted) return;
      setState(() {
        room = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game room')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : RefreshIndicator(
                  onRefresh: loadRoom,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Text(room!['title'].toString(), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('${_gameName(room!['game_type'])} • ${room!['status']}', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text('Hosted by ${room!['host_username']}'),
                      const SizedBox(height: 20),
                      const Text('Players', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...(room!['participants'] as List).map((item) {
                        final participant = Map<String, dynamic>.from(item as Map);
                        return Card(
                          color: _gamesCard,
                          child: ListTile(
                            leading: CircleAvatar(child: Text(participant['username'].toString().substring(0, 1).toUpperCase())),
                            title: Text(participant['username'].toString()),
                            subtitle: Text(participant['role'].toString()),
                            trailing: Text(
                              participant['invitation_status'].toString(),
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Text(
                        '${room!['participant_count']} of ${room!['max_players']} players have joined.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Friend Trivia gameplay will be added in the next implementation stage.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _GameFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GameFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _gamesCard,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white60),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String message;
  const _EmptyMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gamesCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white60)),
    );
  }
}

String _gameName(dynamic gameType) {
  switch (gameType?.toString()) {
    case 'friend_trivia':
      return 'Friend Trivia';
    case 'would_you_rather':
      return 'Would You Rather';
    default:
      return 'Game';
  }
}

IconData _gameIcon(dynamic gameType) {
  return gameType?.toString() == 'friend_trivia'
      ? Icons.quiz_outlined
      : Icons.compare_arrows;
}
