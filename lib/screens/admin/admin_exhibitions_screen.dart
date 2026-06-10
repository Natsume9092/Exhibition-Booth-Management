import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class AdminExhibitionsScreen extends ConsumerStatefulWidget {
  const AdminExhibitionsScreen({super.key});
  @override
  ConsumerState<AdminExhibitionsScreen> createState() => _AdminExhibitionsScreenState();
}

class _AdminExhibitionsScreenState extends ConsumerState<AdminExhibitionsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final exhibitionsAsync = ref.watch(exhibitionsProvider(const ExhibitionFilter()));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search all exhibitions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                : null,
            ),
          )),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => context.push('/admin/exhibition/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
          ),
        ]),
      ),
      Expanded(
        child: exhibitionsAsync.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => ErrorWidget2(message: e.toString()),
          data: (exhibitions) {
            final filtered = _search.isEmpty ? exhibitions :
              exhibitions.where((e) => e.title.toLowerCase().contains(_search.toLowerCase()) ||
                e.venue.toLowerCase().contains(_search.toLowerCase()) ||
                e.organizerName.toLowerCase().contains(_search.toLowerCase())).toList();

            if (filtered.isEmpty) return EmptyState(
              message: 'No exhibitions found', icon: Icons.event_busy);

            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final e = filtered[i];
                return ExhibitionCard(
                  exhibition: e,
                  onTap: () => context.push('/admin/floor-plan/${e.id}'),
                  actions: [
                    // Publish toggle
                    Tooltip(
                      message: e.isPublished ? 'Unpublish' : 'Publish',
                      child: IconButton(
                        icon: Icon(e.isPublished ? Icons.visibility : Icons.visibility_off,
                          color: e.isPublished ? AppTheme.successColor : Colors.grey),
                        onPressed: () => _togglePublish(ref, e),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.map_outlined, size: 20),
                      tooltip: 'Floor Plan',
                      onPressed: () => context.push('/admin/floor-plan/${e.id}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => context.push('/admin/exhibition/edit/${e.id}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () => _delete(context, ref, e),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _togglePublish(WidgetRef ref, Exhibition exhibition) async {
    final updated = exhibition.copyWith(isPublished: !exhibition.isPublished);
    await ref.read(dbProvider).updateExhibition(updated);
    ref.invalidate(exhibitionsProvider(const ExhibitionFilter()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated.isPublished ? 'Exhibition published' : 'Exhibition unpublished')));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Exhibition exhibition) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Delete Exhibition',
        message: 'Permanently delete "${exhibition.title}" and all its booths?',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
      ),
    );
    if (confirm != true) return;
    await ref.read(dbProvider).deleteExhibition(exhibition.id);
    ref.invalidate(exhibitionsProvider(const ExhibitionFilter()));
  }
}
