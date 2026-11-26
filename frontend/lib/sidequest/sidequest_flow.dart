import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'activities/foodpanda_explorer.dart';
import 'activities/movie_explorer.dart';
import 'activities/toggi_explorer.dart';
import 'models/quest_destination.dart';

const questPurple = Color(0xFF8B5CF6);
const questCard = Color(0xFF1D1E35);

const questActivities = <String>[
  'Movies',
  'Eating Out',
  'Indoor Activities',
];

/// Group-chat WebSocket events use this notifier to refresh open SideQuest
/// screens without creating a second WebSocket connection.
class SideQuestEvents {
  SideQuestEvents._();

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void notify() {
    changes.value++;
  }
}

class QuestVote {
  final int id;
  final int optionId;
  final int userId;
  final String username;
  final String activity;

  const QuestVote({
    required this.id,
    required this.optionId,
    required this.userId,
    required this.username,
    required this.activity,
  });

  factory QuestVote.fromJson(Map<String, dynamic> json) {
    return QuestVote(
      id: _asInt(json['id']),
      optionId: _asInt(json['option_id']),
      userId: _asInt(json['user_id']),
      username: json['username']?.toString() ?? 'Unknown user',
      activity: json['activity']?.toString() ?? '',
    );
  }
}

class QuestPlan {
  final int id;
  final int groupId;
  final int createdBy;
  final String groupName;
  final String title;
  final String creatorUsername;
  final String status;
  final List<String> activities;
  final List<QuestDestination> options;
  final List<QuestVote> votes;
  final int currentUserId;
  final String currentUsername;

  const QuestPlan({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.groupName,
    required this.title,
    required this.creatorUsername,
    required this.status,
    required this.activities,
    required this.options,
    required this.votes,
    required this.currentUserId,
    required this.currentUsername,
  });

  bool get finalized => status == 'finalized';

  int get totalVotes => votes.length;

  factory QuestPlan.fromJson(
    Map<String, dynamic> json, {
    required int currentUserId,
    required String currentUsername,
  }) {
    final rawOptions = json['options'] as List? ?? const [];
    final rawVotes = json['votes'] as List? ?? const [];
    final rawActivities = json['activities'] as List? ?? const [];

    final options = rawOptions
        .whereType<Map>()
        .map((item) {
          final option = Map<String, dynamic>.from(item);
          final scheduledAt = DateTime.tryParse(
            option['scheduled_at']?.toString() ?? '',
          );

          return QuestDestination(
            _asInt(option['id']),
            option['name']?.toString() ?? 'Unnamed option',
            option['activity']?.toString() ?? '',
            option['area']?.toString() ?? '',
            _asInt(option['estimated_cost']),
            option['description']?.toString() ?? '',
            _iconForActivity(option['activity']?.toString() ?? ''),
            sourceUrl: option['source_url']?.toString(),
            sourceName: option['source_name']?.toString(),
            sourceId: option['source_id']?.toString(),
            scheduledAt: scheduledAt,
            createdByUserId: _asInt(option['created_by']),
            createdByUsername:
                option['created_by_username']?.toString() ?? 'Unknown user',
          );
        })
        .toList();

    final votes = rawVotes
        .whereType<Map>()
        .map((item) => QuestVote.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();

    return QuestPlan(
      id: _asInt(json['id']),
      groupId: _asInt(json['group_id']),
      createdBy: _asInt(json['created_by']),
      groupName: json['group_name']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Group SideQuest',
      creatorUsername: json['creator_username']?.toString() ?? 'Unknown',
      status: json['status']?.toString() ?? 'open',
      activities: rawActivities.map((item) => item.toString()).toList(),
      options: options,
      votes: votes,
      currentUserId: currentUserId,
      currentUsername: currentUsername,
    );
  }

  List<QuestDestination> nominationsFor(String activity) {
    return options.where((option) => option.activity == activity).toList();
  }

  bool hasOption(QuestDestination destination) {
    return options.any((option) {
      if (option.activity != destination.activity) return false;

      if (destination.sourceId != null &&
          destination.sourceId!.isNotEmpty) {
        return option.sourceId == destination.sourceId;
      }

      return option.name.trim().toLowerCase() ==
              destination.name.trim().toLowerCase() &&
          option.estimatedCost == destination.estimatedCost;
    });
  }

  int voteCountFor(int optionId) {
    return votes.where((vote) => vote.optionId == optionId).length;
  }

  List<String> votersFor(int optionId) {
    return votes
        .where((vote) => vote.optionId == optionId)
        .map((vote) => vote.username)
        .toList();
  }

  // One current vote for the whole SideQuest, regardless of activity.
  int? get myVoteOptionId {
    for (final vote in votes) {
      if (vote.userId == currentUserId) return vote.optionId;
    }
    return null;
  }

  QuestDestination? get myVotedOption {
    final optionId = myVoteOptionId;
    if (optionId == null) return null;

    for (final option in options) {
      if (option.id == optionId) return option;
    }
    return null;
  }

  // The SideQuest has one overall winner across all activities.
  QuestDestination? get overallWinner {
    if (options.isEmpty || votes.isEmpty) return null;

    final highest = options
        .map((option) => voteCountFor(option.id))
        .fold<int>(0, (previous, count) => count > previous ? count : previous);

    if (highest == 0) return null;

    final winners = options
        .where((option) => voteCountFor(option.id) == highest)
        .toList();

    return winners.length == 1 ? winners.first : null;
  }

  bool get hasOverallTie {
    if (options.length < 2 || votes.isEmpty) return false;

    final highest = options
        .map((option) => voteCountFor(option.id))
        .fold<int>(0, (previous, count) => count > previous ? count : previous);

    if (highest == 0) return false;

    return options.where((option) => voteCountFor(option.id) == highest).length > 1;
  }

  bool get canFinalize {
    return options.isNotEmpty &&
        votes.isNotEmpty &&
        overallWinner != null &&
        !hasOverallTie;
  }
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

IconData _iconForActivity(String activity) {
  switch (activity) {
    case 'Movies':
      return Icons.movie;
    case 'Eating Out':
      return Icons.restaurant;
    default:
      return Icons.sports_esports;
  }
}

String questDateLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.day}/${date.month}/${date.year} • '
      '$hour:${date.minute.toString().padLeft(2, '0')} $suffix';
}

/// Opens the current group plan. If no plan exists yet, the creator screen
/// is shown. The group ID, not the group name, identifies the shared plan.
class SideQuestScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final int currentUserId;
  final String currentUsername;

  const SideQuestScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<SideQuestScreen> createState() => _SideQuestScreenState();
}

class _SideQuestScreenState extends State<SideQuestScreen> {
  late Future<Map<String, dynamic>?> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = ApiService.getLatestSideQuest(widget.groupId);
  }

  void _retry() {
    setState(() {
      _loadFuture = ApiService.getLatestSideQuest(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('SideQuest')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return CreateSideQuestScreen(
            groupId: widget.groupId,
            groupName: widget.groupName,
            currentUserId: widget.currentUserId,
            currentUsername: widget.currentUsername,
          );
        }

        final plan = QuestPlan.fromJson(
          data,
          currentUserId: widget.currentUserId,
          currentUsername: widget.currentUsername,
        );

        return QuestHubScreen(plan: plan);
      },
    );
  }
}

class CreateSideQuestScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final int currentUserId;
  final String currentUsername;

  const CreateSideQuestScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<CreateSideQuestScreen> createState() => _CreateSideQuestScreenState();
}

class _CreateSideQuestScreenState extends State<CreateSideQuestScreen> {
  final TextEditingController _titleController =
      TextEditingController(text: 'Our next hangout');
  final Set<String> _selectedActivities = {'Indoor Activities'};
  bool _creating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createSideQuest() async {
    final title = _titleController.text.trim();

    if (title.isEmpty || _selectedActivities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a title and select at least one activity.'),
        ),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      final data = await ApiService.createSideQuest(
        groupId: widget.groupId,
        title: title,
        activities: questActivities
            .where(_selectedActivities.contains)
            .toList(),
      );

      if (!mounted) return;

      final plan = QuestPlan.fromJson(
        data,
        currentUserId: widget.currentUserId,
        currentUsername: widget.currentUsername,
      );

      SideQuestEvents.notify();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuestHubScreen(plan: plan),
        ),
      );
    } catch (error) {
      // If another member created the plan at almost the same time, open
      // their shared plan instead of asking this user to create a duplicate.
      try {
        final existing =
            await ApiService.getLatestSideQuest(widget.groupId);

        if (!mounted) return;

        if (existing != null) {
          final plan = QuestPlan.fromJson(
            existing,
            currentUserId: widget.currentUserId,
            currentUsername: widget.currentUsername,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => QuestHubScreen(plan: plan),
            ),
          );
          return;
        }
      } catch (_) {
        // Show the original create error below.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create SideQuest')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.rocket_launch, color: questPurple, size: 48),
          const SizedBox(height: 12),
          Text(
            'Plan with ${widget.groupName}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Creating as ${widget.currentUsername}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'SideQuest title',
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Choose starting activities',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: questActivities.map((activity) {
              return FilterChip(
                label: Text(activity),
                selected: _selectedActivities.contains(activity),
                selectedColor: questPurple.withValues(alpha: .45),
                onSelected: _creating
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _selectedActivities.add(activity);
                          } else {
                            _selectedActivities.remove(activity);
                          }
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'You and your group members can add more activities and '
            'options after creating the SideQuest.',
            style: TextStyle(color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _creating ? null : _createSideQuest,
            icon: _creating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.rocket_launch),
            label: Text(_creating ? 'Creating...' : 'Create SideQuest'),
            style: FilledButton.styleFrom(
              backgroundColor: questPurple,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}

class QuestHubScreen extends StatefulWidget {
  final QuestPlan plan;

  const QuestHubScreen({super.key, required this.plan});

  @override
  State<QuestHubScreen> createState() => _QuestHubScreenState();
}

class _QuestHubScreenState extends State<QuestHubScreen> {
  late QuestPlan _plan;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    SideQuestEvents.changes.addListener(_onSideQuestEvent);
  }

  @override
  void dispose() {
    SideQuestEvents.changes.removeListener(_onSideQuestEvent);
    super.dispose();
  }

  void _onSideQuestEvent() {
    _refreshPlan();
  }

  Future<void> _refreshPlan() async {
    if (_loading) return;
    _loading = true;

    try {
      final data = await ApiService.getSideQuest(_plan.id);
      if (!mounted) return;
      setState(() {
        _plan = QuestPlan.fromJson(
          data,
          currentUserId: _plan.currentUserId,
          currentUsername: _plan.currentUsername,
        );
      });
    } catch (error) {
      debugPrint('Could not refresh SideQuest: $error');
    } finally {
      _loading = false;
    }
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) await _refreshPlan();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(title: const Text('SideQuest HQ')),
      body: RefreshIndicator(
        onRefresh: _refreshPlan,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR GROUP PLAN',
                    style: TextStyle(
                      color: questPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(plan.groupName),
                  Text('Created by ${plan.creatorUsername}'),
                  const SizedBox(height: 8),
                  Text('Activities: ${plan.activities.join(' • ')}'),
                  const SizedBox(height: 8),
                  Text('${plan.options.length} group options'),
                  Text('${plan.totalVotes} votes submitted'),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(plan.finalized ? 'Finalized' : 'Open for planning'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _stepTile(
              context,
              Icons.explore,
              '1. Explore and add options',
              'Browse providers, add proposals and switch between all three activities.',
              () => _openScreen(
                ExploreDestinationsScreen(plan: plan),
              ),
            ),
            _stepTile(
              context,
              Icons.how_to_vote,
              '2. Group voting',
              'Every member votes using their own authenticated account.',
              () => _openScreen(
                QuestVotingScreen(plan: plan),
              ),
            ),
            _stepTile(
              context,
              Icons.event_available,
              '3. Results and final plan',
              'See which option has the highest number of votes.',
              () => _openScreen(
                FinalQuestScreen(plan: plan),
              ),
            ),
            if (plan.finalized) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateSideQuestScreen(
                        groupId: plan.groupId,
                        groupName: plan.groupName,
                        currentUserId: plan.currentUserId,
                        currentUsername: plan.currentUsername,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Start a new SideQuest'),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'This plan is shared by all members of this group and is saved in the database.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class ExploreDestinationsScreen extends StatefulWidget {
  final QuestPlan plan;

  const ExploreDestinationsScreen({super.key, required this.plan});

  @override
  State<ExploreDestinationsScreen> createState() =>
      _ExploreDestinationsScreenState();
}

class _ExploreDestinationsScreenState
    extends State<ExploreDestinationsScreen> {
  late QuestPlan _plan;
  String _selectedActivity = 'Indoor Activities';
  bool _savingOption = false;
  bool _changingActivity = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _selectedActivity = _plan.activities.isNotEmpty
        ? _plan.activities.first
        : questActivities.first;
    SideQuestEvents.changes.addListener(_onSideQuestEvent);
  }

  @override
  void dispose() {
    SideQuestEvents.changes.removeListener(_onSideQuestEvent);
    super.dispose();
  }

  void _onSideQuestEvent() {
    _refreshPlan();
  }

  Future<void> _refreshPlan() async {
    try {
      final data = await ApiService.getSideQuest(_plan.id);
      if (!mounted) return;
      setState(() {
        _plan = QuestPlan.fromJson(
          data,
          currentUserId: _plan.currentUserId,
          currentUsername: _plan.currentUsername,
        );
      });
    } catch (error) {
      debugPrint('Could not refresh SideQuest options: $error');
    }
  }

  Future<void> _selectActivity(String activity) async {
    if (_changingActivity) return;

    setState(() => _changingActivity = true);

    try {
      if (!_plan.activities.contains(activity)) {
        final data = await ApiService.addSideQuestActivity(
          sideQuestId: _plan.id,
          activity: activity,
        );
        if (!mounted) return;
        _plan = QuestPlan.fromJson(
          data,
          currentUserId: _plan.currentUserId,
          currentUsername: _plan.currentUsername,
        );
      }

      if (!mounted) return;
      setState(() => _selectedActivity = activity);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _changingActivity = false);
    }
  }

  bool _isNominated(QuestDestination destination) {
    return _plan.hasOption(destination);
  }

  void _nominate(QuestDestination destination) {
    unawaited(_addOption(destination));
  }

  Future<void> _addOption(QuestDestination destination) async {
    if (_plan.finalized || _savingOption) return;

    if (_isNominated(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This option is already available to the group.'),
        ),
      );
      return;
    }

    setState(() => _savingOption = true);

    try {
      final data = await ApiService.addSideQuestOption(
        sideQuestId: _plan.id,
        activity: destination.activity,
        name: destination.name,
        area: destination.area,
        estimatedCost: destination.estimatedCost,
        description: destination.description,
        sourceUrl: destination.sourceUrl,
        sourceName: destination.sourceName,
        sourceId: destination.sourceId,
        scheduledAt: destination.scheduledAt,
      );

      if (!mounted) return;

      setState(() {
        _plan = QuestPlan.fromJson(
          data,
          currentUserId: _plan.currentUserId,
          currentUsername: _plan.currentUsername,
        );
      });

      SideQuestEvents.notify();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${destination.name} is now available to everyone in the group.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _savingOption = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    Widget activityContent;
    if (_selectedActivity == 'Eating Out') {
      activityContent = FoodpandaExplorer(
        key: const ValueKey('foodpanda-explorer'),
        locked: plan.finalized || _savingOption,
        isNominated: _isNominated,
        onNominate: _nominate,
      );
    } else if (_selectedActivity == 'Movies') {
      activityContent = MovieExplorer(
        key: const ValueKey('movie-explorer'),
        locked: plan.finalized || _savingOption,
        isNominated: _isNominated,
        onNominate: _nominate,
      );
    } else {
      activityContent = ToggiExplorer(
        key: const ValueKey('toggi-explorer'),
        locked: plan.finalized || _savingOption,
        isNominated: _isNominated,
        onNominate: _nominate,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Explore and add options')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose or switch activity',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: questActivities.map((activity) {
                    final alreadyAdded = plan.activities.contains(activity);
                    return ChoiceChip(
                      label: Text(
                        alreadyAdded ? activity : '+ $activity',
                      ),
                      selected: _selectedActivity == activity,
                      onSelected: plan.finalized || _changingActivity
                          ? null
                          : (_) => _selectActivity(activity),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 5),
                const Text(
                  'You can switch activities at any time. Selecting a new activity adds it to this shared SideQuest.',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_changingActivity) const LinearProgressIndicator(),
          Expanded(child: activityContent),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await _refreshPlan();
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestVotingScreen(plan: _plan),
                    ),
                  );
                },
                child: const Text('Continue to group voting'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuestVotingScreen extends StatefulWidget {
  final QuestPlan plan;

  const QuestVotingScreen({super.key, required this.plan});

  @override
  State<QuestVotingScreen> createState() => _QuestVotingScreenState();
}

class _QuestVotingScreenState extends State<QuestVotingScreen> {
  late QuestPlan _plan;
  int? _submittingOptionId;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    SideQuestEvents.changes.addListener(_onSideQuestEvent);
  }

  @override
  void dispose() {
    SideQuestEvents.changes.removeListener(_onSideQuestEvent);
    super.dispose();
  }

  void _onSideQuestEvent() {
    _refreshPlan();
  }

  Future<void> _refreshPlan() async {
    try {
      final data = await ApiService.getSideQuest(_plan.id);
      if (!mounted) return;
      setState(() {
        _plan = QuestPlan.fromJson(
          data,
          currentUserId: _plan.currentUserId,
          currentUsername: _plan.currentUsername,
        );
      });
    } catch (error) {
      debugPrint('Could not refresh SideQuest voting: $error');
    }
  }

  Future<void> _castVote(int optionId) async {
    if (_plan.finalized || _submittingOptionId != null) return;

    setState(() => _submittingOptionId = optionId);

    try {
      final data = await ApiService.voteForSideQuestOption(
        sideQuestId: _plan.id,
        optionId: optionId,
      );

      if (!mounted) return;

      setState(() {
        _plan = QuestPlan.fromJson(
          data,
          currentUserId: _plan.currentUserId,
          currentUsername: _plan.currentUsername,
        );
        _submittingOptionId = null;
      });

      SideQuestEvents.notify();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your vote has been recorded.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _submittingOptionId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(title: const Text('Group voting')),
      body: RefreshIndicator(
        onRefresh: _refreshPlan,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _panel(
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: questPurple,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Voting as ${plan.currentUsername}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'Your vote is saved to your logged-in account.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose ONE option across this entire SideQuest. You can change your vote to another activity while voting is open.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            for (final activity in plan.activities) ...[
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (plan.nominationsFor(activity).isEmpty)
                      const Text(
                        'No options yet. Return to Explore and add an option.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    for (final option in plan.nominationsFor(activity))
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: option.id,
                        groupValue: plan.myVoteOptionId,
                        activeColor: questPurple,
                        onChanged: plan.finalized ||
                                _submittingOptionId != null
                            ? null
                            : (value) {
                                if (value != null) _castVote(value);
                              },
                        title: Text(option.name),
                        subtitle: Text(
                          '${option.area} • ${option.displayPrice}\n'
                          'Added by ${option.createdByUsername ?? 'Group member'}\n'
                          '${plan.voteCountFor(option.id)} vote(s)'
                          '${plan.votersFor(option.id).isEmpty ? '' : ' • ${plan.votersFor(option.id).join(', ')}'}',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (plan.myVotedOption != null)
              _panel(
                Text(
                  'Your current vote: ${plan.myVotedOption!.name} (${plan.myVotedOption!.activity})',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (plan.finalized)
              const Text(
                'Voting is closed because this SideQuest has been finalized.',
                style: TextStyle(color: Colors.amber),
              )
            else
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FinalQuestScreen(plan: plan),
                  ),
                ),
                icon: const Icon(Icons.bar_chart),
                label: const Text('View voting results'),
              ),
          ],
        ),
      ),
    );
  }
}

class FinalQuestScreen extends StatefulWidget {
  final QuestPlan plan;

  const FinalQuestScreen({super.key, required this.plan});

  @override
  State<FinalQuestScreen> createState() => _FinalQuestScreenState();
}

class _FinalQuestScreenState extends State<FinalQuestScreen> {
  late QuestPlan _plan;
  bool _finalizing = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    SideQuestEvents.changes.addListener(_onSideQuestEvent);
  }

  @override
  void dispose() {
    SideQuestEvents.changes.removeListener(_onSideQuestEvent);
    super.dispose();
  }

  void _onSideQuestEvent() {
    _refreshPlan();
  }

  Future<void> _refreshPlan() async {
    try {
      final data = await ApiService.getSideQuest(_plan.id);
      if (!mounted) return;
      setState(() {
        _plan = QuestPlan.fromJson(
          data,
          currentUserId: _plan.currentUserId,
          currentUsername: _plan.currentUsername,
        );
      });
    } catch (error) {
      debugPrint('Could not refresh final SideQuest: $error');
    }
  }

  Future<void> _finalize() async {
    if (!_plan.canFinalize || _finalizing || _plan.finalized) return;

    setState(() => _finalizing = true);

    try {
      final data = await ApiService.finalizeSideQuest(_plan.id);
      if (!mounted) return;

      setState(() {
        _plan = QuestPlan.fromJson(
          data,
          currentUserId: _plan.currentUserId,
          currentUsername: _plan.currentUsername,
        );
        _finalizing = false;
      });

      SideQuestEvents.notify();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SideQuest finalized. The highest-voted option won.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _finalizing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(title: const Text('Voting results and final plan')),
      body: RefreshIndicator(
        onRefresh: _refreshPlan,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Icon(
              plan.finalized ? Icons.verified : Icons.event_note,
              size: 56,
              color: questPurple,
            ),
            const SizedBox(height: 12),
            Text(
              plan.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              plan.finalized ? 'Finalized group decision' : 'Current group results',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            for (final activity in plan.activities) ...[
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.toUpperCase(),
                      style: const TextStyle(
                        color: questPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final option in plan.nominationsFor(activity))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${option.displayPrice} • Added by ${option.createdByUsername ?? 'Group member'}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${plan.voteCountFor(option.id)} vote(s)',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OVERALL SIDEQUEST RESULT',
                    style: TextStyle(
                      color: questPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (plan.hasOverallTie)
                    const Text(
                      'Tie: more voting is required.',
                      style: TextStyle(color: Colors.amber),
                    )
                  else if (plan.overallWinner == null)
                    const Text(
                      'No winner yet. Members need to vote.',
                      style: TextStyle(color: Colors.white60),
                    )
                  else
                    Text(
                      'Winner: ${plan.overallWinner!.name} (${plan.overallWinner!.activity})',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!plan.finalized)
              FilledButton.icon(
                onPressed: plan.canFinalize && !_finalizing ? _finalize : null,
                icon: _finalizing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _finalizing ? 'Finalizing...' : 'Finalize highest-voted option',
                ),
              ),
            if (!plan.canFinalize && !plan.finalized)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'The entire SideQuest needs one clear highest-voted option. If there is a tie, members must continue voting.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ),
            if (plan.finalized)
              const Center(
                child: Chip(label: Text('SideQuest finalized')),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _panel(Widget child) {
  return Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: questCard,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

Widget _stepTile(
  BuildContext context,
  IconData icon,
  String title,
  String description,
  VoidCallback onTap,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: questCard,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Icon(icon, color: questPurple),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    ),
  );
}
