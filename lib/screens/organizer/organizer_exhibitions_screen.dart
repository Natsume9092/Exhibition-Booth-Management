import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class OrganizerExhibitionsScreen extends ConsumerWidget {
  const OrganizerExhibitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exhibitionsAsync = ref.watch(exhibitionsProvider(const ExhibitionFilter()));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(exhibitionsProvider(const ExhibitionFilter())),
      child: exhibitionsAsync.when(
        loading: () => const LoadingWidget(message: 'Loading your exhibitions...'),
        error: (e, _) => ErrorWidget2(message: e.toString()),
        data: (exhibitions) {
          if (exhibitions.isEmpty) return EmptyState(
            message: 'No exhibitions yet.\nCreate your first exhibition!',
            icon: Icons.event_note,
            actionLabel: 'Create Exhibition',
            onAction: () => context.push('/organizer/exhibition/new'),
          );

          return ListView.builder(
            itemCount: exhibitions.length,
            itemBuilder: (ctx, i) {
              final e = exhibitions[i];
              return ExhibitionCard(
                exhibition: e,
                onTap: () => context.push('/organizer/booths/${e.id}'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.map_outlined, size: 20),
                    tooltip: 'Manage Booths',
                    onPressed: () => context.push('/organizer/booths/${e.id}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.assignment_outlined, size: 20),
                    tooltip: 'Applications',
                    onPressed: () => context.push('/organizer/applications/${e.id}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit',
                    onPressed: () => context.push('/organizer/exhibition/edit/${e.id}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _confirmDelete(context, ref, e),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Exhibition exhibition) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Delete Exhibition',
        message: 'Are you sure you want to delete "${exhibition.title}"? This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
      ),
    );
    if (confirm != true) return;
    await ref.read(dbProvider).deleteExhibition(exhibition.id);
    ref.invalidate(exhibitionsProvider(const ExhibitionFilter()));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exhibition deleted')),
    );
  }
}
