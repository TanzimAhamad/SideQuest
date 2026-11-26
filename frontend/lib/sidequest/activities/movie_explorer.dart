import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quest_destination.dart';

/// Movie selection flow for SideQuest.
///
/// Users first browse the official Blockbuster website. They then return to
/// SideQuest and record the movie, cinema hall, date and showtime they chose.
/// SideQuest does not invent or pre-fill movie listings or showtimes.
class MovieExplorer extends StatefulWidget {
  final bool locked;
  final bool Function(QuestDestination destination) isNominated;
  final ValueChanged<QuestDestination> onNominate;

  const MovieExplorer({
    super.key,
    required this.locked,
    required this.isNominated,
    required this.onNominate,
  });

  @override
  State<MovieExplorer> createState() => _MovieExplorerState();
}

class _MovieExplorerState extends State<MovieExplorer> {
  static final Uri _nowShowingUri = Uri.parse('https://www.blockbusterbd.com/');
  static final Uri _scheduleUri =
      Uri.parse('https://www.blockbusterbd.com/schedule');

  final _movieController = TextEditingController();
  final _hallController = TextEditingController();
  final _priceController = TextEditingController();
  final _bookingUrlController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _movieController.dispose();
    _hallController.dispose();
    _priceController.dispose();
    _bookingUrlController.dispose();
    super.dispose();
  }

  Future<void> _openOfficialSite(Uri uri) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Blockbuster website.')),
      );
    }
  }

  Future<void> _chooseDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _chooseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  QuestDestination? _buildDestination() {
    final movie = _movieController.text.trim();
    final hall = _hallController.text.trim();
    final date = _selectedDate;
    final time = _selectedTime;

    if (movie.isEmpty || hall.isEmpty || date == null || time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the movie and hall, then confirm its date and showtime.',
          ),
        ),
      );
      return null;
    }

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (scheduledAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future showtime.')),
      );
      return null;
    }

    final rawPrice = _priceController.text.trim();
    final priceDigits = RegExp(r'\d+').firstMatch(rawPrice)?.group(0);
    final price = priceDigits == null ? 0 : int.tryParse(priceDigits) ?? 0;

    final enteredUrl = _bookingUrlController.text.trim();
    Uri sourceUri = _scheduleUri;
    if (enteredUrl.isNotEmpty) {
      final parsed = Uri.tryParse(enteredUrl);
      if (parsed == null ||
          (parsed.scheme != 'https' && parsed.scheme != 'http') ||
          parsed.host.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid Blockbuster booking URL, or leave it blank.'),
          ),
        );
        return null;
      }
      sourceUri = parsed;
    }

    final timeLabel = time.format(context);
    final sourceId =
        'blockbuster:${movie.toLowerCase()}:${_dateText(date)}:${hall.toLowerCase()}:$timeLabel';

    return QuestDestination(
      questDestinationId(sourceId),
      movie,
      'Movies',
      'Jamuna Future Park, Dhaka',
      price,
      'Cinema: $hall • Date: ${_dateText(date)} • Showtime: $timeLabel',
      Icons.movie,
      sourceUrl: sourceUri.toString(),
      sourceName: 'Blockbuster Cinemas',
      sourceId: sourceId,
      scheduledAt: scheduledAt,
      priceLabel: price > 0
          ? '৳$price (price checked by user on Blockbuster)'
          : 'Ticket price to be confirmed on Blockbuster',
    );
  }

  void _addNomination() {
    if (widget.locked) return;
    final destination = _buildDestination();
    if (destination == null) return;

    if (widget.isNominated(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This movie option is already available to the group.'),
        ),
      );
      return;
    }

    widget.onNominate(destination);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreviewWithoutValidation();
    final alreadyNominated = preview != null && widget.isNominated(preview);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        const Text(
          'Browse movies on Blockbuster first',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 7),
        const Text(
          'SideQuest will not show a made-up movie list. Open Blockbuster, '
          'check the actual movies, ticket prices, halls and showtimes, then '
          'return here to add your selection for group voting.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _openOfficialSite(_nowShowingUri),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open Blockbuster – Now Showing'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: () => _openOfficialSite(_scheduleUri),
          icon: const Icon(Icons.calendar_month),
          label: const Text('Open Blockbuster – Movie Schedule'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 10),
        const Text(
          'Confirm your movie selection',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'After checking Blockbuster, return to this screen and enter the '
          'details you selected. Ticket price is optional; if you leave it '
          'blank, members will be asked to confirm it on Blockbuster.',
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _movieController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Movie title',
            prefixIcon: Icon(Icons.movie_outlined),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 11),
        TextField(
          controller: _hallController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Cinema hall',
            hintText: 'e.g. Iris, Montage, Club Royale',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.locked ? null : _chooseDate,
          icon: const Icon(Icons.calendar_today),
          label: Text(
            _selectedDate == null
                ? 'Confirm date from Blockbuster'
                : 'Date: ${_dateText(_selectedDate!)}',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.locked ? null : _chooseTime,
          icon: const Icon(Icons.schedule),
          label: Text(
            _selectedTime == null
                ? 'Confirm showtime from Blockbuster'
                : 'Showtime: ${_selectedTime!.format(context)}',
          ),
        ),
        const SizedBox(height: 11),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ticket price (optional)',
            hintText: 'Leave blank if not confirmed',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 11),
        TextField(
          controller: _bookingUrlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Specific booking URL (optional)',
            hintText: 'Paste a Blockbuster booking link if available',
            prefixIcon: Icon(Icons.link),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: widget.locked || alreadyNominated
              ? null
              : _addNomination,
          icon: Icon(
            alreadyNominated ? Icons.check_circle : Icons.add,
          ),
          label: Text(
            alreadyNominated
                ? 'Already added to group options'
                : 'Add movie to group nominations',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  QuestDestination? _buildPreviewWithoutValidation() {
    final movie = _movieController.text.trim();
    final hall = _hallController.text.trim();
    final date = _selectedDate;
    final time = _selectedTime;
    if (movie.isEmpty || hall.isEmpty || date == null || time == null) {
      return null;
    }
    final timeLabel = time.format(context);
    final sourceId =
        'blockbuster:${movie.toLowerCase()}:${_dateText(date)}:${hall.toLowerCase()}:$timeLabel';
    final rawPrice = _priceController.text.trim();
    final priceDigits = RegExp(r'\d+').firstMatch(rawPrice)?.group(0);
    final price = priceDigits == null ? 0 : int.tryParse(priceDigits) ?? 0;
    final enteredUrl = _bookingUrlController.text.trim();
    final parsed = Uri.tryParse(enteredUrl);
    final sourceUrl = parsed != null &&
            (parsed.scheme == 'https' || parsed.scheme == 'http') &&
            parsed.host.isNotEmpty
        ? parsed.toString()
        : _scheduleUri.toString();
    return QuestDestination(
      questDestinationId(sourceId),
      movie,
      'Movies',
      'Jamuna Future Park, Dhaka',
      price,
      'Cinema: $hall • Date: ${_dateText(date)} • Showtime: $timeLabel',
      Icons.movie,
      sourceUrl: sourceUrl,
      sourceName: 'Blockbuster Cinemas',
      sourceId: sourceId,
      scheduledAt: DateTime(date.year, date.month, date.day, time.hour, time.minute),
      priceLabel: price > 0
          ? '৳$price (price checked by user on Blockbuster)'
          : 'Ticket price to be confirmed on Blockbuster',
    );
  }
}
