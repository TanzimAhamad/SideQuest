import 'package:flutter/material.dart';

// Frontend MVP: in-memory demo state. Replace this store with backend calls later.
const questPurple = Color(0xFF8B5CF6);
const questCard = Color(0xFF1D1E35);

class QuestDestination {
  final int id;
  final String name, activity, area, description;
  final int estimatedCost;
  final IconData icon;
  const QuestDestination(this.id, this.name, this.activity, this.area,
      this.estimatedCost, this.description, this.icon);
}

const demoDestinations = <QuestDestination>[
  QuestDestination(1, 'The Garden Bistro', 'Eating Out', 'Dhanmondi', 650,
      'Relaxed dining with plenty of seating.', Icons.restaurant),
  QuestDestination(2, 'Rooftop Bites', 'Eating Out', 'Banani', 850,
      'Casual food and a rooftop atmosphere.', Icons.ramen_dining),
  QuestDestination(3, 'Movie House', 'Movies', 'Bashundhara', 550,
      'Catch a movie together on the big screen.', Icons.movie),
  QuestDestination(4, 'Cinema Plaza', 'Movies', 'Dhanmondi', 450,
      'A relaxed cinema outing.', Icons.local_movies),
  QuestDestination(5, 'City Shopping Mall', 'Shopping', 'Jamuna', 300,
      'Browse stores and take a break together.', Icons.shopping_bag),
  QuestDestination(6, 'Lifestyle Market', 'Shopping', 'Gulshan', 400,
      'An afternoon of browsing and shopping.', Icons.storefront),
  QuestDestination(7, 'Strike & Play', 'Bowling & Games', 'Bashundhara', 700,
      'Bowling lanes and arcade games.', Icons.sports_esports),
  QuestDestination(8, 'Arcade Arena', 'Bowling & Games', 'Uttara', 500,
      'Friendly arcade competitions.', Icons.videogame_asset),
  QuestDestination(9, 'Lakeside Walk', 'Outdoor Activities', 'Hatirjheel', 100,
      'A scenic walk and hangout.', Icons.park),
  QuestDestination(10, 'Green Escape', 'Outdoor Activities', 'Ramna', 150,
      'A laid-back afternoon in the park.', Icons.nature_people),
];

class QuestPlan {
  final String groupName, title;
  final DateTime proposedDateTime;
  final int budget;
  final List<String> activities;
  final Set<int> nominations = {};
  // activity -> participant name -> destination ID
  final Map<String, Map<String, int>> votes = {};
  bool finalized = false;
  QuestPlan({required this.groupName, required this.title,
    required this.proposedDateTime, required this.budget,
    required this.activities});

  List<QuestDestination> nominationsFor(String activity) => demoDestinations
      .where((d) => d.activity == activity && nominations.contains(d.id)).toList();

  QuestDestination? winnerFor(String activity) {
    final choices = nominationsFor(activity);
    if (choices.isEmpty) return null;
    final counts = <int, int>{};
    for (final id in votes[activity]?.values ?? <int>[]) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    // In a tie, first nominated option (stable ID order) wins.
    choices.sort((a, b) {
      final byVotes = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
      return byVotes != 0 ? byVotes : a.id.compareTo(b.id);
    });
    return choices.first;
  }
}

class QuestDemoStore {
  QuestDemoStore._();
  static final Map<String, QuestPlan> plans = {};
  static final ValueNotifier<int> changes = ValueNotifier(0);
  static QuestPlan? get(String groupName) => plans[groupName];
  static void save(QuestPlan plan) { plans[plan.groupName] = plan; notify(); }
  static void notify() => changes.value++;
}

// Date strings in the UI use this method without requiring a BuildContext.
String questDateLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.day}/${date.month}/${date.year} • $hour:${date.minute.toString().padLeft(2, '0')} $suffix';
}

class CreateSideQuestScreen extends StatefulWidget {
  final String groupName;
  const CreateSideQuestScreen({super.key, required this.groupName});
  @override
  State<CreateSideQuestScreen> createState() => _CreateSideQuestScreenState();
}

class _CreateSideQuestScreenState extends State<CreateSideQuestScreen> {
  final title = TextEditingController(text: 'Our next hangout');
  final budget = TextEditingController();
  final selected = <String>{};
  DateTime? day;
  TimeOfDay? time;
  static const options = ['Eating Out', 'Movies', 'Shopping',
    'Bowling & Games', 'Outdoor Activities'];

  @override
  void dispose() { title.dispose(); budget.dispose(); super.dispose(); }

  Future<void> chooseDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(context: context,
        initialDate: now, firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 2));
    if (value != null && mounted) setState(() => day = value);
  }

  Future<void> chooseTime() async {
    final value = await showTimePicker(context: context,
        initialTime: time ?? const TimeOfDay(hour: 16, minute: 0));
    if (value != null && mounted) setState(() => time = value);
  }

  void create() {
    final amount = int.tryParse(budget.text.trim());
    if (title.text.trim().isEmpty || selected.isEmpty || day == null ||
        time == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a title, activities, date, time and valid budget.')));
      return;
    }
    final when = DateTime(day!.year, day!.month, day!.day, time!.hour, time!.minute);
    if (when.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a future date and time.')));
      return;
    }
    final plan = QuestPlan(groupName: widget.groupName,
        title: title.text.trim(), proposedDateTime: when, budget: amount,
        activities: options.where(selected.contains).toList());
    QuestDemoStore.save(plan);
    Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => QuestHubScreen(plan: plan)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create SideQuest')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.rocket_launch, color: questPurple, size: 48),
      const SizedBox(height: 12),
      Text('Plan with ${widget.groupName}', textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 24),
      TextField(controller: title, decoration: const InputDecoration(
          labelText: 'SideQuest title', prefixIcon: Icon(Icons.edit_note))),
      const SizedBox(height: 24),
      const Text('Choose activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: options.map((a) =>
        FilterChip(label: Text(a), selected: selected.contains(a),
          selectedColor: questPurple.withValues(alpha: .5),
          onSelected: (yes) => setState(() => yes ? selected.add(a) : selected.remove(a)))).toList()),
      const SizedBox(height: 24),
      OutlinedButton.icon(onPressed: chooseDate, icon: const Icon(Icons.calendar_today),
          label: Text(day == null ? 'Select proposed date' : '${day!.day}/${day!.month}/${day!.year}')),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: chooseTime, icon: const Icon(Icons.schedule),
          label: Text(time == null ? 'Select proposed time' : time!.format(context))),
      const SizedBox(height: 18),
      TextField(controller: budget, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Budget per person (৳)',
              hintText: 'e.g. 1500', prefixIcon: Icon(Icons.payments))),
      const SizedBox(height: 28),
      FilledButton.icon(onPressed: create, icon: const Icon(Icons.rocket_launch),
          label: const Text('Create and explore'),
          style: FilledButton.styleFrom(backgroundColor: questPurple,
              padding: const EdgeInsets.all(16))),
      const SizedBox(height: 12),
      const Text('Demo mode: plans are stored in memory, not sent to the server.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
    ]),
  );
}

class QuestHubScreen extends StatefulWidget {
  final QuestPlan plan;
  const QuestHubScreen({super.key, required this.plan});
  @override
  State<QuestHubScreen> createState() => _QuestHubScreenState();
}

class _QuestHubScreenState extends State<QuestHubScreen> {
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Scaffold(appBar: AppBar(title: const Text('SideQuest HQ')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR GROUP PLAN', style: TextStyle(color: questPurple, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(plan.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${plan.groupName}  •  ${questDateLabel(plan.proposedDateTime)}'),
          const SizedBox(height: 5), Text('Budget: ৳${plan.budget} / person'),
          const SizedBox(height: 8), Text(plan.activities.join('  •  ')),
        ])),
        const SizedBox(height: 18),
        _stepTile(context, Icons.explore, '1. Explore and nominate',
            'Browse sample destinations for each activity.',
            () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ExploreDestinationsScreen(plan: plan))).then((_) => setState(() {}))),
        _stepTile(context, Icons.how_to_vote, '2. Group voting',
            'Each participant can choose one place per activity.',
            () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => QuestVotingScreen(plan: plan))).then((_) => setState(() {}))),
        _stepTile(context, Icons.event_available, '3. Final hangout plan',
            'Review winners and confirm your itinerary.',
            () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => FinalQuestScreen(plan: plan))).then((_) => setState(() {}))),
        const SizedBox(height: 18),
        _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.finalized ? 'Status: Confirmed' : 'Status: Planning',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${plan.nominations.length} destinations nominated'),
          Text('${plan.votes.values.fold<int>(0, (sum, votes) => sum + votes.length)} votes cast across activities'),
          const SizedBox(height: 6),
          const Text('Votes are demo-local; use the participant selector to simulate friends.',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
        ])),
      ]),
    );
  }
}

class ExploreDestinationsScreen extends StatefulWidget {
  final QuestPlan plan;
  const ExploreDestinationsScreen({super.key, required this.plan});
  @override
  State<ExploreDestinationsScreen> createState() => _ExploreDestinationsScreenState();
}

class _ExploreDestinationsScreenState extends State<ExploreDestinationsScreen> {
  late String selectedActivity;
  bool withinBudget = true;
  @override
  void initState() { super.initState(); selectedActivity = widget.plan.activities.first; }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final results = demoDestinations.where((d) => d.activity == selectedActivity &&
      (!withinBudget || d.estimatedCost <= plan.budget)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Explore destinations')),
      body: Column(children: [
        SizedBox(height: 58, child: ListView(scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: plan.activities.map((a) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: Text(a), selected: selectedActivity == a,
              onSelected: (_) => setState(() => selectedActivity = a)))).toList())),
        SwitchListTile(title: Text('Within ৳${plan.budget} per person'),
          value: withinBudget, activeThumbColor: questPurple,
          onChanged: (v) => setState(() => withinBudget = v)),
        Expanded(child: results.isEmpty ? const Center(
          child: Padding(padding: EdgeInsets.all(24), child: Text(
            'No sample destinations match this budget. Turn off the budget filter.',
            textAlign: TextAlign.center))) : ListView.builder(
          padding: const EdgeInsets.all(14), itemCount: results.length,
          itemBuilder: (context, i) {
            final destination = results[i];
            final nominated = plan.nominations.contains(destination.id);
            return Padding(padding: const EdgeInsets.only(bottom: 12), child:
              _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(backgroundColor: questPurple.withValues(alpha: .2),
                      child: Icon(destination.icon, color: questPurple)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(destination.name, style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
                      Text(destination.area, style: const TextStyle(color: Colors.white60))])),
                  Text('৳${destination.estimatedCost}', style: const TextStyle(
                      color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 10), Text(destination.description),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: plan.finalized ? null : () {
                    setState(() => nominated ? plan.nominations.remove(destination.id) :
                        plan.nominations.add(destination.id));
                    if (nominated) {
                      plan.votes[destination.activity]?.removeWhere((_, id) => id == destination.id);
                    }
                    QuestDemoStore.notify();
                  },
                  icon: Icon(nominated ? Icons.check_circle : Icons.add_circle_outline),
                  label: Text(nominated ? 'Nominated • remove' : 'Nominate for voting'))),
              ])));
          })),
        Padding(padding: const EdgeInsets.all(12), child: SizedBox(
          width: double.infinity, child: FilledButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => QuestVotingScreen(plan: plan))),
          child: const Text('Continue to voting')))),
      ]),
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
  String participant = 'You';
  final participants = const ['You', 'Friend 1', 'Friend 2', 'Friend 3'];
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Scaffold(appBar: AppBar(title: const Text('Group voting')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Demo: switch participant to simulate multiple group members.',
            style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: participant,
          decoration: const InputDecoration(labelText: 'Voting as'),
          items: participants.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (p) => setState(() => participant = p ?? 'You')),
        const SizedBox(height: 18),
        for (final activity in plan.activities) ...[
          _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            if (plan.nominationsFor(activity).isEmpty)
              const Text('No destinations nominated yet. Go back to Explore.',
                  style: TextStyle(color: Colors.white60)),
            for (final destination in plan.nominationsFor(activity))
              RadioListTile<int>(dense: true,
                title: Text(destination.name),
                subtitle: Text('${destination.area} • ৳${destination.estimatedCost}  •  '
                  '${plan.votes[activity]?.values.where((v) => v == destination.id).length ?? 0} votes'),
                value: destination.id,
                groupValue: plan.votes[activity]?[participant],
                onChanged: plan.finalized ? null : (id) {
                  if (id == null) return;
                  setState(() => plan.votes.putIfAbsent(activity, () => {})[participant] = id);
                  QuestDemoStore.notify();
                },
                activeColor: questPurple),
          ])),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => FinalQuestScreen(plan: plan))),
          icon: const Icon(Icons.visibility), label: const Text('View results / final plan')),
      ]),
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
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final complete = plan.activities.every((a) => plan.nominationsFor(a).isNotEmpty &&
      (plan.votes[a]?.isNotEmpty ?? false));
    return Scaffold(appBar: AppBar(title: const Text('Final hangout plan')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Icon(plan.finalized ? Icons.verified : Icons.event_note,
            size: 56, color: questPurple),
        const SizedBox(height: 12),
        Text(plan.title, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(questDateLabel(plan.proposedDateTime), textAlign: TextAlign.center),
        Text('Budget: ৳${plan.budget} per person', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        for (final activity in plan.activities) ...[
          _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity.toUpperCase(), style: const TextStyle(
                color: questPurple, fontWeight: FontWeight.bold)),
            const SizedBox(height: 7),
            Text(plan.winnerFor(activity)?.name ?? 'No destination nominated',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (plan.winnerFor(activity) case final winner?)
              Text('${winner.area} • estimated ৳${winner.estimatedCost} per person'),
            Text('${plan.votes[activity]?.length ?? 0} votes submitted',
                style: const TextStyle(color: Colors.white60)),
          ])),
          const SizedBox(height: 12),
        ],
        if (!plan.finalized) ...[
          const Text('Results use most votes per category. Ties use destination ID order.',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: complete ? () {
              setState(() => plan.finalized = true);
              QuestDemoStore.notify();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('SideQuest confirmed in this demo!')));
            } : null,
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirm final hangout plan')),
          if (!complete) const Padding(padding: EdgeInsets.only(top: 12),
            child: Text('Nominate and vote on at least one destination in every activity to confirm.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.amber))),
        ] else const Center(child: Chip(label: Text('✓ Confirmed'))),
        const SizedBox(height: 16),
        const Text('Note: This is an in-memory frontend demo, not a synced group itinerary.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

Widget _panel(Widget child) => Container(padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(color: questCard,
      borderRadius: BorderRadius.circular(18)), child: child);

Widget _stepTile(BuildContext context, IconData icon, String title,
    String description, VoidCallback onTap) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Material(color: questCard, borderRadius: BorderRadius.circular(18),
    child: ListTile(contentPadding: const EdgeInsets.all(14),
      leading: Icon(icon, color: questPurple), title: Text(title),
      subtitle: Text(description), trailing: const Icon(Icons.chevron_right),
      onTap: onTap)));
