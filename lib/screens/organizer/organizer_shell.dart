import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_sheet.dart';

class OrganizerShell extends ConsumerWidget {
  final Widget child;
  const OrganizerShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0;
    if (location.contains('/applications')) currentIndex = 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Exhibition',
            onPressed: () => context.push('/organizer/exhibition/new'),
          ),
          // Tap the avatar to open the profile sheet (upload a picture).
          IconButton(
            icon: profileAvatar(user, radius: 18, background: Colors.white24),
            tooltip: 'Profile',
            onPressed: () => showProfileSheet(
              context,
              roleLabel: 'Organizer',
              roleColor: AppTheme.secondaryColor,
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/organizer');
          if (i == 1) context.go('/organizer/applications');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event), label: 'My Exhibitions'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Applications'),
        ],
      ),
    );
  }
}
