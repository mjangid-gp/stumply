import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/cricket_avatar.dart';
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
  String? _photoUrl;
  bool _hydrated = false;
  bool _saving = false;
  String? _error;
  String? _status;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_hydrated) return;
    _nameController.text = profile.displayName;
    _cityController.text = profile.city;
    _bioController.text = profile.bio;
    _battingStyle = profile.battingStyle;
    _bowlingStyle = profile.bowlingStyle;
    _photoUrl = profile.photoUrl;
    _hydrated = true;
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 360,
        maxHeight: 360,
        imageQuality: 55,
      );
      if (file == null) return;
      final user = ref.read(authStateProvider).value;
      if (user == null) {
        setState(() => _error = 'Please sign in again, then choose a photo.');
        return;
      }
      setState(() {
        _saving = true;
        _error = null;
        _status = 'Saving photo...';
      });
      final bytes = await file.readAsBytes();
      final url = await ref.read(profileRepositoryProvider).saveGalleryPhoto(user.uid, bytes);
      await ref.read(profileRepositoryProvider).updatePhotoUrl(user.uid, url);
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _saving = false;
        _status = 'Photo saved.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = null;
        _error = 'Could not save gallery photo. ${error.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  Future<void> _selectCartoon(CricketAvatarOption option) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      setState(() => _error = 'Please sign in again, then pick an avatar.');
      return;
    }
    setState(() {
      _photoUrl = option.storageValue;
      _saving = true;
      _error = null;
      _status = 'Saving ${option.label} avatar...';
    });
    try {
      await ref.read(profileRepositoryProvider).updatePhotoUrl(user.uid, option.storageValue);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = '${option.label} avatar saved.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = null;
        _error = 'Could not save cartoon avatar. Please try again.';
      });
    }
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    final profile = ref.read(currentUserProfileProvider).value;
    if (user == null) {
      setState(() => _error = 'Please sign in again.');
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Display name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = (profile ??
              UserProfile(
                id: user.uid,
                displayName: _nameController.text.trim(),
                email: user.email,
              ))
          .copyWith(
            displayName: _nameController.text.trim(),
            city: _cityController.text.trim(),
            bio: _bioController.text.trim(),
            battingStyle: _battingStyle,
            bowlingStyle: _bowlingStyle,
            photoUrl: _photoUrl,
          );
      await ref.read(profileRepositoryProvider).updateProfile(user.uid, updated);
      if (mounted) context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).value;
    if (profile != null) {
      _hydrate(profile);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CricketAvatar(
              photoUrl: _photoUrl,
              radius: 48,
              name: _nameController.text,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_saving ? 'Please wait...' : 'Choose from gallery'),
          ),
          const SizedBox(height: 20),
          Text(
            'Cricket cartoons',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap a cartoon to apply it immediately.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: CricketAvatars.options.map((option) {
              final selected = _photoUrl == option.storageValue;
              return SizedBox(
                width: 92,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saving ? null : () => _selectCartoon(option),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? AppColors.accent : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: CricketAvatar(
                              photoUrl: option.storageValue,
                              radius: 36,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              color: selected ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display Name')),
          const SizedBox(height: 12),
          TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City')),
          const SizedBox(height: 12),
          TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _battingStyle,
            decoration: const InputDecoration(labelText: 'Batting Style'),
            items: const [
              DropdownMenuItem(value: 'right', child: Text('Right Hand')),
              DropdownMenuItem(value: 'left', child: Text('Left Hand')),
            ],
            onChanged: (v) => setState(() => _battingStyle = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _bowlingStyle,
            decoration: const InputDecoration(labelText: 'Bowling Style'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('None')),
              DropdownMenuItem(value: 'fast', child: Text('Fast')),
              DropdownMenuItem(value: 'spin', child: Text('Spin')),
            ],
            onChanged: (v) => setState(() => _bowlingStyle = v!),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!, style: const TextStyle(color: AppColors.success)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.cricketRed)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
