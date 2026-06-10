import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class ExhibitionDetailScreen extends ConsumerWidget {
  final String exhibitionId;
  const ExhibitionDetailScreen({super.key, required this.exhibitionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exhibitionAsync = ref.watch(exhibitionDetailProvider(exhibitionId));
    final boothsAsync = ref.watch(boothsProvider(exhibitionId));
    final user = ref.watch(authStateProvider);
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Exhibition Details')),
      body: exhibitionAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => ErrorWidget2(message: e.toString()),
        data: (exhibition) {
          if (exhibition == null) return const ErrorWidget2(message: 'Exhibition not found');
          return SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ExhibitionStatusChip(status: exhibition.status),
                  const SizedBox(height: 12),
                  Text(exhibition.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('By ${exhibition.organizerName}', style: const TextStyle(color: Colors.white70)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      InfoRow(icon: Icons.location_on, label: 'Venue', value: exhibition.venue),
                      InfoRow(icon: Icons.calendar_today, label: 'Dates',
                        value: '${fmt.format(exhibition.startDate)} – ${fmt.format(exhibition.endDate)}'),
                      if (exhibition.category != null)
                        InfoRow(icon: Icons.category, label: 'Category', value: exhibition.category!),
                      InfoRow(icon: Icons.store, label: 'Booths',
                        value: '${exhibition.availableBooths} available of ${exhibition.totalBooths}'),
                    ]),
                  )),
                  const SizedBox(height: 16),
                  const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(exhibition.description, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 24),
                  // Read-only floor plan
                  const Text('Floor Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  boothsAsync.when(
                    loading: () => const SizedBox(height: 200, child: LoadingWidget()),
                    error: (e, _) => const SizedBox(),
                    data: (booths) => _ReadOnlyFloorPlan(
                      booths: booths,
                      floorPlanImage: exhibition.floorPlanImageBase64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // CTA
                  if (user == null)
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(children: [
                        const Icon(Icons.login, size: 40, color: AppTheme.primaryColor),
                        const SizedBox(height: 12),
                        const Text('Want to book a booth?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Register or login to select and book your booth at this exhibition.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          OutlinedButton(onPressed: () => context.push('/login'), child: const Text('Login')),
                          ElevatedButton(onPressed: () => context.push('/register'), child: const Text('Register')),
                        ]),
                      ]),
                    ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _ReadOnlyFloorPlan extends StatelessWidget {
  final List<Booth> booths;
  final String? floorPlanImage;
  const _ReadOnlyFloorPlan({required this.booths, this.floorPlanImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(children: [
        // Legend
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _LegendItem(color: AppTheme.boothAvailable, label: 'Available'),
            const SizedBox(width: 16),
            _LegendItem(color: AppTheme.boothBooked, label: 'Booked'),
            const SizedBox(width: 16),
            _LegendItem(color: AppTheme.boothPending, label: 'Pending'),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: InteractiveViewer(
            child: Stack(children: [
              Container(color: Colors.grey.shade100),
              // Uploaded floor plan image (behind the booth boxes).
              FloorPlanBackground(base64Image: floorPlanImage),
              ...booths.map((b) => Positioned(
                left: b.x, top: b.y, width: b.width, height: b.height,
                child: GestureDetector(
                  onTap: () => _showBoothInfo(context, b),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _colorForStatus(b.status).withOpacity(0.3),
                      border: Border.all(color: _colorForStatus(b.status), width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(child: Text(b.boothNumber,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center)),
                  ),
                ),
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  Color _colorForStatus(BoothStatus status) => switch (status) {
    BoothStatus.available => AppTheme.boothAvailable,
    BoothStatus.booked => AppTheme.boothBooked,
    BoothStatus.pending => AppTheme.boothPending,
    BoothStatus.unavailable => Colors.grey,
  };

  void _showBoothInfo(BuildContext context, Booth booth) {
    showModalBottomSheet(context: context, builder: (ctx) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Booth ${booth.boothNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(),
        InfoRow(icon: Icons.label, label: 'Type', value: booth.boothType),
        InfoRow(icon: Icons.straighten, label: 'Size', value: '${booth.sizeqm} sqm'),
        InfoRow(icon: Icons.attach_money, label: 'Price', value: 'RM ${booth.price.toStringAsFixed(0)}'),
        if (booth.amenities.isNotEmpty)
          InfoRow(icon: Icons.stars, label: 'Amenities', value: booth.amenities.join(', ')),
        const SizedBox(height: 8),
        StatusChip(
          label: booth.status.name[0].toUpperCase() + booth.status.name.substring(1),
          color: _colorForStatus(booth.status),
        ),
      ]),
    ));
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12)),
  ]);
}
