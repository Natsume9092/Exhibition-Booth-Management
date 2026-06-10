import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

/// dbProvider gives every screen access to the FirebaseService.
final dbProvider = Provider<FirebaseService>((ref) => FirebaseService());

// =====================================================================
// AUTHENTICATION
// =====================================================================

final authStateProvider = StateNotifierProvider<AuthNotifier, UserModel?>(
  (ref) => AuthNotifier(ref.watch(dbProvider)),
);

/// Holds the currently logged-in user (or null when nobody is logged in).
class AuthNotifier extends StateNotifier<UserModel?> {
  final FirebaseService _service;

  AuthNotifier(this._service) : super(null) {
    // When the app starts, Firebase remembers the last session.
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await _service.getCurrentUserModel();
    if (mounted) state = user;
  }

  Future<String?> login(String email, String password) async {
    try {
      final user = await _service.login(email, password);
      if (user == null) return 'Invalid email or password';
      state = user;
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? companyName,
    String? phone,
  }) async {
    try {
      final user = await _service.register(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        companyName: companyName,
        phone: phone,
      );
      if (user == null) return 'Email already registered';
      state = user;
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _service.logout();
    state = null;
  }

  /// Saves a new profile picture (base64 text) for the logged-in user and
  /// refreshes the in-memory user so the new picture shows immediately.
  /// Pass an empty string to remove the picture.
  Future<String?> updatePhoto(String photoBase64) async {
    final current = state;
    if (current == null) return 'You are not logged in';
    try {
      final updated = current.copyWith(photoBase64: photoBase64);
      await _service.updateUser(updated);
      state = updated;
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

// =====================================================================
// LIVE BASE STREAMS (private)
// =====================================================================
// These connect once to Firestore and stay live. Every other provider
// below is built FROM these, so the whole app shares only a few
// connections but still updates in real time.

final _allExhibitionsStream = StreamProvider<List<Exhibition>>(
  (ref) => ref.watch(dbProvider).streamAllExhibitions(),
);

final _publishedExhibitionsStream = StreamProvider<List<Exhibition>>(
  (ref) => ref.watch(dbProvider).streamPublishedExhibitions(),
);

final _allApplicationsStream = StreamProvider<List<BoothApplication>>(
  (ref) => ref.watch(dbProvider).streamAllApplications(),
);

/// The id used for the seeded sample exhibitions. The organizer is allowed
/// to see and manage these shared sample exhibitions as well as their own.
const String kDemoOrganizerId = 'demo-organizer';

// =====================================================================
// EXHIBITIONS
// =====================================================================

/// Search / category / status filter for the exhibition list.
class ExhibitionFilter {
  final String? search;
  final String? category;
  final ExhibitionStatus? status;
  const ExhibitionFilter({this.search, this.category, this.status});

  @override
  bool operator ==(Object other) =>
      other is ExhibitionFilter &&
      other.search == search &&
      other.category == category &&
      other.status == status;

  @override
  int get hashCode => Object.hash(search, category, status);
}

/// The exhibition list each role sees. It returns an [AsyncValue] so the
/// screens can still use `.when(loading:, error:, data:)` as before.
///  - Admin     -> every exhibition.
///  - Organizer -> their own exhibitions + the shared sample exhibitions.
///  - Guest/Exhibitor -> published exhibitions, with the search filter.
final exhibitionsProvider =
    Provider.family<AsyncValue<List<Exhibition>>, ExhibitionFilter>(
        (ref, filter) {
  final user = ref.watch(authStateProvider);

  if (user?.role == UserRole.admin) {
    return ref.watch(_allExhibitionsStream);
  }

  if (user?.role == UserRole.organizer) {
    return ref.watch(_allExhibitionsStream).whenData((list) => list
        .where((e) =>
            e.organizerId == user!.id || e.organizerId == kDemoOrganizerId)
        .toList());
  }

  // Guest or exhibitor: published exhibitions only, then apply the filter.
  return ref.watch(_publishedExhibitionsStream).whenData((list) {
    var result = list;
    final search = filter.search;
    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.venue.toLowerCase().contains(q))
          .toList();
    }
    if (filter.category != null && filter.category!.isNotEmpty) {
      result = result.where((e) => e.category == filter.category).toList();
    }
    if (filter.status != null) {
      result = result.where((e) => e.status == filter.status).toList();
    }
    return result;
  });
});

/// Live details of one exhibition (one Firestore document stream).
final exhibitionDetailProvider = StreamProvider.family<Exhibition?, String>(
  (ref, id) => ref.watch(dbProvider).streamExhibition(id),
);

// =====================================================================
// BOOTHS
// =====================================================================

/// Live list of booths for one exhibition.
final boothsProvider = StreamProvider.family<List<Booth>, String>(
  (ref, exhibitionId) => ref.watch(dbProvider).streamBooths(exhibitionId),
);

// =====================================================================
// ADD-ON ITEMS
// =====================================================================

/// Live list of add-on items. Using a STREAM (not a one-off Future) means
/// that when the Admin adds, edits or deletes an add-on item, the
/// exhibitor / organizer pages update on their own.
final addItemsProvider = StreamProvider<List<AddItem>>(
  (ref) => ref.watch(dbProvider).streamAddItems(),
);

// =====================================================================
// APPLICATIONS
// =====================================================================

/// Applications shown on the "My Applications" / "All Bookings" screens.
///  - Admin / Organizer -> all applications.
///  - Exhibitor         -> only their own applications.
final myApplicationsProvider =
    Provider<AsyncValue<List<BoothApplication>>>((ref) {
  final user = ref.watch(authStateProvider);
  if (user == null) return const AsyncValue.data([]);

  if (user.role == UserRole.admin || user.role == UserRole.organizer) {
    return ref.watch(_allApplicationsStream);
  }
  return ref.watch(_allApplicationsStream).whenData(
      (list) => list.where((a) => a.exhibitorId == user.id).toList());
});

/// Live applications for one exhibition.
final exhibitionApplicationsProvider =
    Provider.family<AsyncValue<List<BoothApplication>>, String>(
  (ref, exhibitionId) => ref.watch(_allApplicationsStream).whenData(
      (list) => list.where((a) => a.exhibitionId == exhibitionId).toList()),
);

/// All applications that belong to the logged-in organizer's exhibitions
/// (used by the organizer "Applications" bottom-nav tab).
final organizerApplicationsProvider =
    Provider<AsyncValue<List<BoothApplication>>>((ref) {
  final exhibitionsAsync = ref.watch(exhibitionsProvider(const ExhibitionFilter()));
  final myExhibitionIds =
      (exhibitionsAsync.valueOrNull ?? <Exhibition>[]).map((e) => e.id).toSet();
  return ref.watch(_allApplicationsStream).whenData((apps) =>
      apps.where((a) => myExhibitionIds.contains(a.exhibitionId)).toList());
});

// =====================================================================
// BOOTH SELECTION CART
// =====================================================================

final selectedBoothsProvider =
    StateNotifierProvider<SelectedBoothsNotifier, List<Booth>>(
  (ref) => SelectedBoothsNotifier(),
);

class SelectedBoothsNotifier extends StateNotifier<List<Booth>> {
  SelectedBoothsNotifier() : super([]);

  void toggle(Booth booth) {
    if (state.any((b) => b.id == booth.id)) {
      state = state.where((b) => b.id != booth.id).toList();
    } else {
      state = [...state, booth];
    }
  }

  void clear() => state = [];

  bool isSelected(String boothId) => state.any((b) => b.id == boothId);
}

// =====================================================================
// USERS (admin)
// =====================================================================

/// Live list of all user accounts.
final allUsersProvider = StreamProvider<List<UserModel>>(
  (ref) => ref.watch(dbProvider).streamAllUsers(),
);
