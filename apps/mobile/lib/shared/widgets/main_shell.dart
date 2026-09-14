import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  static final scaffoldKey = GlobalKey<ScaffoldState>();
  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/tournaments')) return 1;
    if (location.startsWith('/discover')) return 2;
    if (location.startsWith('/feed')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);

    return Scaffold(
      key: scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(gradient: AppTheme.headerGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.sports_cricket, color: AppColors.accent, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppConstants.appName,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppConstants.appTagline,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              _DrawerTile(
                icon: Icons.sports_cricket_outlined,
                label: 'My Cricket',
                selected: index == 0,
                onTap: () => _go(context, '/'),
              ),
              _DrawerTile(
                icon: Icons.emoji_events_outlined,
                label: 'Tournaments',
                selected: index == 1,
                onTap: () => _go(context, '/tournaments'),
              ),
              _DrawerTile(
                icon: Icons.explore_outlined,
                label: 'Discover',
                selected: index == 2,
                onTap: () => _go(context, '/discover'),
              ),
              _DrawerTile(
                icon: Icons.article_outlined,
                label: 'Feed',
                selected: index == 3,
                onTap: () => _go(context, '/feed'),
              ),
              _DrawerTile(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: index == 4,
                onTap: () => _go(context, '/profile'),
              ),
              const Divider(),
              _DrawerTile(
                icon: Icons.videocam_outlined,
                label: 'Broadcast Studio',
                selected: location.startsWith('/broadcast'),
                onTap: () => _go(context, '/broadcast'),
              ),
              _DrawerTile(
                icon: Icons.groups_outlined,
                label: 'My Teams',
                onTap: () => _go(context, '/teams'),
              ),
              _DrawerTile(
                icon: Icons.insights_outlined,
                label: 'CricInsights',
                onTap: () => _go(context, '/analytics'),
              ),
              _DrawerTile(
                icon: Icons.workspace_premium_outlined,
                label: 'PRO Club',
                onTap: () => _go(context, '/pro'),
              ),
              _DrawerTile(
                icon: Icons.storefront_outlined,
                label: 'Store',
                onTap: () => _go(context, '/store'),
              ),
            ],
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            height: 64,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: index,
            onDestinationSelected: (i) {
              switch (i) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/tournaments');
                case 2:
                  context.go('/discover');
                case 3:
                  context.go('/feed');
                case 4:
                  context.go('/profile');
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.sports_cricket_outlined),
                selectedIcon: Icon(Icons.sports_cricket),
                label: 'My Cricket',
              ),
              NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'Tournaments',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Discover',
              ),
              NavigationDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: 'Feed',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, String path) {
    Navigator.of(context).pop();
    context.go(path);
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}
