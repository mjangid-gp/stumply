import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../auth/data/auth_repository.dart';
import '../../teams/data/team_repository.dart';
import '../data/match_repository.dart';

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  final _groundController = TextEditingController();
  int _overs = 20;
  String? _teamAId;
  String? _teamBId;
  String _teamAName = '';
  String _teamBName = '';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _groundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Match')),
      body: user == null
          ? const EmptyStateView(icon: Icons.login, title: 'Sign in required', message: 'Please sign in to create a match.')
          : StreamBuilder(
              stream: ref.watch(teamRepositoryProvider).watchUserTeams(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final teams = snapshot.data ?? [];
                if (teams.length < 2) {
                  return EmptyStateView(
                    icon: Icons.groups,
                    title: 'Need at least 2 teams',
                    message: 'Create two teams first, then you can schedule a match between them.',
                    actionLabel: 'Create Team',
                    onAction: () => context.push('/teams/create'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Match Setup',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select teams and match format',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Team A', prefixIcon: Icon(Icons.shield_outlined)),
                      items: teams.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _teamAId = v;
                          _teamAName = teams.firstWhere((t) => t.id == v).name;
                          if (_teamBId == v) _teamBId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Team B', prefixIcon: Icon(Icons.shield_outlined)),
                      items: teams
                          .where((t) => t.id != _teamAId)
                          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _teamBId = v;
                          _teamBName = teams.firstWhere((t) => t.id == v).name;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _groundController,
                      decoration: const InputDecoration(
                        labelText: 'Ground / Venue',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _overs,
                      decoration: const InputDecoration(labelText: 'Overs', prefixIcon: Icon(Icons.timer_outlined)),
                      items: [10, 15, 20, 30, 50].map((o) => DropdownMenuItem(value: o, child: Text('$o overs'))).toList(),
                      onChanged: (v) => setState(() => _overs = v!),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _loading || _teamAId == null || _teamBId == null ? null : () => _create(user.uid),
                      child: _loading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Create Match'),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _create(String userId) async {
    if (_teamAId == _teamBId) {
      setState(() => _error = 'Team A and Team B must be different.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final match = await ref.read(matchRepositoryProvider).createMatch(
        teamAId: _teamAId!,
        teamBId: _teamBId!,
        teamAName: _teamAName,
        teamBName: _teamBName,
        createdBy: userId,
        totalOvers: _overs,
        ground: _groundController.text.trim(),
      );
      if (mounted) context.go('/matches/${match.id}');
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to create match. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
