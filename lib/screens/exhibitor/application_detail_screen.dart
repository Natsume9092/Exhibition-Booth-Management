import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

/// One application, taken from the live "my applications" stream so this
/// screen updates in real time (for example when an organizer approves
/// or rejects it while the exhibitor is looking at it).
final _applicationDetailProvider =
    Provider.family<AsyncValue<BoothApplication?>, String>((ref, id) {
  return ref.watch(myApplicationsProvider).whenData((apps) {
    for (final a in apps) {
      if (a.id == id) return a;
    }
    return null;
  });
});

class ApplicationDetailScreen extends ConsumerStatefulWidget {
  final String applicationId;
  const ApplicationDetailScreen({super.key, required this.applicationId});
  @override
  ConsumerState<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends ConsumerState<ApplicationDetailScreen> {
  bool _editing = false;
  final _companyDescCtrl = TextEditingController();
  final _exhibitDescCtrl = TextEditingController();
  // Add-on items the exhibitor has ticked while editing.
  final Set<String> _selectedAddItemIds = {};
  // Booths the exhibitor has ticked while editing (lets them re-select
  // their "Booked Booths" - they could not change this before).
  final Set<String> _selectedBoothIds = {};
  bool _saving = false;
  final _fmt = DateFormat('dd MMM yyyy HH:mm');

  /// Fills the edit fields from the current application and turns edit
  /// mode ON. The sets are cleared first so no stale data is carried over.
  void _startEditing(BoothApplication application) {
    setState(() {
      _editing = true;
      _companyDescCtrl.text = application.companyDescription;
      _exhibitDescCtrl.text = application.exhibitDescription;
      _selectedAddItemIds
        ..clear()
        ..addAll(application.selectedAddItemIds);
      _selectedBoothIds
        ..clear()
        ..addAll(application.boothIds);
    });
  }

  /// Live total while editing = chosen booths + chosen add-ons.
  /// (Before the fix, the total never changed when add-ons were ticked.)
  double _liveTotal(List<Booth> allBooths, List<AddItem> allAddItems) {
    double total = 0;
    for (final b in allBooths) {
      if (_selectedBoothIds.contains(b.id)) total += b.price;
    }
    for (final i in allAddItems) {
      if (_selectedAddItemIds.contains(i.id)) total += i.price;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final appAsync = ref.watch(_applicationDetailProvider(widget.applicationId));
    final addItemsAsync = ref.watch(addItemsProvider);
    final isPending =
        appAsync.valueOrNull?.status == ApplicationStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Detail'),
        actions: isPending
            ? [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () {
                          final app = appAsync.valueOrNull;
                          if (app == null) return;
                          if (_editing) {
                            _saveChanges(app);
                          } else {
                            _startEditing(app);
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_editing ? 'Save' : 'Edit',
                          style: const TextStyle(color: Colors.white)),
                ),
              ]
            : null,
      ),
      body: appAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorWidget2(message: e.toString()),
        data: (application) {
          if (application == null) {
            return const ErrorWidget2(message: 'Application not found');
          }

          // Live booth + add-on data for this exhibition.
          final boothsAsync =
              ref.watch(boothsProvider(application.exhibitionId));
          final allBooths = boothsAsync.valueOrNull ?? const <Booth>[];
          final allAddItems = addItemsAsync.valueOrNull ?? const <AddItem>[];

          // The amount to show: live (recomputed) while editing, otherwise
          // the saved value.
          final shownTotal = (_editing && boothsAsync.hasValue)
              ? _liveTotal(allBooths, allAddItems)
              : application.totalPrice;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ---- Status card (clear coloured exhibition box) ----
              Card(
                color: const Color(0xFFE3F2FD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.primaryColor, width: 1.4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.event, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(application.exhibitionTitle,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor)),
                      ),
                      ApplicationStatusChip(status: application.status),
                    ]),
                    const SizedBox(height: 8),
                    Text('Application ID: ${application.id.substring(0, application.id.length < 8 ? application.id.length : 8)}...',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    Text('Submitted: ${_fmt.format(application.createdAt)}',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    Text('Updated: ${_fmt.format(application.updatedAt)}',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ---- Booths ----
              const SectionHeader(title: 'Booked Booths'),
              if (!_editing)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: application.boothNumbers
                          .map((num) => ListTile(
                                leading: const Icon(Icons.store,
                                    color: AppTheme.primaryColor),
                                title: Text('Booth $num'),
                                dense: true,
                              ))
                          .toList(),
                    ),
                  ),
                )
              else
                // EDIT MODE: the exhibitor can now re-select their booths.
                _boothPicker(application, boothsAsync),
              const SizedBox(height: 12),

              // ---- Company ----
              const SectionHeader(title: 'Company Information'),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(application.companyName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_editing)
                    TextField(controller: _companyDescCtrl, maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Company Description'))
                  else
                    Text(application.companyDescription,
                        style: const TextStyle(height: 1.5)),
                ]),
              )),
              const SizedBox(height: 12),

              // ---- Exhibit ----
              const SectionHeader(title: 'Exhibit Profile'),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: _editing
                    ? TextField(controller: _exhibitDescCtrl, maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Exhibit Description'))
                    : Text(application.exhibitDescription,
                        style: const TextStyle(height: 1.5)),
              )),
              const SizedBox(height: 12),

              // ---- Add-ons ----
              const SectionHeader(title: 'Add-on Items'),
              addItemsAsync.when(
                loading: () => const LoadingWidget(),
                error: (_, __) => const SizedBox(),
                data: (items) {
                  if (_editing) {
                    return Column(children: items.map((item) {
                      final isSel = _selectedAddItemIds.contains(item.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: CheckboxListTile(
                          value: isSel,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selectedAddItemIds.add(item.id);
                            } else {
                              _selectedAddItemIds.remove(item.id);
                            }
                          }),
                          title: Text(item.name),
                          subtitle: Text('RM ${item.price.toStringAsFixed(0)}'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    }).toList());
                  }
                  // Not editing: show only the selected add-ons.
                  final selected = items
                      .where((i) => application.selectedAddItemIds.contains(i.id))
                      .toList();
                  if (selected.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('No add-ons selected',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(children: selected.map((item) => ListTile(
                        leading: const Icon(Icons.add_circle_outline,
                            color: AppTheme.accentColor),
                        title: Text(item.name),
                        trailing: Text('RM ${item.price.toStringAsFixed(0)}'),
                      )).toList());
                },
              ),
              const SizedBox(height: 12),

              // ---- Price ----
              Card(
                color: AppTheme.primaryColor.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(children: [
                      const Text('Total Amount',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      Text('RM ${shownTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: AppTheme.primaryColor)),
                    ]),
                    if (_editing) ...[
                      const SizedBox(height: 4),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Updates automatically as you change booths or add-ons.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),

              // ---- Rejection / cancellation reason ----
              if (application.rejectionReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.cancel, color: Colors.red.shade600, size: 18),
                      const SizedBox(width: 6),
                      Text('Rejection Reason',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                    ]),
                    const SizedBox(height: 6),
                    Text(application.rejectionReason!,
                        style: TextStyle(color: Colors.red.shade700)),
                  ]),
                ),
              ],
              if (application.cancellationReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Cancellation Reason',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(application.cancellationReason!),
                  ]),
                ),
              ],

              // ---- Action buttons ----
              if (application.status == ApplicationStatus.pending && !_editing) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancel(application),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Application'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
              if (application.status == ApplicationStatus.rejected ||
                  application.status == ApplicationStatus.cancelled) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/exhibitor'),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Start New Application'),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ]),
          );
        },
      ),
    );
  }

  /// The booth chooser shown in edit mode. The exhibitor can tick/untick
  /// booths. Only AVAILABLE booths (or booths that already belong to this
  /// application) can be ticked - booths taken by other companies are
  /// shown but disabled.
  Widget _boothPicker(
      BoothApplication application, AsyncValue<List<Booth>> boothsAsync) {
    return boothsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Could not load booths: $e'),
      ),
      data: (booths) {
        if (booths.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('No booths in this exhibition.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tick the booths you want. You can add or remove booths here.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          ...booths.map((b) {
            // A booth "belongs to me" if it is part of this application.
            final mine = b.currentApplicationId == application.id ||
                application.boothIds.contains(b.id);
            // Can be ticked only if free, or already mine.
            final canPick = b.status == BoothStatus.available || mine;
            final checked = _selectedBoothIds.contains(b.id);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: CheckboxListTile(
                value: checked,
                // onChanged null => the row is disabled (greyed out).
                onChanged: canPick
                    ? (v) => setState(() {
                          if (v == true) {
                            _selectedBoothIds.add(b.id);
                          } else {
                            _selectedBoothIds.remove(b.id);
                          }
                        })
                    : null,
                title: Text('Booth ${b.boothNumber} – ${b.boothType}'),
                subtitle: Text(
                  '${b.sizeqm} sqm • RM ${b.price.toStringAsFixed(0)}'
                  '${canPick ? '' : ' • Taken by another company'}',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
        ]);
      },
    );
  }

  /// Saves the edited application. This uses resubmitApplication() so the
  /// booth changes are handled cleanly: booths removed from the form are
  /// freed, and the application document is UPDATED (never duplicated).
  Future<void> _saveChanges(BoothApplication application) async {
    // Read the current booth + add-on lists.
    final booths =
        ref.read(boothsProvider(application.exhibitionId)).valueOrNull ??
            const <Booth>[];
    final addItems = ref.read(addItemsProvider).valueOrNull ?? const <AddItem>[];

    // Only keep booths that still exist and were ticked.
    final chosen =
        booths.where((b) => _selectedBoothIds.contains(b.id)).toList();
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one booth')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final boothTotal = chosen.fold(0.0, (s, b) => s + b.price);
      final addOnTotal = addItems
          .where((i) => _selectedAddItemIds.contains(i.id))
          .fold(0.0, (s, i) => s + i.price);

      final updated = application.copyWith(
        companyDescription: _companyDescCtrl.text.trim(),
        exhibitDescription: _exhibitDescCtrl.text.trim(),
        selectedAddItemIds: _selectedAddItemIds.toList(),
        boothIds: chosen.map((b) => b.id).toList(),
        boothNumbers: chosen.map((b) => b.boothNumber).toList(),
        // BUG FIX: the total now follows the booths + add-ons.
        totalPrice: boothTotal + addOnTotal,
      );

      // previousBoothIds lets the service free booths the user removed.
      await ref
          .read(dbProvider)
          .resubmitApplication(updated, application.boothIds);

      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cancel(BoothApplication application) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Application'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Are you sure you want to cancel this application?'),
          const SizedBox(height: 12),
          TextField(controller: ctrl,
              decoration: const InputDecoration(hintText: 'Reason (optional)'),
              maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final db = ref.read(dbProvider);
    final updated = application.copyWith(
      status: ApplicationStatus.cancelled,
      cancellationReason:
          ctrl.text.trim().isEmpty ? 'Cancelled by exhibitor' : ctrl.text.trim(),
    );
    await db.updateApplication(updated);
    if (mounted) context.go('/exhibitor/applications');
  }
}
