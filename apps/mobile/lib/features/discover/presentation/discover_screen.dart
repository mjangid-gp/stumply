import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
  List<NearbyGround> _nearbyGrounds = const [];
  bool _searching = false;
  bool _loadingGrounds = false;
  bool _hasSearched = false;
  String? _groundError;

  DiscoverRepository get _repository => ref.read(discoverRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNearbyGrounds());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _hasSearched = true;
    });
    try {
      final results = await _repository.search(query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadNearbyGrounds() async {
    setState(() {
      _loadingGrounds = true;
      _groundError = null;
    });
    try {
      final position = await _repository.getCurrentPosition();
      final grounds = await _repository.findNearbyCricketGrounds(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) setState(() => _nearbyGrounds = grounds);
    } catch (_) {
      if (mounted) {
        setState(
          () => _groundError =
              'Location permission or location service is required for nearby grounds.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingGrounds = false);
    }
  }

  Future<void> _openGround(NearbyGround ground) async {
    final uri = Uri.tryParse(ground.sourceUrl ?? '');
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
            subtitle: 'Players, teams, grounds & cricket around you',
            leading: const DrawerMenuButton(),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search players, teams, tournaments...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _search,
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _hasSearched
                ? _buildSearchResults(user)
                : _buildDiscoverHome(user),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverHome(dynamic user) {
    return RefreshIndicator(
      onRefresh: _loadNearbyGrounds,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cricket Grounds Near You',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Refresh location',
                onPressed: _loadingGrounds ? null : _loadNearbyGrounds,
                icon: const Icon(Icons.my_location),
              ),
            ],
          ),
          Text(
            'Powered by OpenStreetMap community data',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          if (_loadingGrounds)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_groundError != null)
            CrickCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off_outlined,
                    color: AppColors.cricketRed,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_groundError!)),
                  TextButton(
                    onPressed: _loadNearbyGrounds,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_nearbyGrounds.isEmpty)
            const CrickCard(
              child: Text('No mapped cricket grounds were found within 10 km.'),
            )
          else
            ..._nearbyGrounds.map(
              (ground) =>
                  _GroundCard(ground: ground, onTap: () => _openGround(ground)),
            ),
          const SizedBox(height: 10),
          _QuickActionCard(
            icon: Icons.person_add_outlined,
            title: 'Looking for a match?',
            subtitle: 'Post or browse match opportunities',
            onTap: () => _showLookingForDialog(context, user?.uid),
          ),
          const SizedBox(height: 4),
          const Text(
            '© OpenStreetMap contributors · Data available under the Open Database License (ODbL)',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(dynamic user) {
    if (_results.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off,
        title: 'No results found',
        message: 'Try a different search term.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final r = _results[i];
        final type = r['type'] as String?;
        return CrickCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  _iconForType(type),
                  color: AppColors.primary,
                  size: 20,
                ),
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
                      _typeLabel(type),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (user != null)
                IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: () => _repository.follow(
                    user.uid,
                    r['id'] as String,
                    type ?? 'player',
                  ),
                ),
            ],
          ),
        );
      },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _repository.postLookingFor(
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

class _GroundCard extends StatelessWidget {
  const _GroundCard({required this.ground, required this.onTap});
  final NearbyGround ground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CrickCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.sports_cricket, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ground.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (ground.address != null) ground.address!,
                    ground.distanceLabel,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.open_in_new,
            size: 18,
            color: AppColors.textSecondary,
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
