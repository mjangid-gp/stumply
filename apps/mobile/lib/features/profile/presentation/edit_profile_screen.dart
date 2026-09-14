import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  String _battingStyle = 'right';
  String _bowlingStyle = 'none';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile != null) {
        _nameController.text = profile.displayName;
        _cityController.text = profile.city;
        _bioController.text = profile.bio;
        _battingStyle = profile.battingStyle;
        _bowlingStyle = profile.bowlingStyle;
        setState(() {});
      }
    });
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    final profile = ref.read(currentUserProfileProvider).value;
    if (user == null || profile == null) return;
    setState(() => _saving = true);
    await ref.read(profileRepositoryProvider).updateProfile(
      user.uid,
      profile.copyWith(
        displayName: _nameController.text.trim(),
        city: _cityController.text.trim(),
        bio: _bioController.text.trim(),
        battingStyle: _battingStyle,
        bowlingStyle: _bowlingStyle,
      ),
    );
    if (mounted) {
      setState(() => _saving = false);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display Name')),
          const SizedBox(height: 12),
          TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 12),
          TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _battingStyle,
            decoration: const InputDecoration(labelText: 'Batting Style'),
            items: const [
              DropdownMenuItem(value: 'right', child: Text('Right Hand')),
              DropdownMenuItem(value: 'left', child: Text('Left Hand')),
            ],
            onChanged: (v) => setState(() => _battingStyle = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _bowlingStyle,
            decoration: const InputDecoration(labelText: 'Bowling Style'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('None')),
              DropdownMenuItem(value: 'fast', child: Text('Fast')),
              DropdownMenuItem(value: 'spin', child: Text('Spin')),
            ],
            onChanged: (v) => setState(() => _bowlingStyle = v!),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const CircularProgressIndicator() : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
