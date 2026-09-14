import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../data/team_repository.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _groundController = TextEditingController();
  bool _loading = false;

  Future<void> _create() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _loading = true);
    await ref.read(teamRepositoryProvider).createTeam(
      name: _nameController.text.trim(),
      captainId: user.uid,
      createdBy: user.uid,
      city: _cityController.text.trim(),
      homeGround: _groundController.text.trim(),
    );
    if (mounted) {
      setState(() => _loading = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Team')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Team Name')),
            const SizedBox(height: 12),
            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
            const SizedBox(height: 12),
            TextField(controller: _groundController, decoration: const InputDecoration(labelText: 'Home Ground')),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _create,
              child: _loading ? const CircularProgressIndicator() : const Text('Create Team'),
            ),
          ],
        ),
      ),
    );
  }
}
