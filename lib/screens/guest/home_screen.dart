import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _category;
  ExhibitionStatus? _status;

  final _categories = ['Technology', 'Fashion', 'Energy', 'Food', 'Art', 'Health'];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final filter = ExhibitionFilter(search: _search, category: _category, status: _status);
    final exhibitionsAsync = ref.watch(exhibitionsProvider(filter));

    // Redirect logged-in users to their dashboards
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user != null && mounted) {
        switch (user.role) {
          case UserRole.exhibitor: context.go('/exhibitor'); break;
          case UserRole.organizer: context.go('/organizer'); break;
          case UserRole.admin: context.go('/admin'); break;
          default: break;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exhibition Hub'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/login'),
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('Login', style: TextStyle(color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: () => context.push('/register'),
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Register', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(children: [
        // Hero banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.accentColor],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(children: [
            const Text('Discover Exhibitions', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Browse trade shows and book your booth', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search exhibitions...',
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear),
                  onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
              ),
            ),
          ]),
        ),
        // Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            FilterChip(
              label: const Text('All'),
              selected: _status == null && _category == null,
              onSelected: (_) => setState(() { _status = null; _category = null; }),
            ),
            const SizedBox(width: 8),
            ...ExhibitionStatus.values.map((s) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = _status == s ? null : s),
              ),
            )),
            ..._categories.map((c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = _category == c ? null : c),
              ),
            )),
          ]),
        ),
        // Exhibition list
        Expanded(
          child: exhibitionsAsync.when(
            loading: () => const LoadingWidget(message: 'Loading exhibitions...'),
            error: (e, _) => ErrorWidget2(message: e.toString()),
            data: (exhibitions) {
              if (exhibitions.isEmpty) return EmptyState(
                message: 'No exhibitions found',
                icon: Icons.event_busy,
                actionLabel: 'Clear filters',
                onAction: () => setState(() { _search = ''; _category = null; _status = null; _searchCtrl.clear(); }),
              );
              return ListView.builder(
                itemCount: exhibitions.length,
                itemBuilder: (ctx, i) => ExhibitionCard(
                  exhibition: exhibitions[i],
                  onTap: () => context.push('/exhibition/${exhibitions[i].id}'),
                ),
              );
            },
          ),
        ),
        // CTA banner
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black, // <-- Changed to black background
          child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ready to book your booth?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white, // <-- Changed to white text color
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Get Started'),
            ),
          ]),
        ),
      ]),
    );
  }
}
