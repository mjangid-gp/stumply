import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
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
}
