import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../utils/booth_rules.dart'; // boothsOverlap() - used to auto-place booths

/// FirebaseService
/// ---------------
/// This class REPLACES the old `MockDatabase`. It talks to two Firebase
/// products:
///   1. Firebase Authentication -> handles login / register securely.
///   2. Cloud Firestore         -> stores all app data (the database
///      "exhibition_booth_management").
///
/// IMPORTANT: every public method below uses the SAME NAME and SAME
/// parameters as the old MockDatabase. That is why the screen files do
/// NOT need to change - only this file, providers.dart and main.dart change.
///
/// Firestore "collections" are like database tables:
///   users        -> one document per user account (the document id = uid)
///   exhibitions  -> one document per exhibition event
///   booths       -> one document per booth
///   applications -> one document per booth application
///   addItems     -> one document per optional add-on item
class FirebaseService {
  // The cloud database instance.
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // The login / authentication instance.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---- Collection shortcuts (each one acts like a table) ----
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _exhibitions =>
      _db.collection('exhibitions');
  CollectionReference<Map<String, dynamic>> get _booths =>
      _db.collection('booths');
  CollectionReference<Map<String, dynamic>> get _applications =>
      _db.collection('applications');
  CollectionReference<Map<String, dynamic>> get _addItems =>
      _db.collection('addItems');

  // =====================================================================
  // AUTHENTICATION
  // =====================================================================

  /// Logs a user in with email + password through Firebase Authentication.
  /// Returns the matching [UserModel], or null if the login failed.
  Future<UserModel?> login(String email, String password) async {
    try {
      // Step 1: ask Firebase Auth to check the email + password.
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      // Step 2: load this user's profile (role, name...) from Firestore.
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null; // login ok but profile missing
      return UserModel.fromMap(doc.data()!, uid);
    } on FirebaseAuthException {
      // Wrong password / user not found / etc.
      // Return null so the UI shows "Invalid email or password".
      return null;
    }
  }

  /// Creates a new secure account, then saves the user profile
  /// (including the chosen role) into Firestore.
  /// Returns the [UserModel], or null if the email is already used.
  Future<UserModel?> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? companyName,
    String? phone,
  }) async {
    try {
      // Step 1: create the secure login account in Firebase Auth.
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user!.uid;
      // Step 2: build the profile object.
      final user = UserModel(
        id: uid,
        email: email.trim(),
        displayName: displayName,
        role: role,
        companyName: companyName,
        phone: phone,
        createdAt: DateTime.now(),
      );
      // Step 3: save the profile in Firestore at users/{uid}.
      await _users.doc(uid).set(user.toMap());
      return user;
    } on FirebaseAuthException catch (e) {
      // Email already registered -> return null (UI shows a clear message).
      if (e.code == 'email-already-in-use') return null;
      // Any other error -> throw a readable message.
      throw Exception(e.message ?? 'Registration failed');
    }
  }

  /// Signs the current user out.
  Future<void> logout() async => _auth.signOut();

  /// Loads the [UserModel] of whoever is currently signed in.
  /// Firebase remembers the session, so this is used at app start
  /// to keep the user logged in. Returns null if nobody is signed in.
  Future<UserModel?> getCurrentUserModel() async {
    final authUser = _auth.currentUser;
    if (authUser == null) return null;
    final doc = await _users.doc(authUser.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, authUser.uid);
  }

  // =====================================================================
  // EXHIBITIONS
  // =====================================================================

  /// Returns published exhibitions only (used by guests and exhibitors).
  /// Search / category / status filtering is done in Dart because
  /// Firestore cannot do "text contains" searches.
  Future<List<Exhibition>> getPublishedExhibitions({
    String? search,
    String? category,
    ExhibitionStatus? status,
  }) async {
    final snap =
        await _exhibitions.where('isPublished', isEqualTo: true).get();
    var list =
        snap.docs.map((d) => Exhibition.fromMap(d.data(), d.id)).toList();

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.venue.toLowerCase().contains(q))
          .toList();
    }
    if (category != null && category.isNotEmpty) {
      list = list.where((e) => e.category == category).toList();
    }
    if (status != null) {
      list = list.where((e) => e.status == status).toList();
    }
    return list;
  }

  /// Returns ALL exhibitions. If [organizerId] is given, returns only the
  /// exhibitions owned by that organizer.
  Future<List<Exhibition>> getAllExhibitions({String? organizerId}) async {
    final QuerySnapshot<Map<String, dynamic>> snap;
    if (organizerId != null) {
      snap = await _exhibitions
          .where('organizerId', isEqualTo: organizerId)
          .get();
    } else {
      snap = await _exhibitions.get();
    }
    return snap.docs.map((d) => Exhibition.fromMap(d.data(), d.id)).toList();
  }

  /// Returns a single exhibition by id, or null if it does not exist.
  Future<Exhibition?> getExhibition(String id) async {
    final doc = await _exhibitions.doc(id).get();
    if (!doc.exists) return null;
    return Exhibition.fromMap(doc.data()!, doc.id);
  }

  /// Creates a new exhibition. Firestore generates a unique id for it.
  /// NOTE: unlike the old MockDatabase, this saves ALL fields correctly
  /// because toMap() includes every field.
  Future<Exhibition> createExhibition(Exhibition exhibition) async {
    final ref = await _exhibitions.add(exhibition.toMap());
    return Exhibition.fromMap(exhibition.toMap(), ref.id);
  }

  /// Updates an existing exhibition.
  Future<Exhibition> updateExhibition(Exhibition exhibition) async {
    await _exhibitions.doc(exhibition.id).update(exhibition.toMap());
    return exhibition;
  }

  /// Deletes an exhibition and EVERYTHING that depends on it.
  ///
  /// This fixes the "orphan data" bug: when an exhibition is removed, any
  /// booths AND any booth applications that point to it must be removed
  /// too. Otherwise exhibitors would still see pending/requested booths
  /// for an exhibition that no longer exists.
  ///
  /// All three deletes run inside ONE Firestore batch so they either all
  /// succeed or all fail together (no half-deleted data).
  Future<void> deleteExhibition(String id) async {
    final batch = _db.batch();

    // 1. The exhibition document itself.
    batch.delete(_exhibitions.doc(id));

    // 2. Every booth that belongs to this exhibition.
    final booths = await _booths.where('exhibitionId', isEqualTo: id).get();
    for (final d in booths.docs) {
      batch.delete(d.reference);
    }

    // 3. Every booth application for this exhibition (pending, approved,
    //    rejected or cancelled) - they are now meaningless.
    final apps =
        await _applications.where('exhibitionId', isEqualTo: id).get();
    for (final d in apps.docs) {
      batch.delete(d.reference);
    }

    await batch.commit();
  }

  // =====================================================================
  // BOOTHS
  // =====================================================================

  /// Returns every booth that belongs to one exhibition.
  Future<List<Booth>> getBooths(String exhibitionId) async {
    final snap =
        await _booths.where('exhibitionId', isEqualTo: exhibitionId).get();
    return snap.docs.map((d) => Booth.fromMap(d.data(), d.id)).toList();
  }

  /// Returns a single booth by id, or null if it does not exist.
  Future<Booth?> getBooth(String boothId) async {
    final doc = await _booths.doc(boothId).get();
    if (!doc.exists) return null;
    return Booth.fromMap(doc.data()!, doc.id);
  }

  /// Creates a new booth. Firestore generates a unique id for it.
  ///
  /// BUG FIX: before, a second (or third...) booth created from the
  /// Organizer page was always saved at the same x/y (0,0). On the floor
  /// plan every new booth then sat exactly on top of the previous one.
  /// Now [_findFreePosition] moves the new booth into the nearest EMPTY
  /// space, so booths never overlap - no matter how many are added.
  Future<Booth> createBooth(Booth booth) async {
    // Load the booths that already exist in this exhibition.
    final existing = await getBooths(booth.exhibitionId);
    // Move the new booth to a spot where it does not cover another booth.
    final placed = _findFreePosition(booth, existing);
    final ref = await _booths.add(placed.toMap());
    // Keep the exhibition's booth counts up to date.
    await _recalcBoothCounts(booth.exhibitionId);
    return Booth.fromMap(placed.toMap(), ref.id);
  }

  /// Returns a copy of [booth] whose x/y do not overlap any booth in
  /// [existing]. If the requested position is already free it is kept;
  /// otherwise the floor is scanned left-to-right, top-to-bottom for the
  /// first empty cell.
  Booth _findFreePosition(Booth booth, List<Booth> existing) {
    const double gap = 20.0;     // empty space left between booths
    const double startX = 20.0;  // first column position
    const double startY = 20.0;  // first row position
    final double stepX = booth.width + gap;
    final double stepY = booth.height + gap;

    // Helper: is the booth free of overlaps at position (x, y)?
    bool isFree(double x, double y) {
      final candidate = booth.copyWith(x: x, y: y);
      for (final other in existing) {
        if (boothsOverlap(candidate, other)) return false;
      }
      return true;
    }

    // If the caller already chose a real (non zero) spot and it is free,
    // respect it (the Admin floor-plan editor places booths on purpose).
    if ((booth.x != 0 || booth.y != 0) && isFree(booth.x, booth.y)) {
      return booth;
    }

    // Otherwise scan a grid for the first empty cell (10 columns wide).
    for (int row = 0; row < 200; row++) {
      for (int col = 0; col < 10; col++) {
        final double x = startX + col * stepX;
        final double y = startY + row * stepY;
        if (isFree(x, y)) return booth.copyWith(x: x, y: y);
      }
    }
    // Fallback (should never happen): keep the requested position.
    return booth;
  }

  /// Updates an existing booth.
  Future<Booth> updateBooth(Booth booth) async {
    await _booths.doc(booth.id).update(booth.toMap());
    return booth;
  }

  /// Deletes a booth and refreshes the exhibition's booth counts.
  Future<void> deleteBooth(String id) async {
    // Read the booth first so we know which exhibition it belonged to.
    final doc = await _booths.doc(id).get();
    final exhibitionId = doc.data()?['exhibitionId'] as String?;
    await _booths.doc(id).delete();
    if (exhibitionId != null) await _recalcBoothCounts(exhibitionId);
  }

  // =====================================================================
  // ADD-ON ITEMS
  // =====================================================================

  /// Returns the list of optional add-on items (furniture, wifi...).
  Future<List<AddItem>> getAddItems() async {
    final snap = await _addItems.get();
    return snap.docs.map((d) => AddItem.fromMap(d.data(), d.id)).toList();
  }

  /// Live list of add-on items. The Admin "Add-on Items" page edits this
  /// collection, and every other page (exhibitor / organizer) reads from
  /// the same live list, so a change made by the Admin shows up everywhere
  /// straight away.
  Stream<List<AddItem>> streamAddItems() {
    return _addItems.snapshots().map((snap) =>
        snap.docs.map((d) => AddItem.fromMap(d.data(), d.id)).toList());
  }

  /// Admin: create a new add-on item.
  Future<AddItem> createAddItem(AddItem item) async {
    final ref = await _addItems.add(item.toMap());
    return AddItem.fromMap(item.toMap(), ref.id);
  }

  /// Admin: update an existing add-on item.
  Future<void> updateAddItem(AddItem item) async {
    await _addItems.doc(item.id).update(item.toMap());
  }

  /// Admin: delete an add-on item.
  Future<void> deleteAddItem(String id) async {
    await _addItems.doc(id).delete();
  }

  // =====================================================================
  // APPLICATIONS
  // =====================================================================

  /// Returns applications, optionally filtered by exhibitor or exhibition.
  /// Only ONE field is used inside the Firestore query, so no composite
  /// index is needed. A second filter (if any) is applied in Dart.
  Future<List<BoothApplication>> getApplications({
    String? exhibitorId,
    String? exhibitionId,
  }) async {
    Query<Map<String, dynamic>> query = _applications;
    if (exhibitionId != null) {
      query = query.where('exhibitionId', isEqualTo: exhibitionId);
    } else if (exhibitorId != null) {
      query = query.where('exhibitorId', isEqualTo: exhibitorId);
    }
    final snap = await query.get();
    var list =
        snap.docs.map((d) => BoothApplication.fromMap(d.data(), d.id)).toList();
    if (exhibitionId != null && exhibitorId != null) {
      list = list.where((a) => a.exhibitorId == exhibitorId).toList();
    }
    return list;
  }

  /// Returns a single application by id, or null if it does not exist.
  Future<BoothApplication?> getApplication(String id) async {
    final doc = await _applications.doc(id).get();
    if (!doc.exists) return null;
    return BoothApplication.fromMap(doc.data()!, doc.id);
  }

  /// Submits a new application and marks the chosen booths as "pending".
  /// A Firestore "batch" is used so all booth updates happen together.
  Future<BoothApplication> submitApplication(
      BoothApplication application) async {
    final ref = await _applications.add(application.toMap());
    final batch = _db.batch();
    for (final boothId in application.boothIds) {
      batch.update(_booths.doc(boothId), {
        'status': BoothStatus.pending.name,
        'currentApplicationId': ref.id,
      });
    }
    await batch.commit();
    // Some booths are now "pending", so refresh the booth counts.
    await _recalcBoothCounts(application.exhibitionId);
    return BoothApplication.fromMap(application.toMap(), ref.id);
  }

  /// Updates an application (for example when an organizer approves or
  /// rejects it) and updates the related booth statuses to match.
  Future<BoothApplication> updateApplication(
      BoothApplication application) async {
    await _applications.doc(application.id).update(application.toMap());

    // Decide the new booth status from the application status.
    final boothStatus = switch (application.status) {
      ApplicationStatus.approved => BoothStatus.booked,
      ApplicationStatus.rejected ||
      ApplicationStatus.cancelled =>
        BoothStatus.available,
      ApplicationStatus.pending => BoothStatus.pending,
    };

    final batch = _db.batch();
    for (final boothId in application.boothIds) {
      batch.update(_booths.doc(boothId), {
        'status': boothStatus.name,
        'currentApplicationId':
            application.status == ApplicationStatus.approved
                ? application.id
                : null,
      });
    }
    await batch.commit();
    // Booth statuses changed, so refresh the booth counts.
    await _recalcBoothCounts(application.exhibitionId);
    return application;
  }

  /// Re-saves a PENDING application after the exhibitor edited it.
  ///
  /// Why a special method: the exhibitor may have ADDED or REMOVED booths
  /// while editing. Without care this leaves "redundant" data behind -
  /// booths that are still marked pending for an application that no
  /// longer uses them. This method fixes that:
  ///   * booths that were removed  -> set back to AVAILABLE.
  ///   * booths still in the form  -> kept/marked PENDING for this app.
  /// The application document itself is UPDATED (never added again), so
  /// the resubmit can never create a duplicate application.
  ///
  /// [previousBoothIds] is the booth list the application had BEFORE the
  /// edit, so we know which booths to release.
  Future<BoothApplication> resubmitApplication(
      BoothApplication application, List<String> previousBoothIds) async {
    // 1. Update (not add) the single application document.
    await _applications.doc(application.id).update(application.toMap());

    final batch = _db.batch();

    // 2. Release booths that the exhibitor removed from the application.
    for (final boothId in previousBoothIds) {
      if (!application.boothIds.contains(boothId)) {
        batch.update(_booths.doc(boothId), {
          'status': BoothStatus.available.name,
          'currentApplicationId': null,
        });
      }
    }

    // 3. Mark every booth that is still in the application as PENDING and
    //    tie it to this application.
    for (final boothId in application.boothIds) {
      batch.update(_booths.doc(boothId), {
        'status': BoothStatus.pending.name,
        'currentApplicationId': application.id,
      });
    }

    await batch.commit();
    await _recalcBoothCounts(application.exhibitionId);
    return application;
  }

  /// Permanently deletes a booth application (Admin only).
  ///
  /// Used by the Admin "All Bookings" page to clean up applications that
  /// are CANCELLED, REJECTED or APPROVED. If the application was APPROVED
  /// (or still PENDING), its booths are first set back to AVAILABLE so the
  /// booths are not stuck as "booked/pending" for a record that is gone.
  Future<void> deleteApplication(String id) async {
    final doc = await _applications.doc(id).get();
    if (!doc.exists) return;
    final application = BoothApplication.fromMap(doc.data()!, doc.id);

    // Free the booths if they were still held by this application.
    if (application.status == ApplicationStatus.approved ||
        application.status == ApplicationStatus.pending) {
      final batch = _db.batch();
      for (final boothId in application.boothIds) {
        batch.update(_booths.doc(boothId), {
          'status': BoothStatus.available.name,
          'currentApplicationId': null,
        });
      }
      await batch.commit();
    }

    // Remove the application document itself.
    await _applications.doc(id).delete();
    await _recalcBoothCounts(application.exhibitionId);
  }

  // =====================================================================
  // USERS (admin)
  // =====================================================================

  /// Returns every user profile (used by the admin user-management page).
  Future<List<UserModel>> getAllUsers() async {
    final snap = await _users.get();
    return snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
  }

  /// Updates a user profile.
  Future<UserModel> updateUser(UserModel user) async {
    await _users.doc(user.id).update(user.toMap());
    return user;
  }

  /// Deletes a user PROFILE document.
  /// NOTE: this does not delete the Firebase Auth login account. Deleting
  /// another person's Auth account needs the Firebase Admin SDK on a
  /// server, which is outside the scope of this mobile app. For the
  /// assignment, removing the profile (so the app ignores the account)
  /// is enough. You can also set isActive = false instead of deleting.
  Future<void> deleteUser(String id) async => _users.doc(id).delete();

  // =====================================================================
  // FLOOR PLAN IMAGE  (Phase 2 feature)
  // =====================================================================

  /// Saves the floor plan image for an exhibition, or clears it when
  /// [base64Image] is null. The image is stored as base64 text directly
  /// on the exhibition document - no Firebase Storage (and no credit
  /// card) is needed.
  Future<void> setFloorPlanImage(
      String exhibitionId, String? base64Image) async {
    await _exhibitions.doc(exhibitionId).set(
      {'floorPlanImageBase64': base64Image},
      SetOptions(merge: true), // only change this one field
    );
  }

  // =====================================================================
  // BOOTH COUNT HELPER
  // =====================================================================

  /// Recounts the booths of one exhibition and writes the correct
  /// totalBooths / availableBooths back to the exhibition document, so the
  /// numbers shown to users are always accurate. This fixes the old bug
  /// where the counts were fixed numbers that never changed.
  Future<void> _recalcBoothCounts(String exhibitionId) async {
    final snap =
        await _booths.where('exhibitionId', isEqualTo: exhibitionId).get();
    final total = snap.docs.length;
    final available = snap.docs
        .where((d) => d.data()['status'] == BoothStatus.available.name)
        .length;
    await _exhibitions.doc(exhibitionId).set(
      {'totalBooths': total, 'availableBooths': available},
      SetOptions(merge: true),
    );
  }

  // =====================================================================
  // REAL-TIME STREAMS  (live updates)
  // =====================================================================
  // A "stream" keeps an open connection to Firestore. Every time the data
  // changes in the cloud, Firestore PUSHES the new data to the app, so the
  // screens update by themselves - no need to log out and log in again.

  /// Live list of every exhibition.
  Stream<List<Exhibition>> streamAllExhibitions() {
    return _exhibitions.snapshots().map((snap) =>
        snap.docs.map((d) => Exhibition.fromMap(d.data(), d.id)).toList());
  }

  /// Live list of published exhibitions only (used by guests / exhibitors).
  Stream<List<Exhibition>> streamPublishedExhibitions() {
    return _exhibitions
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Exhibition.fromMap(d.data(), d.id)).toList());
  }

  /// Live single exhibition (updates when its image or booth counts change).
  Stream<Exhibition?> streamExhibition(String id) {
    return _exhibitions.doc(id).snapshots().map(
        (doc) => doc.exists ? Exhibition.fromMap(doc.data()!, doc.id) : null);
  }

  /// Live list of the booths that belong to one exhibition.
  Stream<List<Booth>> streamBooths(String exhibitionId) {
    return _booths
        .where('exhibitionId', isEqualTo: exhibitionId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Booth.fromMap(d.data(), d.id)).toList());
  }

  /// Live list of every booth application.
  Stream<List<BoothApplication>> streamAllApplications() {
    return _applications.snapshots().map((snap) => snap.docs
        .map((d) => BoothApplication.fromMap(d.data(), d.id))
        .toList());
  }

  /// Live list of every user account (used by the admin user page).
  Stream<List<UserModel>> streamAllUsers() {
    return _users.snapshots().map((snap) =>
        snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList());
  }

  // =====================================================================
  // SAMPLE DATA SEEDING
  // =====================================================================

  /// Fills Firestore with sample exhibitions, booths and add-on items the
  /// FIRST time the app runs (only when the database is still empty).
  /// This gives you demo data for testing and the presentation.
  ///
  /// It does NOT create user accounts - users are created through the
  /// Register screen so that Firebase Authentication handles them.
  Future<void> seedSampleDataIfEmpty() async {
    // If at least one exhibition already exists, do nothing.
    final existing = await _exhibitions.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    // ---- Add-on items ----
    final addItems = [
      {
        'name': 'Premium Furniture Package',
        'description': 'Table, 4 chairs, display shelf',
        'price': 350,
      },
      {
        'name': 'Extended WiFi (High Speed)',
        'description': '100Mbps dedicated connection',
        'price': 200,
      },
      {
        'name': 'Promotional Spot (Digital Screen)',
        'description': '30-second looping ad on venue screens',
        'price': 500,
      },
      {
        'name': 'Power Extension Package',
        'description': '3x 15A power outlets',
        'price': 120,
      },
    ];
    for (final item in addItems) {
      await _addItems.add(item);
    }

    final now = DateTime.now();

    // ---- Sample exhibition 1 (upcoming) ----
    final expo1 = await _exhibitions.add({
      'title': 'Tech Innovation Expo 2026',
      'description':
          'The premier technology exhibition showcasing cutting-edge '
              'innovations in AI, robotics, and green tech.',
      'organizerId': 'demo-organizer',
      'organizerName': 'Demo Organizer',
      'venue': 'KLCC Convention Centre, Kuala Lumpur',
      'startDate': now.add(const Duration(days: 30)).toIso8601String(),
      'endDate': now.add(const Duration(days: 33)).toIso8601String(),
      'isPublished': true,
      'status': ExhibitionStatus.upcoming.name,
      'floorPlanImageUrl': null,
      'floorPlanId': null,
      'totalBooths': 20,
      'availableBooths': 20,
      'category': 'Technology',
      'imageUrl': null,
      'preventAdjacentCompetitors': true,
    });
    await _seedBooths(expo1.id);

    // ---- Sample exhibition 2 (ongoing) ----
    final expo2 = await _exhibitions.add({
      'title': 'Malaysia Fashion Week 2026',
      'description':
          'Southeast Asia\'s most prestigious fashion exhibition featuring '
              'local and international designers.',
      'organizerId': 'demo-organizer',
      'organizerName': 'Demo Organizer',
      'venue': 'Mid Valley Exhibition Centre',
      'startDate': now.subtract(const Duration(days: 2)).toIso8601String(),
      'endDate': now.add(const Duration(days: 5)).toIso8601String(),
      'isPublished': true,
      'status': ExhibitionStatus.ongoing.name,
      'floorPlanImageUrl': null,
      'floorPlanId': null,
      'totalBooths': 20,
      'availableBooths': 20,
      'category': 'Fashion',
      'imageUrl': null,
      'preventAdjacentCompetitors': false,
    });
    await _seedBooths(expo2.id);
  }

  /// Helper: creates a 4 x 5 grid of 20 booths for one exhibition.
  Future<void> _seedBooths(String exhibitionId) async {
    const types = ['Premium', 'Standard', 'Economy'];
    const amenitiesMap = {
      'Premium': ['Power', 'WiFi', 'Corner', 'Extra Display'],
      'Standard': ['Power', 'WiFi'],
      'Economy': ['Power'],
    };
    const priceMap = {'Premium': 2000.0, 'Standard': 1200.0, 'Economy': 700.0};
    const sizeMap = {'Premium': 25.0, 'Standard': 16.0, 'Economy': 9.0};

    final batch = _db.batch();
    int count = 0;
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        final type = types[count % 3];
        final letter = String.fromCharCode(65 + row); // A, B, C, D
        final number = (col + 1).toString().padLeft(2, '0'); // 01..05
        // doc() with no id makes Firestore generate a unique id.
        batch.set(_booths.doc(), {
          'exhibitionId': exhibitionId,
          'boothNumber': '$letter-$number',
          'boothType': type,
          'sizeqm': sizeMap[type],
          'price': priceMap[type],
          'status': BoothStatus.available.name,
          'x': 20.0 + col * 120,
          'y': 20.0 + row * 120,
          'width': 100.0,
          'height': 100.0,
          'amenities': amenitiesMap[type],
          'currentApplicationId': null,
          'notes': null,
        });
        count++;
      }
    }
    await batch.commit();
  }
}
