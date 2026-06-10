import 'package:equatable/equatable.dart';

enum ExhibitionStatus { upcoming, ongoing, completed, cancelled }
enum UserRole { guest, exhibitor, organizer, admin }
enum BoothStatus { available, booked, pending, unavailable }
enum ApplicationStatus { pending, approved, rejected, cancelled }

class UserModel extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String? companyName;
  final String? phone;
  final DateTime createdAt;
  final bool isActive;
  // Profile picture stored as base64 text (no Firebase Storage needed).
  // Empty string or null means "no picture uploaded".
  final String? photoBase64;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.companyName,
    this.phone,
    required this.createdAt,
    this.isActive = true,
    this.photoBase64,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) => UserModel(
    id: id,
    email: map['email'] ?? '',
    displayName: map['displayName'] ?? '',
    role: UserRole.values.firstWhere((r) => r.name == map['role'], orElse: () => UserRole.exhibitor),
    companyName: map['companyName'],
    phone: map['phone'],
    createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    isActive: map['isActive'] ?? true,
    photoBase64: map['photoBase64'],
  );

  Map<String, dynamic> toMap() => {
    'email': email, 'displayName': displayName, 'role': role.name,
    'companyName': companyName, 'phone': phone,
    'createdAt': createdAt.toIso8601String(), 'isActive': isActive,
    'photoBase64': photoBase64,
  };

  UserModel copyWith({String? email, String? displayName, UserRole? role, String? companyName,
      String? phone, bool? isActive, String? photoBase64}) =>
    UserModel(id: id, email: email ?? this.email, displayName: displayName ?? this.displayName,
      role: role ?? this.role, companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone, createdAt: createdAt, isActive: isActive ?? this.isActive,
      photoBase64: photoBase64 ?? this.photoBase64);

  /// True when the user has uploaded a profile picture.
  bool get hasPhoto => photoBase64 != null && photoBase64!.isNotEmpty;

  @override
  List<Object?> get props => [id, email, role];
}

class Exhibition extends Equatable {
  final String id;
  final String title;
  final String description;
  final String organizerId;
  final String organizerName;
  final String venue;
  final DateTime startDate;
  final DateTime endDate;
  final bool isPublished;
  final ExhibitionStatus status;
  final String? floorPlanImageUrl;
  final String? floorPlanId;
  final String? floorPlanImageBase64; // uploaded floor plan image (base64 text)
  final int totalBooths;
  final int availableBooths;
  final String? category;
  final String? imageUrl;
  final bool preventAdjacentCompetitors;

  const Exhibition({
    required this.id, required this.title, required this.description,
    required this.organizerId, required this.organizerName, required this.venue,
    required this.startDate, required this.endDate, required this.isPublished,
    required this.status, this.floorPlanImageUrl, this.floorPlanId,
    this.floorPlanImageBase64,
    this.totalBooths = 0, this.availableBooths = 0, this.category,
    this.imageUrl, this.preventAdjacentCompetitors = false,
  });

  factory Exhibition.fromMap(Map<String, dynamic> map, String id) => Exhibition(
    id: id, title: map['title'] ?? '', description: map['description'] ?? '',
    organizerId: map['organizerId'] ?? '', organizerName: map['organizerName'] ?? '',
    venue: map['venue'] ?? '',
    startDate: DateTime.tryParse(map['startDate'] ?? '') ?? DateTime.now(),
    endDate: DateTime.tryParse(map['endDate'] ?? '') ?? DateTime.now(),
    isPublished: map['isPublished'] ?? false,
    status: ExhibitionStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => ExhibitionStatus.upcoming),
    floorPlanImageUrl: map['floorPlanImageUrl'], floorPlanId: map['floorPlanId'],
    floorPlanImageBase64: map['floorPlanImageBase64'],
    totalBooths: map['totalBooths'] ?? 0, availableBooths: map['availableBooths'] ?? 0,
    category: map['category'], imageUrl: map['imageUrl'],
    preventAdjacentCompetitors: map['preventAdjacentCompetitors'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'title': title, 'description': description, 'organizerId': organizerId,
    'organizerName': organizerName, 'venue': venue,
    'startDate': startDate.toIso8601String(), 'endDate': endDate.toIso8601String(),
    'isPublished': isPublished, 'status': status.name,
    'floorPlanImageUrl': floorPlanImageUrl, 'floorPlanId': floorPlanId,
    'floorPlanImageBase64': floorPlanImageBase64,
    'totalBooths': totalBooths, 'availableBooths': availableBooths,
    'category': category, 'imageUrl': imageUrl,
    'preventAdjacentCompetitors': preventAdjacentCompetitors,
  };

  Exhibition copyWith({String? title, String? description, String? venue,
    DateTime? startDate, DateTime? endDate, bool? isPublished, ExhibitionStatus? status,
    String? floorPlanImageUrl, String? floorPlanId, String? floorPlanImageBase64,
    int? totalBooths, int? availableBooths,
    String? category, String? imageUrl, bool? preventAdjacentCompetitors}) =>
    Exhibition(id: id, title: title ?? this.title, description: description ?? this.description,
      organizerId: organizerId, organizerName: organizerName, venue: venue ?? this.venue,
      startDate: startDate ?? this.startDate, endDate: endDate ?? this.endDate,
      isPublished: isPublished ?? this.isPublished, status: status ?? this.status,
      floorPlanImageUrl: floorPlanImageUrl ?? this.floorPlanImageUrl,
      floorPlanId: floorPlanId ?? this.floorPlanId,
      floorPlanImageBase64: floorPlanImageBase64 ?? this.floorPlanImageBase64,
      totalBooths: totalBooths ?? this.totalBooths, availableBooths: availableBooths ?? this.availableBooths,
      category: category ?? this.category, imageUrl: imageUrl ?? this.imageUrl,
      preventAdjacentCompetitors: preventAdjacentCompetitors ?? this.preventAdjacentCompetitors);

  String get statusLabel => switch (status) {
    ExhibitionStatus.upcoming => 'Upcoming',
    ExhibitionStatus.ongoing => 'Ongoing',
    ExhibitionStatus.completed => 'Completed',
    ExhibitionStatus.cancelled => 'Cancelled',
  };

  @override
  List<Object?> get props => [id, title, isPublished, status];
}

class Booth extends Equatable {
  final String id;
  final String exhibitionId;
  final String boothNumber;
  final String boothType;
  final double sizeqm;
  final double price;
  final BoothStatus status;
  final double x;
  final double y;
  final double width;
  final double height;
  final List<String> amenities;
  final String? currentApplicationId;
  final String? notes;

  const Booth({
    required this.id, required this.exhibitionId, required this.boothNumber,
    required this.boothType, required this.sizeqm, required this.price,
    required this.status, required this.x, required this.y,
    required this.width, required this.height,
    this.amenities = const [], this.currentApplicationId, this.notes,
  });

  factory Booth.fromMap(Map<String, dynamic> map, String id) => Booth(
    id: id, exhibitionId: map['exhibitionId'] ?? '',
    boothNumber: map['boothNumber'] ?? '', boothType: map['boothType'] ?? 'Standard',
    sizeqm: (map['sizeqm'] ?? 0).toDouble(), price: (map['price'] ?? 0).toDouble(),
    status: BoothStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => BoothStatus.available),
    x: (map['x'] ?? 0).toDouble(), y: (map['y'] ?? 0).toDouble(),
    width: (map['width'] ?? 60).toDouble(), height: (map['height'] ?? 60).toDouble(),
    amenities: List<String>.from(map['amenities'] ?? []),
    currentApplicationId: map['currentApplicationId'], notes: map['notes'],
  );

  Map<String, dynamic> toMap() => {
    'exhibitionId': exhibitionId, 'boothNumber': boothNumber, 'boothType': boothType,
    'sizeqm': sizeqm, 'price': price, 'status': status.name,
    'x': x, 'y': y, 'width': width, 'height': height,
    'amenities': amenities, 'currentApplicationId': currentApplicationId, 'notes': notes,
  };

  Booth copyWith({String? boothType, double? sizeqm, double? price, BoothStatus? status,
    double? x, double? y, double? width, double? height, List<String>? amenities,
    String? currentApplicationId, String? notes}) =>
    Booth(id: id, exhibitionId: exhibitionId, boothNumber: boothNumber,
      boothType: boothType ?? this.boothType, sizeqm: sizeqm ?? this.sizeqm,
      price: price ?? this.price, status: status ?? this.status,
      x: x ?? this.x, y: y ?? this.y, width: width ?? this.width, height: height ?? this.height,
      amenities: amenities ?? this.amenities,
      currentApplicationId: currentApplicationId ?? this.currentApplicationId,
      notes: notes ?? this.notes);

  @override
  List<Object?> get props => [id, boothNumber, status];
}

class AddItem extends Equatable {
  final String id;
  final String name;
  final String description;
  final double price;

  const AddItem({required this.id, required this.name, required this.description, required this.price});

  factory AddItem.fromMap(Map<String, dynamic> map, String id) =>
    AddItem(id: id, name: map['name'] ?? '', description: map['description'] ?? '', price: (map['price'] ?? 0).toDouble());

  Map<String, dynamic> toMap() => {'name': name, 'description': description, 'price': price};

  @override
  List<Object?> get props => [id, name];
}

class BoothApplication extends Equatable {
  final String id;
  final String exhibitionId;
  final String exhibitionTitle;
  final String exhibitorId;
  final String exhibitorName;
  final List<String> boothIds;
  final List<String> boothNumbers;
  final String companyName;
  final String companyDescription;
  final String exhibitDescription;
  final DateTime exhibitionStartDate;
  final DateTime exhibitionEndDate;
  final List<String> selectedAddItemIds;
  final double totalPrice;
  final ApplicationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rejectionReason;
  final String? cancellationReason;

  const BoothApplication({
    required this.id, required this.exhibitionId, required this.exhibitionTitle,
    required this.exhibitorId, required this.exhibitorName, required this.boothIds,
    required this.boothNumbers, required this.companyName, required this.companyDescription,
    required this.exhibitDescription, required this.exhibitionStartDate, required this.exhibitionEndDate,
    required this.selectedAddItemIds, required this.totalPrice, required this.status,
    required this.createdAt, required this.updatedAt, this.rejectionReason, this.cancellationReason,
  });

  factory BoothApplication.fromMap(Map<String, dynamic> map, String id) => BoothApplication(
    id: id, exhibitionId: map['exhibitionId'] ?? '', exhibitionTitle: map['exhibitionTitle'] ?? '',
    exhibitorId: map['exhibitorId'] ?? '', exhibitorName: map['exhibitorName'] ?? '',
    boothIds: List<String>.from(map['boothIds'] ?? []),
    boothNumbers: List<String>.from(map['boothNumbers'] ?? []),
    companyName: map['companyName'] ?? '', companyDescription: map['companyDescription'] ?? '',
    exhibitDescription: map['exhibitDescription'] ?? '',
    exhibitionStartDate: DateTime.tryParse(map['exhibitionStartDate'] ?? '') ?? DateTime.now(),
    exhibitionEndDate: DateTime.tryParse(map['exhibitionEndDate'] ?? '') ?? DateTime.now(),
    selectedAddItemIds: List<String>.from(map['selectedAddItemIds'] ?? []),
    totalPrice: (map['totalPrice'] ?? 0).toDouble(),
    status: ApplicationStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => ApplicationStatus.pending),
    createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    rejectionReason: map['rejectionReason'], cancellationReason: map['cancellationReason'],
  );

  Map<String, dynamic> toMap() => {
    'exhibitionId': exhibitionId, 'exhibitionTitle': exhibitionTitle,
    'exhibitorId': exhibitorId, 'exhibitorName': exhibitorName,
    'boothIds': boothIds, 'boothNumbers': boothNumbers,
    'companyName': companyName, 'companyDescription': companyDescription,
    'exhibitDescription': exhibitDescription,
    'exhibitionStartDate': exhibitionStartDate.toIso8601String(),
    'exhibitionEndDate': exhibitionEndDate.toIso8601String(),
    'selectedAddItemIds': selectedAddItemIds, 'totalPrice': totalPrice, 'status': status.name,
    'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(),
    'rejectionReason': rejectionReason, 'cancellationReason': cancellationReason,
  };

  BoothApplication copyWith({String? companyName, String? companyDescription,
    String? exhibitDescription, List<String>? selectedAddItemIds, double? totalPrice,
    ApplicationStatus? status, String? rejectionReason, String? cancellationReason,
    List<String>? boothIds, List<String>? boothNumbers}) =>
    BoothApplication(
      id: id, exhibitionId: exhibitionId, exhibitionTitle: exhibitionTitle,
      exhibitorId: exhibitorId, exhibitorName: exhibitorName,
      boothIds: boothIds ?? this.boothIds,
      boothNumbers: boothNumbers ?? this.boothNumbers,
      companyName: companyName ?? this.companyName,
      companyDescription: companyDescription ?? this.companyDescription,
      exhibitDescription: exhibitDescription ?? this.exhibitDescription,
      exhibitionStartDate: exhibitionStartDate, exhibitionEndDate: exhibitionEndDate,
      selectedAddItemIds: selectedAddItemIds ?? this.selectedAddItemIds,
      totalPrice: totalPrice ?? this.totalPrice, status: status ?? this.status,
      createdAt: createdAt, updatedAt: DateTime.now(),
      rejectionReason: rejectionReason ?? this.rejectionReason,
      cancellationReason: cancellationReason ?? this.cancellationReason);

  String get statusLabel => switch (status) {
    ApplicationStatus.pending => 'Pending Review',
    ApplicationStatus.approved => 'Approved',
    ApplicationStatus.rejected => 'Rejected',
    ApplicationStatus.cancelled => 'Cancelled',
  };

  @override
  List<Object?> get props => [id, status, updatedAt];
}

class FloorPlan extends Equatable {
  final String id;
  final String exhibitionId;
  final String imageUrl;
  final double mapWidth;
  final double mapHeight;
  final DateTime createdAt;

  const FloorPlan({
    required this.id, required this.exhibitionId, required this.imageUrl,
    required this.mapWidth, required this.mapHeight, required this.createdAt,
  });

  factory FloorPlan.fromMap(Map<String, dynamic> map, String id) => FloorPlan(
    id: id, exhibitionId: map['exhibitionId'] ?? '', imageUrl: map['imageUrl'] ?? '',
    mapWidth: (map['mapWidth'] ?? 800).toDouble(), mapHeight: (map['mapHeight'] ?? 600).toDouble(),
    createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'exhibitionId': exhibitionId, 'imageUrl': imageUrl,
    'mapWidth': mapWidth, 'mapHeight': mapHeight, 'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, exhibitionId];
}
