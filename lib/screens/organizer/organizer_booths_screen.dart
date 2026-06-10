import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class OrganizerBoothsScreen extends ConsumerWidget {
  final String exhibitionId;
  const OrganizerBoothsScreen({super.key, required this.exhibitionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boothsAsync = ref.watch(boothsProvider(exhibitionId));
    final exhibitionAsync = ref.watch(exhibitionDetailProvider(exhibitionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(exhibitionAsync.valueOrNull?.title ?? 'Booth Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Booth',
            onPressed: () => _showBoothForm(context, ref, null),
          ),
        ],
      ),
      body: boothsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorWidget2(message: e.toString()),
        data: (booths) {
          if (booths.isEmpty) return EmptyState(
            message: 'No booths yet. Add booths to this exhibition.',
            icon: Icons.store_mall_directory_outlined,
            actionLabel: 'Add Booth',
            onAction: () => _showBoothForm(context, ref, null),
          );

          // Stats row
          final available = booths.where((b) => b.status == BoothStatus.available).length;
          final booked = booths.where((b) => b.status == BoothStatus.booked).length;
          final pending = booths.where((b) => b.status == BoothStatus.pending).length;

          return Column(children: [
            // Stats
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _StatChip(label: 'Total', count: booths.length, color: Colors.grey),
                const SizedBox(width: 8),
                _StatChip(label: 'Available', count: available, color: AppTheme.boothAvailable),
                const SizedBox(width: 8),
                _StatChip(label: 'Booked', count: booked, color: AppTheme.boothBooked),
                const SizedBox(width: 8),
                _StatChip(label: 'Pending', count: pending, color: AppTheme.boothPending),
              ]),
            ),
            // Booth list
            Expanded(
              child: ListView.builder(
                itemCount: booths.length,
                itemBuilder: (ctx, i) {
                  final booth = booths[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: _colorForStatus(booth.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _colorForStatus(booth.status)),
                        ),
                        child: Center(child: Text(booth.boothNumber,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center)),
                      ),
                      title: Text('${booth.boothType} – ${booth.boothNumber}'),
                      subtitle: Text('${booth.sizeqm} sqm • RM ${booth.price.toStringAsFixed(0)} • ${booth.amenities.join(', ')}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        StatusChip(
                          label: booth.status.name[0].toUpperCase() + booth.status.name.substring(1),
                          color: _colorForStatus(booth.status),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'edit') _showBoothForm(context, ref, booth);
                            if (action == 'delete') _deleteBooth(context, ref, booth);
                            if (action == 'toggle') _toggleAvailability(ref, booth);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(booth.status == BoothStatus.unavailable ? 'Mark Available' : 'Mark Unavailable'),
                            ),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }

  Color _colorForStatus(BoothStatus status) => switch (status) {
    BoothStatus.available => AppTheme.boothAvailable,
    BoothStatus.booked => AppTheme.boothBooked,
    BoothStatus.pending => AppTheme.boothPending,
    BoothStatus.unavailable => Colors.grey,
  };

  void _showBoothForm(BuildContext context, WidgetRef ref, Booth? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BoothForm(exhibitionId: exhibitionId, existing: existing, ref: ref),
      ),
    );
  }

  Future<void> _deleteBooth(BuildContext context, WidgetRef ref, Booth booth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Delete Booth',
        message: 'Delete booth ${booth.boothNumber}?',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
      ),
    );
    if (confirm != true) return;
    await ref.read(dbProvider).deleteBooth(booth.id);
    ref.invalidate(boothsProvider(exhibitionId));
  }

  Future<void> _toggleAvailability(WidgetRef ref, Booth booth) async {
    final newStatus = booth.status == BoothStatus.unavailable
      ? BoothStatus.available : BoothStatus.unavailable;
    await ref.read(dbProvider).updateBooth(booth.copyWith(status: newStatus));
    ref.invalidate(boothsProvider(exhibitionId));
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ]),
    ),
  );
}

class _BoothForm extends StatefulWidget {
  final String exhibitionId;
  final Booth? existing;
  final WidgetRef ref;
  const _BoothForm({required this.exhibitionId, this.existing, required this.ref});

  @override
  State<_BoothForm> createState() => _BoothFormState();
}

class _BoothFormState extends State<_BoothForm> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  String _type = 'Standard';
  final Set<String> _amenities = {};
  bool _saving = false;

  final _types = ['Economy', 'Standard', 'Premium'];
  final _amenityOptions = ['Power', 'WiFi', 'Corner', 'Extra Display', 'Storage'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _numberCtrl.text = widget.existing!.boothNumber;
      _priceCtrl.text = widget.existing!.price.toStringAsFixed(0);
      _sizeCtrl.text = widget.existing!.sizeqm.toStringAsFixed(0);
      _type = widget.existing!.boothType;
      _amenities.addAll(widget.existing!.amenities);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.existing != null ? 'Edit Booth' : 'Add Booth',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(children: [
            Row(children: [
              Expanded(child: TextFormField(
                controller: _numberCtrl,
                decoration: const InputDecoration(labelText: 'Booth Number *'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v ?? 'Standard'),
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (RM) *', prefixText: 'RM '),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _sizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Size (sqm) *', suffixText: 'sqm'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              )),
            ]),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft,
              child: const Text('Amenities:', style: TextStyle(fontWeight: FontWeight.w500))),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: _amenityOptions.map((a) => FilterChip(
                label: Text(a),
                selected: _amenities.contains(a),
                onSelected: (v) => setState(() { if (v) _amenities.add(a); else _amenities.remove(a); }),
              )).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.existing != null ? 'Save Changes' : 'Add Booth'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = widget.ref.read(dbProvider);
      final booth = Booth(
        id: widget.existing?.id ?? '',
        exhibitionId: widget.exhibitionId,
        boothNumber: _numberCtrl.text.trim(),
        boothType: _type,
        sizeqm: double.tryParse(_sizeCtrl.text) ?? 16,
        price: double.tryParse(_priceCtrl.text) ?? 1000,
        status: widget.existing?.status ?? BoothStatus.available,
        x: widget.existing?.x ?? 0,
        y: widget.existing?.y ?? 0,
        width: widget.existing?.width ?? 100,
        height: widget.existing?.height ?? 100,
        amenities: _amenities.toList(),
      );
      if (widget.existing != null) {
        await db.updateBooth(booth);
      } else {
        await db.createBooth(booth);
      }
      widget.ref.invalidate(boothsProvider(widget.exhibitionId));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
