import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/cosmos_colors.dart';

const _destinations = [
  (Icons.rocket_launch_outlined, Icons.rocket_launch, 'Home'),
  (Icons.photo_library_outlined, Icons.photo_library, 'Gallery'),
  (Icons.public_outlined, Icons.public, 'Planets'),
  (Icons.star_outline, Icons.star, 'Favorites'),
];

/// Responsive navigation: bottom bar on phones, navigation rail on tablets / desktop browsers.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: CosmosColors.midnightPurple,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('COSMOS',
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: CosmosColors.starYellow)),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3)),
              ],
            ),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
                icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
