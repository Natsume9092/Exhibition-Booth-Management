import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class AdminApplicationsScreen extends ConsumerStatefulWidget {
  const AdminApplicationsScreen({super.key});
  @override
  ConsumerState<AdminApplicationsScreen> createState() => _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends ConsumerState<AdminApplicationsScreen> {
  String _search = '';
  ApplicationStatus? _filterStatus;
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(myApplicationsProvider);
    final fmt = DateFormat('dd MMM yyyy');

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search by company, exhibitor, or exhibition...',
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
              FilterChip(label: const Text('All'), selected: _filterStatus == null,
                onSelected: (_) => setState(() => _filterStatus = null)),
              const SizedBox(width: 8),
              ...ApplicationStatus.values.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                  selected: _filterStatus == s,
                  onSelected: (_) => setState(() => _filterStatus = _filterStatus == s ? null : s),
                ),
              )),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myApplicationsProvider),
          child: applicationsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => ErrorWidget2(message: e.toString()),
            data: (applications) {
              var filtered = applications.where((a) {
                if (_filterStatus != null && a.status != _filterStatus) return false;
                if (_search.isNotEmpty) {
                  final q = _search.toLowerCase();
                  return a.companyName.toLowerCase().contains(q) ||
                    a.exhibitorName.toLowerCase().contains(q) ||
                    a.exhibitionTitle.toLowerCase().contains(q) ||
                    a.boothNumbers.any((b) => b.toLowerCase().contains(q));
                }
                return true;
              }).toList();

              if (filtered.isEmpty) return const EmptyState(
                message: 'No applications found', icon: Icons.assignment_late_outlined);

              // Summary
              final totalRevenue = applications
                .where((a) => a.status == ApplicationStatus.approved)
                .fold(0.0, (s, a) => s + a.totalPrice);

              return ListView(children: [
                // Revenue card - now a SOLID coloured card with white text
                // so the "Total Approved Revenue" stands out clearly
                // (the old faint card was hard to read).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: AppTheme.primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payments_rounded,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Total Approved Revenue',
                            style: TextStyle(color: Colors.white70, fontSize: 12,
                                fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text('RM ${totalRevenue.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        ]),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(children: [
                            Text('${applications.where((a) => a.status == ApplicationStatus.pending).length}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                            const Text('Pending',
                                style: TextStyle(fontSize: 10, color: Colors.white)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...filtered.map((a) => _AdminApplicationCard(application: a, fmt: fmt)),
              ]);
            },
          ),
        ),
      ),
    ]);
  }
}

class _AdminApplicationCard extends ConsumerWidget {
  final BoothApplication application;
  final DateFormat fmt;
  const _AdminApplicationCard({required this.application, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(application.companyName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(application.exhibitionTitle,
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
            ])),
            ApplicationStatusChip(status: application.status),
          ]),
          const SizedBox(height: 8),
          Text('Exhibitor: ${application.exhibitorName}', style: const TextStyle(fontSize: 13)),
          Text('Booths: ${application.boothNumbers.join(', ')}', style: const TextStyle(fontSize: 13)),
          Text('Date: ${fmt.format(application.createdAt)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            Text('RM ${application.totalPrice.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryColor)),
            const Spacer(),
            if (application.status == ApplicationStatus.pending) ...[
              TextButton(
                onPressed: () => _updateStatus(context, ref, ApplicationStatus.rejected),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: () => _updateStatus(context, ref, ApplicationStatus.approved),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                child: const Text('Approve'),
              ),
            ] else ...[
              // Approved bookings can still be cancelled by the admin.
              if (application.status == ApplicationStatus.approved)
                OutlinedButton(
                  onPressed: () => _updateStatus(context, ref, ApplicationStatus.cancelled),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  child: const Text('Cancel'),
                ),
              // Delete is allowed for APPROVED, CANCELLED and REJECTED
              // applications so the admin can clean up old records.
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _delete(context, ref),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  /// Permanently deletes an application (APPROVED / CANCELLED / REJECTED).
  /// If it was approved, FirebaseService frees its booths first.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Delete Application',
        message: 'Permanently delete ${application.companyName}\'s '
            '"${application.statusLabel}" application? This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red,
      ),
    );
    if (confirm != true) return;
    await ref.read(dbProvider).deleteApplication(application.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application deleted')),
      );
    }
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, ApplicationStatus newStatus) async {
    String? reason;
    if (newStatus == ApplicationStatus.rejected || newStatus == ApplicationStatus.cancelled) {
      final ctrl = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(newStatus == ApplicationStatus.rejected ? 'Reject Application' : 'Cancel Booking'),
          content: TextField(controller: ctrl, maxLines: 2,
            decoration: const InputDecoration(hintText: 'Reason...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty
              ? 'Admin action' : ctrl.text.trim()), child: const Text('Confirm')),
          ],
        ),
      );
      if (reason == null) return;
    }

    final updated = application.copyWith(
      status: newStatus,
      rejectionReason: newStatus == ApplicationStatus.rejected ? reason : null,
      cancellationReason: newStatus == ApplicationStatus.cancelled ? reason : null,
    );
    await ref.read(dbProvider).updateApplication(updated);
    ref.invalidate(myApplicationsProvider);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Application ${newStatus.name}')));
  }
}
