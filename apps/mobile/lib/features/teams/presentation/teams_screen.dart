import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../data/team_repository.dart';

class TeamsScreen extends ConsumerWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold(body: Center(child: Text('Login required')));

    final teamsStream = ref.watch(teamRepositoryProvider).watchUserTeams(user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('My Teams')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/teams/create'),
        icon: const Icon(Icons.add),
        label: const Text('Add Team'),
      ),
      body: StreamBuilder(
        stream: teamsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final teams = snapshot.data ?? [];
          if (teams.isEmpty) {
            return const Center(child: Text('No teams yet. Create your first team!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (context, i) {
              final team = teams[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(team.name[0])),
                  title: Text(team.name),
                  subtitle: Text('${team.memberCount} players · ${team.city}'),
                  trailing: team.captainId == user.uid ? const Chip(label: Text('Captain')) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
