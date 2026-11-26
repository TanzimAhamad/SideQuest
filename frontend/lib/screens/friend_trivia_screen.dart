import 'dart:async';

import 'package:flutter/material.dart';

import '../services/games_service.dart';

const _triviaPurple = Color(0xFF8B5CF6);
const _triviaTeal = Color(0xFF0E9F9A);
const _triviaCard = Color(0xFF1D1E35);

class FriendTriviaGameScreen extends StatefulWidget {
  final int roomId;

  const FriendTriviaGameScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<FriendTriviaGameScreen> createState() => _FriendTriviaGameScreenState();
}

class _FriendTriviaGameScreenState extends State<FriendTriviaGameScreen> {
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
      final result = await GamesService.getFriendTriviaState(widget.roomId);
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

  List<Map<String, dynamic>> _asMaps(Object? value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = gameState?['title']?.toString() ?? 'Friend Trivia';
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
          Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
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
        color: _triviaCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _triviaPurple.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _triviaPurple.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.quiz_outlined, color: _triviaPurple, size: 27),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FRIEND TRIVIA',
                  style: TextStyle(
                    color: _triviaPurple,
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
          Text('$count/$max', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
    );
  }

  Widget _buildLobby(Map<String, dynamic> state) {
    final isHost = state['is_host'] == true;
    final pending = _asInt(state['pending_invites']);
    final players = _asMaps(state['players']);
    final canStart = isHost && pending == 0 && players.length >= 2 && !isBusy;

    String startLabel;
    if (isBusy) {
      startLabel = 'Starting game...';
    } else if (pending > 0) {
      startLabel = 'Waiting for $pending invitation(s)';
    } else if (players.length < 2) {
      startLabel = 'At least 2 players are required';
    } else {
      startLabel = 'Start Friend Trivia';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Game lobby', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Each player gets three personal questions. The others try to guess their answers.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        _playerList(players, showRoundStatus: false),
        if (pending > 0) ...[
          const SizedBox(height: 14),
          _infoPanel(
            Icons.hourglass_top,
            '$pending invitation(s) are still pending. The host can start after every invitation is accepted or declined.',
          ),
        ],
        if (isHost) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canStart
                  ? () => _runAction(() => GamesService.startFriendTrivia(widget.roomId))
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(startLabel),
              style: FilledButton.styleFrom(
                backgroundColor: _triviaPurple,
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
    final totalRounds = _asInt(round['total_rounds'], 1);
    final guessesSubmitted = _asInt(state['guesses_submitted']);
    final guessersTotal = _asInt(state['guessers_total']);
    final isSubject = round['is_subject'] == true;
    final phase = round['phase']?.toString() ?? 'answering';
    final myAnswer = round['my_answer']?.toString();
    final myGuess = round['my_guess']?.toString();
    final revealed = round['results_revealed'] == true;
    final options = _asMaps(round['options']);
    final isHost = state['is_host'] == true;

    final progressValue = guessersTotal == 0
        ? 0.0
        : (guessesSubmitted / guessersTotal).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question $roundNumber of $totalRounds',
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '$guessesSubmitted/$guessersTotal guessed',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 7,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(_triviaTeal),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _triviaPurple.withValues(alpha: 0.28),
                _triviaTeal.withValues(alpha: 0.13),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Text(
                isSubject ? 'YOUR QUESTION' : 'GUESS ${round['subject_username']?.toString().toUpperCase() ?? 'YOUR FRIEND'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                round['question']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, height: 1.35, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 9),
              Text(
                isSubject
                    ? 'Choose the answer that describes you best.'
                    : 'What do you think ${round['subject_username']} would choose?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (phase == 'answering' && !isSubject)
          _infoPanel(Icons.hourglass_top, 'Waiting for ${round['subject_username']} to choose an answer.'),
        if (phase == 'answering' && isSubject)
          ..._buildOptionCards(options, selected: myAnswer, enabled: !isBusy, onSelected: _submitAnswer),
        if (phase == 'guessing' && isSubject) ...[
          _infoPanel(
            Icons.check_circle_outline,
            'Your answer is locked in. The other players are now guessing.',
          ),
          if (myAnswer != null) _selectedAnswerPanel(options, myAnswer),
        ],
        if (phase == 'guessing' && !isSubject && myGuess == null)
          ..._buildOptionCards(options, selected: null, enabled: !isBusy, onSelected: _submitGuess),
        if (phase == 'guessing' && !isSubject && myGuess != null)
          _infoPanel(Icons.check_circle_outline, 'Your guess is submitted. Waiting for the other players.'),
        if (revealed) ...[
          _buildAnswerReveal(round),
          const SizedBox(height: 14),
          _buildLeaderboard(_asMaps(state['leaderboard'])),
          const SizedBox(height: 14),
          if (isHost)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBusy
                    ? null
                    : () => _runAction(() => GamesService.nextFriendTriviaRound(widget.roomId)),
                icon: Icon(roundNumber >= totalRounds ? Icons.flag : Icons.arrow_forward),
                label: Text(
                  isBusy
                      ? 'Please wait...'
                      : roundNumber >= totalRounds
                          ? 'Finish game'
                          : 'Next question',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _triviaPurple,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            )
          else
            _infoPanel(Icons.hourglass_empty, 'Everyone has guessed. Waiting for the host to continue.'),
        ],
        const SizedBox(height: 18),
        _playerList(_asMaps(state['players']), showRoundStatus: true),
      ],
    );
  }

  List<Widget> _buildOptionCards(
    List<Map<String, dynamic>> options, {
    required String? selected,
    required bool enabled,
    required ValueChanged<String> onSelected,
  }) {
    return options.map((option) {
      final choice = option['choice']?.toString() ?? '';
      final text = option['text']?.toString() ?? '';
      final selectedNow = selected == choice;
      final colors = <String, Color>{
        'A': _triviaPurple,
        'B': _triviaTeal,
        'C': const Color(0xFFD97757),
        'D': const Color(0xFFCA8A04),
      };
      final color = colors[choice] ?? _triviaPurple;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          color: selectedNow ? color.withValues(alpha: 0.22) : _triviaCard,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: selectedNow ? color : Colors.white12, width: selectedNow ? 1.8 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => onSelected(choice) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    foregroundColor: color,
                    child: Text(choice, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (selectedNow) Icon(Icons.check_circle, color: color),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> _submitAnswer(String choice) async {
    await _runAction(
      () => GamesService.submitFriendTriviaAnswer(roomId: widget.roomId, choice: choice),
    );
  }

  Future<void> _submitGuess(String choice) async {
    await _runAction(
      () => GamesService.submitFriendTriviaGuess(roomId: widget.roomId, choice: choice),
    );
  }

  Widget _selectedAnswerPanel(List<Map<String, dynamic>> options, String choice) {
    Map<String, dynamic>? selected;
    for (final option in options) {
      if (option['choice'] == choice) {
        selected = option;
        break;
      }
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _triviaPurple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        'Your answer: ${selected?['text'] ?? choice}',
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildAnswerReveal(Map<String, dynamic> round) {
    final choice = round['correct_choice']?.toString() ?? '';
    final answer = round['correct_answer']?.toString() ?? 'Answer unavailable';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _triviaTeal.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _triviaTeal.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('THE ANSWER', style: TextStyle(color: _triviaTeal, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          const SizedBox(height: 7),
          Text('$choice. $answer', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('That was ${round['subject_username']}’s choice.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List<Map<String, dynamic>> leaderboard) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _triviaCard, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...leaderboard.asMap().entries.map((entry) {
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 27, child: Text('#${entry.key + 1}', style: const TextStyle(color: Colors.white54))),
                  Expanded(child: Text(item['username']?.toString() ?? 'Player')),
                  Text('${_asInt(item['score'])} pts', style: const TextStyle(color: _triviaTeal, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompleted(Map<String, dynamic> state) {
    final roundValue = state['current_round'];
    final round = roundValue is Map ? Map<String, dynamic>.from(roundValue) : null;
    return Column(
      children: [
        const SizedBox(height: 25),
        const Icon(Icons.emoji_events_outlined, size: 70, color: Colors.amber),
        const SizedBox(height: 14),
        const Text('Friend Trivia completed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Everyone has taken a turn. Here is the final leaderboard.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        if (round != null && round['results_revealed'] == true) ...[
          const SizedBox(height: 18),
          _buildAnswerReveal(round),
        ],
        const SizedBox(height: 18),
        _buildLeaderboard(_asMaps(state['leaderboard'])),
        const SizedBox(height: 18),
        _playerList(_asMaps(state['players']), showRoundStatus: false),
      ],
    );
  }

  Widget _playerList(
    List<Map<String, dynamic>> players, {
    required bool showRoundStatus,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _triviaCard, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Players (${players.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          ...players.map((player) {
            final username = player['username']?.toString() ?? 'Player';
            final isSubject = player['is_subject'] == true;
            final hasAnswered = player['has_answered'] == true;
            final hasGuessed = player['has_guessed'] == true;
            String statusText = '';
            if (showRoundStatus) {
              statusText = isSubject
                  ? (hasAnswered ? 'Answered' : 'Choosing')
                  : (hasGuessed ? 'Guessed' : 'Waiting');
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: _triviaPurple.withValues(alpha: 0.2),
                    child: Text(username.isEmpty ? '?' : username[0].toUpperCase(), style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(isSubject ? '$username (subject)' : username),
                  ),
                  if (showRoundStatus)
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusText == 'Answered' || statusText == 'Guessed'
                            ? Colors.greenAccent
                            : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text('${_asInt(player['score'])} pts', style: const TextStyle(color: Colors.white60, fontSize: 11)),
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
            child: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
