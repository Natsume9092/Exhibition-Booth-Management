import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

/// Admin "Add-on Items" management page.
///
/// The Admin sets up the list of optional add-on items here (create / edit
/// / delete). Because the list is stored in ONE shared Firestore
/// collection, every other page (the exhibitor application form, the
/// application detail page) just READS this list and lets the user pick.
/// So once the Admin sets it up, no other page needs to define add-ons.
///
/// This screen has no Scaffold of its own - it is shown inside AdminShell,
/// which already provides the app bar and bottom navigation.
class AdminAddonsScreen extends ConsumerWidget {
  const AdminAddonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addItemsAsync = ref.watch(addItemsProvider);

    return Column(children: [
      // Header with the "New Item" button.
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Expanded(
            child: Text('Add-on Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () => _openForm(context, ref, null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Item'),
          ),
        ]),
      ),
      Expanded(
        child: addItemsAsync.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => ErrorWidget2(message: e.toString()),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                message:
                    'No add-on items yet.\nCreate items that exhibitors can choose.',
                icon: Icons.add_business_outlined,
                actionLabel: 'Create Item',
                onAction: () => _openForm(context, ref, null),
              );
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final item = items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0x1A00ACC1),
                      child: Icon(Icons.add_circle_outline,
                          color: AppTheme.accentColor),
                    ),
                    title: Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(item.description),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('RM ${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') _openForm(context, ref, item);
                          if (action == 'delete') _delete(context, ref, item);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  /// Opens the add / edit form in a bottom sheet.
  /// [existing] is null when creating a new item.
  void _openForm(BuildContext context, WidgetRef ref, AddItem? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddonForm(existing: existing, ref: ref),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AddItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Delete Add-on Item',
        message: 'Delete "${item.name}"? Exhibitors will no longer be able '
            'to choose it.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
      ),
    );
    if (confirm != true) return;
    await ref.read(dbProvider).deleteAddItem(item.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add-on item deleted')),
      );
    }
  }
}

/// The create / edit form for one add-on item.
class _AddonForm extends StatefulWidget {
  final AddItem? existing;
  final WidgetRef ref;
  const _AddonForm({required this.existing, required this.ref});

  @override
  State<_AddonForm> createState() => _AddonFormState();
}

class _AddonFormState extends State<_AddonForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the fields when editing an existing item.
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _descCtrl.text = widget.existing!.description;
      _priceCtrl.text = widget.existing!.price.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Form(
        key: _formKey,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(isEdit ? 'Edit Add-on Item' : 'New Add-on Item',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g. Extended WiFi (High Speed)',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Short description of the item',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price *',
                  prefixText: 'RM ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(isEdit ? 'Save Changes' : 'Create Item'),
                ),
              ),
            ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = widget.ref.read(dbProvider);
      final item = AddItem(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
      );
      if (widget.existing != null) {
        await db.updateAddItem(item);
      } else {
        await db.createAddItem(item);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
