import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quest_destination.dart';

/// Members browse the official Toggi games page, then submit an estimated
/// per-person budget as a shared SideQuest option.
class ToggiExplorer extends StatefulWidget {
  final bool locked;
  final bool Function(QuestDestination destination) isNominated;
  final ValueChanged<QuestDestination> onNominate;

  const ToggiExplorer({
    super.key,
    required this.locked,
    required this.isNominated,
    required this.onNominate,
  });

  @override
  State<ToggiExplorer> createState() => _ToggiExplorerState();
}

class _ToggiExplorerState extends State<ToggiExplorer> {
  static final Uri _toggiGamesUri = Uri.parse(
    'https://www.toggifunworld.com/games-rides/',
  );

  final TextEditingController _budgetController = TextEditingController();

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _openToggiWebsite() async {
    try {
      final opened = await launchUrl(
        _toggiGamesUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Toggi Fun World. Please try again.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open Toggi Fun World.')),
        );
      }
    }
  }

  QuestDestination? _buildBudgetProposal({bool showError = true}) {
    final rawBudget = _budgetController.text.trim().replaceAll(',', '');
    final budget = int.tryParse(rawBudget);

    if (budget == null || budget <= 0) {
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid estimated budget per person.'),
          ),
        );
      }
      return null;
    }

    final sourceId = 'toggi:dhaka:budget:$budget';

    return QuestDestination(
      questDestinationId(sourceId),
      'Toggi Fun World - ৳$budget/person',
      'Indoor Activities',
      'Bashundhara City, Panthapath, Dhaka',
      budget,
      'Estimated indoor activities budget per person after checking Toggi games and rides.',
      Icons.sports_esports,
      sourceUrl: _toggiGamesUri.toString(),
      sourceName: 'Toggi Fun World',
      sourceId: sourceId,
      priceLabel: 'Estimated ৳$budget per person',
    );
  }

  void _addBudgetProposal() {
    if (widget.locked) return;

    final destination = _buildBudgetProposal();
    if (destination == null) return;

    if (widget.isNominated(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This Toggi budget option is already in group voting.'),
        ),
      );
      return;
    }

    widget.onNominate(destination);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildBudgetProposal(showError: false);
    final alreadyNominated =
        preview != null && widget.isNominated(preview);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Card(
          color: const Color(0xFF1D1E35),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.sports_esports,
                      color: Colors.deepPurpleAccent,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Indoor Activities - Toggi Fun World',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Browse Toggi Fun World to explore games and rides '
                  'and check the current prices. Then return here to '
                  'estimate your budget per person.',
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openToggiWebsite,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Browse Toggi Games & Rides'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Estimate Your Budget',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'After checking the game and ride prices, enter the estimated '
          'amount each person may need to spend.',
          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _budgetController,
          enabled: !widget.locked,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Estimated budget per person (BDT)',
            hintText: 'e.g. 1500',
            prefixText: '৳ ',
            prefixIcon: Icon(Icons.payments_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.locked || alreadyNominated
                ? null
                : _addBudgetProposal,
            icon: Icon(
              alreadyNominated ? Icons.check_circle : Icons.how_to_vote,
            ),
            label: Text(
              alreadyNominated
                  ? 'Already added to group voting'
                  : 'Add budget to group voting',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'SideQuest records your estimate only. It does not book rides '
          'or packages. Confirm current prices and availability with Toggi.',
          style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }
}
