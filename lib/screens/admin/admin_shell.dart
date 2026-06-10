import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../widgets/profile_sheet.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  // The dark navy used across the whole Admin area.
  static const Color adminColor = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    final location = GoRouterState.of(context).uri.path;

    // Work out which bottom-nav tab is active from the current route.
    int currentIndex = 0;
    if (location.contains('/users')) currentIndex = 1;
    if (location.contains('/applications')) currentIndex = 2;
    if (location.contains('/addons')) currentIndex = 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: adminColor,
        actions: [
          IconButton(
            icon: profileAvatar(user,
                radius: 18,
                background: Colors.white24,
                fallbackIcon: Icons.admin_panel_settings),
            tooltip: 'Profile',
            onPressed: () => showProfileSheet(
              context,
              roleLabel: 'System Administrator',
              roleColor: adminColor,
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/admin');
          if (i == 1) context.go('/admin/users');
          if (i == 2) context.go('/admin/applications');
          if (i == 3) context.go('/admin/addons');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event), label: 'Exhibitions'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'All Bookings'),
          NavigationDestination(icon: Icon(Icons.add_business), label: 'Add-ons'),
        ],
      ),
    );
  }
}
