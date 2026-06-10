import 'dart:convert'; // for base64Encode (floor plan image)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // pick image from gallery
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/booth_rules.dart'; // boothsOverlap()
import '../../widgets/widgets.dart';
import '../../theme/app_theme.dart';

/// What the current drag in "Edit Layout" mode is doing.
enum _EditAction {
  move,         // dragging the body -> move the booth
  resizeWidth,  // dragging the right edge -> change WIDTH only
  resizeHeight, // dragging the bottom edge -> change HEIGHT only
  resizeBoth,   // dragging the corner -> change width AND height
}

/// Admin floor plan / layout builder.
///
/// Features:
///  - The canvas is BIG and you can pan + zoom around it (mouse scroll
///    wheel zooms, on PC; the +/- buttons zoom too).
///  - In "Edit Layout" mode you can DRAG a booth to move it, and use the
///    RESIZE HANDLES to change its size:
///      * right edge handle  -> width only
///      * bottom edge handle -> height only
///      * corner handle      -> width and height together
///  - Booths are not allowed to overlap each other.
///  - Drag/resize is saved to Firestore only when the gesture ENDS, so it
///    is smooth and does not flood the database.
class AdminFloorPlanScreen extends ConsumerStatefulWidget {
  final String exhibitionId;
  const AdminFloorPlanScreen({super.key, required this.exhibitionId});
  @override
  ConsumerState<AdminFloorPlanScreen> createState() =>
      _AdminFloorPlanScreenState();
}

class _AdminFloorPlanScreenState extends ConsumerState<AdminFloorPlanScreen> {
  bool _editMode = false;

  /// What the current drag gesture is doing (move / resize which side).
  _EditAction _action = _EditAction.move;

  /// While the admin is dragging or resizing a booth, the new position /
  /// size is kept here (key = boothId). It is written to Firestore only
  /// when the gesture finishes. This keeps dragging smooth.
  final Map<String, Booth> _localEdits = {};

  /// Controls pan + zoom of the canvas (mouse-wheel zoom + zoom buttons).
  final TransformationController _transform = TransformationController();

  static const double _minZoom = 0.2;
  static const double _maxZoom = 4.0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final matrix = _transform.value.clone();
    final current = matrix.getMaxScaleOnAxis();
    final next = current * factor;
    if (next < _minZoom || next > _maxZoom) return;
    matrix.scale(factor, factor);
    _transform.value = matrix;
  }

  void _resetZoom() => _transform.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final exhibitionAsync =
        ref.watch(exhibitionDetailProvider(widget.exhibitionId));
    final boothsAsync = ref.watch(boothsProvider(widget.exhibitionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(exhibitionAsync.valueOrNull?.title ?? 'Floor Plan'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _editMode = !_editMode;
              _localEdits.clear();
            }),
            icon: Icon(_editMode ? Icons.done : Icons.edit,
                color: Colors.white),
            label: Text(_editMode ? 'Done' : 'Edit Layout',
                style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add Booth',
            onPressed: () => _showAddBoothSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Floor Plan Image',
            onSelected: (value) {
              if (value == 'upload') _uploadFloorPlanImage(context);
              if (value == 'remove') _removeFloorPlanImage(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'upload', child: Text('Upload floor plan image')),
              PopupMenuItem(
                  value: 'remove', child: Text('Remove floor plan image')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        // Help bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _editMode ? Colors.orange.shade50 : Colors.grey.shade50,
          child: Row(children: [
            Icon(_editMode ? Icons.open_with : Icons.touch_app,
                size: 16, color: _editMode ? Colors.orange : Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _editMode
                    ? 'Drag a booth to move it. Drag the right/bottom/corner '
                        'handles to resize width, height or both.'
                    : 'Tap a booth to view details. Scroll the mouse wheel '
                        'or use the +/- buttons to zoom.',
                style: TextStyle(
                    fontSize: 12,
                    color: _editMode
                        ? Colors.orange.shade800
                        : Colors.grey.shade700),
              ),
            ),
          ]),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Legend(color: AppTheme.boothAvailable, label: 'Available'),
                _Legend(color: AppTheme.boothBooked, label: 'Booked'),
                _Legend(color: AppTheme.boothPending, label: 'Pending'),
                _Legend(color: Colors.grey, label: 'Unavailable'),
              ]),
        ),
        // Canvas
        Expanded(
          child: boothsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => ErrorWidget2(message: e.toString()),
            data: (booths) => _buildCanvas(
                booths, exhibitionAsync.valueOrNull?.floorPlanImageBase64),
          ),
        ),
        // Bottom stats
        boothsAsync.when(
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
          data: (booths) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BoothStat(
                      label: 'Total',
                      value: booths.length,
                      color: Colors.grey),
                  _BoothStat(
                      label: 'Available',
                      value: booths
                          .where((b) => b.status == BoothStatus.available)
                          .length,
                      color: AppTheme.boothAvailable),
                  _BoothStat(
                      label: 'Booked',
                      value: booths
                          .where((b) => b.status == BoothStatus.booked)
                          .length,
                      color: AppTheme.boothBooked),
                  _BoothStat(
                      label: 'Pending',
                      value: booths
                          .where((b) => b.status == BoothStatus.pending)
                          .length,
                      color: AppTheme.boothPending),
                ]),
          ),
        ),
      ]),
    );
  }

  /// Returns the booth with any in-progress drag/resize applied.
  Booth _effective(Booth booth) => _localEdits[booth.id] ?? booth;

  Widget _buildCanvas(List<Booth> booths, String? floorPlanImage) {
    // Work out how big the canvas must be so NO booth is ever cut off.
    double maxX = 1000, maxY = 1000;
    for (final booth in booths) {
      final b = _effective(booth);
      if (b.x + b.width + 300 > maxX) maxX = b.x + b.width + 300;
      if (b.y + b.height + 300 > maxY) maxY = b.y + b.height + 300;
    }

    // Stack = the zoomable canvas + the floating zoom buttons on top.
    return Stack(children: [
      InteractiveViewer(
        transformationController: _transform,
        constrained: false, // the canvas may be bigger than the screen
        minScale: _minZoom,
        maxScale: _maxZoom,
        boundaryMargin: const EdgeInsets.all(400),
        scaleEnabled: true, // mouse-wheel zoom + pinch zoom
        child: Container(
          width: maxX,
          height: maxY,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(children: [
            FloorPlanBackground(base64Image: floorPlanImage),
            CustomPaint(size: Size(maxX, maxY), painter: _GridPainter()),
            ...booths.map((booth) => _buildBoothWidget(booth, booths)),
          ]),
        ),
      ),
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

  Widget _buildBoothWidget(Booth original, List<Booth> allBooths) {
    final booth = _effective(original);
    final color = _colorForStatus(booth.status);

    // VIEW MODE: tap a booth to see its details.
    if (!_editMode) {
      return Positioned(
        left: booth.x,
        top: booth.y,
        width: booth.width,
        height: booth.height,
        child: GestureDetector(
          onTap: () => _showBoothDetail(booth),
          child: _BoothBox(booth: booth, color: color, editMode: false),
        ),
      );
    }

    // EDIT MODE: ONE gesture detector. Where the drag STARTS decides what
    // happens:
    //   * right edge   -> resize WIDTH
    //   * bottom edge  -> resize HEIGHT
    //   * corner       -> resize BOTH
    //   * anywhere else-> MOVE
    return Positioned(
      left: booth.x,
      top: booth.y,
      width: booth.width,
      height: booth.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          final w = booth.width, h = booth.height;
          final dx = d.localPosition.dx, dy = d.localPosition.dy;
          final nearRight = dx > w - 26;
          final nearBottom = dy > h - 26;
          if (nearRight && nearBottom) {
            _action = _EditAction.resizeBoth;
          } else if (nearRight) {
            _action = _EditAction.resizeWidth;
          } else if (nearBottom) {
            _action = _EditAction.resizeHeight;
          } else {
            _action = _EditAction.move;
          }
          _localEdits[original.id] = booth;
        },
        onPanUpdate: (d) {
          switch (_action) {
            case _EditAction.move:
              _moveBooth(original, d.delta, allBooths);
              break;
            case _EditAction.resizeWidth:
              _resize(original, d.delta, allBooths, width: true, height: false);
              break;
            case _EditAction.resizeHeight:
              _resize(original, d.delta, allBooths, width: false, height: true);
              break;
            case _EditAction.resizeBoth:
              _resize(original, d.delta, allBooths, width: true, height: true);
              break;
          }
        },
        onPanEnd: (_) => _commitEdit(original.id),
        child: Stack(children: [
          Positioned.fill(
            child: _BoothBox(booth: booth, color: color, editMode: true),
          ),
          // ---- Resize handles (visual only - the gesture detector above
          // reads where the drag started and does the real work) ----
          // Right edge handle = WIDTH.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  width: 14,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.boothSelected,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.swap_horiz,
                      size: 11, color: Colors.white),
                ),
              ),
            ),
          ),
          // Bottom edge handle = HEIGHT.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  width: 40,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.boothSelected,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.swap_vert,
                      size: 11, color: Colors.white),
                ),
              ),
            ),
          ),
          // Corner handle = WIDTH + HEIGHT together.
          Positioned(
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomRight: Radius.circular(3)),
                ),
                child: const Icon(Icons.open_in_full,
                    size: 13, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Moves a booth, but only if the new position does not overlap others.
  void _moveBooth(Booth original, Offset delta, List<Booth> allBooths) {
    final current = _effective(original);
    final newX = (current.x + delta.dx).clamp(0.0, 6000.0);
    final newY = (current.y + delta.dy).clamp(0.0, 6000.0);
    final candidate = current.copyWith(x: newX, y: newY);
    if (_overlapsAny(candidate, original.id, allBooths)) return; // blocked
    setState(() => _localEdits[original.id] = candidate);
  }

  /// Resizes a booth. [width] / [height] choose which side(s) change, so
  /// the same method serves the right, bottom and corner handles.
  /// The change is blocked if it would make the booth overlap another.
  void _resize(Booth original, Offset delta, List<Booth> allBooths,
      {required bool width, required bool height}) {
    final current = _effective(original);
    // Minimum size 50 so a booth never becomes too small to tap.
    final newW = width
        ? (current.width + delta.dx).clamp(50.0, 1200.0)
        : current.width;
    final newH = height
        ? (current.height + delta.dy).clamp(50.0, 1200.0)
        : current.height;
    final candidate = current.copyWith(width: newW, height: newH);
    if (_overlapsAny(candidate, original.id, allBooths)) return; // blocked
    setState(() => _localEdits[original.id] = candidate);
  }

  /// True if [candidate] would cover the same area as any other booth.
  bool _overlapsAny(Booth candidate, String selfId, List<Booth> allBooths) {
    for (final other in allBooths) {
      if (other.id == selfId) continue;
      if (boothsOverlap(candidate, _effective(other))) return true;
    }
    return false;
  }

  /// Saves the final position/size to Firestore once the drag/resize ends.
  Future<void> _commitEdit(String boothId) async {
    final edited = _localEdits[boothId];
    if (edited == null) return;
    await ref.read(dbProvider).updateBooth(edited);
    if (mounted) setState(() => _localEdits.remove(boothId));
  }

  Color _colorForStatus(BoothStatus s) => switch (s) {
        BoothStatus.available => AppTheme.boothAvailable,
        BoothStatus.booked => AppTheme.boothBooked,
        BoothStatus.pending => AppTheme.boothPending,
        BoothStatus.unavailable => Colors.grey,
      };

  void _showBoothDetail(Booth booth) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text('Booth ${booth.boothNumber}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold))),
                StatusChip(
                  label: booth.status.name[0].toUpperCase() +
                      booth.status.name.substring(1),
                  color: _colorForStatus(booth.status),
                ),
              ]),
              const Divider(),
              InfoRow(
                  icon: Icons.label, label: 'Type', value: booth.boothType),
              InfoRow(
                  icon: Icons.straighten,
                  label: 'Size',
                  value: '${booth.sizeqm} sqm'),
              InfoRow(
                  icon: Icons.attach_money,
                  label: 'Price',
                  value: 'RM ${booth.price.toStringAsFixed(0)}'),
              InfoRow(
                  icon: Icons.aspect_ratio,
                  label: 'Box',
                  value:
                      '${booth.width.toInt()} x ${booth.height.toInt()} at (${booth.x.toInt()}, ${booth.y.toInt()})'),
              if (booth.amenities.isNotEmpty)
                InfoRow(
                    icon: Icons.star_outline,
                    label: 'Amenities',
                    value: booth.amenities.join(', ')),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final newStatus = booth.status == BoothStatus.unavailable
                        ? BoothStatus.available
                        : BoothStatus.unavailable;
                    await ref
                        .read(dbProvider)
                        .updateBooth(booth.copyWith(status: newStatus));
                  },
                  icon: const Icon(Icons.toggle_on),
                  label: Text(booth.status == BoothStatus.unavailable
                      ? 'Enable'
                      : 'Disable'),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(dbProvider).deleteBooth(booth.id);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red),
                )),
              ]),
            ]),
      ),
    );
  }

  void _showAddBoothSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddBoothForm(exhibitionId: widget.exhibitionId, ref: ref),
      ),
    );
  }

  /// Lets the Admin pick an image and save it as the floor plan image.
  Future<void> _uploadFloorPlanImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 60,
      );
      if (picked == null) return; // the user cancelled

      final bytes = await picked.readAsBytes();
      // A Firestore document holds about 1 MB. base64 text is ~33% bigger,
      // so keep the raw image under 650 KB.
      if (bytes.lengthInBytes > 650 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Image is too large. Please choose a smaller image.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      final base64Image = base64Encode(bytes);
      await ref
          .read(dbProvider)
          .setFloorPlanImage(widget.exhibitionId, base64Image);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Floor plan image uploaded.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _removeFloorPlanImage(BuildContext context) async {
    await ref.read(dbProvider).setFloorPlanImage(widget.exhibitionId, null);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Floor plan image removed.'),
      ));
    }
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
            onPressed: onZoomIn),
        const Divider(height: 1),
        IconButton(
            icon: const Icon(Icons.remove),
            tooltip: 'Zoom out',
            onPressed: onZoomOut),
        const Divider(height: 1),
        IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Reset zoom',
            onPressed: onReset),
      ]),
    );
  }
}

/// The visible booth box (just the coloured rectangle + label).
/// It has no fixed size - it fills whatever space its parent gives it.
class _BoothBox extends StatelessWidget {
  final Booth booth;
  final Color color;
  final bool editMode;
  const _BoothBox(
      {required this.booth, required this.color, required this.editMode});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.25),
          border: Border.all(color: color, width: editMode ? 2.5 : 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(booth.boothNumber,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  Text('RM ${booth.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center),
                ]),
          ),
        ),
      );
}

/// Clean "Add Booth" form shown in a bottom sheet.
class _AddBoothForm extends StatefulWidget {
  final String exhibitionId;
  final WidgetRef ref;
  const _AddBoothForm({required this.exhibitionId, required this.ref});

  @override
  State<_AddBoothForm> createState() => _AddBoothFormState();
}

class _AddBoothFormState extends State<_AddBoothForm> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '1200');
  final _sizeCtrl = TextEditingController(text: '16');
  String _type = 'Standard';
  final Set<String> _amenities = {'Power', 'WiFi'};
  bool _saving = false;

  final _types = ['Economy', 'Standard', 'Premium'];
  final _amenityOptions = ['Power', 'WiFi', 'Corner', 'Extra Display',
    'Storage'];

  @override
  Widget build(BuildContext context) {
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
              const Text('Add New Booth',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('The new booth is placed automatically in an empty spot '
                  'so it never overlaps another booth. You can drag it after.',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 20),

              TextFormField(
                controller: _numberCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Booth Number',
                  hintText: 'e.g. A-06',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Booth Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _types
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'Standard'),
              ),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: 'RM ',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sizeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Size',
                      suffixText: 'sqm',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              const Text('Amenities',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _amenityOptions
                    .map((a) => FilterChip(
                          label: Text(a),
                          selected: _amenities.contains(a),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _amenities.add(a);
                            } else {
                              _amenities.remove(a);
                            }
                          }),
                        ))
                    .toList(),
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
                      : const Icon(Icons.add),
                  label: const Text('Add Booth'),
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
      // x:0,y:0 means "no chosen position" - createBooth() will then
      // place the booth automatically in the first free spot.
      final booth = Booth(
        id: '',
        exhibitionId: widget.exhibitionId,
        boothNumber: _numberCtrl.text.trim(),
        boothType: _type,
        sizeqm: double.tryParse(_sizeCtrl.text) ?? 16,
        price: double.tryParse(_priceCtrl.text) ?? 1200,
        status: BoothStatus.available,
        x: 0,
        y: 0,
        width: 110,
        height: 110,
        amenities: _amenities.toList(),
      );
      await db.createBooth(booth);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
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

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]);
}

class _BoothStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _BoothStat(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text('$value',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ]);
}
