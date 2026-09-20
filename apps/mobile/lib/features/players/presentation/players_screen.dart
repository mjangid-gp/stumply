import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/player_repository.dart';

class PlayersScreen extends ConsumerStatefulWidget {
  const PlayersScreen({super.key});
  @override
  ConsumerState<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends ConsumerState<PlayersScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(playerRepositoryProvider).watchPlayers(query: _query);
    return Scaffold(
      appBar: AppBar(title: const Text('Players')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search player or city', border: OutlineInputBorder()),
          ),
        ),
        Expanded(child: StreamBuilder(
          stream: stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final players = snapshot.data!;
            if (players.isEmpty) return const Center(child: Text('No players found'));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = players[i];
                return Card(child: ListTile(
                  leading: CircleAvatar(child: Text(p.displayName.isEmpty ? '?' : p.displayName[0].toUpperCase())),
                  title: Text(p.displayName),
                  subtitle: Text('${p.city.isEmpty ? 'City not set' : p.city} · ${p.matches} matches · ${p.runs} runs · ${p.wickets} wickets'),
                  trailing: p.isGuest ? const Chip(label: Text('Guest')) : null,
                ));
              },
            );
          },
        )),
      ]),
    );
  }
}
