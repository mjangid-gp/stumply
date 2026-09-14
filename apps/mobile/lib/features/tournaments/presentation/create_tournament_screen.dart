import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../data/tournament_repository.dart';

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends ConsumerState<CreateTournamentScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _descController = TextEditingController();
  String _format = 'round_robin';
  int _overs = 20;
  bool _homeVsAway = false;
  bool _loading = false;

  Future<void> _create() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _loading = true);
    final tournament = await ref.read(tournamentRepositoryProvider).createTournament(
      name: _nameController.text.trim(),
      organizerId: user.uid,
      description: _descController.text.trim(),
      format: _format,
      city: _cityController.text.trim(),
      totalOvers: _overs,
      homeVsAway: _homeVsAway,
      startDate: DateTime.now(),
    );
    if (mounted) {
      setState(() => _loading = false);
      context.go('/tournaments/${tournament.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tournament')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Tournament Name')),
          const SizedBox(height: 12),
          TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 12),
          TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _format,
            decoration: const InputDecoration(labelText: 'Format'),
            items: const [
              DropdownMenuItem(value: 'round_robin', child: Text('Round Robin')),
              DropdownMenuItem(value: 'knockout', child: Text('Knockout')),
            ],
            onChanged: (v) => setState(() => _format = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _overs,
            decoration: const InputDecoration(labelText: 'Overs per match'),
            items: [10, 15, 20].map((o) => DropdownMenuItem(value: o, child: Text('$o'))).toList(),
            onChanged: (v) => setState(() => _overs = v!),
          ),
          SwitchListTile(
            title: const Text('Home vs Away'),
            value: _homeVsAway,
            onChanged: (v) => setState(() => _homeVsAway = v),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _create,
            child: _loading ? const CircularProgressIndicator() : const Text('Create Tournament'),
          ),
        ],
      ),
    );
  }
}
