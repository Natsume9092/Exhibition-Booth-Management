import 'dart:convert'; // for base64Decode (floor plan image)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    backgroundColor: color.withOpacity(0.12),
    side: BorderSide(color: color.withOpacity(0.4)),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

class ExhibitionStatusChip extends StatelessWidget {
  final ExhibitionStatus status;
  const ExhibitionStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ExhibitionStatus.upcoming => ('Upcoming', AppTheme.secondaryColor),
      ExhibitionStatus.ongoing => ('Ongoing', AppTheme.successColor),
      ExhibitionStatus.completed => ('Completed', Colors.grey),
      ExhibitionStatus.cancelled => ('Cancelled', AppTheme.errorColor),
    };
    return StatusChip(label: label, color: color);
  }
}

class ApplicationStatusChip extends StatelessWidget {
  final ApplicationStatus status;
  const ApplicationStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ApplicationStatus.pending => ('Pending Review', AppTheme.warningColor),
      ApplicationStatus.approved => ('Approved', AppTheme.successColor),
      ApplicationStatus.rejected => ('Rejected', AppTheme.errorColor),
      ApplicationStatus.cancelled => ('Cancelled', Colors.grey),
    };
    return StatusChip(label: label, color: color);
  }
}

class ExhibitionCard extends StatelessWidget {
  final Exhibition exhibition;
  final VoidCallback onTap;
  final List<Widget>? actions;

  const ExhibitionCard({super.key, required this.exhibition, required this.onTap, this.actions});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(exhibition.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ExhibitionStatusChip(status: exhibition.status),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(exhibition.venue, style: const TextStyle(color: Colors.grey, fontSize: 13))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${fmt.format(exhibition.startDate)} – ${fmt.format(exhibition.endDate)}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
            if (exhibition.category != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Chip(
                  label: Text(exhibition.category!, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Spacer(),
                Text('${exhibition.availableBooths}/${exhibition.totalBooths} booths available',
                  style: TextStyle(fontSize: 12, color: exhibition.availableBooths > 0
                    ? AppTheme.successColor : AppTheme.errorColor)),
              ]),
            ],
            if (!exhibition.isPublished)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text('Draft – Not Published', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ),
            if (actions != null) ...[
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
            ],
          ]),
        ),
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(),
      if (message != null) ...[const SizedBox(height: 16), Text(message!)],
    ]),
  );
}

class ErrorWidget2 extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorWidget2({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 64, color: Colors.red),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center),
      if (onRetry != null) ...[
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ]),
  );
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ]),
    ),
  );
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color? confirmColor;
  final Widget? extra;

  const ConfirmDialog({super.key, required this.title, required this.message,
    this.confirmLabel = 'Confirm', this.confirmColor, this.extra});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(message),
      if (extra != null) ...[const SizedBox(height: 12), extra!],
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(backgroundColor: confirmColor ?? AppTheme.primaryColor),
        child: Text(confirmLabel),
      ),
    ],
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (trailing != null) ...[const Spacer(), trailing!],
    ]),
  );
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
    ]),
  );
}

/// FloorPlanBackground
/// -------------------
/// Shows the floor plan image that the Admin uploaded. The image is kept
/// as base64 text inside the exhibition document, so here it is decoded
/// back into picture bytes and shown.
///
/// It is placed as the FIRST child of a Stack so the booth boxes sit on
/// top of it. If there is no image, it shows nothing (an empty box).
class FloorPlanBackground extends StatelessWidget {
  final String? base64Image;
  const FloorPlanBackground({super.key, this.base64Image});

  @override
  Widget build(BuildContext context) {
    final data = base64Image;
    // No image uploaded yet -> show nothing.
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    try {
      // Turn the base64 text back into image bytes.
      final bytes = base64Decode(data);
      // SizedBox.expand makes the image fill the whole map area.
      return SizedBox.expand(
        child: Image.memory(bytes, fit: BoxFit.fill),
      );
    } catch (_) {
      // If the saved text is not a valid image, just show nothing.
      return const SizedBox.shrink();
    }
  }
}
