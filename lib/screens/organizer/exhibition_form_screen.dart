import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class ExhibitionFormScreen extends ConsumerStatefulWidget {
  final String? exhibitionId;
  final bool isAdmin;
  const ExhibitionFormScreen({super.key, this.exhibitionId, this.isAdmin = false});
  @override
  ConsumerState<ExhibitionFormScreen> createState() => _ExhibitionFormScreenState();
}

class _ExhibitionFormScreenState extends ConsumerState<ExhibitionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  // Holds the typed-in category when the user picks "Other".
  final _customCategoryCtrl = TextEditingController();
  String? _category;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isPublished = false;
  bool _preventAdjacentCompetitors = false;
  bool _loading = false;
  bool _loaded = false;

  final _categories = ['Technology', 'Fashion', 'Energy', 'Food', 'Art', 'Health', 'Business', 'Other'];

  @override
  void initState() {
    super.initState();
    if (widget.exhibitionId != null) _loadExhibition();
  }

  Future<void> _loadExhibition() async {
    final exhibition = await ref.read(dbProvider).getExhibition(widget.exhibitionId!);
    if (exhibition != null && mounted) {
      setState(() {
        _titleCtrl.text = exhibition.title;
        _descCtrl.text = exhibition.description;
        _venueCtrl.text = exhibition.venue;
        _category = exhibition.category;
        // If the saved category is NOT one of the preset choices, it is a
        // custom one - show it as "Other" with the text filled in.
        if (_category != null &&
            _category!.isNotEmpty &&
            !_categories.contains(_category)) {
          _customCategoryCtrl.text = _category!;
          _category = 'Other';
        }
        _startDate = exhibition.startDate;
        _endDate = exhibition.endDate;
        _isPublished = exhibition.isPublished;
        _preventAdjacentCompetitors = exhibition.preventAdjacentCompetitors;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.exhibitionId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Exhibition' : 'New Exhibition')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Exhibition Title *', prefixIcon: Icon(Icons.event)),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description *', prefixIcon: Icon(Icons.description), alignLabelWithHint: true),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _venueCtrl,
              decoration: const InputDecoration(labelText: 'Venue *', prefixIcon: Icon(Icons.location_on)),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            // When "Other" is chosen, show a box for the user to type
            // their own category name.
            if (_category == 'Other') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customCategoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Category *',
                  hintText: 'Type your own category',
                  prefixIcon: Icon(Icons.edit),
                ),
                validator: (v) =>
                    (_category == 'Other' && (v == null || v.trim().isEmpty))
                        ? 'Please type your category'
                        : null,
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _DateField(
                label: 'Start Date *',
                value: _startDate,
                onPick: (d) => setState(() => _startDate = d),
              )),
              const SizedBox(width: 12),
              Expanded(child: _DateField(
                label: 'End Date *',
                value: _endDate,
                onPick: (d) => setState(() => _endDate = d),
              )),
            ]),
            const SizedBox(height: 16),
            Card(child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                if (widget.isAdmin) SwitchListTile(
                  title: const Text('Published'),
                  subtitle: const Text('Visible to organizers and exhibitors'),
                  value: _isPublished,
                  onChanged: (v) => setState(() => _isPublished = v),
                  secondary: Icon(_isPublished ? Icons.visibility : Icons.visibility_off,
                    color: _isPublished ? AppTheme.successColor : Colors.grey),
                ),
                SwitchListTile(
                  title: const Text('Prevent Adjacent Competitors'),
                  subtitle: const Text('Block competitors from booking adjacent booths'),
                  value: _preventAdjacentCompetitors,
                  onChanged: (v) => setState(() => _preventAdjacentCompetitors = v),
                  secondary: const Icon(Icons.block, color: AppTheme.warningColor),
                ),
              ]),
            )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
                label: Text(isEdit ? 'Save Changes' : 'Create Exhibition'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')));
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')));
      return;
    }

    setState(() => _loading = true);
    try {
      final db = ref.read(dbProvider);
      final user = ref.read(authStateProvider)!;
      final now = DateTime.now();
      final status = _startDate!.isAfter(now) ? ExhibitionStatus.upcoming :
        (_endDate!.isBefore(now) ? ExhibitionStatus.completed : ExhibitionStatus.ongoing);

      // When "Other" is picked, save the typed-in custom category text.
      final categoryValue = _category == 'Other'
          ? _customCategoryCtrl.text.trim()
          : _category;

      final exhibition = Exhibition(
        id: widget.exhibitionId ?? '',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        organizerId: user.id,
        organizerName: user.displayName,
        venue: _venueCtrl.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        isPublished: _isPublished,
        status: status,
        category: categoryValue,
        preventAdjacentCompetitors: _preventAdjacentCompetitors,
      );

      if (widget.exhibitionId != null) {
        await db.updateExhibition(exhibition);
      } else {
        await db.createExhibition(exhibition);
      }

      ref.invalidate(exhibitionsProvider(const ExhibitionFilter()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.exhibitionId != null ? 'Exhibition updated!' : 'Exhibition created!')));
      context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  const _DateField({required this.label, this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        );
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null ? '${value!.day}/${value!.month}/${value!.year}' : 'Select date',
          style: TextStyle(color: value != null ? Colors.black87 : Colors.grey),
        ),
      ),
    );
  }
}
