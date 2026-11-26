import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/quest_destination.dart';

/// Eating Out flow:
/// members browse Foodpanda's Dhaka catalog externally, then submit
/// an estimated per-person budget for the group's voting.
class FoodpandaExplorer extends StatefulWidget {
  final bool locked;
  final bool Function(QuestDestination destination) isNominated;
  final ValueChanged<QuestDestination> onNominate;

  const FoodpandaExplorer({
    super.key,
    required this.locked,
    required this.isNominated,
    required this.onNominate,
  });

  @override
  State<FoodpandaExplorer> createState() => _FoodpandaExplorerState();
}

class _FoodpandaExplorerState extends State<FoodpandaExplorer> {
  static final Uri _foodpandaDhakaUri =
      Uri.parse('https://www.foodpanda.com.bd/city/dhaka');

  final TextEditingController _budgetController = TextEditingController();

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _openFoodpanda() async {
    final opened = await launchUrl(
      _foodpandaDhakaUri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Foodpanda. Please try again.'),
        ),
      );
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

    final sourceId = 'foodpanda:dhaka:budget:$budget';

    return QuestDestination(
      questDestinationId(sourceId),
      'Foodpanda Budget - ৳$budget/person',
      'Eating Out',
      'Dhaka',
      budget,
      'Estimated food budget per person after checking restaurants and menus on Foodpanda.',
      Icons.restaurant,
      sourceUrl: _foodpandaDhakaUri.toString(),
      sourceName: 'Foodpanda',
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
          content: Text('This Foodpanda budget option is already in group voting.'),
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
                    Icon(Icons.restaurant, color: Color(0xFFE21B70)),
                    SizedBox(width: 9),
                    Text(
                      'Eating Out • Dhaka',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                const Text(
                  'Browse restaurants and menus on Foodpanda. Decide what '
                  'your group would like to eat, then return here and enter '
                  'the estimated budget per person.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openFoodpanda,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Visit Foodpanda – Dhaka'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE21B70),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Estimate your food budget',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 7),
        const Text(
          'After checking the menu, enter how much each person may need '
          'to spend. Your estimate will be added as an option for group voting.',
          style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _budgetController,
          enabled: !widget.locked,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Estimated budget per person (BDT)',
            hintText: 'e.g. 800',
            prefixIcon: Icon(Icons.payments_outlined),
            prefixText: '৳ ',
          ),
        ),
        const SizedBox(height: 14),
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
              backgroundColor: const Color(0xFFE21B70),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Foodpanda is used for browsing only. SideQuest records the '
          'estimated budget you enter; it does not place an order. '
          'Foodpanda delivery prices may differ from dine-in prices.',
          style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}
