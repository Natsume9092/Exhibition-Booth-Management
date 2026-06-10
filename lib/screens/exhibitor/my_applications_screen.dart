import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(myApplicationsProvider);
    final fmt = DateFormat('dd MMM yyyy');

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myApplicationsProvider),
      child: applicationsAsync.when(
        loading: () => const LoadingWidget(message: 'Loading applications...'),
        error: (e, _) => ErrorWidget2(message: e.toString()),
        data: (applications) {
          if (applications.isEmpty) return EmptyState(
            message: 'No applications yet.\nBrowse exhibitions and book a booth!',
            icon: Icons.assignment_outlined,
            actionLabel: 'Browse Exhibitions',
            onAction: () => context.go('/exhibitor'),
          );

          // Group by status
          final pending = applications.where((a) => a.status == ApplicationStatus.pending).toList();
          final approved = applications.where((a) => a.status == ApplicationStatus.approved).toList();
          final others = applications.where((a) =>
            a.status == ApplicationStatus.rejected || a.status == ApplicationStatus.cancelled).toList();

          return ListView(children: [
            // Summary cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _SummaryCard(label: 'Pending', count: pending.length, color: AppTheme.warningColor),
                const SizedBox(width: 8),
                _SummaryCard(label: 'Approved', count: approved.length, color: AppTheme.successColor),
                const SizedBox(width: 8),
                _SummaryCard(label: 'Other', count: others.length, color: Colors.grey),
              ]),
            ),
            if (pending.isNotEmpty) ...[
              const SectionHeader(title: 'Pending Review'),
              ...pending.map((a) => _ApplicationCard(application: a, fmt: fmt)),
            ],
            if (approved.isNotEmpty) ...[
              const SectionHeader(title: 'Approved'),
              ...approved.map((a) => _ApplicationCard(application: a, fmt: fmt)),
            ],
            if (others.isNotEmpty) ...[
              const SectionHeader(title: 'Rejected / Cancelled'),
              ...others.map((a) => _ApplicationCard(application: a, fmt: fmt)),
            ],
          ]);
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryCard({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ]),
    ),
  );
}

class _ApplicationCard extends ConsumerWidget {
  final BoothApplication application;
  final DateFormat fmt;
  const _ApplicationCard({required this.application, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/exhibitor/application/${application.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(application.exhibitionTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              ApplicationStatusChip(status: application.status),
            ]),
            const SizedBox(height: 8),
            Text('Booths: ${application.boothNumbers.join(', ')}',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text('Submitted: ${fmt.format(application.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              Text('RM ${application.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 16)),
              const Spacer(),
              if (application.status == ApplicationStatus.pending) ...[
                TextButton(
                  onPressed: () => _cancelApplication(context, ref),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () => context.push('/exhibitor/application/${application.id}'),
                  child: const Text('Edit'),
                ),
              ] else
                TextButton(
                  onPressed: () => context.push('/exhibitor/application/${application.id}'),
                  child: const Text('View Details'),
                ),
            ]),
            if (application.rejectionReason != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50, borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.red.shade600),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Reason: ${application.rejectionReason}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  void _cancelApplication(BuildContext context, WidgetRef ref) async {
    final reason = await _showReasonDialog(context, 'Cancel Application',
      'Please provide a reason for cancellation:');
    if (reason == null) return;

    final db = ref.read(dbProvider);
    final updated = application.copyWith(
      status: ApplicationStatus.cancelled,
      cancellationReason: reason,
    );
    await db.updateApplication(updated);
    ref.invalidate(myApplicationsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application cancelled')),
      );
    }
  }

  Future<String?> _showReasonDialog(BuildContext context, String title, String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, maxLines: 3,
          decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? 'No reason provided' : ctrl.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
