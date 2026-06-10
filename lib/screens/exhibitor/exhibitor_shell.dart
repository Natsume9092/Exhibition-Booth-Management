import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_sheet.dart';

class ExhibitorShell extends ConsumerWidget {
  final Widget child;
  const ExhibitorShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    final location = GoRouterState.of(context).uri.path;

    int currentIndex = 0;
    if (location.contains('/applications')) currentIndex = 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exhibitor Portal'),
        actions: [
          // Tapping the avatar opens the profile sheet, where the user can
          // upload a profile picture. The avatar itself also shows that
          // picture once it has been uploaded.
          IconButton(
            icon: profileAvatar(user, radius: 18, background: Colors.white24),
            tooltip: 'Profile',
            onPressed: () => showProfileSheet(
              context,
              roleLabel: 'Exhibitor',
              roleColor: AppTheme.accentColor,
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/exhibitor');
          if (i == 1) context.go('/exhibitor/applications');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore), label: 'Exhibitions'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'My Applications'),
        ],
      ),
    );
  }
}
