import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class ExhibitorExhibitionsScreen extends ConsumerStatefulWidget {
  const ExhibitorExhibitionsScreen({super.key});
  @override
  ConsumerState<ExhibitorExhibitionsScreen> createState() => _ExhibitorExhibitionsScreenState();
}

class _ExhibitorExhibitionsScreenState extends ConsumerState<ExhibitorExhibitionsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  ExhibitionStatus? _status;

  @override
  Widget build(BuildContext context) {
    final filter = ExhibitionFilter(search: _search, status: _status);
    final exhibitionsAsync = ref.watch(exhibitionsProvider(filter));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search exhibitions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                : null,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              FilterChip(label: const Text('All'), selected: _status == null,
                onSelected: (_) => setState(() => _status = null)),
              const SizedBox(width: 8),
              ...ExhibitionStatus.values.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = _status == s ? null : s),
                ),
              )),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: exhibitionsAsync.when(
          loading: () => const LoadingWidget(message: 'Loading exhibitions...'),
          error: (e, _) => ErrorWidget2(message: e.toString()),
          data: (exhibitions) {
            if (exhibitions.isEmpty) return EmptyState(
              message: 'No exhibitions available',
              icon: Icons.event_busy,
            );
            return ListView.builder(
              itemCount: exhibitions.length,
              itemBuilder: (ctx, i) {
                final e = exhibitions[i];
                return ExhibitionCard(
                  exhibition: e,
                  onTap: () => context.push('/exhibitor/floor-plan/${e.id}'),
                  actions: [
                    ElevatedButton.icon(
                      onPressed: e.availableBooths > 0
                          ? () => context.push('/exhibitor/floor-plan/${e.id}')
                          : null,
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('View Floor Plan'),
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
}
