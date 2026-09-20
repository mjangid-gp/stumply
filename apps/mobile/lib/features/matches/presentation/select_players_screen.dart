import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/match_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/models/player.dart';
import '../../../shared/models/team.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../players/data/player_repository.dart';
import '../../teams/data/team_repository.dart';
import '../data/match_repository.dart';

class SelectPlayersScreen extends ConsumerStatefulWidget {
  const SelectPlayersScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<SelectPlayersScreen> createState() =>
      _SelectPlayersScreenState();
}

class _SelectPlayersScreenState extends ConsumerState<SelectPlayersScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  MatchModel? _match;
  Team? _teamA;
  Team? _teamB;

  List<Player> _teamAPlayers = [];
  List<Player> _teamBPlayers = [];

  final Set<String> _selectedA = <String>{};
  final Set<String> _selectedB = <String>{};

  String? _captainA;
  String? _captainB;
  String? _keeperA;
  String? _keeperB;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final match = await ref
          .read(matchRepositoryProvider)
          .watchMatch(widget.matchId)
          .first;
      if (match == null) throw StateError('Match not found.');

      final teamRepository = ref.read(teamRepositoryProvider);
      final playerRepository = ref.read(playerRepositoryProvider);

      final results = await Future.wait([
        teamRepository.getTeam(match.teamAId),
        teamRepository.getTeam(match.teamBId),
        playerRepository.getPlayersByIds([
          ...match.teamAPlayers,
          ...match.teamBPlayers,
        ]),
      ]);

      final teamA = results[0] as Team?;
      final teamB = results[1] as Team?;
      final selectedPlayers = results[2] as List<Player>;

      if (teamA == null || teamB == null) {
        throw StateError('Could not load both teams.');
      }

      final rosterA = await playerRepository.getPlayersByIds(teamA.memberIds);
      final rosterB = await playerRepository.getPlayersByIds(teamB.memberIds);

      final selectedById = {
        for (final player in selectedPlayers) player.id: player,
      };

      final mergedA = <String, Player>{
        for (final player in rosterA) player.id: player,
      };
      final mergedB = <String, Player>{
        for (final player in rosterB) player.id: player,
      };

      for (final id in match.teamAPlayers) {
        final player = selectedById[id];
        if (player != null) mergedA[id] = player;
      }
      for (final id in match.teamBPlayers) {
        final player = selectedById[id];
        if (player != null) mergedB[id] = player;
      }

      if (!mounted) return;

      setState(() {
        _match = match;
        _teamA = teamA;
        _teamB = teamB;
        _teamAPlayers = mergedA.values.toList();
        _teamBPlayers = mergedB.values.toList();

        _selectedA.addAll(match.teamAPlayers.where(mergedA.containsKey));
        _selectedB.addAll(match.teamBPlayers.where(mergedB.containsKey));

        _captainA = match.captainAId;
        _captainB = match.captainBId;
        _keeperA = match.wicketkeeperAId;
        _keeperB = match.wicketkeeperBId;

        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _createGuestPlayer(bool teamA) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${teamA ? _teamA?.name : _teamB?.name} player'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Player name',
            hintText: 'e.g. Rahul Sharma',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('Add Player'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.trim().isEmpty || !mounted) return;

    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) return;

    try {
      final player = await ref
          .read(playerRepositoryProvider)
          .createGuestPlayer(displayName: name, createdBy: authUser.uid);

      setState(() {
        if (teamA) {
          _teamAPlayers = [..._teamAPlayers, player];
          _selectedA.add(player.id);
        } else {
          _teamBPlayers = [..._teamBPlayers, player];
          _selectedB.add(player.id);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add player: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (_selectedA.length != 11 || _selectedB.length != 11) {
      setState(() {
        _error = 'Select exactly 11 starting players for each team.';
      });
      return;
    }

    if (_captainA == null ||
        _captainB == null ||
        _keeperA == null ||
        _keeperB == null) {
      setState(() {
        _error = 'Select captain and wicketkeeper for both teams.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(matchRepositoryProvider)
          .updateSquad(
            matchId: widget.matchId,
            teamAPlayers: _selectedA.toList(),
            teamBPlayers: _selectedB.toList(),
            captainAId: _captainA!,
            captainBId: _captainB!,
            wicketkeeperAId: _keeperA!,
            wicketkeeperBId: _keeperB!,
          );

      if (mounted) {
        context.go('/matches/${widget.matchId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null && _match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Players')),
        body: EmptyStateView(
          icon: Icons.error_outline,
          title: 'Could not load match',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Players'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_match!.teamAName} vs ${_match!.teamBName}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select the starting XI for both teams. You can add a guest player if they do not have a Stumply account.',
          ),
          const SizedBox(height: 20),
          _TeamSquadCard(
            teamName: _match!.teamAName,
            players: _teamAPlayers,
            selected: _selectedA,
            captainId: _captainA,
            wicketkeeperId: _keeperA,
            onToggle: (id) => _toggle(id, true),
            onCaptainChanged: (id) => setState(() => _captainA = id),
            onKeeperChanged: (id) => setState(() => _keeperA = id),
            onAddPlayer: () => _createGuestPlayer(true),
          ),
          const SizedBox(height: 16),
          _TeamSquadCard(
            teamName: _match!.teamBName,
            players: _teamBPlayers,
            selected: _selectedB,
            captainId: _captainB,
            wicketkeeperId: _keeperB,
            onToggle: (id) => _toggle(id, false),
            onCaptainChanged: (id) => setState(() => _captainB = id),
            onKeeperChanged: (id) => setState(() => _keeperB = id),
            onAddPlayer: () => _createGuestPlayer(false),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_saving ? 'Saving...' : 'Save Squad & Continue'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _toggle(String playerId, bool teamA) {
    final selected = teamA ? _selectedA : _selectedB;

    setState(() {
      if (selected.contains(playerId)) {
        selected.remove(playerId);
        if (teamA) {
          if (_captainA == playerId) _captainA = null;
          if (_keeperA == playerId) _keeperA = null;
        } else {
          if (_captainB == playerId) _captainB = null;
          if (_keeperB == playerId) _keeperB = null;
        }
        return;
      }

      if (selected.length >= 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting XI already has 11 players.')),
        );
        return;
      }

      selected.add(playerId);
    });
  }
}

class _TeamSquadCard extends StatelessWidget {
  const _TeamSquadCard({
    required this.teamName,
    required this.players,
    required this.selected,
    required this.captainId,
    required this.wicketkeeperId,
    required this.onToggle,
    required this.onCaptainChanged,
    required this.onKeeperChanged,
    required this.onAddPlayer,
  });

  final String teamName;
  final List<Player> players;
  final Set<String> selected;
  final String? captainId;
  final String? wicketkeeperId;
  final ValueChanged<String> onToggle;
  final ValueChanged<String?> onCaptainChanged;
  final ValueChanged<String?> onKeeperChanged;
  final VoidCallback onAddPlayer;

  @override
  Widget build(BuildContext context) {
    final selectedPlayers = players
        .where((player) => selected.contains(player.id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    teamName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(label: Text('${selected.length}/11')),
              ],
            ),
            const SizedBox(height: 8),
            if (players.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No registered players in this team yet.'),
              ),
            ...players.map(
              (player) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected.contains(player.id),
                onChanged: (_) => onToggle(player.id),
                title: Text(player.displayName),
                subtitle: Text(
                  [
                    if (player.battingStyle.isNotEmpty) player.battingStyle,
                    if (player.bowlingStyle.isNotEmpty) player.bowlingStyle,
                    if (player.isGuest) 'Guest player',
                  ].join(' · '),
                ),
                secondary: player.isGuest
                    ? const Icon(Icons.person_outline)
                    : const Icon(Icons.account_circle_outlined),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAddPlayer,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Player'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selected.any((id) => id == captainId)
                  ? captainId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Captain',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: selectedPlayers
                  .map(
                    (player) => DropdownMenuItem(
                      value: player.id,
                      child: Text(player.displayName),
                    ),
                  )
                  .toList(),
              onChanged: selectedPlayers.isEmpty ? null : onCaptainChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selected.any((id) => id == wicketkeeperId)
                  ? wicketkeeperId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Wicketkeeper',
                prefixIcon: Icon(Icons.sports_cricket),
              ),
              items: selectedPlayers
                  .map(
                    (player) => DropdownMenuItem(
                      value: player.id,
                      child: Text(player.displayName),
                    ),
                  )
                  .toList(),
              onChanged: selectedPlayers.isEmpty ? null : onKeeperChanged,
            ),
          ],
        ),
      ),
    );
  }
}
