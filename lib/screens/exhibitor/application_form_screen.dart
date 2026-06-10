import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class ApplicationFormScreen extends ConsumerStatefulWidget {
  final String exhibitionId;
  const ApplicationFormScreen({super.key, required this.exhibitionId});
  @override
  ConsumerState<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends ConsumerState<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameCtrl = TextEditingController();
  final _companyDescCtrl = TextEditingController();
  final _exhibitDescCtrl = TextEditingController();
  final Set<String> _selectedAddItemIds = {};
  bool _loading = false;
  final _fmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider);
    if (user?.companyName != null) _companyNameCtrl.text = user!.companyName!;
  }

  @override
  Widget build(BuildContext context) {
    final exhibitionAsync = ref.watch(exhibitionDetailProvider(widget.exhibitionId));
    final selectedBooths = ref.watch(selectedBoothsProvider);
    final addItemsAsync = ref.watch(addItemsProvider);

    if (selectedBooths.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Application Form')),
        body: EmptyState(
          message: 'No booths selected. Go back and select booths from the floor plan.',
          icon: Icons.map_outlined,
          actionLabel: 'Go Back',
          onAction: () => context.pop(),
        ),
      );
    }

    final boothTotal = selectedBooths.fold(0.0, (s, b) => s + b.price);

    return Scaffold(
      appBar: AppBar(title: const Text('Booth Application')),
      body: exhibitionAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorWidget2(message: e.toString()),
        data: (exhibition) {
          if (exhibition == null) return const ErrorWidget2(message: 'Exhibition not found');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Exhibition summary box - now uses a clear light-blue
                // background with a blue border and a blue title, so the
                // exhibition name, venue and dates are easy to see.
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
                          child: Text(exhibition.title,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.location_on, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(exhibition.venue,
                              style: const TextStyle(color: Colors.black87, fontSize: 13)),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.calendar_today, size: 13, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text('${_fmt.format(exhibition.startDate)} – ${_fmt.format(exhibition.endDate)}',
                            style: const TextStyle(color: Colors.black87, fontSize: 13)),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Selected booths
                const SectionHeader(title: 'Selected Booths'),
                ...selectedBooths.map((b) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.boothSelected.withOpacity(0.15),
                      child: Text(b.boothNumber.split('-').last,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.boothSelected)),
                    ),
                    title: Text('Booth ${b.boothNumber} – ${b.boothType}'),
                    subtitle: Text('${b.sizeqm} sqm • ${b.amenities.join(', ')}'),
                    trailing: Text('RM ${b.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  ),
                )),
                const SizedBox(height: 16),

                // Company info
                const SectionHeader(title: 'Company Information'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    TextFormField(
                      controller: _companyNameCtrl,
                      decoration: const InputDecoration(labelText: 'Company Name *', prefixIcon: Icon(Icons.business)),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _companyDescCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Company Description *',
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Exhibit profile
                const SectionHeader(title: 'Exhibit Profile'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextFormField(
                    controller: _exhibitDescCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'What will you showcase? *',
                      hintText: 'Describe your products, services, or exhibits...',
                      prefixIcon: Icon(Icons.campaign),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Exhibition dates (read-only)
                const SectionHeader(title: 'Exhibition Dates'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        InfoRow(icon: Icons.event_available, label: 'Start Date', value: _fmt.format(exhibition.startDate)),
                        InfoRow(icon: Icons.event_busy, label: 'End Date', value: _fmt.format(exhibition.endDate)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Add-on items
                const SectionHeader(title: 'Add-on Items (Optional)'),
                addItemsAsync.when(
                  loading: () => const LoadingWidget(),
                  error: (_, __) => const SizedBox(),
                  data: (items) => Column(
                    children: items.map((item) {
                      final isSelected = _selectedAddItemIds.contains(item.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (v) => setState(() {
                            if (v == true) _selectedAddItemIds.add(item.id);
                            else _selectedAddItemIds.remove(item.id);
                          }),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(item.description),
                          secondary: Text('RM ${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Price summary
                addItemsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (allItems) {
                    final addOnItems = allItems.where((i) => _selectedAddItemIds.contains(i.id)).toList();
                    final addOnTotal = addOnItems.fold(0.0, (s, i) => s + i.price);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          const Text('Price Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Divider(),
                          Row(children: [
                            const Text('Booth(s)'),
                            const Spacer(),
                            Text('RM ${boothTotal.toStringAsFixed(0)}'),
                          ]),
                          if (addOnTotal > 0) Row(children: [
                            const Text('Add-ons'),
                            const Spacer(),
                            Text('RM ${addOnTotal.toStringAsFixed(0)}'),
                          ]),
                          const Divider(),
                          Row(children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            Text('RM ${(boothTotal + addOnTotal).toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Submit
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : () => _submit(context, exhibition, selectedBooths, ref),
                      icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                      label: const Text('Submit Application'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Your application will be reviewed by the organizer. You will be notified of the decision.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit(BuildContext context, Exhibition exhibition,
      List<Booth> selectedBooths, WidgetRef ref) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final user = ref.read(authStateProvider)!;
      final db = ref.read(dbProvider);
      final allItems = await db.getAddItems();
      final addOnItems = allItems.where((i) => _selectedAddItemIds.contains(i.id)).toList();
      final addOnTotal = addOnItems.fold(0.0, (s, i) => s + i.price);
      final boothTotal = selectedBooths.fold(0.0, (s, b) => s + b.price);

      final application = BoothApplication(
        id: '',
        exhibitionId: widget.exhibitionId,
        exhibitionTitle: exhibition.title,
        exhibitorId: user.id,
        exhibitorName: user.displayName,
        boothIds: selectedBooths.map((b) => b.id).toList(),
        boothNumbers: selectedBooths.map((b) => b.boothNumber).toList(),
        companyName: _companyNameCtrl.text.trim(),
        companyDescription: _companyDescCtrl.text.trim(),
        exhibitDescription: _exhibitDescCtrl.text.trim(),
        exhibitionStartDate: exhibition.startDate,
        exhibitionEndDate: exhibition.endDate,
        selectedAddItemIds: _selectedAddItemIds.toList(),
        totalPrice: boothTotal + addOnTotal,
        status: ApplicationStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.submitApplication(application);
      ref.read(selectedBoothsProvider.notifier).clear();
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(boothsProvider(widget.exhibitionId));

      if (!mounted) return;
      _showSuccessDialog(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppTheme.successColor, size: 60),
        title: const Text('Application Submitted!'),
        content: const Text('Your booth application has been submitted successfully. '
          'The organizer will review it and you\'ll be notified of the decision.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/exhibitor/applications');
            },
            child: const Text('View My Applications'),
          ),
        ],
      ),
    );
  }
}
