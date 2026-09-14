import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/crick_ui.dart';
import '../../auth/data/auth_repository.dart';
import '../data/discover_repository.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() { _searching = true; _hasSearched = true; });
    final results = await ref.read(discoverRepositoryProvider).search(query);
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          CrickGradientHeader(
            title: 'Discover',
            subtitle: 'Find players, teams & tournaments',
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search players, teams, tournaments...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _hasSearched
                ? _results.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.search_off,
                        title: 'No results found',
                        message: 'Try a different search term.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return CrickCard(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  child: Icon(_iconForType(r['type'] as String?), color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r['name'] ?? r['displayName'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        _typeLabel(r['type'] as String?),
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                if (user != null)
                                  IconButton(
                                    icon: const Icon(Icons.person_add_outlined),
                                    onPressed: () => ref.read(discoverRepositoryProvider).follow(
                                      user.uid,
                                      r['id'] as String,
                                      r['type'] as String? ?? 'player',
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _QuickActionCard(
                        icon: Icons.place_outlined,
                        title: 'Cricket Grounds',
                        subtitle: 'Find grounds near you',
                        onTap: () {},
                      ),
                      _QuickActionCard(
                        icon: Icons.person_add_outlined,
                        title: 'Looking for a match?',
                        subtitle: 'Post or browse match opportunities',
                        onTap: () => _showLookingForDialog(context, user?.uid),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'teams':
        return Icons.groups;
      case 'tournaments':
        return Icons.emoji_events;
      case 'grounds':
        return Icons.place;
      default:
        return Icons.person;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'teams':
        return 'Team';
      case 'tournaments':
        return 'Tournament';
      case 'grounds':
        return 'Ground';
      case 'players':
        return 'Player';
      default:
        return type ?? 'Unknown';
    }
  }

  void _showLookingForDialog(BuildContext context, String? userId) {
    if (userId == null) return;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Looking for Match'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(discoverRepositoryProvider).postLookingFor(
                authorId: userId,
                title: titleController.text,
                description: descController.text,
                city: '',
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post created successfully!')),
                );
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CrickCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
