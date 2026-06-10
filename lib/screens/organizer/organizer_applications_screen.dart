import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

/// Shows booth applications for the organizer.
///
/// - If [exhibitionId] is given  -> applications for THAT exhibition only.
/// - If [exhibitionId] is null   -> ALL applications across every
///   exhibition the organizer owns (used by the "Applications" tab).
///
/// This screen returns a plain widget (no Scaffold) because it is shown
/// inside the OrganizerShell, which already provides the app bar.
class OrganizerApplicationsScreen extends ConsumerWidget {
  final String? exhibitionId;
  const OrganizerApplicationsScreen({super.key, this.exhibitionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd MMM yyyy');

    // Pick the right data source depending on the mode.
    final AsyncValue<List<BoothApplication>> applicationsAsync =
        exhibitionId != null
            ? ref.watch(exhibitionApplicationsProvider(exhibitionId!))
            : ref.watch(organizerApplicationsProvider);

    // Title: the exhibition name, or a general title for the tab view.
    final String headerTitle = exhibitionId != null
        ? (ref.watch(exhibitionDetailProvider(exhibitionId!)).valueOrNull?.title ??
            'Applications')
        : 'All Applications';

    return Column(children: [
      // Simple header (the shell provides the real app bar).
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(headerTitle,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
            exhibitionId != null
                ? 'Applications for this exhibition'
                : 'Applications across all your exhibitions',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ]),
      ),
      Expanded(
        child: applicationsAsync.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => ErrorWidget2(message: e.toString()),
          data: (applications) {
            if (applications.isEmpty) {
              return EmptyState(
                message: exhibitionId != null
                    ? 'No applications for this exhibition yet.'
                    : 'No applications for your exhibitions yet.',
                icon: Icons.assignment_late_outlined,
              );
            }

            // Group by status so the organizer sees pending ones first.
            final pending = applications
                .where((a) => a.status == ApplicationStatus.pending)
                .toList();
            final approved = applications
                .where((a) => a.status == ApplicationStatus.approved)
                .toList();
            final others = applications
                .where((a) =>
                    a.status == ApplicationStatus.rejected ||
                    a.status == ApplicationStatus.cancelled)
                .toList();

            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  _StatCard(
                      label: 'Pending',
                      count: pending.length,
                      color: AppTheme.warningColor),
                  const SizedBox(width: 8),
                  _StatCard(
                      label: 'Approved',
                      count: approved.length,
                      color: AppTheme.successColor),
                  const SizedBox(width: 8),
                  _StatCard(
                      label: 'Other',
                      count: others.length,
                      color: Colors.grey),
                ]),
              ),
              if (pending.isNotEmpty) ...[
                const SectionHeader(title: 'Pending Review'),
                ...pending.map((a) =>
                    _OrganizerApplicationCard(application: a, fmt: fmt)),
              ],
              if (approved.isNotEmpty) ...[
                const SectionHeader(title: 'Approved'),
                ...approved.map((a) =>
                    _OrganizerApplicationCard(application: a, fmt: fmt)),
              ],
              if (others.isNotEmpty) ...[
                const SectionHeader(title: 'Rejected / Cancelled'),
                ...others.map((a) =>
                    _OrganizerApplicationCard(application: a, fmt: fmt)),
              ],
              const SizedBox(height: 16),
            ]);
          },
        ),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatCard(
      {required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ]),
        ),
      );
}

class _OrganizerApplicationCard extends ConsumerWidget {
  final BoothApplication application;
  final DateFormat fmt;
  const _OrganizerApplicationCard(
      {required this.application, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(application.companyName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(application.exhibitorName,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ])),
            ApplicationStatusChip(status: application.status),
          ]),
          const Divider(height: 16),
          Text('Exhibition: ${application.exhibitionTitle}',
              style: const TextStyle(fontSize: 13)),
          Text('Booths: ${application.boothNumbers.join(', ')}',
              style: const TextStyle(fontSize: 13)),
          Text('Submitted: ${fmt.format(application.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Text('What they\'ll showcase:',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13)),
          Text(application.exhibitDescription,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            Text('RM ${application.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryColor)),
            const Spacer(),
            if (application.status == ApplicationStatus.pending) ...[
              OutlinedButton(
                onPressed: () => _reject(context, ref),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red)),
                child: const Text('Reject'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _approve(context, ref),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor),
                child: const Text('Approve'),
              ),
            ] else if (application.status == ApplicationStatus.approved)
              OutlinedButton(
                onPressed: () => _cancel(context, ref),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange)),
                child: const Text('Withdraw'),
              ),
          ]),
          if (application.rejectionReason != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Reason: ${application.rejectionReason}',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            ),
        ]),
      ),
    );
  }

  // NOTE: no ref.invalidate() is needed any more. The applications come
  // from a live Firestore stream, so the screen updates by itself the
  // moment updateApplication() saves the change.

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Approve Application',
        message:
            'Approve ${application.companyName}\'s application for booths ${application.boothNumbers.join(', ')}?',
        confirmLabel: 'Approve',
        confirmColor: AppTheme.successColor,
      ),
    );
    if (confirm != true) return;
    final updated = application.copyWith(status: ApplicationStatus.approved);
    await ref.read(dbProvider).updateApplication(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Application approved!'),
          backgroundColor: AppTheme.successColor));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Reject Application',
        message: 'Reject ${application.companyName}\'s application?',
        confirmLabel: 'Reject',
        confirmColor: Colors.red,
        extra: TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(hintText: 'Reason for rejection *'),
            maxLines: 2),
      ),
    );
    if (confirm != true) return;
    final updated = application.copyWith(
      status: ApplicationStatus.rejected,
      rejectionReason: ctrl.text.trim().isEmpty
          ? 'Application did not meet requirements'
          : ctrl.text.trim(),
    );
    await ref.read(dbProvider).updateApplication(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application rejected')));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Withdraw Booking',
        message:
            'Withdraw the approved booking for ${application.companyName}?',
        confirmLabel: 'Withdraw',
        confirmColor: Colors.orange,
        extra: TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(hintText: 'Reason for withdrawal *'),
            maxLines: 2),
      ),
    );
    if (confirm != true) return;
    final updated = application.copyWith(
      status: ApplicationStatus.cancelled,
      cancellationReason: ctrl.text.trim().isEmpty
          ? 'Booking withdrawn by organizer'
          : ctrl.text.trim(),
    );
    await ref.read(dbProvider).updateApplication(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Booking withdrawn')));
    }
  }
}
