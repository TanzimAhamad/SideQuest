import 'dart:async';

import 'package:flutter/material.dart';

import '../services/games_service.dart';

const _wyrPurple = Color(0xFF8B5CF6);
const _wyrTeal = Color(0xFF0E9F9A);
const _wyrCard = Color(0xFF1D1E35);

class WouldYouRatherGameScreen extends StatefulWidget {
  final int roomId;

  const WouldYouRatherGameScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<WouldYouRatherGameScreen> createState() =>
      _WouldYouRatherGameScreenState();
}

class _WouldYouRatherGameScreenState extends State<WouldYouRatherGameScreen> {
  Map<String, dynamic>? gameState;
  String? errorMessage;
  bool isLoading = true;
  bool isBusy = false;
  bool isFetching = false;
  Timer? pollTimer;
  int requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadState(showLoader: true);
    // REST polling keeps both browser sessions in sync for this first version.
    pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadState(),
    );
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState({bool showLoader = false}) async {
    if (isFetching || isBusy) return;
    isFetching = true;
    final version = ++requestVersion;

    if (showLoader && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final result = await GamesService.getWouldYouRatherState(widget.roomId);
      if (!mounted || version != requestVersion) return;
      setState(() {
        gameState = result;
        errorMessage = null;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted || version != requestVersion) return;
      setState(() {
        errorMessage = _cleanError(error);
        isLoading = false;
      });
    } finally {
      isFetching = false;
    }
  }

  Future<void> _runAction(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    if (isBusy) return;
    setState(() => isBusy = true);
    // Ignore any older polling response that was already in flight.
    requestVersion++;

    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        gameState = result;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
      await _loadState();
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  int _asInt(Object? value, [int fallback = 0]) =>
      value is num ? value.toInt() : fallback;

  double _asDouble(Object? value) =>
      value is num ? value.toDouble() : 0.0;

  List<Map<String, dynamic>> _asMaps(Object? value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = gameState?['title']?.toString() ?? 'Would You Rather';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh game',
            onPressed: () => _loadState(showLoader: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null && gameState == null
              ? _buildLoadError()
              : RefreshIndicator(
                  onRefresh: _loadState,
                  child: _buildGameContent(),
                ),
    );
  }

  Widget _buildLoadError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
        const SizedBox(height: 12),
        Center(child: Text(errorMessage!, textAlign: TextAlign.center)),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: () => _loadState(showLoader: true),
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  Widget _buildGameContent() {
    final state = gameState!;
    final roomStatus = state['room_status']?.toString() ?? 'lobby';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        _buildRoomHeader(state),
        const SizedBox(height: 18),
        if (roomStatus == 'lobby')
          _buildLobby(state)
        else if (roomStatus == 'completed')
          _buildCompleted(state)
        else
          _buildActiveGame(state),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            errorMessage!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Game updates automatically every 3 seconds.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomHeader(Map<String, dynamic> state) {
    final count = _asInt(state['participant_count']);
    final max = _asInt(state['max_players']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _wyrCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _wyrTeal.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _wyrTeal.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.compare_arrows, color: _wyrTeal, size: 27),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WOULD YOU RATHER',
                  style: TextStyle(
                    color: _wyrTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hosted by ${state['host_username'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '$count/$max',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby(Map<String, dynamic> state) {
    final isHost = state['is_host'] == true;
    final pending = _asInt(state['pending_invites']);
    final playerCount = _asInt(state['players_total']);
    final players = _asMaps(state['players']);
    final canStart = isHost && pending == 0 && playerCount >= 2 && !isBusy;

    String startLabel;
    if (isBusy) {
      startLabel = 'Starting game...';
    } else if (pending > 0) {
      startLabel = 'Waiting for $pending invitation(s)';
    } else if (playerCount < 2) {
      startLabel = 'At least 2 players are required';
    } else {
      startLabel = 'Start game';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Game lobby',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Everyone who has accepted the invitation will play together.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        _playerList(players, showVoteStatus: false),
        const SizedBox(height: 14),
        if (pending > 0)
          _infoPanel(
            Icons.hourglass_top,
            '$pending invitation(s) are still pending. The host can start after each invitation is accepted or declined.',
          ),
        if (isHost) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canStart
                  ? () => _runAction(
                        () => GamesService.startWouldYouRather(widget.roomId),
                      )
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(startLabel),
              style: FilledButton.styleFrom(
                backgroundColor: _wyrPurple,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ] else
          _infoPanel(
            Icons.hourglass_empty,
            'Waiting for ${state['host_username'] ?? 'the host'} to start the game.',
          ),
      ],
    );
  }

  Widget _buildActiveGame(Map<String, dynamic> state) {
    final roundValue = state['current_round'];
    if (roundValue is! Map) {
      return _infoPanel(Icons.hourglass_empty, 'Waiting for the first question...');
    }

    final round = Map<String, dynamic>.from(roundValue);
    final roundNumber = _asInt(round['round_number'], 1);
    final totalRounds = _asInt(round['total_rounds'], 10);
    final playersTotal = _asInt(state['players_total']);
    final votesSubmitted = _asInt(state['votes_submitted']);
    final myVote = state['my_vote']?.toString();
    final resultsRevealed = state['results_revealed'] == true;
    final isHost = state['is_host'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Round $roundNumber of $totalRounds',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '$votesSubmitted/$playersTotal voted',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: playersTotal == 0 ? 0 : votesSubmitted / playersTotal,
            minHeight: 7,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(_wyrTeal),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _wyrPurple.withValues(alpha: 0.28),
                _wyrTeal.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              const Text(
                'THE QUESTION',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                round['question']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  height: 1.35,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _choiceCard(
          letter: 'A',
          option: round['option_a']?.toString() ?? '',
          selected: myVote == 'A',
          enabled: myVote == null && !isBusy,
          onTap: () => _vote('A'),
        ),
        const SizedBox(height: 11),
        _choiceCard(
          letter: 'B',
          option: round['option_b']?.toString() ?? '',
          selected: myVote == 'B',
          enabled: myVote == null && !isBusy,
          onTap: () => _vote('B'),
        ),
        const SizedBox(height: 16),
        if (myVote != null && !resultsRevealed)
          _infoPanel(
            Icons.check_circle_outline,
            'Your choice has been submitted. Waiting for the other players to vote.',
          )
        else if (myVote == null)
          _infoPanel(
            Icons.touch_app,
            'Select one option. You can vote only once in each round.',
          ),
        if (resultsRevealed) ...[
          const SizedBox(height: 4),
          _buildResults(state, round),
          const SizedBox(height: 14),
          if (isHost)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy
                    ? null
                    : () => _runAction(
                          () => GamesService.nextWouldYouRatherRound(
                            widget.roomId,
                          ),
                        ),
                icon: Icon(
                  roundNumber >= totalRounds ? Icons.flag : Icons.arrow_forward,
                ),
                label: Text(
                  isBusy
                      ? 'Please wait...'
                      : roundNumber >= totalRounds
                          ? 'Finish game'
                          : 'Next question',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _wyrPurple,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            )
          else
            _infoPanel(
              Icons.hourglass_empty,
              'Everyone has voted. Waiting for the host to continue.',
            ),
        ],
        const SizedBox(height: 18),
        _playerList(_asMaps(state['players']), showVoteStatus: true),
      ],
    );
  }

  Future<void> _vote(String choice) async {
    await _runAction(
      () => GamesService.submitWouldYouRatherVote(
        roomId: widget.roomId,
        choice: choice,
      ),
    );
  }

  Widget _choiceCard({
    required String letter,
    required String option,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = letter == 'A' ? _wyrPurple : _wyrTeal;
    return Card(
      color: selected ? color.withValues(alpha: 0.22) : _wyrCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? color : Colors.white12,
          width: selected ? 1.8 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.2),
                foregroundColor: color,
                child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  option,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: color)
              else if (enabled)
                const Icon(Icons.circle_outlined, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(Map<String, dynamic> state, Map<String, dynamic> round) {
    final aVotes = _asInt(state['option_a_votes']);
    final bVotes = _asInt(state['option_b_votes']);
    final aPercent = _asDouble(state['option_a_percentage']);
    final bPercent = _asDouble(state['option_b_percentage']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _wyrCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Voting results',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          _resultLine('A', round['option_a'].toString(), aVotes, aPercent, _wyrPurple),
          const SizedBox(height: 14),
          _resultLine('B', round['option_b'].toString(), bVotes, bPercent, _wyrTeal),
        ],
      ),
    );
  }

  Widget _resultLine(
    String letter,
    String option,
    int votes,
    double percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$letter. $option',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%  ($votes)',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 9,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleted(Map<String, dynamic> state) {
    final roundValue = state['current_round'];
    final round = roundValue is Map ? Map<String, dynamic>.from(roundValue) : null;
    return Column(
      children: [
        const SizedBox(height: 26),
        const Icon(Icons.emoji_events_outlined, size: 70, color: Colors.amber),
        const SizedBox(height: 14),
        const Text(
          'Game completed!',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'All 10 questions have been answered.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        if (round != null && state['results_revealed'] == true) ...[
          const SizedBox(height: 20),
          _buildResults(state, round),
        ],
        const SizedBox(height: 20),
        _playerList(_asMaps(state['players']), showVoteStatus: false),
      ],
    );
  }

  Widget _playerList(
    List<Map<String, dynamic>> players, {
    required bool showVoteStatus,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _wyrCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Players (${players.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 7),
          ...players.map((player) {
            final username = player['username']?.toString() ?? 'Player';
            final hasVoted = player['has_voted'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: _wyrPurple.withValues(alpha: 0.2),
                    child: Text(
                      username.isEmpty ? '?' : username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(username)),
                  if (showVoteStatus)
                    Text(
                      hasVoted ? 'Voted' : 'Waiting',
                      style: TextStyle(
                        color: hasVoted ? Colors.greenAccent : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _infoPanel(IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
