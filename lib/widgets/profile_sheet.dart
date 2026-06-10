import 'dart:convert'; // base64Encode / base64Decode for the photo
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart'; // pick image from gallery
import '../models/models.dart';
import '../providers/providers.dart';

/// profileAvatar
/// -------------
/// Builds a round avatar. If the user has uploaded a profile picture it
/// shows the picture; otherwise it shows a fallback icon. It is used both
/// in the app bar (small) and inside the profile sheet (large).
Widget profileAvatar(
  UserModel? user, {
  double radius = 20,
  Color background = Colors.white24,
  IconData fallbackIcon = Icons.person,
  Color iconColor = Colors.white,
}) {
  if (user != null && user.hasPhoto) {
    try {
      // Turn the saved base64 text back into image bytes.
      final bytes = base64Decode(user.photoBase64!);
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
    } catch (_) {
      // The saved text was not a valid image -> fall through to the icon.
    }
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: background,
    child: Icon(fallbackIcon, color: iconColor, size: radius * 1.1),
  );
}

/// Opens the profile bottom sheet. EVERY logged-in role (admin, organizer,
/// exhibitor) uses this same sheet, so the "upload profile picture"
/// feature works the same everywhere. The user just taps their picture.
void showProfileSheet(
  BuildContext context, {
  required String roleLabel,
  required Color roleColor,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ProfileSheet(roleLabel: roleLabel, roleColor: roleColor),
  );
}

class _ProfileSheet extends ConsumerStatefulWidget {
  final String roleLabel;
  final Color roleColor;
  const _ProfileSheet({required this.roleLabel, required this.roleColor});

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  // True while a photo is being picked / uploaded / removed.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    // Watching here means the sheet redraws the instant the photo changes.
    final user = ref.watch(authStateProvider);
    final hasPhoto = user != null && user.hasPhoto;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Small grey drag handle.
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Tappable avatar with a small camera badge -> upload a new photo.
        GestureDetector(
          onTap: _busy ? null : _pickPhoto,
          child: Stack(children: [
            profileAvatar(user,
                radius: 44,
                background: widget.roleColor,
                fallbackIcon: Icons.person,
                iconColor: Colors.white),
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.roleColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ),
          ]),
        ),
        TextButton.icon(
          onPressed: _busy ? null : _pickPhoto,
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(hasPhoto ? 'Change profile photo' : 'Upload profile photo'),
        ),
        Text(user?.displayName ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
        if (user?.companyName != null && user!.companyName!.isNotEmpty)
          Text(user.companyName!, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Chip(
          label: Text(widget.roleLabel),
          backgroundColor: widget.roleColor.withOpacity(0.15),
        ),
        const SizedBox(height: 16),
        // Only show "Remove photo" when there is a photo to remove.
        if (hasPhoto)
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _busy ? null : _removePhoto,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Remove photo',
                  style: TextStyle(color: Colors.red)),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            onPressed: _busy
                ? null
                : () async {
                    Navigator.pop(context);
                    await ref.read(authStateProvider.notifier).logout();
                    if (context.mounted) context.go('/');
                  },
          ),
        ),
      ]),
    );
  }

  /// Lets the user pick an image from the gallery, then saves it as the
  /// profile photo (stored as base64 text on the user document).
  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,    // a small picture keeps the base64 text small
        imageQuality: 55, // compress so it fits inside one Firestore doc
      );
      if (picked == null) return; // the user cancelled

      setState(() => _busy = true);
      final bytes = await picked.readAsBytes();
      // A Firestore document holds ~1 MB. base64 text is ~33% larger, so
      // keep the raw image under 500 KB to stay safely inside the limit.
      if (bytes.lengthInBytes > 500 * 1024) {
        _toast('Image is too large. Please choose a smaller photo.',
            isError: true);
        return;
      }
      final base64Image = base64Encode(bytes);
      final error =
          await ref.read(authStateProvider.notifier).updatePhoto(base64Image);
      _toast(error ?? 'Profile photo updated.', isError: error != null);
    } catch (e) {
      _toast('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Clears the profile photo (saves an empty string).
  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    final error = await ref.read(authStateProvider.notifier).updatePhoto('');
    if (mounted) setState(() => _busy = false);
    _toast(error ?? 'Profile photo removed.', isError: error != null);
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : null,
    ));
  }
}
