import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/booth_rules.dart'; // adjacent competitor rule
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

class FloorPlanScreen extends ConsumerStatefulWidget {
  final String exhibitionId;
  const FloorPlanScreen({super.key, required this.exhibitionId});
  @override
  ConsumerState<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends ConsumerState<FloorPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Clear the booth cart. The booth, image and application data all
      // come from live Firestore streams now, so they refresh by
      // themselves - no manual invalidate is needed.
      ref.read(selectedBoothsProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final exhibitionAsync = ref.watch(exhibitionDetailProvider(widget.exhibitionId));
    final boothsAsync = ref.watch(boothsProvider(widget.exhibitionId));
    final selected = ref.watch(selectedBoothsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Booths'),
        actions: [
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge(
                label: Text('${selected.length}'),
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => _showCart(context, selected, widget.exhibitionId),
                ),
              ),
            ),
        ],
      ),
      body: Column(children: [
        // Legend
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _LegendDot(color: AppTheme.boothAvailable, label: 'Available'),
            _LegendDot(color: AppTheme.boothBooked, label: 'Booked'),
            _LegendDot(color: AppTheme.boothPending, label: 'Pending'),
            _LegendDot(color: AppTheme.boothSelected, label: 'Selected'),
          ]),
        ),
        // Exhibition info strip - now uses a clear, solid colour so the
        // exhibition name, info and competitor rule are easy to read.
        exhibitionAsync.when(
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
          data: (exhibition) => exhibition == null
              ? const SizedBox()
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppTheme.primaryColor.withOpacity(0.12),
                  child: Row(children: [
                    const Icon(Icons.event, size: 18, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(exhibition.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.primaryColor)),
                    ),
                    // When the rule is ON, show a clear badge so the user
                    // can SEE that competitor protection is active.
                    if (exhibition.preventAdjacentCompetitors)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.block, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text('Competitor rule ON',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    Text('${exhibition.availableBooths} available',
                        style: const TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
        ),
        // Floor plan canvas
        Expanded(
          child: boothsAsync.when(
            loading: () => const LoadingWidget(message: 'Loading floor plan...'),
            error: (e, _) => ErrorWidget2(message: e.toString()),
            data: (booths) => _FloorPlanCanvas(
              booths: booths,
              exhibitionId: widget.exhibitionId,
            ),
          ),
        ),
        // Bottom cart bar
        if (selected.isNotEmpty) _CartBar(
          selected: selected,
          exhibitionId: widget.exhibitionId,
        ),
      ]),
    );
  }

  void _showCart(BuildContext context, List<Booth> selected, String exhibitionId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => _CartSheet(selected: selected, exhibitionId: exhibitionId, controller: ctrl),
      ),
    );
  }
}

/// The floor plan map. It is a STATEFUL widget so it can own a
/// [TransformationController] - that controller is what makes the
/// mouse-scroll zoom and the on-screen zoom buttons possible.
class _FloorPlanCanvas extends ConsumerStatefulWidget {
  final List<Booth> booths;
  final String exhibitionId;
  const _FloorPlanCanvas({required this.booths, required this.exhibitionId});

  @override
  ConsumerState<_FloorPlanCanvas> createState() => _FloorPlanCanvasState();
}

class _FloorPlanCanvasState extends ConsumerState<_FloorPlanCanvas> {
  // Controls pan + zoom of the floor plan. The InteractiveViewer below
  // already zooms when the user scrolls the mouse wheel (great for PC).
  // The +/- buttons use this same controller, so both ways stay in sync.
  final TransformationController _transform = TransformationController();

  static const double _minZoom = 0.2;
  static const double _maxZoom = 4.0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Zooms the map in (factor > 1) or out (factor < 1) by changing the
  /// controller matrix. Used by the on-screen zoom buttons.
  void _zoom(double factor) {
    final matrix = _transform.value.clone();
    final current = matrix.getMaxScaleOnAxis();
    final next = current * factor;
    // Do not zoom past the allowed limits.
    if (next < _minZoom || next > _maxZoom) return;
    matrix.scale(factor, factor);
    _transform.value = matrix;
  }

  /// Resets the map back to its normal size and position.
  void _resetZoom() => _transform.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final booths = widget.booths;
    final exhibitionId = widget.exhibitionId;
    final selectedNotifier = ref.read(selectedBoothsProvider.notifier);
    final selected = ref.watch(selectedBoothsProvider);
    final user = ref.watch(authStateProvider);

    // --- Data needed for the "prevent adjacent competitors" rule ---
    final exhibition =
        ref.watch(exhibitionDetailProvider(exhibitionId)).valueOrNull;
    final applications =
        ref.watch(exhibitionApplicationsProvider(exhibitionId)).valueOrNull ??
            const <BoothApplication>[];
    final ruleOn = exhibition?.preventAdjacentCompetitors ?? false;
    // Build a map: boothId -> the company that already took that booth.
    final boothCompany = <String, String>{};
    for (final app in applications) {
      if (app.status == ApplicationStatus.approved ||
          app.status == ApplicationStatus.pending) {
        for (final boothId in app.boothIds) {
          boothCompany[boothId] = app.companyName;
        }
      }
    }
    // My company name (used to tell my own booths apart from competitors).
    String myCompany = user?.displayName ?? 'Unknown';
    final companyName = user?.companyName?.trim();
    if (companyName != null && companyName.isNotEmpty) myCompany = companyName;

    // Make the canvas big enough that NO booth is ever cut off, with a
    // 200px margin and a large minimum size for breathing room.
    double maxX = 700, maxY = 700;
    for (final b in booths) {
      if (b.x + b.width + 200 > maxX) maxX = b.x + b.width + 200;
      if (b.y + b.height + 200 > maxY) maxY = b.y + b.height + 200;
    }

    // Stack = the zoomable map + the floating zoom buttons on top.
    return Stack(children: [
      InteractiveViewer(
        transformationController: _transform,
        constrained: false, // let the canvas be bigger than the screen
        minScale: _minZoom,
        maxScale: _maxZoom,
        boundaryMargin: const EdgeInsets.all(400),
        // scaleEnabled true keeps mouse-wheel zoom + pinch zoom working.
        scaleEnabled: true,
        child: Container(
          width: maxX,
          height: maxY,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(children: [
            // Uploaded floor plan image sits behind everything.
            FloorPlanBackground(base64Image: exhibition?.floorPlanImageBase64),
            // Grid lines
            CustomPaint(size: Size(maxX, maxY), painter: _GridPainter()),
            // Booths
            ...booths.map((booth) {
              final isSelected = selected.any((b) => b.id == booth.id);
              final canSelect = booth.status == BoothStatus.available;
              return Positioned(
                left: booth.x,
                top: booth.y,
                width: booth.width,
                height: booth.height,
                child: GestureDetector(
                  onTap: () {
                    // Booked / unavailable booth that is NOT in my cart
                    // -> just show its details (cannot be selected).
                    if (!canSelect && !isSelected) {
                      _showBoothDetail(context, booth, isSelected, canSelect, null);
                      return;
                    }
                    // ADJACENT COMPETITOR RULE: only checked when the user
                    // is ABOUT TO ADD a booth (not when removing one).
                    if (!isSelected && canSelect && ruleOn) {
                      final competitor = competitorNextTo(
                        candidate: booth,
                        allBooths: booths,
                        boothCompany: boothCompany,
                        myCompany: myCompany,
                      );
                      if (competitor != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Cannot select Booth ${booth.boothNumber}. '
                              'It is next to "$competitor", a competitor.'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ));
                        return; // do not open the sheet for a blocked booth
                      }
                    }
                    // BUG FIX: do NOT toggle the booth here. We open the
                    // detail sheet showing the booth's CURRENT state, and
                    // the sheet's button does the add/remove. That way the
                    // button label always matches what will happen:
                    //   not selected yet -> button says "Add to Selection"
                    //   already selected -> button says "Remove from..."
                    _showBoothDetail(
                        context, booth, isSelected, canSelect, selectedNotifier);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _bgColor(booth.status, isSelected),
                      border: Border.all(
                        color: _borderColor(booth.status, isSelected),
                        width: isSelected ? 3 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppTheme.boothSelected.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)]
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(booth.boothNumber,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _textColor(booth.status, isSelected)),
                            textAlign: TextAlign.center),
                        Text('RM ${booth.price.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 8,
                                color: _textColor(booth.status, isSelected).withOpacity(0.8)),
                            textAlign: TextAlign.center),
                        if (isSelected)
                          const Icon(Icons.check_circle, size: 14, color: AppTheme.boothSelected),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ]),
        ),
      ),
      // ---- Zoom buttons (bottom-right corner) ----
      // The mouse scroll wheel ALSO zooms; these buttons are an easy,
      // obvious second way to zoom (handy on PC and touch).
      Positioned(
        right: 12,
        bottom: 12,
        child: _ZoomControls(
          onZoomIn: () => _zoom(1.25),
          onZoomOut: () => _zoom(0.8),
          onReset: _resetZoom,
        ),
      ),
    ]);
  }

  Color _bgColor(BoothStatus status, bool selected) {
    if (selected) return AppTheme.boothSelected.withOpacity(0.2);
    return switch (status) {
      BoothStatus.available => AppTheme.boothAvailable.withOpacity(0.15),
      BoothStatus.booked => AppTheme.boothBooked.withOpacity(0.15),
      BoothStatus.pending => AppTheme.boothPending.withOpacity(0.15),
      BoothStatus.unavailable => Colors.grey.withOpacity(0.15),
    };
  }

  Color _borderColor(BoothStatus status, bool selected) {
    if (selected) return AppTheme.boothSelected;
    return switch (status) {
      BoothStatus.available => AppTheme.boothAvailable,
      BoothStatus.booked => AppTheme.boothBooked,
      BoothStatus.pending => AppTheme.boothPending,
      BoothStatus.unavailable => Colors.grey,
    };
  }

  Color _textColor(BoothStatus status, bool selected) {
    if (selected) return AppTheme.boothSelected;
    return Colors.black87;
  }

  /// Shows the booth detail bottom sheet.
  ///
  /// [isCurrentlySelected] is the booth's selection state RIGHT NOW. The
  /// button label is built from it, so:
  ///   * not selected -> "Add to Selection"
  ///   * selected     -> "Remove from Selection"
  void _showBoothDetail(BuildContext context, Booth booth,
      bool isCurrentlySelected, bool canSelect, SelectedBoothsNotifier? notifier) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Booth ${booth.boothNumber}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            StatusChip(
              label: booth.status.name[0].toUpperCase() + booth.status.name.substring(1),
              color: _borderColor(booth.status, false),
            ),
          ]),
          const Divider(),
          InfoRow(icon: Icons.label_outline, label: 'Type', value: booth.boothType),
          InfoRow(icon: Icons.straighten, label: 'Size', value: '${booth.sizeqm} sqm'),
          InfoRow(icon: Icons.attach_money, label: 'Price', value: 'RM ${booth.price.toStringAsFixed(0)}'),
          if (booth.amenities.isNotEmpty)
            InfoRow(icon: Icons.star_outline, label: 'Amenities', value: booth.amenities.join(', ')),
          if (booth.notes != null && booth.notes!.isNotEmpty)
            InfoRow(icon: Icons.notes, label: 'Notes', value: booth.notes!),
          const SizedBox(height: 16),
          if (canSelect && notifier != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Do the actual add/remove here.
                  notifier.toggle(booth);
                  Navigator.pop(ctx);
                },
                icon: Icon(isCurrentlySelected
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline),
                label: Text(isCurrentlySelected
                    ? 'Remove from Selection'
                    : 'Add to Selection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCurrentlySelected ? Colors.orange : AppTheme.boothAvailable,
                ),
              ),
            ),
          if (!canSelect)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                booth.status == BoothStatus.booked
                    ? 'This booth is already booked.'
                    : 'This booth is not available.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Small stacked zoom in / out / reset buttons.
class _ZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  const _ZoomControls(
      {required this.onZoomIn, required this.onZoomOut, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Zoom in',
          onPressed: onZoomIn,
        ),
        const Divider(height: 1),
        IconButton(
          icon: const Icon(Icons.remove),
          tooltip: 'Zoom out',
          onPressed: onZoomOut,
        ),
        const Divider(height: 1),
        IconButton(
          icon: const Icon(Icons.center_focus_strong),
          tooltip: 'Reset zoom',
          onPressed: onReset,
        ),
      ]),
    );
  }
}

class _CartBar extends ConsumerWidget {
  final List<Booth> selected;
  final String exhibitionId;
  const _CartBar({required this.selected, required this.exhibitionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = selected.fold(0.0, (sum, b) => sum + b.price);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${selected.length} booth${selected.length > 1 ? 's' : ''} selected',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('RM ${total.toStringAsFixed(0)} total',
            style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
        ]),
        const Spacer(),
        OutlinedButton(
          onPressed: () => ref.read(selectedBoothsProvider.notifier).clear(),
          child: const Text('Clear'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => context.push('/exhibitor/apply/$exhibitionId'),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Apply'),
        ),
      ]),
    );
  }
}

class _CartSheet extends ConsumerWidget {
  final List<Booth> selected;
  final String exhibitionId;
  final ScrollController controller;
  const _CartSheet({required this.selected, required this.exhibitionId, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = selected.fold(0.0, (sum, b) => sum + b.price);
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        color: Colors.white,
      ),
      child: Column(children: [
        Container(
          width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Selected Booths', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${selected.length} booth${selected.length > 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.grey)),
          ]),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            controller: controller,
            itemCount: selected.length,
            itemBuilder: (ctx, i) {
              final b = selected[i];
              return ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.boothSelected.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.boothSelected),
                  ),
                  child: Center(child: Text(b.boothNumber, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                ),
                title: Text('${b.boothType} – ${b.boothNumber}'),
                subtitle: Text('${b.sizeqm} sqm • ${b.amenities.join(', ')}'),
                trailing: Text('RM ${b.price.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Text('Booth Total:', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('RM ${total.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); context.push('/exhibitor/apply/$exhibitionId'); },
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('Proceed to Application'),
            ),
          ),
        ),
      ]),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey.shade200..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ]);
}
